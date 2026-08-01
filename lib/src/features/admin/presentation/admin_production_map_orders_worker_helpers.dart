part of 'admin_production_map_orders_screen.dart';

List<_WorkerCompletedOrderEntry> _workerCompletedOrders({
  required List<ProductionMapSaved> orders,
  required List<AdminCompletedQueueOrder> completedOrders,
  required List<AdminApparatus> apparatus,
  required String query,
}) {
  final byId = {for (final order in orders) order.map.id.trim(): order};
  final seen = <String>{};
  final entries = <_WorkerCompletedOrderEntry>[];
  for (final completed in completedOrders) {
    final orderId = completed.orderId.trim();
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
  final title = completed.apparatus.trim();
  if (title.isEmpty) {
    return null;
  }
  for (final item in apparatus) {
    if (_apparatusTitlesMatch(item.name, title)) {
      return item;
    }
  }
  return AdminApparatus(name: title);
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
    return const [];
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
    final index = apparatus.indexWhere(
      (entry) => _apparatusTitlesMatch(entry.name, item),
    );
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
  final title = apparatus.name.trim();
  return assignedApparatus.any((item) => _apparatusTitlesMatch(title, item));
}
