import 'saved_account_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

AccountSecretStore createDefaultAccountSecretStore(
  SharedPreferences preferences,
) {
  final supportsNativeSecureStorage = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (supportsNativeSecureStorage) {
    return const PlatformAccountSecretStore();
  }
  return _SharedPreferencesAccountSecretStore(preferences);
}

class PlatformAccountSecretStore implements AccountSecretStore {
  const PlatformAccountSecretStore();

  static const MethodChannel _channel = MethodChannel(
    'accord/secure_account_storage',
  );

  @override
  Future<String?> read(String key) async {
    final normalizedKey = _requireKey(key);
    return _channel.invokeMethod<String>('read', <String, String>{
      'key': normalizedKey,
    });
  }

  @override
  Future<void> write(String key, String value) async {
    final normalizedKey = _requireKey(key);
    await _channel.invokeMethod<void>('write', <String, String>{
      'key': normalizedKey,
      'value': value,
    });
  }

  @override
  Future<void> delete(String key) async {
    final normalizedKey = _requireKey(key);
    await _channel.invokeMethod<void>('delete', <String, String>{
      'key': normalizedKey,
    });
  }

  String _requireKey(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    return normalized;
  }
}

class _SharedPreferencesAccountSecretStore implements AccountSecretStore {
  const _SharedPreferencesAccountSecretStore(this._preferences);

  static const String _keyPrefix = 'saved_account_local_secret_v1:';

  final SharedPreferences _preferences;

  @override
  Future<String?> read(String key) async {
    return _preferences.getString(_storageKey(key));
  }

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(_storageKey(key), value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(_storageKey(key));
  }

  String _storageKey(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty');
    }
    return '$_keyPrefix$normalized';
  }
}
