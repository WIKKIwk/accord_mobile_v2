package com.example.accord_mobile_v2

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

private const val GODEX_STATUS_INITIAL_TIMEOUT_MS = 1_200L
private const val GODEX_STATUS_POLL_MS = 150L
private const val GODEX_STATUS_READ_TIMEOUT_MS = 250
private const val GODEX_STATUS_BASE_TIMEOUT_MS = 8_000L
private const val GODEX_STATUS_PER_LABEL_TIMEOUT_MS = 2_000L
private const val GODEX_STATUS_MAX_TIMEOUT_MS = 30_000L
private const val GODEX_FALLBACK_PER_LABEL_MS = 1_200L
private const val GODEX_FALLBACK_MAX_MS = 15_000L
private val godexStatusPattern = Regex("(?:^|[^0-9])([0-9]{2}),([0-9]{5})(?:[^0-9]|$)")
private val godexActiveErrorPattern = Regex("ERROR([0-9]{2})")
private val godexGraphicNamePattern = Regex("[A-Z0-9]{1,20}")

class UsbPrinterChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "accord/usb_printer")
    private val usbManager = activity.getSystemService(Context.USB_SERVICE) as UsbManager
    private val actionUsbPermission = "${activity.packageName}.USB_PRINTER_PERMISSION"
    private val printExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "accord-usb-printer").apply { isDaemon = true }
    }
    private val deferredGodexCleanupNames = linkedSetOf<String>()
    private var pendingPrint: PendingUsbPrint? = null
    private var permissionReceiver: BroadcastReceiver? = null

    init {
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "printTest" -> printTest(call, result)
            "printRpsTest" -> printRpsTest(call, result)
            "detectPrinter" -> detectPrinter(result)
            "printRaw" -> printRaw(call, result)
            else -> result.notImplemented()
        }
    }

    private fun detectPrinter(result: MethodChannel.Result) {
        val printer = findPrinterCandidate()
        if (printer == null) {
            result.error("usb_printer_not_found", "USB printer not found", null)
            return
        }
        if (printer.profile.kind == UsbPrinterKind.UNKNOWN) {
            result.error(
                "usb_printer_unsupported",
                "USB printer is neither GoDEX nor Zebra",
                printer.profile.response(printer.device),
            )
            return
        }
        result.success(printer.profile.response(printer.device))
    }

    private fun printTest(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPrint != null) {
            result.error("usb_printer_busy", "Printer permission request is already open", null)
            return
        }
        val printer = findPrinterCandidate()
        if (printer == null) {
            result.error("usb_printer_not_found", "USB printer not found", null)
            return
        }
        val title = call.argument<String>("title").orEmpty().ifBlank { "ACCORD USB TEST" }
        val payload = call.argument<String>("payload").orEmpty().ifBlank { "ACCORD-USB-TEST" }
        val bytes = buildEscPosTestLabel(title, payload)
        val request = PendingUsbPrint(printer.device, bytes, result) { device, write ->
            mapOf(
                "ok" to true,
                "bytes" to write.bytes,
                "deviceName" to device.deviceName,
                "vendorId" to device.vendorId,
                "productId" to device.productId,
            )
        }
        startPrint(request)
    }

    private fun printRpsTest(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPrint != null) {
            result.error("usb_printer_busy", "Printer permission request is already open", null)
            return
        }
        val printer = findPrinterCandidate()
        if (printer == null) {
            result.error("usb_printer_not_found", "USB printer not found", null)
            return
        }
        val requestBody = UsbRpsPrintRequest.fromCall(call)
        val rendered = buildGodexRpsTestJob(requestBody)
        val request = PendingUsbPrint(
            device = printer.device,
            bytes = rendered.bytes,
            result = result,
            options = UsbPrintOptions(
                printerKind = printer.profile.kind,
                godexGraphicNames = rendered.graphicNames,
                labelCount = rendered.labelCount,
            ),
        ) { device, write ->
            requestBody.response(device, write)
        }
        startPrint(request)
    }

    private fun printRaw(call: MethodCall, result: MethodChannel.Result) {
        if (pendingPrint != null) {
            result.error("usb_printer_busy", "Printer permission request is already open", null)
            return
        }
        val printer = findPrinterCandidate()
        if (printer == null) {
            result.error("usb_printer_not_found", "USB printer not found", null)
            return
        }
        val bytes = rawBytes(call)
        if (bytes == null || bytes.isEmpty()) {
            result.error("usb_printer_invalid_payload", "Raw USB payload is empty", null)
            return
        }
        val expectedPrinter = UsbPrinterKind.fromValue(
            call.argument<String>("printer_kind").orEmpty(),
        )
        if (printer.profile.kind == UsbPrinterKind.UNKNOWN) {
            result.error(
                "usb_printer_unsupported",
                "USB printer is neither GoDEX nor Zebra",
                printer.profile.response(printer.device),
            )
            return
        }
        if (expectedPrinter != UsbPrinterKind.UNKNOWN &&
            expectedPrinter != printer.profile.kind
        ) {
            result.error(
                "usb_printer_changed",
                "Connected USB printer changed before print",
                printer.profile.response(printer.device),
            )
            return
        }
        val printCount = call.argument<Number>("print_count")?.toInt()
            ?.takeIf { it > 0 }
            ?: 1
        val labelCount = call.argument<Number>("label_count")?.toInt()
            ?.takeIf { it > 0 }
            ?: printCount
        val graphicNames = if (printer.profile.kind == UsbPrinterKind.GODEX) {
            godexGraphicNames(call)
        } else {
            emptyList()
        }
        val payload = repeatBytes(bytes, printCount)
        val request = PendingUsbPrint(
            device = printer.device,
            bytes = payload,
            result = result,
            options = UsbPrintOptions(
                printerKind = printer.profile.kind,
                godexGraphicNames = graphicNames,
                labelCount = labelCount * printCount,
            ),
        ) { device, write ->
            mapOf(
                "ok" to true,
                "status" to "done",
                "printer_status" to write.printerStatus,
                "print_count" to printCount,
                "bytes" to write.bytes,
                "deviceName" to device.deviceName,
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "printer" to printer.profile.kind.value,
                "manufacturerName" to printer.profile.manufacturerName,
                "productName" to printer.profile.productName,
            )
        }
        startPrint(request)
    }

    private fun rawBytes(call: MethodCall): ByteArray? {
        val value = call.argument<Any>("bytes")
        return when (value) {
            is ByteArray -> value
            is List<*> -> value.mapNotNull { (it as? Number)?.toInt()?.toByte() }.toByteArray()
            else -> null
        }
    }

    private fun godexGraphicNames(call: MethodCall): List<String> {
        return call.argument<List<*>>("godex_graphic_names")
            .orEmpty()
            .mapNotNull { value ->
                value?.toString()?.trim()?.uppercase(Locale.US)
                    ?.takeIf(godexGraphicNamePattern::matches)
            }
            .distinct()
            .take(200)
    }

    private fun startPrint(request: PendingUsbPrint) {
        if (usbManager.hasPermission(request.device)) {
            finishPrint(request)
            return
        }
        pendingPrint = request
        registerPermissionReceiver()
        usbManager.requestPermission(request.device, permissionIntent())
    }

    private fun findPrinterCandidate(): UsbPrinterCandidate? {
        val devices = usbManager.deviceList.values.toList()
        val candidates = devices.mapNotNull { device ->
            printerCandidate(device, requirePrinterClass = true)
                ?: printerCandidate(device, requirePrinterClass = false)
        }
        return candidates.maxByOrNull { candidate ->
            if (candidate.profile.kind == UsbPrinterKind.UNKNOWN) 0 else 1
        }
    }

    private fun printerCandidate(
        device: UsbDevice,
        requirePrinterClass: Boolean,
    ): UsbPrinterCandidate? {
        for (index in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(index)
            if (requirePrinterClass && usbInterface.interfaceClass != UsbConstants.USB_CLASS_PRINTER) {
                continue
            }
            val endpoint = bulkOutEndpoint(usbInterface) ?: continue
            return UsbPrinterCandidate(
                device,
                usbInterface,
                endpoint,
                bulkInEndpoint(usbInterface),
                UsbPrinterProfile.fromDevice(device),
            )
        }
        return null
    }

    private fun bulkOutEndpoint(usbInterface: UsbInterface): UsbEndpoint? {
        for (index in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(index)
            val isBulk = endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK
            val isOut = endpoint.direction == UsbConstants.USB_DIR_OUT
            if (isBulk && isOut) {
                return endpoint
            }
        }
        return null
    }

    private fun bulkInEndpoint(usbInterface: UsbInterface): UsbEndpoint? {
        for (index in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(index)
            val isBulk = endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK
            val isIn = endpoint.direction == UsbConstants.USB_DIR_IN
            if (isBulk && isIn) {
                return endpoint
            }
        }
        return null
    }

    private fun registerPermissionReceiver() {
        if (permissionReceiver != null) {
            return
        }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != actionUsbPermission) {
                    return
                }
                val request = pendingPrint ?: return
                pendingPrint = null
                unregisterPermissionReceiver()
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                if (!granted) {
                    request.result.error("usb_printer_permission_denied", "USB printer permission denied", null)
                    return
                }
                finishPrint(request)
            }
        }
        permissionReceiver = receiver
        val filter = IntentFilter(actionUsbPermission)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            activity.registerReceiver(receiver, filter)
        }
    }

    private fun unregisterPermissionReceiver() {
        val receiver = permissionReceiver ?: return
        permissionReceiver = null
        runCatching { activity.unregisterReceiver(receiver) }
    }

    private fun permissionIntent(): PendingIntent {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        return PendingIntent.getBroadcast(
            activity,
            0,
            Intent(actionUsbPermission).setPackage(activity.packageName),
            flags,
        )
    }

    private fun finishPrint(request: PendingUsbPrint) {
        printExecutor.execute {
            try {
                val candidate = printerCandidate(request.device, requirePrinterClass = false)
                    ?: throw IllegalStateException("USB printer endpoint not found")
                val write = writeBytes(candidate, request.bytes, request.options)
                val response = request.response(request.device, write)
                activity.runOnUiThread {
                    request.result.success(response)
                }
            } catch (error: Throwable) {
                activity.runOnUiThread {
                    request.result.error(
                        "usb_printer_write_failed",
                        error.message ?: "USB printer write failed",
                        null,
                    )
                }
            }
        }
    }

    private fun writeBytes(
        candidate: UsbPrinterCandidate,
        bytes: ByteArray,
        options: UsbPrintOptions,
    ): UsbPrintWriteResult {
        val connection = usbManager.openDevice(candidate.device)
            ?: throw IllegalStateException("USB device open failed")
        var claimed = false
        try {
            if (!connection.claimInterface(candidate.usbInterface, true)) {
                throw IllegalStateException("USB interface claim failed")
            }
            claimed = true
            if (options.printerKind == UsbPrinterKind.GODEX) {
                drainGodexStatus(connection, candidate.statusEndpoint)
            }
            val sent = writeUsbPayload(connection, candidate.endpoint, bytes)
            if (options.printerKind != UsbPrinterKind.GODEX) {
                return UsbPrintWriteResult(sent, "USB OK")
            }
            val printerStatus = finishGodexPrint(connection, candidate, options)
            return UsbPrintWriteResult(sent, printerStatus)
        } finally {
            if (claimed) {
                connection.releaseInterface(candidate.usbInterface)
            }
            connection.close()
        }
    }

    private fun writeUsbPayload(
        connection: UsbDeviceConnection,
        endpoint: UsbEndpoint,
        bytes: ByteArray,
    ): Int {
        var offset = 0
        while (offset < bytes.size) {
            val chunkSize = minOf(
                endpoint.maxPacketSize.coerceAtLeast(64),
                bytes.size - offset,
            )
            val sent = connection.bulkTransfer(
                endpoint,
                bytes,
                offset,
                chunkSize,
                5000,
            )
            if (sent <= 0) {
                throw IllegalStateException("USB bulk transfer failed at byte $offset")
            }
            offset += sent
        }
        return offset
    }

    private fun drainGodexStatus(
        connection: UsbDeviceConnection,
        endpoint: UsbEndpoint?,
    ) {
        endpoint ?: return
        val buffer = ByteArray(endpoint.maxPacketSize.coerceAtLeast(64))
        repeat(8) {
            val received = connection.bulkTransfer(
                endpoint,
                buffer,
                buffer.size,
                20,
            )
            if (received <= 0) {
                return
            }
        }
    }

    private fun finishGodexPrint(
        connection: UsbDeviceConnection,
        candidate: UsbPrinterCandidate,
        options: UsbPrintOptions,
    ): String {
        val currentNames = options.godexGraphicNames
        val outcome = waitForGodexReady(
            connection,
            candidate,
            options.labelCount.coerceAtLeast(1),
        )
        if (outcome.errorCode != null) {
            deferredGodexCleanupNames.addAll(currentNames)
            throw IllegalStateException(godexStatusError(outcome.errorCode))
        }
        if (outcome.ready) {
            cleanupGodexGraphics(
                connection,
                candidate.endpoint,
                deferredGodexCleanupNames + currentNames,
            )
            return outcome.rawStatus.ifBlank { "00,00000" }
        }
        if (outcome.sawStatus) {
            deferredGodexCleanupNames.addAll(currentNames)
            return outcome.rawStatus.ifBlank { "USB queued" }
        }

        val settled = waitForGodexFallback(options.labelCount.coerceAtLeast(1))
        if (settled) {
            cleanupGodexGraphics(
                connection,
                candidate.endpoint,
                deferredGodexCleanupNames + currentNames,
            )
        } else {
            deferredGodexCleanupNames.addAll(currentNames)
        }
        return "USB OK"
    }

    private fun waitForGodexReady(
        connection: UsbDeviceConnection,
        candidate: UsbPrinterCandidate,
        labelCount: Int,
    ): GodexStatusOutcome {
        val endpoint = candidate.statusEndpoint ?: return GodexStatusOutcome()
        val startedAt = SystemClock.elapsedRealtime()
        val timeoutMs = (GODEX_STATUS_BASE_TIMEOUT_MS +
            labelCount.toLong() * GODEX_STATUS_PER_LABEL_TIMEOUT_MS)
            .coerceAtMost(GODEX_STATUS_MAX_TIMEOUT_MS)
        val deadline = startedAt + timeoutMs
        val noResponseDeadline = startedAt + GODEX_STATUS_INITIAL_TIMEOUT_MS
        val response = StringBuilder()
        val readBuffer = ByteArray(endpoint.maxPacketSize.coerceAtLeast(64))
        var lastPollAt = 0L
        var sawStatus = false
        var rawStatus = ""

        while (SystemClock.elapsedRealtime() < deadline) {
            val received = connection.bulkTransfer(
                endpoint,
                readBuffer,
                readBuffer.size,
                GODEX_STATUS_READ_TIMEOUT_MS,
            )
            if (received > 0) {
                response.append(String(readBuffer, 0, received, Charsets.US_ASCII))
                val activeError = godexActiveErrorPattern
                    .findAll(response)
                    .lastOrNull()
                    ?.groupValues
                    ?.get(1)
                if (activeError != null) {
                    return GodexStatusOutcome(
                        sawStatus = true,
                        rawStatus = "ERROR$activeError",
                        errorCode = activeError,
                    )
                }
                val statusMatch = godexStatusPattern.findAll(response).lastOrNull()
                if (statusMatch != null) {
                    sawStatus = true
                    val code = statusMatch.groupValues[1]
                    val remaining = statusMatch.groupValues[2].toIntOrNull() ?: 0
                    rawStatus = "$code,${statusMatch.groupValues[2]}"
                    if (code == "00" && remaining == 0) {
                        return GodexStatusOutcome(
                            ready = true,
                            sawStatus = true,
                            rawStatus = rawStatus,
                        )
                    }
                    if (code != "00" && code != "50" && code != "60") {
                        return GodexStatusOutcome(
                            sawStatus = true,
                            rawStatus = rawStatus,
                            errorCode = code,
                        )
                    }
                }
            }

            val now = SystemClock.elapsedRealtime()
            if (!sawStatus && now >= noResponseDeadline) {
                return GodexStatusOutcome()
            }
            if (now - lastPollAt >= GODEX_STATUS_POLL_MS) {
                writeUsbPayload(
                    connection,
                    candidate.endpoint,
                    "~S,STATUS\r\n".toByteArray(Charsets.US_ASCII),
                )
                lastPollAt = now
            }
        }
        return GodexStatusOutcome(sawStatus = sawStatus, rawStatus = rawStatus)
    }

    private fun waitForGodexFallback(labelCount: Int): Boolean {
        val requiredMs = labelCount.toLong() * GODEX_FALLBACK_PER_LABEL_MS
        val waitMs = requiredMs.coerceAtMost(GODEX_FALLBACK_MAX_MS)
        Thread.sleep(waitMs)
        return requiredMs <= GODEX_FALLBACK_MAX_MS
    }

    private fun cleanupGodexGraphics(
        connection: UsbDeviceConnection,
        endpoint: UsbEndpoint,
        names: Collection<String>,
    ) {
        val validNames = names
            .map { it.trim().uppercase(Locale.US) }
            .filter(godexGraphicNamePattern::matches)
            .distinct()
        if (validNames.isEmpty()) {
            return
        }
        val cleanup = buildString {
            for (name in validNames) {
                append("~MDELG,")
                append(name)
                append("\r\n")
            }
        }.toByteArray(Charsets.US_ASCII)
        val cleaned = runCatching {
            writeUsbPayload(connection, endpoint, cleanup)
        }.isSuccess
        if (cleaned) {
            deferredGodexCleanupNames.removeAll(validNames.toSet())
        } else {
            deferredGodexCleanupNames.addAll(validNames)
        }
    }

    private fun godexStatusError(code: String): String {
        val detail = when (code) {
            "01", "02" -> "Media empty or jammed"
            "03" -> "Ribbon empty"
            "04" -> "Print head is open"
            "05" -> "Rewinder full"
            "06" -> "File system full"
            "07" -> "File name not found"
            "08" -> "Duplicate Name"
            "09" -> "Syntax error"
            "10" -> "Cutter jam"
            "11" -> "Extended memory not found"
            "20" -> "Printer paused"
            else -> "Printer error"
        }
        return "GoDEX status $code: $detail"
    }

    private fun buildEscPosTestLabel(title: String, payload: String): ByteArray {
        val ascii = Charset.forName("US-ASCII")
        val now = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
        val data = payload.take(180).toByteArray(ascii)
        val storeLength = data.size + 3
        val pL = storeLength % 256
        val pH = storeLength / 256
        val output = ArrayList<Byte>()
        fun write(vararg values: Int) {
            values.forEach { output.add(it.toByte()) }
        }
        fun writeText(value: String) {
            output.addAll(value.toByteArray(ascii).toList())
        }
        write(0x1B, 0x40)
        write(0x1B, 0x61, 0x01)
        write(0x1B, 0x45, 0x01)
        writeText("${title.take(32)}\n")
        write(0x1B, 0x45, 0x00)
        writeText("USB DIRECT PRINT\n")
        writeText("$now\n\n")
        write(0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00)
        write(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06)
        write(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31)
        write(0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30)
        output.addAll(data.toList())
        write(0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30)
        writeText("\n$payload\n\n\n")
        return output.toByteArray()
    }

    private fun buildGodexRpsTestJob(request: UsbRpsPrintRequest): GodexNativePrintJob {
        val output = ArrayList<Byte>()
        val graphicNames = mutableListOf<String>()
        val count = request.printCount.coerceAtLeast(1)
        repeat(count) { index ->
            val rendered = GodexRpsRenderer.renderJob(
                request,
                includeFinalStatus = index == count - 1,
            )
            output.addAll(rendered.bytes.toList())
            graphicNames.addAll(rendered.graphicNames)
        }
        return GodexNativePrintJob(
            bytes = output.toByteArray(),
            graphicNames = graphicNames,
            labelCount = count,
        )
    }

    private fun repeatBytes(bytes: ByteArray, count: Int): ByteArray {
        val safeCount = count.coerceAtLeast(1)
        if (safeCount == 1) {
            return bytes
        }
        val output = ByteArray(bytes.size * safeCount)
        for (index in 0 until safeCount) {
            System.arraycopy(bytes, 0, output, index * bytes.size, bytes.size)
        }
        return output
    }
}

