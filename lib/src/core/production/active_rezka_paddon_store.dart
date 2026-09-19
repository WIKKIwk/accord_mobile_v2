import 'dart:convert';

import '../api/mobile_api.dart';
import '../network/server_endpoint_store.dart';
import '../session/state/app_session.dart';

/// Server-owned selection. The scope key is only a widget identity, never a
/// local persistence key. Reads must not fall back to a device preference.
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

  static Future<String?> load(String apparatusId) =>
      MobileApi.instance.activeRezkaPaddon(apparatusId);

  static Future<String?> save(String apparatusId, String? code) =>
      MobileApi.instance.setActiveRezkaPaddon(apparatusId, code);
}
