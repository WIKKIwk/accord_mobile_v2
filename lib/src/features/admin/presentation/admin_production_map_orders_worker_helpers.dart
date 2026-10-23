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
      orderStatusesByOrderId[id]?.orderStatus.trim().toLowerCase() == 'frozen';
}

String _workerFrozenOrderMessage(AppLocalizations l10n, String orderTitle) {
  final title = orderTitle.trim();
  return title.isEmpty
      ? l10n.productionText('worker.freeze.active')
      : l10n.productionText('worker.freeze.named', values: {'order': title});
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
  final seen = <(String, String)>{};
  final entries = <_WorkerCompletedOrderEntry>[];
  final assigned = assignedApparatus.map((id) => id.trim()).toSet();
  for (final completed in completedOrders) {
    // One history entry per order and producing apparatus. A later stage on
    // another assigned apparatus must not hide this worker's earlier output.
    if (!assigned.contains(completed.apparatus.trim())) continue;
    final orderId = completed.orderId.trim();
    if (completed.status.trim().toLowerCase() == 'frozen' ||
        _workerOrderIsFrozen(
          orderId: orderId,
          orderControlsByOrderId: orderControlsByOrderId,
          queueStatesByApparatus: queueStatesByApparatus,
          queueActionControlsByApparatus: queueActionControlsByApparatus,
          orderStatusesByOrderId: orderStatusesByOrderId,
        )) {
      continue;
    }
    if (orderId.isEmpty || !seen.add((orderId, completed.apparatus.trim()))) {
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
          apparatusId: completed.apparatus.trim(),
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
