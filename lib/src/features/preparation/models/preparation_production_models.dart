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

sealed class PreparationProductionRow {
  const PreparationProductionRow();
  String get journalKey;
}

class PreparationProductionOrder extends PreparationProductionRow {
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
  @override
  String get journalKey => id;
}

class PreparationProductionBatch extends PreparationProductionRow {
  PreparationProductionBatch.fromJson(Map<String, dynamic> json)
      : id = _identity(json, 'batch_id'),
        orderId = _text(json, 'order_id'),
        orderCode = _text(json, 'order_code'),
        orderTitle = _text(json, 'order_title'),
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
      orderCode,
      orderTitle,
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
  @override
  String get journalKey => id;
  String get displayItem => itemName.isEmpty ? itemCode : itemName;
  String get formulaName =>
      formula?['variant_name']?.toString() ?? 'Formula qayd etilmagan';
}

class PreparationProductionRoll extends PreparationProductionRow {
  PreparationProductionRoll.fromJson(Map<String, dynamic> json)
      : epc = _identity(json, 'epc'),
        receiptName = _text(json, 'receipt_name'),
        batchId = _text(json, 'batch_id'),
        orderId = _text(json, 'order_id'),
        orderCode = _text(json, 'order_code'),
        orderTitle = _text(json, 'order_title'),
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
      batchId,
      orderId,
      orderCode,
      orderTitle,
      itemCode,
      itemName,
      warehouse,
      netKg,
      printedAt;
  final String? grossKg, lengthM, widthMm, micron;
  final Map<String, dynamic>? formula;
  @override
  String get journalKey => receiptName.isEmpty ? epc : receiptName;
}

class PreparationMaterialPaddon extends PreparationProductionRow {
  PreparationMaterialPaddon.fromJson(Map<String, dynamic> json)
      : id = _identity(json, 'paddon_id'),
        code = _identity(json, 'paddon_code'),
        name = _text(json, 'name').trim(),
        warehouse = _identity(json, 'warehouse'),
        remainingKg = _amount(json, 'remaining_kg'),
        contents = _items(json, 'contents', PreparationPaddonContent.fromJson);

  final String id, code, name, warehouse, remainingKg;
  final List<PreparationPaddonContent> contents;

  @override
  String get journalKey => id;
}

class PreparationPaddonContent {
  PreparationPaddonContent.fromJson(Map<String, dynamic> json)
      : itemName = _identity(json, 'item_name'),
        lotNumber = _text(json, 'lot_number'),
        remainingKg = _amount(json, 'remaining_kg'),
        unitKg = json['unit_kg'] == null ? null : _amount(json, 'unit_kg'),
        remainingCount = json['remaining_count'] == null
            ? null
            : _count(json, 'remaining_count'),
        kind = _text(json, 'kind');

  final String itemName, lotNumber, remainingKg, kind;
  final String? unitKg;
  final int? remainingCount;
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

class PreparationProductionBatchesPage extends PreparationProductionPage {
  PreparationProductionBatchesPage.fromJson(super.json)
      : batches = _items(json, 'batches', PreparationProductionBatch.fromJson);
  final List<PreparationProductionBatch> batches;
}

class PreparationProductionRollsPage extends PreparationProductionPage {
  PreparationProductionRollsPage.fromJson(super.json)
      : rolls = _items(json, 'rolls', PreparationProductionRoll.fromJson);
  final List<PreparationProductionRoll> rolls;
}

class PreparationMaterialPaddonsPage extends PreparationProductionPage {
  PreparationMaterialPaddonsPage.fromJson(super.json)
      : paddons = _items(json, 'paddons', PreparationMaterialPaddon.fromJson);

  final List<PreparationMaterialPaddon> paddons;
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
