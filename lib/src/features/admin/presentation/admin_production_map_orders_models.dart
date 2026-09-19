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
    this.bobinaKg,
    this.diameter,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.finishedGoodsMeter,
    this.rezkaFrames = const [],
    this.rezkaOutputCycle = '',
    this.uom = '',
    this.qrPayload = '',
    this.progressBatchId = '',
    this.customerName = '',
    this.driverUrl = '',
    this.printTransport = PrintTransport.wifi,
    this.printer = '',
    this.printMode = '',
    this.completionRequestNote = '',
    this.returnedPaintItems = const [],
    this.returnedPaintImageId = '',
    this.fullCompletionReportRequired = false,
    this.completeWithoutOutput = false,
    this.workerHandoff = false,
    this.removeRollFromApparatus = false,
    this.freezeRequestId = '',
    this.freezeWithIssue = false,
    this.issueNote = '',
    this.printPreflightHoldId = '',
  });
  final AdminApparatus apparatus;
  final ProductionMapSaved order;
  final String action;
  final List<String> materialBarcodes;
  final List<String> qolipCodes;
  final double? producedQty;
  final double? grossQty;
  final double? bobinaKg;
  final double? diameter;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? finishedGoodsMeter;
  final List<Map<String, dynamic>> rezkaFrames;
  final String rezkaOutputCycle;
  final String uom;
  final String qrPayload;
  final String progressBatchId;
  final String customerName;
  final String driverUrl;
  final PrintTransport printTransport;
  final String printer;
  final String printMode;
  final String completionRequestNote;
  final List<ReturnedPaintItemInput> returnedPaintItems;
  final String returnedPaintImageId;
  final bool fullCompletionReportRequired;
  final bool completeWithoutOutput;
  final bool workerHandoff;
  final bool removeRollFromApparatus;
  final String freezeRequestId;
  final bool freezeWithIssue;
  final String issueNote;
  final String printPreflightHoldId;
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
    required this.issueNote,
  });
  final ProductionMapSaved order;
  final AdminApparatus? apparatus;
  final String status;
  final String issueNote;
  bool get isInProgress => status.trim().toLowerCase() == 'in_progress';
  bool get isFrozen => status.trim().toLowerCase() == 'frozen';
  bool get hasFreezeIssue => isFrozen || issueNote.trim().isNotEmpty;
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
    required this.stageNodeId,
    required this.rezkaOutputKadrCounts,
    required this.rezkaInputLineage,
    required this.rezkaActivePartialRolls,
    required this.materialAssignments,
    required this.intakeCandidateAssignments,
    required this.assignedMaterialAssignments,
    required this.confirmedMaterialBarcodes,
    required this.materialRequiredCount,
    required this.materialScannedCount,
    required this.allMaterialsScanned,
    required this.showStartMaterials,
    required this.showIntakeCandidates,
    required this.materialIntakeAllowed,
    required this.qolipScanRequired,
    required this.previousStage,
    required this.openingWipRequired,
    required this.previousProgressRequired,
    required this.previousProgressReady,
    required this.showStart,
    required this.printPreflight,
    required this.showPrintPreflightHold,
    required this.showPrintPreflightOutcome,
    required this.showPrintPreflightFreeze,
    required this.showPause,
    required this.showMerge,
    required this.showRollComplete,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
    required this.showWaitingForSequence,
    required this.contractSynchronized,
    required this.blockingReasonCode,
    required this.showBackendBlockingState,
  });
  final String orderId;
  final String station;
  final String stageNodeId;
  final List<int> rezkaOutputKadrCounts;
  final List<AdminRezkaInputLink> rezkaInputLineage;
  final List<AdminRezkaActivePartialRoll> rezkaActivePartialRolls;

  /// Backend-selected assignments that participate in the start policy.
  final List<AdminRawMaterialAssignment> materialAssignments;

  /// Assigned, staged and available materials that can still be taken.
  final List<AdminRawMaterialAssignment> intakeCandidateAssignments;

  /// Every raw material attached to the order, across apparatus.
  final List<AdminRawMaterialAssignment> assignedMaterialAssignments;
  final Set<String> confirmedMaterialBarcodes;
  final int materialRequiredCount;
  final int materialScannedCount;
  final bool allMaterialsScanned;
  final bool showStartMaterials;
  final bool showIntakeCandidates;
  final bool materialIntakeAllowed;
  final bool qolipScanRequired;
  final String? previousStage;
  final bool openingWipRequired;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final bool showStart;
  final AdminPrintPreflightHold? printPreflight;
  final bool showPrintPreflightHold;
  final bool showPrintPreflightOutcome;
  final bool showPrintPreflightFreeze;
  final bool showPause;
  final bool showMerge;
  final bool showRollComplete;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;
  final bool showWaitingForSequence;
  final bool contractSynchronized;
  final String blockingReasonCode;
  final bool showBackendBlockingState;
  int get scannedCount => materialScannedCount;
}

