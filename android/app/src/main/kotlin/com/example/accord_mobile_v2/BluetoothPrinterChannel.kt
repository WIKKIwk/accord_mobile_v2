package com.example.accord_mobile_v2

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.posprinter.IDeviceConnection
import net.posprinter.POSConnect
import net.posprinter.TSPLConst
import net.posprinter.TSPLPrinter
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

class BluetoothPrinterChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    companion object {
        private const val TAG = "BluetoothPrinter"
        private const val PERMISSION_REQUEST_CODE = 4917
        private const val PRINT_TIMEOUT_MS = 25_000L
        private const val LABEL_WIDTH_MM = 56.0
        private const val LABEL_HEIGHT_MM = 60.0
        // XP-P323B is 203 dpi, so a 56 x 60 mm label is approximately
        // 448 x 480 dots. Keep a real margin on both edges instead of
        // relying on the printer's REFERENCE offset.
        private const val LABEL_WIDTH_DOTS = 448
        private const val LABEL_LEFT_MARGIN_DOTS = 24
        private const val LABEL_RIGHT_MARGIN_DOTS = 24
        private const val PACK_QR_X = 278
        private const val PACK_QR_Y = 166
        private const val PACK_EPC_Y = 328
        private const val LARGE_QR_X = 192
        private const val LARGE_QR_Y = 66
        private const val LARGE_QR_FOOTER_Y = 322
        private const val LABEL_CHARSET = "US-ASCII"
        private const val LABEL_CODE_PAGE = "0"
    }

    private val channel = MethodChannel(messenger, "accord/bluetooth_printer")
    private val mainHandler = Handler(Looper.getMainLooper())
    private val printBusy = AtomicBoolean(false)
    private var pendingPermissionAction: (() -> Unit)? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var activeConnection: IDeviceConnection? = null
    private var activeAddress = ""
    private var activePrintFailure: ((String, String) -> Unit)? = null

    init {
        POSConnect.init(activity.applicationContext)
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pairedPrinters" -> withBluetoothPermission(result) {
                pairedPrinters(result)
            }
            "printLabel" -> withBluetoothPermission(result) {
                printLabel(call, result)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return false
        }
        val action = pendingPermissionAction
        val result = pendingPermissionResult
        pendingPermissionAction = null
        pendingPermissionResult = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            action?.invoke()
        } else {
            result?.error(
                "bluetooth_permission_denied",
                "Bluetooth printer permission denied",
                permissions.toList(),
            )
        }
        return true
    }

    fun dispose() {
        activePrintFailure = null
        val connection = activeConnection
        activeConnection = null
        activeAddress = ""
        if (connection != null) {
            closeConnection(connection)
        }
        channel.setMethodCallHandler(null)
    }

    private fun withBluetoothPermission(
        result: MethodChannel.Result,
        action: () -> Unit,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            action()
            return
        }
        val requiredPermissions = arrayOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
        )
        if (requiredPermissions.all { permission ->
                ContextCompat.checkSelfPermission(
                    activity,
                    permission,
                ) == PackageManager.PERMISSION_GRANTED
            }
        ) {
            action()
            return
        }
        if (pendingPermissionAction != null) {
            result.error(
                "bluetooth_permission_busy",
                "Bluetooth permission request is already open",
                null,
            )
            return
        }
        pendingPermissionAction = action
        pendingPermissionResult = result
        activity.requestPermissions(
            requiredPermissions,
            PERMISSION_REQUEST_CODE,
        )
    }

    @Suppress("MissingPermission")
    private fun pairedPrinters(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter(result) ?: return
        val printers = adapter.bondedDevices
            .filter { isXpP323b(it.name.orEmpty()) }
            .sortedBy { it.name.orEmpty() }
            .map { device ->
                mapOf(
                    "name" to device.name.orEmpty(),
                    "address" to device.address.orEmpty(),
                )
            }
        result.success(printers)
    }

    @Suppress("MissingPermission")
    private fun printLabel(call: MethodCall, result: MethodChannel.Result) {
        bluetoothAdapter(result) ?: return
        if (!printBusy.compareAndSet(false, true)) {
            result.error(
                "bluetooth_printer_busy",
                "XP-P323B print is already in progress",
                null,
            )
            return
        }
        val address = call.argument<String>("mac_address").orEmpty().trim()
        val label = BluetoothLabelRequest.from(call)
        if (label == null) {
            printBusy.set(false)
            result.error(
                "bluetooth_print_invalid_payload",
                "XP-P323B label payload is invalid",
                null,
            )
            return
        }
        if (address.isEmpty()) {
            printBusy.set(false)
            result.error("bluetooth_printer_not_selected", "XP-P323B printer is not selected", null)
            return
        }

        val completed = AtomicBoolean(false)
        val sendStarted = AtomicBoolean(false)
        val existing = activeConnection
        val connection = if (
            existing != null &&
            activeAddress == address &&
            existing.isConnect
        ) {
            existing
        } else {
            disconnectActiveConnection()
            POSConnect.createDevice(POSConnect.DEVICE_TYPE_BLUETOOTH).also {
                activeConnection = it
                activeAddress = address
            }
        }
        val timeout = Runnable {
            finishError(
                completed,
                connection,
                result,
                "bluetooth_print_timeout",
                "XP-P323B Bluetooth connection or write timed out",
            )
        }
        mainHandler.postDelayed(timeout, PRINT_TIMEOUT_MS)

        activePrintFailure = { code, message ->
            finishError(completed, connection, result, code, message)
        }

        fun sendWithSdk() {
            if (!sendStarted.compareAndSet(false, true) || completed.get()) {
                return
            }
            try {
                connection.setSendCallback { sentBytes ->
                    if (sentBytes > 0) {
                        finishSuccess(
                            completed,
                            connection,
                            result,
                            sentBytes,
                            address,
                            label.printCount,
                        )
                    } else {
                        finishError(
                            completed,
                            connection,
                            result,
                            "bluetooth_send_failed",
                            "XP-P323B Bluetooth write failed",
                        )
                    }
                }
                val printer = TSPLPrinter(connection)
                buildSdkLabel(printer, label)
                printer.print(label.printCount)
            } catch (error: Exception) {
                Log.e(TAG, "XP-P323B SDK print failed", error)
                finishError(
                    completed,
                    connection,
                    result,
                    "bluetooth_print_failed",
                    error.message?.takeIf { it.isNotBlank() }
                        ?: "XP-P323B SDK print failed",
                )
            }
        }

        if (connection.isConnect) {
            sendWithSdk()
            return
        }

        connection.connect(address) { code, _, message ->
            when (code) {
                POSConnect.CONNECT_SUCCESS -> sendWithSdk()
                POSConnect.CONNECT_FAIL -> handleConnectionFailure(
                    connection,
                    "bluetooth_connect_failed",
                    message.ifBlank { "XP-P323B Bluetooth connection failed" },
                )
                POSConnect.SEND_FAIL -> handleConnectionFailure(
                    connection,
                    "bluetooth_send_failed",
                    message.ifBlank { "XP-P323B Bluetooth send failed" },
                )
                POSConnect.CONNECT_INTERRUPT,
                POSConnect.BLUETOOTH_INTERRUPT,
                -> handleConnectionFailure(
                    connection,
                    "bluetooth_print_interrupted",
                    message.ifBlank { "XP-P323B Bluetooth connection interrupted" },
                )
            }
        }
    }

    private fun buildSdkLabel(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        printer.setCharSet(LABEL_CHARSET)
        printer
            .sizeMm(LABEL_WIDTH_MM, LABEL_HEIGHT_MM)
            .speed(4.0)
            .density(10)
            .direction(TSPLConst.DIRECTION_FORWARD)
            .reference(0, 0)
            .cls()
            .codePage(LABEL_CODE_PAGE)

        when {
            label.isQolipCell -> printQolipCell(printer, label)
            label.isQolipCode || label.isMaterialProduct -> printLargeQr(printer, label)
            else -> printPackLabel(printer, label)
        }
    }

    private fun printQolipCell(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        val name = cleanLabelText(
            label.itemName.ifBlank { label.itemCode },
        )
        val payload = requiredPayload(label.epc)
        val title = fitLabelText(name, 18)
        val titleX = ((400 - title.length * 24) / 2).coerceIn(8, 392)
        sdkText(printer, titleX, 12, TSPLConst.FNT_16_24, title)
        sdkQr(printer, 68, 82, payload, cellSize = 8)
    }

    private fun printLargeQr(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        val payload = requiredPayload(label.epc)
        val rawTitle = if (label.isMaterialProduct) {
            materialProductTitle(label)
        } else {
            label.itemName.ifBlank { label.itemCode }
        }
        val titleLines = wrapLabelText(cleanLabelText(rawTitle), 25).take(2)
        titleLines.forEachIndexed { index, line ->
            sdkText(
                printer,
                LABEL_LEFT_MARGIN_DOTS,
                6 + index * 26,
                TSPLConst.FNT_12_20,
                line,
            )
        }
        sdkQr(printer, LARGE_QR_X, LARGE_QR_Y, payload, cellSize = 8)
        val footer = fitLabelText(
            largeQrFooter(label, payload),
            if (label.isMaterialProduct) 32 else 46,
        )
        val footerFont = if (label.isMaterialProduct && footer.length <= 32) {
            TSPLConst.FNT_12_20
        } else {
            TSPLConst.FNT_8_12
        }
        val footerX = if (label.isMaterialProduct) {
            centeredLabelX(footer, if (footerFont == TSPLConst.FNT_12_20) 12 else 8)
        } else {
            LABEL_LEFT_MARGIN_DOTS
        }
        sdkText(
            printer,
            footerX,
            LARGE_QR_FOOTER_Y,
            footerFont,
            footer,
        )
    }

    private fun printPackLabel(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        val payload = requiredPayload(label.epc)
        val product = cleanLabelText(label.itemName.ifBlank { label.itemCode })
        val productLines = wrapLabelText(product, 24).take(3)
        val quantityUnit = cleanLabelText(
            if (label.isProgress && label.progressUnit.isNotBlank()) {
                label.progressUnit
            } else {
                label.unit.ifBlank { "kg" }
            },
        )
        val grossUnit = cleanLabelText(label.unit.ifBlank { "kg" })
        val quantityLabel = if (label.isProgress) "METRAJ" else "NETTO"
        val quantity = if (label.isProgress) {
            label.progressQty ?: label.netQty
        } else {
            label.netQty
        }

        sdkText(
            printer,
            LABEL_LEFT_MARGIN_DOTS,
            4,
            TSPLConst.FNT_16_24,
            "ACCORD",
        )
        productLines.forEachIndexed { index, line ->
            sdkText(
                printer,
                LABEL_LEFT_MARGIN_DOTS,
                34 + index * 24,
                TSPLConst.FNT_12_20,
                line,
            )
        }
        sdkText(
            printer,
            LABEL_LEFT_MARGIN_DOTS,
            112,
            TSPLConst.FNT_12_20,
            "$quantityLabel: ${formatLabelQty(quantity)} $quantityUnit",
        )
        sdkText(
            printer,
            LABEL_LEFT_MARGIN_DOTS,
            138,
            TSPLConst.FNT_12_20,
            "BRUTTO: ${formatLabelQty(label.grossQty)} $grossUnit",
        )
        sdkQr(printer, PACK_QR_X, PACK_QR_Y, payload, cellSize = 5)
        val epcFont = if (payload.length <= 32) {
            TSPLConst.FNT_12_20
        } else {
            TSPLConst.FNT_8_12
        }
        val epcText = fitLabelText(payload, if (epcFont == TSPLConst.FNT_12_20) 32 else 46)
        sdkText(
            printer,
            centeredLabelX(epcText, if (epcFont == TSPLConst.FNT_12_20) 12 else 8),
            PACK_EPC_Y,
            epcFont,
            epcText,
        )
    }

    private fun sdkText(
        printer: TSPLPrinter,
        x: Int,
        y: Int,
        font: String,
        value: String,
    ) {
        printer.text(
            x,
            y,
            font,
            TSPLConst.ROTATION_0,
            1,
            1,
            cleanLabelText(value),
        )
    }

    private fun sdkQr(
        printer: TSPLPrinter,
        x: Int,
        y: Int,
        value: String,
        cellSize: Int,
    ) {
        printer.qrcode(
            x,
            y,
            TSPLConst.EC_LEVEL_H,
            cellSize,
            TSPLConst.QRCODE_MODE_AUTO,
            TSPLConst.ROTATION_0,
            TSPLConst.QRCODE_MODEL_M2,
            "S7",
            value,
        )
    }

    private fun requiredPayload(value: String): String {
        return cleanLabelText(value).takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("XP-P323B QR payload is empty")
    }

    private fun materialProductTitle(label: BluetoothLabelRequest): String {
        val name = label.itemName.ifBlank { label.itemCode }
        val unit = label.unit.ifBlank { "kg" }
        val net = compactLabelQty(label.netQty)
        return if (label.tareEnabled && label.tareKg > 0) {
            "$name  B:${compactLabelQty(label.grossQty)} $unit N:$net $unit"
        } else {
            "$name  $net $unit"
        }
    }

    private fun largeQrFooter(
        label: BluetoothLabelRequest,
        payload: String,
    ): String {
        val value = when {
            label.isMaterialProduct -> payload
            label.isQolipCode && payload.startsWith("RPS-BATCH:") ->
                "BATCH ID: ${payload.removePrefix("RPS-BATCH:")}"
            label.itemCode.isNotBlank() -> label.itemCode
            else -> payload
        }
        return cleanLabelText(value)
    }

    private fun centeredLabelX(value: String, charWidth: Int): Int {
        val availableWidth = LABEL_WIDTH_DOTS -
            LABEL_LEFT_MARGIN_DOTS - LABEL_RIGHT_MARGIN_DOTS
        val textWidth = (value.length * charWidth).coerceAtMost(availableWidth)
        val maxX = LABEL_WIDTH_DOTS - LABEL_RIGHT_MARGIN_DOTS - textWidth
        return ((LABEL_WIDTH_DOTS - textWidth) / 2)
            .coerceIn(LABEL_LEFT_MARGIN_DOTS, maxX)
    }

    private fun cleanLabelText(value: String): String {
        return value
            .replace('‘', '\'')
            .replace('’', '\'')
            .replace('`', '\'')
            .replace('"', '\'')
            .replace(Regex("[\\r\\n\\t]+"), " ")
            .trim()
            .uppercase(Locale.US)
            .replace(Regex("\\s+"), " ")
    }

    private fun fitLabelText(value: String, maxLength: Int): String {
        return if (value.length <= maxLength) value else value.take(maxLength)
    }

    private fun wrapLabelText(value: String, width: Int): List<String> {
        val lines = mutableListOf<String>()
        var current = ""
        value.split(Regex("\\s+")).filter { it.isNotEmpty() }.forEach { word ->
            var rest = word
            while (rest.length > width) {
                if (current.isNotEmpty()) {
                    lines += current
                    current = ""
                }
                lines += rest.take(width)
                rest = rest.drop(width)
            }
            val candidate = if (current.isEmpty()) rest else "$current $rest"
            if (candidate.length <= width) {
                current = candidate
            } else {
                lines += current
                current = rest
            }
        }
        if (current.isNotEmpty()) {
            lines += current
        }
        return lines
    }

    private fun formatLabelQty(value: Double): String {
        val rounded = (value * 10).roundToInt() / 10.0
        return if (rounded == rounded.toInt().toDouble()) {
            rounded.toInt().toString()
        } else {
            String.format(Locale.US, "%.1f", rounded)
        }
    }

    private fun compactLabelQty(value: Double): String {
        return String.format(Locale.US, "%.3f", value)
            .trimEnd('0')
            .trimEnd('.')
    }

    @Suppress("MissingPermission")
    private fun bluetoothAdapter(result: MethodChannel.Result) =
        (activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)
            ?.adapter
            ?.also { adapter ->
                if (!adapter.isEnabled) {
                    result.error(
                        "bluetooth_disabled",
                        "Android Bluetooth is turned off",
                        null,
                    )
                    return null
                }
            }
            ?: run {
                result.error(
                    "bluetooth_unavailable",
                    "Android Bluetooth is not available",
                    null,
                )
                null
            }

    private fun finishSuccess(
        completed: AtomicBoolean,
        connection: IDeviceConnection,
        result: MethodChannel.Result,
        bytes: Int,
        address: String,
        labelCount: Int,
    ) {
        if (!completed.compareAndSet(false, true)) {
            return
        }
        mainHandler.removeCallbacksAndMessages(null)
        if (activeConnection === connection) {
            activePrintFailure = null
        }
        printBusy.set(false)
        activity.runOnUiThread {
            result.success(
                mapOf(
                    "ok" to true,
                    "status" to "done",
                    "bytes" to bytes,
                    "deviceName" to "XP-P323B",
                    "address" to address,
                    "label_count" to labelCount,
                    "printer_status" to "Bluetooth OK",
                ),
            )
        }
    }

    private fun finishError(
        completed: AtomicBoolean,
        connection: IDeviceConnection,
        result: MethodChannel.Result,
        code: String,
        message: String,
    ) {
        if (!completed.compareAndSet(false, true)) {
            return
        }
        mainHandler.removeCallbacksAndMessages(null)
        if (activeConnection === connection) {
            activeConnection = null
            activeAddress = ""
            activePrintFailure = null
        }
        closeConnection(connection)
        printBusy.set(false)
        activity.runOnUiThread {
            result.error(code, message, null)
        }
    }

    private fun handleConnectionFailure(
        connection: IDeviceConnection,
        code: String,
        message: String,
    ) {
        if (activeConnection !== connection) {
            return
        }
        val failure = activePrintFailure
        if (failure != null) {
            failure(code, message)
            return
        }
        activeConnection = null
        activeAddress = ""
        closeConnection(connection)
    }

    private fun disconnectActiveConnection() {
        val connection = activeConnection
        activeConnection = null
        activeAddress = ""
        activePrintFailure = null
        if (connection != null) {
            closeConnection(connection)
        }
    }

    private fun closeConnection(connection: IDeviceConnection) {
        try {
            connection.close()
        } catch (error: Exception) {
            Log.w(TAG, "XP-P323B Bluetooth close failed", error)
        }
    }

    private fun isXpP323b(name: String): Boolean {
        return name.uppercase().replace("-", "").replace("_", "").replace(" ", "")
            .contains("XPP323B") || name.uppercase().contains("P323B")
    }
}

