import 'dart:async';
import 'dart:math';

import 'package:accord_mobile_v2/src/features/qolip/qolip_search_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/qolip_search_reference.dart' as legacy;

void main() {
  test('optimized search preserves the legacy match set', () {
    final random = Random(4721);
    String word(int length) =>
        List.generate(length, (_) => 'abcde'[random.nextInt(5)]).join();
    const special = [
      'кросс',
      'кrоss',
      'rhjcc',
      'лкщыы',
      'Q-001',
      'Q 0-0 1',
      'model kroos',
      'iskndar kroos',
      'kr oss',
      '',
      '   '
    ];
    for (var i = 0; i < 3500; i++) {
      final value = word(1 + random.nextInt(24));
      final values = [
        value,
        word(1 + random.nextInt(12)),
        'Kross model',
        'Customer Iskandar',
        'Q-001'
      ];
      final query = i < special.length
          ? special[i]
          : switch (i % 4) {
              0 => word(3 + random.nextInt(13)),
              1 =>
                value.length > 3 ? value.substring(1, value.length - 1) : value,
              2 => value.length > 3
                  ? '${value[1]}${value[0]}${value.substring(2)}'
                  : value,
              _ => '${word(3)} ${word(4)}',
            };
      expect(QolipSearchQuery(query).matches(QolipSearchDocument(values)),
          legacy.qolipSearchMatches(query, values),
          reason: '$query / $values');
    }
  });

  test('large scans yield to input and abandon superseded searches', () async {
    final values = List.generate(
        20000, (i) => QolipSearchDocument(['Mahsulot $i', 'Q-$i']));
    var current = true;
    var visited = 0;
    Timer.run(() => current = false);
    final matches = await filterQolipSearch(values, 'topilmaydigan', (value) {
      visited++;
      return value;
    }, isCurrent: () => current);
    expect(matches, isNull);
    expect(visited, lessThan(values.length));
  });

  test('sliced filtering preserves input order and duplicate records',
      () async {
    final values = ['Kross', 'Botinka', 'Kross', 'кросс'];
    expect(
        await filterQolipSearch(
            values, 'kroos', (value) => QolipSearchDocument([value])),
        ['Kross', 'Kross', 'кросс']);
    expect(
        await filterQolipSearch(values, '',
            (value) => throw StateError('empty query must not index records')),
        values);
  });
}