class _PreparedReadOnlyQueueAction {
  const _PreparedReadOnlyQueueAction({
    required this.apparatus,
    required this.onQueueAction,
    required this.materialAssignments,
    required this.scannedMaterialBarcodes,
    required this.startInputBatchId,
    required this.startInputQrPayload,
    this.blockReason,
  });
  final AdminApparatus apparatus;
  final _ReadOnlyQueueActionCallback onQueueAction;
  final List<AdminRawMaterialAssignment> materialAssignments;
  final Set<String> scannedMaterialBarcodes;
  final String startInputBatchId;
  final String startInputQrPayload;
  final String? blockReason;
}

class _MoveUnassignedApparatus extends AdminApparatus {
  const _MoveUnassignedApparatus() : super(name: 'Tanlanmagan');
}

const _moveUnassignedApparatus = _MoveUnassignedApparatus();

bool _isMoveUnassignedApparatus(AdminApparatus? apparatus) {
  return apparatus is _MoveUnassignedApparatus;
}

bool _sameMoveApparatusIdentity(
  AdminApparatus? left,
  AdminApparatus? right,
) {
  if (left == null || right == null) return false;
  if (_isMoveUnassignedApparatus(left) || _isMoveUnassignedApparatus(right)) {
    return _isMoveUnassignedApparatus(left) &&
        _isMoveUnassignedApparatus(right);
  }
  final leftId = left.id.trim();
  final rightId = right.id.trim();
  return leftId.isNotEmpty && rightId.isNotEmpty && leftId == rightId;
}

enum _OrderCardTone {
  neutral,
  printPreflight,
  printPreflightPassed,
  inProgress,
  waitingNextStage,
  paused,
  frozen,
  issue,
  completed,
}

_OrderCardTone _resolveWorkerOrderCardTone({
  required AdminQueueWorkActivity? workActivity,
  required String workerRole,
  required String workerRef,
  AdminProductionOrderStatusDetail? orderStatus,
  AdminOrderControlState orderControl = AdminOrderControlState.active,
  ApparatusQueueOrderState? apparatusState,
  bool printPreflightPassed = false,
}) {
  // Order-wide safety warnings remain shared. Active/paused/completed on a
  // different stage must not override this worker's own apparatus session.
  final globalTone = _resolveOrderCardTone(
    orderStatus: orderStatus,
    orderControl: orderControl,
    apparatusState: apparatusState,
  );
  if (globalTone == _OrderCardTone.issue ||
      globalTone == _OrderCardTone.frozen ||
      apparatusState == ApparatusQueueOrderState.frozen) {
    return globalTone == _OrderCardTone.issue
        ? globalTone
        : _OrderCardTone.frozen;
  }
  if (apparatusState == ApparatusQueueOrderState.printPreflight) {
    return printPreflightPassed
        ? _OrderCardTone.printPreflightPassed
        : _OrderCardTone.printPreflight;
  }
  if (workActivity == null ||
      !workActivity.belongsTo(role: workerRole, ref: workerRef)) {
    return _OrderCardTone.neutral;
  }
  return switch ((workActivity.state, apparatusState)) {
    ('in_progress', ApparatusQueueOrderState.inProgress) =>
      _OrderCardTone.inProgress,
    ('paused', ApparatusQueueOrderState.paused) => _OrderCardTone.paused,
    _ => _OrderCardTone.neutral,
  };
}

