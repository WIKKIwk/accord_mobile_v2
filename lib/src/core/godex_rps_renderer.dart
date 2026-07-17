import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'native_usb_printer.dart';

/// Produces the raw EZPL stream used by the Android Godex printer path.
///
/// Keep this renderer byte-compatible with GodexRpsRenderer.kt. Transport is
/// deliberately outside this class so web preview and Android send the same
/// bytes to different USB transports.
class GodexRpsRenderer {
  const GodexRpsRenderer._();

  static Uint8List render(UsbRpsPrintRequest request) {
    if (request.isQolipCellLabel) {
      return _renderQolipCell(request);
    }
    if (request.isQolipCodeLabel) {
      return _renderQolipCode(request);
    }
    final content = _PackLabelContent(
      companyName: _uppercaseClean('Accord'),
      productName: _uppercaseClean(
        request.itemName.trim().isEmpty ? request.epc : request.itemName,
      ),
      kgText: _normalizeKgValue(request.netQty.toStringAsFixed(3)),
      bruttoText: _normalizeKgValue(request.grossQty.toStringAsFixed(3)),
      epc: _uppercaseClean(request.epc),
      qrPayload: _uppercaseClean(request.epc),
    );
    final textGraphic = _renderPackEpcGraphic(content);
    final qrGraphic = _renderQrGraphic(content.qrPayload, 144);
    final out = BytesBuilder(copy: false);

    void send(String command) {
      out.add(_ascii(command.replaceFirst(RegExp(r'[\r\n]+$'), '')));
      out.addByte(13);
      out.addByte(10);
    }

    send('^XSET,BUZZER,0');
    send('~MDELG,TEXTLBL');
    send('~EB,TEXTLBL,${textGraphic.length}');
    out.add(textGraphic);
    send('~MDELG,QRLBL');
    send('~EB,QRLBL,${qrGraphic.length}');
    out.add(qrGraphic);
    final commands = request.isProgressLabel
        ? _buildProgressCommands(
            content,
            grossQty: request.grossQty,
            progressQty: request.effectiveProgressQty,
            progressUnit: request.progressUnit.trim().isEmpty
                ? request.unit
                : request.progressUnit,
          )
        : _buildPackCommands(content);
    for (final command in commands) {
      send(command);
    }
    send('~S,STATUS');
    return out.takeBytes();
  }

  static Uint8List _renderQolipCell(UsbRpsPrintRequest request) {
    final cellName = _uppercaseClean(
      request.itemName.trim().isEmpty ? request.itemCode : request.itemName,
    );
    final payload = _uppercaseClean(request.epc);
    if (payload.isEmpty) {
      throw StateError('qr payload is empty');
    }
    final textGraphic = _renderCellNameGraphic(cellName);
    final qrGraphic = _renderQrGraphic(payload, 288);
    final out = BytesBuilder(copy: false);

    void send(String command) {
      out.add(_ascii(command.replaceFirst(RegExp(r'[\r\n]+$'), '')));
      out.addByte(13);
      out.addByte(10);
    }

    send('^XSET,BUZZER,0');
    send('~MDELG,TEXTLBL');
    send('~EB,TEXTLBL,${textGraphic.length}');
    out.add(textGraphic);
    send('~MDELG,QRLBL');
    send('~EB,QRLBL,${qrGraphic.length}');
    out.add(qrGraphic);
    send('~S,ESG');
    send('^AD');
    send('^XSET,UNICODE,1');
    send('^XSET,IMMEDIATE,1');
    send('^XSET,ACTIVERESPONSE,1');
    send('^XSET,CODEPAGE,16');
    send('^Q50,3');
    send('^W50');
    send('^H10');
    send('^P1');
    send('^L');
    send('Y0,0,TEXTLBL');
    send('Y56,96,QRLBL');
    send('E');
    send('~S,STATUS');
    return out.takeBytes();
  }

  static Uint8List _renderQolipCode(UsbRpsPrintRequest request) {
    final name = _uppercaseClean(
      request.itemName.trim().isEmpty ? request.itemCode : request.itemName,
    );
    final code = _uppercaseClean(
      request.itemCode.trim().isEmpty ? request.epc : request.itemCode,
    );
    final payload = _uppercaseClean(request.epc);
    if (payload.isEmpty) {
      throw StateError('qr payload is empty');
    }
    final textGraphic = _renderQolipCodeTextGraphic(name, code);
    final qrGraphic = _renderQrGraphic(payload, 288);
    final out = BytesBuilder(copy: false);

    void send(String command) {
      out.add(_ascii(command.replaceFirst(RegExp(r'[\r\n]+$'), '')));
      out.addByte(13);
      out.addByte(10);
    }

    send('^XSET,BUZZER,0');
    send('~MDELG,TEXTLBL');
    send('~EB,TEXTLBL,${textGraphic.length}');
    out.add(textGraphic);
    send('~MDELG,QRLBL');
    send('~EB,QRLBL,${qrGraphic.length}');
    out.add(qrGraphic);
    send('~S,ESG');
    send('^AD');
    send('^XSET,UNICODE,1');
    send('^XSET,IMMEDIATE,1');
    send('^XSET,ACTIVERESPONSE,1');
    send('^XSET,CODEPAGE,16');
    send('^Q50,3');
    send('^W50');
    send('^H10');
    send('^P1');
    send('^L');
    send('Y0,0,TEXTLBL');
    send('Y56,56,QRLBL');
    send('E');
    send('~S,STATUS');
    return out.takeBytes();
  }

