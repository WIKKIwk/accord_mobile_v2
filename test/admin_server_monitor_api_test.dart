import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('admin server monitor returns readable test mode data', () async {
    await TestModeController.instance.setEnabled(true);
    addTearDown(() async {
      await TestModeController.instance.setEnabled(false);
    });

    final report = await MobileApi.instance.adminServerMonitor();

    expect(report.server.status, 'running');
    expect(report.server.bindAddr, '127.0.0.1:8081');
    expect(report.database.reachable, isTrue);
    expect(report.database.status, 'online');
    expect(report.backups.exists, isTrue);
    expect(report.backups.fileCount, 1);
    expect(report.backups.latest?.name, endsWith('.dump'));
  });

  test('live stream watchdog fails silent streams so screen reconnects',
      () async {
    final controller = StreamController<int>();
    addTearDown(controller.close);

    await expectLater(
      withLiveStreamSilenceTimeout<int>(
        controller.stream,
        timeout: const Duration(milliseconds: 1),
      ).drain<void>(),
      throwsA(isA<TimeoutException>()),
    );
  });
}
