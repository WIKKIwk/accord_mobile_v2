package com.example.accord_mobile_v2

import java.io.ByteArrayOutputStream
import java.nio.charset.Charset
import java.text.Normalizer
import java.util.Locale
import kotlin.math.abs

internal object GodexRpsRenderer {
    private const val TEXT_GRAPHIC_NAME = "TEXTLBL"
    private const val QR_GRAPHIC_NAME = "QRLBL"
    private val ascii: Charset = Charset.forName("US-ASCII")

    fun render(request: UsbRpsPrintRequest): ByteArray {
        val content = PackLabelContent(
            companyName = uppercaseClean("Accord"),
            productName = uppercaseClean(request.itemName.ifBlank { request.epc }),
            kgText = normalizeKgValue(String.format(Locale.US, "%.3f", request.netQty())),
            bruttoText = normalizeKgValue(String.format(Locale.US, "%.3f", request.grossQty)),
            epc = uppercaseClean(request.epc),
            qrPayload = uppercaseClean(request.epc),
        )
        val textGraphic = renderPackEpcGraphic(content)
        val qrGraphic = renderQrGraphic(content.qrPayload, qrBoxDots = 144)
        val out = ByteArrayOutputStream()
        fun send(command: String) {
            out.write(command.trimEnd('\r', '\n').toByteArray(ascii))
            out.write('\r'.code)
            out.write('\n'.code)
        }
        fun writeRaw(payload: ByteArray) {
            out.write(payload)
        }

        send("^XSET,BUZZER,0")
        send("~MDELG,$TEXT_GRAPHIC_NAME")
        send("~EB,$TEXT_GRAPHIC_NAME,${textGraphic.size}")
        writeRaw(textGraphic)
        send("~MDELG,$QR_GRAPHIC_NAME")
        send("~EB,$QR_GRAPHIC_NAME,${qrGraphic.size}")
        writeRaw(qrGraphic)
        buildPackCommands(content).forEach(::send)
        send("~S,STATUS")
        return out.toByteArray()
    }

    private fun buildPackCommands(content: PackLabelContent): List<String> {
        val commands = mutableListOf(
            "~S,ESG",
            "^AD",
            "^XSET,UNICODE,1",
            "^XSET,IMMEDIATE,1",
            "^XSET,ACTIVERESPONSE,1",
            "^XSET,CODEPAGE,16",
            "^Q50,3",
            "^W50",
            "^H10",
            "^P1",
            "^L",
            "Y0,0,$TEXT_GRAPHIC_NAME",
            "AB,16,72,1,1,0,0,COMPANY: ${content.companyName}",
        )
        wrapTextForEzpl("MAHSULOT NOMI: ${content.productName}", 184, 1, 8, 8)
            .take(4)
            .forEachIndexed { index, line ->
                commands.add("AB,16,${112 + index * 40},1,1,0,0,$line")
            }
        commands.add("AB,16,264,1,1,0,0,NETTO: ${content.kgText} KG")
        commands.add("AB,16,304,1,1,0,0,BRUTTO: ${content.bruttoText} KG")
        commands.add("BA,0,24,1,2,42,0,0,${content.epc}")
        commands.add("Y224,224,$QR_GRAPHIC_NAME")
        commands.add("E")
        return commands
    }

    private fun renderPackEpcGraphic(content: PackLabelContent): ByteArray {
        val canvas = MonoBitmap.filled(400, 400, light = true)
        drawText(canvas, 16, 0, 2, "EPC: ${content.epc}")
        return encodeMonoBmp(canvas.cropInk())
    }

