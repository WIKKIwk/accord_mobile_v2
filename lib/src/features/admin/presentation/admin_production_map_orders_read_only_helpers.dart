part of 'admin_production_map_orders_screen.dart';

Map<String, String> _queueStatesForStation(
  String station,
  Map<String, Map<String, String>> queueStatesByApparatus,
) {
  final direct = queueStatesByApparatus[station];
  if (direct != null) {
    return direct;
  }
  return const {};
}

class _RawMaterialBalance {
  const _RawMaterialBalance({
    required this.uom,
    required this.receivedQty,
    required this.consumedQty,
  });
  final String uom;
  final double receivedQty;
  final double consumedQty;
  double get remainingQty {
    final result = receivedQty - consumedQty;
    return result > 0 ? result : 0;
  }
}

List<_RawMaterialBalance> _rawMaterialBalances(
  List<AdminRawMaterialAssignment> assignments,
) {
  final receivedByUom = <String, double>{};
  final consumedByUom = <String, double>{};
  final labelsByUom = <String, String>{};
  for (final assignment in assignments) {
    final uom = assignment.stockUom.trim();
    if (uom.isEmpty) continue;
    final key = uom.toLowerCase();
    labelsByUom.putIfAbsent(key, () => uom);
    final received = assignment.receivedQty;
    final consumed = assignment.consumedQty;
    if (received.isFinite && received > 0) {
      receivedByUom[key] = (receivedByUom[key] ?? 0) + received;
    }
    if (consumed.isFinite && consumed > 0) {
      consumedByUom[key] = (consumedByUom[key] ?? 0) + consumed;
    }
  }
  final balances = <_RawMaterialBalance>[
    for (final entry in labelsByUom.entries)
      _RawMaterialBalance(
        uom: entry.value,
        receivedQty: receivedByUom[entry.key] ?? 0,
        consumedQty: consumedByUom[entry.key] ?? 0,
      ),
  ];
  balances.sort((left, right) =>
      left.uom.toLowerCase().compareTo(right.uom.toLowerCase()));
  return balances;
}

bool _rawMaterialAssignmentIsConsumed(AdminRawMaterialAssignment assignment) {
  return assignment.stockStatus.trim().toLowerCase() == 'consumed' ||
      assignment.consumedQty > 0;
}

bool _rawMaterialAssignmentIsLocked(AdminRawMaterialAssignment assignment) {
  final status = assignment.stockStatus.trim().toLowerCase();
  return _rawMaterialAssignmentIsConsumed(assignment) ||
      (status.isNotEmpty && status != 'available');
}

bool _rawMaterialAssignmentCanBeUnlinked(
  AdminRawMaterialAssignment assignment,
) {
  return !_rawMaterialAssignmentIsLocked(assignment);
}

String _rawMaterialAssignmentStatusText(
  AdminRawMaterialAssignment assignment,
  AppLocalizations l10n,
) {
  if (_rawMaterialAssignmentIsConsumed(assignment)) {
    return l10n.productionText('worker.material.status.consumed');
  }
  return switch (assignment.stockStatus.trim().toLowerCase()) {
    'in_use' => l10n.productionText('worker.material.status.in_use'),
    'available' || '' => '',
    _ => l10n.productionText('worker.material.status.attached'),
  };
}

Set<String> _confirmedMaterialBarcodes({
  required List<AdminRawMaterialAssignment> assignments,
  required Set<String> scannedBarcodes,
  required String orderId,
}) {
  return {
    for (final assignment in assignments)
      if (_materialAssignmentConfirmed(
        assignment: assignment,
        scannedBarcodes: scannedBarcodes,
        orderId: orderId,
      ))
        _materialBarcodeKey(assignment.barcode),
  };
}

bool _materialAssignmentConfirmed({
  required AdminRawMaterialAssignment assignment,
  required Set<String> scannedBarcodes,
  required String orderId,
}) {
  if (scannedBarcodes.contains(_materialBarcodeKey(assignment.barcode))) {
    return true;
  }
  final stockStatus = assignment.stockStatus.trim().toLowerCase();
  final reservedOrderId = assignment.reservedOrderId.trim();
  return reservedOrderId == orderId &&
      (stockStatus == 'in_use' || stockStatus == 'consumed');
}

