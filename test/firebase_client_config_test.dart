import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/notifications/service/firebase_client_config.dart';
import 'package:accord_mobile_v2/src/core/notifications/service/firebase_client_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const iosConfig = FirebaseClientConfig(
    projectId: 'accord-test',
    appId: '1:123:ios:abc',
    apiKey: 'AIzaPublicTestKey',
    senderId: '123',
    applicationId: 'com.example.accordMobileV2.mirsaid.uzkingshark');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Android file selects this package from multiple Firebase clients', () {
    final raw = jsonEncode({
      'project_info': {'project_id': 'accord-test', 'project_number': '123'},
      'client': [
        {
          'client_info': {
            'android_client_info': {'package_name': 'unrelated'}
          }
        },
        {
          'client_info': {
            'mobilesdk_app_id': '1:123:android:abc',
            'android_client_info': {
              'package_name': 'com.example.accord_mobile_v2'
            }
          },
          'api_key': [
            {'current_key': 'AIzaPublicTestKey'}
          ]
        }
      ]
    });
    final config = FirebaseClientConfig.fromFile(raw, 'android');
    expect(config.projectId, 'accord-test');
    expect(config.appId, '1:123:android:abc');
    expect(config.options.iosBundleId, isNull);
    expect(config.matches(config.options), isTrue);
  });

  test('iOS plist parses public options and validates the bundle and sender',
      () {
    const raw = '''<?xml version="1.0"?><plist version="1.0"><dict>
      <key>GOOGLE_APP_ID</key><string>1:123:ios:abc</string>
      <key>PROJECT_ID</key><string>accord-test</string>
      <key>GCM_SENDER_ID</key><string>123</string>
      <key>API_KEY</key><string>AIzaPublicTestKey</string>
      <key>BUNDLE_ID</key><string>com.example.accordMobileV2.mirsaid.uzkingshark</string>
      <key>IS_ADS_ENABLED</key><false/>
      </dict></plist>''';
    expect(
        FirebaseClientConfig.fromFile(raw, 'ios').toJson(), iosConfig.toJson());
    expect(
        () => FirebaseClientConfig.fromFile(
            raw.replaceAll('mirsaid', 'other'), 'ios'),
        throwsFormatException);
    expect(
        () => FirebaseClientConfig.fromFile(
            raw.replaceAll('1:123:ios', '1:456:ios'), 'ios'),
        throwsFormatException);
    expect(
        () => FirebaseClientConfig.fromFile(
            '{"type":"service_account"}', 'android'),
        throwsA(anything));
  });

  test(
      'fetched settings are stored for native cold start without private credentials',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final config = await FirebaseClientBootstrap.resolve(
        platform: 'ios',
        server: 'https://erp.test',
        fetch: () async => iosConfig,
        preferences: prefs);
    expect(config.toJson(), iosConfig.toJson());
    expect(jsonDecode(prefs.getString(FirebaseClientBootstrap.configKey)!),
        iosConfig.toJson());
    expect(
        prefs.getString(FirebaseClientBootstrap.serverKey), 'https://erp.test');
    expect(prefs.getString(FirebaseClientBootstrap.configKey),
        isNot(contains('private_key')));
  });

  test('offline options are scoped to the same server and platform', () async {
    final prefs = await SharedPreferences.getInstance();
    await FirebaseClientBootstrap.resolve(
        platform: 'ios',
        server: 'one',
        fetch: () async => iosConfig,
        preferences: prefs);
    Future<FirebaseClientConfig?> offline() async => throw Exception('offline');
    expect(
        (await FirebaseClientBootstrap.resolve(
                platform: 'ios',
                server: 'one',
                fetch: offline,
                preferences: prefs))
            .appId,
        iosConfig.appId);
    await expectLater(
        FirebaseClientBootstrap.resolve(
            platform: 'ios', server: 'two', fetch: offline, preferences: prefs),
        throwsA(anything));
    await expectLater(
        FirebaseClientBootstrap.resolve(
            platform: 'android',
            server: 'one',
            fetch: offline,
            preferences: prefs),
        throwsFormatException);
  });

  test(
      'server removal clears cache and authorization errors cannot use cached settings',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await FirebaseClientBootstrap.resolve(
        platform: 'ios',
        server: 'one',
        fetch: () async => iosConfig,
        preferences: prefs);
    await expectLater(
        FirebaseClientBootstrap.resolve(
            platform: 'ios',
            server: 'one',
            fetch: () async => throw const MobileApiException(
                code: 'unauthorized', message: '', statusCode: 401),
            preferences: prefs),
        throwsA(isA<MobileApiException>()));
    await expectLater(
        FirebaseClientBootstrap.resolve(
            platform: 'ios',
            server: 'one',
            fetch: () async => null,
            preferences: prefs),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'push_config_client_missing')));
    expect(prefs.getString(FirebaseClientBootstrap.configKey), isNull);
    expect(prefs.getString(FirebaseClientBootstrap.serverKey), isNull);
  });
}