  static Uint8List _renderCellNameGraphic(String cellName) {
    const scale = 8;
    const width = 400;
    const height = 96;
    final bitmap = _MonoBitmap.filled(width, height, light: true);
    final textWidth = cellName.length * 6 * scale;
    var cursor = ((width - textWidth) ~/ 2).clamp(0, width - 1);
    for (final character in cellName.split('')) {
      _drawChar(bitmap, cursor, 16, scale, character);
      cursor += 6 * scale;
    }
    return _encodeMonoBmp(bitmap.cropInk());
  }

  static Uint8List _renderQolipCodeTextGraphic(String name, String code) {
    const width = 400;
    const height = 400;
    final bitmap = _MonoBitmap.filled(width, height, light: true);

    void drawCentered(String text, int y, {required int scale}) {
      final textWidth = text.length * 6 * scale;
      var cursor = ((width - textWidth) ~/ 2).clamp(0, width - 1);
      for (final character in text.split('')) {
        _drawChar(bitmap, cursor, y, scale, character);
        cursor += 6 * scale;
      }
    }

    drawCentered(name, 8, scale: 2);
    drawCentered(code, 352, scale: 4);
    return _encodeMonoBmp(bitmap.cropInk());
  }

  static Uint8List renderRepeated(UsbRpsPrintRequest request) {
    final label = render(request);
    final output = BytesBuilder(copy: false);
    final count = request.printCount > 0 ? request.printCount : 1;
    for (var i = 0; i < count; i++) {
      output.add(label);
    }
    return output.takeBytes();
  }

  static List<String> _buildPackCommands(_PackLabelContent content) {
    final commands = <String>[
      '~S,ESG',
      '^AD',
      '^XSET,UNICODE,1',
      '^XSET,IMMEDIATE,1',
      '^XSET,ACTIVERESPONSE,1',
      '^XSET,CODEPAGE,16',
      '^Q50,3',
      '^W50',
      '^H10',
      '^P1',
      '^L',
      'Y0,0,TEXTLBL',
      'AB,16,72,1,1,0,0,COMPANY: ${content.companyName}',
    ];
    final lines = _wrapTextForEzpl(
      'MAHSULOT NOMI: ${content.productName}',
      184,
      1,
      8,
      8,
    ).take(4).toList();
    for (var i = 0; i < lines.length; i++) {
      commands.add('AB,16,${112 + i * 40},1,1,0,0,${lines[i]}');
    }
    commands.add('AB,16,264,1,1,0,0,NETTO: ${content.kgText} KG');
    commands.add('AB,16,304,1,1,0,0,BRUTTO: ${content.bruttoText} KG');
    commands.add('BA,0,24,1,2,42,0,0,${content.epc}');
    commands.add('Y224,224,QRLBL');
    commands.add('E');
    return commands;
  }

  static List<String> _buildProgressCommands(
    _PackLabelContent content, {
    required double grossQty,
    required double progressQty,
    required String progressUnit,
  }) {
    final commands = <String>[
      '~S,ESG',
      '^AD',
      '^XSET,UNICODE,1',
      '^XSET,IMMEDIATE,1',
      '^XSET,ACTIVERESPONSE,1',
      '^XSET,CODEPAGE,16',
      '^Q50,3',
      '^W50',
      '^H10',
      '^P1',
      '^L',
      'Y0,0,TEXTLBL',
      'AB,16,72,1,1,0,0,COMPANY: ${content.companyName}',
    ];
    final lines = _wrapTextForEzpl(
      'MAHSULOT NOMI: ${content.productName}',
      184,
      1,
      8,
      8,
    ).take(4).toList();
    for (var i = 0; i < lines.length; i++) {
      commands.add('AB,16,${112 + i * 40},1,1,0,0,${lines[i]}');
    }
    final unit = _uppercaseClean(progressUnit);
    final qty = _normalizeKgValue(progressQty.toString());
    final qtyText = unit.isEmpty ? qty : '$qty $unit';
    commands.add(
      'AB,16,264,1,1,0,0,KG: ${_normalizeKgValue(grossQty.toString())}',
    );
    commands.add('AB,16,304,1,1,0,0,METRAJ: $qtyText');
    commands.add('BA,0,24,1,2,42,0,0,${content.epc}');
    commands.add('Y224,224,QRLBL');
    commands.add('E');
    return commands;
  }

