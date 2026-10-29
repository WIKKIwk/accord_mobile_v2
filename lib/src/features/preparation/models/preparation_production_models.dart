String _text(Map<String, dynamic> json, String key) =>
    json[key]?.toString() ?? '';

String _identity(Map<String, dynamic> json, String key) {
  final value = _text(json, key).trim();
  if (value.isEmpty) {
    throw const FormatException('Ishlab chiqarish ma’lumoti noto‘g‘ri');
  }
  return value;
}

int _count(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) {
    throw const FormatException('Ishlab chiqarish miqdori noto‘g‘ri');
  }
  return value;
}

String _amount(Map<String, dynamic> json, String key) {
  final value = _text(json, key);
  if (!RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(value)) {
    throw const FormatException('Ishlab chiqarish miqdori noto‘g‘ri');
  }
  return value;
}

Map<String, dynamic>? _recipe(Map<String, dynamic> json) {
  final value = json['preparation_formula'];
  if (value == null) return null;
  if (value is! Map) throw const FormatException('Formula ma’lumoti noto‘g‘ri');
  return Map<String, dynamic>.unmodifiable(value.cast<String, dynamic>());
}

List<T> _items<T>(Map<String, dynamic> json, String key,
    T Function(Map<String, dynamic>) decode) {
  final value = json[key];
  if (value is! List) {
    throw const FormatException('Ishlab chiqarish ro‘yxati noto‘g‘ri');
  }
  return List<T>.unmodifiable(value.map((entry) {
    if (entry is! Map) {
      throw const FormatException('Ishlab chiqarish yozuvi noto‘g‘ri');
    }
    return decode(entry.cast<String, dynamic>());
  }));
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) {
    throw const FormatException('Ishlab chiqarish yozuvi topilmadi');
  }
  return value.cast<String, dynamic>();
}

class PreparationProductionOrder {
  PreparationProductionOrder.fromJson(Map<String, dynamic> json)
      : id = _identity(json, 'order_id'),
        code = _text(json, 'order_code'),
        title = _text(json, 'order_title'),
        customerName = _text(json, 'customer_name'),
        activeBatchCount = _count(json, 'active_batch_count'),
        batchCount = _count(json, 'batch_count'),
        rollCount = _count(json, 'roll_count'),
        netKg = _amount(json, 'total_net_kg'),
        lengthM = _amount(json, 'total_length_m'),
        lastActivityAt = _text(json, 'last_activity_at');
  final String id, code, title, customerName, netKg, lengthM, lastActivityAt;
  final int activeBatchCount, batchCount, rollCount;
  String get displayCode => code.isEmpty ? id : code;
}

class PreparationProductionBatch {
  PreparationProductionBatch.fromJson(Map<String, dynamic> json)
      : id = _identity(json, 'batch_id'),
        orderId = _identity(json, 'order_id'),
        itemCode = _text(json, 'item_code'),
        itemName = _text(json, 'item_name'),
        warehouse = _text(json, 'warehouse'),
        active = json['active'] == true,
        startedAt = _text(json, 'started_at'),
        endedAt = _text(json, 'ended_at'),
        lastActivityAt = _text(json, 'last_activity_at'),
        rollCount = _count(json, 'roll_count'),
        netKg = _amount(json, 'total_net_kg'),
        lengthM = _amount(json, 'total_length_m'),
        formula = _recipe(json);
  final String id,
      orderId,
      itemCode,
      itemName,
      warehouse,
      startedAt,
      endedAt,
      lastActivityAt,
      netKg,
      lengthM;
  final bool active;
  final int rollCount;
  final Map<String, dynamic>? formula;
  String get displayItem => itemName.isEmpty ? itemCode : itemName;
  String get formulaName =>
      formula?['variant_name']?.toString() ?? 'Formula qayd etilmagan';
}

class PreparationProductionRoll {
  PreparationProductionRoll.fromJson(Map<String, dynamic> json)
      : epc = _identity(json, 'epc'),
        receiptName = _text(json, 'receipt_name'),
        itemCode = _text(json, 'item_code'),
        itemName = _text(json, 'item_name'),
        warehouse = _text(json, 'warehouse'),
        netKg = _amount(json, 'net_kg'),
        grossKg = json['gross_kg'] == null ? null : _amount(json, 'gross_kg'),
        lengthM = json['length_m'] == null ? null : _amount(json, 'length_m'),
        widthMm = json['width_mm'] == null ? null : _amount(json, 'width_mm'),
        micron = json['micron'] == null ? null : _amount(json, 'micron'),
        printedAt = _text(json, 'printed_at'),
        formula = _recipe(json);
  final String epc,
      receiptName,
      itemCode,
      itemName,
      warehouse,
      netKg,
      printedAt;
  final String? grossKg, lengthM, widthMm, micron;
  final Map<String, dynamic>? formula;
}

abstract class PreparationProductionPage {
  PreparationProductionPage(Map<String, dynamic> json)
      : hasMore = json['has_more'] == true,
        nextOffset =
            json['next_offset'] is int ? json['next_offset'] as int : null {
    if (json['has_more'] is! bool ||
        (hasMore && (nextOffset == null || nextOffset! <= 0))) {
      throw const FormatException('Ishlab chiqarish sahifasi noto‘g‘ri');
    }
  }
  final bool hasMore;
  final int? nextOffset;
}

class PreparationProductionOrdersPage extends PreparationProductionPage {
  PreparationProductionOrdersPage.fromJson(super.json)
      : orders = _items(json, 'orders', PreparationProductionOrder.fromJson);
  final List<PreparationProductionOrder> orders;
}

class PreparationProductionOrderPage extends PreparationProductionPage {
  PreparationProductionOrderPage.fromJson(super.json)
      : order = PreparationProductionOrder.fromJson(_object(json, 'order')),
        batches = _items(json, 'batches', PreparationProductionBatch.fromJson);
  final PreparationProductionOrder order;
  final List<PreparationProductionBatch> batches;
}

class PreparationProductionBatchPage extends PreparationProductionPage {
  PreparationProductionBatchPage.fromJson(super.json)
      : batch = PreparationProductionBatch.fromJson(_object(json, 'batch')),
        rolls = _items(json, 'rolls', PreparationProductionRoll.fromJson);
  final PreparationProductionBatch batch;
  final List<PreparationProductionRoll> rolls;
}
