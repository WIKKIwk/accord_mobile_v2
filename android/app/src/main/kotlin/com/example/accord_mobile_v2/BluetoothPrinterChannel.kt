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
import java.io.ByteArrayOutputStream
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
        // 448 x 480 dots. The printer's physical label origin is a few
        // dots left of the adhesive label, so compensate it at the TSPL
        // origin rather than moving individual objects independently.
        private const val LABEL_WIDTH_DOTS = 448
        private const val LABEL_HEIGHT_DOTS = 480
        private const val LABEL_REFERENCE_X_DOTS = 72
        private const val LABEL_LEFT_MARGIN_DOTS = 24
        private const val LABEL_RIGHT_MARGIN_DOTS = 24
        private const val DEFAULT_PRINT_DENSITY = 10
        private const val MATERIAL_PRINT_DENSITY = 12
        private const val MATERIAL_TEXT_BOLD_OFFSET_DOTS = 1
        private const val MATERIAL_TITLE_WIDTH_CHARS = 28
        private const val MATERIAL_TITLE_TOP_Y = 6
        private const val MATERIAL_TITLE_LINE_HEIGHT_DOTS = 26
        private const val MATERIAL_TITLE_FONT_HEIGHT_DOTS = 19
        private const val MATERIAL_TITLE_QR_GAP_DOTS = 8
        private const val PACK_QR_X = 278
        private const val PACK_QR_Y = 166
        private const val PACK_EPC_Y = 328
        private const val PROGRESS_PACK_QR_X = 250
        private const val PROGRESS_PACK_QR_Y = 285
        private const val PROGRESS_PACK_EPC_GAP_DOTS = 16
        private const val PROGRESS_TEXT_CHAR_WIDTH_DOTS = 16
        private const val PROGRESS_TEXT_LINE_HEIGHT_DOTS = 24
        private const val PROGRESS_TEXT_TOP_Y = 36
        private const val PROGRESS_FIELD_GAP_DOTS = 4
        private const val PROGRESS_BOLD_OFFSET_DOTS = 1
        private const val PROGRESS_FIELD_WIDTH_CHARS = 24
        // FNT_12_20 is rendered slightly wider by XP-P323B than its name
        // suggests. Use a conservative width estimate for wrapping. The
        // actual field line is emitted as one string so the printer itself
        // owns the single-space separation after the colon.
        private const val QOLIP_FIELD_CHAR_WIDTH_DOTS = 16
        private const val QOLIP_FIELD_LINE_HEIGHT_DOTS = 24
        private const val QOLIP_FIELD_TOP_Y = 24
        private const val QOLIP_FIELD_ROW_GAP_DOTS = 8
        private const val QOLIP_FIELD_QR_GAP_DOTS = 16
        private const val LARGE_QR_FOOTER_GAP_DOTS = 28
        private const val LARGE_QR_FOOTER_LEFT_SHIFT_DOTS = 16
        private const val LARGE_QR_FOOTER_HEIGHT_DOTS = 24
        private const val QR_ALPHANUMERIC = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
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
                val printer = CapturingTsplPrinter(connection)
                buildSdkLabel(printer, label)
                printer.print(label.printCount)
                val payload = printer.payload()
                if (payload.isEmpty()) {
                    finishError(
                        completed,
                        connection,
                        result,
                        "bluetooth_print_failed",
                        "XP-P323B SDK produced an empty TSPL payload",
                    )
                    return
                }
                val sentBytes = connection.sendSync(payload)
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
                        "XP-P323B Bluetooth write failed (status=$sentBytes)",
                    )
                }
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
            .density(
                if (label.isMaterialProduct) {
                    MATERIAL_PRINT_DENSITY
                } else {
                    DEFAULT_PRINT_DENSITY
                },
            )
            .direction(TSPLConst.DIRECTION_FORWARD)
            .reference(LABEL_REFERENCE_X_DOTS, 0)
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
        val title = fitLabelText(name, 16)
        val titleX = centeredLabelX(title, charWidth = 24)
        sdkText(printer, titleX, 12, TSPLConst.FNT_16_24, title)
        val cellSize = largeQrCellSize(payload)
        sdkQr(
            printer,
            centeredQrX(payload, cellSize),
            centeredQrY(payload, cellSize),
            payload,
            cellSize = cellSize,
        )
    }

    private fun printLargeQr(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        val payload = requiredPayload(label.epc)
        val rawTitle = label.itemName.ifBlank { label.itemCode }
        val titleLines = largeQrTitleLines(label, rawTitle)
        val titleFont = if (label.isMaterialProduct) {
            TSPLConst.FNT_14_19
        } else {
            TSPLConst.FNT_12_20
        }
        val cellSize = if (label.isMaterialProduct) {
            materialQrCellSize(payload)
        } else {
            largeQrCellSize(payload)
        }
        val qrX = centeredQrX(payload, cellSize)
        val qrSize = qrSymbolSizeDots(payload, cellSize)
        val baseQrY = centeredQrY(payload, cellSize)
        val latestQrY = (LABEL_HEIGHT_DOTS - qrSize -
            LARGE_QR_FOOTER_GAP_DOTS - LARGE_QR_FOOTER_HEIGHT_DOTS)
            .coerceAtLeast(baseQrY)
        val qrY = when {
            label.isQolipProductCode -> {
                val requestedQrY = qolipFieldsEndY(label, rawTitle) +
                    QOLIP_FIELD_QR_GAP_DOTS
                requestedQrY.coerceIn(baseQrY, latestQrY)
            }
            label.isMaterialProduct -> {
                val titleEndY = MATERIAL_TITLE_TOP_Y +
                    (titleLines.size - 1).coerceAtLeast(0) *
                    MATERIAL_TITLE_LINE_HEIGHT_DOTS + MATERIAL_TITLE_FONT_HEIGHT_DOTS
                val requestedQrY = titleEndY + MATERIAL_TITLE_QR_GAP_DOTS
                requestedQrY.coerceIn(baseQrY, latestQrY)
            }
            else -> baseQrY
        }
        if (label.isQolipProductCode) {
            var fieldY = QOLIP_FIELD_TOP_Y
            fieldY = printQolipField(
                printer,
                fieldY,
                "MIJOZ",
                label.customerName,
            )
            fieldY = printQolipField(
                printer,
                fieldY,
                "MAHSULOT NOMI",
                rawTitle,
            )
            printQolipField(
                printer,
                fieldY,
                "QOLIP RANGI",
                label.qolipColor,
            )
        } else {
            titleLines.forEachIndexed { index, line ->
                val titleX = LABEL_LEFT_MARGIN_DOTS
                val titleY = if (label.isMaterialProduct) {
                    MATERIAL_TITLE_TOP_Y + index * MATERIAL_TITLE_LINE_HEIGHT_DOTS
                } else {
                    6 + index * 26
                }
                if (label.isMaterialProduct) {
                    sdkText(printer, titleX, titleY, titleFont, line)
                    sdkText(
                        printer,
                        titleX + MATERIAL_TEXT_BOLD_OFFSET_DOTS,
                        titleY,
                        titleFont,
                        line,
                    )
                } else {
                    sdkText(printer, titleX, titleY, titleFont, line)
                }
            }
        }
        sdkQr(
            printer,
            qrX,
            qrY,
            payload,
            cellSize = cellSize,
        )
        if (label.isQolipProductCode) {
            printQolipField(
                printer,
                centeredQrFooterY(qrY, qrSize),
                "EPC",
                payload,
            )
            return
        }
        val footer = fitLabelText(
            largeQrFooter(label, payload),
            if (label.isMaterialProduct) 32 else 46,
        )
        val footerIsLarge =
            (label.isMaterialProduct || label.isQolipCode) && footer.length <= 32
        val footerFont = if (footerIsLarge) {
            TSPLConst.FNT_12_20
        } else {
            TSPLConst.FNT_8_12
        }
        val footerX = if (label.isMaterialProduct || label.isQolipCode) {
            (centeredLabelX(footer, if (footerIsLarge) 12 else 8) -
                LARGE_QR_FOOTER_LEFT_SHIFT_DOTS)
                .coerceAtLeast(LABEL_LEFT_MARGIN_DOTS)
        } else {
            LABEL_LEFT_MARGIN_DOTS
        }
        sdkText(
            printer,
            footerX,
            centeredQrFooterY(qrY, qrSize),
            footerFont,
            footer,
        )
    }

    private fun printPackLabel(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        if (label.isProgress) {
            printProgressPackLabel(printer, label)
            return
        }
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
        sdkQr(
            printer,
            PACK_QR_X,
            PACK_QR_Y,
            payload,
            cellSize = packQrCellSize(payload),
        )
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

    private fun printProgressPackLabel(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        val payload = requiredPayload(label.epc)
        val customer = cleanLabelText(label.customerName.ifBlank { "-" })
        val rawProduct = cleanLabelText(
            label.itemName.ifBlank { label.itemCode }.ifBlank { "-" },
        )
        val product = progressProductName(rawProduct, label.itemCode)
        val apparatus = progressApparatusName(label.apparatus, rawProduct)
        val status = progressStatusLabel(rawProduct)
        var y = PROGRESS_TEXT_TOP_Y
        y = printProgressField(printer, y, "MIJOZ", customer, maxLines = 2)
        y = printProgressField(printer, y, "MAHSULOT NOMI", product, maxLines = 3)
        y = printProgressField(printer, y, "APARAT", apparatus, maxLines = 2)
        y += PROGRESS_FIELD_GAP_DOTS * 2
        y = printProgressField(
            printer,
            y,
            "HOLAT",
            status,
            maxLines = 2,
        )
        y += PROGRESS_FIELD_GAP_DOTS

        val meterUnit = cleanLabelText(label.progressUnit.ifBlank { "m" })
        val weightUnit = cleanLabelText(label.unit.ifBlank { "kg" })
        y = printProgressField(
            printer,
            y,
            "METRAJ",
            "${formatLabelQty(label.progressQty ?: label.netQty)} $meterUnit",
        )
        y = printProgressField(
            printer,
            y,
            "NETTO",
            "${formatLabelQty(label.netQty)} $weightUnit",
        )
        printProgressField(
            printer,
            y,
            "BRUTTO",
            "${formatLabelQty(label.grossQty)} $weightUnit",
        )

        val qrCellSize = packQrCellSize(payload)
        val qrSize = qrSymbolSizeDots(payload, qrCellSize)
        val epcY = (PROGRESS_PACK_QR_Y + qrSize + PROGRESS_PACK_EPC_GAP_DOTS)
            .coerceAtMost(LABEL_HEIGHT_DOTS - 24)
        sdkQr(
            printer,
            PROGRESS_PACK_QR_X,
            PROGRESS_PACK_QR_Y,
            payload,
            cellSize = qrCellSize,
        )
        val epcFont = if (payload.length <= 32) {
            TSPLConst.FNT_12_20
        } else {
            TSPLConst.FNT_8_12
        }
        val epcText = fitLabelText(payload, if (epcFont == TSPLConst.FNT_12_20) 32 else 46)
        sdkText(
            printer,
            centeredLabelX(epcText, if (epcFont == TSPLConst.FNT_12_20) 12 else 8),
            epcY,
            epcFont,
            epcText,
        )
    }

    private fun printProgressField(
        printer: TSPLPrinter,
        y: Int,
        fieldLabel: String,
        value: String,
        maxLines: Int = 1,
    ): Int {
        val lines = progressFieldLines(fieldLabel, value, maxLines)
        lines.forEachIndexed { index, line ->
            sdkProgressLine(printer, y + index * PROGRESS_TEXT_LINE_HEIGHT_DOTS, line)
        }
        return y + lines.size * PROGRESS_TEXT_LINE_HEIGHT_DOTS + PROGRESS_FIELD_GAP_DOTS
    }

    private fun progressFieldLines(
        fieldLabel: String,
        value: String,
        maxLines: Int,
    ): List<String> {
        return wrapLabelText(
            "$fieldLabel: ${value.trim().ifBlank { "-" }}",
            PROGRESS_FIELD_WIDTH_CHARS,
        ).take(maxLines.coerceAtLeast(1))
    }

    private fun sdkProgressLine(
        printer: TSPLPrinter,
        y: Int,
        line: String,
    ) {
        val separator = line.indexOf(':')
        if (separator < 0) {
            sdkBoldText(printer, LABEL_LEFT_MARGIN_DOTS, y, line)
            return
        }
        val labelPart = line.take(separator + 1)
        val valuePart = line.drop(separator + 1).trimStart()
        sdkText(
            printer,
            LABEL_LEFT_MARGIN_DOTS,
            y,
            TSPLConst.FNT_16_24,
            labelPart,
        )
        if (valuePart.isNotEmpty()) {
            sdkBoldText(
                printer,
                LABEL_LEFT_MARGIN_DOTS +
                    (labelPart.length + 1) * PROGRESS_TEXT_CHAR_WIDTH_DOTS,
                y,
                valuePart,
            )
        }
    }

    private fun sdkBoldText(
        printer: TSPLPrinter,
        x: Int,
        y: Int,
        value: String,
        font: String = TSPLConst.FNT_16_24,
    ) {
        sdkText(printer, x, y, font, value)
        sdkText(
            printer,
            x + PROGRESS_BOLD_OFFSET_DOTS,
            y,
            font,
            value,
        )
    }

    private fun printQolipField(
        printer: TSPLPrinter,
        y: Int,
        fieldLabel: String,
        value: String,
    ): Int {
        val labelPart = "$fieldLabel: "
        val displayValue = cleanLabelText(value).ifBlank { "-" }
        val fullLineChars = ((LABEL_WIDTH_DOTS - LABEL_LEFT_MARGIN_DOTS -
            LABEL_RIGHT_MARGIN_DOTS) / QOLIP_FIELD_CHAR_WIDTH_DOTS).coerceAtLeast(1)
        val inlineFits = displayValue.length + labelPart.length <= fullLineChars
        val valueLines = wrapLabelText(displayValue, fullLineChars)
        if (inlineFits) {
            sdkText(
                printer,
                LABEL_LEFT_MARGIN_DOTS,
                y,
                TSPLConst.FNT_12_20,
                "$labelPart$displayValue",
            )
        } else {
            sdkText(
                printer,
                LABEL_LEFT_MARGIN_DOTS,
                y,
                TSPLConst.FNT_12_20,
                labelPart,
            )
            valueLines.forEachIndexed { index, line ->
                sdkBoldText(
                    printer,
                    LABEL_LEFT_MARGIN_DOTS,
                    y + QOLIP_FIELD_LINE_HEIGHT_DOTS * (index + 1),
                    line,
                    font = TSPLConst.FNT_12_20,
                )
            }
        }
        val lineCount = if (inlineFits) 1 else valueLines.size + 1
        return y + QOLIP_FIELD_LINE_HEIGHT_DOTS * lineCount +
            QOLIP_FIELD_ROW_GAP_DOTS
    }

    private fun qolipFieldsEndY(
        label: BluetoothLabelRequest,
        rawTitle: String,
    ): Int {
        var y = QOLIP_FIELD_TOP_Y
        y = qolipFieldNextY(y, "MIJOZ", label.customerName)
        y = qolipFieldNextY(y, "MAHSULOT NOMI", rawTitle)
        return qolipFieldNextY(y, "QOLIP RANGI", label.qolipColor)
    }

    private fun qolipFieldNextY(
        y: Int,
        fieldLabel: String,
        value: String,
    ): Int {
        val labelPart = "$fieldLabel: "
        val displayValue = cleanLabelText(value).ifBlank { "-" }
        val fullLineChars = ((LABEL_WIDTH_DOTS - LABEL_LEFT_MARGIN_DOTS -
            LABEL_RIGHT_MARGIN_DOTS) / QOLIP_FIELD_CHAR_WIDTH_DOTS).coerceAtLeast(1)
        val inlineFits = displayValue.length + labelPart.length <= fullLineChars
        val valueLineCount = if (inlineFits) {
            1
        } else {
            wrapLabelText(displayValue, fullLineChars).size + 1
        }
        return y + QOLIP_FIELD_LINE_HEIGHT_DOTS * valueLineCount +
            QOLIP_FIELD_ROW_GAP_DOTS
    }

    private fun progressProductName(itemName: String, fallback: String): String {
        val value = cleanLabelText(itemName.ifBlank { fallback }.ifBlank { "-" })
        val markers = listOf(
            " YARIM TAYYOR MAHSULOT",
            " YARIM TAYYOR",
            " TAYYOR MAHSULOT",
            ", APPARAT:",
            ", REZKA HOLATDA",
        )
        val cutAt = markers.mapNotNull { marker ->
            value.indexOf(marker, ignoreCase = true).takeIf { it > 0 }
        }.minOrNull()
        return (if (cutAt == null) value else value.take(cutAt))
            .trim()
            .trimEnd(',', '-', ' ')
            .ifBlank { value }
    }

    private fun progressStatusLabel(itemName: String): String {
        return when {
            itemName.contains("YARIM TAYYOR", ignoreCase = true) ->
                "YARIM TAYYOR MAHSULOT"
            itemName.contains("TAYYOR MAHSULOT", ignoreCase = true) ->
                "TAYYOR MAHSULOT"
            itemName.contains("TAYYOR", ignoreCase = true) ->
                "TAYYOR MAHSULOT"
            else -> "YARIM TAYYOR MAHSULOT"
        }
    }

    private fun progressApparatusName(apparatus: String, itemName: String): String {
        val explicit = cleanLabelText(apparatus).trim()
        if (explicit.isNotEmpty()) {
            return explicit
        }
        val marker = ", APPARAT:"
        val markerStart = itemName.indexOf(marker, ignoreCase = true)
        if (markerStart < 0) {
            return "-"
        }
        val valueStart = markerStart + marker.length
        return itemName.substring(valueStart)
            .substringBefore(',')
            .trim()
            .ifBlank { "-" }
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

    private fun largeQrCellSize(value: String): Int {
        return when {
            value.length <= 32 -> 8
            value.length <= 46 -> 7
            else -> 6
        }
    }

    private fun materialQrCellSize(value: String): Int {
        return (largeQrCellSize(value) + 1).coerceAtMost(9)
    }

    private fun centeredQrX(value: String, cellSize: Int): Int {
        val qrSize = qrSymbolSizeDots(value, cellSize)
        return ((LABEL_WIDTH_DOTS - qrSize) / 2).coerceAtLeast(0)
    }

    private fun centeredQrY(value: String, cellSize: Int): Int {
        val qrSize = qrSymbolSizeDots(value, cellSize)
        return ((LABEL_HEIGHT_DOTS - qrSize) / 2).coerceAtLeast(0)
    }

    private fun qrSymbolSizeDots(value: String, cellSize: Int): Int {
        return qrModuleCount(value) * cellSize
    }

    private fun qrModuleCount(value: String): Int {
        val normalized = value.uppercase(Locale.US)
        val dataLength = normalized.toByteArray(Charsets.US_ASCII).size
        val capacities = when {
            normalized.all { it.isDigit() } ->
                intArrayOf(17, 34, 58, 82, 106, 139, 154, 202, 235, 288)
            normalized.all { QR_ALPHANUMERIC.contains(it) } ->
                intArrayOf(10, 20, 35, 50, 64, 84, 93, 122, 143, 174)
            else ->
                intArrayOf(7, 14, 24, 34, 44, 58, 64, 84, 98, 119)
        }
        val version = capacities.indexOfFirst { dataLength <= it }
            .let { if (it >= 0) it + 1 else capacities.size }
        return 17 + version * 4
    }

    private fun centeredQrFooterY(qrY: Int, qrSize: Int): Int {
        return (qrY + qrSize + LARGE_QR_FOOTER_GAP_DOTS).coerceAtMost(
            LABEL_HEIGHT_DOTS - LARGE_QR_FOOTER_HEIGHT_DOTS,
        )
    }

    private fun packQrCellSize(value: String): Int {
        return if (value.length <= 32) 5 else 4
    }

    private fun largeQrTitleLines(
        label: BluetoothLabelRequest,
        rawTitle: String,
    ): List<String> {
        if (label.isMaterialProduct) {
            val productName = cleanLabelText(
                label.itemName.ifBlank { label.itemCode },
            )
            val unit = cleanLabelText(label.unit.ifBlank { "kg" })
            val netWeight = compactLabelQty(label.netQty)
            val productLines = if (label.materialNameLines.isEmpty()) {
                wrapLabelText(
                    cleanLabelText("MAHSULOT: $productName"),
                    MATERIAL_TITLE_WIDTH_CHARS,
                )
            } else {
                label.materialNameLines.flatMap {
                    wrapLabelText(cleanLabelText(it), MATERIAL_TITLE_WIDTH_CHARS)
                }
            }
            val weightLines = wrapLabelText(
                cleanLabelText("NET VAZNI: $netWeight $unit"),
                MATERIAL_TITLE_WIDTH_CHARS,
            )
            return productLines + weightLines
        }
        if (label.isQolipCode && label.customerName.isNotBlank()) {
            return listOf(
                fitLabelText(cleanLabelText(label.customerName), 25),
                fitLabelText(cleanLabelText(rawTitle), 25),
            ).filter { it.isNotBlank() }
        }
        return wrapLabelText(cleanLabelText(rawTitle), 25).take(2)
    }

    private fun largeQrFooter(
        label: BluetoothLabelRequest,
        payload: String,
    ): String {
        val value = when {
            label.isMaterialProduct -> payload
            label.isQolipProductCode -> "EPC: $payload"
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
        val response = mapOf(
            "ok" to true,
            "status" to "done",
            "bytes" to bytes,
            "deviceName" to "XP-P323B",
            "address" to address,
            "label_count" to labelCount,
            "printer_status" to "Bluetooth OK",
        )
        activity.runOnUiThread {
            printBusy.set(false)
            result.success(response)
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

private class CapturingTsplPrinter(
    connection: IDeviceConnection,
) : TSPLPrinter(connection) {
    private val output = ByteArrayOutputStream()

    override fun sendData(data: ByteArray): TSPLPrinter {
        output.write(data)
        return this
    }

    override fun sendData(data: MutableList<ByteArray?>): TSPLPrinter {
        data.forEach { chunk ->
            if (chunk != null) {
                output.write(chunk)
            }
        }
        return this
    }

    fun payload(): ByteArray = output.toByteArray()
}

private data class BluetoothLabelRequest(
    val epc: String,
    val itemCode: String,
    val itemName: String,
    val apparatus: String,
    val customerName: String,
    val qolipColor: String,
    val grossQty: Double,
    val unit: String,
    val tareEnabled: Boolean,
    val tareKg: Double,
    val printCount: Int,
    val labelKind: String,
    val materialNameLines: List<String>,
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
        get() = labelKind == "qolip_code" || labelKind == "paddon_code"

    val isQolipProductCode: Boolean
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
                apparatus = call.argument<String>("apparatus").orEmpty().trim(),
                customerName = call.argument<String>("customer_name").orEmpty().trim(),
                qolipColor = call.argument<String>("qolip_color").orEmpty().trim(),
                grossQty = grossQty.coerceAtLeast(0.0),
                unit = call.argument<String>("unit").orEmpty().trim().ifBlank { "kg" },
                tareEnabled = call.argument<Boolean>("tare_enabled") == true || tareKg > 0,
                tareKg = tareKg.coerceAtLeast(0.0),
                printCount = printCount,
                labelKind = call.argument<String>("label_kind")
                    .orEmpty()
                    .trim()
                    .lowercase(Locale.US),
                materialNameLines = call.argument<List<Any?>>("material_name_lines")
                    .orEmpty()
                    .mapNotNull { value ->
                        value?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    },
                progressQty = call.argument<Number>("progress_qty")?.toDouble()
                    ?.takeIf { it.isFinite() },
                progressUnit = call.argument<String>("progress_unit").orEmpty().trim(),
            )
        }
    }
}