  static Uint8List _renderPackEpcGraphic(_PackLabelContent content) {
    final canvas = _MonoBitmap.filled(400, 400, light: true);
    _drawText(canvas, 16, 0, 2, 'EPC: ${content.epc}');
    return _encodeMonoBmp(canvas.cropInk());
  }

  static Uint8List _renderQrGraphic(String payload, int qrBoxDots) {
    if (payload.isEmpty) throw StateError('qr payload is empty');
    final qr = _QrCode.encodeText(payload);
    const quietZone = 4;
    final moduleCount = qr.size + quietZone * 2;
    final moduleDots = math.max(qrBoxDots ~/ moduleCount, 1);
    final drawn = moduleCount * moduleDots;
    final offset = math.max(qrBoxDots - drawn, 0) ~/ 2;
    final bitmap = _MonoBitmap.filled(qrBoxDots, qrBoxDots, light: true);
    for (var y = 0; y < qr.size; y++) {
      for (var x = 0; x < qr.size; x++) {
        if (!qr.getModule(x, y)) continue;
        final startX = offset + (x + quietZone) * moduleDots;
        final startY = offset + (y + quietZone) * moduleDots;
        for (var dy = 0; dy < moduleDots; dy++) {
          for (var dx = 0; dx < moduleDots; dx++) {
            bitmap.setLight(startX + dx, startY + dy, false);
          }
        }
      }
    }
    return _encodeMonoBmp(bitmap);
  }

  static void _drawText(
      _MonoBitmap canvas, int x, int y, int scale, String text) {
    var cursor = x;
    for (final ch in text.split('')) {
      _drawChar(canvas, cursor, y, scale, ch.toUpperCase());
      cursor += 6 * scale;
    }
  }

  static void _drawChar(
      _MonoBitmap canvas, int x, int y, int scale, String ch) {
    if (ch == ' ') return;
    final glyph = _glyphRows[ch] ?? const [31, 17, 21, 21, 21, 17, 31];
    for (var rowIndex = 0; rowIndex < glyph.length; rowIndex++) {
      for (var col = 0; col < 5; col++) {
        if ((glyph[rowIndex] & (0x10 >> col)) == 0) continue;
        for (var dy = 0; dy < scale; dy++) {
          for (var dx = 0; dx < scale; dx++) {
            canvas.setLight(
                x + col * scale + dx, y + rowIndex * scale + dy, false);
          }
        }
      }
    }
  }

  static Uint8List _encodeMonoBmp(_MonoBitmap src) {
    final rowBytes = ((src.width + 31) ~/ 32) * 4;
    final pixelBytes = rowBytes * src.height;
    const headerBytes = 14 + 40 + 8;
    final out = BytesBuilder(copy: false);
    void u16(int value) {
      out.addByte(value & 0xff);
      out.addByte((value >> 8) & 0xff);
    }

    void u32(int value) {
      out.addByte(value & 0xff);
      out.addByte((value >> 8) & 0xff);
      out.addByte((value >> 16) & 0xff);
      out.addByte((value >> 24) & 0xff);
    }

    out.add(const [0x42, 0x4d]);
    u32(headerBytes + pixelBytes);
    u16(0);
    u16(0);
    u32(headerBytes);
    u32(40);
    u32(src.width);
    u32(src.height);
    u16(1);
    u16(1);
    u32(0);
    u32(pixelBytes);
    u32(0);
    u32(0);
    u32(2);
    u32(2);
    out.add(const [0, 0, 0, 0, 0xff, 0xff, 0xff, 0]);
    for (var y = src.height - 1; y >= 0; y--) {
      final row = Uint8List(rowBytes);
      for (var x = 0; x < src.width; x++) {
        if (src.isLight(x, y)) {
          row[x ~/ 8] |= 0x80 >> (x % 8);
        }
      }
      out.add(row);
    }
    return out.takeBytes();
  }

  static List<String> _wrapTextForEzpl(
    String text,
    int widthDots,
    int xMul,
    int pitchDots,
    int minChars,
  ) {
    final cleanText = _sanitizeLabelText(text);
    if (cleanText.isEmpty) return const [''];
    final charWidth = math.max(pitchDots * math.max(xMul, 1), 1);
    final widthChars = math.max(minChars, math.max(widthDots ~/ charWidth, 0));
    final lines =
        _wrapWordsByCharCount(cleanText, widthChars, breakLong: false);
    return lines.any((line) => line.length > widthChars)
        ? _wrapWordsByCharCount(cleanText, widthChars, breakLong: true)
        : lines;
  }