String _materialBarcodeKey(String value) => value.trim().toUpperCase();

AdminRawMaterialAssignment? _materialAssignmentForScannedBarcode({
  required List<AdminRawMaterialAssignment> assignments,
  required String barcode,
}) {
  final normalized = _materialBarcodeKey(rawMaterialBarcodeFromQr(barcode));
  return assignments
      .where((item) => _materialBarcodeKey(item.barcode) == normalized)
      .cast<AdminRawMaterialAssignment?>()
      .firstWhere((item) => item != null, orElse: () => null);
}

bool _progressBatchCanBeScanned(AdminProgressBatch batch) {
  final wipStatus = batch.wipStatus.trim().toLowerCase();
  return wipStatus.isEmpty || wipStatus == 'waiting';
}

AdminProgressBatch? _matchingInputProgressBatch({
  required List<AdminProgressBatch> batches,
  required AdminProgressBatch batch,
}) {
  for (final item in batches) {
    final sameBatch = item.batchId.trim().isNotEmpty &&
        item.batchId.trim() == batch.batchId.trim();
    final sameQr = item.qrPayload.trim().isNotEmpty &&
        item.qrPayload.trim().toUpperCase() ==
            batch.qrPayload.trim().toUpperCase();
    if (sameBatch || sameQr) {
      return item;
    }
  }
  return null;
}

AdminProgressBatch? _inputProgressBatchForScannedQr({
  required List<AdminProgressBatch> batches,
  required String qrPayload,
}) {
  final normalized = qrPayload.trim().toUpperCase();
  if (normalized.isEmpty) return null;
  for (final batch in batches) {
    if (batch.qrPayload.trim().toUpperCase() == normalized &&
        _progressBatchCanBeScanned(batch)) {
      return batch;
    }
  }
  return null;
}

AdminOpeningWipBatch? _matchingOpeningWipBatch({
  required List<AdminOpeningWipBatch> batches,
  String batchId = '',
  String qrPayload = '',
}) {
  final normalizedBatchId = batchId.trim();
  final normalizedQr = qrPayload.trim().toUpperCase();
  for (final batch in batches) {
    final sameBatch = normalizedBatchId.isNotEmpty &&
        batch.batchId.trim() == normalizedBatchId;
    final sameQr = normalizedQr.isNotEmpty &&
        batch.qrPayload.trim().toUpperCase() == normalizedQr;
    if ((sameBatch || sameQr) &&
        batch.wipStatus.trim().toLowerCase() == 'waiting') {
      return batch;
    }
  }
  return null;
}

List<String> _queueActionMaterialBarcodes({
  required String action,
  required List<AdminRawMaterialAssignment> assignments,
  required Set<String> scannedBarcodes,
}) {
  if (action != 'start') return const [];
  final scanned = scannedBarcodes.map(_materialBarcodeKey).toSet()..remove('');
  return [
    for (final assignment in assignments)
      if (scanned.contains(_materialBarcodeKey(assignment.barcode)))
        assignment.barcode.trim(),
  ];
}

String _queueActionQrPayload({
  required String action,
  required String qrPayload,
  required String startInputQrPayload,
}) {
  final explicitQrPayload = qrPayload.trim();
  if (explicitQrPayload.isNotEmpty) {
    return explicitQrPayload;
  }
  return action == 'start' ? startInputQrPayload.trim() : '';
}

String _queueActionProgressBatchId({
  required String action,
  required String progressBatchId,
  required String startInputBatchId,
}) {
  final explicitProgressBatchId = progressBatchId.trim();
  if (explicitProgressBatchId.isNotEmpty) {
    return explicitProgressBatchId;
  }
  return action == 'start' ? startInputBatchId.trim() : '';
}

bool _queueActionShouldClearStartInputProgress({
  required String action,
  required AdminApparatusQueueActionResult? result,
}) {
  return result != null &&
      const {'start', 'roll_complete', 'complete'}.contains(action);
}

