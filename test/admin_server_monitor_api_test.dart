import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:http/http.dart' as http;
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
    expect(report.backups.healthy, isTrue);
    expect(report.backups.snapshotCount, 1);
    expect(report.backups.snapshots, hasLength(1));
    expect(report.backups.latestSnapshot?.ready, isTrue);
    expect(report.runtime.cpuPercent, greaterThanOrEqualTo(0));
    expect(report.runtime.memoryPercent, greaterThanOrEqualTo(0));
    expect(report.runtime.memoryUsedMb, greaterThanOrEqualTo(0));
    expect(report.runtime.memoryTotalMb, greaterThanOrEqualTo(0));
    expect(report.runtime.loadAverage, greaterThanOrEqualTo(0));
    expect(report.runtime.diskPath, isNotEmpty);
    expect(report.runtime.diskPercent, greaterThanOrEqualTo(0));
    expect(report.runtime.diskUsedMb, greaterThanOrEqualTo(0));
    expect(report.runtime.diskTotalMb, greaterThanOrEqualTo(0));
    expect(report.runtime.diskAvailableMb, greaterThanOrEqualTo(0));
  });

  test('admin can start and stream a backup in test mode', () async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    addTearDown(() async {
      resetMobileApiTestModeData();
      await TestModeController.instance.setEnabled(false);
    });

    final job = await MobileApi.instance.adminStartBackup();
    final report = await MobileApi.instance.adminServerMonitor();
    final download = await MobileApi.instance.adminDownloadBackup(job.id);

    expect(job.status, 'queued');
    expect(report.backups.snapshotCount, 2);
    expect(
      report.backups.snapshots.any(
        (snapshot) => snapshot.id == job.id && snapshot.ready,
      ),
      isTrue,
    );
    expect(download.filename, endsWith('.dump'));
    expect(download.contentLength, 17);
    expect(utf8.decode(await download.stream.expand((chunk) => chunk).toList()),
        'test-backup-bytes');
  });

  test('admin can repeat today backup and import an exported dump', () async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    addTearDown(() async {
      resetMobileApiTestModeData();
      await TestModeController.instance.setEnabled(false);
    });

    final first = await MobileApi.instance.adminStartBackup();
    final second = await MobileApi.instance.adminStartBackup();
    expect(first.id, isNot(second.id));

    final imported = await MobileApi.instance.adminImportBackup(
      filename: 'mini_rs_erp.dump',
      contentLength: 13,
      openStream: () => Stream<List<int>>.value(
        utf8.encode('exported-dump'),
      ),
    );
    final report = await MobileApi.instance.adminServerMonitor();

    expect(imported.source, 'imported');
    expect(
      report.backups.snapshots.any(
        (snapshot) => snapshot.id == imported.id && snapshot.ready,
      ),
      isTrue,
    );
  });

  test('admin import starts the streamed request before closing its body',
      () async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    addTearDown(() async {
      AppSession.instance.token = null;
      await TestModeController.instance.setEnabled(false);
    });

    final client = _RecordingBackupImportClient();
    final imported = await http.runWithClient(
      () => MobileApi.instance
          .adminImportBackup(
            filename: 'mobile-export.dump',
            contentLength: 13,
            openStream: () => Stream<List<int>>.value(
              utf8.encode('exported-dump'),
            ),
          )
          .timeout(const Duration(seconds: 1)),
      () => client,
    );

    expect(imported.id, 'import-1');
    expect(client.receivedBody, utf8.encode('exported-dump'));
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

  test('server monitor pong event reports websocket round trip latency', () {
    final event = AdminServerMonitorLiveEvent.fromJson(
      const {'type': 'pong', 'id': 9, 'sent_at_ms': 1000},
      nowMs: () => 1042,
    );

    expect(event.report, isNull);
    expect(event.latencyMs, 42);
  });
}

class _RecordingBackupImportClient extends http.BaseClient {
  List<int>? receivedBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    receivedBody = await request.finalize().toBytes();
    final body = jsonEncode({
      'id': 'import-1',
      'status': 'queued',
      'source': 'imported',
      'requested_by': 'Admin',
      'created_at_unix': 1,
      'started_at_unix': 0,
      'completed_at_unix': 0,
      'size_bytes': 0,
      'artifact_name': 'mobile-export.dump',
      'checksum_sha256': '',
      'verified': false,
      'error': '',
    });
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      202,
      contentLength: utf8.encode(body).length,
    );
  }
}
