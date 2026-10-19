import 'package:accord_mobile_v2/src/core/update/app_update_installer.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.linux,
    TargetPlatform.windows
  ]) {
    test('$platform reads installed version without Android installer channel',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      PackageInfo.setMockInitialValues(
        appName: 'Accord Mobile',
        packageName: 'com.example.accord_mobile_v2',
        version: '1.0.60',
        buildNumber: '89',
        buildSignature: '',
      );
      const updater = NativeAppUpdatePlatform();
      expect(updater.isSupported, isFalse);
      final current = await updater.currentAppInfo();
      expect(current.versionName, '1.0.60');
      expect(current.versionCode, 89);
    });
  }

  test('missing version metadata is an error instead of a latest-version claim',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    PackageInfo.setMockInitialValues(
        appName: 'Accord Mobile',
        packageName: '',
        version: '',
        buildNumber: '',
        buildSignature: '');
    await expectLater(
        const NativeAppUpdatePlatform().currentAppInfo(),
        throwsA(
          isA<AppUpdateException>()
              .having((error) => error.code, 'code', 'app_info_failed'),
        ));
  });
}
