import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/update/app_update_installer.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final releaseVersion in [4, 5]) {
    test(
        'non-Android device checks version $releaseVersion without downloading APK',
        () async {
      final directory =
          await Directory.systemTemp.createTemp('accord-version-check-');
      addTearDown(() => directory.delete(recursive: true));
      final platform = _FakeUpdatePlatform(
        apkBytes: [],
        downloadDirectory: directory,
        supported: false,
      );
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/mobile/app-update/android');
        return http.Response(
            jsonEncode({
              'version_code': releaseVersion,
              'version_name': '1.0.$releaseVersion',
              'apk_url': '/accord.apk',
              'sha256': 'a' * 64,
              'size_bytes': 1024,
            }),
            200);
      });
      addTearDown(client.close);
      final service = AppUpdateService(
          client: client,
          platform: platform,
          baseUri: Uri.parse('https://erp.example/'));
      final result = await service.check();
      expect(result.current.versionCode, 4);
      expect(result.manifest!.versionCode, releaseVersion);
      expect(result.updateAvailable, releaseVersion > 4);
      await expectLater(
          service.downloadAndInstall(result),
          throwsA(
            isA<AppUpdateException>()
                .having((error) => error.code, 'code', 'unsupported_platform'),
          ));
      expect(platform.downloadStarts, 0);
      expect(platform.installCalls, 0);
    });
  }

  test('checks, verifies, caches, and launches a valid APK', () async {
    final apkBytes = utf8.encode('signed-accord-apk');
    final checksum = sha256.convert(apkBytes).toString();
    final downloadDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    final platform = _FakeUpdatePlatform(
      apkBytes: apkBytes,
      downloadDirectory: downloadDirectory,
    );
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.path);
      if (request.url.path == '/v1/mobile/app-update/android') {
        return http.Response(
          jsonEncode({
            'version_code': 5,
            'version_name': '0.2.0',
            'minimum_supported_version_code': 0,
            'mandatory': false,
            'apk_url':
                '/v1/mobile/app-update/android/apk/accord-5-$checksum.apk',
            'sha256': checksum,
            'size_bytes': apkBytes.length,
            'release_notes': 'Updater',
            'published_at': '2026-07-23T12:00:00Z',
          }),
          HttpStatus.ok,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', HttpStatus.notFound);
    });
    addTearDown(() async {
      client.close();
      if (await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
    });
    final service = AppUpdateService(
      client: client,
      platform: platform,
      baseUri: Uri.parse('https://erp.example/'),
      downloadPollInterval: Duration.zero,
      automaticRetryDelay: Duration.zero,
    );

    final update = await service.check();
    expect(update.updateAvailable, isTrue);
    expect(update.mandatory, isFalse);

    final firstResult = await service.downloadAndInstall(update);
    expect(firstResult, AppInstallLaunchResult.installerLaunched);
    expect(platform.installCalls, 1);
    expect(await File(platform.lastInstalledPath!).readAsBytes(), apkBytes);

    await service.downloadAndInstall(update);
    expect(platform.installCalls, 2);
    expect(platform.downloadStarts, 1);
    expect(requests, ['/v1/mobile/app-update/android']);
  });

  test('does not install an APK with a mismatching checksum', () async {
    final apkBytes = utf8.encode('tampered-apk');
    final downloadDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    final platform = _FakeUpdatePlatform(
      apkBytes: apkBytes,
      downloadDirectory: downloadDirectory,
    );
    final client = MockClient((request) async {
      if (request.url.path == '/v1/mobile/app-update/android') {
        return http.Response(
          jsonEncode({
            'version_code': 5,
            'version_name': '0.2.0',
            'minimum_supported_version_code': 0,
            'mandatory': false,
            'apk_url':
                '/v1/mobile/app-update/android/apk/accord-5-tampered.apk',
            'sha256':
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            'size_bytes': apkBytes.length,
          }),
          HttpStatus.ok,
        );
      }
      return http.Response.bytes(
        apkBytes,
        HttpStatus.ok,
        headers: {'content-length': '${apkBytes.length}'},
      );
    });
    addTearDown(() async {
      client.close();
      if (await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
    });
    final service = AppUpdateService(
      client: client,
      platform: platform,
      baseUri: Uri.parse('https://erp.example/'),
      downloadPollInterval: Duration.zero,
      automaticRetryDelay: Duration.zero,
    );

    final update = await service.check();

    await expectLater(
      service.downloadAndInstall(update),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.code,
          'code',
          'apk_checksum_mismatch',
        ),
      ),
    );
    expect(platform.installCalls, 0);
    expect(platform.cancelCalls, 1);
    expect(await File(platform.downloadPath).exists(), isFalse);
  });

  test(
      'an APK rejected by native signature validation is never marked ready or installed',
      () async {
    final bytes = utf8.encode('wrong-signing-key');
    final directory =
        await Directory.systemTemp.createTemp('accord-rejected-apk-');
    addTearDown(() => directory.delete(recursive: true));
    final platform = _FakeUpdatePlatform(
        apkBytes: bytes, downloadDirectory: directory, rejectValidation: true);
    final service = AppUpdateService(platform: platform);
    await expectLater(
        service.prepareUpdate(_updateResult(
            checksum: sha256.convert(bytes).toString(),
            sizeBytes: bytes.length)),
        throwsA(isA<AppUpdateException>()
            .having((e) => e.code, 'code', 'signer_mismatch')));
    expect(platform.validationCalls, 1);
    expect(platform.installCalls, 0);
  });

  test('attaches to an active system download and keeps its progress',
      () async {
    final apkBytes = utf8.encode('background-download');
    final checksum = sha256.convert(apkBytes).toString();
    final downloadDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    final platform = _FakeUpdatePlatform(
      apkBytes: apkBytes,
      downloadDirectory: downloadDirectory,
      initialStatus: AppUpdateDownloadStatus.running,
      initialReceivedBytes: 7,
    );
    addTearDown(() async {
      if (await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
    });
    final update =
        _updateResult(checksum: checksum, sizeBytes: apkBytes.length);
    final service = AppUpdateService(
      platform: platform,
      downloadPollInterval: Duration.zero,
      automaticRetryDelay: Duration.zero,
    );

    final active = await service.activeDownload(update);
    expect(active?.status, AppUpdateDownloadStatus.running);
    expect(active?.receivedBytes, 7);

    final progress = <int>[];
    final result = await service.downloadAndInstall(
      update,
      onProgress: (received, _) => progress.add(received),
    );

    expect(result, AppInstallLaunchResult.installerLaunched);
    expect(progress, contains(7));
    expect(progress.last, apkBytes.length);
    expect(platform.downloadStarts, 1);
  });

  test('cancels the Android system download immediately', () async {
    final apkBytes = utf8.encode('cancelled-download');
    final checksum = sha256.convert(apkBytes).toString();
    final downloadDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    final platform = _FakeUpdatePlatform(
      apkBytes: apkBytes,
      downloadDirectory: downloadDirectory,
      initialStatus: AppUpdateDownloadStatus.paused,
    );
    addTearDown(() async {
      if (await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
    });
    final update =
        _updateResult(checksum: checksum, sizeBytes: apkBytes.length);
    final service = AppUpdateService(
      platform: platform,
      downloadPollInterval: const Duration(days: 1),
    );
    final cancellation = AppUpdateCancellation();

    final download = service.downloadAndInstall(
      update,
      cancellation: cancellation,
    );
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();

    await expectLater(
      download,
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.code,
          'code',
          'cancelled',
        ),
      ),
    );
    expect(platform.cancelCalls, 1);
    expect(platform.installCalls, 0);
  });

  test('offline pauses retain the partial download and resume without restart',
      () async {
    final apkBytes = utf8.encode('resumed-download');
    final directory = await Directory.systemTemp.createTemp('accord-resume-');
    addTearDown(() => directory.delete(recursive: true));
    final platform = _FakeUpdatePlatform(
      apkBytes: apkBytes,
      downloadDirectory: directory,
      initialStatus: AppUpdateDownloadStatus.paused,
      initialReceivedBytes: 7,
    );
    final service = AppUpdateService(
      platform: platform,
      downloadPollInterval: const Duration(milliseconds: 5),
    );
    final progress = <int>[];
    final pending = service.prepareUpdate(
      _updateResult(
          checksum: sha256.convert(apkBytes).toString(),
          sizeBytes: apkBytes.length),
      onProgress: (received, _) => progress.add(received),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(platform.downloadStarts, 1);
    expect(platform.cancelCalls, 0);
    expect(platform.installCalls, 0);
    platform._status = AppUpdateDownloadStatus.running;
    final prepared = await pending;
    expect(progress, contains(7));
    expect(platform.downloadStarts, 1);
    expect(platform.cancelCalls, 0);
    expect(platform.validationCalls, 1);
    expect(await File(prepared.path).readAsBytes(), apkBytes);
  });

  test(
      'prepared APK and mandatory policy survive restart without network or reinstall',
      () async {
    final bytes = utf8.encode('persisted-signed-apk');
    final directory =
        await Directory.systemTemp.createTemp('accord-persisted-');
    addTearDown(() => directory.delete(recursive: true));
    final platform =
        _FakeUpdatePlatform(apkBytes: bytes, downloadDirectory: directory);
    final update = _updateResult(
        checksum: sha256.convert(bytes).toString(), sizeBytes: bytes.length);
    final manifest = AppUpdateManifest.fromJson(
        {...update.manifest!.toJson(), 'mandatory': true},
        baseUri: Uri.parse('https://erp.example/'));
    final first = AppUpdateService(
        platform: platform, baseUri: Uri.parse('https://erp.example/'));
    final prepared = await first.prepareUpdate(
        AppUpdateCheckResult(current: update.current, manifest: manifest));
    expect(platform.installCalls, 0);
    final second = AppUpdateService(
        platform: platform,
        baseUri: Uri.parse('https://erp.example/'),
        client:
            MockClient((_) async => throw const SocketException('offline')));
    final restored = await second.restorePendingUpdate();
    expect(restored!.mandatory, isTrue);
    final cached = await second.prepareUpdate(restored);
    expect(cached.path, prepared.path);
    expect(platform.downloadStarts, 1);
    expect(platform.installCalls, 0);
    await second.installPreparedUpdate(cached);
    expect(platform.installCalls, 1);
  });

  test('detaching the foreground monitor does not cancel a system download',
      () async {
    final bytes = utf8.encode('background-continues');
    final directory = await Directory.systemTemp.createTemp('accord-detach-');
    addTearDown(() => directory.delete(recursive: true));
    final platform = _FakeUpdatePlatform(
        apkBytes: bytes,
        downloadDirectory: directory,
        initialStatus: AppUpdateDownloadStatus.paused,
        initialReceivedBytes: 8);
    final service = AppUpdateService(
        platform: platform, downloadPollInterval: const Duration(days: 1));
    final cancellation = AppUpdateCancellation(preserveDownload: true);
    final preparing = service.prepareUpdate(
        _updateResult(
            checksum: sha256.convert(bytes).toString(),
            sizeBytes: bytes.length),
        cancellation: cancellation);
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    await expectLater(
        preparing,
        throwsA(isA<AppUpdateException>()
            .having((e) => e.code, 'code', 'cancelled')));
    expect(platform.cancelCalls, 0);
    expect(platform._status, AppUpdateDownloadStatus.paused);
  });

  test('automatically restarts a retryable system download failure', () async {
    final apkBytes = utf8.encode('retried-download');
    final checksum = sha256.convert(apkBytes).toString();
    final downloadDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    final platform = _FakeUpdatePlatform(
      apkBytes: apkBytes,
      downloadDirectory: downloadDirectory,
      initialStatus: AppUpdateDownloadStatus.running,
      failFirstQuery: true,
    );
    addTearDown(() async {
      if (await downloadDirectory.exists()) {
        await downloadDirectory.delete(recursive: true);
      }
    });
    final service = AppUpdateService(
      platform: platform,
      downloadPollInterval: Duration.zero,
      automaticRetryDelay: Duration.zero,
    );

    final result = await service.downloadAndInstall(
      _updateResult(checksum: checksum, sizeBytes: apkBytes.length),
    );

    expect(result, AppInstallLaunchResult.installerLaunched);
    expect(platform.cancelCalls, 1);
    expect(platform.downloadStarts, 2);
    expect(platform.installCalls, 1);
  });
}

