part of '../mobile_api.dart';

extension MobileApiCalculate on MobileApi {
  Future<CalculateResponse> calculate(CalculateRequest request) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(payload['error'], fallback: 'calculate_failed'),
        message: _calculateText(
          payload['detail'],
          fallback: _calculateText(
            payload['message'],
            fallback: 'Calculate failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return CalculateResponse.fromJson(payload);
  }

  Future<List<CalculateOrderTemplate>> calculateOrderTemplates() async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders'),
        headers: _headers(requireToken()),
      ),
    );
    final payload = _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(payload['error'], fallback: 'calculate_orders'),
        message: _calculateText(
          payload['detail'],
          fallback: 'Calculate orders failed',
        ),
        statusCode: response.statusCode,
      );
    }
    return (payload['templates'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CalculateOrderTemplate.fromJson(
              item.cast<String, dynamic>(),
            ))
        .toList(growable: false);
  }

  Future<CalculateOrderTemplate> upsertCalculateOrderTemplate(
    CalculateOrderTemplate template,
  ) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(template.toJson()),
      ),
    );
    final payload = _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code:
            _calculateText(payload['error'], fallback: 'calculate_order_save'),
        message: _calculateText(
          payload['detail'],
          fallback: 'Calculate order save failed',
        ),
        statusCode: response.statusCode,
      );
    }
    final raw = payload['template'];
    return CalculateOrderTemplate.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{},
    );
  }

  Future<void> deleteCalculateOrderTemplate(String id) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders/delete'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id}),
      ),
    );
    final payload = _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(payload['error'],
            fallback: 'calculate_order_delete'),
        message: _calculateText(
          payload['detail'],
          fallback: 'Calculate order delete failed',
        ),
        statusCode: response.statusCode,
      );
    }
  }

  Future<CalculateOrderImage> uploadCalculateOrderImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders/image'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'image/jpeg'
          ..['x-file-name'] = filename,
        body: bytes,
      ),
    );
    final payload = _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code:
            _calculateText(payload['error'], fallback: 'calculate_image_save'),
        message: _calculateText(
          payload['detail'],
          fallback: 'Calculate image save failed',
        ),
        statusCode: response.statusCode,
      );
    }
    final raw = payload['image'];
    return CalculateOrderImage.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{},
    );
  }

  String calculateOrderImageUrl(String imageUrl) {
    final value = imageUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '${MobileApi.baseUrl}$value';
    }
    return value;
  }
}

class CalculateRequest {
  const CalculateRequest({
    this.orderNumber = '',
    this.customer = '',
    this.product = '',
    this.status = '',
    this.materialDisplay = '',
    this.color = '',
    required this.kg,
    required this.widthMm,
    this.wastePercent = 5,
    this.rollCount,
    required this.firstLayer,
    required this.secondLayer,
    this.thirdLayer = const CalculateLayerInput(),
    this.note = '',
  });

  final String orderNumber;
  final String customer;
  final String product;
  final String status;
  final String materialDisplay;
  final String color;
  final double kg;
  final double widthMm;
  final double wastePercent;
  final double? rollCount;
  final CalculateLayerInput firstLayer;
  final CalculateLayerInput secondLayer;
  final CalculateLayerInput thirdLayer;
  final String note;

  Map<String, dynamic> toJson() {
    return {
      if (orderNumber.trim().isNotEmpty) 'order_number': orderNumber.trim(),
      if (customer.trim().isNotEmpty) 'customer': customer.trim(),
      if (product.trim().isNotEmpty) 'product': product.trim(),
      if (status.trim().isNotEmpty) 'status': status.trim(),
      if (materialDisplay.trim().isNotEmpty)
        'material_display': materialDisplay.trim(),
      if (color.trim().isNotEmpty) 'color': color.trim(),
      'kg': kg,
      'width_mm': widthMm,
      'waste_percent': wastePercent,
      if (rollCount != null) 'roll_count': rollCount,
      'first_layer': firstLayer.toJson(),
      'second_layer': secondLayer.toJson(),
      if (!thirdLayer.isEmpty) 'third_layer': thirdLayer.toJson(),
      if (note.trim().isNotEmpty) 'note': note.trim(),
    };
  }
}

class CalculateLayerInput {
  const CalculateLayerInput({
    this.material = '',
    this.micron = '',
  });

  final String material;
  final String micron;

  bool get isEmpty => material.trim().isEmpty && micron.trim().isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'material': material.trim(),
      'micron': micron.trim(),
    };
  }
}

class CalculateResponse {
  const CalculateResponse({
    required this.ok,
    required this.kg,
    required this.widthMm,
    required this.rubberSizeMm,
    required this.wastePercent,
    required this.layers,
    required this.results,
  });

  factory CalculateResponse.fromJson(Map<String, dynamic> json) {
    final layers = (json['layers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CalculateLayer.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    final results = (json['results'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CalculateResult.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    return CalculateResponse(
      ok: json['ok'] == true,
      kg: _calculateNumber(json['kg']),
      widthMm: _calculateNumber(json['width_mm']),
      rubberSizeMm: _calculateInt(json['rubber_size_mm']),
      wastePercent: _calculateNumber(json['waste_percent'], fallback: 5),
      layers: layers,
      results: results,
    );
  }

  final bool ok;
  final double kg;
  final double widthMm;
  final int rubberSizeMm;
  final double wastePercent;
  final List<CalculateLayer> layers;
  final List<CalculateResult> results;
}

class CalculateLayer {
  const CalculateLayer({
    required this.material,
    required this.micron,
  });

  factory CalculateLayer.fromJson(Map<String, dynamic> json) {
    return CalculateLayer(
      material: _calculateText(json['material']),
      micron: _calculateText(json['micron']),
    );
  }

