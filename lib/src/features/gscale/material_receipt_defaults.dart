import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../shared/models/app_models.dart';

/// A material can occur in several order layers with different thicknesses.
class MaterialReceiptChoice {
  const MaterialReceiptChoice(this.item, this.micron);
  final SupplierItem item;
  final double? micron;

  static List<MaterialReceiptChoice> fromItems(Iterable<SupplierItem> items) =>
      [
        for (final item in items)
          if (item.orderMicrons.isEmpty)
            MaterialReceiptChoice(item, null)
          else
            for (final micron in item.orderMicrons.toSet())
              MaterialReceiptChoice(item, micron),
      ];
}

/// Preferences are scoped to the backend and user, never shared across accounts.
class MaterialWarehousePreferences {
  MaterialWarehousePreferences(String userKey)
      : _key = 'material_receipt_warehouses_v1:$userKey';
  final String _key;

  Map<String, dynamic> _read(SharedPreferences prefs) {
    try {
      return Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_key) ?? '{}') as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> record(String warehouse) async {
    final prefs = await SharedPreferences.getInstance();
    final values = _read(prefs);
    final name = warehouse.trim().toLowerCase();
    if (name.isEmpty) return;
    final previous = values[name] as Map?;
    final sequence = values.values.fold<int>(
        0,
        (max, entry) => entry is Map && (entry['last'] as num? ?? 0) > max
            ? (entry['last'] as num).toInt()
            : max);
    values[name] = {
      'count': (previous?['count'] as num? ?? 0) + 1,
      'last': sequence + 1
    };
    await prefs.setString(_key, jsonEncode(values));
  }

  Future<String?> preferred(Iterable<String> allowed) async {
    final names = allowed.toSet().toList();
    final values = _read(await SharedPreferences.getInstance());
    int score(String name, String field) =>
        ((values[name.trim().toLowerCase()] as Map?)?[field] as num? ?? 0)
            .toInt();
    names.sort((a, b) {
      final count = score(b, 'count').compareTo(score(a, 'count'));
      return count != 0 ? count : score(b, 'last').compareTo(score(a, 'last'));
    });
    if (names.isEmpty || (names.length > 1 && score(names.first, 'count') == 0)) {
      return null;
    }
    return names.first;
  }
}
