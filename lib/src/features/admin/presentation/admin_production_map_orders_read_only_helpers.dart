part of 'admin_production_map_orders_screen.dart';

Map<String, String> _queueStatesForStation(
  String station,
  Map<String, Map<String, String>> queueStatesByApparatus,
) {
  final direct = queueStatesByApparatus[station];
  if (direct != null) {
    return direct;
  }
  for (final entry in queueStatesByApparatus.entries) {
    if (productionMapWarehouseTitlesMatch(entry.key, station)) {
      return entry.value;
    }
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

String _rawMaterialAssignmentStatusText(AdminRawMaterialAssignment assignment) {
  if (_rawMaterialAssignmentIsConsumed(assignment)) {
    return 'Sarf qilingan';
  }
  return switch (assignment.stockStatus.trim().toLowerCase()) {
    'in_use' => 'Ishlatilmoqda',
    'available' || '' => '',
    _ => 'Band',
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

Future<_MaterialScanResult?> _scanMaterialAssignmentFromDialog({
  required BuildContext context,
  required List<AdminRawMaterialAssignment> assignments,
}) async {
  final barcode = await showRawMaterialScanDialog(context);
  if (barcode == null || barcode.trim().isEmpty) {
    return null;
  }
  return _MaterialScanResult(
    assignment: _materialAssignmentForScannedBarcode(
      assignments: assignments,
      barcode: barcode,
    ),
  );
}

bool _progressBatchMatchesPreviousStage({
  required AdminProgressBatch batch,
  required String orderId,
  required String previousStage,
}) {
  final action = batch.action.trim().toLowerCase();
  final status = batch.status.trim().toLowerCase();
  final matchesOrder = batch.orderId.trim() == orderId;
  final matchesStage = productionMapWarehouseTitlesMatch(
    batch.apparatus,
    previousStage,
  );
  final usableAction = action == 'pause' || action == 'complete';
  final usableStatus =
      status == 'paused' || status == 'completed' || status == 'resumed';
  return matchesOrder && matchesStage && usableAction && usableStatus;
}

bool _progressBatchCanFeedStation({
  required AdminProgressBatch batch,
  required String station,
}) {
  final nextApparatus = batch.nextApparatus.trim();
  return nextApparatus.isEmpty ||
      productionMapNextStageTitleMatchesApparatus(nextApparatus, station);
}

bool _progressBatchCanBeScanned(AdminProgressBatch batch) {
  return batch.wipStatus.trim().toLowerCase() != 'processed';
}

bool _laminatsiyaMaterialScanCanBeSkippedForWip({
  required String station,
  required String? previousStage,
  required List<AdminProgressBatch> inputProgressBatches,
}) {
  if (!productionMapIsLaminatsiyaApparatus(station) ||
      previousStage == null) {
    return false;
  }
  return inputProgressBatches.any((batch) {
    final nextApparatus = batch.nextApparatus.trim();
    if (batch.wipStatus.trim().toLowerCase() != 'processed' ||
        !productionMapWarehouseTitlesMatch(batch.apparatus, previousStage) ||
        (nextApparatus.isNotEmpty &&
            !productionMapNextStageTitleMatchesApparatus(
              nextApparatus,
              station,
            ))) {
      return false;
    }
    final processedBy = batch.processedByApparatus.trim().isEmpty
        ? batch.currentApparatus
        : batch.processedByApparatus;
    return productionMapWarehouseTitlesMatch(processedBy, station);
  });
}

bool _laminatsiyaMaterialGateBypassed({
  required String station,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required bool skipStartMaterialScan,
}) {
  if (skipStartMaterialScan) {
    return true;
  }
  return productionMapIsLaminatsiyaApparatus(station) &&
      materialRequirements != null &&
      materialRequirements.normalizedAssignedBarcodes.isEmpty;
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
    if ((sameBatch || sameQr) && _progressBatchCanBeScanned(item)) {
      return item;
    }
  }
  return null;
}

Future<AdminProgressBatch?> _scanProgressBatchFromQrDialog(
  BuildContext context,
) async {
  final raw = await showRawMaterialScanDialog(
    context,
    title: 'Progress QR',
    manualLabel: 'EPC',
  );
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return MobileApi.instance
      .adminProgressQrLookup(rawMaterialBarcodeFromQr(raw));
}

String _progressQrLookupErrorText(Object error) {
  return error is MobileApiException
      ? error.message
      : 'Progress QR tekshirilmadi';
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
  required String qrPayload,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  return qrPayload.trim().isEmpty
      ? (startInputProgressBatch?.qrPayload ?? '')
      : qrPayload;
}

String _queueActionProgressBatchId({
  required String progressBatchId,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  return progressBatchId.trim().isEmpty
      ? (startInputProgressBatch?.batchId ?? '')
      : progressBatchId;
}

bool _queueActionShouldClearStartInputProgress({
  required String action,
  required AdminApparatusQueueActionResult? result,
}) {
  return action == 'start' && result != null;
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
  required String driverUrl,
  required PrintTransport printTransport,
  required String printer,
  required String printMode,
  required String completionRequestNote,
  required List<String> qolipCodes,
  String freezeRequestId = '',
}) {
  return _ReadOnlyQueueActionRequest(
    apparatus: prepared.apparatus,
    order: order,
    action: action,
    materialBarcodes: prepared.bypassStartMaterialScan && action == 'start'
        ? const []
        : _queueActionMaterialBarcodes(
            action: action,
            assignments: prepared.materialAssignments,
            scannedBarcodes: prepared.scannedMaterialBarcodes,
          ),
    qolipCodes: qolipCodes,
    producedQty: progressInput?.meterQty,
    grossQty: progressInput?.kgQty,
    returnInkKg: progressInput?.returnInkKg,
    laminationPrintLeftoverRolls: progressInput?.laminationPrintLeftoverRolls,
    laminationFilmLeftoverRolls: progressInput?.laminationFilmLeftoverRolls,
    rezkaBosmaWaste: progressInput?.rezkaBosmaWaste,
    rezkaLaminationWaste: progressInput?.rezkaLaminationWaste,
    rezkaEdgeWaste: progressInput?.rezkaEdgeWaste,
    totalWaste: progressInput?.totalWaste,
    finishedGoodsKg: progressInput?.finishedGoodsKg,
    finishedGoodsMeter: progressInput?.finishedGoodsMeter,
    uom: uom,
    qrPayload: _queueActionQrPayload(
      qrPayload: qrPayload,
      startInputProgressBatch: prepared.startInputProgressBatch,
    ),
    progressBatchId: _queueActionProgressBatchId(
      progressBatchId: progressBatchId,
      startInputProgressBatch: prepared.startInputProgressBatch,
    ),
    driverUrl: driverUrl,
    printTransport: printTransport,
    printer: printer,
    printMode: printMode,
    completionRequestNote: completionRequestNote,
    returnedPaintItems: progressInput?.returnedPaintItems ?? const [],
    returnedPaintImageId: progressInput?.returnedPaintImageId ?? '',
    freezeRequestId: freezeRequestId,
  );
}

bool _apparatusRequiresQolipScan(String apparatus) {
  return productionMapApparatusRequiresQolipScan(apparatus);
}

String? _queueActionStartBlockReason({
  required String action,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required bool materialsLoading,
  required String materialsError,
  required ProductionMapDefinition map,
  required String station,
  required AdminProgressBatch? startInputProgressBatch,
  required bool qolipScanRequired,
  required bool qolipScanned,
  required bool skipStartMaterialScan,
}) {
  if (action != 'start') {
    return null;
  }
  final bypassMaterialGate = _laminatsiyaMaterialGateBypassed(
    station: station,
    materialRequirements: materialRequirements,
    skipStartMaterialScan: skipStartMaterialScan,
  );
  if (!bypassMaterialGate) {
    if (materialsLoading) {
      return 'Homashyo qoidasi yuklanmoqda';
    }
    if (materialsError.trim().isNotEmpty || materialRequirements == null) {
      return materialsError.trim().isEmpty
          ? 'Homashyo qoidasi yuklanmadi'
          : materialsError.trim();
    }
    if (materialRequirements.requiresMaterial &&
        materialRequirements.normalizedAssignedBarcodes.isEmpty) {
      return 'Ish boshlash uchun homashyo biriktirilmagan';
    }
    if (!materialRequirements.assignmentsSatisfied) {
      return 'Majburiy homashyo guruhlari to‘liq biriktirilmagan';
    }
    if (materialRequirements.policy == AdminRawMaterialStartPolicy.stateAll &&
        materialRequirements.normalizedAssignedBarcodes.isNotEmpty &&
        materialRequirements.normalizedStagedBarcodes.isEmpty) {
      return 'Apparat oldiga homashyo olib kelinmagan';
    }
    if (materialRequirements.normalizedAssignedBarcodes.isNotEmpty &&
        !materialRequirements.scanSatisfied) {
      return materialRequirements.policy == AdminRawMaterialStartPolicy.stateAll
          ? 'Avval state’dagi barcha homashyolarni QR scan qiling'
          : 'Avval har bir majburiy guruhdan minimum homashyo QR scan qiling';
    }
  }
  if (qolipScanRequired && !qolipScanned) {
    return 'Avval qolip QR scan qiling';
  }
  final previousStage = station.isEmpty
      ? null
      : productionMapPreviousWorkStageStation(map: map, station: station);
  if (previousStage != null && startInputProgressBatch == null) {
    return 'Oldingi bosqich QR sini scan qiling';
  }
  return null;
}

String _readOnlyQueueActionErrorText(Object error) {
  return error is MobileApiException ? error.message : 'Amal bajarilmadi';
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
  required ProductionMapSaved order,
  required Set<String> scannedMaterialBarcodes,
  required AdminProgressBatch? startInputProgressBatch,
  required bool qolipScanned,
  required bool skipStartMaterialScan,
}) {
  if (apparatus == null || onQueueAction == null || actionInFlight) {
    return null;
  }
  final station = apparatus.name.trim();
  final bypassMaterialGate = _laminatsiyaMaterialGateBypassed(
    station: station,
    materialRequirements: materialRequirements,
    skipStartMaterialScan: skipStartMaterialScan,
  );
  final stationMaterialAssignments =
      (materialRequirements == null || bypassMaterialGate)
      ? const <AdminRawMaterialAssignment>[]
      : materialAssignments;
  final inputProgressBatch = action == 'start' ? startInputProgressBatch : null;
  return _PreparedReadOnlyQueueAction(
    apparatus: apparatus,
    onQueueAction: onQueueAction,
    materialAssignments: stationMaterialAssignments,
    scannedMaterialBarcodes: Set<String>.unmodifiable(
      bypassMaterialGate ? const <String>{} : scannedMaterialBarcodes,
    ),
    startInputProgressBatch: inputProgressBatch,
    bypassStartMaterialScan: bypassMaterialGate,
    blockReason: _queueActionStartBlockReason(
      action: action,
      materialRequirements: materialRequirements,
      materialsLoading: materialsLoading,
      materialsError: materialsError,
      map: order.map,
      station: station,
      startInputProgressBatch: inputProgressBatch,
      qolipScanRequired: _apparatusRequiresQolipScan(station),
      qolipScanned: qolipScanned,
      skipStartMaterialScan: skipStartMaterialScan,
    ),
  );
}

_ReadOnlyOrderDetailUiState _readOnlyOrderDetailUiState({
  required ProductionMapSaved order,
  required AdminApparatus? apparatus,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required List<AdminRawMaterialAssignment> materialAssignments,
  required List<AdminRawMaterialAssignment> startMaterialAssignments,
  required List<AdminRawMaterialAssignment> intakeCandidateAssignments,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required Set<String> scannedMaterialBarcodes,
  required bool canManageQueue,
  required List<String> sequenceOrderIds,
  required List<String> visibleOrderIds,
  required ApparatusQueuePolicy queuePolicy,
  required AdminProgressBatch? startInputProgressBatch,
  required bool skipStartMaterialScan,
  required AdminOrderControlState orderControlState,
  required Map<String, AdminOrderControlState> orderControlsByOrderId,
}) {
  final map = order.map;
  final orderId = map.id.trim();
  final station = apparatus?.name.trim() ?? '';
  final queueState = apparatusQueueOrderStateFromRaw(queueStates[orderId]);
  final previousStage = station.isEmpty
      ? null
      : productionMapPreviousWorkStageStation(map: map, station: station);
  final bypassMaterialGate = _laminatsiyaMaterialGateBypassed(
    station: station,
    materialRequirements: materialRequirements,
    skipStartMaterialScan: skipStartMaterialScan,
  );
  final stationMaterialAssignments = materialRequirements == null
      ? const <AdminRawMaterialAssignment>[]
      : startMaterialAssignments;
  final confirmedMaterialBarcodes = _confirmedMaterialBarcodes(
    assignments: materialAssignments,
    scannedBarcodes: scannedMaterialBarcodes,
    orderId: orderId,
  );
  final allMaterialsScanned = bypassMaterialGate
      ? true
      : materialRequirements?.scanSatisfied ?? true;
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
  final previousStageReady = productionMapOrderReadyForStation(
    map: map,
    orderId: orderId,
    station: station,
    queueStatesByApparatus: queueStatesByApparatus,
  );
  final sequence = effectiveQueueSequence(
    sequence: sequenceOrderIds,
    visibleOrderIds: visibleOrderIds,
  );
  final effectiveQueueStates = Map<String, String>.from(queueStates)
    ..removeWhere(
      (id, _) => orderControlsByOrderId[id] == AdminOrderControlState.frozen,
    );
  final actionableId = canManageQueue
      ? firstActionableQueueOrderId(
          sequence: sequence,
          states: effectiveQueueStates,
          visibleOrderIds: visibleOrderIds,
        )
      : null;
  final activeOrderId = canManageQueue
      ? firstInProgressQueueOrderId(
          sequence: sequence,
          states: effectiveQueueStates,
          visibleOrderIds: visibleOrderIds,
        )
      : null;
  final freePick = queuePolicy == ApparatusQueuePolicy.freePick;
  final canStartWithPreviousProgress = previousStage != null &&
      previousStageReady &&
      queueState == ApparatusQueueOrderState.pending &&
      (activeOrderId == null || activeOrderId == orderId);
  final isActionable = canManageQueue &&
      (freePick
          ? activeOrderId == null || activeOrderId == orderId
          : actionableId == orderId || canStartWithPreviousProgress);
  final previousProgressRequired = previousStage != null;
  return _ReadOnlyOrderDetailUiState(
    orderId: orderId,
    station: station,
    materialAssignments: stationMaterialAssignments,
    intakeCandidateAssignments: intakeCandidateAssignments,
    assignedMaterialAssignments: materialAssignments,
    confirmedMaterialBarcodes: confirmedMaterialBarcodes,
    materialRequiredCount: materialRequiredCount,
    materialScannedCount: materialScannedCount,
    hasMaterialAssignments: bypassMaterialGate
        ? false
        : materialRequirements == null
            ? stationMaterialAssignments.isNotEmpty
            : materialRequirements.requiresMaterial ||
                materialRequirements.normalizedAssignedBarcodes.isNotEmpty,
    allMaterialsScanned: allMaterialsScanned,
    showStartMaterials: queueState == ApparatusQueueOrderState.pending &&
        materialRequirements != null,
    showIntakeCandidates: queueState == ApparatusQueueOrderState.inProgress ||
        queueState == ApparatusQueueOrderState.paused,
    previousStage: previousStage,
    previousProgressRequired: previousProgressRequired,
    previousProgressReady:
        !previousProgressRequired || startInputProgressBatch != null,
    showStart: isActionable &&
        previousStageReady &&
        queueState == ApparatusQueueOrderState.pending,
    showPause: isActionable &&
        queueState == ApparatusQueueOrderState.inProgress &&
        orderControlState != AdminOrderControlState.frozen,
    showComplete: isActionable &&
        queueState == ApparatusQueueOrderState.inProgress &&
        orderControlState == AdminOrderControlState.active,
    showResume: isActionable && queueState == ApparatusQueueOrderState.paused,
    showWaitingForPrevious: canManageQueue &&
        previousStage != null &&
        !previousStageReady &&
        queueState == ApparatusQueueOrderState.pending,
  );
}

ProductionMapNode? _rezkaNodeForStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  final trimmedStation = station.trim();
  if (trimmedStation.isEmpty ||
      !productionMapIsRezkaApparatus(trimmedStation)) {
    return null;
  }
  final rezkaNodes = _linearProductionMapNodes(map)
      .where(
        (node) =>
            node.kind == 'apparatus' &&
            productionMapIsRezkaApparatus(node.title),
      )
      .toList(growable: false);
  for (final node in rezkaNodes) {
    if (productionMapWarehouseTitlesMatch(node.title, trimmedStation)) {
      return node;
    }
  }
  return rezkaNodes.isEmpty ? null : rezkaNodes.first;
}

List<String> _rezkaWipSplitInstructionLines({
  required ProductionMapDefinition map,
  required String station,
}) {
  final node = _rezkaNodeForStation(map: map, station: station);
  if (node == null) {
    return const [];
  }
  final groups =
      node.rezkaFrameGroups.where((group) => group > 0).toList(growable: false);
  if (groups.isNotEmpty) {
    final totalFrames = groups.fold<int>(0, (sum, group) => sum + group);
    return [
      'WIP ${groups.length} bo‘lakka bo‘linadi',
      for (var index = 0; index < groups.length; index++)
        '${index + 1}-bo‘lak: ${groups[index]} kadr',
      if (totalFrames > 0) 'Jami: $totalFrames kadr',
    ];
  }
  final lines = <String>[];
  final kadrCount = node.rezkaKadrCount;
  if (kadrCount != null && kadrCount > 0) {
    lines.add('${formatRawQuantity(kadrCount.toDouble())} kadr bo‘yicha');
  }
  final labelLength = node.rezkaLabelLength;
  if (labelLength != null && labelLength > 0) {
    lines.add('Etiketka uzunligi: ${formatRawQuantity(labelLength)} mm');
  }
  return lines;
}