  static List<String> _wrapWordsByCharCount(String text, int width,
      {required bool breakLong}) {
    final lines = <String>[];
    var current = '';
    for (final word
        in text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty)) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length <= width) {
        current = candidate;
        continue;
      }
      if (current.isNotEmpty) lines.add(current);
      if (!breakLong || word.length <= width) {
        current = word;
        continue;
      }
      var rest = word;
      while (rest.length > width) {
        lines.add(rest.substring(0, width));
        rest = rest.substring(width);
      }
      current = rest;
    }
    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [text] : lines;
  }

  static String _uppercaseClean(String value) =>
      _sanitizeLabelText(value).toUpperCase();

  static String _sanitizeLabelText(String value) {
    return value
        .replaceAll(RegExp(r'[\r\n\^~]'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  static String _normalizeKgValue(String text) {
    var value = _sanitizeLabelText(text);
    final lowered = value.toLowerCase();
    if (lowered.startsWith('kg:')) value = value.substring(3).trim();
    if (value.toLowerCase().endsWith('kg')) {
      value = value.substring(0, value.length - 2).trim();
    }
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite) return value;
    var formatted = (parsed * 10).round().toString();
    formatted = (int.parse(formatted) / 10).toStringAsFixed(1);
    while (formatted.contains('.') && formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted;
  }

  static Uint8List _ascii(String value) =>
      Uint8List.fromList(value.codeUnits.map((unit) => unit & 0xff).toList());
}

class _PackLabelContent {
  const _PackLabelContent(
      {required this.companyName,
      required this.productName,
      required this.kgText,
      required this.bruttoText,
      required this.epc,
      required this.qrPayload});
  final String companyName;
  final String productName;
  final String kgText;
  final String bruttoText;
  final String epc;
  final String qrPayload;
}

class _MonoBitmap {
  _MonoBitmap(this.width, this.height, List<bool> pixels)
      : _lightPixels = pixels;
  final int width;
  final int height;
  final List<bool> _lightPixels;

  static _MonoBitmap filled(int width, int height, {required bool light}) =>
      _MonoBitmap(width, height,
          List<bool>.filled(math.max(width, 0) * math.max(height, 0), light));
  void setLight(int x, int y, bool light) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _lightPixels[y * width + x] = light;
    }
  }

  bool isLight(int x, int y) => _lightPixels[y * width + x];

  _MonoBitmap cropInk() {
    var minX = width, minY = height, maxX = 0, maxY = 0;
    var found = false;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!isLight(x, y)) {
          minX = math.min(minX, x);
          minY = math.min(minY, y);
          maxX = math.max(maxX, x + 1);
          maxY = math.max(maxY, y + 1);
          found = true;
        }
      }
    }
    if (!found) {
      return _MonoBitmap(width, height, List<bool>.from(_lightPixels));
    }
    minX = math.max(minX - 1, 0);
    maxX = math.min(maxX + 1, width);
    final out = filled(maxX - minX, maxY - minY, light: true);
    for (var y = minY; y < maxY; y++) {
      for (var x = minX; x < maxX; x++) {
        out.setLight(x - minX, y - minY, isLight(x, y));
      }
    }
    return out;
  }
}

const Map<String, List<int>> _glyphRows = {
  'A': [14, 17, 17, 31, 17, 17, 17],
  'B': [30, 17, 17, 30, 17, 17, 30],
  'C': [14, 17, 16, 16, 16, 17, 14],
  'D': [30, 17, 17, 17, 17, 17, 30],
  'E': [31, 16, 16, 30, 16, 16, 31],
  'F': [31, 16, 16, 30, 16, 16, 16],
  'G': [14, 17, 16, 23, 17, 17, 14],
  'H': [17, 17, 17, 31, 17, 17, 17],
  'I': [14, 4, 4, 4, 4, 4, 14],
  'J': [7, 2, 2, 2, 18, 18, 12],
  'K': [17, 18, 20, 24, 20, 18, 17],
  'L': [16, 16, 16, 16, 16, 16, 31],
  'M': [17, 27, 21, 21, 17, 17, 17],
  'N': [17, 25, 21, 19, 17, 17, 17],
  'O': [14, 17, 17, 17, 17, 17, 14],
  'P': [30, 17, 17, 30, 16, 16, 16],
  'Q': [14, 17, 17, 17, 21, 18, 13],
  'R': [30, 17, 17, 30, 20, 18, 17],
  'S': [15, 16, 16, 14, 1, 1, 30],
  'T': [31, 4, 4, 4, 4, 4, 4],
  'U': [17, 17, 17, 17, 17, 17, 14],
  'V': [17, 17, 17, 17, 17, 10, 4],
  'W': [17, 17, 17, 21, 21, 21, 10],
  'X': [17, 17, 10, 4, 10, 17, 17],
  'Y': [17, 17, 10, 4, 4, 4, 4],
  'Z': [31, 1, 2, 4, 8, 16, 31],
  '0': [14, 17, 19, 21, 25, 17, 14],
  '1': [4, 12, 4, 4, 4, 4, 14],
  '2': [14, 17, 1, 2, 4, 8, 31],
  '3': [30, 1, 1, 14, 1, 1, 30],
  '4': [2, 6, 10, 18, 31, 2, 2],
  '5': [31, 16, 16, 30, 1, 1, 30],
  '6': [14, 16, 16, 30, 17, 17, 14],
  '7': [31, 1, 2, 4, 8, 8, 8],
  '8': [14, 17, 17, 14, 17, 17, 14],
  '9': [14, 17, 17, 15, 1, 1, 14],
  ':': [0, 4, 4, 0, 4, 4, 0],
  '.': [0, 0, 0, 0, 0, 12, 12],
  '-': [0, 0, 0, 31, 0, 0, 0],
  "'": [4, 4, 8, 0, 0, 0, 0],
  '/': [1, 1, 2, 4, 8, 16, 16],
};

