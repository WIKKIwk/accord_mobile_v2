part of '../mobile_api.dart';

final List<CalculateOrderTemplate> _testModeCalculateOrderTemplates = [];
final List<CalculateMaterial> _testModeCalculateMaterials =
    List<CalculateMaterial>.from(_defaultCalculateMaterials());
const double kCalculateEdgeAllowanceMm = 15;
const double kCalculateMinMoldExtraMm = 50;
const double kCalculateAdhesiveGsmPerBond = 2.5;

void resetMobileApiCalculateTestModeData() {
  _testModeCalculateOrderTemplates.clear();
  _testModeCalculateMaterials
    ..clear()
    ..addAll(_defaultCalculateMaterials());
}

extension MobileApiCalculate on MobileApi {
  Future<CalculateResponse> calculate(CalculateRequest request) async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeCalculate(request);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
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

  Future<List<CalculateMaterial>> calculateMaterials() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<CalculateMaterial>.unmodifiable(_testModeCalculateMaterials);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/calculate-materials'),
        headers: _headers(requireToken()),
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(payload['error'], fallback: 'calculate_materials'),
        message: _calculateText(
          payload['detail'],
          fallback: _calculateText(
            payload['error'],
            fallback: 'Calculate materials failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return (payload['materials'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CalculateMaterial.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<CalculateMaterial> upsertCalculateMaterial(
    CalculateMaterial material,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final saved = material.id.trim().isEmpty
          ? material.copyWith(
              id: 'test-material-${DateTime.now().millisecondsSinceEpoch}',
            )
          : material;
      _testModeCalculateMaterials.removeWhere((item) => item.id == saved.id);
      _testModeCalculateMaterials.add(saved);
      return saved;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/calculate-materials'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(material.toJson()),
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(
          payload['error'],
          fallback: 'calculate_material_save',
        ),
        message: _calculateText(
          payload['detail'],
          fallback: _calculateText(
            payload['error'],
            fallback: 'Calculate material save failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    final raw = payload['material'];
    return CalculateMaterial.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{},
    );
  }

  Future<List<CalculateOrderTemplate>> calculateOrderTemplates() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<CalculateOrderTemplate>.unmodifiable(
        _testModeCalculateOrderTemplates,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders'),
        headers: _headers(requireToken()),
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
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
        .map(
          (item) =>
              CalculateOrderTemplate.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<CalculateOrderTemplate> upsertCalculateOrderTemplate(
    CalculateOrderTemplate template,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeUpsertCalculateOrderTemplate(template);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(template.toJson()),
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(
          payload['error'],
          fallback: 'calculate_order_save',
        ),
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
    if (await TestModeController.instance.isEnabled()) {
      _testModeCalculateOrderTemplates.removeWhere(
        (template) => template.id.trim() == id.trim(),
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders/delete'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id}),
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(
          payload['error'],
          fallback: 'calculate_order_delete',
        ),
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
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/calculate/orders/image'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'image/jpeg'
          ..['x-file-name'] = filename,
        body: bytes,
      ),
    );
    final payload = await _calculateDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _calculateText(
          payload['error'],
          fallback: 'calculate_image_save',
        ),
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

CalculateResponse _testModeCalculate(CalculateRequest request) {
  final widthSm = request.widthMm / 10;
  final rubberSize = productionMapRubberSizeFromWidth(request.widthMm);
  final layers = request.effectiveLayers;
  final layerGsm = layers.map(_testModeLayerGsm).toList(growable: false);
  if (layers.isEmpty || layerGsm.any((gsm) => gsm <= 0)) {
    throw StateError('Xomashyo katalogdan aniq tanlanishi kerak');
  }
  if (request.wastePercent < 0 || request.wastePercent >= 100) {
    throw StateError('Atxod foiz noto‘g‘ri');
  }
  final filmGsm = layerGsm.fold<double>(0, (sum, gsm) => sum + gsm);
  final adhesiveGsm = (layers.length - 1).clamp(0, layers.length).toDouble() *
      kCalculateAdhesiveGsmPerBond;
  final totalGsm = filmGsm + adhesiveGsm;
  final baseLength = request.widthMm <= 0 || totalGsm <= 0
      ? 0.0
      : request.kg * 1000000 / (request.widthMm * totalGsm);
  final productionLength = baseLength / (1 - request.wastePercent / 100);
  final wasteLength = productionLength - baseLength;
  final roundedLength = (productionLength / 500).ceil() * 500.0;
  final firstGsm = layerGsm.isEmpty ? 0.0 : layerGsm.first;
  final firstCoeff = firstGsm * 0.06;
  final otherCoeff = (totalGsm - firstGsm) * 0.06;
  final coeffSum = totalGsm * 0.06;
  return CalculateResponse(
    ok: true,
    kg: request.kg,
    frameProductSizeMm: request.frameProductSizeMm,
    frameCount: request.frameCount,
    edgeAllowanceMm: request.edgeAllowanceMm,
    widthMm: request.widthMm,
    minMoldSizeMm: request.minMoldSizeMm,
    rubberSizeMm: rubberSize,
    wastePercent: request.wastePercent,
    layers: layers
        .map(
          (layer) => CalculateLayer(
            materialId: layer.materialId,
            material: layer.material,
            micron: layer.micron,
          ),
        )
        .toList(growable: false),
    results: [
      CalculateResult(
        filmGsm: filmGsm,
        adhesiveGsm: adhesiveGsm,
        totalGsm: totalGsm,
        firstCoeff: firstCoeff,
        otherCoeff: otherCoeff,
        coeffSum: coeffSum,
        widthSm: widthSm,
        baseLength: baseLength,
        wasteLength: wasteLength,
        roundedLength: roundedLength,
      ),
    ],
  );
}

double _testModeLayerGsm(CalculateLayerInput layer) {
  final materialKey = _calculateMaterialKey(layer.material);
  CalculateMaterial? material;
  for (final candidate in _testModeCalculateMaterials) {
    final matches = layer.materialId.trim().isNotEmpty
        ? candidate.id.trim() == layer.materialId.trim()
        : _calculateMaterialKey(candidate.name) == materialKey;
    if (matches) {
      material = candidate;
      break;
    }
  }
  final micron = int.tryParse(layer.micron.trim()) ?? 0;
  CalculateMaterialVariant? variant;
  for (final candidate
      in material?.variants ?? const <CalculateMaterialVariant>[]) {
    if (candidate.micron == micron) {
      variant = candidate;
      break;
    }
  }
  final actualGsm = variant?.actualGsm;
  if (actualGsm != null && actualGsm > 0) {
    return actualGsm;
  }
  if (material != null && material.densityGCm3 > 0 && micron > 0) {
    return material.densityGCm3 * micron;
  }
  if (variant != null && variant.coefficient > 0) {
    return variant.coefficient * (1000000 / 60000);
  }
  return 0;
}

String _calculateMaterialKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class CalculateRequest {
  const CalculateRequest({
    this.orderNumber = '',
    this.customer = '',
    this.product = '',
    this.status = '',
    this.materialDisplay = '',
    this.color = '',
    required this.kg,
    required this.frameProductSizeMm,
    required this.frameCount,
    this.edgeAllowanceMm = kCalculateEdgeAllowanceMm,
    this.wastePercent = 5,
    this.rollCount,
    this.layers = const <CalculateLayerInput>[],
    this.firstLayer = const CalculateLayerInput(),
    this.secondLayer = const CalculateLayerInput(),
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
  final double frameProductSizeMm;
  final double frameCount;
  final double edgeAllowanceMm;
  final double wastePercent;
  final double? rollCount;
  final List<CalculateLayerInput> layers;
  final CalculateLayerInput firstLayer;
  final CalculateLayerInput secondLayer;
  final CalculateLayerInput thirdLayer;
  final String note;

  double get widthMm =>
      _deriveCalculateWidthMm(frameProductSizeMm, frameCount, edgeAllowanceMm);

  double get minMoldSizeMm =>
      _deriveCalculateMinMoldSizeMm(frameProductSizeMm, frameCount);

  List<CalculateLayerInput> get effectiveLayers {
    if (layers.isNotEmpty) {
      return layers;
    }
    return [firstLayer, secondLayer, thirdLayer]
        .where((layer) => !layer.isEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    final effective = effectiveLayers;
    CalculateLayerInput legacy(int index) => index < effective.length
        ? effective[index]
        : const CalculateLayerInput();
    return {
      if (orderNumber.trim().isNotEmpty) 'order_number': orderNumber.trim(),
      if (customer.trim().isNotEmpty) 'customer': customer.trim(),
      if (product.trim().isNotEmpty) 'product': product.trim(),
      if (status.trim().isNotEmpty) 'status': status.trim(),
      if (materialDisplay.trim().isNotEmpty)
        'material_display': materialDisplay.trim(),
      if (color.trim().isNotEmpty) 'color': color.trim(),
      'kg': kg,
      'frame_product_size_mm': frameProductSizeMm,
      'frame_count': frameCount,
      'edge_allowance_mm': edgeAllowanceMm,
      'waste_percent': wastePercent,
      if (rollCount != null) 'roll_count': rollCount,
      'layers':
          effective.map((layer) => layer.toJson()).toList(growable: false),
      'first_layer': legacy(0).toJson(),
      'second_layer': legacy(1).toJson(),
      if (!legacy(2).isEmpty) 'third_layer': legacy(2).toJson(),
      if (note.trim().isNotEmpty) 'note': note.trim(),
    };
  }
}

class CalculateLayerInput {
  const CalculateLayerInput({
    this.materialId = '',
    this.material = '',
    this.micron = '',
  });

  final String materialId;
  final String material;
  final String micron;

  bool get isEmpty => material.trim().isEmpty && micron.trim().isEmpty;

  Map<String, dynamic> toJson() {
    return {
      if (materialId.trim().isNotEmpty) 'material_id': materialId.trim(),
      'material': material.trim(),
      'micron': micron.trim(),
    };
  }
}

class CalculateMaterialVariant {
  const CalculateMaterialVariant({
    required this.micron,
    this.coefficient = 0,
    this.firstLayerCoefficient,
    this.actualGsm,
  });

  factory CalculateMaterialVariant.fromJson(Map<String, dynamic> json) {
    return CalculateMaterialVariant(
      micron: _calculateInt(json['micron']),
      coefficient: _calculateNumber(json['coefficient']),
      firstLayerCoefficient: _calculateOptionalNumber(
        json['first_layer_coefficient'],
      ),
      actualGsm: _calculateOptionalNumber(json['actual_gsm']),
    );
  }

  final int micron;
  final double coefficient;
  final double? firstLayerCoefficient;
  final double? actualGsm;

  Map<String, dynamic> toJson() {
    return {
      'micron': micron,
      'coefficient': coefficient,
      if (firstLayerCoefficient != null)
        'first_layer_coefficient': firstLayerCoefficient,
      if (actualGsm != null) 'actual_gsm': actualGsm,
    };
  }
}

class CalculateMaterial {
  const CalculateMaterial({
    required this.id,
    required this.name,
    required this.active,
    this.densityGCm3 = 0,
    required this.variants,
  });

  factory CalculateMaterial.fromJson(Map<String, dynamic> json) {
    final variants = (json['variants'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => CalculateMaterialVariant.fromJson(
            item.cast<String, dynamic>(),
          ),
        )
        .where((variant) => variant.micron > 0)
        .toList(growable: false);
    return CalculateMaterial(
      id: _calculateText(json['id']),
      name: _calculateText(json['name']),
      active: json['active'] != false,
      densityGCm3: _calculateNumber(json['density_g_cm3']),
      variants: variants,
    );
  }

  final String id;
  final String name;
  final bool active;
  final double densityGCm3;
  final List<CalculateMaterialVariant> variants;

  CalculateMaterial copyWith({
    String? id,
    String? name,
    bool? active,
    double? densityGCm3,
    List<CalculateMaterialVariant>? variants,
  }) {
    return CalculateMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      active: active ?? this.active,
      densityGCm3: densityGCm3 ?? this.densityGCm3,
      variants: variants ?? this.variants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.trim().isNotEmpty) 'id': id.trim(),
      'name': name.trim(),
      'active': active,
      'density_g_cm3': densityGCm3,
      'variants': variants.map((variant) => variant.toJson()).toList(),
    };
  }
}

class CalculateResponse {
  const CalculateResponse({
    required this.ok,
    required this.kg,
    required this.frameProductSizeMm,
    required this.frameCount,
    required this.edgeAllowanceMm,
    required this.widthMm,
    required this.minMoldSizeMm,
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
    final widthMm = _calculateNumber(json['width_mm']);
    final frameProductSizeMm = _calculateNumber(
      json['frame_product_size_mm'],
      fallback: widthMm > kCalculateEdgeAllowanceMm
          ? widthMm - kCalculateEdgeAllowanceMm
          : 0,
    );
    final frameCount = _calculateNumber(
      json['frame_count'],
      fallback: widthMm > 0 ? 1 : 0,
    );
    return CalculateResponse(
      ok: json['ok'] == true,
      kg: _calculateNumber(json['kg']),
      frameProductSizeMm: frameProductSizeMm,
      frameCount: frameCount,
      edgeAllowanceMm: _calculateNumber(
        json['edge_allowance_mm'],
        fallback: kCalculateEdgeAllowanceMm,
      ),
      widthMm: widthMm,
      minMoldSizeMm: _calculateNumber(
        json['min_mold_size_mm'],
        fallback: _deriveCalculateMinMoldSizeMm(frameProductSizeMm, frameCount),
      ),
      rubberSizeMm: _calculateInt(json['rubber_size_mm']),
      wastePercent: _calculateNumber(json['waste_percent'], fallback: 5),
      layers: layers,
      results: results,
    );
  }

  final bool ok;
  final double kg;
  final double frameProductSizeMm;
  final double frameCount;
  final double edgeAllowanceMm;
  final double widthMm;
  final double minMoldSizeMm;
  final int rubberSizeMm;
  final double wastePercent;
  final List<CalculateLayer> layers;
  final List<CalculateResult> results;
}

class CalculateLayer {
  const CalculateLayer({
    required this.materialId,
    required this.material,
    required this.micron,
  });

  factory CalculateLayer.fromJson(Map<String, dynamic> json) {
    return CalculateLayer(
      materialId: _calculateText(json['material_id']),
      material: _calculateText(json['material']),
      micron: _calculateText(json['micron']),
    );
  }

  final String materialId;
  final String material;
  final String micron;
}

class CalculateResult {
  const CalculateResult({
    this.filmGsm = 0,
    this.adhesiveGsm = 0,
    this.totalGsm = 0,
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
      filmGsm: _calculateNumber(json['film_gsm']),
      adhesiveGsm: _calculateNumber(json['adhesive_gsm']),
      totalGsm: _calculateNumber(json['total_gsm']),
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
  final double filmGsm;
  final double adhesiveGsm;
  final double totalGsm;
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
    required this.code,
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
    this.frameProductSizeMm = 0,
    this.frameCount = 0,
    this.edgeAllowanceMm = kCalculateEdgeAllowanceMm,
    required this.widthMm,
    required this.wastePercent,
    required this.rollCount,
    this.layers = const <CalculateLayerInput>[],
    required this.firstLayerMaterial,
    required this.firstLayerMicron,
    required this.secondLayerMaterial,
    required this.secondLayerMicron,
    required this.thirdLayerMaterial,
    required this.thirdLayerMicron,
    required this.note,
    this.kg = 0,
    this.sourceMapId = '',
  });

  factory CalculateOrderTemplate.fromJson(Map<String, dynamic> json) {
    final layers = (json['layers'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) => CalculateLayerInput(
            materialId: _calculateText(item['material_id']),
            material: _calculateText(item['material']),
            micron: _calculateText(item['micron']),
          ),
        )
        .where((layer) => !layer.isEmpty)
        .toList(growable: false);
    final widthMm = _calculateNumber(json['width_mm']);
    final frameProductSizeMm = _calculateNumber(
      json['frame_product_size_mm'],
      fallback: widthMm > kCalculateEdgeAllowanceMm
          ? widthMm - kCalculateEdgeAllowanceMm
          : 0,
    );
    final frameCount = _calculateNumber(
      json['frame_count'],
      fallback: widthMm > 0 ? 1 : 0,
    );
    return CalculateOrderTemplate(
      id: _calculateText(json['id']),
      code: _calculateText(json['code']),
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
      frameProductSizeMm: frameProductSizeMm,
      frameCount: frameCount,
      edgeAllowanceMm: _calculateNumber(
        json['edge_allowance_mm'],
        fallback: kCalculateEdgeAllowanceMm,
      ),
      widthMm: widthMm,
      wastePercent: _calculateNumber(json['waste_percent'], fallback: 5),
      rollCount: _calculateOptionalNumber(json['roll_count']),
      layers: layers,
      firstLayerMaterial: _calculateText(json['first_layer_material']),
      firstLayerMicron: _calculateText(json['first_layer_micron']),
      secondLayerMaterial: _calculateText(json['second_layer_material']),
      secondLayerMicron: _calculateText(json['second_layer_micron']),
      thirdLayerMaterial: _calculateText(json['third_layer_material']),
      thirdLayerMicron: _calculateText(json['third_layer_micron']),
      note: _calculateText(json['note']),
      kg: _calculateNumber(json['kg']),
      sourceMapId: _calculateText(json['source_map_id']),
    );
  }

  final String id;
  final String code;
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
  final double frameProductSizeMm;
  final double frameCount;
  final double edgeAllowanceMm;
  final double widthMm;
  final double wastePercent;
  final double? rollCount;
  final List<CalculateLayerInput> layers;
  final String firstLayerMaterial;
  final String firstLayerMicron;
  final String secondLayerMaterial;
  final String secondLayerMicron;
  final String thirdLayerMaterial;
  final String thirdLayerMicron;
  final String note;
  final double kg;
  final String sourceMapId;

  List<CalculateLayerInput> get effectiveLayers {
    if (layers.isNotEmpty) {
      return layers;
    }
    return [
      CalculateLayerInput(
        material: firstLayerMaterial,
        micron: firstLayerMicron,
      ),
      CalculateLayerInput(
        material: secondLayerMaterial,
        micron: secondLayerMicron,
      ),
      CalculateLayerInput(
        material: thirdLayerMaterial,
        micron: thirdLayerMicron,
      ),
    ].where((layer) => !layer.isEmpty).toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    final effective = effectiveLayers;
    CalculateLayerInput legacy(int index) => index < effective.length
        ? effective[index]
        : const CalculateLayerInput();
    return {
      if (id.trim().isNotEmpty) 'id': id.trim(),
      if (code.trim().isNotEmpty) 'code': code.trim(),
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
      'frame_product_size_mm': frameProductSizeMm,
      'frame_count': frameCount,
      'edge_allowance_mm': edgeAllowanceMm,
      'width_mm': widthMm,
      'waste_percent': wastePercent,
      if (rollCount != null) 'roll_count': rollCount,
      'layers':
          effective.map((layer) => layer.toJson()).toList(growable: false),
      'first_layer_material': legacy(0).material.trim(),
      'first_layer_micron': legacy(0).micron.trim(),
      'second_layer_material': legacy(1).material.trim(),
      'second_layer_micron': legacy(1).micron.trim(),
      'third_layer_material': legacy(2).material.trim(),
      'third_layer_micron': legacy(2).micron.trim(),
      'note': note.trim(),
      if (kg > 0) 'kg': kg,
      if (sourceMapId.trim().isNotEmpty) 'source_map_id': sourceMapId.trim(),
    };
  }

  CalculateOrderTemplate copyWith({
    String? id,
    String? code,
    String? name,
    DateTime? savedAt,
    String? orderNumber,
    String? customerRef,
    String? customer,
    String? itemCode,
    String? product,
    String? status,
    String? materialDisplay,
    String? color,
    String? imageId,
    String? imageName,
    String? imageMime,
    int? imageSizeBytes,
    String? imageUrl,
    double? frameProductSizeMm,
    double? frameCount,
    double? edgeAllowanceMm,
    double? widthMm,
    double? wastePercent,
    double? rollCount,
    List<CalculateLayerInput>? layers,
    String? firstLayerMaterial,
    String? firstLayerMicron,
    String? secondLayerMaterial,
    String? secondLayerMicron,
    String? thirdLayerMaterial,
    String? thirdLayerMicron,
    String? note,
    double? kg,
    String? sourceMapId,
  }) {
    return CalculateOrderTemplate(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      savedAt: savedAt ?? this.savedAt,
      orderNumber: orderNumber ?? this.orderNumber,
      customerRef: customerRef ?? this.customerRef,
      customer: customer ?? this.customer,
      itemCode: itemCode ?? this.itemCode,
      product: product ?? this.product,
      status: status ?? this.status,
      materialDisplay: materialDisplay ?? this.materialDisplay,
      color: color ?? this.color,
      imageId: imageId ?? this.imageId,
      imageName: imageName ?? this.imageName,
      imageMime: imageMime ?? this.imageMime,
      imageSizeBytes: imageSizeBytes ?? this.imageSizeBytes,
      imageUrl: imageUrl ?? this.imageUrl,
      frameProductSizeMm: frameProductSizeMm ?? this.frameProductSizeMm,
      frameCount: frameCount ?? this.frameCount,
      edgeAllowanceMm: edgeAllowanceMm ?? this.edgeAllowanceMm,
      widthMm: widthMm ?? this.widthMm,
      wastePercent: wastePercent ?? this.wastePercent,
      rollCount: rollCount ?? this.rollCount,
      layers: layers ?? this.layers,
      firstLayerMaterial: firstLayerMaterial ?? this.firstLayerMaterial,
      firstLayerMicron: firstLayerMicron ?? this.firstLayerMicron,
      secondLayerMaterial: secondLayerMaterial ?? this.secondLayerMaterial,
      secondLayerMicron: secondLayerMicron ?? this.secondLayerMicron,
      thirdLayerMaterial: thirdLayerMaterial ?? this.thirdLayerMaterial,
      thirdLayerMicron: thirdLayerMicron ?? this.thirdLayerMicron,
      note: note ?? this.note,
      kg: kg ?? this.kg,
      sourceMapId: sourceMapId ?? this.sourceMapId,
    );
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

CalculateOrderTemplate _testModeUpsertCalculateOrderTemplate(
  CalculateOrderTemplate template,
) {
  if (_testModeForceCalculateTemplateSaveFailure) {
    throw const MobileApiException(
      code: 'calculate_order_save',
      message: 'Calculate order save failed (test)',
    );
  }
  final id = template.id.trim().isNotEmpty
      ? template.id.trim()
      : 'test-co-${DateTime.now().millisecondsSinceEpoch}';
  final code = template.code.trim().isNotEmpty ? template.code.trim() : 'Z-$id';
  final saved = CalculateOrderTemplate(
    id: id,
    code: code,
    name: template.name,
    savedAt: DateTime.now().toUtc(),
    orderNumber: template.orderNumber,
    customerRef: template.customerRef,
    customer: template.customer,
    itemCode: template.itemCode,
    product: template.product,
    status: template.status,
    materialDisplay: template.materialDisplay,
    color: template.color,
    imageId: template.imageId,
    imageName: template.imageName,
    imageMime: template.imageMime,
    imageSizeBytes: template.imageSizeBytes,
    imageUrl: template.imageUrl,
    frameProductSizeMm: template.frameProductSizeMm,
    frameCount: template.frameCount,
    edgeAllowanceMm: template.edgeAllowanceMm,
    widthMm: template.widthMm,
    wastePercent: template.wastePercent,
    rollCount: template.rollCount,
    layers: template.effectiveLayers,
    firstLayerMaterial: template.firstLayerMaterial,
    firstLayerMicron: template.firstLayerMicron,
    secondLayerMaterial: template.secondLayerMaterial,
    secondLayerMicron: template.secondLayerMicron,
    thirdLayerMaterial: template.thirdLayerMaterial,
    thirdLayerMicron: template.thirdLayerMicron,
    note: template.note,
    kg: template.kg,
    sourceMapId: template.sourceMapId,
  );
  final lowerCode = code.toLowerCase();
  _testModeCalculateOrderTemplates.removeWhere(
    (item) => item.id == saved.id || item.code.toLowerCase() == lowerCode,
  );
  _testModeCalculateOrderTemplates.insert(0, saved);
  return saved;
}

List<CalculateMaterial> _defaultCalculateMaterials() {
  const commonMicrons = <int>[20, 25, 30, 35, 40, 45, 50, 60];
  return [
    CalculateMaterial(
      id: 'builtin-pet',
      name: 'PET',
      active: true,
      densityGCm3: 1.40,
      variants: _densityCalculateVariants(
        const [12, ...commonMicrons],
        1.40,
      ),
    ),
    CalculateMaterial(
      id: 'builtin-opp',
      name: 'OPP',
      active: true,
      densityGCm3: 0.91,
      variants: _densityCalculateVariants(
        const [18, ...commonMicrons],
        0.91,
      ),
    ),
    CalculateMaterial(
      id: 'builtin-bopp-metal',
      name: 'BOPP metal',
      active: true,
      densityGCm3: 0.91,
      variants: _densityCalculateVariants(
        const [18, ...commonMicrons],
        0.91,
      ),
    ),
    CalculateMaterial(
      id: 'builtin-mcp',
      name: 'MCP',
      active: true,
      densityGCm3: 0.90,
      variants: _densityCalculateVariants(commonMicrons, 0.90),
    ),
    CalculateMaterial(
      id: 'builtin-cpp',
      name: 'CPP',
      active: true,
      densityGCm3: 0.90,
      variants: _densityCalculateVariants(commonMicrons, 0.90),
    ),
    CalculateMaterial(
      id: 'builtin-pe',
      name: 'PE',
      active: true,
      densityGCm3: 0.92,
      variants: _densityCalculateVariants(
        const [30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90],
        0.92,
      ),
    ),
    const CalculateMaterial(
      id: 'builtin-jem',
      name: 'JEM',
      active: true,
      variants: [
        CalculateMaterialVariant(
          micron: 25,
          coefficient: 1,
          actualGsm: 16.666666666666668,
        ),
        CalculateMaterialVariant(
          micron: 30,
          coefficient: 1.5,
          actualGsm: 25,
        ),
      ],
    ),
  ];
}

List<CalculateMaterialVariant> _densityCalculateVariants(
  List<int> microns,
  double densityGCm3,
) {
  return microns
      .map(
        (micron) => CalculateMaterialVariant(
          micron: micron,
          coefficient: micron * densityGCm3 * 0.06,
        ),
      )
      .toList(growable: false);
}

Future<Map<String, dynamic>> _calculateDecodeObject(String body) async {
  try {
    return await decodeJsonMapPayload(body);
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

double _deriveCalculateWidthMm(
  double frameProductSizeMm,
  double frameCount, [
  double edgeAllowanceMm = kCalculateEdgeAllowanceMm,
]) {
  return frameProductSizeMm * frameCount + edgeAllowanceMm;
}

double _deriveCalculateMinMoldSizeMm(
  double frameProductSizeMm,
  double frameCount,
) {
  return frameProductSizeMm * frameCount + kCalculateMinMoldExtraMm;
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
