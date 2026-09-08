import 'dart:math';

final _scale = BigInt.from(1000000);
final _maximum = BigInt.parse('999999999999999999');

BigInt rawSplitQuantity(String raw, {bool allowZero = false}) {
  final value = raw.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(value)) {
    throw const FormatException('Son kiriting (ko‘pi bilan 6 kasr xona)');
  }
  final parts = value.split('.');
  final units = BigInt.parse(parts[0]) * _scale +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(6, '0'));
  if (units > _maximum ||
      units < BigInt.zero ||
      (!allowZero && units == BigInt.zero)) {
    throw const FormatException('Miqdor ruxsat etilgan chegaradan tashqarida');
  }
  return units;
}

String rawSplitDecimal(BigInt units) =>
    '${units ~/ _scale}.${(units % _scale).toString().padLeft(6, '0')}';
String rawSplitDisplay(String value) =>
    rawSplitDecimal(rawSplitQuantity(value, allowZero: true))
        .replaceFirst(RegExp(r'\.?0+$'), '');
String newRawSplitRequestId() {
  final random = Random.secure();
  return 'split-${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

String _required(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Noto‘g‘ri javob: $key');
  }
  return value;
}

class RawSplitRoll {
  RawSplitRoll.fromJson(Map<String, dynamic> json)
      : stockId = _required(json, 'stock_id'),
        revision = json['revision'] as String?,
        barcode = _required(json, 'barcode'),
        warehouse = _required(json, 'warehouse'),
        itemCode = _required(json, 'item_code'),
        itemName = _required(json, 'item_name'),
        kg = _required(json, 'kg'),
        grossKg = json['gross_kg'] as String?,
        bobinaKg = json['bobina_kg'] as String?,
        widthMm = _required(json, 'width_mm'),
        micron = _required(json, 'micron') {
    rawSplitQuantity(kg);
    rawSplitQuantity(widthMm);
    rawSplitQuantity(micron);
    if ((grossKg == null) != (bobinaKg == null) ||
        (grossKg != null &&
            rawSplitQuantity(grossKg!) -
                    rawSplitQuantity(bobinaKg!, allowZero: true) !=
                rawSplitQuantity(kg))) {
      throw const FormatException('Brutto, babina va netto hisobi noto‘g‘ri');
    }
  }
  final String? revision;
  final String? grossKg, bobinaKg;
  String get labelName {
    final base = itemName.trim().replaceFirst(
        RegExp(r'\s*\d+(?:[.,]\d+)?\s*/\s*\d+(?:[.,]\d+)?\s*$'), '');
    return '${base.trim()} ${rawSplitDisplay(widthMm)}/${rawSplitDisplay(micron)}'
        .trim();
  }

  final String stockId,
      barcode,
      warehouse,
      itemCode,
      itemName,
      kg,
      widthMm,
      micron;
}

class RawSplitResult {
  RawSplitResult.fromJson(Map<String, dynamic> json)
      : id = _required(json, 'id'),
        source = RawSplitRoll.fromJson(
            Map<String, dynamic>.from(json['source'] as Map)),
        sourceKg = _required(json, 'source_kg'),
        outputKg = _required(json, 'output_kg'),
        wasteKg = _required(json, 'waste_kg'),
        createdAt = json['created_at'] as String?,
        outputs = (json['outputs'] as List)
            .map((e) =>
                RawSplitRoll.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false) {
    final sum = outputs.fold(BigInt.zero, (a, b) => a + rawSplitQuantity(b.kg));
    if (outputs.isEmpty ||
        outputs.length > 100 ||
        outputs.map((o) => o.barcode).toSet().length != outputs.length ||
        outputs.map((o) => o.stockId).toSet().length != outputs.length ||
        rawSplitQuantity(source.kg) != rawSplitQuantity(sourceKg) ||
        sum != rawSplitQuantity(outputKg) ||
        sum + rawSplitQuantity(wasteKg, allowZero: true) !=
            rawSplitQuantity(sourceKg) ||
        outputs.any((o) =>
            o.stockId == source.stockId ||
            o.barcode == source.barcode ||
            o.itemCode != source.itemCode ||
            o.warehouse != source.warehouse ||
            rawSplitQuantity(o.widthMm) > rawSplitQuantity(source.widthMm) ||
            rawSplitQuantity(o.micron) != rawSplitQuantity(source.micron))) {
      throw const FormatException('Bo‘lish natijasining hisobi noto‘g‘ri');
    }
  }
  final String id, sourceKg, outputKg, wasteKg;
  final String? createdAt;
  final RawSplitRoll source;
  final List<RawSplitRoll> outputs;
}

class RawSplitSnapshot {
  RawSplitSnapshot.fromJson(Map<String, dynamic> json)
      : warehouses = (json['warehouses'] as List).cast<String>(),
        history = (json['history'] as List)
            .map((e) =>
                RawSplitResult.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false);
  final List<String> warehouses;
  final List<RawSplitResult> history;
}