    private fun renderQrGraphic(payload: String, qrBoxDots: Int): ByteArray {
        require(payload.isNotEmpty()) { "qr payload is empty" }
        val qr = QrCode.encodeText(payload)
        val matrixSize = qr.size
        val quietZone = 4
        val moduleCount = matrixSize + quietZone * 2
        val moduleDots = (qrBoxDots / moduleCount).coerceAtLeast(1)
        val drawn = moduleCount * moduleDots
        val offset = (qrBoxDots - drawn).coerceAtLeast(0) / 2
        val bitmap = MonoBitmap.filled(qrBoxDots, qrBoxDots, light = true)
        for (y in 0 until matrixSize) {
            for (x in 0 until matrixSize) {
                if (!qr.getModule(x, y)) continue
                val startX = offset + (x + quietZone) * moduleDots
                val startY = offset + (y + quietZone) * moduleDots
                for (dy in 0 until moduleDots) {
                    for (dx in 0 until moduleDots) {
                        bitmap.setLight(startX + dx, startY + dy, false)
                    }
                }
            }
        }
        return encodeMonoBmp(bitmap)
    }

    private fun drawText(canvas: MonoBitmap, x: Int, y: Int, scale: Int, text: String) {
        var cursor = x
        for (ch in text) {
            drawChar(canvas, cursor, y, scale, ch)
            cursor += 6 * scale
        }
    }

    private fun drawChar(canvas: MonoBitmap, x: Int, y: Int, scale: Int, ch: Char) {
        if (ch == ' ') return
        val glyph = glyphRows(ch.uppercaseChar())
        for ((rowIndex, row) in glyph.withIndex()) {
            for (col in 0 until 5) {
                if (row and (0b10000 shr col) == 0) continue
                for (dy in 0 until scale) {
                    for (dx in 0 until scale) {
                        val px = x + col * scale + dx
                        val py = y + rowIndex * scale + dy
                        if (px >= 0 && py >= 0) {
                            canvas.setLight(px, py, false)
                        }
                    }
                }
            }
        }
    }

    private fun glyphRows(ch: Char): IntArray {
        return when (ch) {
            'A' -> intArrayOf(14, 17, 17, 31, 17, 17, 17)
            'B' -> intArrayOf(30, 17, 17, 30, 17, 17, 30)
            'C' -> intArrayOf(14, 17, 16, 16, 16, 17, 14)
            'D' -> intArrayOf(30, 17, 17, 17, 17, 17, 30)
            'E' -> intArrayOf(31, 16, 16, 30, 16, 16, 31)
            'F' -> intArrayOf(31, 16, 16, 30, 16, 16, 16)
            'G' -> intArrayOf(14, 17, 16, 23, 17, 17, 14)
            'H' -> intArrayOf(17, 17, 17, 31, 17, 17, 17)
            'I' -> intArrayOf(14, 4, 4, 4, 4, 4, 14)
            'J' -> intArrayOf(7, 2, 2, 2, 18, 18, 12)
            'K' -> intArrayOf(17, 18, 20, 24, 20, 18, 17)
            'L' -> intArrayOf(16, 16, 16, 16, 16, 16, 31)
            'M' -> intArrayOf(17, 27, 21, 21, 17, 17, 17)
            'N' -> intArrayOf(17, 25, 21, 19, 17, 17, 17)
            'O' -> intArrayOf(14, 17, 17, 17, 17, 17, 14)
            'P' -> intArrayOf(30, 17, 17, 30, 16, 16, 16)
            'Q' -> intArrayOf(14, 17, 17, 17, 21, 18, 13)
            'R' -> intArrayOf(30, 17, 17, 30, 20, 18, 17)
            'S' -> intArrayOf(15, 16, 16, 14, 1, 1, 30)
            'T' -> intArrayOf(31, 4, 4, 4, 4, 4, 4)
            'U' -> intArrayOf(17, 17, 17, 17, 17, 17, 14)
            'V' -> intArrayOf(17, 17, 17, 17, 17, 10, 4)
            'W' -> intArrayOf(17, 17, 17, 21, 21, 21, 10)
            'X' -> intArrayOf(17, 17, 10, 4, 10, 17, 17)
            'Y' -> intArrayOf(17, 17, 10, 4, 4, 4, 4)
            'Z' -> intArrayOf(31, 1, 2, 4, 8, 16, 31)
            '0' -> intArrayOf(14, 17, 19, 21, 25, 17, 14)
            '1' -> intArrayOf(4, 12, 4, 4, 4, 4, 14)
            '2' -> intArrayOf(14, 17, 1, 2, 4, 8, 31)
            '3' -> intArrayOf(30, 1, 1, 14, 1, 1, 30)
            '4' -> intArrayOf(2, 6, 10, 18, 31, 2, 2)
            '5' -> intArrayOf(31, 16, 16, 30, 1, 1, 30)
            '6' -> intArrayOf(14, 16, 16, 30, 17, 17, 14)
            '7' -> intArrayOf(31, 1, 2, 4, 8, 8, 8)
            '8' -> intArrayOf(14, 17, 17, 14, 17, 17, 14)
            '9' -> intArrayOf(14, 17, 17, 15, 1, 1, 14)
            ':' -> intArrayOf(0, 4, 4, 0, 4, 4, 0)
            '.' -> intArrayOf(0, 0, 0, 0, 0, 12, 12)
            '-' -> intArrayOf(0, 0, 0, 31, 0, 0, 0)
            '\'' -> intArrayOf(4, 4, 8, 0, 0, 0, 0)
            '/' -> intArrayOf(1, 1, 2, 4, 8, 16, 16)
            else -> intArrayOf(31, 17, 21, 21, 21, 17, 31)
        }
    }