bool _queueActionShouldReloadMaterials({
  required String action,
  required AdminApparatusQueueActionResult? result,
}) {
  return action == 'start' && result != null;
}

_ReadOnlyQueueActionRequest _readOnlyQueueActionRequest({
  required _PreparedReadOnlyQueueAction prepared,
  required ProductionMapSaved order,
  required String action,
  required _ProgressQtyInput? progressInput,
  required String uom,
  required String qrPayload,
  required String progressBatchId,
  required String customerName,
  required String driverUrl,
  required PrintTransport printTransport,
  required String printer,
  required String printMode,
  required String completionRequestNote,
  required List<String> qolipCodes,
  String freezeRequestId = '',
  bool workerHandoff = false,
  bool removeRollFromApparatus = false,
  bool freezeWithIssue = false,
  String issueNote = '',
}) {
  return _ReadOnlyQueueActionRequest(
    apparatus: prepared.apparatus,
    order: order,
    action: action,
    materialBarcodes: _queueActionMaterialBarcodes(
      action: action,
      assignments: prepared.materialAssignments,
      scannedBarcodes: prepared.scannedMaterialBarcodes,
    ),
    qolipCodes: qolipCodes,
    producedQty: progressInput?.meterQty,
    grossQty: progressInput?.kgQty,
    bobinaKg: progressInput?.bobinaKg,
    diameter: progressInput?.diameter,
    returnInkKg: progressInput?.returnInkKg,
    laminationPrintLeftoverRolls: progressInput?.laminationPrintLeftoverRolls,
    laminationFilmLeftoverRolls: progressInput?.laminationFilmLeftoverRolls,
    rezkaBosmaWaste: progressInput?.rezkaBosmaWaste,
    rezkaLaminationWaste: progressInput?.rezkaLaminationWaste,
    rezkaEdgeWaste: progressInput?.rezkaEdgeWaste,
    totalWaste: progressInput?.totalWaste,
    finishedGoodsKg: progressInput?.finishedGoodsKg,
    finishedGoodsMeter: progressInput?.finishedGoodsMeter,
    rezkaOutputCycle: progressInput?.rezkaOutputCycle ?? '',
    rezkaFrames: [
      for (final frame in progressInput?.rezkaFrames ?? const [])
        frame.toJson(),
    ],
    uom: uom,
    qrPayload: _queueActionQrPayload(
      action: action,
      qrPayload: qrPayload,
      startInputQrPayload: prepared.startInputQrPayload,
    ),
    progressBatchId: _queueActionProgressBatchId(
      action: action,
      progressBatchId: progressBatchId,
      startInputBatchId: prepared.startInputBatchId,
    ),
    customerName: customerName.trim(),
    driverUrl: driverUrl,
    printTransport: printTransport,
    printer: printer,
    printMode: printMode,
    completionRequestNote: completionRequestNote.trim().isEmpty
        ? progressInput?.description ?? ''
        : completionRequestNote,
    returnedPaintItems: progressInput?.returnedPaintItems ?? const [],
    returnedPaintImageId: progressInput?.returnedPaintImageId ?? '',
    fullCompletionReportRequired:
        progressInput?.fullCompletionReportRequired ?? false,
    workerHandoff: workerHandoff,
    removeRollFromApparatus: removeRollFromApparatus,
    freezeRequestId: freezeRequestId,
    freezeWithIssue: freezeWithIssue,
    issueNote: issueNote,
  );
}

