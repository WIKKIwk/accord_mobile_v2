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
    layers: template.effectiveLayers,
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

Map<String, double> _productionMapOrderKgByMapId(
  List<ProductionMapSaved> orders,
  List<CalculateOrderTemplate> templates,
) {
  final kgByMap = <String, double>{};
  for (final order in orders) {
    final mapId = order.map.id.trim();
    if (mapId.isEmpty) {
      continue;
    }
    final kg = _productionMapOrderKg(order.map, templates);
    if (kg != null && kg > 0) {
      kgByMap[mapId] = kg;
    }
  }
  return kgByMap;
}

Map<String, String> _productionMapCustomerByMapId(
  List<ProductionMapSaved> orders,
  List<CalculateOrderTemplate> templates,
) {
  final customerByMap = <String, String>{};
  for (final order in orders) {
    final mapId = order.map.id.trim();
    if (mapId.isEmpty) {
      continue;
    }
    final customer = _calculateCustomerForProductionMap(order.map, templates);
    if (customer != null && customer.isNotEmpty) {
      customerByMap[mapId] = customer;
    }
  }
  return customerByMap;
}

String? _calculateCustomerForProductionMap(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) {
  final directCustomer = _calculateTemplateForProductionMap(
    map,
    templates,
  )?.customer.trim();
  if (directCustomer != null && directCustomer.isNotEmpty) {
    return directCustomer;
  }

  final mapId = map.id.trim();
  final orderNumber = map.orderNumber.trim();
  final code = map.code.trim();
  final idSuffix = mapId.startsWith('zakaz-') ? mapId.substring(6).trim() : '';
  final orderKeys =
      {orderNumber, code, idSuffix}.where((value) => value.isNotEmpty).toSet();
  for (final template in templates) {
    final customer = template.customer.trim();
    if (customer.isEmpty) {
      continue;
    }
    if (orderKeys.contains(template.orderNumber.trim()) ||
        orderKeys.contains(template.code.trim())) {
      return customer;
    }
  }

  final productKeys = {
    map.productCode.trim().toLowerCase(),
    map.title.trim().toLowerCase(),
    _openedOrderProductTitle(map).toLowerCase(),
    for (final node in map.nodes)
      if (node.itemCode.trim().isNotEmpty) node.itemCode.trim().toLowerCase(),
  }..removeWhere((value) => value.isEmpty);
  for (final template in templates) {
    final customer = template.customer.trim();
    if (customer.isEmpty) {
      continue;
    }
    final templateProduct = template.product.trim().toLowerCase();
    final templateItem = template.itemCode.trim().toLowerCase();
    if (productKeys.contains(templateProduct) ||
        productKeys.contains(templateItem)) {
      return customer;
    }
  }
  return null;
}

Future<_ProductionMapOrderMetrics> _productionMapOrderMetrics(
  List<ProductionMapSaved> orders,
  List<CalculateOrderTemplate> templates,
) async {
  return _ProductionMapOrderMetrics(
    baseMetrajByMapId: await _productionMapBaseMetrajByMapId(orders, templates),
    orderKgByMapId: _productionMapOrderKgByMapId(orders, templates),
    customerByMapId: _productionMapCustomerByMapId(orders, templates),
  );
}
