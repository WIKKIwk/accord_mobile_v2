import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const checksum =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('parses a valid Android update manifest', () {
    final manifest = AppUpdateManifest.fromJson(
      {
        'version_code': 5,
        'version_name': '0.2.0',
        'minimum_supported_version_code': 4,
        'mandatory': false,
        'apk_url': '/v1/mobile/app-update/android/apk/accord-5-aabbcc.apk',
        'sha256': checksum,
        'size_bytes': 1234,
        'release_notes': 'Updater qo‘shildi',
        'published_at': '2026-07-23T12:00:00Z',
      },
      baseUri: Uri.parse('https://erp.example/api/'),
    );

    expect(manifest.versionCode, 5);
    expect(manifest.apkUri.toString(),
        'https://erp.example/v1/mobile/app-update/android/apk/accord-5-aabbcc.apk');
    expect(manifest.releaseNotes, 'Updater qo‘shildi');
  });

  test('minimum supported version makes only older clients mandatory', () {
    final manifest = AppUpdateManifest.fromJson(
      {
        'version_code': 6,
        'version_name': '0.3.0',
        'minimum_supported_version_code': 5,
        'mandatory': false,
        'apk_url': '/v1/mobile/app-update/android/apk/accord-6-aabbcc.apk',
        'sha256': checksum,
        'size_bytes': 1234,
      },
      baseUri: Uri.parse('https://erp.example/'),
    );

    expect(manifest.isMandatoryFor(_installation(versionCode: 4)), isTrue);
    expect(manifest.isMandatoryFor(_installation(versionCode: 5)), isFalse);
  });

  test('rejects an invalid checksum', () {
    expect(
      () => AppUpdateManifest.fromJson(
        {
          'version_code': 5,
          'version_name': '0.2.0',
          'apk_url': '/v1/mobile/app-update/android/apk/accord-5-aabbcc.apk',
          'sha256': 'not-a-checksum',
          'size_bytes': 1234,
        },
        baseUri: Uri.parse('https://erp.example/'),
      ),
      throwsA(
        isA<AppUpdateException>().having(
          (error) => error.code,
          'code',
          'invalid_manifest',
        ),
      ),
    );
  });
}

AppInstallationInfo _installation({required int versionCode}) {
  return AppInstallationInfo(
    packageName: 'com.example.accord_mobile_v2',
    versionCode: versionCode,
    versionName: 'test',
    signerSha256: '',
  );
}
