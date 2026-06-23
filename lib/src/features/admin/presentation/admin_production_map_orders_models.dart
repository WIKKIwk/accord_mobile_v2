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

class _MoveApparatusDefaults {
  const _MoveApparatusDefaults({
    required this.top,
    required this.bottom,
  });

  final AdminWarehouse? top;
  final AdminWarehouse? bottom;
}

class _ProductionMapOrdersAndApparatus {
  const _ProductionMapOrdersAndApparatus({
    required this.orders,
    required this.apparatus,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminWarehouse> apparatus;
}

class _ProductionMapOrderMetrics {
  const _ProductionMapOrderMetrics({
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
  });

  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
}

class _ProductionMapLiveConnection {
  const _ProductionMapLiveConnection({
    required this.subscription,
    required this.completed,
  });

  final StreamSubscription<String> subscription;
  final Future<void> completed;
}

class _ReadOnlyOrderDetailUiState {
  const _ReadOnlyOrderDetailUiState({
    required this.orderId,
    required this.station,
    required this.materialAssignments,
    required this.confirmedMaterialBarcodes,
    required this.hasMaterialAssignments,
    required this.allMaterialsScanned,
    required this.previousStage,
    required this.previousProgressRequired,
    required this.previousProgressReady,
    required this.showStart,
    required this.showPause,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
  });

  final String orderId;
  final String station;
  final List<AdminRawMaterialAssignment> materialAssignments;
  final Set<String> confirmedMaterialBarcodes;
  final bool hasMaterialAssignments;
  final bool allMaterialsScanned;
  final String? previousStage;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final bool showStart;
  final bool showPause;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;

  int get scannedCount => confirmedMaterialBarcodes.length;
}

const _moveUnassignedWarehouse = AdminWarehouse(
  warehouse: 'Tanlanmagan',
  parentWarehouse: 'production-map-unassigned',
);

bool _isMoveUnassignedApparatus(AdminWarehouse? apparatus) {
  return apparatus?.parentWarehouse == _moveUnassignedWarehouse.parentWarehouse;
}