class _FakeUpdatePlatform implements AppUpdatePlatform {
  _FakeUpdatePlatform({
    required this.apkBytes,
    required this.downloadDirectory,
    this.initialStatus = AppUpdateDownloadStatus.missing,
    this.initialReceivedBytes = 0,
    this.failFirstQuery = false,
    this.supported = true,
    this.rejectValidation = false,
  })  : _status = initialStatus,
        _runningQueriesRemaining =
            initialStatus == AppUpdateDownloadStatus.running ? 1 : 0;

  final List<int> apkBytes;
  final Directory downloadDirectory;
  final AppUpdateDownloadStatus initialStatus;
  final int initialReceivedBytes;
  final bool failFirstQuery;
  final bool supported;
  final bool rejectValidation;
  late AppUpdateDownloadStatus _status;
  int _runningQueriesRemaining;
  bool _queryFailureReturned = false;
  int installCalls = 0;
  int validationCalls = 0;
  int downloadStarts = 0;
  int cancelCalls = 0;
  String? lastInstalledPath;

  String get downloadPath => '${downloadDirectory.path}/accord-5.apk';

  @override
  bool get isSupported => supported;

  @override
  Future<AppInstallationInfo> currentAppInfo() async {
    return const AppInstallationInfo(
      packageName: 'com.example.accord_mobile_v2',
      versionCode: 4,
      versionName: '0.1.0',
      signerSha256: 'test',
    );
  }

