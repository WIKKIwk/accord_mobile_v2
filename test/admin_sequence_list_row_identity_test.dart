import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unchanged summary reuses its presentation shell across rebuilds', () {
    final row = AdminSequenceListRow.fromJson({
      'id': 'zakaz-1',
      'code': '1',
      'title': 'Product',
      'customer_name': 'Customer',
      'image_id': '',
      'queue_state': 'pending',
      'display_state': 'pending',
      'can_reorder': true,
      'frozen': false,
    });
    final first = row.toPresentationOrder();
    expect(identical(first, row.toPresentationOrder()), isTrue);
    expect(first.map.nodes, isEmpty);
    expect(first.program.operations, isEmpty);
    final changed = AdminSequenceListRow.fromJson({
      'id': 'zakaz-1',
      'code': '1',
      'title': 'Changed product',
      'customer_name': 'Customer',
      'image_id': '',
      'queue_state': 'pending',
      'display_state': 'pending',
      'can_reorder': true,
      'frozen': false,
    });
    expect(identical(first, changed.toPresentationOrder()), isFalse);
    expect(changed.toPresentationOrder().map.title, 'Changed product');
  });
}
