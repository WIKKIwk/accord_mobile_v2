import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Retain an unacknowledged command so a timeout or app restart cannot turn a
/// retry into a different transfer. Keys include the server and account scope.
class ApparatusTransferCommandStore {
  static Future<void> _writes = Future<void>.value();

  static String _key(String scope, Map<String, String> command) =>
      'apparatus_transfer_pending_v1:${base64Url.encode(utf8.encode(jsonEncode([
            scope,
            command['order_id'],
            command['from_apparatus'],
            command['to_apparatus'],
          ])))}';

  static Future<Map<String, String>> retain(
    String scope,
    Map<String, String> command,
  ) {
    final result = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(scope, command);
      final stored = prefs.getString(key);
      if (stored != null) {
        return Map<String, String>.from(jsonDecode(stored) as Map);
      }
      if (!await prefs.setString(key, jsonEncode(command))) {
        throw StateError('Ko‘chirish so‘rovi qurilmada saqlanmadi');
      }
      return Map<String, String>.unmodifiable(command);
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static Future<void> acknowledge(
      String scope, Map<String, String> command) async {
    final result = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(scope, command);
      if (prefs.getString(key) == jsonEncode(command)) await prefs.remove(key);
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await result;
  }
}
