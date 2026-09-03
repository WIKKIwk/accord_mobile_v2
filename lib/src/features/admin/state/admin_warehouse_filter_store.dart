import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/session/state/app_session.dart';

class AdminWarehouseFilterStore {
  AdminWarehouseFilterStore._();

  static final AdminWarehouseFilterStore instance =
      AdminWarehouseFilterStore._();

  String? _cachedWarehouse;

  String? get cachedWarehouse => _cachedWarehouse;

  static String preferenceKey({String? profileRef}) {
    final ref = (profileRef ?? AppSession.instance.profile?.ref)?.trim() ?? '';
    return 'admin.warehouses.selected_warehouse.${ref.isEmpty ? 'default' : ref}';
  }

  Future<String?> loadSavedWarehouse({
    String? profileRef,
    SharedPreferences? preferences,
  }) async {
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      var warehouse =
          prefs.getString(preferenceKey(profileRef: profileRef))?.trim();

      final currentRef =
          (profileRef ?? AppSession.instance.profile?.ref)?.trim() ?? '';
      if ((warehouse == null || warehouse.isEmpty) && currentRef.isNotEmpty) {
        warehouse =
            prefs.getString(preferenceKey(profileRef: 'default'))?.trim();
      }

      if (warehouse != null && warehouse.isNotEmpty) {
        _cachedWarehouse = warehouse;
      }
      return _cachedWarehouse;
    } catch (_) {
      return _cachedWarehouse;
    }
  }

  Future<void> saveWarehouse(
    String warehouse, {
    String? profileRef,
    SharedPreferences? preferences,
  }) async {
    final normalized = warehouse.trim();
    _cachedWarehouse = normalized.isNotEmpty ? normalized : null;
    try {
      final prefs = preferences ?? await SharedPreferences.getInstance();
      if (normalized.isNotEmpty) {
        await prefs.setString(
          preferenceKey(profileRef: profileRef),
          normalized,
        );
        await prefs.setString(
          preferenceKey(profileRef: 'default'),
          normalized,
        );
      } else {
        await prefs.remove(preferenceKey(profileRef: profileRef));
        await prefs.remove(preferenceKey(profileRef: 'default'));
      }
    } catch (_) {}
  }

  String? resolveWarehouse(
    Iterable<String> availableWarehouses, {
    String? preferred,
  }) {
    final target = (preferred ?? _cachedWarehouse)?.trim().toLowerCase() ?? '';
    if (target.isEmpty) return null;

    for (final warehouse in availableWarehouses) {
      if (warehouse.trim().toLowerCase() == target) {
        return warehouse.trim();
      }
    }
    return null;
  }

  void clearCache() {
    _cachedWarehouse = null;
  }
}
