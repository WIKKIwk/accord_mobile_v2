import 'package:accord_mobile_v2/src/core/update/app_update_installer.dart';
import 'package:accord_mobile_v2/src/core/update/app_update_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('preflight validates APK without opening settings or the installer',
      () async {
    const channel = MethodChannel('accord/app_update');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await const NativeAppUpdatePlatform().validateApk(
        path: '/downloads/app_updates/accord.apk',
        expectedPackageName: 'com.example.accord_mobile_v2',
        expectedVersionCode: 92);
    expect(calls.map((call) => call.method), ['validateApk']);
    expect(calls.single.arguments['expectedVersionCode'], 92);
  });

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
