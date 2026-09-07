import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/server_endpoint_store.dart';
import '../session/state/app_session.dart';

/// A pallet selection belongs to one account, server and physical apparatus.
class ActiveRezkaPaddonStore {
  static String? scopeKey(String apparatusId) {
    final profile = AppSession.instance.profile;
    if (profile == null ||
        profile.ref.trim().isEmpty ||
        apparatusId.trim().isEmpty) {
      return null;
    }
    return 'rezka.active_paddon.${jsonEncode([
          ServerEndpointStore.instance.baseUrl,
          profile.role.name,
          profile.ref.trim(),
          apparatusId.trim(),
        ])}';
  }

  static Future<String?> load(String apparatusId) async {
    final key = scopeKey(apparatusId);
    if (key == null) return null;
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(key)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static Future<void> save(String apparatusId, String? code) async {
    final key = scopeKey(apparatusId);
    if (key == null) throw StateError('No active Rezka account');
    final preferences = await SharedPreferences.getInstance();
    final value = code?.trim() ?? '';
    final saved = value.isEmpty
        ? await preferences.remove(key)
        : await preferences.setString(key, value);
    if (!saved) throw StateError('Paddon selection was not saved');
  }
}
