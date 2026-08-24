import 'saved_account_store.dart';
import 'package:flutter/services.dart';

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
