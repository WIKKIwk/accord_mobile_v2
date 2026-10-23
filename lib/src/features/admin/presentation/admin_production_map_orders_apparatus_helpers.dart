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
  final apparatusId = node.alternativeGroupId.trim().isNotEmpty || assigned.isEmpty ? node.apparatusId.trim() : assigned;
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
      if (byId.containsKey(orderId.trim()) &&
          productionMapPrintAssignmentAllowsOrder(
            map: byId[orderId.trim()]!.map,
            apparatus: apparatus,
          ))
        byId[orderId.trim()]!,
  ];
}

List<ProductionMapSaved> _productionMapOrdersForApparatus({
  required List<ProductionMapSaved> orders,
  required AdminApparatus apparatus,
  required Map<String, List<String>> visibleOrderIdsByApparatus,
  required Map<String, List<String>> sequenceByApparatus,
  required Map<String, AdminApparatusQueuePolicy> queuePoliciesByApparatus,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, Map<String, String>> stageStatesByOrderId,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>> queueActionControlsByApparatus,
  required Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId,
  required bool workerMode,
  Map<String, AdminOrderControlState> orderControlsByOrderId = const {},
  bool excludeFrozen = false,
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
  final freePick =
      _queuePolicyForApparatus(
        apparatus,
        queuePoliciesByApparatus: queuePoliciesByApparatus,
      ) == ApparatusQueuePolicy.freePick;
  final queueOrders = visibleOrders.where(
    (order) {
      final orderId = order.map.id.trim();
      if (excludeFrozen &&
          _workerOrderIsFrozen(
            orderId: orderId,
            orderControlsByOrderId: orderControlsByOrderId,
            queueStatesByApparatus: queueStatesByApparatus,
            queueActionControlsByApparatus: queueActionControlsByApparatus,
            orderStatusesByOrderId: orderStatusesByOrderId,
          )) {
        return false;
      }
      // A hold or issue on an upstream node does not hide this node's WIP.
      final ownControl = queueActionControlsByApparatus[apparatus.id]?[orderId];
      if (excludeFrozen &&
          (states[orderId] == 'frozen' ||
              ownControl?.state == 'frozen' ||
              ownControl?.interaction?.mode ==
                  AdminQueueInteractionMode.frozen)) {
        return false;
      }
      final lifecycle = orderStatusesByOrderId[orderId]?.lifecycleStatus;
      if (const {'production_completed', 'closed', 'cancelled'}.contains(lifecycle)) {
        return false;
      }
      // Stage states describe shared operations; queue states describe this
      // machine's actual work. Never manufacture a completion for an unused
      // candidate, or hide a later occurrence of the same physical machine.
      final occurrences = productionMapLinearWorkStages(order.map)
          .where((stage) => stage.apparatusId == apparatus.id)
          .toList();
      final stageStates =
          stageStatesByOrderId[orderId] ?? const <String, String>{};
      bool stageCompleted(String nodeId) =>
          _apparatusStageCompleted(nodeId, stageStates, ownControl);
      if (occurrences.isNotEmpty &&
          occurrences.every((stage) => stageCompleted(stage.nodeId))) {
        return false;
      }
      // A machine can occur again later in the route. Its previous queue
      // completion must not hide a stage the snapshot still marks unfinished.
      if (occurrences.any((stage) =>
          stageStates.containsKey(stage.nodeId) &&
          !stageCompleted(stage.nodeId))) {
        return true;
      }
      final state = apparatusQueueOrderStateFromRaw(states[orderId]);
      return state != ApparatusQueueOrderState.completed;
    },
  ).toList(growable: false);
  final sequence = _sequenceOrderIdsForApparatus(
    apparatus,
    sequenceByApparatus: sequenceByApparatus,
  );
  final queueOrderIds = queueOrders.map((order) => order.map.id).toList();
  // Free queues follow the server's shared display order, before either role's
  // visibility/search filters. Strict queues retain manual sequence changes.
  final ordered = freePick
      ? queueOrders
      : _applyApparatusOrderSequence(
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

bool _apparatusStageCompleted(
  String nodeId,
  Map<String, String> stageStates,
  AdminApparatusQueueOrderActionControl? control,
) =>
    stageStates[nodeId] == 'completed' ||
    (control?.stageNodeId == nodeId &&
        control?.stageWork?.localCompleted == true);

ApparatusQueueOrderState _apparatusOrderCardState({
  required ProductionMapDefinition map,
  required String apparatusId,
  required ApparatusQueueOrderState queueState,
  required Map<String, String> stageStates,
  AdminApparatusQueueOrderActionControl? control,
}) {
  // Real machine activity outranks shared operation state and old reports.
  if (queueState != ApparatusQueueOrderState.completed) return queueState;
  final occurrences = productionMapLinearWorkStages(map)
      .where((stage) => stage.apparatusId == apparatusId)
      .toList(growable: false);
  if (occurrences.length < 2) return queueState;
  const unfinishedStates = {
    'pending',
    'print_preflight',
    'in_progress',
    'paused',
    'frozen',
  };
  final hasUnfinishedOccurrence = occurrences.any(
    (stage) =>
        unfinishedStates.contains(stageStates[stage.nodeId]) &&
        !_apparatusStageCompleted(stage.nodeId, stageStates, control),
  );
  // The queue row remains for another occurrence, not the completed report.
  // Missing stage metadata does not establish new work.
  return hasUnfinishedOccurrence
      ? ApparatusQueueOrderState.pending
      : queueState;
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
