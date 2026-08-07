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

  test('completed final output with no next apparatus stays free WIP', () {
    final batch = _batch(
      'final',
      'Laminatsiya 1 chiqim',
      action: 'complete',
      status: 'completed',
      flowStatus: 'free_wip',
    );

    expect(isFinalFreeWip(batch), isTrue);
    expect(batch.wipStatus, 'waiting');
    expect(batch.nextApparatus, isEmpty);
  });

  test('roll-completed final output with no next apparatus stays free WIP', () {
    final batch = _batch(
      'roll-final',
      'Rezka chiqim',
      action: 'roll_complete',
      status: 'completed',
      flowStatus: '',
    );

    expect(isFinalFreeWip(batch), isTrue);
  });

  test('paused final-stage output is free WIP while session is paused', () {
    final batch = _batch(
      'paused-final',
      'Rezka chiqim',
      action: 'pause',
      status: 'paused',
    );

    expect(isFinalFreeWip(batch), isTrue);
    expect(
      AdminProgressBatchStatusDetail.fromJsonOrBatchJson(const {
        'action': 'pause',
        'status': 'paused',
        'wip_status': 'waiting',
        'next_apparatus': '',
      }).flowStatus,
      'free_wip',
    );
  });

  test('paused intermediate-stage output still waits for next apparatus', () {
    final batch = _batch(
      'paused-intermediate',
      'Bosma chiqim',
      action: 'pause',
      status: 'paused',
      nextApparatus: 'Laminatsiya',
    );

    expect(isFinalFreeWip(batch), isFalse);
    expect(
      AdminProgressBatchStatusDetail.fromJsonOrBatchJson(const {
        'action': 'pause',
        'status': 'paused',
        'wip_status': 'waiting',
        'next_apparatus': 'Laminatsiya',
      }).flowStatus,
      'waiting_next_stage',
    );
  });
}

AdminProgressBatch _batch(
  String id,
  String currentLocation, {
  String wipStatus = 'waiting',
  String action = 'pause',
  String status = 'paused',
  String flowStatus = '',
  String nextApparatus = '',
}) {
  return AdminProgressBatch(
    batchId: id,
    sessionId: 'session-$id',
    apparatus: '7 ta rangli pechat',
    orderId: 'zakaz-$id',
    action: action,
    status: status,
    producedQty: 1,
    uom: 'm',
    qrPayload: 'qr-$id',
    labelItemCode: 'item-$id',
    labelItemName: 'Paynet',
    executorName: 'Operator',
    wipStatus: wipStatus,
    statusDetail: AdminProgressBatchStatusDetail(
      workStatus: status == 'completed' ? 'completed' : status,
      wipStatus: wipStatus,
      flowStatus: flowStatus,
    ),
    currentApparatus: '7 ta rangli pechat',
    currentLocation: currentLocation,
    nextApparatus: nextApparatus,
  );
}
