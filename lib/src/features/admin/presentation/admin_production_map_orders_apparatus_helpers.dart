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
  required Map<String, AdminOrderControlState> orderControlsByOrderId,
  required bool workerMode,
  required String query,
}) {
  final visibleOrders = _productionMapBaseOrdersForApparatus(
    orders: orders,
    apparatus: apparatus,
    visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
  );
  final states = _queueStatesForApparatus(
    apparatus,
    queueStatesByApparatus: queueStatesByApparatus,
  );
  final activeOrders = visibleOrders.where(
    (order) {
      final orderId = order.map.id.trim();
      final state = apparatusQueueOrderStateFromRaw(states[orderId]);
      final orderControl = adminProductionMapOrderControlFor(
        orderControlsByOrderId,
        orderId,
      );
      return state != ApparatusQueueOrderState.completed &&
          state != ApparatusQueueOrderState.frozen &&
          orderControl != AdminOrderControlState.frozen;
    },
  ).toList(growable: false);
  final sequence = _sequenceOrderIdsForApparatus(
    apparatus,
    sequenceByApparatus: sequenceByApparatus,
  );
  final activeOrderIds = activeOrders.map((order) => order.map.id).toList();
  final ordered = _applyApparatusOrderSequence(
    orders: activeOrders,
    sequence: effectiveQueueSequence(
      sequence: sequence,
      visibleOrderIds: activeOrderIds,
    ),
  );
  if (!workerMode) {
    return ordered;
  }
  return _filterOrdersBySearch(ordered, query: query);
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

List<AdminFrozenQueueOrder> _productionMapFrozenOrdersForApparatus({
  required AdminApparatus apparatus,
  required Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus,
  required String query,
}) {
  final title = apparatus.name.trim();
  final matching = <AdminFrozenQueueOrder>[];
  final seen = <String>{};
  for (final entry in frozenOrdersByApparatus.entries) {
    if (!_apparatusTitlesMatch(entry.key, title)) {
      continue;
    }
    for (final frozen in entry.value) {
      if (seen.add(frozen.orderId.trim())) {
        matching.add(frozen);
      }
    }
  }
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return matching;
  }
  return matching
      .where(
        (frozen) =>
            frozen.orderId.toLowerCase().contains(normalizedQuery) ||
            frozen.issueNote.toLowerCase().contains(normalizedQuery) ||
            frozen.apparatus.toLowerCase().contains(normalizedQuery),
      )
      .toList(growable: false);
}
