import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/session/state/app_session.dart';
import '../../shared/models/app_models.dart';

class AdminSequenceApparatusStore {
  AdminSequenceApparatusStore._();

  static final AdminSequenceApparatusStore instance =
      AdminSequenceApparatusStore._();

  String? _cachedApparatusId;
  String? _cachedApparatusName;

  String? get cachedApparatusId => _cachedApparatusId;
  String? get cachedApparatusName => _cachedApparatusName;

  static String preferenceKey({String? profileRef}) {
    final ref = (profileRef ?? AppSession.instance.profile?.ref)?.trim() ?? '';
    return 'admin.production_map.sequence_apparatus.${ref.isEmpty ? 'default' : ref}';
  }

  static String preferenceNameKey({String? profileRef}) {
    return '${preferenceKey(profileRef: profileRef)}_name';
  }

  Future<String?> loadSavedApparatusId({
    String? profileRef,
    SharedPreferences? preferences,
  }) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      var id = prefs.getString(preferenceKey(profileRef: profileRef))?.trim();
      var name = prefs
          .getString(preferenceNameKey(profileRef: profileRef))
          ?.trim();

      // If user profile was specified but has no saved key yet, check 'default'.
      final currentRef =
          (profileRef ?? AppSession.instance.profile?.ref)?.trim() ?? '';
      if ((id == null || id.isEmpty) && currentRef.isNotEmpty) {
        id = prefs.getString(preferenceKey(profileRef: 'default'))?.trim();
        name = prefs
            .getString(preferenceNameKey(profileRef: 'default'))
            ?.trim();
      }

      if (id != null && id.isNotEmpty) {
        _cachedApparatusId = id;
      }
      if (name != null && name.isNotEmpty) {
        _cachedApparatusName = name;
      }
      return _cachedApparatusId;
    } catch (_) {
      return _cachedApparatusId;
    }
  }

  Future<void> saveApparatus(
    AdminApparatus apparatus, {
    String? profileRef,
    SharedPreferences? preferences,
  }) async {
    final id = apparatus.id.trim();
    final name = apparatus.name.trim();
    _cachedApparatusId = id.isNotEmpty ? id : null;
    _cachedApparatusName = name.isNotEmpty ? name : null;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      if (id.isNotEmpty) {
        await prefs.setString(preferenceKey(profileRef: profileRef), id);
        await prefs.setString(preferenceKey(profileRef: 'default'), id);
      }
      if (name.isNotEmpty) {
        await prefs.setString(
          preferenceNameKey(profileRef: profileRef),
          name,
        );
        await prefs.setString(
          preferenceNameKey(profileRef: 'default'),
          name,
        );
      }
    } catch (_) {}
  }

  AdminApparatus? resolveApparatus(
    Iterable<AdminApparatus> apparatusList, {
    String? id,
    String? name,
  }) {
    final targetId = (id ?? _cachedApparatusId)?.trim() ?? '';
    final targetName = (name ?? _cachedApparatusName)?.trim() ?? '';
    if (targetId.isEmpty && targetName.isEmpty) {
      return null;
    }

    if (targetId.isNotEmpty) {
      for (final item in apparatusList) {
        if (item.id.trim() == targetId) {
          return item;
        }
      }
    }
    if (targetName.isNotEmpty) {
      final lower = targetName.toLowerCase();
      for (final item in apparatusList) {
        if (item.name.trim().toLowerCase() == lower) {
          return item;
        }
      }
    }
    return null;
  }

  void clearCache() {
    _cachedApparatusId = null;
    _cachedApparatusName = null;
  }
}