    private fun encodeMonoBmp(src: MonoBitmap): ByteArray {
        val rowBytes = ((src.width + 31) / 32) * 4
        val pixelBytes = rowBytes * src.height
        val headerBytes = 14 + 40 + 8
        val fileBytes = headerBytes + pixelBytes
        val out = ByteArrayOutputStream(fileBytes)
        fun u16(value: Int) {
            out.write(value and 0xFF)
            out.write((value ushr 8) and 0xFF)
        }
        fun u32(value: Int) {
            out.write(value and 0xFF)
            out.write((value ushr 8) and 0xFF)
            out.write((value ushr 16) and 0xFF)
            out.write((value ushr 24) and 0xFF)
        }
        out.write('B'.code)
        out.write('M'.code)
        u32(fileBytes)
        u16(0)
        u16(0)
        u32(headerBytes)
        u32(40)
        u32(src.width)
        u32(src.height)
        u16(1)
        u16(1)
        u32(0)
        u32(pixelBytes)
        u32(0)
        u32(0)
        u32(2)
        u32(2)
        out.write(byteArrayOf(0x00, 0x00, 0x00, 0x00))
        out.write(byteArrayOf(0xff.toByte(), 0xff.toByte(), 0xff.toByte(), 0x00))
        for (y in src.height - 1 downTo 0) {
            val row = ByteArray(rowBytes)
            for (x in 0 until src.width) {
                if (src.isLight(x, y)) {
                    row[x / 8] = (row[x / 8].toInt() or (0x80 shr (x % 8))).toByte()
                }
            }
            out.write(row)
        }
        return out.toByteArray()
    }

    private fun wrapTextForEzpl(
        text: String,
        widthDots: Int,
        xMul: Int,
        pitchDots: Int,
        minChars: Int,
    ): List<String> {
        val cleanText = sanitizeLabelText(text)
        if (cleanText.isEmpty()) return listOf("")
        val charWidth = (pitchDots * xMul.coerceAtLeast(1)).coerceAtLeast(1)
        val widthChars = minChars.coerceAtLeast((widthDots / charWidth).coerceAtLeast(0))
        val lines = wrapWordsByCharCount(cleanText, widthChars, breakLong = false)
        return if (lines.any { it.length > widthChars }) {
            wrapWordsByCharCount(cleanText, widthChars, breakLong = true)
        } else {
            lines
        }
    }

    private fun wrapWordsByCharCount(text: String, width: Int, breakLong: Boolean): List<String> {
        val lines = mutableListOf<String>()
        var current = ""
        for (word in text.split(Regex("\\s+")).filter { it.isNotEmpty() }) {
            val candidate = if (current.isEmpty()) word else "$current $word"
            if (candidate.length <= width) {
                current = candidate
                continue
            }
            if (current.isNotEmpty()) lines.add(current)
            if (!breakLong || word.length <= width) {
                current = word
                continue
            }
            var rest = word
            while (rest.length > width) {
                lines.add(rest.substring(0, width))
                rest = rest.substring(width)
            }
            current = rest
        }
        if (current.isNotEmpty()) lines.add(current)
        return lines.ifEmpty { listOf(text) }
    }

