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
      wastePercent: _calculateNumber(json['waste_percent'], fallback: 5),
      layers: layers,
      results: results,
    );
  }

  final bool ok;
  final double kg;
  final double widthMm;
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

String _calculateText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