_OrderCardTone _resolveOrderCardTone({
  AdminProductionOrderStatusDetail? orderStatus,
  AdminOrderControlState orderControl = AdminOrderControlState.active,
  OrderQueueActivityState? orderActivityState,
  ApparatusQueueOrderState? apparatusState,
  bool printPreflightPassed = false,
}) {
  final preflightTone = printPreflightPassed
      ? _OrderCardTone.printPreflightPassed
      : _OrderCardTone.printPreflight;
  final status = orderStatus?.orderStatus.trim().toLowerCase() ?? '';
  final lifecycleStatus =
      orderStatus?.lifecycleStatus.trim().toLowerCase() ?? '';
  if (status == 'completed_with_issue' ||
      (orderStatus?.completedWithIssueCount ?? 0) > 0) {
    return _OrderCardTone.issue;
  }
  if (orderControl != AdminOrderControlState.active) {
    return _OrderCardTone.frozen;
  }
  if (status == 'frozen') {
    return _OrderCardTone.frozen;
  }
  if (status == 'print_preflight') {
    return preflightTone;
  }
  if (status == 'paused') {
    return _OrderCardTone.paused;
  }
  if (status == 'in_progress') {
    return _OrderCardTone.inProgress;
  }
  if (status == 'waiting_next_stage' || status == 'partially_completed') {
    return _OrderCardTone.waitingNextStage;
  }
  if (status == 'completed' ||
      lifecycleStatus == 'production_completed' ||
      lifecycleStatus == 'closed') {
    return _OrderCardTone.completed;
  }
  final activityState = orderActivityState ??
      switch (apparatusState) {
        ApparatusQueueOrderState.pending => OrderQueueActivityState.pending,
        ApparatusQueueOrderState.printPreflight =>
          OrderQueueActivityState.printPreflight,
        ApparatusQueueOrderState.inProgress =>
          OrderQueueActivityState.inProgress,
        ApparatusQueueOrderState.paused => OrderQueueActivityState.paused,
        ApparatusQueueOrderState.frozen => OrderQueueActivityState.frozen,
        ApparatusQueueOrderState.completed => OrderQueueActivityState.completed,
        null => null,
      };
  if (activityState != null) {
    return switch (activityState) {
      OrderQueueActivityState.printPreflight => preflightTone,
      OrderQueueActivityState.inProgress => _OrderCardTone.inProgress,
      OrderQueueActivityState.waitingNextStage =>
        _OrderCardTone.waitingNextStage,
      OrderQueueActivityState.paused => _OrderCardTone.paused,
      OrderQueueActivityState.frozen => _OrderCardTone.frozen,
      OrderQueueActivityState.completed => _OrderCardTone.completed,
      OrderQueueActivityState.pending => _OrderCardTone.neutral,
    };
  }
  return _OrderCardTone.neutral;
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
    _OrderCardTone.printPreflight ||
    _OrderCardTone.printPreflightPassed =>
      Colors.transparent,
    _OrderCardTone.inProgress => const Color(0xFF2E7D32),
    _OrderCardTone.waitingNextStage => const Color(0xFF1565C0),
    _OrderCardTone.paused => const Color(0xFFF9A825),
    _OrderCardTone.frozen => const Color(0xFFC62828),
    _OrderCardTone.issue => const Color(0xFFC62828),
    _OrderCardTone.completed => const Color(0xFF2E7D32),
    _OrderCardTone.neutral => Colors.transparent,
  };
  final opacity = theme.brightness == Brightness.dark ? 0.30 : 0.16;
  return Color.alphaBlend(
    accent.withValues(alpha: opacity),
    theme.colorScheme.surfaceContainerLowest,
  );
}

Gradient? _orderCardBackgroundGradient(_OrderCardTone tone) {
  if (tone == _OrderCardTone.printPreflightPassed) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2A6618), Color(0xFF79BD2F), Color(0xFFBFE653)],
      stops: [0.0, 0.52, 1.0],
    );
  }
  if (tone != _OrderCardTone.printPreflight) return null;
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF7E86A8),
      Color(0xFFE5BFC4),
      Color(0xFFF4FAFC),
    ],
    stops: [0.0, 0.52, 1.0],
  );
}

// Presentation only: never turn a passed colour trial into a queue/work state.
// Match the current apparatus/order, and ignore historical or consumed holds.
bool _orderPrintPreflightPassed({
  required String orderId,
  required Map<String, Map<String, String>> queueStates,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      controls,
  String? apparatusId,
  String? stageNodeId,
}) {
  final id = orderId.trim();
  final stages = queueStates.entries.where((entry) =>
      (apparatusId == null || entry.key == apparatusId.trim()) &&
      entry.value[id]?.trim() == 'print_preflight');
  return stages.isNotEmpty &&
      stages.every((entry) {
        final control = controls[entry.key]?[id];
        final hold = control?.printPreflight;
        return control?.state.trim() == 'print_preflight' &&
            (stageNodeId == null ||
                control?.stageNodeId.trim() == stageNodeId.trim()) &&
            hold != null &&
            hold.isPassed &&
            hold.orderId.trim() == id &&
            hold.apparatus.trim() == entry.key;
      });
}
