import '../../shared/models/app_models.dart';

class ReturnedPaintItemInput {
  const ReturnedPaintItemInput({
    required this.usage,
    required this.category,
    required this.name,
    required this.values,
  });

  final String usage;
  final String category;
  final String name;
  final Map<String, String> values;

  Map<String, dynamic> toJson() => {
        'usage': usage,
        'category': category,
        'name': name,
        'values': values,
      };

  factory ReturnedPaintItemInput.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    return ReturnedPaintItemInput(
      usage: json['usage']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      values: rawValues is Map
          ? rawValues.map(
              (key, value) => MapEntry(
                key.toString(),
                value.toString(),
              ),
            )
          : const <String, String>{},
    );
  }
}

double? returnedPaintAstatkaTotal(
  Iterable<ReturnedPaintItemInput> items,
) {
  final values = items.toList(growable: false);
  if (values.isEmpty) return null;

  var total = 0.0;
  for (final item in values) {
    if (item.usage.trim().toLowerCase() != 'astatka') continue;
    for (final value in item.values.values) {
      final parsed = double.tryParse(value);
      if (parsed == null || !parsed.isFinite) return null;
      total += parsed;
    }
  }
  return total.isFinite ? total : null;
}

class ReturnedPaintSubmission {
  const ReturnedPaintSubmission({
    required this.orderId,
    required this.orderCode,
    required this.orderName,
    required this.apparatus,
    required this.items,
  });

  final String orderId;
  final String orderCode;
  final String orderName;
  final String apparatus;
  final List<ReturnedPaintItemInput> items;

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'order_code': orderCode,
        'order_name': orderName,
        'apparatus': apparatus,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };
}

class ReturnedPaintRequest {
  const ReturnedPaintRequest({
    required this.id,
    required this.orderId,
    required this.orderCode,
    required this.orderName,
    required this.apparatus,
    required this.senderRole,
    required this.senderRef,
    required this.senderDisplayName,
    required this.items,
    required this.createdAt,
    this.calculation,
    this.message = '',
  });

  final String id;
  final String orderId;
  final String orderCode;
  final String orderName;
  final String apparatus;
  final UserRole senderRole;
  final String senderRef;
  final String senderDisplayName;
  final List<ReturnedPaintItemInput> items;
  final DateTime createdAt;
  final ReturnedPaintCalculation? calculation;
  final String message;

  factory ReturnedPaintRequest.fromJson(Map<String, dynamic> json) {
    final createdAtUnix = (json['created_at_unix'] as num?)?.toInt() ?? 0;
    return ReturnedPaintRequest(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      orderCode: json['order_code']?.toString() ?? '',
      orderName: json['order_name']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      senderRole: userRoleFromJson(json['sender_role']?.toString()),
      senderRef: json['sender_ref']?.toString() ?? '',
      senderDisplayName: json['sender_display_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ReturnedPaintItemInput.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      calculation: json['calculation'] is Map
          ? ReturnedPaintCalculation.fromJson(
              (json['calculation'] as Map).cast<String, dynamic>(),
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAtUnix * 1000,
        isUtc: true,
      ).toLocal(),
    );
  }
}

class ReturnedPaintCalculation {
  const ReturnedPaintCalculation({
    required this.rasxotMixTotal,
    required this.astatkaMixTotal,
    required this.rasxotAlcohol,
    required this.astatkaAlcohol,
    required this.finalUsedAlcohol,
    required this.rasxotPurePaint,
    required this.astatkaPurePaint,
    required this.finalUsedPaint,
  });

  final String rasxotMixTotal;
  final String astatkaMixTotal;
  final String rasxotAlcohol;
  final String astatkaAlcohol;
  final String finalUsedAlcohol;
  final String rasxotPurePaint;
  final String astatkaPurePaint;
  final String finalUsedPaint;

  factory ReturnedPaintCalculation.fromJson(Map<String, dynamic> json) {
    return ReturnedPaintCalculation(
      rasxotMixTotal: _decimalText(json['rasxot_mix_total']),
      astatkaMixTotal: _decimalText(json['astatka_mix_total']),
      rasxotAlcohol: _decimalText(json['rasxot_alcohol']),
      astatkaAlcohol: _decimalText(json['astatka_alcohol']),
      finalUsedAlcohol: _decimalText(json['final_used_alcohol']),
      rasxotPurePaint: _decimalText(json['rasxot_pure_paint']),
      astatkaPurePaint: _decimalText(json['astatka_pure_paint']),
      finalUsedPaint: _decimalText(json['final_used_paint']),
    );
  }
}

String _decimalText(Object? value) => value?.toString().trim() ?? '';

class ReturnedPaintRequestPage {
  const ReturnedPaintRequestPage({
    required this.items,
    required this.hasMore,
  });

  final List<ReturnedPaintRequest> items;
  final bool hasMore;

  factory ReturnedPaintRequestPage.fromJson(Map<String, dynamic> json) {
    return ReturnedPaintRequestPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ReturnedPaintRequest.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      hasMore: json['has_more'] == true,
    );
  }
}