String? _queueActionStartBlockReason({
  required String action,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required bool materialsLoading,
  required String materialsError,
  required bool inputWipReady,
  required bool materialScanRequired,
  required bool previousWipRequired,
  required bool qolipScanRequired,
  required bool qolipScanned,
  required AppLocalizations l10n,
}) {
  if (action != 'start') {
    return null;
  }
  final materialUnavailableReason = _materialStartUnavailableReason(
    materialRequirements: materialRequirements,
    materialsLoading: materialsLoading,
    materialsError: materialsError,
    materialScanRequired: materialScanRequired,
    l10n: l10n,
  );
  if (materialUnavailableReason != null) {
    return materialUnavailableReason;
  }
  if (materialScanRequired && materialRequirements != null) {
    if (materialRequirements.normalizedAssignedBarcodes.isNotEmpty &&
        !materialRequirements.scanSatisfied) {
      return materialRequirements.policy == AdminRawMaterialStartPolicy.stateAll
          ? l10n.productionText('worker.error.scan_all_materials')
          : l10n.productionText('worker.error.scan_required_materials');
    }
  }
  if (qolipScanRequired && !qolipScanned) {
    return l10n.productionText('worker.error.scan_molds');
  }
  if (previousWipRequired && !inputWipReady) {
    return l10n.productionText('worker.error.scan_previous');
  }
  return null;
}

String? _materialStartUnavailableReason({
  required AdminRawMaterialStartRequirements? materialRequirements,
  required bool materialsLoading,
  required String materialsError,
  required bool materialScanRequired,
  required AppLocalizations l10n,
}) {
  if (!materialScanRequired) {
    return null;
  }
  if (materialsLoading) {
    return l10n.productionText('worker.error.rule_loading');
  }
  if (materialsError.trim().isNotEmpty || materialRequirements == null) {
    return materialsError.trim().isEmpty
        ? l10n.productionText('worker.error.rule_failed')
        : materialsError.trim();
  }
  if (materialRequirements.requiresMaterial &&
      materialRequirements.normalizedAssignedBarcodes.isEmpty) {
    return l10n.productionText('worker.error.no_materials');
  }
  if (!materialRequirements.assignmentsSatisfied) {
    return l10n.productionText('worker.error.incomplete_material_groups');
  }
  if (materialRequirements.policy == AdminRawMaterialStartPolicy.stateAll &&
      materialRequirements.normalizedAssignedBarcodes.isNotEmpty &&
      materialRequirements.normalizedStagedBarcodes.isEmpty) {
    return l10n.productionText('worker.error.material_not_at_machine');
  }
  return null;
}

String _readOnlyQueueActionErrorText(
  Object error,
  AppLocalizations l10n,
) {
  if (error is TimeoutException || error is http.ClientException) {
    return l10n.productionText('worker.error.network_timeout');
  }
  if (error is MobileApiException &&
      error.code == 'merge_input_frame_count_mismatch' &&
      error.activeKadrCount != null &&
      error.scannedKadrCount != null) {
    return l10n.productionText(
      'worker.error.merge_input_frame_count_mismatch_detail',
      values: {
        'active': error.activeKadrCount,
        'scanned': error.scannedKadrCount,
      },
    );
  }
  return error is MobileApiException
      ? l10n.productionErrorMessage(
          error.code,
          fallback: error.message,
        )
      : l10n.productionText('worker.error.action_failed');
}

bool _queueActionShouldClearQolipScan(Object error) {
  if (error is! MobileApiException) return false;
  return const {
    'qolip_scan_required',
    'qolip_scan_incomplete',
    'qolip_code_not_found',
    'qolip_code_mismatch',
    'qolip_location_not_found',
    'insufficient_stock',
    'location_identity_mismatch',
  }.contains(error.code);
}