enum _Ecc {
  low(1),
  medium(0),
  quartile(3),
  high(2);

  const _Ecc(this.formatBits);
  final int formatBits;
}

class _QrCode {
  _QrCode(this.version, this.ecc)
      : size = version * 4 + 17,
        modules =
            List<bool>.filled((version * 4 + 17) * (version * 4 + 17), false),
        isFunction =
            List<bool>.filled((version * 4 + 17) * (version * 4 + 17), false);
  final int version;
  _Ecc ecc;
  final int size;
  final List<bool> modules;
  final List<bool> isFunction;
  bool getModule(int x, int y) =>
      x >= 0 && x < size && y >= 0 && y < size && modules[y * size + x];
  void _setModule(int x, int y, bool dark) {
    modules[y * size + x] = dark;
  }

  void _setFunctionModule(int x, int y, bool dark) {
    _setModule(x, y, dark);
    isFunction[y * size + x] = true;
  }

  void _drawFunctionPatterns() {
    for (var i = 0; i < size; i++) {
      _setFunctionModule(6, i, i % 2 == 0);
      _setFunctionModule(i, 6, i % 2 == 0);
    }
    _drawFinderPattern(3, 3);
    _drawFinderPattern(size - 4, 3);
    _drawFinderPattern(3, size - 4);
    final align = _alignmentPatternPositions();
    for (var i = 0; i < align.length; i++) {
      for (var j = 0; j < align.length; j++) {
        if (!((i == 0 && j == 0) ||
            (i == 0 && j == align.length - 1) ||
            (i == align.length - 1 && j == 0))) {
          _drawAlignmentPattern(align[i], align[j]);
        }
      }
    }
    _drawFormatBits(0);
    _drawVersion();
  }

  void _drawFormatBits(int mask) {
    final data = (ecc.formatBits << 3) | mask;
    var rem = data;
    for (var i = 0; i < 10; i++) {
      rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    }
    final bits = ((data << 10) | rem) ^ 0x5412;
    for (var i = 0; i < 6; i++) {
      _setFunctionModule(8, i, _bit(bits, i));
    }
    _setFunctionModule(8, 7, _bit(bits, 6));
    _setFunctionModule(8, 8, _bit(bits, 7));
    _setFunctionModule(7, 8, _bit(bits, 8));
    for (var i = 9; i < 15; i++) {
      _setFunctionModule(14 - i, 8, _bit(bits, i));
    }
    for (var i = 0; i < 8; i++) {
      _setFunctionModule(size - 1 - i, 8, _bit(bits, i));
    }
    for (var i = 8; i < 15; i++) {
      _setFunctionModule(8, size - 15 + i, _bit(bits, i));
    }
    _setFunctionModule(8, size - 8, true);
  }

  void _drawVersion() {
    if (version < 7) return;
    var rem = version;
    for (var i = 0; i < 12; i++) {
      rem = (rem << 1) ^ ((rem >> 11) * 0x1f25);
    }
    final bits = (version << 12) | rem;
    for (var i = 0; i < 18; i++) {
      final a = size - 11 + i % 3, b = i ~/ 3;
      _setFunctionModule(a, b, _bit(bits, i));
      _setFunctionModule(b, a, _bit(bits, i));
    }
  }

  void _drawFinderPattern(int x, int y) {
    for (var dy = -4; dy <= 4; dy++) {
      for (var dx = -4; dx <= 4; dx++) {
        final xx = x + dx, yy = y + dy;
        if (xx >= 0 && xx < size && yy >= 0 && yy < size) {
          final dist = math.max(dx.abs(), dy.abs());
          _setFunctionModule(xx, yy, dist != 2 && dist != 4);
        }
      }
    }
  }

