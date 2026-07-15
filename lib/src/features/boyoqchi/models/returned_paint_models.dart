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
    this.imageId = '',
  });

  final String orderId;
  final String orderCode;
  final String orderName;
  final String apparatus;
  final List<ReturnedPaintItemInput> items;
  final String imageId;

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'order_code': orderCode,
        'order_name': orderName,
        'apparatus': apparatus,
        if (imageId.trim().isNotEmpty) 'image_id': imageId.trim(),
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };
}

class ReturnedPaintCompleteSubmission {
  const ReturnedPaintCompleteSubmission({
    required this.requestId,
    required this.items,
  });

  final String requestId;
  final List<ReturnedPaintItemInput> items;

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'items': items.map((item) => item.toJson()).toList(growable: false),
      };
}

enum ReturnedPaintStatus {
  waitingForBoyoqchiInput,
  completed,
}

ReturnedPaintStatus returnedPaintStatusFromJson(Object? value) {
  return value?.toString().trim() == 'waiting_for_boyoqchi_input'
      ? ReturnedPaintStatus.waitingForBoyoqchiInput
      : ReturnedPaintStatus.completed;
}

class ReturnedPaintImage {
  const ReturnedPaintImage({
    required this.imageId,
    required this.imageName,
    required this.imageMime,
    required this.imageSizeBytes,
    required this.imageUrl,
  });

  final String imageId;
  final String imageName;
  final String imageMime;
  final int imageSizeBytes;
  final String imageUrl;

  factory ReturnedPaintImage.fromJson(Map<String, dynamic> json) {
    return ReturnedPaintImage(
      imageId: json['image_id']?.toString() ?? '',
      imageName: json['image_name']?.toString() ?? '',
      imageMime: json['image_mime']?.toString() ?? '',
      imageSizeBytes: (json['image_size_bytes'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'image_id': imageId,
        'image_name': imageName,
        'image_mime': imageMime,
        'image_size_bytes': imageSizeBytes,
        'image_url': imageUrl,
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
    this.status = ReturnedPaintStatus.completed,
    this.image,
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
  final ReturnedPaintStatus status;
  final ReturnedPaintImage? image;
  final ReturnedPaintCalculation? calculation;
  final String message;

  bool get waitingForBoyoqchiInput =>
      status == ReturnedPaintStatus.waitingForBoyoqchiInput;

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
      status: returnedPaintStatusFromJson(json['status']),
      message: json['message']?.toString() ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) => ReturnedPaintItemInput.fromJson(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      image: json['image'] is Map
          ? ReturnedPaintImage.fromJson(
              (json['image'] as Map).cast<String, dynamic>(),
            )
          : null,
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

  ReturnedPaintRequest copyWith({
    List<ReturnedPaintItemInput>? items,
    ReturnedPaintStatus? status,
    ReturnedPaintImage? image,
    bool clearImage = false,
    ReturnedPaintCalculation? calculation,
    bool clearCalculation = false,
    String? message,
  }) {
    return ReturnedPaintRequest(
      id: id,
      orderId: orderId,
      orderCode: orderCode,
      orderName: orderName,
      apparatus: apparatus,
      senderRole: senderRole,
      senderRef: senderRef,
      senderDisplayName: senderDisplayName,
      items: items ?? this.items,
      createdAt: createdAt,
      status: status ?? this.status,
      image: clearImage ? null : (image ?? this.image),
      calculation: clearCalculation ? null : (calculation ?? this.calculation),
      message: message ?? this.message,
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
