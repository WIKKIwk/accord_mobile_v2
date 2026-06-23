part of 'admin_production_map_orders_screen.dart';

double? _productionMapOrderKg(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) {
  final stored = map.orderKg;
  if (stored != null && stored > 0) {
    return stored;
  }
  final template = _calculateTemplateForProductionMap(map, templates);
  if (template != null && template.kg > 0) {
    return template.kg;
  }
  return null;
}

List<String> _productionMapWorkflowLines(
  ProductionMapDefinition map, {
  double? baseMetraj,
  double? orderKg,
}) {
  final workSteps = <String>[];
  for (final node in _linearProductionMapNodes(map)) {
    if (node.kind == 'start' || node.kind == 'end') {
      continue;
    }
    final title = _productionMapNodeDisplayTitle(node);
    if (title.isEmpty) {
      continue;
    }
    switch (node.kind) {
      case 'apparatus':
        workSteps.add('$title aparatidan');
        break;
      case 'task':
        workSteps.add(title);
        break;
      default:
        break;
    }
  }
  if (workSteps.isEmpty) {
    final result = _productionMapResultSummary(
      map,
      baseMetraj: baseMetraj,
      orderKg: orderKg,
    );
    return result.isEmpty ? const [] : ['Natija: $result'];
  }

  final lines = <String>['Ish tartibi:'];
  for (var index = 0; index < workSteps.length; index++) {
    final step = workSteps[index];
    if (index == 0) {
      lines.add('${index + 1}. Birinchi bosqich — $step boshlanadi');
    } else if (index == workSteps.length - 1) {
      lines.add('${index + 1}. So‘ng — $step');
    } else {
      lines.add('${index + 1}. Keyin — $step');
    }
  }
  final result = _productionMapResultSummary(
    map,
    baseMetraj: baseMetraj,
    orderKg: orderKg,
  );
  if (result.isNotEmpty) {
    lines.add('Natija: $result');
  }
  return lines;
}

CalculateOrderTemplate? _calculateTemplateForProductionMap(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) {
  final mapId = map.id.trim();
  for (final template in templates) {
    if (template.sourceMapId.trim() == mapId) {
      return template;
    }
  }
  final orderNumber = map.orderNumber.trim();
  final code = map.code.trim();
  final idSuffix = mapId.startsWith('zakaz-') ? mapId.substring(6).trim() : '';
  final orderKeys =
      {orderNumber, code, idSuffix}.where((value) => value.isNotEmpty).toSet();
  for (final template in templates) {
    final templateOrder = template.orderNumber.trim();
    final templateCode = template.code.trim();
    if (orderKeys.contains(templateOrder) || orderKeys.contains(templateCode)) {
      return template;
    }
  }
  final productKeys = {
    map.productCode.trim().toLowerCase(),
    map.title.trim().toLowerCase(),
    _openedOrderProductTitle(map).toLowerCase(),
  }..removeWhere((value) => value.isEmpty);
  if (productKeys.isEmpty) {
    return null;
  }
  CalculateOrderTemplate? fallback;
  for (final template in templates) {
    if (template.kg <= 0) {
      continue;
    }
    final templateProduct = template.product.trim().toLowerCase();
    final templateItem = template.itemCode.trim().toLowerCase();
    if (!productKeys.contains(templateProduct) &&
        !productKeys.contains(templateItem)) {
      continue;
    }
    if (map.widthMm != null &&
        map.widthMm! > 0 &&
        template.widthMm > 0 &&
        (map.widthMm! - template.widthMm).abs() > 0.5) {
      continue;
    }
    fallback = template;
    if (template.sourceMapId.trim().isNotEmpty) {
      return template;
    }
  }
  return fallback;
}