_PreparedReadOnlyQueueAction? _prepareReadOnlyQueueAction({
  required String action,
  required AdminApparatus? apparatus,
  required _ReadOnlyQueueActionCallback? onQueueAction,
  required bool actionInFlight,
  required List<AdminRawMaterialAssignment> materialAssignments,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required bool materialsLoading,
  required String materialsError,
  required AdminApparatusQueueOrderActionControl? queueActionControl,
  required Set<String> scannedMaterialBarcodes,
  required AdminProgressBatch? startInputProgressBatch,
  required AdminOpeningWipBatch? startInputOpeningWipBatch,
  required bool qolipScanned,
  required AppLocalizations l10n,
}) {
  if (apparatus == null || onQueueAction == null || actionInFlight) {
    return null;
  }
  if (queueActionControl?.contractValid != true) {
    return null;
  }
  final interaction = queueActionControl?.interaction;
  if (interaction == null) return null;
  final openingWipRequired =
      interaction.openingWipMode == AdminQueuePreviousWipMode.scanRequired;
  final previousWipRequired =
      interaction.previousWipMode == AdminQueuePreviousWipMode.scanRequired;
  final inputWipReady = openingWipRequired
      ? startInputOpeningWipBatch != null
      : !previousWipRequired || startInputProgressBatch != null;
  final startInputBatchId = openingWipRequired
      ? startInputOpeningWipBatch?.batchId ?? ''
      : startInputProgressBatch?.batchId ?? '';
  final startInputQrPayload = openingWipRequired
      ? startInputOpeningWipBatch?.qrPayload ?? ''
      : startInputProgressBatch?.qrPayload ?? '';
  return _PreparedReadOnlyQueueAction(
    apparatus: apparatus,
    onQueueAction: onQueueAction,
    materialAssignments: materialAssignments,
    scannedMaterialBarcodes: Set<String>.unmodifiable(scannedMaterialBarcodes),
    startInputBatchId: startInputBatchId,
    startInputQrPayload: startInputQrPayload,
    blockReason: _queueActionStartBlockReason(
      action: action,
      materialRequirements: materialRequirements,
      materialsLoading: materialsLoading,
      materialsError: materialsError,
      inputWipReady: inputWipReady,
      materialScanRequired: interaction.materialScanRequired,
      previousWipRequired: previousWipRequired || openingWipRequired,
      qolipScanRequired:
          interaction.qolipMode == AdminQueueQolipMode.scanRequired,
      qolipScanned: qolipScanned,
      l10n: l10n,
    ),
  );
}

