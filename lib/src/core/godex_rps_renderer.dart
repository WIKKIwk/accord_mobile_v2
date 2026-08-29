import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'native_usb_printer.dart';

part 'godex_rps_renderer_declarations_part_01.dart';
part 'godex_rps_renderer_declarations_part_02.dart';
part 'godex_rps_renderer_declarations_part_03.dart';

/// Produces the raw EZPL stream used by the Android Godex printer path.
///
/// Keep this renderer byte-compatible with GodexRpsRenderer.kt. Transport is
/// deliberately outside this class so web preview and Android send the same
/// bytes to different USB transports.
class GodexRpsRenderer {
  const GodexRpsRenderer._();

  static const _legacyGraphicNames = _GodexGraphicNames(
    text: 'TEXTLBL',
    qr: 'QRLBL',
  );
  static int _androidGraphicSequence = 0;

  static QrCodeMatrix qrMatrix(String payload) {
    final normalized = _uppercaseClean(payload);
    if (normalized.isEmpty) {
      throw StateError('qr payload is empty');
    }
    final qr = _QrCode.encodeText(normalized);
    return QrCodeMatrix._(
      qr.size,
      List<bool>.generate(
        qr.size * qr.size,
        (index) => qr.getModule(index % qr.size, index ~/ qr.size),
        growable: false,
      ),
    );
  }

  static Uint8List render(UsbRpsPrintRequest request) {
    return _renderJob(
      request,
      graphicNames: _legacyGraphicNames,
      deleteExistingGraphics: true,
      includeFinalStatus: true,
    ).bytes;
  }

  static GodexRpsPrintJob renderAndroid(
    UsbRpsPrintRequest request, {
    String? graphicToken,
  }) {
    return _renderJob(
      request,
      graphicNames: _androidGraphicNames(graphicToken),
      deleteExistingGraphics: false,
      includeFinalStatus: true,
    );
  }

