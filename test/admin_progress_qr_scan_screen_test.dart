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

  test('finished output explains warehouse acceptance without WIP wording', () {
    expect(
      progressQrHumanStatusLabel(
        workStatus: 'completed',
        flowStatus: 'finished_pending_acceptance',
        wipStatus: 'waiting',
      ),
      'Ishi tugagan, ombor qabulini kutmoqda',
    );

    expect(
      progressQrTechnicalProductStatusLabel(
        workStatus: 'completed',
        flowStatus: 'finished_pending_acceptance',
        wipStatus: 'waiting',
      ),
      'Yarim tayyor mahsulot holati: ombor qabulini kutmoqda',
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
}