_ReadOnlyOrderDetailUiState _readOnlyOrderDetailUiState({
  required ProductionMapSaved order,
  required AdminApparatus? apparatus,
  required List<AdminRawMaterialAssignment> materialAssignments,
  required List<AdminRawMaterialAssignment> startMaterialAssignments,
  required List<AdminRawMaterialAssignment> intakeCandidateAssignments,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required Set<String> scannedMaterialBarcodes,
  required bool canManageQueue,
  required AdminApparatusQueueOrderActionControl? queueActionControl,
  required AdminOrderControlState orderControlState,
  String? queueState,
  required AdminProgressBatch? startInputProgressBatch,
  required AdminOpeningWipBatch? startInputOpeningWipBatch,
}) {
  final map = order.map;
  final orderId = map.id.trim();
  final station = apparatus?.id.trim() ?? '';
  final contractValid = queueActionControl?.contractValid == true;
  final contractSynchronized = contractValid &&
      queueActionControl!.isConsistentWith(
        orderControlState,
        queueState: queueState,
      );
  final interaction = contractValid ? queueActionControl?.interaction : null;
  final previousStageValue = queueActionControl?.previousStage.trim() ?? '';
  final previousStage = previousStageValue.isEmpty ? null : previousStageValue;
  final bypassMaterialGate = interaction?.startMaterialsMode !=
      AdminQueueStartMaterialsMode.scanRequired;
  final stationMaterialAssignments = materialRequirements == null
      ? const <AdminRawMaterialAssignment>[]
      : startMaterialAssignments;
  final confirmedMaterialBarcodes = _confirmedMaterialBarcodes(
    assignments: materialAssignments,
    scannedBarcodes: scannedMaterialBarcodes,
    orderId: orderId,
  );
  final allMaterialsScanned =
      bypassMaterialGate ? true : materialRequirements?.scanSatisfied ?? true;
  final materialRequiredCount = materialRequirements == null
      ? 0
      : bypassMaterialGate
          ? 0
          : materialRequirements.normalizedAssignedBarcodes.isEmpty &&
                  !materialRequirements.requiresMaterial
              ? 0
              : materialRequirements.requiredScanCount;
  final materialScannedCount =
      materialRequirements == null || bypassMaterialGate
          ? 0
          : materialRequirements.matchedScanCount;
  final normalPreviousProgressRequired =
      interaction?.previousWipMode == AdminQueuePreviousWipMode.scanRequired;
  final openingWipRequired =
      interaction?.openingWipMode == AdminQueuePreviousWipMode.scanRequired;
  final previousProgressRequired =
      normalPreviousProgressRequired || openingWipRequired;
  final acceptedPreviousWip = openingWipRequired
      ? startInputOpeningWipBatch != null
      : normalPreviousProgressRequired && startInputProgressBatch != null;
  final showStart = contractSynchronized &&
      canManageQueue &&
      queueActionControl.allows('start');
  final showPause = contractSynchronized &&
      canManageQueue &&
      queueActionControl.allows('pause');
  final showMerge = contractSynchronized &&
      canManageQueue &&
      queueActionControl.allows('merge');
  final showRollComplete = contractSynchronized &&
      canManageQueue &&
      queueActionControl.allows('roll_complete');
  final showComplete = contractSynchronized &&
      canManageQueue &&
      queueActionControl.allows('complete');
  final showResume = contractSynchronized &&
      canManageQueue &&
      queueActionControl.allows('resume');
  return _ReadOnlyOrderDetailUiState(
    orderId: orderId,
    station: station,
    stageNodeId: queueActionControl?.stageNodeId.trim() ?? '',
    rezkaOutputKadrCounts:
        queueActionControl?.rezkaOutputKadrCounts ?? const <int>[],
    rezkaInputLineage:
        queueActionControl?.rezkaInputLineage ?? const <AdminRezkaInputLink>[],
    rezkaActivePartialRolls: queueActionControl?.rezkaActivePartialRolls ??
        const <AdminRezkaActivePartialRoll>[],
    materialAssignments: stationMaterialAssignments,
    intakeCandidateAssignments: intakeCandidateAssignments,
    assignedMaterialAssignments: materialAssignments,
    confirmedMaterialBarcodes: confirmedMaterialBarcodes,
    materialRequiredCount: materialRequiredCount,
    materialScannedCount: materialScannedCount,
    allMaterialsScanned: allMaterialsScanned,
    showStartMaterials: contractSynchronized &&
        interaction?.startMaterialsMode ==
            AdminQueueStartMaterialsMode.scanRequired,
    showIntakeCandidates:
        contractSynchronized && (interaction?.materialIntakeAllowed ?? false),
    materialIntakeAllowed:
        contractSynchronized && (interaction?.materialIntakeAllowed ?? false),
    qolipScanRequired: contractSynchronized &&
        interaction?.qolipMode == AdminQueueQolipMode.scanRequired,
    previousStage: previousStage,
    openingWipRequired: openingWipRequired,
    previousProgressRequired: previousProgressRequired,
    previousProgressReady: !previousProgressRequired || acceptedPreviousWip,
    showStart: showStart,
    showPause: showPause,
    showMerge: showMerge,
    showRollComplete: showRollComplete,
    showComplete: showComplete,
    showResume: showResume,
    showWaitingForPrevious: contractSynchronized &&
        canManageQueue &&
        (interaction?.previousWipMode == AdminQueuePreviousWipMode.waiting ||
            interaction?.openingWipMode == AdminQueuePreviousWipMode.waiting),
    showWaitingForSequence: contractSynchronized &&
        canManageQueue &&
        interaction?.blockingReasonCode == 'waiting_sequence',
    contractSynchronized: contractSynchronized,
    blockingReasonCode: interaction?.blockingReasonCode ?? '',
    showBackendBlockingState: canManageQueue &&
        contractValid &&
        const {
          AdminQueueInteractionMode.freshStartBlocked,
          AdminQueueInteractionMode.requeuedWaiting,
          AdminQueueInteractionMode.waitingPreviousStage,
          AdminQueueInteractionMode.paused,
          AdminQueueInteractionMode.frozen,
        }.contains(interaction?.mode),
  );
}

