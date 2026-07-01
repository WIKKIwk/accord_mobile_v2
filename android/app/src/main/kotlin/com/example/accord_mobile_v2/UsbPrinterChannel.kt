package com.example.accord_mobile_v2

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class UsbPrinterChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, "accord/usb_printer")
    private val usbManager = activity.getSystemService(Context.USB_SERVICE) as UsbManager
    private val actionUsbPermission = "${activity.packageName}.USB_PRINTER_PERMISSION"
    private var pendingPrint: PendingUsbPrint? = null
    private var permissionReceiver: BroadcastReceiver? = null

    init {
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "printTest" -> printTest(call, result)
            else -> result.notImplemented()
        }
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
        val request = PendingUsbPrint(printer.device, bytes, result)
        if (usbManager.hasPermission(printer.device)) {
            finishPrint(request)
            return
        }
        pendingPrint = request
        registerPermissionReceiver()
        usbManager.requestPermission(printer.device, permissionIntent())
    }

    private fun findPrinterCandidate(): UsbPrinterCandidate? {
        val devices = usbManager.deviceList.values.toList()
        val preferred = devices.firstNotNullOfOrNull { device ->
            printerCandidate(device, requirePrinterClass = true)
        }
        if (preferred != null) {
            return preferred
        }
        return devices.firstNotNullOfOrNull { device ->
            printerCandidate(device, requirePrinterClass = false)
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
            return UsbPrinterCandidate(device, usbInterface, endpoint)
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
        try {
            val candidate = printerCandidate(request.device, requirePrinterClass = false)
                ?: throw IllegalStateException("USB printer endpoint not found")
            val sent = writeBytes(candidate, request.bytes)
            request.result.success(
                mapOf(
                    "ok" to true,
                    "bytes" to sent,
                    "deviceName" to request.device.deviceName,
                    "vendorId" to request.device.vendorId,
                    "productId" to request.device.productId,
                ),
            )
        } catch (error: Throwable) {
            request.result.error(
                "usb_printer_write_failed",
                error.message ?: "USB printer write failed",
                null,
            )
        }
    }

    private fun writeBytes(candidate: UsbPrinterCandidate, bytes: ByteArray): Int {
        val connection = usbManager.openDevice(candidate.device)
            ?: throw IllegalStateException("USB device open failed")
        var claimed = false
        try {
            if (!connection.claimInterface(candidate.usbInterface, true)) {
                throw IllegalStateException("USB interface claim failed")
            }
            claimed = true
            var offset = 0
            while (offset < bytes.size) {
                val chunkSize = minOf(
                    candidate.endpoint.maxPacketSize.coerceAtLeast(64),
                    bytes.size - offset,
                )
                val sent = connection.bulkTransfer(
                    candidate.endpoint,
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
        } finally {
            if (claimed) {
                connection.releaseInterface(candidate.usbInterface)
            }
            connection.close()
        }
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
}

private data class UsbPrinterCandidate(
    val device: UsbDevice,
    val usbInterface: UsbInterface,
    val endpoint: UsbEndpoint,
)

private data class PendingUsbPrint(
    val device: UsbDevice,
    val bytes: ByteArray,
    val result: MethodChannel.Result,
)
