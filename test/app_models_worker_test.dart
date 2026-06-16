import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AdminWorker tolerates null phone from stale runtime objects', () {
    const worker = AdminWorker(
      id: 'worker_1',
      name: 'Ali',
      phone: null,
      level: 'Master',
    );

    expect(worker.phone, '');
    expect(worker.toJson()['phone'], '');
  });
}
