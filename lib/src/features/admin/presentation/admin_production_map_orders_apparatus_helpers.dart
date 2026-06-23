part of 'admin_production_map_orders_screen.dart';

bool _isAlternativeOrderForApparatus(
  ProductionMapSaved order,
  AdminWarehouse apparatus,
) {
  if (_isFlexoOrderBlockedForColorPechat(order.map, apparatus)) {
    return false;
  }
  return order.map.nodes.any((node) {
    return node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isNotEmpty &&
        productionMapWarehouseTitlesMatch(node.title, apparatus.warehouse);
  });
}

bool _hasAlternativeApparatus(ProductionMapDefinition map) {
  return map.nodes.any(
    (node) =>
        node.kind == 'apparatus' && node.alternativeGroupId.trim().isNotEmpty,
  );
}

bool _hasUnassignedAlternativeGroupForApparatus(
  ProductionMapDefinition map,
  AdminWarehouse apparatus,
) {
  final matchingGroups = <String>{};
  final assignedGroups = <String>{};
  for (final node in map.nodes) {
    if (node.kind != 'apparatus') {
      continue;
    }
    final groupId = node.alternativeGroupId.trim();
    if (groupId.isEmpty) {
      continue;
    }
    if (productionMapWarehouseTitlesMatch(node.title, apparatus.warehouse)) {
      matchingGroups.add(groupId);
    }
    if (node.alternativeAssignedTitle.trim().isNotEmpty) {
      assignedGroups.add(groupId);
    }
  }
  return matchingGroups.any((groupId) => !assignedGroups.contains(groupId));
}

bool _alternativeOrderAssignedToApparatus(
  ProductionMapDefinition map,
  AdminWarehouse apparatus,
) {
  final title = apparatus.warehouse.trim();
  return map.nodes.any(
    (node) =>
        node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isNotEmpty &&
        productionMapWarehouseTitlesMatch(
          node.alternativeAssignedTitle,
          title,
        ),
  );
}

bool _isFlexoOrderBlockedForColorPechat(
  ProductionMapDefinition map,
  AdminWarehouse apparatus,
) {
  return productionMapIsFlexoOrder(map) &&
      productionMapPechatColorCount(apparatus.warehouse) != null;
}

String? _assignedAlternativeGroupIdForApparatus(
  ProductionMapDefinition map,
  String apparatusTitle,
) {
  for (final node in map.nodes) {
    if (node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isNotEmpty &&
        productionMapWarehouseTitlesMatch(
          node.alternativeAssignedTitle,
          apparatusTitle,
        )) {
      return node.alternativeGroupId.trim();
    }
  }
  return null;
}

List<ProductionMapSaved> _productionMapBaseOrdersForApparatus({
  required List<ProductionMapSaved> orders,
  required AdminWarehouse apparatus,
}) {
  final title = apparatus.warehouse.trim();
  return orders.where((order) {
    if (_isFlexoOrderBlockedForColorPechat(order.map, apparatus)) {
      return false;
    }
    final hasAlternative = _hasAlternativeApparatus(order.map);
    if (hasAlternative) {
      return _alternativeOrderAssignedToApparatus(order.map, apparatus);
    }
    return productionMapMapHasWorkStageForStation(
      map: order.map,
      station: title,
    );
  }).toList();
}

List<ProductionMapSaved> _productionMapOrdersForApparatus({
  required List<ProductionMapSaved> orders,
  required AdminWarehouse apparatus,
  required Map<String, List<String>> sequenceByApparatus,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required bool workerMode,
  required String query,
}) {
  final filtered = _productionMapBaseOrdersForApparatus(
    orders: orders,
    apparatus: apparatus,
  );
  final sequence = _sequenceOrderIdsForApparatus(
    apparatus,
    sequenceByApparatus: sequenceByApparatus,
  );
  final ordered = _applyApparatusOrderSequence(
    orders: filtered,
    sequence: sequence,
  );
  if (!workerMode) {
    return ordered;
  }
  final states = _queueStatesForApparatus(
    apparatus,
    queueStatesByApparatus: queueStatesByApparatus,
  );
  final activeOrders = ordered
      .where(
        (order) =>
            apparatusQueueOrderStateFromRaw(states[order.map.id.trim()]) !=
            ApparatusQueueOrderState.completed,
      )
      .toList(growable: false);
  return _filterOrdersBySearch(activeOrders, query: query);
}

List<ProductionMapSaved> _applyApparatusOrderSequence({
  required List<ProductionMapSaved> orders,
  required List<String> sequence,
}) {
  if (sequence.isEmpty) {
    return orders;
  }
  final byId = {for (final order in orders) order.map.id: order};
  return [
    for (final id in sequence)
      if (byId.containsKey(id)) byId.remove(id)!,
    ...byId.values,
  ];
}
