import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/session/state/app_session.dart';
import '../../shared/models/app_models.dart';

class AdminUsersRoleStore {
  AdminUsersRoleStore._();

  static final AdminUsersRoleStore instance = AdminUsersRoleStore._();

  AdminUserKind? _cachedRole;

  AdminUserKind? get cachedRole => _cachedRole;

  static String preferenceKey({String? profileRef}) {
    final ref = (profileRef ?? AppSession.instance.profile?.ref)?.trim() ?? '';
    return 'admin.users.selected_role.${ref.isEmpty ? 'default' : ref}';
  }

  static AdminUserKind? parseKind(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final kind in AdminUserKind.values) {
      if (kind.name.toLowerCase() == normalized) return kind;
    }
    return null;
  }

  Future<AdminUserKind?> loadSavedRole({
    String? profileRef,
    SharedPreferences? preferences,
  }) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      var raw = prefs.getString(preferenceKey(profileRef: profileRef))?.trim();

      final currentRef =
          (profileRef ?? AppSession.instance.profile?.ref)?.trim() ?? '';
      if ((raw == null || raw.isEmpty) && currentRef.isNotEmpty) {
        raw = prefs.getString(preferenceKey(profileRef: 'default'))?.trim();
      }

      final kind = parseKind(raw);
      if (kind != null) {
        _cachedRole = kind;
      }
      return _cachedRole;
    } catch (_) {
      return _cachedRole;
    }
  }

  Future<void> saveRole(
    AdminUserKind kind, {
    String? profileRef,
    SharedPreferences? preferences,
  }) async {
    _cachedRole = kind;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey(profileRef: profileRef), kind.name);
      await prefs.setString(preferenceKey(profileRef: 'default'), kind.name);
    } catch (_) {}
  }

  void clearCache() {
    _cachedRole = null;
  }
}