private data class BluetoothLabelRequest(
    val epc: String,
    val itemCode: String,
    val itemName: String,
    val grossQty: Double,
    val unit: String,
    val tareEnabled: Boolean,
    val tareKg: Double,
    val printCount: Int,
    val labelKind: String,
    val progressQty: Double?,
    val progressUnit: String,
) {
    val netQty: Double
        get() = (grossQty - tareKg).coerceAtLeast(0.0)

    val isProgress: Boolean
        get() = labelKind == "progress"

    val isQolipCell: Boolean
        get() = labelKind == "qolip_cell" || labelKind == "qr_center"

    val isQolipCode: Boolean
        get() = labelKind == "qolip_code"

    val isMaterialProduct: Boolean
        get() = labelKind == "material_product"

    companion object {
        fun from(call: MethodCall): BluetoothLabelRequest? {
            val epc = call.argument<String>("epc").orEmpty().trim()
            val grossQty = call.argument<Number>("gross_qty")?.toDouble() ?: 0.0
            val tareKg = call.argument<Number>("tare_kg")?.toDouble() ?: 0.0
            val printCount = call.argument<Number>("print_count")?.toInt() ?: 1
            if (epc.isEmpty() || !grossQty.isFinite() || !tareKg.isFinite() ||
                printCount !in 1..100
            ) {
                return null
            }
            return BluetoothLabelRequest(
                epc = epc,
                itemCode = call.argument<String>("item_code").orEmpty().trim(),
                itemName = call.argument<String>("item_name").orEmpty().trim(),
                grossQty = grossQty.coerceAtLeast(0.0),
                unit = call.argument<String>("unit").orEmpty().trim().ifBlank { "kg" },
                tareEnabled = call.argument<Boolean>("tare_enabled") == true || tareKg > 0,
                tareKg = tareKg.coerceAtLeast(0.0),
                printCount = printCount,
                labelKind = call.argument<String>("label_kind")
                    .orEmpty()
                    .trim()
                    .lowercase(Locale.US),
                progressQty = call.argument<Number>("progress_qty")?.toDouble()
                    ?.takeIf { it.isFinite() },
                progressUnit = call.argument<String>("progress_unit").orEmpty().trim(),
            )
        }
    }
}
