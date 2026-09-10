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
    '${units.isNegative ? '-' : ''}${units.abs() ~/ _scale}.${(units.abs() % _scale).toString().padLeft(6, '0')}';

BigInt rawSplitDifference(String raw) {
  if (!RegExp(r'^-?\d+(\.\d{1,6})?$').hasMatch(raw)) {
    throw const FormatException('Farq miqdori noto‘g‘ri');
  }
  final parts = raw.replaceFirst('-', '').split('.');
  final absolute = BigInt.parse(parts[0]) * _scale +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(6, '0'));
  if (absolute > _maximum * BigInt.two) {
    throw const FormatException('Farq chegaradan tashqarida');
  }
  return raw.startsWith('-') ? -absolute : absolute;
}

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
        lengthM = json['length_m'] as String?,
        widthMm = _required(json, 'width_mm'),
        micron = _required(json, 'micron') {
    rawSplitQuantity(kg);
    rawSplitQuantity(widthMm);
    rawSplitQuantity(micron);
    if (lengthM != null && lengthM!.trim().isNotEmpty) {
      rawSplitQuantity(lengthM!);
    }
    if ((grossKg == null) != (bobinaKg == null) ||
        (grossKg != null &&
            rawSplitQuantity(grossKg!) -
                    rawSplitQuantity(bobinaKg!, allowZero: true) !=
                rawSplitQuantity(kg))) {
      throw const FormatException('Brutto, babina va netto hisobi noto‘g‘ri');
    }
  }
  final String? revision;
  final String? grossKg, bobinaKg, lengthM;
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
        issueId = json['issue_id'] as String?,
        issueNote = json['issue_note'] as String?,
        differenceKg = json['difference_kg'] as String? ?? '0.000000',
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
        sum +
                rawSplitQuantity(wasteKg, allowZero: true) +
                rawSplitDifference(differenceKg) !=
            rawSplitQuantity(sourceKg) ||
        (issueId == null && rawSplitDifference(differenceKg) != BigInt.zero) ||
        (issueId != null &&
            (issueId!.isEmpty ||
                issueNote == null ||
                issueNote!.trim().isEmpty)) ||
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
  final String id, sourceKg, outputKg, wasteKg, differenceKg;
  final String? issueId, issueNote;
  String get differenceLabel {
    final difference = rawSplitDifference(differenceKg);
    final kg =
        rawSplitDecimal(difference.abs()).replaceFirst(RegExp(r'\.?0+$'), '');
    return difference == BigInt.zero
        ? 'Muammo izoh bilan qayd etilgan'
        : '${difference.isNegative ? 'Izohli ortiqcha' : 'Izohli kamomad'}: $kg kg';
  }

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
            .toList(growable: false),
        issues = ((json['issues'] as List?) ?? const [])
            .map((e) =>
                RawSplitIssue.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false);
  final List<String> warehouses;
  final List<RawSplitResult> history;
  final List<RawSplitIssue> issues;
}

/// Waste is measured, never inferred or silently replaced by the difference.
class RawSplitWasteCheck {
  RawSplitWasteCheck(this.source, this.output, String enteredWaste) {
    try {
      waste = rawSplitQuantity(enteredWaste, allowZero: true);
    } on FormatException {
      waste = null;
    }
  }

  final BigInt source, output;
  late final BigInt? waste;
  BigInt? get difference => waste == null ? null : source - output - waste!;
  String? get kind => waste == null
      ? 'invalid_waste'
      : waste == BigInt.zero
          ? 'zero_waste'
          : difference! > BigInt.zero
              ? 'missing_weight'
              : difference! < BigInt.zero
                  ? 'excess_weight'
                  : null;

  String get message {
    if (waste == null) {
      return 'Atxot kg ni kiriting (0 dan katta, ko‘pi bilan 6 kasr xona).';
    }
    final lines = <String>[];
    if (waste == BigInt.zero) lines.add('Atxot 0 dan katta bo‘lishi kerak.');
    final delta = difference!;
    final amount =
        rawSplitDecimal(delta.abs()).replaceFirst(RegExp(r'\.?0+$'), '');
    if (delta > BigInt.zero) {
      lines.add('$amount kg hisobga olinmagan — yetishmayapti.');
    }
    if (delta < BigInt.zero) lines.add('Asl vazndan $amount kg oshib ketdi.');
    return lines.join('\n');
  }
}

class RawSplitIssue {
  RawSplitIssue.fromJson(Map<String, dynamic> json)
      : id = _required(json, 'id'),
        requestId = _required(json, 'request_id'),
        source = RawSplitRoll.fromJson(
            Map<String, dynamic>.from(json['source'] as Map)),
        note = _required(json, 'note'),
        actorRef = _required(json, 'actor_ref'),
        actorName = _required(json, 'actor_name'),
        createdAt = DateTime.parse(_required(json, 'created_at')),
        enteredWaste = json['entered_waste_kg'] as String,
        outputs = (json['outputs'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false) {
    var sum = BigInt.zero;
    for (final output in outputs) {
      final net = rawSplitQuantity(_required(output, 'kg'));
      if (rawSplitQuantity(_required(output, 'gross_kg')) -
              rawSplitQuantity(_required(output, 'bobina_kg'),
                  allowZero: true) !=
          net) {
        throw const FormatException('Muammodagi netto hisobi noto‘g‘ri');
      }
      rawSplitQuantity(_required(output, 'width_mm'));
      sum += net;
    }
    check = RawSplitWasteCheck(rawSplitQuantity(source.kg), sum, enteredWaste);
    final delta = check.difference;
    final expectedDelta = delta == null
        ? null
        : '${delta.isNegative ? '-' : ''}${rawSplitDecimal(delta.abs())}';
    if (outputs.isEmpty ||
        outputs.length > 100 ||
        check.kind == null ||
        json['kind'] != check.kind ||
        rawSplitQuantity(_required(json, 'source_kg')) != check.source ||
        json['output_kg'] != rawSplitDecimal(sum) ||
        json['difference_kg'] != expectedDelta ||
        json['waste_kg'] !=
            (check.waste == null ? null : rawSplitDecimal(check.waste!))) {
      throw const FormatException('Muammo hisobining javobi noto‘g‘ri');
    }
  }

  final String id, requestId, note, actorRef, actorName, enteredWaste;
  final DateTime createdAt;
  final RawSplitRoll source;
  final List<Map<String, dynamic>> outputs;
  late final RawSplitWasteCheck check;
}
