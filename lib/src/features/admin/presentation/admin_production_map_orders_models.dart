part of 'admin_production_map_orders_screen.dart';

typedef _ReadOnlyQueueActionCallback = Future<AdminApparatusQueueActionResult?>
    Function(
  _ReadOnlyQueueActionRequest request,
);

class _ReadOnlyQueueActionRequest {
  const _ReadOnlyQueueActionRequest({
    required this.apparatus,
    required this.order,
    required this.action,
    this.materialBarcodes = const [],
    this.producedQty,
    this.grossQty,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.finishedGoodsMeter,
    this.uom = '',
    this.qrPayload = '',
    this.progressBatchId = '',
    this.driverUrl = '',
    this.completionRequestNote = '',
  });

  final AdminWarehouse apparatus;
  final ProductionMapSaved order;
  final String action;
  final List<String> materialBarcodes;
  final double? producedQty;
  final double? grossQty;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? finishedGoodsMeter;
  final String uom;
  final String qrPayload;
  final String progressBatchId;
  final String driverUrl;
  final String completionRequestNote;
}

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

class _PreparedReadOnlyQueueAction {
  const _PreparedReadOnlyQueueAction({
    required this.apparatus,
    required this.onQueueAction,
    required this.materialAssignments,
    required this.startInputProgressBatch,
    this.blockReason,
  });

  final AdminWarehouse apparatus;
  final _ReadOnlyQueueActionCallback onQueueAction;
  final List<AdminRawMaterialAssignment> materialAssignments;
  final AdminProgressBatch? startInputProgressBatch;
  final String? blockReason;
}

class _MaterialScanResult {
  const _MaterialScanResult({required this.assignment});

  final AdminRawMaterialAssignment? assignment;
}

const _moveUnassignedWarehouse = AdminWarehouse(
  warehouse: 'Tanlanmagan',
  parentWarehouse: 'production-map-unassigned',
);

bool _isMoveUnassignedApparatus(AdminWarehouse? apparatus) {
  return apparatus?.parentWarehouse == _moveUnassignedWarehouse.parentWarehouse;
}
