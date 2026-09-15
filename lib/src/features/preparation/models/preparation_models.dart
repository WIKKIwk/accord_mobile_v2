import 'dart:math';

BigInt preparationDecimal(String raw, {bool allowZero = false}) {
  final text = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(text)) {
    throw const FormatException(
        'Musbat son kiriting (ko‘pi bilan 6 kasr xona)');
  }
  final parts = text.split('.');
  final value = BigInt.parse(parts[0]) * BigInt.from(1000000) +
      BigInt.parse((parts.length == 1 ? '' : parts[1]).padRight(6, '0'));
  if ((!allowZero && value == BigInt.zero) ||
      value > BigInt.parse('999999999999999999')) {
    throw const FormatException('Miqdor ruxsat etilgan chegaradan tashqarida');
  }
  return value;
}

String preparationDecimalText(BigInt value) {
  final scale = BigInt.from(1000000);
  return '${value ~/ scale}.${(value % scale).toString().padLeft(6, '0')}';
}

String preparationRequiredKg(String orderKg, String percent) {
  final kg = preparationDecimal(orderKg);
  final pct = preparationDecimal(percent);
  if (pct > BigInt.from(100000000)) {
    throw const FormatException('Foiz 100 dan oshmasligi kerak');
  }
  final result = (kg * pct + BigInt.from(50000000)) ~/ BigInt.from(100000000);
  if (result == BigInt.zero) {
    throw const FormatException('Hisoblangan sarf 0.000001 kg dan kichik');
  }
  return preparationDecimalText(result);
}

String preparationDisplay(String value) => value.contains('.')
    ? value.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
    : value;

String newPreparationRequestId() {
  final random = Random.secure();
  return 'prep-${DateTime.now().microsecondsSinceEpoch}-'
      '${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class PreparationMaterial {
  PreparationMaterial.fromJson(Map<String, dynamic> json)
      : code = json['item_code'] as String,
        name = json['name'] as String,
        canReceive = json['can_receive'] != false,
        visibleWarehouses = json.containsKey('visible_warehouses')
            ? ((json['visible_warehouses'] is List)
                ? (json['visible_warehouses'] as List)
                    .whereType<String>()
                    .map((w) => w.trim().toLowerCase())
                    .where((w) => w.isNotEmpty)
                    .toSet()
                : <String>{})
            : null,
        balances = {
          for (final b in json['balances'] as List? ?? [])
            b['warehouse'] as String: b['kg'] as String
        };
  final String code, name;
  final bool canReceive;
  final Set<String>? visibleWarehouses;
  final Map<String, String> balances;
  String available(String? warehouse) => balances[warehouse] ?? '0';
  bool visibleIn(String? warehouse) {
    final key = warehouse?.trim().toLowerCase();
    if (key == null || key.isEmpty) return false;
    final scope = visibleWarehouses;
    return scope == null || scope.contains(key);
  }
}

class PreparationOrder {
  PreparationOrder.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        code = json['code'] as String? ?? '',
        title = json['title'] as String? ?? '',
        kg = json['order_kg'] as String,
        widthMm = double.tryParse(json['width_mm']?.toString() ?? ''),
        saved = json['saved'] == true;
  final String id, code, title, kg;
  final double? widthMm;
  final bool saved;
  String get label => '${code.isEmpty ? id : code} — $title';
}

List<String> _preparationWarehouseList(dynamic raw) => raw is List
    ? raw.whereType<String>().toList(growable: false)
    : const [];