  @override
  Future<AppUpdateDownloadSnapshot> startOrAttachDownload({
    required AppUpdateManifest manifest,
  }) async {
    if (_status == AppUpdateDownloadStatus.missing) {
      downloadStarts += 1;
      await File(downloadPath).writeAsBytes(apkBytes);
      _status = AppUpdateDownloadStatus.successful;
    } else if (_status == AppUpdateDownloadStatus.running) {
      downloadStarts += 1;
    } else if (_status == AppUpdateDownloadStatus.paused) {
      downloadStarts += 1;
    }
    return _snapshot(manifest);
  }

  @override
  Future<AppUpdateDownloadSnapshot> queryDownload({
    required AppUpdateManifest manifest,
  }) async {
    if (_status == AppUpdateDownloadStatus.running) {
      if (failFirstQuery && !_queryFailureReturned) {
        _queryFailureReturned = true;
        _status = AppUpdateDownloadStatus.failed;
        return _snapshot(manifest);
      }
      if (_runningQueriesRemaining > 0) {
        _runningQueriesRemaining -= 1;
        return _snapshot(manifest);
      }
      await File(downloadPath).writeAsBytes(apkBytes);
      _status = AppUpdateDownloadStatus.successful;
    }
    return _snapshot(manifest);
  }

  @override
  Future<void> cancelDownload({required AppUpdateManifest manifest}) async {
    cancelCalls += 1;
    _status = AppUpdateDownloadStatus.missing;
    final file = File(downloadPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> validateApk(
      {required String path,
      required String expectedPackageName,
      required int expectedVersionCode}) async {
    validationCalls++;
    if (rejectValidation) {
      throw const AppUpdateException(
          code: 'signer_mismatch', message: 'Wrong signing key');
    }
    expect(expectedPackageName, 'com.example.accord_mobile_v2');
    expect(expectedVersionCode, 5);
    expect(await File(path).exists(), isTrue);
  }

  @override
  Future<AppInstallLaunchResult> installApk({
    required String path,
    required String expectedPackageName,
    required int expectedVersionCode,
  }) async {
    installCalls += 1;
    lastInstalledPath = path;
    expect(expectedPackageName, 'com.example.accord_mobile_v2');
    expect(expectedVersionCode, 5);
    return AppInstallLaunchResult.installerLaunched;
  }

  AppUpdateDownloadSnapshot _snapshot(AppUpdateManifest manifest) {
    final successful = _status == AppUpdateDownloadStatus.successful;
    return AppUpdateDownloadSnapshot(
      status: _status,
      receivedBytes: successful
          ? manifest.sizeBytes
          : initialReceivedBytes.clamp(0, manifest.sizeBytes),
      totalBytes: manifest.sizeBytes,
      path: successful ? downloadPath : '',
      reason: _status == AppUpdateDownloadStatus.failed ? 1004 : 0,
      retryable: _status == AppUpdateDownloadStatus.failed,
    );
  }
}

AppUpdateCheckResult _updateResult({
  required String checksum,
  required int sizeBytes,
}) {
  return AppUpdateCheckResult(
    current: const AppInstallationInfo(
      packageName: 'com.example.accord_mobile_v2',
      versionCode: 4,
      versionName: '0.1.0',
      signerSha256: 'test',
    ),
    manifest: AppUpdateManifest(
      versionCode: 5,
      versionName: '0.2.0',
      minimumSupportedVersionCode: 0,
      mandatory: false,
      apkUri: Uri.parse('https://erp.example/accord.apk'),
      sha256: checksum,
      sizeBytes: sizeBytes,
      releaseNotes: '',
      publishedAt: '',
    ),
  );
}
