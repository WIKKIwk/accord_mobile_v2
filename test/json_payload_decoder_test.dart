import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/json_payload_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes small list and map payloads without changing their shape',
      () async {
    final list = await decodeJsonListPayload('[{"id":1},{"id":2}]');
    final map = await decodeJsonMapPayload('{"ok":true,"count":2}');

    expect(list, hasLength(2));
    expect((list.first as Map)['id'], 1);
    expect(map, {'ok': true, 'count': 2});
  });

  test('decodes a large payload through the background path', () async {
    final source = jsonEncode({
      'items': List.generate(
        5000,
        (index) => {'id': index, 'name': 'Mahsulot $index'},
      ),
    });

    final payload = await decodeJsonMapPayload(
      source,
      backgroundThresholdCodeUnits: 0,
    );
    final items = payload['items'] as List<dynamic>;

    expect(items, hasLength(5000));
    expect((items.last as Map)['id'], 4999);
  });
}
