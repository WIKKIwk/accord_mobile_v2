import '../../../core/session/session.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalculateOrderTemplate {
  const CalculateOrderTemplate({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.orderNumber,
    required this.customer,
    required this.product,
    required this.status,
    required this.materialDisplay,
    required this.color,
    required this.widthMm,
    required this.wastePercent,
    required this.rollCount,
    required this.firstLayerMaterial,
    required this.firstLayerMicron,
    required this.secondLayerMaterial,
    required this.secondLayerMicron,
    required this.thirdLayerMaterial,
    required this.thirdLayerMicron,
    required this.note,
  });

  factory CalculateOrderTemplate.fromJson(Map<String, dynamic> json) {
    return CalculateOrderTemplate(
      id: _text(json['id']),
      name: _text(json['name']),
      savedAt: DateTime.tryParse(_text(json['saved_at'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      orderNumber: _text(json['order_number']),
      customer: _text(json['customer']),
      product: _text(json['product']),
      status: _text(json['status']),
      materialDisplay: _text(json['material_display']),
      color: _text(json['color']),
      widthMm: _number(json['width_mm']),
      wastePercent: _number(json['waste_percent'], fallback: 5),
      rollCount: _optionalNumber(json['roll_count']),
      firstLayerMaterial: _text(json['first_layer_material']),
      firstLayerMicron: _text(json['first_layer_micron']),
      secondLayerMaterial: _text(json['second_layer_material']),
      secondLayerMicron: _text(json['second_layer_micron']),
      thirdLayerMaterial: _text(json['third_layer_material']),
      thirdLayerMicron: _text(json['third_layer_micron']),
      note: _text(json['note']),
    );
  }

  final String id;
  final String name;
  final DateTime savedAt;
  final String orderNumber;
  final String customer;
  final String product;
  final String status;
  final String materialDisplay;
  final String color;
  final double widthMm;
  final double wastePercent;
  final double? rollCount;
  final String firstLayerMaterial;
  final String firstLayerMicron;
  final String secondLayerMaterial;
  final String secondLayerMicron;
  final String thirdLayerMaterial;
  final String thirdLayerMicron;
  final String note;

  CalculateOrderTemplate copyWith({
    String? id,
    DateTime? savedAt,
  }) {
    return CalculateOrderTemplate(
      id: id ?? this.id,
      name: name,
      savedAt: savedAt ?? this.savedAt,
      orderNumber: orderNumber,
      customer: customer,
      product: product,
      status: status,
      materialDisplay: materialDisplay,
      color: color,
      widthMm: widthMm,
      wastePercent: wastePercent,
      rollCount: rollCount,
      firstLayerMaterial: firstLayerMaterial,
      firstLayerMicron: firstLayerMicron,
      secondLayerMaterial: secondLayerMaterial,
      secondLayerMicron: secondLayerMicron,
      thirdLayerMaterial: thirdLayerMaterial,
      thirdLayerMicron: thirdLayerMicron,
      note: note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'saved_at': savedAt.toUtc().toIso8601String(),
      'order_number': orderNumber,
      'customer': customer,
      'product': product,
      'status': status,
      'material_display': materialDisplay,
      'color': color,
      'width_mm': widthMm,
      'waste_percent': wastePercent,
      if (rollCount != null) 'roll_count': rollCount,
      'first_layer_material': firstLayerMaterial,
      'first_layer_micron': firstLayerMicron,
      'second_layer_material': secondLayerMaterial,
      'second_layer_micron': secondLayerMicron,
      'third_layer_material': thirdLayerMaterial,
      'third_layer_micron': thirdLayerMicron,
      'note': note,
    };
  }
}

class CalculateOrderTemplateStore extends ChangeNotifier {
  CalculateOrderTemplateStore({
    this.prefsKey = 'admin_calculate_orders_v1',
  });

  static final CalculateOrderTemplateStore instance =
      CalculateOrderTemplateStore();

  final String prefsKey;
  final Map<String, List<CalculateOrderTemplate>> _templatesByUser = {};
  bool _loaded = false;

  List<CalculateOrderTemplate> get templates {
    final key = _userKey();
    if (key == null) {
      return const <CalculateOrderTemplate>[];
    }
    return List<CalculateOrderTemplate>.unmodifiable(
      _templatesByUser[key] ?? const <CalculateOrderTemplate>[],
    );
  }

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    _templatesByUser.clear();
    if (raw != null && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final rows = entry.value as List<dynamic>? ?? const <dynamic>[];
        _templatesByUser[entry.key] = rows
            .whereType<Map>()
            .map((row) => CalculateOrderTemplate.fromJson(
                  row.cast<String, dynamic>(),
                ))
            .where((template) => template.name.trim().isNotEmpty)
            .toList(growable: false);
      }
    }
    for (final entry in _templatesByUser.entries) {
      entry.value.sort((left, right) => right.savedAt.compareTo(left.savedAt));
    }
    _loaded = true;
  }

  Future<void> upsert(CalculateOrderTemplate template) async {
    final key = _userKey();
    if (key == null) {
      return;
    }
    await load();
    final list = List<CalculateOrderTemplate>.from(
      _templatesByUser[key] ?? const <CalculateOrderTemplate>[],
    );
    final normalizedName = _normalizeName(template.name);
    final index = list.indexWhere(
      (item) => _normalizeName(item.name) == normalizedName,
    );
    final existingId = index >= 0 ? list[index].id : '';
    final saved = template.copyWith(
      id: existingId.isNotEmpty ? existingId : _newId(),
      savedAt: DateTime.now().toUtc(),
    );
    if (index >= 0) {
      list[index] = saved;
    } else {
      list.add(saved);
    }
    list.sort((left, right) => right.savedAt.compareTo(left.savedAt));
    _templatesByUser[key] = list;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final key = _userKey();
    if (key == null) {
      return;
    }
    await load();
    final list = List<CalculateOrderTemplate>.from(
      _templatesByUser[key] ?? const <CalculateOrderTemplate>[],
    )..removeWhere((template) => template.id == id);
    _templatesByUser[key] = list;
    await _persist();
    notifyListeners();
  }

  Future<void> debugReset() async {
    _templatesByUser.clear();
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    notifyListeners();
  }

  Future<void> _persist() async {
    final payload = <String, List<Map<String, dynamic>>>{};
    for (final entry in _templatesByUser.entries) {
      payload[entry.key] = entry.value.map((item) => item.toJson()).toList();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, jsonEncode(payload));
  }

  String? _userKey() {
    final profile = AppSession.instance.profile;
    if (profile == null) {
      return null;
    }
    return '${profile.accessRole?.name ?? profile.role.name}:${profile.ref}';
  }
}

String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

String _normalizeName(String value) => value.trim().toLowerCase();

String _text(Object? value) => value?.toString().trim() ?? '';

double _number(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _optionalNumber(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return double.tryParse(text);
}