    private fun uppercaseClean(value: String): String {
        return sanitizeLabelText(value).uppercase(Locale.US)
    }

    private fun sanitizeLabelText(value: String): String {
        val normalized = Normalizer.normalize(value, Normalizer.Form.NFKC)
            .replace(Regex("[\\r\\n\\^~]"), " ")
        return normalized.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
    }

    private fun normalizeKgValue(text: String): String {
        var value = sanitizeLabelText(text)
        val lowered = value.lowercase(Locale.US)
        value = when {
            lowered.startsWith("kg:") -> value.substring(3).trim()
            lowered.endsWith("kg") -> value.substring(0, value.length - 2).trim()
            else -> value
        }
        return roundKgText(value) ?: value
    }

    private fun roundKgText(text: String): String? {
        val parsed = text.trim().replace(',', '.').toDoubleOrNull() ?: return null
        var formatted = String.format(Locale.US, "%.1f", kotlin.math.round(parsed * 10.0) / 10.0)
        while (formatted.contains('.') && formatted.endsWith('0')) {
            formatted = formatted.dropLast(1)
        }
        if (formatted.endsWith('.')) {
            formatted = formatted.dropLast(1)
        }
        return formatted
    }

    private data class PackLabelContent(
        val companyName: String,
        val productName: String,
        val kgText: String,
        val bruttoText: String,
        val epc: String,
        val qrPayload: String,
    )

    private class MonoBitmap private constructor(
        val width: Int,
        val height: Int,
        private val lightPixels: BooleanArray,
    ) {
        fun setLight(x: Int, y: Int, light: Boolean) {
            if (x !in 0 until width || y !in 0 until height) return
            lightPixels[y * width + x] = light
        }

        fun isLight(x: Int, y: Int): Boolean = lightPixels[y * width + x]

        fun cropInk(): MonoBitmap {
            var minX = width
            var minY = height
            var maxX = 0
            var maxY = 0
            var found = false
            for (y in 0 until height) {
                for (x in 0 until width) {
                    if (!isLight(x, y)) {
                        minX = minOf(minX, x)
                        minY = minOf(minY, y)
                        maxX = maxOf(maxX, x + 1)
                        maxY = maxOf(maxY, y + 1)
                        found = true
                    }
                }
            }
            if (!found) return copy()
            minX = (minX - 1).coerceAtLeast(0)
            maxX = (maxX + 1).coerceAtMost(width)
            val out = filled(maxX - minX, maxY - minY, light = true)
            for (y in minY until maxY) {
                for (x in minX until maxX) {
                    out.setLight(x - minX, y - minY, isLight(x, y))
                }
            }
            return out
        }

        private fun copy(): MonoBitmap = MonoBitmap(width, height, lightPixels.copyOf())

        companion object {
            fun filled(width: Int, height: Int, light: Boolean): MonoBitmap {
                return MonoBitmap(width, height, BooleanArray(width.coerceAtLeast(0) * height.coerceAtLeast(0)) { light })
            }
        }
    }

