part of 'admin_production_map_orders_screen.dart';

typedef _ReadOnlyQueueActionCallback = Future<AdminApparatusQueueActionResult?>
    Function(
  _ReadOnlyQueueActionRequest request,
);

enum _ProgressActionOutcome { completed, cancelled, failed }

class _ReadOnlyQueueActionRequest {
  const _ReadOnlyQueueActionRequest({
    required this.apparatus,
    required this.order,
    required this.action,
    this.materialBarcodes = const [],
    this.qolipCode = '',
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
    this.printTransport = PrintTransport.wifi,
    this.printer = '',
    this.printMode = '',
    this.completionRequestNote = '',
    this.returnedPaintItems = const [],
    this.returnedPaintImageId = '',
    this.freezeRequestId = '',
  });

  final AdminApparatus apparatus;
  final ProductionMapSaved order;
  final String action;
  final List<String> materialBarcodes;
  final String qolipCode;
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
  final PrintTransport printTransport;
  final String printer;
  final String printMode;
  final String completionRequestNote;
  final List<ReturnedPaintItemInput> returnedPaintItems;
  final String returnedPaintImageId;
  final String freezeRequestId;
}

class _WorkerWatchTab {
  const _WorkerWatchTab.apparatus(this.apparatus) : isCompleted = false;
  const _WorkerWatchTab.completed()
      : apparatus = null,
        isCompleted = true;

  final AdminApparatus? apparatus;
  final bool isCompleted;
}

class _WorkerCompletedOrderEntry {
  const _WorkerCompletedOrderEntry({
    required this.order,
    required this.apparatus,
  });

  final ProductionMapSaved order;
  final AdminApparatus? apparatus;
}

class _MoveApparatusDefaults {
  const _MoveApparatusDefaults({
    required this.top,
    required this.bottom,
  });

  final AdminApparatus? top;
  final AdminApparatus? bottom;
}

class _ProductionMapOrdersAndApparatus {
  const _ProductionMapOrdersAndApparatus({
    required this.orders,
    required this.apparatus,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatus;
}

class _ProductionMapOrderMetrics {
  const _ProductionMapOrderMetrics({
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
  });

  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
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

  final AdminApparatus apparatus;
  final _ReadOnlyQueueActionCallback onQueueAction;
  final List<AdminRawMaterialAssignment> materialAssignments;
  final AdminProgressBatch? startInputProgressBatch;
  final String? blockReason;
}

class _MaterialScanResult {
  const _MaterialScanResult({required this.assignment});

  final AdminRawMaterialAssignment? assignment;
}

class _MoveUnassignedApparatus extends AdminApparatus {
  const _MoveUnassignedApparatus() : super(name: 'Tanlanmagan');
}

const _moveUnassignedApparatus = _MoveUnassignedApparatus();

bool _isMoveUnassignedApparatus(AdminApparatus? apparatus) {
  return apparatus is _MoveUnassignedApparatus;
}
