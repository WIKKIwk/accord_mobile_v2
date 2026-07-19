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
      'Ishlab chiqarish bosqichi tugagan, erkin WIP holatida',
    );

    expect(
      progressQrTechnicalProductStatusLabel(
        workStatus: 'completed',
        flowStatus: 'free_wip',
        wipStatus: 'waiting',
      ),
      'Yarim tayyor mahsulot holati: erkin WIP holatida',
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