    private class QrCode private constructor(
        private val version: Int,
        private var ecl: Ecc,
        private val modules: BooleanArray,
        private val isFunction: BooleanArray,
    ) {
        val size: Int = version * 4 + 17

        fun getModule(x: Int, y: Int): Boolean {
            return x in 0 until size && y in 0 until size && modules[y * size + x]
        }

        private fun setModule(x: Int, y: Int, dark: Boolean) {
            modules[y * size + x] = dark
        }

        private fun setFunctionModule(x: Int, y: Int, dark: Boolean) {
            setModule(x, y, dark)
            isFunction[y * size + x] = true
        }

        private fun drawFunctionPatterns() {
            for (i in 0 until size) {
                setFunctionModule(6, i, i % 2 == 0)
                setFunctionModule(i, 6, i % 2 == 0)
            }
            drawFinderPattern(3, 3)
            drawFinderPattern(size - 4, 3)
            drawFinderPattern(3, size - 4)
            val align = alignmentPatternPositions()
            for (i in align.indices) {
                for (j in align.indices) {
                    if (!((i == 0 && j == 0) || (i == 0 && j == align.lastIndex) || (i == align.lastIndex && j == 0))) {
                        drawAlignmentPattern(align[i], align[j])
                    }
                }
            }
            drawFormatBits(0)
            drawVersion()
        }

        private fun drawFormatBits(mask: Int) {
            val data = (ecl.formatBits shl 3) or mask
            var rem = data
            repeat(10) {
                rem = (rem shl 1) xor ((rem ushr 9) * 0x537)
            }
            val bits = ((data shl 10) or rem) xor 0x5412
            for (i in 0 until 6) setFunctionModule(8, i, bit(bits, i))
            setFunctionModule(8, 7, bit(bits, 6))
            setFunctionModule(8, 8, bit(bits, 7))
            setFunctionModule(7, 8, bit(bits, 8))
            for (i in 9 until 15) setFunctionModule(14 - i, 8, bit(bits, i))
            for (i in 0 until 8) setFunctionModule(size - 1 - i, 8, bit(bits, i))
            for (i in 8 until 15) setFunctionModule(8, size - 15 + i, bit(bits, i))
            setFunctionModule(8, size - 8, true)
        }

        private fun drawVersion() {
            if (version < 7) return
            var rem = version
            repeat(12) {
                rem = (rem shl 1) xor ((rem ushr 11) * 0x1F25)
            }
            val bits = (version shl 12) or rem
            for (i in 0 until 18) {
                val a = size - 11 + i % 3
                val b = i / 3
                val dark = bit(bits, i)
                setFunctionModule(a, b, dark)
                setFunctionModule(b, a, dark)
            }
        }

        private fun drawFinderPattern(x: Int, y: Int) {
            for (dy in -4..4) {
                for (dx in -4..4) {
                    val xx = x + dx
                    val yy = y + dy
                    if (xx in 0 until size && yy in 0 until size) {
                        val dist = maxOf(abs(dx), abs(dy))
                        setFunctionModule(xx, yy, dist != 2 && dist != 4)
                    }
                }
            }
        }

        private fun drawAlignmentPattern(x: Int, y: Int) {
            for (dy in -2..2) {
                for (dx in -2..2) {
                    setFunctionModule(x + dx, y + dy, maxOf(abs(dx), abs(dy)) != 1)
                }
            }
        }

        private fun addEccAndInterleave(data: IntArray): IntArray {
            val numBlocks = NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][version]
            val blockEccLen = ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][version]
            val rawCodewords = getNumRawDataModules(version) / 8
            val numShortBlocks = numBlocks - rawCodewords % numBlocks
            val shortBlockLen = rawCodewords / numBlocks
            val rsDiv = reedSolomonComputeDivisor(blockEccLen)
            val blocks = ArrayList<IntArray>()
            var k = 0
            for (i in 0 until numBlocks) {
                val dataLen = shortBlockLen - blockEccLen + if (i >= numShortBlocks) 1 else 0
                val block = IntArray(dataLen + blockEccLen + if (i < numShortBlocks) 1 else 0)
                for (j in 0 until dataLen) block[j] = data[k++]
                val ecc = reedSolomonComputeRemainder(block.copyOfRange(0, dataLen), rsDiv)
                var offset = dataLen
                if (i < numShortBlocks) offset++
                for (j in ecc.indices) block[offset + j] = ecc[j]
                blocks.add(block)
            }
            val result = ArrayList<Int>(rawCodewords)
            for (i in 0..shortBlockLen) {
                for (j in blocks.indices) {
                    if (i != shortBlockLen - blockEccLen || j >= numShortBlocks) {
                        result.add(blocks[j][i])
                    }
                }
            }
            return result.toIntArray()
        }

        private fun drawCodewords(data: IntArray) {
            var i = 0
            var right = size - 1
            while (right >= 1) {
                if (right == 6) right = 5
                for (vert in 0 until size) {
                    for (j in 0 until 2) {
                        val x = right - j
                        val upward = ((right + 1) and 2) == 0
                        val y = if (upward) size - 1 - vert else vert
                        if (!isFunction[y * size + x] && i < data.size * 8) {
                            setModule(x, y, bit(data[i ushr 3], 7 - (i and 7)))
                            i++
                        }
                    }
                }
                right -= 2
            }
        }

        private fun applyMask(mask: Int) {
            for (y in 0 until size) {
                for (x in 0 until size) {
                    val invert = when (mask) {
                        0 -> (x + y) % 2 == 0
                        1 -> y % 2 == 0
                        2 -> x % 3 == 0
                        3 -> (x + y) % 3 == 0
                        4 -> (x / 3 + y / 2) % 2 == 0
                        5 -> x * y % 2 + x * y % 3 == 0
                        6 -> (x * y % 2 + x * y % 3) % 2 == 0
                        else -> ((x + y) % 2 + x * y % 3) % 2 == 0
                    }
                    val index = y * size + x
                    if (invert && !isFunction[index]) modules[index] = !modules[index]
                }
            }
        }

        private fun penaltyScore(): Int {
            var result = 0
            for (y in 0 until size) {
                var runColor = false
                var runX = 0
                val history = FinderPenalty(size)
                for (x in 0 until size) {
                    if (getModule(x, y) == runColor) {
                        runX++
                        if (runX == 5) result += 3 else if (runX > 5) result++
                    } else {
                        history.add(runX)
                        if (!runColor) result += history.countPatterns() * 40
                        runColor = getModule(x, y)
                        runX = 1
                    }
                }
                result += history.terminateAndCount(runColor, runX) * 40
            }
            for (x in 0 until size) {
                var runColor = false
                var runY = 0
                val history = FinderPenalty(size)
                for (y in 0 until size) {
                    if (getModule(x, y) == runColor) {
                        runY++
                        if (runY == 5) result += 3 else if (runY > 5) result++
                    } else {
                        history.add(runY)
                        if (!runColor) result += history.countPatterns() * 40
                        runColor = getModule(x, y)
                        runY = 1
                    }
                }
                result += history.terminateAndCount(runColor, runY) * 40
            }
            for (y in 0 until size - 1) {
                for (x in 0 until size - 1) {
                    val color = getModule(x, y)
                    if (color == getModule(x + 1, y) && color == getModule(x, y + 1) && color == getModule(x + 1, y + 1)) {
                        result += 3
                    }
                }
            }
            val dark = modules.count { it }
            val total = size * size
            val k = ((dark * 20 - total * 10).let { abs(it) } + total - 1) / total - 1
            result += k * 10
            return result
        }

        private fun alignmentPatternPositions(): List<Int> {
            if (version == 1) return emptyList()
            val numAlign = version / 7 + 2
            val step = if (version == 32) 26 else ((version * 4 + numAlign * 2 + 1) / (numAlign * 2 - 2)) * 2
            val result = mutableListOf<Int>()
            for (i in 0 until numAlign - 1) result.add(size - 7 - i * step)
            result.add(6)
            result.reverse()
            return result
        }

        private class FinderPenalty(private val qrSize: Int) {
            private val runHistory = IntArray(7)
            fun add(currentRunLengthInput: Int) {
                var currentRunLength = currentRunLengthInput
                if (runHistory[0] == 0) currentRunLength += qrSize
                for (i in runHistory.size - 2 downTo 0) runHistory[i + 1] = runHistory[i]
                runHistory[0] = currentRunLength
            }

            fun countPatterns(): Int {
                val n = runHistory[1]
                val core = n > 0 && runHistory[2] == n && runHistory[3] == n * 3 && runHistory[4] == n && runHistory[5] == n
                return (if (core && runHistory[0] >= n * 4 && runHistory[6] >= n) 1 else 0) +
                    (if (core && runHistory[6] >= n * 4 && runHistory[0] >= n) 1 else 0)
            }

            fun terminateAndCount(currentRunColor: Boolean, currentRunLengthInput: Int): Int {
                var currentRunLength = currentRunLengthInput
                if (currentRunColor) {
                    add(currentRunLength)
                    currentRunLength = 0
                }
                currentRunLength += qrSize
                add(currentRunLength)
                return countPatterns()
            }
        }

        companion object {
            fun encodeText(text: String): QrCode {
                val segment = QrSegment.make(text)
                var version = 1
                var ecl = Ecc.Low
                val dataUsedBits: Int
                while (true) {
                    val capacity = getNumDataCodewords(version, ecl) * 8
                    val used = segment.totalBits(version)
                    if (used <= capacity) {
                        dataUsedBits = used
                        break
                    }
                    version++
                    require(version <= 40) { "qr data too long" }
                }
                for (newEcl in listOf(Ecc.Medium, Ecc.Quartile, Ecc.High)) {
                    if (dataUsedBits <= getNumDataCodewords(version, newEcl) * 8) ecl = newEcl
                }
                val data = buildDataCodewords(segment, version, ecl, dataUsedBits)
                return encodeCodewords(version, ecl, data)
            }

            private fun encodeCodewords(version: Int, ecl: Ecc, dataCodewords: IntArray): QrCode {
                val size = version * 4 + 17
                val qr = QrCode(version, ecl, BooleanArray(size * size), BooleanArray(size * size))
                qr.drawFunctionPatterns()
                qr.drawCodewords(qr.addEccAndInterleave(dataCodewords))
                var bestMask = 0
                var bestPenalty = Int.MAX_VALUE
                for (mask in 0 until 8) {
                    qr.applyMask(mask)
                    qr.drawFormatBits(mask)
                    val penalty = qr.penaltyScore()
                    if (penalty < bestPenalty) {
                        bestMask = mask
                        bestPenalty = penalty
                    }
                    qr.applyMask(mask)
                }
                qr.applyMask(bestMask)
                qr.drawFormatBits(bestMask)
                return qr
            }

            private fun buildDataCodewords(segment: QrSegment, version: Int, ecl: Ecc, dataUsedBits: Int): IntArray {
                val bits = ArrayList<Boolean>(dataUsedBits + 32)
                appendBits(bits, segment.modeBits, 4)
                appendBits(bits, segment.numChars, segment.charCountBits(version))
                bits.addAll(segment.data)
                val capacity = getNumDataCodewords(version, ecl) * 8
                appendBits(bits, 0, minOf(4, capacity - bits.size))
                appendBits(bits, 0, (-bits.size) and 7)
                var pad = 0
                while (bits.size < capacity) {
                    appendBits(bits, if (pad % 2 == 0) 0xEC else 0x11, 8)
                    pad++
                }
                val out = IntArray(bits.size / 8)
                for (i in bits.indices) {
                    if (bits[i]) out[i ushr 3] = out[i ushr 3] or (1 shl (7 - (i and 7)))
                }
                return out
            }

            private fun appendBits(bits: MutableList<Boolean>, value: Int, length: Int) {
                for (i in length - 1 downTo 0) bits.add(((value ushr i) and 1) != 0)
            }

            private fun getNumRawDataModules(version: Int): Int {
                var result = (16 * version + 128) * version + 64
                if (version >= 2) {
                    val numAlign = version / 7 + 2
                    result -= (25 * numAlign - 10) * numAlign - 55
                    if (version >= 7) result -= 36
                }
                return result
            }

            private fun getNumDataCodewords(version: Int, ecl: Ecc): Int {
                return getNumRawDataModules(version) / 8 -
                    ECC_CODEWORDS_PER_BLOCK[ecl.ordinal][version] * NUM_ERROR_CORRECTION_BLOCKS[ecl.ordinal][version]
            }

            private fun reedSolomonComputeDivisor(degree: Int): IntArray {
                val result = IntArray(degree)
                result[degree - 1] = 1
                var root = 1
                repeat(degree) {
                    for (j in 0 until degree) {
                        result[j] = reedSolomonMultiply(result[j], root)
                        if (j + 1 < degree) result[j] = result[j] xor result[j + 1]
                    }
                    root = reedSolomonMultiply(root, 0x02)
                }
                return result
            }

            private fun reedSolomonComputeRemainder(data: IntArray, divisor: IntArray): IntArray {
                val result = IntArray(divisor.size)
                for (b in data) {
                    val factor = b xor result[0]
                    for (i in 0 until result.size - 1) result[i] = result[i + 1]
                    result[result.lastIndex] = 0
                    for (i in result.indices) {
                        result[i] = result[i] xor reedSolomonMultiply(divisor[i], factor)
                    }
                }
                return result
            }

            private fun reedSolomonMultiply(x: Int, y: Int): Int {
                var z = 0
                for (i in 7 downTo 0) {
                    z = ((z shl 1) xor ((z ushr 7) * 0x1D)) and 0xFF
                    z = z xor (((y ushr i) and 1) * x)
                }
                return z
            }

            private fun bit(value: Int, index: Int): Boolean = ((value ushr index) and 1) != 0

            private val ECC_CODEWORDS_PER_BLOCK = arrayOf(
                intArrayOf(-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30),
                intArrayOf(-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28),
                intArrayOf(-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30),
                intArrayOf(-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30),
            )
            private val NUM_ERROR_CORRECTION_BLOCKS = arrayOf(
                intArrayOf(-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25),
                intArrayOf(-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49),
                intArrayOf(-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68),
                intArrayOf(-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81),
            )
        }
    }

    private data class QrSegment(
        val modeBits: Int,
        val numChars: Int,
        val data: List<Boolean>,
    ) {
        fun charCountBits(version: Int): Int {
            val index = (version + 7) / 17
            return when (modeBits) {
                0x1 -> intArrayOf(10, 12, 14)[index]
                0x2 -> intArrayOf(9, 11, 13)[index]
                else -> intArrayOf(8, 16, 16)[index]
            }
        }

        fun totalBits(version: Int): Int = 4 + charCountBits(version) + data.size

        companion object {
            private const val ALPHANUMERIC_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

            fun make(text: String): QrSegment {
                return when {
                    text.all { it in '0'..'9' } -> makeNumeric(text)
                    text.all { ALPHANUMERIC_CHARSET.contains(it) } -> makeAlphanumeric(text)
                    else -> makeBytes(text.toByteArray(Charsets.UTF_8))
                }
            }

            private fun makeNumeric(text: String): QrSegment {
                val bits = mutableListOf<Boolean>()
                var accumData = 0
                var accumCount = 0
                for (ch in text) {
                    accumData = accumData * 10 + (ch.code - '0'.code)
                    accumCount++
                    if (accumCount == 3) {
                        appendBits(bits, accumData, 10)
                        accumData = 0
                        accumCount = 0
                    }
                }
                if (accumCount > 0) appendBits(bits, accumData, accumCount * 3 + 1)
                return QrSegment(0x1, text.length, bits)
            }

            private fun makeAlphanumeric(text: String): QrSegment {
                val bits = mutableListOf<Boolean>()
                var accumData = 0
                var accumCount = 0
                for (ch in text) {
                    accumData = accumData * 45 + ALPHANUMERIC_CHARSET.indexOf(ch)
                    accumCount++
                    if (accumCount == 2) {
                        appendBits(bits, accumData, 11)
                        accumData = 0
                        accumCount = 0
                    }
                }
                if (accumCount > 0) appendBits(bits, accumData, 6)
                return QrSegment(0x2, text.length, bits)
            }

            private fun makeBytes(data: ByteArray): QrSegment {
                val bits = mutableListOf<Boolean>()
                for (byte in data) appendBits(bits, byte.toInt() and 0xFF, 8)
                return QrSegment(0x4, data.size, bits)
            }

            private fun appendBits(bits: MutableList<Boolean>, value: Int, length: Int) {
                for (i in length - 1 downTo 0) bits.add(((value ushr i) and 1) != 0)
            }
        }
    }

    private enum class Ecc(val formatBits: Int) {
        Low(1),
        Medium(0),
        Quartile(3),
        High(2),
    }
}
