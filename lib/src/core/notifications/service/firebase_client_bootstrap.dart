import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../api/mobile_api.dart';
import 'firebase_client_config.dart';

class FirebaseClientBootstrap {
  static const configKey = 'accord.push.client_config';
  static const serverKey = 'accord.push.client_server';

  /// Cached public options are also read by the native app before background push.
  static Future<FirebaseClientConfig> resolve(
      {required String platform,
      required String server,
      required Future<FirebaseClientConfig?> Function() fetch,
      required SharedPreferences preferences}) async {
    FirebaseClientConfig? config;
    try {
      config = await fetch();
    } catch (error) {
      if (error is FormatException ||
          error is TypeError ||
          (error is MobileApiException &&
              (error.code == 'push_config_test_mode' ||
                  (error.statusCode != null && error.statusCode! < 500)))) {
        rethrow;
      }
      if (preferences.getString(serverKey) != server) rethrow;
      final raw = preferences.getString(configKey);
      if (raw == null) rethrow;
      config = FirebaseClientConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    }
    if (config == null) {
      await preferences.remove(configKey);
      await preferences.remove(serverKey);
      throw const MobileApiException(
          code: 'push_config_client_missing',
          message: 'Mobile configuration is missing');
    }
    config.validate(platform);
    // Clear the association first so an interrupted write cannot use another server's config.
    await preferences.remove(serverKey);
    if (!await preferences.setString(configKey, jsonEncode(config.toJson())) ||
        !await preferences.setString(serverKey, server)) {
      throw const MobileApiException(
          code: 'push_config_client_save_failed',
          message: 'Cannot save device configuration');
    }
    return config;
  }

  static Future<void> initialize(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    final config = await resolve(
        platform: platform,
        server: MobileApi.baseUrl,
        fetch: () => MobileApi.instance.mobilePushConfig(platform),
        preferences: prefs);
    // Read any default app created by the native cold-start bootstrap.
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp();
      } catch (_) {/* First configuration has no bundled options. */}
    }
    if (Firebase.apps.isNotEmpty) {
      if (!config.matches(Firebase.app().options)) {
        throw const MobileApiException(
            code: 'push_config_restart_required',
            message:
                'Saved new Firebase project; restart the app to switch the default SDK instance');
      }
      return;
    }
    await Firebase.initializeApp(options: config.options);
  }

  static Future<void> initializeBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(configKey);
    if (raw != null) {
      final config = FirebaseClientConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
      await Firebase.initializeApp(options: config.options);
    } else {
      await Firebase.initializeApp();
    }
  }
}
