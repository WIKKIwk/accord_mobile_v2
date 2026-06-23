part of 'admin_production_map_orders_screen.dart';

String _openedOrderDisplayCode(ProductionMapDefinition map) {
  final code = map.code.trim();
  if (code.isNotEmpty) {
    return code;
  }
  final orderNumber = map.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = map.id.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return '';
}

String _openedOrderPrimaryTitle(ProductionMapDefinition map) {
  final title = map.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  final product = _openedOrderProductTitle(map);
  if (product.isNotEmpty) {
    return product;
  }
  return 'Zakaz';
}

String _openedOrderProductTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return '';
}

String _openedOrderSubtitle(
  ProductionMapDefinition map, {
  bool includeApparatusCount = false,
}) {
  final productTitle = _openedOrderProductTitle(map);
  final apparatusCount =
      map.nodes.where((node) => node.kind == 'apparatus').length;
  return [
    if (productTitle.isNotEmpty) productTitle,
    if (map.productCode.trim().isNotEmpty) map.productCode.trim(),
    if (includeApparatusCount && apparatusCount > 0)
      '$apparatusCount ta aparat',
  ].join(' • ');
}

String _closedOrderDisplayCode(AdminClosedProductionOrder order) {
  final orderNumber = order.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = order.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _completionRequestDisplayCode(
  AdminCompletionRequestNotification request,
) {
  final orderNumber = request.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = request.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _closedOrderTitle(AdminClosedProductionOrder order) {
  final title = order.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  return 'Zakaz';
}

String _closedActorLabel({
  required String displayName,
  required String role,
  required String ref,
}) {
  final display = displayName.trim();
  if (display.isNotEmpty) {
    return display;
  }
  final actorRef = ref.trim();
  if (actorRef.isNotEmpty) {
    return actorRef;
  }
  final actorRole = role.trim();
  if (actorRole.isNotEmpty) {
    return actorRole;
  }
  return 'Noma’lum ijrochi';
}

String _closedLogActionLabel(String action) {
  return switch (action.trim()) {
    'start' => 'Boshladi',
    'pause' => 'Pauza qildi',
    'resume' => 'Davom ettirdi',
    'complete' => 'Tugatdi',
    final value when value.isNotEmpty => value,
    _ => 'Harakat',
  };
}

String _closedLogTitle(AdminProductionOrderLogEntry log) {
  if (log.completedWithIssue) {
    final note = log.issueNote.trim();
    return note.isNotEmpty ? note : 'Muammo bilan yopildi';
  }
  return _closedLogActionLabel(log.action);
}

String _closedLogStateLabel(AdminProductionOrderLogEntry log) {
  final from = log.fromState.trim();
  final to = log.toState.trim();
  if (from.isNotEmpty && to.isNotEmpty) {
    return '$from → $to';
  }
  if (to.isNotEmpty) {
    return to;
  }
  return from;
}

String _closedLogTimeLabel(int unixSeconds) {
  return formatUnixSecondsLocalDateTime(unixSeconds);
}

List<ProductionMapNode> _linearProductionMapNodes(ProductionMapDefinition map) {
  final byId = {for (final node in map.nodes) node.id: node};
  final byFrom = <String, List<ProductionMapEdge>>{};
  for (final edge in map.edges) {
    byFrom.putIfAbsent(edge.from, () => <ProductionMapEdge>[]).add(edge);
  }
  final start = map.nodes
      .where((node) => node.kind == 'start')
      .map((node) => node.id)
      .cast<String?>()
      .firstWhere((id) => id != null, orElse: () => null);
  if (start == null || !byId.containsKey(start)) {
    return map.nodes;
  }
  final result = <ProductionMapNode>[];
  final seen = <String>{};
  var current = start;
  while (seen.add(current)) {
    final node = byId[current];
    if (node != null) {
      result.add(node);
    }
    final next = byFrom[current]
        ?.map((edge) => edge.to)
        .where((id) => byId.containsKey(id))
        .cast<String?>()
        .firstWhere((id) => id != null, orElse: () => null);
    if (next == null) {
      break;
    }
    current = next;
  }
  return result.isEmpty ? map.nodes : result;
}

String _productionMapNodeDisplayTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  if (assigned.isNotEmpty) {
    return assigned;
  }
  return node.title.trim();
}

String _productionMapResultSummary(
  ProductionMapDefinition map, {
  double? baseMetraj,
  double? orderKg,
}) {
  final product = _openedOrderProductTitle(map);
  final title = product.isNotEmpty ? product : map.title.trim();
  if (title.isEmpty) {
    return '';
  }
  final details = <String>[];
  if (orderKg != null && orderKg > 0) {
    details.add('${_productionMapQtyLabel(orderKg)} kg');
  }
  if (baseMetraj != null && baseMetraj > 0) {
    details.add('${_productionMapMetrajLabel(baseMetraj)} m metraj');
  }
  final rollCount = map.rollCount;
  if (rollCount != null && rollCount > 0) {
    details.add('${_productionMapQtyLabel(rollCount)} rulon');
  }
  final widthMm = map.widthMm;
  if (widthMm != null && widthMm > 0) {
    details.add('${_productionMapQtyLabel(widthMm)} mm en');
  }
  if (map.productCode.trim().isNotEmpty) {
    details.add(map.productCode.trim());
  }
  if (details.isEmpty) {
    return '$title tayyor bo‘ladi';
  }
  return '$title tayyor bo‘ladi (${details.join(', ')})';
}

String _productionMapQtyLabel(double value) => formatRawQuantity(value);

String _productionMapMetrajLabel(double value) {
  return value.toStringAsFixed(1);
}
