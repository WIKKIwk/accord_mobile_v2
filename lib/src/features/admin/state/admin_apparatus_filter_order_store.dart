import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/app_models.dart';

/// Device-local display order for the admin sequence filter.
class AdminApparatusFilterOrderStore {
  static String preferenceKey(String profileRef) {
    final ref = profileRef.trim();
    if (ref.isEmpty) throw ArgumentError.value(profileRef, 'profileRef');
    return 'admin.production_map.apparatus_filter_order.v1.$ref';
  }

  static Future<List<String>> load(String profileRef) async {
    final key = preferenceKey(profileRef);
    final preferences = await SharedPreferences.getInstance();
    return _normalize(preferences.getStringList(key) ?? const []);
  }

  static Future<void> save(String profileRef, Iterable<String> ids) async {
    final key = preferenceKey(profileRef);
    final order = _normalize(ids);
    final preferences = await SharedPreferences.getInstance();
    final saved = order.isEmpty
        ? await preferences.remove(key)
        : await preferences.setStringList(key, order);
    if (!saved) throw StateError('Apparatus filter order was not saved');
  }

  static List<AdminApparatus> apply(
    List<AdminApparatus> catalog,
    Iterable<String> savedIds,
  ) {
    final remaining = <String, AdminApparatus>{
      for (final apparatus in catalog)
        if (apparatus.id.trim().isNotEmpty && apparatus.name.trim().isNotEmpty)
          apparatus.id.trim(): apparatus,
    };
    final ordered = <AdminApparatus>[];
    for (final id in savedIds) {
      final apparatus = remaining.remove(id.trim());
      if (apparatus != null) ordered.add(apparatus);
    }
    // Removed IDs are ignored; new machines keep their catalog order at the end.
    return ordered..addAll(remaining.values);
  }

  static List<String> _normalize(Iterable<String> ids) => ids
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