class PreparationSnapshot {
  PreparationSnapshot.fromJson(Map<String, dynamic> json)
      : warehouses = _preparationWarehouseList(json['warehouses']),
        assignedWarehouses =
            _preparationWarehouseList(json['assigned_warehouses']),
        materialWarehouses =
            _preparationWarehouseList(json['material_warehouses']),
        materials = (json['materials'] as List)
            .map((m) => PreparationMaterial.fromJson(
                Map<String, dynamic>.from(m as Map)))
            .toList(),
        orders = (json['orders'] as List)
            .map((m) =>
                PreparationOrder.fromJson(Map<String, dynamic>.from(m as Map)))
            .toList(),
        history = (json['history'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList(),
        responsibilities = (json['responsibilities'] as List? ?? const [])
            .map((m) => PreparationResponsibility.fromJson(
                Map<String, dynamic>.from(m as Map)))
            .toList();
  final List<String> warehouses;
  final List<String> assignedWarehouses;
  final List<String> materialWarehouses;
  final List<PreparationMaterial> materials;
  final List<PreparationOrder> orders;
  final List<Map<String, dynamic>> history;
  final List<PreparationResponsibility> responsibilities;
}

class PreparationResponsibility {
  const PreparationResponsibility({
    required this.materialId,
    required this.materialName,
  });
  factory PreparationResponsibility.fromJson(Map<String, dynamic> json) =>
      PreparationResponsibility(
        materialId: (json['material_id'] as String? ?? '').trim(),
        materialName: (json['material_name'] as String? ?? '').trim(),
      );
  Map<String, String> toJson() =>
      {'material_id': materialId, 'material_name': materialName};
  final String materialId;
  final String materialName;
}

class PreparationPendingCommand {
  const PreparationPendingCommand(
      {required this.kind, required this.payload, required this.requestId});
  final String kind, requestId;
  final Map<String, dynamic> payload;
  Map<String, dynamic> toJson() =>
      {'kind': kind, 'payload': payload, 'request_id': requestId};
  factory PreparationPendingCommand.fromJson(Map<String, dynamic> json) =>
      PreparationPendingCommand(
          kind: json['kind'] as String,
          requestId: json['request_id'] as String,
          payload: Map<String, dynamic>.from(json['payload'] as Map));
}

class PreparationFormulaLine {
  const PreparationFormulaLine({
    required this.itemCode,
    required this.name,
    required this.percent,
  });
  factory PreparationFormulaLine.fromJson(Map<String, dynamic> json) =>
      PreparationFormulaLine(
        itemCode: (json['item_code'] as String? ?? '').trim(),
        name: (json['name'] as String? ?? '').trim(),
        percent: (json['percent'] as String? ?? '').trim(),
      );
  Map<String, String> toJson() => {'item_code': itemCode, 'percent': percent};
  final String itemCode;
  final String name;
  final String percent;
}

class PreparationFormula {
  const PreparationFormula({
    required this.productCode,
    required this.name,
    required this.lines,
  });
  factory PreparationFormula.fromJson(Map<String, dynamic> json) {
    final raw = json['lines'];
    final lines = raw is List
        ? [
            for (final e in raw)
              if (e is Map)
                PreparationFormulaLine.fromJson(
                    Map<String, dynamic>.from(e)),
          ]
        : const <PreparationFormulaLine>[];
    final sorted = [...lines]
      ..sort((a, b) {
        final byName =
            a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0
            ? byName
            : a.itemCode.compareTo(b.itemCode);
      });
    final rawName = json['name'] as String?;
    return PreparationFormula(
      productCode: (json['product_code'] as String? ?? '').trim(),
      name: (rawName == null || rawName.trim().isEmpty)
          ? 'Asosiy'
          : rawName.trim(),
      lines: List<PreparationFormulaLine>.unmodifiable(sorted),
    );
  }

  /// GET /formulas javobi: {"product_code":..., "formulas":[...]}.
  /// Nom bo'yicha alifbo tartibida saralanadi.
  static List<PreparationFormula> listFromJson(Map<String, dynamic> json) {
    final productCode = (json['product_code'] as String? ?? '').trim();
    final raw = json['formulas'];
    if (raw is! List) return const [];
    final formulas = [
      for (final e in raw)
        if (e is Map)
          PreparationFormula.fromJson({
            'product_code': productCode,
            ...Map<String, dynamic>.from(e),
          }),
    ]..sort((a, b) {
        final byName =
            a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.name.compareTo(b.name);
      });
    return List<PreparationFormula>.unmodifiable(formulas);
  }

  final String productCode;
  final String name;
  final List<PreparationFormulaLine> lines;
}
