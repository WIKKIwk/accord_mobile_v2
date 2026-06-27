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
}
