part of 'admin_production_map_orders_screen.dart';

class _WorkerWatchTab {
  const _WorkerWatchTab.apparatus(this.apparatus) : isCompleted = false;
  const _WorkerWatchTab.completed()
      : apparatus = null,
        isCompleted = true;

  final AdminWarehouse? apparatus;
  final bool isCompleted;
}

class _WorkerCompletedOrderEntry {
  const _WorkerCompletedOrderEntry({
    required this.order,
    required this.apparatus,
  });

  final ProductionMapSaved order;
  final AdminWarehouse? apparatus;
}

const _moveUnassignedWarehouse = AdminWarehouse(
  warehouse: 'Tanlanmagan',
  parentWarehouse: 'production-map-unassigned',
);

bool _isMoveUnassignedApparatus(AdminWarehouse? apparatus) {
  return apparatus?.parentWarehouse == _moveUnassignedWarehouse.parentWarehouse;
}
