import 'package:accord_mobile_v2/src/core/printing/progress_bluetooth_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object> payload(
          {String product = 'ZIZI SPONGE YARIM TAYYOR MAHSULOT'}) =>
      {
        'item_name': product,
        'item_code': 'INTERNAL-ID',
        'order_code': 'WORK-42',
        'customer_name': 'MIJOZ',
        'apparatus_display_name': '8 TA RANGLI BOSMA',
        'gross_qty': 100.0,
        'tare_kg': 5.0,
        'progress_qty': 1250.0,
        'unit': 'KG',
        'progress_unit': 'M',
        'completed_at_label': '31.10.2026 14:30',
      };

  void expectLayoutFits(BluetoothProgressLayout layout) {
    final lines = layout.lines;
    expect(lines.first['y'], 12);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final y = line['y'] as int;
      final font = line['font'] as String;
      final height = font == 'large'
          ? 24
          : font == 'medium'
              ? 20
              : 12;
      final width = line['char_width'] as int;
      expect(8 + (line['text'] as String).length * width + 1,
          lessThanOrEqualTo(548));
      if (i + 1 < lines.length) {
        expect(y + height, lessThanOrEqualTo(lines[i + 1]['y'] as int));
      } else {
        expect(y + height + 12, lessThanOrEqualTo(layout.codeY));
      }
    }
    expect(layout.codeY, inInclusiveRange(236, 252));
    expect(layout.codeY + 104 + 8 + 24, lessThanOrEqualTo(388));
  }

  test('orders the fields and keeps details small inside the 50 mm label', () {
    final layout = buildBluetoothProgressLayout(payload());
    final texts = layout.lines.map((line) => line['text']).toList();
    expect(texts, [
      'APARAT: 8TALIK BOSMA',
      'MAHSULOT NOMI: MIJOZ - ZIZI',
      'SPONGE',
      'METRAJ: 1250.00 M',
      'NETTO: 95.00 KG',
      'BRUTTO: 100.00 KG',
      'HOLAT: YARIM TAYYOR',
      'TUGATILDI: 31.10.2026 14:30',
      'ISH KODI: WORK-42',
    ]);
    expect(
        layout.lines.take(6).every((line) => line['font'] != 'small'), isTrue);
    expect(
        layout.lines.skip(6).every((line) => line['font'] == 'small'), isTrue);
    expectLayoutFits(layout);
  });

  test('wraps long names and selects a size that fits without dropping text',
      () {
    const name =
        'JUDA UZUN MAHSULOT NOMI BIRINCHI QATOR IKKINCHI QATOR UCHINCHI QATOR TORTINCHI QATOR';
    final layout = buildBluetoothProgressLayout(
        payload(product: '$name YARIM TAYYOR MAHSULOT'));
    final text = layout.lines.map((line) => line['text']).join(' ');
    expect(text, contains(name));
    expect(layout.lines.first['font'], anyOf('medium', 'small'));
    expectLayoutFits(layout);
  });

  test('rejects text that cannot fit instead of cutting off the label', () {
    expect(
      () => buildBluetoothProgressLayout(
          payload(product: List.filled(100, 'MAHSULOT').join(' '))),
      throwsStateError,
    );
  });
}