  void _drawAlignmentPattern(int x, int y) {
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        _setFunctionModule(x + dx, y + dy, math.max(dx.abs(), dy.abs()) != 1);
      }
    }
  }

  List<int> _alignmentPatternPositions() {
    if (version == 1) return const [];
    final numAlign = version ~/ 7 + 2;
    final step = version == 32
        ? 26
        : ((version * 4 + numAlign * 2 + 1) ~/ (numAlign * 2 - 2)) * 2;
    final result = <int>[];
    for (var i = 0; i < numAlign - 1; i++) {
      result.add(size - 7 - i * step);
    }
    result.add(6);
    return result.reversed.toList();
  }

  void _drawCodewords(List<int> data) {
    var i = 0, right = size - 1;
    while (right >= 1) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        for (var j = 0; j < 2; j++) {
          final x = right - j,
              upward = ((right + 1) & 2) == 0,
              y = upward ? size - 1 - vert : vert;
          if (!isFunction[y * size + x] && i < data.length * 8) {
            _setModule(x, y, _bit(data[i ~/ 8], 7 - i % 8));
            i++;
          }
        }
      }
      right -= 2;
    }
  }

  void _applyMask(int mask) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final invert = switch (mask) {
          0 => (x + y) % 2 == 0,
          1 => y % 2 == 0,
          2 => x % 3 == 0,
          3 => (x + y) % 3 == 0,
          4 => (x ~/ 3 + y ~/ 2) % 2 == 0,
          5 => (x * y) % 2 + (x * y) % 3 == 0,
          6 => ((x * y) % 2 + (x * y) % 3) % 2 == 0,
          _ => ((x + y) % 2 + (x * y) % 3) % 2 == 0
        };
        final index = y * size + x;
        if (invert && !isFunction[index]) modules[index] = !modules[index];
      }
    }
  }

  int _penaltyScore() {
    var result = 0;
    for (var y = 0; y < size; y++) {
      var runColor = false, runX = 0;
      final history = _FinderPenalty(size);
      for (var x = 0; x < size; x++) {
        if (getModule(x, y) == runColor) {
          runX++;
          if (runX == 5) {
            result += 3;
          } else if (runX > 5) {
            result++;
          }
        } else {
          history.add(runX);
          if (!runColor) {
            result += history.countPatterns() * 40;
          }
          runColor = getModule(x, y);
          runX = 1;
        }
      }
      result += history.terminateAndCount(runColor, runX) * 40;
    }
    for (var x = 0; x < size; x++) {
      var runColor = false, runY = 0;
      final history = _FinderPenalty(size);
      for (var y = 0; y < size; y++) {
        if (getModule(x, y) == runColor) {
          runY++;
          if (runY == 5) {
            result += 3;
          } else if (runY > 5) {
            result++;
          }
        } else {
          history.add(runY);
          if (!runColor) {
            result += history.countPatterns() * 40;
          }
          runColor = getModule(x, y);
          runY = 1;
        }
      }
      result += history.terminateAndCount(runColor, runY) * 40;
    }
    for (var y = 0; y < size - 1; y++) {
      for (var x = 0; x < size - 1; x++) {
        final color = getModule(x, y);
        if (color == getModule(x + 1, y) &&
            color == getModule(x, y + 1) &&
            color == getModule(x + 1, y + 1)) {
          result += 3;
        }
      }
    }
    final dark = modules.where((value) => value).length, total = size * size;
    final k = (((dark * 20 - total * 10).abs() + total - 1) ~/ total) - 1;
    return result + k * 10;
  }

  static _QrCode encodeText(String text) {
    final segment = _QrSegment.make(text);
    var version = 1;
    var ecc = _Ecc.low;
    late int dataUsedBits;
    while (true) {
      final capacity = _numDataCodewords(version, ecc) * 8,
          used = segment.totalBits(version);
      if (used <= capacity) {
        dataUsedBits = used;
        break;
      }
      version++;
      if (version > 40) throw StateError('qr data too long');
    }
    for (final newEcc in [_Ecc.medium, _Ecc.quartile, _Ecc.high]) {
      if (dataUsedBits <= _numDataCodewords(version, newEcc) * 8) ecc = newEcc;
    }
    return _encodeCodewords(
        version, ecc, _buildDataCodewords(segment, version, ecc));
  }

  static _QrCode _encodeCodewords(int version, _Ecc ecc, List<int> data) {
    final qr = _QrCode(version, ecc);
    qr._drawFunctionPatterns();
    qr._drawCodewords(qr._addEccAndInterleave(data));
    var bestMask = 0, bestPenalty = 1 << 30;
    for (var mask = 0; mask < 8; mask++) {
      qr._applyMask(mask);
      qr._drawFormatBits(mask);
      final penalty = qr._penaltyScore();
      if (penalty < bestPenalty) {
        bestMask = mask;
        bestPenalty = penalty;
      }
      qr._applyMask(mask);
    }
    qr._applyMask(bestMask);
    qr._drawFormatBits(bestMask);
    return qr;
  }

  static List<int> _buildDataCodewords(
      _QrSegment segment, int version, _Ecc ecc) {
    final bits = <bool>[];
    _appendBits(bits, segment.modeBits, 4);
    _appendBits(bits, segment.numChars, segment.charCountBits(version));
    bits.addAll(segment.data);
    final capacity = _numDataCodewords(version, ecc) * 8;
    _appendBits(bits, 0, math.min(4, capacity - bits.length));
    _appendBits(bits, 0, (-bits.length) & 7);
    var pad = 0;
    while (bits.length < capacity) {
      _appendBits(bits, pad % 2 == 0 ? 0xec : 0x11, 8);
      pad++;
    }
    final out = List<int>.filled(bits.length ~/ 8, 0);
    for (var i = 0; i < bits.length; i++) {
      if (bits[i]) out[i ~/ 8] |= 1 << (7 - i % 8);
    }
    return out;
  }

  static void _appendBits(List<bool> bits, int value, int length) {
    for (var i = length - 1; i >= 0; i--) {
      bits.add(((value >> i) & 1) != 0);
    }
  }

  static int _rawDataModules(int version) {
    var result = (16 * version + 128) * version + 64;
    if (version >= 2) {
      final numAlign = version ~/ 7 + 2;
      result -= (25 * numAlign - 10) * numAlign - 55;
      if (version >= 7) result -= 36;
    }
    return result;
  }

  static int _numDataCodewords(int version, _Ecc ecc) =>
      _rawDataModules(version) ~/ 8 -
      _eccCodewords[ecc.index][version] * _numBlocks[ecc.index][version];
  List<int> _addEccAndInterleave(List<int> data) {
    final numBlocks = _numBlocks[ecc.index][version],
        blockEccLen = _eccCodewords[ecc.index][version],
        rawCodewords = _rawDataModules(version) ~/ 8,
        numShortBlocks = numBlocks - rawCodewords % numBlocks,
        shortBlockLen = rawCodewords ~/ numBlocks,
        divisor = _reedSolomonDivisor(blockEccLen);
    final blocks = <List<int>>[];
    var k = 0;
    for (var i = 0; i < numBlocks; i++) {
      final dataLen =
              shortBlockLen - blockEccLen + (i >= numShortBlocks ? 1 : 0),
          block = List<int>.filled(
              dataLen + blockEccLen + (i < numShortBlocks ? 1 : 0), 0);
      for (var j = 0; j < dataLen; j++) {
        block[j] = data[k++];
      }
      final remainder =
          _reedSolomonRemainder(block.sublist(0, dataLen), divisor);
      var offset = dataLen;
      if (i < numShortBlocks) offset++;
      for (var j = 0; j < remainder.length; j++) {
        block[offset + j] = remainder[j];
      }
      blocks.add(block);
    }
    final result = <int>[];
    for (var i = 0; i <= shortBlockLen; i++) {
      for (var j = 0; j < blocks.length; j++) {
        if (i != shortBlockLen - blockEccLen || j >= numShortBlocks) {
          result.add(blocks[j][i]);
        }
      }
    }
    return result;
  }

  static List<int> _reedSolomonDivisor(int degree) {
    final result = List<int>.filled(degree, 0);
    result[degree - 1] = 1;
    var root = 1;
    for (var i = 0; i < degree; i++) {
      for (var j = 0; j < degree; j++) {
        result[j] = _reedSolomonMultiply(result[j], root);
        if (j + 1 < degree) result[j] ^= result[j + 1];
      }
      root = _reedSolomonMultiply(root, 2);
    }
    return result;
  }

  static List<int> _reedSolomonRemainder(List<int> data, List<int> divisor) {
    final result = List<int>.filled(divisor.length, 0);
    for (final b in data) {
      final factor = b ^ result[0];
      for (var i = 0; i < result.length - 1; i++) {
        result[i] = result[i + 1];
      }
      result[result.length - 1] = 0;
      for (var i = 0; i < result.length; i++) {
        result[i] ^= _reedSolomonMultiply(divisor[i], factor);
      }
    }
    return result;
  }

  static int _reedSolomonMultiply(int x, int y) {
    var z = 0;
    for (var i = 7; i >= 0; i--) {
      z = ((z << 1) ^ ((z >> 7) * 0x1d)) & 0xff;
      z ^= (((y >> i) & 1) * x);
    }
    return z;
  }

  static bool _bit(int value, int index) => ((value >> index) & 1) != 0;
}

