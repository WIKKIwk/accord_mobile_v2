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
    this.qolipCodes = const [],
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
  final List<String> qolipCodes;
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
    required this.status,
  });

  final ProductionMapSaved order;
  final AdminApparatus? apparatus;
  final String status;

  bool get isInProgress => status.trim().toLowerCase() == 'in_progress';
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
    required this.customerByMapId,
  });

  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
  final Map<String, String> customerByMapId;
}

class _ReadOnlyOrderDetailUiState {
  const _ReadOnlyOrderDetailUiState({
    required this.orderId,
    required this.station,
    required this.materialAssignments,
    required this.intakeCandidateAssignments,
    required this.assignedMaterialAssignments,
    required this.confirmedMaterialBarcodes,
    required this.materialRequiredCount,
    required this.materialScannedCount,
    required this.hasMaterialAssignments,
    required this.allMaterialsScanned,
    required this.showStartMaterials,
    required this.showIntakeCandidates,
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

  /// Backend-selected assignments that participate in the start policy.
  final List<AdminRawMaterialAssignment> materialAssignments;

  /// Assigned, staged and available materials that can still be taken.
  final List<AdminRawMaterialAssignment> intakeCandidateAssignments;

  /// Every raw material attached to the order, across apparatus.
  final List<AdminRawMaterialAssignment> assignedMaterialAssignments;
  final Set<String> confirmedMaterialBarcodes;
  final int materialRequiredCount;
  final int materialScannedCount;
  final bool hasMaterialAssignments;
  final bool allMaterialsScanned;
  final bool showStartMaterials;
  final bool showIntakeCandidates;
  final String? previousStage;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final bool showStart;
  final bool showPause;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;

  int get scannedCount => materialScannedCount;
}

class _PreparedReadOnlyQueueAction {
  const _PreparedReadOnlyQueueAction({
    required this.apparatus,
    required this.onQueueAction,
    required this.materialAssignments,
    required this.scannedMaterialBarcodes,
    required this.startInputProgressBatch,
    required this.bypassStartMaterialScan,
    this.blockReason,
  });

  final AdminApparatus apparatus;
  final _ReadOnlyQueueActionCallback onQueueAction;
  final List<AdminRawMaterialAssignment> materialAssignments;
  final Set<String> scannedMaterialBarcodes;
  final AdminProgressBatch? startInputProgressBatch;
  final bool bypassStartMaterialScan;
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

enum _OrderCardTone { neutral, inProgress, paused, frozen, issue }

_OrderCardTone _resolveOrderCardTone({
  AdminProductionOrderStatusDetail? orderStatus,
  AdminOrderControlState orderControl = AdminOrderControlState.active,
  ApparatusQueueOrderState? apparatusState,
}) {
  final status = orderStatus?.orderStatus.trim() ?? '';
  if (status == 'completed_with_issue' ||
      (orderStatus?.completedWithIssueCount ?? 0) > 0) {
    return _OrderCardTone.issue;
  }
  if (orderControl != AdminOrderControlState.active) {
    return _OrderCardTone.frozen;
  }
  if (apparatusState != null) {
    return switch (apparatusState) {
      ApparatusQueueOrderState.inProgress => _OrderCardTone.inProgress,
      ApparatusQueueOrderState.paused => _OrderCardTone.paused,
      ApparatusQueueOrderState.completed => _OrderCardTone.neutral,
      ApparatusQueueOrderState.pending => _OrderCardTone.neutral,
    };
  }
  return switch (status) {
    'in_progress' => _OrderCardTone.inProgress,
    'paused' => _OrderCardTone.paused,
    _ => _OrderCardTone.neutral,
  };
}

Color? _orderCardBackgroundColor(
  BuildContext context,
  _OrderCardTone tone,
) {
  if (tone == _OrderCardTone.neutral) {
    return null;
  }
  final theme = Theme.of(context);
  final accent = switch (tone) {
    _OrderCardTone.inProgress => const Color(0xFF2E7D32),
    _OrderCardTone.paused => const Color(0xFFF9A825),
    _OrderCardTone.frozen => const Color(0xFF1565C0),
    _OrderCardTone.issue => const Color(0xFFC62828),
    _OrderCardTone.neutral => Colors.transparent,
  };
  final opacity = theme.brightness == Brightness.dark ? 0.30 : 0.16;
  return Color.alphaBlend(
    accent.withValues(alpha: opacity),
    theme.colorScheme.surfaceContainerLowest,
  );
}

Color? _qolipOrderCardBackgroundColor(
  BuildContext context,
  AdminQolipOrderNote? note,
) {
  if (note == null || (!note.isGiven && !note.isReturned)) {
    return null;
  }
  final theme = Theme.of(context);
  final accent =
      note.isGiven ? const Color(0xFF2E7D32) : const Color(0xFFF9A825);
  final opacity = theme.brightness == Brightness.dark ? 0.30 : 0.16;
  return Color.alphaBlend(
    accent.withValues(alpha: opacity),
    theme.colorScheme.surfaceContainerLowest,
  );
}
