part of 'admin_production_map_orders_screen.dart';

bool _workerOrderIsFrozen({
  required String orderId,
  required Map<String, AdminOrderControlState> orderControlsByOrderId,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControlsByApparatus,
  required Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId,
}) {
  final id = orderId.trim();
  return orderControlsByOrderId[id] == AdminOrderControlState.frozen ||
      orderStatusesByOrderId[id]?.orderStatus.trim().toLowerCase() == 'frozen' ||
      queueStatesByApparatus.values.any(
        (states) => apparatusQueueOrderStateFromRaw(states[id]) ==
            ApparatusQueueOrderState.frozen,
      ) ||
      queueActionControlsByApparatus.values.any((controls) =>
          controls[id]?.state.trim().toLowerCase() == 'frozen' ||
          controls[id]?.interaction?.mode == AdminQueueInteractionMode.frozen);
}

String _workerFrozenOrderMessage(AppLocalizations l10n, String orderTitle) {
  final title = orderTitle.trim();
  return title.isEmpty
      ? l10n.productionText('worker.freeze.active')
      : l10n.productionText('worker.freeze.named', values: {'order': title});
}

List<ProductionMapSaved> _workerDisplayOrderSequence({
  required List<ProductionMapSaved> orders,
  required ApparatusQueuePolicy policy,
  required Map<String, String> queueStates,
  required Map<String, AdminApparatusQueueOrderActionControl> controls,
}) {
  if (policy != ApparatusQueuePolicy.freePick) return orders;
  final positions = {
    for (var index = 0; index < orders.length; index++)
      orders[index].map.id.trim(): index,
  };
  int priority(String id) {
    final state = apparatusQueueOrderStateFromRaw(queueStates[id]);
    if (state == ApparatusQueueOrderState.inProgress ||
        state == ApparatusQueueOrderState.printPreflight) {
      return 0;
    }
    if ((controls[id]?.lastWorkedAtUnix ?? 0) > 0 ||
        state == ApparatusQueueOrderState.paused) {
      return 1;
    }
    return 2;
  }

  // A display-only copy: never rewrite the administrator's queue sequence.
  // Server timestamps restore recency after re-entry, including released work.
  return List<ProductionMapSaved>.of(orders)
    ..sort((left, right) {
      final leftId = left.map.id.trim();
      final rightId = right.map.id.trim();
      final byPriority = priority(leftId).compareTo(priority(rightId));
      if (byPriority != 0) return byPriority;
      final byRecency = (controls[rightId]?.lastWorkedAtUnix ?? 0)
          .compareTo(controls[leftId]?.lastWorkedAtUnix ?? 0);
      return byRecency != 0
          ? byRecency
          : positions[leftId]!.compareTo(positions[rightId]!);
    });
}

List<_WorkerCompletedOrderEntry> _workerCompletedOrders({
  required List<ProductionMapSaved> orders,
  required List<AdminCompletedQueueOrder> completedOrders,
  required List<AdminApparatus> apparatus,
  required List<String> assignedApparatus,
  required Map<String, AdminOrderControlState> orderControlsByOrderId,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControlsByApparatus,
  required Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId,
  required String query,
}) {
  final byId = {for (final order in orders) order.map.id.trim(): order};
  final seen = <String>{};
  final entries = <_WorkerCompletedOrderEntry>[];
  final assigned = assignedApparatus.map((id) => id.trim()).toSet();
  for (final completed in completedOrders) {
    // Filter exact execution ownership before deduplicating orders. Another
    // alternative's more recent event must neither appear here nor mask ours.
    if (!assigned.contains(completed.apparatus.trim())) continue;
    final orderId = completed.orderId.trim();
    if (completed.status.trim().toLowerCase() == 'frozen' ||
        _workerOrderIsFrozen(
          orderId: orderId,
          orderControlsByOrderId: orderControlsByOrderId,
          queueStatesByApparatus: queueStatesByApparatus,
          queueActionControlsByApparatus: queueActionControlsByApparatus,
          orderStatusesByOrderId: orderStatusesByOrderId,
        )) continue;
    if (orderId.isEmpty || !seen.add(orderId)) {
      continue;
    }
    final order = byId[orderId];
    if (order != null) {
      entries.add(
        _WorkerCompletedOrderEntry(
          order: order,
          apparatus: _completedOrderApparatus(
            completed: completed,
            apparatus: apparatus,
          ),
          status: completed.status,
          issueNote: completed.issueNote,
        ),
      );
    }
  }
  final filtered = _filterOrdersBySearch(
    entries.map((entry) => entry.order).toList(growable: false),
    query: query,
  );
  final visibleIds = filtered.map((order) => order.map.id.trim()).toSet();
  return entries
      .where((entry) => visibleIds.contains(entry.order.map.id.trim()))
      .toList(growable: false);
}

AdminApparatus? _completedOrderApparatus({
  required AdminCompletedQueueOrder completed,
  required List<AdminApparatus> apparatus,
}) {
  final apparatusId = completed.apparatus.trim();
  if (apparatusId.isEmpty) {
    return null;
  }
  for (final item in apparatus) {
    if (item.id.trim() == apparatusId) {
      return item;
    }
  }
  return null;
}

int _workerWatchTabCount(List<AdminApparatus> apparatus) {
  return apparatus.isEmpty ? 1 : apparatus.length + 1;
}

List<AdminApparatus> _workerWatchApparatusOrder({
  required List<AdminApparatus> apparatus,
  required Iterable<String> assignedApparatus,
}) {
  final ordered = List<AdminApparatus>.from(apparatus);
  final index = _initialWatchApparatusIndex(
    apparatus: ordered,
    assignedApparatus: assignedApparatus,
  );
  if (index > 0) {
    final assigned = ordered.removeAt(index);
    ordered.insert(0, assigned);
  }
  return ordered;
}

List<_WorkerWatchTab> _workerWatchTabs({
  required List<AdminApparatus> apparatus,
  required Iterable<String> assignedApparatus,
}) {
  final ordered = _workerWatchApparatusOrder(
    apparatus: apparatus,
    assignedApparatus: assignedApparatus,
  );
  if (ordered.isEmpty) {
    return const [_WorkerWatchTab.completed()];
  }
  return [
    _WorkerWatchTab.apparatus(ordered.first),
    const _WorkerWatchTab.completed(),
    for (final item in ordered.skip(1)) _WorkerWatchTab.apparatus(item),
  ];
}

int _initialWatchApparatusIndex({
  required List<AdminApparatus> apparatus,
  required Iterable<String> assignedApparatus,
}) {
  final assigned = assignedApparatus
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty);
  for (final item in assigned) {
    final index = apparatus.indexWhere((entry) => entry.id.trim() == item);
    if (index >= 0) {
      return index;
    }
  }
  return 0;
}

bool _isAssignedWatchApparatus(
  AdminApparatus apparatus, {
  required Iterable<String> assignedApparatus,
}) {
  final apparatusId = apparatus.id.trim();
  return apparatusId.isNotEmpty &&
      assignedApparatus.any((item) => apparatusId == item.trim());
}
