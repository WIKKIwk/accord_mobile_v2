import 'dart:math' as math;

/// XP-P323B WIP label: 70 x 50 mm at 8 dots/mm.
class BluetoothProgressLayout {
  const BluetoothProgressLayout(this.lines, this.codeY, this.codeX);

  final List<Map<String, Object>> lines;
  final int codeY;
  final int codeX;
}

BluetoothProgressLayout buildBluetoothProgressLayout(
    Map<String, Object> payload) {
  String value(String key) => (payload[key]?.toString() ?? '').trim();
  final rawProduct =
      value('item_name').isNotEmpty ? value('item_name') : value('item_code');
  final customer =
      value('customer_name').isEmpty ? '-' : value('customer_name');
  var product = rawProduct;
  for (final marker in const [
    ' YARIM TAYYOR MAHSULOT',
    ' YARIM TAYYOR',
    ' TAYYOR MAHSULOT',
    ', APPARAT:',
    ', REZKA HOLATDA',
  ]) {
    final index = product.indexOf(marker);
    if (index > 0) product = product.substring(0, index);
  }
  product = product.replaceFirst(RegExp(r'[ ,\-]+$'), '').trim();
  if (product.isEmpty) product = rawProduct.isEmpty ? '-' : rawProduct;

  var apparatus = value('apparatus_display_name');
  if (apparatus.isEmpty) apparatus = value('apparatus');
  if (apparatus.isEmpty) {
    final marker = rawProduct.indexOf(', APPARAT:');
    if (marker >= 0) {
      apparatus = rawProduct
          .substring(marker + ', APPARAT:'.length)
          .split(',')
          .first
          .trim();
    }
  }
  apparatus = switch (apparatus) {
    '7 TA RANGLI BOSMA' || '7 TA RANGLI BOSMA APARAT' => '7TALIK BOSMA',
    '8 TA RANGLI BOSMA' || '8 TA RANGLI BOSMA APARAT' => '8TALIK BOSMA',
    '9 TA RANGLI BOSMA' || '9 TA RANGLI BOSMA APARAT' => '9TALIK BOSMA',
    '' => '-',
    _ => apparatus,
  };
  final status = rawProduct.contains('YARIM TAYYOR')
      ? 'YARIM TAYYOR'
      : rawProduct.contains('TAYYOR')
          ? 'TAYYOR MAHSULOT'
          : 'YARIM TAYYOR';
  final gross = (payload['gross_qty'] as num?)?.toDouble() ?? 0;
  final tare = (payload['tare_kg'] as num?)?.toDouble() ?? 0;
  final net = math.max(0.0, gross - tare);
  final progress = (payload['progress_qty'] as num?)?.toDouble() ?? net;
  final weightUnit = value('unit').isEmpty ? 'KG' : value('unit');
  final progressUnit =
      value('progress_unit').isEmpty ? 'M' : value('progress_unit');
  String quantity(double amount) => amount.toStringAsFixed(2);

  final primary = <String>[
    'APARAT: $apparatus',
    'MAHSULOT NOMI: $customer - $product',
    'METRAJ: ${quantity(progress)} $progressUnit',
    'NETTO: ${quantity(net)} $weightUnit',
    'BRUTTO: ${quantity(gross)} $weightUnit',
  ];
  final secondary = <String>[
    'HOLAT: $status',
    if (value('completed_at_label').isNotEmpty)
      'TUGATILDI: ${value('completed_at_label')}',
    'ISH KODI: ${value('order_code').isEmpty ? '-' : value('order_code')}',
  ];

  const left = 8;
  const rightMargin = 12;
  const labelWidth = 560;
  const top = 12;
  const bottom = 12;
  const symbolSize = 104;
  const codeGap = 12;
  const footerGap = 8;
  const footerHeight = 24;
  const fieldGap = 3;
  const latestCodeY = 400 - bottom - symbolSize - footerGap - footerHeight;
  const maxTextEnd = latestCodeY - codeGap;
  for (final size in const [
    (name: 'large', height: 24, width: 16),
    // XP-P323B can render its 12x20 font wider than twelve dots.
    (name: 'medium', height: 20, width: 16),
    (name: 'small', height: 12, width: 8),
  ]) {
    final output = <Map<String, Object>>[];
    var y = top;
    void append(List<String> fields, String font, int height, int charWidth) {
      final columns = (labelWidth - left - rightMargin - 1) ~/ charWidth;
      for (final field in fields) {
        for (final line in _wrap(field, columns)) {
          output.add(
              {'text': line, 'y': y, 'font': font, 'char_width': charWidth});
          y += height;
        }
        y += fieldGap;
      }
    }

    append(primary, size.name, size.height, size.width);
    append(secondary, 'medium', 20, 16);
    y -= fieldGap;
    if (y <= maxTextEnd) {
      // The existing row starts at 92 dots. Move it left by one millimeter.
      return BluetoothProgressLayout(output, math.max(236, y + codeGap), 84);
    }
  }
  throw StateError('WIP label matni 70 x 50 mm qog‘ozga sig‘madi');
}

List<String> _wrap(String text, int width) {
  final lines = <String>[];
  var current = '';
  for (final word
      in text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty)) {
    var rest = word;
    while (rest.length > width) {
      if (current.isNotEmpty) {
        lines.add(current);
        current = '';
      }
      lines.add(rest.substring(0, width));
      rest = rest.substring(width);
    }
    final candidate = current.isEmpty ? rest : '$current $rest';
    if (candidate.length <= width) {
      current = candidate;
    } else {
      lines.add(current);
      current = rest;
    }
  }
  if (current.isNotEmpty) lines.add(current);
  return lines;
}
