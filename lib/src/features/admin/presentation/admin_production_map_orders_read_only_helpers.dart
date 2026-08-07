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
    if (productionMapQueueApparatusTitlesMatch(entry.key, station)) {
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
  final usableAction =
      action == 'pause' || action == 'roll_complete' || action == 'complete';
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
  final wipStatus = batch.wipStatus.trim().toLowerCase();
  return wipStatus.isEmpty || wipStatus == 'waiting';
}

bool _laminatsiyaMaterialScanCanBeSkippedForWip({
  required String station,
  required String? previousStage,
  required List<AdminProgressBatch> inputProgressBatches,
}) {
  if (!productionMapIsLaminatsiyaApparatus(station) || previousStage == null) {
    return false;
  }
  return inputProgressBatches.any((batch) {
    final nextApparatus = batch.nextApparatus.trim();
    final wipStatus = batch.wipStatus.trim().toLowerCase();
    if (wipStatus != 'waiting' &&
        wipStatus != 'in_use' &&
        wipStatus != 'processed') {
      return false;
    }
    if (!productionMapWarehouseTitlesMatch(batch.apparatus, previousStage) ||
        (nextApparatus.isNotEmpty &&
            !productionMapNextStageTitleMatchesApparatus(
              nextApparatus,
              station,
            ))) {
      return false;
    }
    if (wipStatus == 'waiting') {
      return true;
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
  required String action,
  required String qrPayload,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  final explicitQrPayload = qrPayload.trim();
  if (explicitQrPayload.isNotEmpty) {
    return explicitQrPayload;
  }
  return action == 'start' ? (startInputProgressBatch?.qrPayload ?? '') : '';
}

String _queueActionProgressBatchId({
  required String action,
  required String progressBatchId,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  final explicitProgressBatchId = progressBatchId.trim();
  if (explicitProgressBatchId.isNotEmpty) {
    return explicitProgressBatchId;
  }
  return action == 'start' ? (startInputProgressBatch?.batchId ?? '') : '';
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
    uom: uom,
    qrPayload: _queueActionQrPayload(
      action: action,
      qrPayload: qrPayload,
      startInputProgressBatch: prepared.startInputProgressBatch,
    ),
    progressBatchId: _queueActionProgressBatchId(
      action: action,
      progressBatchId: progressBatchId,
      startInputProgressBatch: prepared.startInputProgressBatch,
    ),
    customerName: customerName.trim(),
    driverUrl: driverUrl,
    printTransport: printTransport,
    printer: printer,
    printMode: printMode,
    completionRequestNote: completionRequestNote,
    returnedPaintItems: progressInput?.returnedPaintItems ?? const [],
    returnedPaintImageId: progressInput?.returnedPaintImageId ?? '',
    fullCompletionReportRequired:
        progressInput?.fullCompletionReportRequired ?? false,
    workerHandoff: workerHandoff,
    removeRollFromApparatus: removeRollFromApparatus,
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
  final inputProgressBatch = startInputProgressBatch;
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
  required List<AdminRawMaterialAssignment> materialAssignments,
  required List<AdminRawMaterialAssignment> startMaterialAssignments,
  required List<AdminRawMaterialAssignment> intakeCandidateAssignments,
  required AdminRawMaterialStartRequirements? materialRequirements,
  required Set<String> scannedMaterialBarcodes,
  required bool canManageQueue,
  required AdminApparatusQueueOrderActionControl? queueActionControl,
  required AdminProgressBatch? startInputProgressBatch,
  required bool skipStartMaterialScan,
}) {
  final map = order.map;
  final orderId = map.id.trim();
  final station = apparatus?.name.trim() ?? '';
  final queueState = apparatusQueueOrderStateFromRaw(
    queueActionControl?.state,
  );
  final previousStageValue = queueActionControl?.previousStage.trim() ?? '';
  final previousStage = previousStageValue.isEmpty ? null : previousStageValue;
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
  final previousStageReady = queueActionControl?.previousStageReady ?? false;
  final previousProgressRequired = previousStage != null;
  final acceptedPreviousWip = previousProgressRequired &&
      startInputProgressBatch != null &&
      _progressBatchCanBeScanned(startInputProgressBatch) &&
      _progressBatchMatchesPreviousStage(
        batch: startInputProgressBatch,
        orderId: orderId,
        previousStage: previousStage,
      ) &&
      _progressBatchCanFeedStation(
        batch: startInputProgressBatch,
        station: station,
      );
  final previousStageStartReady =
      !previousProgressRequired || previousStageReady || acceptedPreviousWip;
  final showStart = canManageQueue &&
      queueActionControl?.allows('start') == true &&
      queueState == ApparatusQueueOrderState.pending &&
      previousStageStartReady;
  final showPause = canManageQueue &&
      queueActionControl?.allows('pause') == true &&
      queueState == ApparatusQueueOrderState.inProgress;
  final showRollComplete = canManageQueue &&
      queueActionControl?.allows('roll_complete') == true &&
      queueState == ApparatusQueueOrderState.inProgress;
  final showComplete = canManageQueue &&
      queueActionControl?.allows('complete') == true &&
      queueState == ApparatusQueueOrderState.inProgress;
  final showResume = canManageQueue &&
      queueActionControl?.allows('resume') == true &&
      queueState == ApparatusQueueOrderState.paused;
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
    previousProgressReady: !previousProgressRequired || acceptedPreviousWip,
    showStart: showStart,
    showPause: showPause,
    showRollComplete: showRollComplete,
    showComplete: showComplete,
    showResume: showResume,
    showWaitingForPrevious: canManageQueue &&
        previousStage != null &&
        !previousStageStartReady &&
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
            (productionMapIsRezkaApparatus(node.title) ||
                productionMapIsRezkaApparatus(node.alternativeAssignedTitle)),
      )
      .toList(growable: false);
  for (final node in rezkaNodes) {
    if (_rezkaNodeMatchesStation(node, trimmedStation)) {
      return node;
    }
  }
  return rezkaNodes.isEmpty ? null : rezkaNodes.first;
}

bool _rezkaNodeMatchesStation(ProductionMapNode node, String station) {
  return productionMapWarehouseTitlesMatch(node.title, station) ||
      (node.alternativeAssignedTitle.trim().isNotEmpty &&
          productionMapWarehouseTitlesMatch(
            node.alternativeAssignedTitle,
            station,
          ));
}

List<String> _rezkaWipSplitInstructionLines({
  required ProductionMapDefinition map,
  required String station,
}) {
  final node = _rezkaNodeForStation(map: map, station: station);
  if (node == null) {
    return const [];
  }
  final kadrCount = node.rezkaKadrCount;
  if (kadrCount != null && kadrCount > 0) {
    final lines = <String>[
      'Rulon $kadrCount ta alohida WIP ga bo‘linadi',
      'Har bir WIP uchun alohida QR chiqadi',
      'Har bir WIPning metraj va kg miqdori bir xil bo‘ladi',
    ];
    final labelLength = node.rezkaLabelLength;
    if (labelLength != null && labelLength > 0) {
      lines.add('Etiketka uzunligi: ${formatRawQuantity(labelLength)} mm');
    }
    return lines;
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
  final labelLength = node.rezkaLabelLength;
  if (labelLength != null && labelLength > 0) {
    lines.add('Etiketka uzunligi: ${formatRawQuantity(labelLength)} mm');
  }
  return lines;
}