private data class UsbPrinterCandidate(
    val device: UsbDevice,
    val usbInterface: UsbInterface,
    val endpoint: UsbEndpoint,
    val statusEndpoint: UsbEndpoint?,
    val profile: UsbPrinterProfile,
)

private data class UsbPrintOptions(
    val printerKind: UsbPrinterKind = UsbPrinterKind.UNKNOWN,
    val godexGraphicNames: List<String> = emptyList(),
    val labelCount: Int = 1,
)

internal data class UsbPrintWriteResult(
    val bytes: Int,
    val printerStatus: String,
)

private data class GodexStatusOutcome(
    val ready: Boolean = false,
    val sawStatus: Boolean = false,
    val rawStatus: String = "",
    val errorCode: String? = null,
)

internal enum class UsbPrinterKind(val value: String) {
    GODEX("godex"),
    ZEBRA("zebra"),
    UNKNOWN("unknown");

    companion object {
        fun fromValue(value: String): UsbPrinterKind {
            return when (value.trim().lowercase(Locale.US)) {
                "godex", "go-dex", "g500" -> GODEX
                "zebra", "zpl", "rfid" -> ZEBRA
                else -> UNKNOWN
            }
        }
    }
}

internal data class UsbPrinterProfile(
    val kind: UsbPrinterKind,
    val manufacturerName: String,
    val productName: String,
) {
    fun response(device: UsbDevice): Map<String, Any> {
        return mapOf(
            "ok" to (kind != UsbPrinterKind.UNKNOWN),
            "printer" to kind.value,
            "print_mode" to if (kind == UsbPrinterKind.ZEBRA) "rfid" else "label",
            "rfid_epc_write" to (kind == UsbPrinterKind.ZEBRA),
            "deviceName" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
            "manufacturerName" to manufacturerName,
            "productName" to productName,
        )
    }

    companion object {
        fun fromDevice(device: UsbDevice): UsbPrinterProfile {
            val manufacturer = runCatching { device.manufacturerName.orEmpty() }.getOrDefault("")
            val product = runCatching { device.productName.orEmpty() }.getOrDefault("")
            return UsbPrinterProfile(
                kind = classifyUsbPrinter(
                    vendorId = device.vendorId,
                    productId = device.productId,
                    manufacturerName = manufacturer,
                    productName = product,
                ),
                manufacturerName = manufacturer,
                productName = product,
            )
        }
    }
}

