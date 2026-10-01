import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlin.math.roundToInt
import java.nio.file.Files
import java.nio.file.Path
import net.posprinter.TSPLConst
import net.posprinter.TSPLPrinter
import io.flutter.plugin.common.MethodCall
class NativeBefore {
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
        // Three copies at 60% of the former 174-dot receipt symbol.
        private const val MATERIAL_DATA_MATRIX_SIZE_DOTS = 104
        private const val MATERIAL_DATA_MATRIX_COUNT = 3
        private const val MATERIAL_DATA_MATRIX_GAP_DOTS = 16
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
        // Homashyo split yorlig'i: kattaroq matn (FNT_24_32) va kattaroq QR.
        // 16 char/en = 400 dot ichiga sig'adi, qator balandligi 36 dot.
        private const val SPLIT_TEXT_CHAR_WIDTH_DOTS = 24
        private const val SPLIT_TEXT_LINE_HEIGHT_DOTS = 36
        private const val SPLIT_FIELD_WIDTH_CHARS = 16
        private const val SPLIT_QR_BASE_Y = 250
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

    fun buildSdkLabel(
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
            label.isMaterialSplit -> printMaterialSplitLabel(printer, label)
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
        val useDataMatrix = label.materialDataMatrix && label.isMaterialProduct
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
        val qrSize = if (useDataMatrix) {
            MATERIAL_DATA_MATRIX_SIZE_DOTS
        } else {
            qrSymbolSizeDots(payload, cellSize)
        }
        val baseQrY = if (useDataMatrix) {
            (LABEL_HEIGHT_DOTS - qrSize) / 2
        } else {
            centeredQrY(payload, cellSize)
        }
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
        if (useDataMatrix) {
            sdkMaterialDataMatrixRow(printer, qrY, label.materialDataMatrixBars)
        } else {
            sdkQr(printer, qrX, qrY, payload, cellSize = cellSize)
        }
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

    // Homashyo rezkachisi split chiqishi: katta matn (FNT_24_32 bold) va
    // pastda kattaroq QR. Matn balandligiga qarab QR pastga suriladi, lekin
    // EPC footer bilan birga yorliqdan chiqib ketmaydi. Faqat
    // isMaterialSplit uchun ishlaydi, boshqa chop etishlarga tegmaydi.
    private fun printMaterialSplitLabel(
        printer: TSPLPrinter,
        label: BluetoothLabelRequest,
    ) {
        val payload = requiredPayload(label.epc)
        val product = cleanLabelText(
            label.itemName.ifBlank { label.itemCode }.ifBlank { "-" },
        )
        val weightUnit = cleanLabelText(label.unit.ifBlank { "kg" })
        val meterUnit = cleanLabelText(label.progressUnit.ifBlank { "m" })
        val lengthM = label.progressQty?.takeIf { it.isFinite() && it > 0.0 }
        var y = PROGRESS_TEXT_TOP_Y
        y = printSplitField(printer, y, "HOMASHYO", product, maxLines = 3)
        y = printSplitField(
            printer,
            y,
            "BRUTTO",
            "${formatLabelQty(label.grossQty)} $weightUnit",
        )
        y = printSplitField(
            printer,
            y,
            "NETTO",
            "${formatLabelQty(label.netQty)} $weightUnit",
        )
        // Tizimga kiritilgan metraj (lengthM) bo'lsa chiqar, bo'lmasa qatorni
        // tashlab ket — QR baribir pastda katta qoladi.
        if (lengthM != null) {
            y = printSplitField(
                printer,
                y,
                "METRAJ",
                "${formatLabelQty(lengthM)} $meterUnit",
            )
        }

        val qrCellSize = splitQrCellWidth(payload)
        val qrSize = if (label.materialDataMatrix) {
            MATERIAL_DATA_MATRIX_SIZE_DOTS
        } else {
            qrSymbolSizeDots(payload, qrCellSize)
        }
        // Preserve the EPC position from the former single-QR layout. Put
        // the compact row immediately above that stable footer so the smaller
        // symbols do not make EPC jump upward.
        val previousQrSize = qrSymbolSizeDots(payload, qrCellSize)
        val previousLatestQrY = LABEL_HEIGHT_DOTS - LARGE_QR_FOOTER_HEIGHT_DOTS -
            PROGRESS_PACK_EPC_GAP_DOTS - previousQrSize
        val previousQrY = maxOf(SPLIT_QR_BASE_Y, minOf(y + 8, previousLatestQrY))
        val epcY = (previousQrY + previousQrSize + PROGRESS_PACK_EPC_GAP_DOTS)
            .coerceAtMost(LABEL_HEIGHT_DOTS - 24)
        val qrY = if (label.materialDataMatrix) {
            maxOf(
                SPLIT_QR_BASE_Y,
                epcY - PROGRESS_PACK_EPC_GAP_DOTS - qrSize,
            )
        } else {
            previousQrY
        }
        if (label.materialDataMatrix) {
            sdkMaterialDataMatrixRow(printer, qrY, label.materialDataMatrixBars)
        } else {
            sdkQr(
                printer,
                PROGRESS_PACK_QR_X,
                qrY,
                payload,
                cellSize = qrCellSize,
            )
        }
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

    private fun splitQrCellWidth(value: String): Int {
        return (packQrCellSize(value) + 1).coerceAtMost(6)
    }

    private fun printSplitField(
        printer: TSPLPrinter,
        y: Int,
        fieldLabel: String,
        value: String,
        maxLines: Int = 1,
    ): Int {
        val lines = splitFieldLines(fieldLabel, value, maxLines)
        lines.forEachIndexed { index, line ->
            sdkSplitLine(printer, y + index * SPLIT_TEXT_LINE_HEIGHT_DOTS, line)
        }
        return y + lines.size * SPLIT_TEXT_LINE_HEIGHT_DOTS + PROGRESS_FIELD_GAP_DOTS
    }

    private fun splitFieldLines(
        fieldLabel: String,
        value: String,
        maxLines: Int,
    ): List<String> {
        return wrapLabelText(
            "$fieldLabel: ${value.trim().ifBlank { "-" }}",
            SPLIT_FIELD_WIDTH_CHARS,
        ).take(maxLines.coerceAtLeast(1))
    }

    private fun sdkSplitLine(
        printer: TSPLPrinter,
        y: Int,
        line: String,
    ) {
        val separator = line.indexOf(':')
        if (separator < 0) {
            sdkSplitBoldText(printer, LABEL_LEFT_MARGIN_DOTS, y, line)
            return
        }
        val labelPart = line.take(separator + 1)
        val valuePart = line.drop(separator + 1).trimStart()
        sdkText(
            printer,
            LABEL_LEFT_MARGIN_DOTS,
            y,
            TSPLConst.FNT_24_32,
            labelPart,
        )
        if (valuePart.isNotEmpty()) {
            sdkSplitBoldText(
                printer,
                LABEL_LEFT_MARGIN_DOTS +
                    (labelPart.length + 1) * SPLIT_TEXT_CHAR_WIDTH_DOTS,
                y,
                valuePart,
            )
        }
    }

    private fun sdkSplitBoldText(
        printer: TSPLPrinter,
        x: Int,
        y: Int,
        value: String,
    ) {
        sdkText(printer, x, y, TSPLConst.FNT_24_32, value)
        sdkText(
            printer,
            x + PROGRESS_BOLD_OFFSET_DOTS,
            y,
            TSPLConst.FNT_24_32,
            value,
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
        val apparatus = progressApparatusName(
            label.apparatusDisplayName,
            label.apparatus,
            rawProduct,
        )
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

    private fun progressApparatusName(
        displayName: String,
        canonicalApparatus: String,
        itemName: String,
    ): String {
        val explicit = cleanLabelText(displayName).trim()
        if (explicit.isNotEmpty()) {
            return explicit
        }
        val canonical = cleanLabelText(canonicalApparatus).trim()
        if (canonical.isNotEmpty()) {
            return canonical
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

    private fun sdkMaterialDataMatrixRow(
        printer: TSPLPrinter,
        y: Int,
        bars: List<List<Double>>,
    ) {
        val rowWidth = MATERIAL_DATA_MATRIX_COUNT * MATERIAL_DATA_MATRIX_SIZE_DOTS +
            (MATERIAL_DATA_MATRIX_COUNT - 1) * MATERIAL_DATA_MATRIX_GAP_DOTS
        val startX = (LABEL_WIDTH_DOTS - rowWidth) / 2
        repeat(MATERIAL_DATA_MATRIX_COUNT) { index ->
            sdkDataMatrix(
                printer,
                startX + index * (MATERIAL_DATA_MATRIX_SIZE_DOTS + MATERIAL_DATA_MATRIX_GAP_DOTS),
                y,
                bars,
                MATERIAL_DATA_MATRIX_SIZE_DOTS,
            )
        }
    }

    private fun sdkDataMatrix(
        printer: TSPLPrinter,
        x: Int,
        y: Int,
        bars: List<List<Double>>,
        sizeDots: Int,
    ) {
        // Explicit dot bounds keep firmware from auto-sizing the ECC 200 symbol.
        val commands = buildString {
            for (bar in bars) {
                val left = (bar[0] * sizeDots).roundToInt()
                val top = (bar[1] * sizeDots).roundToInt()
                val right = (bar[2] * sizeDots).roundToInt()
                val bottom = (bar[3] * sizeDots).roundToInt()
                append("BAR ${x + left},${y + top},${right - left},${bottom - top}\r\n")
            }
        }
        printer.sendData(commands.toByteArray(Charsets.US_ASCII))
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
            val weights = if (label.tareEnabled) {
                listOf("BRUTTO: ${compactLabelQty(label.grossQty)} $unit", "NETTO: $netWeight $unit")
            } else {
                listOf("NET VAZNI: $netWeight $unit")
            }
            val meterUnit = cleanLabelText(label.progressUnit.ifBlank { "m" })
            val meterPart = if (label.progressQty != null && label.progressQty > 0) {
                listOf("METRI: ${compactLabelQty(label.progressQty)} $meterUnit")
            } else {
                emptyList()
            }
            val weightLines = (weights + meterPart).flatMap {
                wrapLabelText(cleanLabelText(it), MATERIAL_TITLE_WIDTH_CHARS)
            }
            if (label.materialDataMatrix) {
                // Reserve the complete code row and footer before placing the name.
                val maxTitleLines = 1 + (LABEL_HEIGHT_DOTS - MATERIAL_DATA_MATRIX_SIZE_DOTS -
                    LARGE_QR_FOOTER_GAP_DOTS - LARGE_QR_FOOTER_HEIGHT_DOTS -
                    MATERIAL_TITLE_QR_GAP_DOTS - MATERIAL_TITLE_TOP_Y -
                    MATERIAL_TITLE_FONT_HEIGHT_DOTS) / MATERIAL_TITLE_LINE_HEIGHT_DOTS
                return productLines.take((maxTitleLines - weightLines.size).coerceAtLeast(0)) +
                    weightLines
            }
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
        val rounded = (value * 100).roundToInt() / 100.0
        return String.format(Locale.US, "%.2f", rounded)
    }

    private fun compactLabelQty(value: Double): String {
        return String.format(Locale.US, "%.3f", value)
            .trimEnd('0')
            .trimEnd('.')
    }


}
data class BluetoothLabelRequest(
    val epc: String,
    val itemCode: String,
    val itemName: String,
    val apparatus: String,
    val apparatusDisplayName: String,
    val customerName: String,
    val qolipColor: String,
    val grossQty: Double,
    val unit: String,
    val tareEnabled: Boolean,
    val tareKg: Double,
    val printCount: Int,
    val labelKind: String,
    val materialDataMatrix: Boolean,
    val materialDataMatrixBars: List<List<Double>>,
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

    // Faqat homashyo rezkachisi split chiqishi (progressUnit='m' yoki
    // HOMASHYO sarlavha): yangi zich tartib + WIP dagi kichik o'ng-past QR.
    // Uzunliksiz generic material_product eski katta markaziy QR yo'lida
    // qoladi.
    val isMaterialSplit: Boolean
        get() = isMaterialProduct &&
            (progressUnit.equals("m", ignoreCase = true) ||
                materialNameLines.firstOrNull()?.startsWith("HOMASHYO") == true)

    companion object {
        fun from(call: MethodCall): BluetoothLabelRequest? {
            val epc = call.argument<String>("epc").orEmpty().trim()
            val grossQty = call.argument<Number>("gross_qty")?.toDouble() ?: 0.0
            val tareKg = call.argument<Number>("tare_kg")?.toDouble() ?: 0.0
            val printCount = call.argument<Number>("print_count")?.toInt() ?: 1
            val materialDataMatrix = call.argument<Boolean>("material_data_matrix") == true
            val bars = call.argument<List<List<Number>>>("material_data_matrix_bars")
                .orEmpty().map { row -> row.map { it.toDouble() } }
            if (materialDataMatrix && (bars.isEmpty() || bars.any { bar ->
                    bar.size != 4 || bar.any { !it.isFinite() || it !in 0.0..1.0 } ||
                        bar[0] >= bar[2] || bar[1] >= bar[3]
                })) {
                return null
            }
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
                apparatusDisplayName = call.argument<String>("apparatus_display_name")
                    .orEmpty()
                    .trim(),
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
                materialDataMatrix = materialDataMatrix,
                materialDataMatrixBars = bars,
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

class Capture : TSPLPrinter(null) {
  val output = ByteArrayOutputStream()
  override fun sendData(data: ByteArray): TSPLPrinter { output.write(data); return this }
  override fun sendData(data: MutableList<ByteArray?>): TSPLPrinter { data.filterNotNull().forEach { output.write(it) }; return this }
}
fun main(args: Array<String>) {
  val dir=Path.of(args[0])
  val inputs=listOf("known","unknown","empty","partial","legacy")
  for (sample in inputs) {
    val values=mutableMapOf<String,Any>("epc" to "00001", "item_code" to "00001", "item_name" to "PADDON 00001", "gross_qty" to 1.0, "label_kind" to "paddon_code", "print_count" to 2)
    val header=dir.resolve(sample+"-header.txt")
    if (Files.exists(header)) values["paddon_label_lines"] = Files.readAllLines(header)
    val label=BluetoothLabelRequest.from(MethodCall("printLabel",values))!!
    val capture=Capture()
    NativeBefore().buildSdkLabel(capture,label)
    capture.print(2)
    Files.write(dir.resolve("android-before-"+sample+".tspl"),capture.output.toByteArray())
  }
}
