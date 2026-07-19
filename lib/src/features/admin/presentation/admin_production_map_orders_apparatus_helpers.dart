part of 'admin_production_map_orders_screen.dart';

bool _isAlternativeOrderForApparatus(
  ProductionMapSaved order,
  AdminApparatus apparatus,
) {
  if (_isFlexoOrderBlockedForColorPechat(order.map, apparatus)) {
    return false;
  }
  return order.map.nodes.any((node) {
    return node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isNotEmpty &&
        productionMapWarehouseTitlesMatch(node.title, apparatus.name);
  });
}

bool _hasUnassignedAlternativeGroupForApparatus(
  ProductionMapDefinition map,
  AdminApparatus apparatus,
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
    if (productionMapWarehouseTitlesMatch(node.title, apparatus.name)) {
      matchingGroups.add(groupId);
    }
    if (node.alternativeAssignedTitle.trim().isNotEmpty) {
      assignedGroups.add(groupId);
    }
  }
  return matchingGroups.any((groupId) => !assignedGroups.contains(groupId));
}

bool _isUnassignedAlternativeCandidateForApparatus({
  required ProductionMapSaved order,
  required AdminApparatus apparatus,
}) {
  if (_isMoveUnassignedApparatus(apparatus)) {
    return false;
  }
  return _hasUnassignedAlternativeGroupForApparatus(order.map, apparatus);
}

bool _isFlexoOrderBlockedForColorPechat(
  ProductionMapDefinition map,
  AdminApparatus apparatus,
) {
  return productionMapIsFlexoOrder(map) &&
      productionMapPechatColorCount(apparatus.name) != null;
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
  required AdminApparatus apparatus,
  required Map<String, List<String>> visibleOrderIdsByApparatus,
}) {
  final title = apparatus.name.trim();
  return productionMapOrdersVisibleByBackendIds(
    orders: orders,
    visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
    station: title,
  );
}

List<ProductionMapSaved> _productionMapOrdersForApparatus({
  required List<ProductionMapSaved> orders,
  required AdminApparatus apparatus,
  required Map<String, List<String>> visibleOrderIdsByApparatus,
  required Map<String, List<String>> sequenceByApparatus,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required bool workerMode,
  required String query,
}) {
  final filtered = _productionMapBaseOrdersForApparatus(
    orders: orders,
    apparatus: apparatus,
    visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
  );
  final sequence = _sequenceOrderIdsForApparatus(
    apparatus,
    sequenceByApparatus: sequenceByApparatus,
  );
  final visibleOrderIds = filtered.map((order) => order.map.id).toList();
  final ordered = _applyApparatusOrderSequence(
    orders: filtered,
    sequence: effectiveQueueSequence(
      sequence: sequence,
      visibleOrderIds: visibleOrderIds,
    ),
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