internal fun classifyUsbPrinter(
    vendorId: Int,
    productId: Int,
    manufacturerName: String,
    productName: String,
): UsbPrinterKind {
    val descriptor = "$manufacturerName $productName".lowercase(Locale.US)
    if ((vendorId == 0x195f && productId == 0x0001) ||
        descriptor.contains("godex") || descriptor.contains("go-dex")
    ) {
        return UsbPrinterKind.GODEX
    }
    if (vendorId == 0x0a5f || descriptor.contains("zebra")) {
        return UsbPrinterKind.ZEBRA
    }
    return UsbPrinterKind.UNKNOWN
}

private data class PendingUsbPrint(
    val device: UsbDevice,
    val bytes: ByteArray,
    val result: MethodChannel.Result,
    val options: UsbPrintOptions = UsbPrintOptions(),
    val response: (UsbDevice, UsbPrintWriteResult) -> Map<String, Any>,
)

internal data class UsbRpsPrintRequest(
    val epc: String,
    val itemCode: String,
    val itemName: String,
    val warehouse: String,
    val printer: String,
    val printMode: String,
    val grossQty: Double,
    val unit: String,
    val tareEnabled: Boolean,
    val tareKg: Double,
    val printCount: Int,
    val labelKind: String = "",
) {
    fun response(device: UsbDevice, write: UsbPrintWriteResult): Map<String, Any> {
        val netQty = netQty()
        return mapOf(
            "ok" to true,
            "status" to "done",
            "epc" to epc,
            "item_code" to itemCode,
            "item_name" to itemName,
            "warehouse" to warehouse,
            "printer" to printer,
            "mode" to printMode,
            "qty" to netQty,
            "net_qty" to netQty,
            "gross_qty" to grossQty,
            "unit" to unit,
            "tare" to tareEnabled,
            "tare_kg" to tareKg,
            "printer_status" to write.printerStatus,
            "print_count" to printCount,
            "bytes" to write.bytes,
            "deviceName" to device.deviceName,
            "vendorId" to device.vendorId,
            "productId" to device.productId,
        )
    }

    fun netQty(): Double {
        return (grossQty - tareKg).coerceAtLeast(0.0)
    }

    companion object {
        fun fromCall(call: MethodCall): UsbRpsPrintRequest {
            val grossQty = call.argument<Number>("gross_qty")?.toDouble()
                ?.takeIf { it.isFinite() && it > 0.0 }
                ?: 1.0
            val tareKg = call.argument<Number>("tare_kg")?.toDouble()
                ?.takeIf { it.isFinite() && it > 0.0 }
                ?: 0.0
            val printCount = call.argument<Number>("print_count")?.toInt()
                ?.takeIf { it > 0 }
                ?: 1
            return UsbRpsPrintRequest(
                epc = clean(call.argument<String>("epc"), "RPS-USB-TEST").uppercase(Locale.US),
                itemCode = clean(call.argument<String>("item_code"), "USB-TEST"),
                itemName = clean(call.argument<String>("item_name"), "USB printer test"),
                warehouse = clean(call.argument<String>("warehouse"), "RPS USB TEST"),
                printer = clean(call.argument<String>("printer"), "godex").lowercase(Locale.US),
                printMode = clean(call.argument<String>("print_mode"), "label").lowercase(Locale.US),
                grossQty = grossQty,
                unit = clean(call.argument<String>("unit"), "kg").lowercase(Locale.US),
                tareEnabled = call.argument<Boolean>("tare_enabled") == true || tareKg > 0.0,
                tareKg = tareKg,
                printCount = printCount,
                labelKind = clean(call.argument<String>("label_kind"), "").lowercase(Locale.US),
            )
        }

        private fun clean(value: String?, fallback: String): String {
            return value.orEmpty().trim().ifBlank { fallback }
        }
    }
}