CalculateRequest _calculateRequestForOrder({
  required ProductionMapDefinition map,
  required CalculateOrderTemplate template,
}) {
  final widthMm = template.widthMm > 0 ? template.widthMm : (map.widthMm ?? 0);
  final frameProductSizeMm = template.frameProductSizeMm > 0
      ? template.frameProductSizeMm
      : (widthMm > kCalculateEdgeAllowanceMm
          ? widthMm - kCalculateEdgeAllowanceMm
          : 0.0);
  final frameCount = template.frameCount > 0 ? template.frameCount : 1.0;
  final kg = template.kg > 0 ? template.kg : (map.orderKg ?? 0);
  return CalculateRequest(
    orderNumber: template.orderNumber.isNotEmpty
        ? template.orderNumber
        : map.orderNumber,
    customer: template.customer,
    product: template.product.isNotEmpty ? template.product : map.title,
    status: template.status,
    materialDisplay: template.materialDisplay,
    color: template.color,
    kg: kg,
    frameProductSizeMm: frameProductSizeMm,
    frameCount: frameCount,
    edgeAllowanceMm: template.edgeAllowanceMm,
    wastePercent: template.wastePercent,
    rollCount: template.rollCount ?? map.rollCount,
    firstLayer: CalculateLayerInput(
      material: template.firstLayerMaterial,
      micron: template.firstLayerMicron,
    ),
    secondLayer: CalculateLayerInput(
      material: template.secondLayerMaterial,
      micron: template.secondLayerMicron,
    ),
    thirdLayer: CalculateLayerInput(
      material: template.thirdLayerMaterial,
      micron: template.thirdLayerMicron,
    ),
    note: template.note,
  );
}

Future<double?> _productionMapBaseMetrajForOrder(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) async {
  final stored = map.baseLength;
  if (stored != null && stored > 0) {
    return stored;
  }
  final template = _calculateTemplateForProductionMap(map, templates);
  if (template == null && (map.orderKg ?? 0) <= 0) {
    return null;
  }
  if (template == null) {
    return _productionMapBaseMetrajFromMapOnly(map);
  }
  return _productionMapBaseMetrajForTemplate(map, template);
}

Future<double?> _productionMapBaseMetrajFromMapOnly(
  ProductionMapDefinition map,
) async {
  final kg = map.orderKg ?? 0;
  final widthMm = map.widthMm ?? 0;
  if (kg <= 0 || widthMm <= 0) {
    return null;
  }
  try {
    final response = await MobileApi.instance.calculate(
      CalculateRequest(
        product: map.title,
        kg: kg,
        frameProductSizeMm: widthMm > kCalculateEdgeAllowanceMm
            ? widthMm - kCalculateEdgeAllowanceMm
            : 0,
        frameCount: 1,
        edgeAllowanceMm: kCalculateEdgeAllowanceMm,
        rollCount: map.rollCount,
        firstLayer: const CalculateLayerInput(),
        secondLayer: const CalculateLayerInput(),
      ),
    );
    if (response.results.isEmpty) {
      return null;
    }
    final base = response.results.first.baseLength;
    return base > 0 ? base : null;
  } catch (_) {
    return null;
  }
}

Future<double?> _productionMapBaseMetrajForTemplate(
  ProductionMapDefinition map,
  CalculateOrderTemplate template,
) async {
  final widthMm = template.widthMm > 0 ? template.widthMm : (map.widthMm ?? 0);
  final kg = template.kg > 0 ? template.kg : (map.orderKg ?? 0);
  if (kg <= 0 || widthMm <= 0) {
    return null;
  }
  try {
    final response = await MobileApi.instance.calculate(
      _calculateRequestForOrder(map: map, template: template),
    );
    if (response.results.isEmpty) {
      return null;
    }
    final base = response.results.first.baseLength;
    return base > 0 ? base : null;
  } catch (_) {
    return null;
  }
}

Future<Map<String, double>> _productionMapBaseMetrajByMapId(
  List<ProductionMapSaved> orders,
  List<CalculateOrderTemplate> templates,
) async {
  final metraj = <String, double>{};
  for (final order in orders) {
    final mapId = order.map.id.trim();
    if (mapId.isEmpty || metraj.containsKey(mapId)) {
      continue;
    }
    final base = await _productionMapBaseMetrajForOrder(order.map, templates);
    if (base != null) {
      metraj[mapId] = base;
    }
  }
  return metraj;
}