class _FinderPenalty {
  _FinderPenalty(this.qrSize);
  final int qrSize;
  final runHistory = List<int>.filled(7, 0);
  void add(int input) {
    var length = input;
    if (runHistory[0] == 0) length += qrSize;
    for (var i = runHistory.length - 2; i >= 0; i--) {
      runHistory[i + 1] = runHistory[i];
    }
    runHistory[0] = length;
  }

  int countPatterns() {
    final n = runHistory[1],
        core = n > 0 &&
            runHistory[2] == n &&
            runHistory[3] == n * 3 &&
            runHistory[4] == n &&
            runHistory[5] == n;
    return (core && runHistory[0] >= n * 4 && runHistory[6] >= n ? 1 : 0) +
        (core && runHistory[6] >= n * 4 && runHistory[0] >= n ? 1 : 0);
  }

  int terminateAndCount(bool currentColor, int input) {
    var length = input;
    if (currentColor) {
      add(length);
      length = 0;
    }
    length += qrSize;
    add(length);
    return countPatterns();
  }
}

class _QrSegment {
  const _QrSegment(this.modeBits, this.numChars, this.data);
  final int modeBits;
  final int numChars;
  final List<bool> data;
  int charCountBits(int version) {
    final index = (version + 7) ~/ 17;
    if (modeBits == 1) return [10, 12, 14][index];
    if (modeBits == 2) return [9, 11, 13][index];
    return [8, 16, 16][index];
  }

