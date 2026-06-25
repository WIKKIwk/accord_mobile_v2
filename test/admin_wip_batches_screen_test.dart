import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_wip_batches_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current location filter keeps only exact location matches', () {
    final batches = [
      _batch('one', '7 ta rangli pechat chiqim'),
      _batch('two', 'Laminatsiya 1'),
      _batch('three', '7 ta rangli pechat chiqim'),
    ];

    final filtered = filterWipBatchesByCurrentLocation(
      batches,
      '7 ta rangli pechat chiqim',
    );

    expect(filtered.map((batch) => batch.batchId), ['one', 'three']);
    expect(
      filtered.every(
        (batch) => batch.currentLocation == '7 ta rangli pechat chiqim',
      ),
      isTrue,
    );
  });

  test('empty current location filter keeps original list', () {
    final batches = [
      _batch('one', '7 ta rangli pechat chiqim'),
      _batch('two', 'Laminatsiya 1'),
    ];

    final filtered = filterWipBatchesByCurrentLocation(batches, '');

    expect(identical(filtered, batches), isTrue);
  });
}

AdminProgressBatch _batch(String id, String currentLocation) {
  return AdminProgressBatch(
    batchId: id,
    sessionId: 'session-$id',
    apparatus: '7 ta rangli pechat',
    orderId: 'zakaz-$id',
    action: 'pause',
    status: 'paused',
    producedQty: 1,
    uom: 'm',
    qrPayload: 'qr-$id',
    labelItemCode: 'item-$id',
    labelItemName: 'Paynet',
    executorName: 'Operator',
    wipStatus: 'waiting',
    currentApparatus: '7 ta rangli pechat',
    currentLocation: currentLocation,
  );
}