ProductionMapNode? _rezkaNodeForStation({
  required ProductionMapDefinition map,
  required String station,
  String stageNodeId = '',
}) {
  final trimmedStation = station.trim();
  if (trimmedStation.isEmpty) {
    return null;
  }
  final preferredNodeId = stageNodeId.trim();
  if (preferredNodeId.isNotEmpty) {
    for (final node in map.nodes) {
      if (node.id.trim() == preferredNodeId &&
          node.kind == 'apparatus' &&
          productionMapNodeMatchesStation(
            node: node,
            station: trimmedStation,
          )) {
        return node;
      }
    }
  }
  for (final node in _linearProductionMapNodes(map)) {
    if (node.kind == 'apparatus' &&
        productionMapNodeMatchesStation(
          node: node,
          station: trimmedStation,
        )) {
      return node;
    }
  }
  return null;
}

List<String> _rezkaWipSplitInstructionLines({
  required ProductionMapDefinition map,
  required String station,
  required String stageNodeId,
  required List<int> outputKadrCounts,
  required AppLocalizations l10n,
}) {
  final node = _rezkaNodeForStation(
    map: map,
    station: station,
    stageNodeId: stageNodeId,
  );
  if (node == null) {
    return const [];
  }
  final authoritativeOutputs =
      outputKadrCounts.where((count) => count > 0).toList(growable: false);
  final groups = authoritativeOutputs.isNotEmpty
      ? authoritativeOutputs
      : node.rezkaFrameGroups
          .where((group) => group > 0)
          .toList(growable: false);
  if (groups.isNotEmpty) {
    final totalFrames = groups.fold<int>(0, (sum, group) => sum + group);
    return [
      l10n.productionText(
        'worker.split.summary',
        values: {'count': groups.length},
      ),
      for (var index = 0; index < groups.length; index++)
        l10n.productionText(
          'worker.split.part',
          values: {'index': index + 1, 'frames': groups[index]},
        ),
      if (totalFrames > 0)
        l10n.productionText(
          'worker.split.total',
          values: {'frames': totalFrames},
        ),
    ];
  }
  final kadrCount = node.rezkaKadrCount;
  if (kadrCount != null && kadrCount > 0) {
    final lines = <String>[
      l10n.productionText(
        'worker.split.rolls',
        values: {'frames': kadrCount},
      ),
      l10n.productionText('worker.split.qr'),
      l10n.productionText('worker.split.same'),
    ];
    final labelLength = node.rezkaLabelLength;
    if (labelLength != null && labelLength > 0) {
      lines.add(
        l10n.productionText(
          'worker.split.label_length',
          values: {'length': formatRawQuantity(labelLength)},
        ),
      );
    }
    return lines;
  }
  final lines = <String>[];
  final labelLength = node.rezkaLabelLength;
  if (labelLength != null && labelLength > 0) {
    lines.add(
      l10n.productionText(
        'worker.split.label_length',
        values: {'length': formatRawQuantity(labelLength)},
      ),
    );
  }
  return lines;
}

List<String> _rezkaMergeStateLines({
  required List<AdminRezkaInputLink> inputLineage,
  required List<AdminRezkaActivePartialRoll> activePartialRolls,
  required AppLocalizations l10n,
}) {
  // A single input is only the WIP selected by Start. Merge state becomes
  // real only after an explicit successful Merge adds another source.
  if (inputLineage.length < 2) {
    return const [];
  }
  final lineage = inputLineage.toList(growable: false)
    ..sort((left, right) => left.sequenceNo.compareTo(right.sequenceNo));
  var currentBatch = '';
  for (final link in lineage) {
    if (link.inUse) {
      currentBatch = link.inputBatchId;
      break;
    }
  }
  final sourceBatchIds = <String>{
    for (final roll in activePartialRolls) ...roll.sourceInputBatchIds,
  };
  return [
    if (currentBatch.isNotEmpty)
      l10n.productionText(
        'worker.merge_state.current',
        values: {'batch': currentBatch},
      ),
    if (lineage.isNotEmpty)
      l10n.productionText(
        'worker.merge_state.lineage',
        values: {
          'lineage': lineage.map((link) => link.inputBatchId).join(' → '),
        },
      ),
    if (activePartialRolls.isNotEmpty)
      l10n.productionText(
        'worker.merge_state.partial_rolls',
        values: {
          'rolls': activePartialRolls.length,
          'sources': sourceBatchIds.length,
        },
      ),
  ];
}