  int totalBits(int version) => 4 + charCountBits(version) + data.length;
  static const alphanumericCharset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ ' r'$%*+-./:';
  static _QrSegment make(String text) {
    if (text.isNotEmpty &&
        text
            .split('')
            .every((ch) => ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57)) {
      return _makeNumeric(text);
    }
    if (text.split('').every(alphanumericCharset.contains)) {
      return _makeAlphanumeric(text);
    }
    return _makeBytes(utf8.encode(text));
  }

  static _QrSegment _makeNumeric(String text) {
    final bits = <bool>[];
    var data = 0, count = 0;
    for (final ch in text.split('')) {
      data = data * 10 + ch.codeUnitAt(0) - 48;
      count++;
      if (count == 3) {
        _QrCode._appendBits(bits, data, 10);
        data = 0;
        count = 0;
      }
    }
    if (count > 0) _QrCode._appendBits(bits, data, count * 3 + 1);
    return _QrSegment(1, text.length, bits);
  }

  static _QrSegment _makeAlphanumeric(String text) {
    final bits = <bool>[];
    var data = 0, count = 0;
    for (final ch in text.split('')) {
      data = data * 45 + alphanumericCharset.indexOf(ch);
      count++;
      if (count == 2) {
        _QrCode._appendBits(bits, data, 11);
        data = 0;
        count = 0;
      }
    }
    if (count > 0) _QrCode._appendBits(bits, data, 6);
    return _QrSegment(2, text.length, bits);
  }

  static _QrSegment _makeBytes(List<int> data) {
    final bits = <bool>[];
    for (final value in data) {
      _QrCode._appendBits(bits, value & 0xff, 8);
    }
    return _QrSegment(4, data.length, bits);
  }
}

const _eccCodewords = <List<int>>[
  [
    -1,
    7,
    10,
    15,
    20,
    26,
    18,
    20,
    24,
    30,
    18,
    20,
    24,
    26,
    30,
    22,
    24,
    28,
    30,
    28,
    28,
    28,
    26,
    30,
    30,
    26,
    28,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30
  ],
  [
    -1,
    10,
    16,
    26,
    18,
    24,
    16,
    18,
    22,
    22,
    26,
    30,
    22,
    22,
    24,
    24,
    28,
    28,
    26,
    26,
    26,
    26,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28,
    28
  ],
  [
    -1,
    13,
    22,
    18,
    26,
    18,
    24,
    18,
    22,
    20,
    24,
    28,
    26,
    24,
    20,
    30,
    24,
    28,
    28,
    26,
    30,
    28,
    30,
    30,
    30,
    30,
    28,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30
  ],
  [
    -1,
    17,
    28,
    22,
    16,
    22,
    28,
    26,
    26,
    24,
    28,
    24,
    28,
    22,
    24,
    24,
    30,
    28,
    28,
    26,
    28,
    30,
    24,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30,
    30
  ],
];
const _numBlocks = <List<int>>[
  [
    -1,
    1,
    1,
    1,
    1,
    1,
    2,
    2,
    2,
    2,
    4,
    4,
    4,
    4,
    4,
    6,
    6,
    6,
    6,
    7,
    8,
    8,
    9,
    9,
    10,
    12,
    12,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    19,
    20,
    21,
    22,
    24,
    25
  ],
  [
    -1,
    1,
    1,
    1,
    2,
    2,
    4,
    4,
    4,
    5,
    5,
    5,
    8,
    9,
    9,
    10,
    10,
    11,
    13,
    14,
    16,
    17,
    17,
    18,
    20,
    21,
    23,
    25,
    26,
    28,
    29,
    31,
    33,
    35,
    37,
    38,
    40,
    43,
    45,
    47,
    49
  ],
  [
    -1,
    1,
    1,
    2,
    2,
    4,
    4,
    6,
    6,
    8,
    8,
    8,
    10,
    12,
    16,
    12,
    17,
    16,
    18,
    21,
    20,
    23,
    23,
    25,
    27,
    29,
    34,
    34,
    35,
    38,
    40,
    43,
    45,
    48,
    51,
    53,
    56,
    59,
    62,
    65,
    68
  ],
  [
    -1,
    1,
    1,
    2,
    4,
    4,
    4,
    5,
    6,
    8,
    8,
    11,
    11,
    16,
    16,
    18,
    16,
    19,
    21,
    25,
    25,
    25,
    34,
    30,
    32,
    35,
    37,
    40,
    42,
    45,
    48,
    51,
    54,
    57,
    60,
    63,
    66,
    70,
    74,
    77,
    81
  ],
];
