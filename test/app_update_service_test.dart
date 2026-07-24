import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/update/app_update_installer.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('checks, verifies, caches, and launches a valid APK', () async {
    final apkBytes = utf8.encode('signed-accord-apk');
    final checksum = sha256.convert(apkBytes).toString();
    final platform = _FakeUpdatePlatform();
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
      if (request.url.path ==
          '/v1/mobile/app-update/android/apk/accord-5-$checksum.apk') {
        return http.Response.bytes(
          apkBytes,
          HttpStatus.ok,
          headers: {
            'content-type': 'application/vnd.android.package-archive',
            'content-length': '${apkBytes.length}',
          },
        );
      }
      return http.Response('not found', HttpStatus.notFound);
    });
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    addTearDown(() async {
      client.close();
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });
    final service = AppUpdateService(
      client: client,
      platform: platform,
      temporaryDirectoryProvider: () async => temporaryDirectory,
      baseUri: Uri.parse('https://erp.example/'),
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
    expect(
      requests.where(
        (path) =>
            path == '/v1/mobile/app-update/android/apk/accord-5-$checksum.apk',
      ),
      hasLength(1),
    );
  });

  test('does not install an APK with a mismatching checksum', () async {
    final apkBytes = utf8.encode('tampered-apk');
    final platform = _FakeUpdatePlatform();
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
    final temporaryDirectory =
        await Directory.systemTemp.createTemp('accord-update-test-');
    addTearDown(() async {
      client.close();
      if (await temporaryDirectory.exists()) {
        await temporaryDirectory.delete(recursive: true);
      }
    });
    final service = AppUpdateService(
      client: client,
      platform: platform,
      temporaryDirectoryProvider: () async => temporaryDirectory,
      baseUri: Uri.parse('https://erp.example/'),
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
  });
}

class _FakeUpdatePlatform implements AppUpdatePlatform {
  int installCalls = 0;
  String? lastInstalledPath;

  @override
  bool get isSupported => true;

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
}