  static GodexRpsPrintJob _renderJob(
    UsbRpsPrintRequest request, {
    required _GodexGraphicNames graphicNames,
    required bool deleteExistingGraphics,
    required bool includeFinalStatus,
  }) {
    if (request.isQolipCellLabel) {
      return _renderQolipCell(
        request,
        graphicNames: graphicNames,
        deleteExistingGraphics: deleteExistingGraphics,
        includeFinalStatus: includeFinalStatus,
      );
    }
    if (request.isQolipCodeLabel ||
        request.isPaddonCodeLabel ||
        request.isMaterialProductLabel) {
      return _renderQolipCode(
        request,
        graphicNames: graphicNames,
        deleteExistingGraphics: deleteExistingGraphics,
        includeFinalStatus: includeFinalStatus,
      );
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
    if (deleteExistingGraphics) {
      send('~MDELG,${graphicNames.text}');
    }
    send('~EB,${graphicNames.text},${textGraphic.length}');
    out.add(textGraphic);
    if (deleteExistingGraphics) {
      send('~MDELG,${graphicNames.qr}');
    }
    send('~EB,${graphicNames.qr},${qrGraphic.length}');
    out.add(qrGraphic);
    final commands = request.isProgressLabel
        ? _buildProgressCommands(
            content,
            graphicNames: graphicNames,
            grossQty: request.grossQty,
            progressQty: request.effectiveProgressQty,
            progressUnit: request.progressUnit.trim().isEmpty
                ? request.unit
                : request.progressUnit,
          )
        : _buildPackCommands(content, graphicNames: graphicNames);
    for (final command in commands) {
      send(command);
    }
    if (includeFinalStatus) {
      send('~S,STATUS');
    }
    return GodexRpsPrintJob(
      bytes: out.takeBytes(),
      graphicNames: graphicNames.values,
      labelCount: 1,
    );
  }

  static GodexRpsPrintJob _renderQolipCell(
    UsbRpsPrintRequest request, {
    required _GodexGraphicNames graphicNames,
    required bool deleteExistingGraphics,
    required bool includeFinalStatus,
  }) {
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
    if (deleteExistingGraphics) {
      send('~MDELG,${graphicNames.text}');
    }
    send('~EB,${graphicNames.text},${textGraphic.length}');
    out.add(textGraphic);
    if (deleteExistingGraphics) {
      send('~MDELG,${graphicNames.qr}');
    }
    send('~EB,${graphicNames.qr},${qrGraphic.length}');
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
    send('Y0,0,${graphicNames.text}');
    send('Y56,96,${graphicNames.qr}');
    send('E');
    if (includeFinalStatus) {
      send('~S,STATUS');
    }
    return GodexRpsPrintJob(
      bytes: out.takeBytes(),
      graphicNames: graphicNames.values,
      labelCount: 1,
    );
  }

  static GodexRpsPrintJob _renderQolipCode(
    UsbRpsPrintRequest request, {
    required _GodexGraphicNames graphicNames,
    required bool deleteExistingGraphics,
    required bool includeFinalStatus,
  }) {
    final name = _uppercaseClean(
      request.isMaterialProductLabel
          ? request.materialProductLabelTitle
          : request.itemName.trim().isEmpty
              ? request.itemCode
              : request.itemName,
    );
    final payload = _uppercaseClean(request.epc);
    if (payload.isEmpty) {
      throw StateError('qr payload is empty');
    }
    final footer = _uppercaseClean(request.largeQrLabelFooter(payload));
    final textGraphic = _renderQolipCodeTextGraphic(name, footer);
    final qrGraphic = _renderQrGraphic(payload, 288);
    final out = BytesBuilder(copy: false);

    void send(String command) {
      out.add(_ascii(command.replaceFirst(RegExp(r'[\r\n]+$'), '')));
      out.addByte(13);
      out.addByte(10);
    }

    send('^XSET,BUZZER,0');
    if (deleteExistingGraphics) {
      send('~MDELG,${graphicNames.text}');
    }
    send('~EB,${graphicNames.text},${textGraphic.length}');
    out.add(textGraphic);
    if (deleteExistingGraphics) {
      send('~MDELG,${graphicNames.qr}');
    }
    send('~EB,${graphicNames.qr},${qrGraphic.length}');
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
    send('Y0,0,${graphicNames.text}');
    send('Y56,56,${graphicNames.qr}');
    send('E');
    if (includeFinalStatus) {
      send('~S,STATUS');
    }
    return GodexRpsPrintJob(
      bytes: out.takeBytes(),
      graphicNames: graphicNames.values,
      labelCount: 1,
    );
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

    final nameLines = _wrapTextForEzpl(name, width, 1, 18, 22).take(2);
    var lineIndex = 0;
    for (final line in nameLines) {
      drawCentered(line, lineIndex * 28, scale: 3);
      lineIndex++;
    }
    drawCentered(code, 352, scale: code.length > 33 ? 1 : 2);
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

  static GodexRpsPrintJob renderAndroidRepeated(
    UsbRpsPrintRequest request,
  ) {
    final output = BytesBuilder(copy: false);
    final graphicNames = <String>[];
    final count = request.printCount > 0 ? request.printCount : 1;
    for (var index = 0; index < count; index++) {
      final names = _androidGraphicNames(null);
      final rendered = _renderJob(
        request,
        graphicNames: names,
        deleteExistingGraphics: false,
        includeFinalStatus: index == count - 1,
      );
      output.add(rendered.bytes);
      graphicNames.addAll(rendered.graphicNames);
    }
    return GodexRpsPrintJob(
      bytes: output.takeBytes(),
      graphicNames: List.unmodifiable(graphicNames),
      labelCount: count,
    );
  }

  static List<String> _buildPackCommands(
    _PackLabelContent content, {
    required _GodexGraphicNames graphicNames,
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
      'Y0,0,${graphicNames.text}',
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
    commands.add('Y224,224,${graphicNames.qr}');
    commands.add('E');
    return commands;
  }

  static List<String> _buildProgressCommands(
    _PackLabelContent content, {
    required _GodexGraphicNames graphicNames,
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
      'Y0,0,${graphicNames.text}',
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
    commands.add('Y224,224,${graphicNames.qr}');
    commands.add('E');
    return commands;
  }

  static _GodexGraphicNames _androidGraphicNames(String? graphicToken) {
    final rawToken = graphicToken ?? _nextAndroidGraphicToken();
    var token = rawToken.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    if (token.isEmpty) {
      token = '0';
    }
    if (token.length > 18) {
      token = token.substring(token.length - 18);
    }
    return _GodexGraphicNames(text: 'T$token', qr: 'Q$token');
  }

  static String _nextAndroidGraphicToken() {
    _androidGraphicSequence = (_androidGraphicSequence + 1) & 0xFFFFF;
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final sequence = _androidGraphicSequence.toRadixString(36).padLeft(4, '0');
    return '$micros$sequence';
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
