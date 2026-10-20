import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _page(int offset, int total, {String version = 'v1', int revision = 1}) => {
  'version': version, 'epoch': 'server', 'rev': revision, 'offset': offset,
  'total': total, 'next_cursor': offset + 20 < total ? 'next-$revision' : null,
  'closed_orders': [for (var i = offset; i < total && i < offset + 20; i++)
    {'order_id': 'o$i', 'title': 'Order $i'}],
};
AdminProductionMapPageWindowMessage _event(String type, Map<String, dynamic> value) =>
  AdminProductionMapPageWindowMessage.fromJson({
    'type': type, 'window': 'w1', 'epoch': 'server', 'rev': 2,
    'base_version': 'v1', 'version': 'v2', ...value,
  });
List<Map<String, Object?>> _metadata(int index, {String? next}) => [
  {'op': 'set', 'path': ['version'], 'value': 'v2'},
  {'op': 'set', 'path': ['rev'], 'value': 2},
  {'op': 'set', 'path': ['next_cursor'], 'value': next},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('page checkpoint advances cursors and preserves every row object', () async {
    final before = [await AdminProductionOrderPage.fromJson(_page(0, 40)),
      await AdminProductionOrderPage.fromJson(_page(20, 40))];
    final after = await applyAdminOrderPageWindow(before,
      _event('page_window_checkpoint', {'next_cursors': ['next-2', null]}));
    expect(after.first.version, 'v2');
    expect(after.first.nextCursor, 'next-2');
    expect(identical(after.first.closedOrders, before.first.closedOrders), isTrue);
    expect(before.first.version, 'v1');
    expect(before.first.nextCursor, 'next-1');
  });
  test('sparse update changes one row and reuses metadata-only pages', () async {
    final before = [await AdminProductionOrderPage.fromJson(_page(0, 40)),
      await AdminProductionOrderPage.fromJson(_page(20, 40))];
    final after = await applyAdminOrderPageWindow(before, _event('page_window_delta', {
      'page_count': 2,
      'changes': [
        {'index': 0, 'ops': [..._metadata(0, next: 'next-2'),
          {'op': 'set', 'path': ['closed_orders', 3, 'title'], 'value': 'Updated'}]},
        {'index': 1, 'ops': _metadata(1)},
      ],
    }));
    expect(after.first.wireValue!['closed_orders'][3]['title'], 'Updated');
    expect(before.first.wireValue!['closed_orders'][3]['title'], 'Order 3');
    expect(identical(after.last.closedOrders, before.last.closedOrders), isTrue);
  });
  test('atomic prefix handles row deletion and page shrink', () async {
    final before = [await AdminProductionOrderPage.fromJson(_page(0, 25)),
      await AdminProductionOrderPage.fromJson(_page(20, 25))];
    final after = await applyAdminOrderPageWindow(before, _event('page_window_delta', {
      'page_count': 1, 'changes': [{'index': 0, 'ops': [
        {'op': 'set', 'path': [], 'value': _page(0, 19, version: 'v2', revision: 2)}]}],
    }));
    expect(after, hasLength(1));
    expect(after.single.closedOrders, hasLength(19));
    expect(after.single.nextCursor, isNull);
    expect(before, hasLength(2));
  });
  test('page gaps, epoch, scope, malformed paths and mixed versions reject atomically', () async {
    final before = [await AdminProductionOrderPage.fromJson(_page(0, 40)),
      await AdminProductionOrderPage.fromJson(_page(20, 40))];
    final invalid = [
      _event('page_window_checkpoint', {'base_version': 'wrong', 'next_cursors': ['n', null]}),
      _event('page_window_checkpoint', {'epoch': 'other', 'next_cursors': ['n', null]}),
      _event('page_window_checkpoint', {'rev': 1, 'next_cursors': ['n', null]}),
      _event('page_window_checkpoint', {'next_cursors': [null, null]}),
      _event('page_window_checkpoint', {'next_cursors': ['n']}),
      _event('page_window_delta', {'page_count': 2, 'changes': [
        {'index': 0, 'ops': [{'op': 'set', 'path': ['closed_orders', 30, 'title'], 'value': 'bad'}]}]}),
      _event('page_window_delta', {'page_count': 2, 'changes': [
        {'index': 0, 'ops': _metadata(0, next: 'n')}]}),
      _event('page_window_delta', {'page_count': 2, 'changes': [
        {'index': 0, 'ops': _metadata(0, next: 'n')}, {'index': 0, 'ops': _metadata(0, next: 'n')}]}),
    ];
    for (final event in invalid) {
      await expectLater(applyAdminOrderPageWindow(before, event), throwsA(isA<MobileApiException>()));
      expect(before.first.version, 'v1');
      expect(before.first.wireValue!['closed_orders'][3]['title'], 'Order 3');
    }
  });
}
