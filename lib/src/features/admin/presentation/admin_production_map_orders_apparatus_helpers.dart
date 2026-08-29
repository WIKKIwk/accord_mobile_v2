part of 'admin_production_map_orders_screen.dart';

AdminApparatus? _canonicalApparatusForId(
  Iterable<AdminApparatus> apparatus,
  String apparatusId,
) {
  final normalized = apparatusId.trim();
  if (!canonicalApparatusIdIsValid(normalized)) return null;
  for (final item in apparatus) {
    if (item.id.trim() == normalized) return item;
  }
  return null;
}

String _canonicalNodeOperation(
  ProductionMapNode node,
  Iterable<AdminApparatus> apparatus,
) {
  if (node.kind != 'apparatus') return '';
  final assigned = node.alternativeAssignedApparatusId.trim();
  final apparatusId = assigned.isEmpty ? node.apparatusId.trim() : assigned;
  return _canonicalApparatusForId(apparatus, apparatusId)
          ?.operation
          .trim()
          .toLowerCase() ??
      '';
}

bool _isAlternativeOrderForApparatus(
  ProductionMapSaved order,
  AdminApparatus apparatus,
) {
  return order.map.nodes.any((node) {
    return node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isNotEmpty &&
        node.apparatusId == apparatus.id;
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
    if (node.apparatusId == apparatus.id) {
      matchingGroups.add(groupId);
    }
    if (node.alternativeAssignedApparatusId.trim().isNotEmpty) {
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

String? _assignedAlternativeGroupIdForApparatus(
  ProductionMapDefinition map,
  AdminApparatus apparatus,
) {
  for (final node in map.nodes) {
    if (node.kind == 'apparatus' &&
        node.alternativeGroupId.trim().isNotEmpty &&
        node.alternativeAssignedApparatusId == apparatus.id) {
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
  final visibleOrderIds =
      visibleOrderIdsByApparatus[apparatus.id.trim()] ?? const <String>[];
  final byId = {for (final order in orders) order.map.id.trim(): order};
  return [
    for (final orderId in visibleOrderIds)
      if (byId.containsKey(orderId.trim())) byId[orderId.trim()]!,
  ];
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
  final visibleOrders = _productionMapBaseOrdersForApparatus(
    orders: orders,
    apparatus: apparatus,
    visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
  );
  final states = _queueStatesForApparatus(
    apparatus,
    queueStatesByApparatus: queueStatesByApparatus,
  );
  final queueOrders = visibleOrders.where(
    (order) {
      final orderId = order.map.id.trim();
      final state = apparatusQueueOrderStateFromRaw(states[orderId]);
      return state != ApparatusQueueOrderState.completed;
    },
  ).toList(growable: false);
  final sequence = _sequenceOrderIdsForApparatus(
    apparatus,
    sequenceByApparatus: sequenceByApparatus,
  );
  final queueOrderIds = queueOrders.map((order) => order.map.id).toList();
  final ordered = _applyApparatusOrderSequence(
    orders: queueOrders,
    sequence: effectiveQueueSequence(
      sequence: sequence,
      visibleOrderIds: queueOrderIds,
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
