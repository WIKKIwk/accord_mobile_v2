import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_progress_qr_scan_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed progress QR keeps batch status over waiting queue state', () {
    expect(
      progressQrBatchDisplayState(
        batchStatus: 'completed',
        queueState: 'waiting',
      ),
      'completed',
    );
  });

  test('progress QR uses queue state only when batch status is empty', () {
    expect(
      progressQrBatchDisplayState(
        batchStatus: '',
        queueState: 'in_progress',
      ),
      'in_progress',
    );
  });

  test('finished output remains free WIP without assuming a warehouse', () {
    expect(
      progressQrHumanStatusLabel(
        workStatus: 'completed',
        flowStatus: 'free_wip',
        wipStatus: 'waiting',
      ),
      'Ishlab chiqarish tugagan, omborga topshirishni kutmoqda',
    );

    expect(
      progressQrTechnicalProductStatusLabel(
        workStatus: 'completed',
        flowStatus: 'free_wip',
        wipStatus: 'waiting',
      ),
      'Tayyor mahsulot holati: erkin WIP holatida',
    );
  });

  test('intermediate output remains labelled as semi-finished', () {
    expect(
      progressQrTechnicalProductStatusLabel(
        workStatus: 'paused',
        flowStatus: 'waiting_next_stage',
        wipStatus: 'waiting',
      ),
      'Yarim tayyor mahsulot holati: keyingi bosqichni kutmoqda',
    );
  });

  test('timeline action labels are plain Uzbek production language', () {
    expect(progressQrTimelineTitle('start'), 'Bosqichdagi ish boshlandi');
    expect(
      progressQrTimelineTitle('pause'),
      'Bosqichdagi ish vaqtincha to‘xtatildi',
    );
    expect(
      progressQrTimelineTitle('resume'),
      'Bosqichdagi ish davom ettirildi',
    );
    expect(progressQrTimelineTitle('complete'), 'Bosqichdagi ish yakunlandi');
  });

  test('correction record reads the editor and reason from report JSON', () {
    final correction = AdminProgressBatchCorrectionRecord.fromJson({
      'batch_id': 'batch-1',
      'previous_revision': 1,
      'new_revision': 2,
      'reason': 'Tarozidagi qiymat qayta tekshirildi',
      'actor': {
        'role': 'admin',
        'ref_': 'admin-1',
        'display_name': 'Bosh admin',
      },
      'old_values': {'produced_qty': 100, 'uom': 'kg'},
      'new_values': {'produced_qty': 98.5, 'uom': 'kg'},
      'created_at_unix': 1710000000,
    });

    expect(correction.actorDisplayName, 'Bosh admin');
    expect(correction.actorRef, 'admin-1');
    expect(correction.reason, 'Tarozidagi qiymat qayta tekshirildi');
  });

  test('passport exposes only human-readable changed production fields', () {
    const correction = AdminProgressBatchCorrectionRecord(
      batchId: 'batch-1',
      previousRevision: 1,
      newRevision: 2,
      reason: 'Qayta o‘lchandi',
      actorRole: 'admin',
      actorRef: 'admin-1',
      actorDisplayName: 'Bosh admin',
      oldValues: {
        'produced_qty': 100,
        'uom': 'kg',
        'total_waste': 3,
        'description': '',
        'payload_json': {'technical': true},
      },
      newValues: {
        'produced_qty': 98.5,
        'uom': 'kg',
        'total_waste': 4,
        'description': 'Qayta tortildi',
        'payload_json': {'technical': false},
      },
      createdAtUnix: 1710000000,
    );

    final changes = progressQrCorrectionChanges(correction);

    expect(
      changes.map((change) => change.label),
      [
        'Ishlab chiqarilgan miqdor',
        'Jami chiqindi',
        'Izoh',
      ],
    );
    expect(changes.first.before, '100 kg');
    expect(changes.first.after, '98.5 kg');
    expect(changes.last.before, 'kiritilmagan');
    expect(changes.last.after, 'Qayta tortildi');
  });
}