  final String material;
  final String micron;
}

class CalculateResult {
  const CalculateResult({
    required this.firstCoeff,
    required this.otherCoeff,
    required this.coeffSum,
    required this.widthSm,
    required this.baseLength,
    required this.wasteLength,
    required this.roundedLength,
  });

  factory CalculateResult.fromJson(Map<String, dynamic> json) {
    return CalculateResult(
      firstCoeff: _calculateNumber(json['first_coeff']),
      otherCoeff: _calculateNumber(json['other_coeff']),
      coeffSum: _calculateNumber(json['coeff_sum']),
      widthSm: _calculateNumber(json['width_sm']),
      baseLength: _calculateNumber(json['base_length']),
      wasteLength: _calculateNumber(json['waste_length']),
      roundedLength: _calculateNumber(json['rounded_length']),
    );
  }

  final double firstCoeff;
  final double otherCoeff;
  final double coeffSum;
  final double widthSm;
  final double baseLength;
  final double wasteLength;
  final double roundedLength;
}

class CalculateOrderTemplate {
  const CalculateOrderTemplate({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.orderNumber,
    required this.customerRef,
    required this.customer,
    required this.itemCode,
    required this.product,
    required this.status,
    required this.materialDisplay,
    required this.color,
    required this.imageId,
    required this.imageName,
    required this.imageMime,
    required this.imageSizeBytes,
    required this.imageUrl,
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
      id: _calculateText(json['id']),
      name: _calculateText(json['name']),
      savedAt: _calculateDate(json['saved_at']),
      orderNumber: _calculateText(json['order_number']),
      customerRef: _calculateText(json['customer_ref']),
      customer: _calculateText(json['customer']),
      itemCode: _calculateText(json['item_code']),
      product: _calculateText(json['product']),
      status: _calculateText(json['status']),
      materialDisplay: _calculateText(json['material_display']),
      color: _calculateText(json['color']),
      imageId: _calculateText(json['image_id']),
      imageName: _calculateText(json['image_name']),
      imageMime: _calculateText(json['image_mime']),
      imageSizeBytes: _calculateInt(json['image_size_bytes']),
      imageUrl: _calculateText(json['image_url']),
      widthMm: _calculateNumber(json['width_mm']),
      wastePercent: _calculateNumber(json['waste_percent'], fallback: 5),
      rollCount: _calculateOptionalNumber(json['roll_count']),
      firstLayerMaterial: _calculateText(json['first_layer_material']),
      firstLayerMicron: _calculateText(json['first_layer_micron']),
      secondLayerMaterial: _calculateText(json['second_layer_material']),
      secondLayerMicron: _calculateText(json['second_layer_micron']),
      thirdLayerMaterial: _calculateText(json['third_layer_material']),
      thirdLayerMicron: _calculateText(json['third_layer_micron']),
      note: _calculateText(json['note']),
    );
  }

  final String id;
  final String name;
  final DateTime savedAt;
  final String orderNumber;
  final String customerRef;
  final String customer;
  final String itemCode;
  final String product;
  final String status;
  final String materialDisplay;
  final String color;
  final String imageId;
  final String imageName;
  final String imageMime;
  final int imageSizeBytes;
  final String imageUrl;
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

  Map<String, dynamic> toJson() {
    return {
      if (id.trim().isNotEmpty) 'id': id.trim(),
      'name': name.trim(),
      if (savedAt.millisecondsSinceEpoch > 0)
        'saved_at': savedAt.toUtc().toIso8601String(),
      'order_number': orderNumber.trim(),
      'customer_ref': customerRef.trim(),
      'customer': customer.trim(),
      'item_code': itemCode.trim(),
      'product': product.trim(),
      'status': status.trim(),
      'material_display': materialDisplay.trim(),
      'color': color.trim(),
      'image_id': imageId.trim(),
      'image_name': imageName.trim(),
      'image_mime': imageMime.trim(),
      'image_size_bytes': imageSizeBytes,
      'image_url': imageUrl.trim(),
      'width_mm': widthMm,
      'waste_percent': wastePercent,
      if (rollCount != null) 'roll_count': rollCount,
      'first_layer_material': firstLayerMaterial.trim(),
      'first_layer_micron': firstLayerMicron.trim(),
      'second_layer_material': secondLayerMaterial.trim(),
      'second_layer_micron': secondLayerMicron.trim(),
      'third_layer_material': thirdLayerMaterial.trim(),
      'third_layer_micron': thirdLayerMicron.trim(),
      'note': note.trim(),
    };
  }
}

class CalculateOrderImage {
  const CalculateOrderImage({
    required this.imageId,
    required this.imageName,
    required this.imageMime,
    required this.imageSizeBytes,
    required this.imageUrl,
  });

  factory CalculateOrderImage.fromJson(Map<String, dynamic> json) {
    return CalculateOrderImage(
      imageId: _calculateText(json['image_id']),
      imageName: _calculateText(json['image_name']),
      imageMime: _calculateText(json['image_mime']),
      imageSizeBytes: _calculateInt(json['image_size_bytes']),
      imageUrl: _calculateText(json['image_url']),
    );
  }

  final String imageId;
  final String imageName;
  final String imageMime;
  final int imageSizeBytes;
  final String imageUrl;
}

Map<String, dynamic> _calculateDecodeObject(String body) {
  try {
    return (jsonDecode(body) as Map?)?.cast<String, dynamic>() ?? const {};
  } catch (_) {
    return const {};
  }
}

double _calculateNumber(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _calculateOptionalNumber(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(text);
}

int _calculateInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _calculateText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

DateTime _calculateDate(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  final parsed = DateTime.tryParse(text);
  if (parsed != null) {
    return parsed;
  }
  final micros = int.tryParse(text);
  if (micros != null) {
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
