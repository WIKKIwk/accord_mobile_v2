import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_wip_batches_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current location filter keeps only canonical location matches', () {
    final batches = [
      _batch('one', '7 ta rangli pechat chiqim'),
      _batch('two', 'Laminatsiya 1'),
      _batch('three', '7 ta rangli pechat'),
      _batch('four', '7 ta rangli pechat chiqim', wipStatus: 'in_use'),
    ];

    final filtered = filterWipBatchesForWaitingDisplay(
      batches,
      '7 ta rangli pechat chiqim',
    );

    expect(filtered.map((batch) => batch.batchId), ['one', 'three']);
    expect(
      filtered.every(
        (batch) =>
            canonicalWaitingLocation(batch) == '7 ta rangli pechat chiqim',
      ),
      isTrue,
    );
    expect(filtered.every((batch) => batch.wipStatus == 'waiting'), isTrue);
  });

  test('empty current location filter keeps only waiting list', () {
    final batches = [
      _batch('one', '7 ta rangli pechat chiqim'),
      _batch('two', 'Laminatsiya 1', wipStatus: 'processed'),
      _batch('three', 'Laminatsiya 1'),
    ];

    final filtered = filterWipBatchesForWaitingDisplay(batches, '');

    expect(filtered.map((batch) => batch.batchId), ['one', 'three']);
    expect(filtered.every((batch) => batch.wipStatus == 'waiting'), isTrue);
  });

  test('waiting location canonicalizes legacy apparatus-only location', () {
    final batch = _batch('one', '7 ta rangli pechat');

    expect(canonicalWaitingLocation(batch), '7 ta rangli pechat chiqim');
  });
}

AdminProgressBatch _batch(
  String id,
  String currentLocation, {
  String wipStatus = 'waiting',
}) {
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
    wipStatus: wipStatus,
    currentApparatus: '7 ta rangli pechat',
    currentLocation: currentLocation,
  );
}
