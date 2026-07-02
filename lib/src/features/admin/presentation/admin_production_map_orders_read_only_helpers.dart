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

List<AdminRawMaterialAssignment> _stationMaterialAssignments({
  required List<AdminRawMaterialAssignment> assignments,
  required String orderId,
  required String station,
}) {
  final result = assignments.where((assignment) {
    if (assignment.orderId.trim() != orderId) {
      return false;
    }
    if (station.isEmpty) {
      return true;
    }
    return productionMapWarehouseTitlesMatch(assignment.apparatus, station);
  }).toList();
  result.sort((left, right) {
    final leftTitle =
        left.itemName.trim().isEmpty ? left.itemCode : left.itemName;
    final rightTitle =
        right.itemName.trim().isEmpty ? right.itemCode : right.itemName;
    return leftTitle.toLowerCase().compareTo(rightTitle.toLowerCase());
  });
  return result;
}

bool _allMaterialsScanned({
  required List<AdminRawMaterialAssignment> assignments,
  required Set<String> scannedBarcodes,
  required String orderId,
}) {
  if (assignments.isEmpty) {
    return true;
  }
  return assignments.every(
    (assignment) => _materialAssignmentConfirmed(
      assignment: assignment,
      scannedBarcodes: scannedBarcodes,
      orderId: orderId,
    ),
  );
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

bool _materialScanCompleted({
  required List<AdminRawMaterialAssignment> assignments,
  required Set<String> scannedBarcodes,
  required String orderId,
}) {
  return _allMaterialsScanned(
    assignments: assignments,
    scannedBarcodes: scannedBarcodes,
    orderId: orderId,
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
      productionMapWarehouseTitlesMatch(nextApparatus, station);
}

bool _progressBatchCanBeScanned(AdminProgressBatch batch) {
  return batch.wipStatus.trim().toLowerCase() != 'processed';
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
}) {
  return action == 'start'
      ? assignments.map((item) => item.barcode).toList()
      : const [];
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
  required String completionRequestNote,
  required String qolipCode,
}) {
  return _ReadOnlyQueueActionRequest(
    apparatus: prepared.apparatus,
    order: order,
    action: action,
    materialBarcodes: _queueActionMaterialBarcodes(
      action: action,
      assignments: prepared.materialAssignments,
    ),
    qolipCode: qolipCode,
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
    completionRequestNote: completionRequestNote,
  );
}

bool _apparatusRequiresQolipScan(String apparatus) {
  return apparatus.trim().toLowerCase().contains('pechat');
}

String? _queueActionStartBlockReason({
  required String action,
  required List<AdminRawMaterialAssignment> materialAssignments,
  required Set<String> scannedMaterialBarcodes,
  required String orderId,
  required ProductionMapDefinition map,
  required String station,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  if (action != 'start') {
    return null;
  }
  if (materialAssignments.isNotEmpty &&
      !_allMaterialsScanned(
        assignments: materialAssignments,
        scannedBarcodes: scannedMaterialBarcodes,
        orderId: orderId,
      )) {
    return 'Avval hamma homashyoni QR scan qiling';
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

_PreparedReadOnlyQueueAction? _prepareReadOnlyQueueAction({
  required String action,
  required AdminWarehouse? apparatus,
  required _ReadOnlyQueueActionCallback? onQueueAction,
  required bool actionInFlight,
  required List<AdminRawMaterialAssignment> materialAssignments,
  required ProductionMapSaved order,
  required Set<String> scannedMaterialBarcodes,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  if (apparatus == null || onQueueAction == null || actionInFlight) {
    return null;
  }
  final orderId = order.map.id.trim();
  final station = apparatus.warehouse.trim();
  final stationMaterialAssignments = _stationMaterialAssignments(
    assignments: materialAssignments,
    orderId: orderId,
    station: station,
  );
  final inputProgressBatch = action == 'start' ? startInputProgressBatch : null;
  return _PreparedReadOnlyQueueAction(
    apparatus: apparatus,
    onQueueAction: onQueueAction,
    materialAssignments: stationMaterialAssignments,
    startInputProgressBatch: inputProgressBatch,
    blockReason: _queueActionStartBlockReason(
      action: action,
      materialAssignments: stationMaterialAssignments,
      scannedMaterialBarcodes: scannedMaterialBarcodes,
      orderId: orderId,
      map: order.map,
      station: station,
      startInputProgressBatch: inputProgressBatch,
    ),
  );
}

_ReadOnlyOrderDetailUiState _readOnlyOrderDetailUiState({
  required ProductionMapSaved order,
  required AdminWarehouse? apparatus,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required List<AdminRawMaterialAssignment> materialAssignments,
  required Set<String> scannedMaterialBarcodes,
  required bool canManageQueue,
  required List<String> sequenceOrderIds,
  required List<String> visibleOrderIds,
  required ApparatusQueuePolicy queuePolicy,
  required AdminProgressBatch? startInputProgressBatch,
}) {
  final map = order.map;
  final orderId = map.id.trim();
  final station = apparatus?.warehouse.trim() ?? '';
  final queueState = apparatusQueueOrderStateFromRaw(queueStates[orderId]);
  final stationMaterialAssignments = _stationMaterialAssignments(
    assignments: materialAssignments,
    orderId: orderId,
    station: station,
  );
  final allMaterialsScanned = _allMaterialsScanned(
    assignments: stationMaterialAssignments,
    scannedBarcodes: scannedMaterialBarcodes,
    orderId: orderId,
  );
  final confirmedMaterialBarcodes = _confirmedMaterialBarcodes(
    assignments: stationMaterialAssignments,
    scannedBarcodes: scannedMaterialBarcodes,
    orderId: orderId,
  );
  final previousStage = station.isEmpty
      ? null
      : productionMapPreviousWorkStageStation(map: map, station: station);
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
  final actionableId = canManageQueue
      ? firstActionableQueueOrderId(
          sequence: sequence,
          states: queueStates,
          visibleOrderIds: visibleOrderIds,
        )
      : null;
  final activeOrderId = canManageQueue
      ? firstInProgressQueueOrderId(
          sequence: sequence,
          states: queueStates,
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
    confirmedMaterialBarcodes: confirmedMaterialBarcodes,
    hasMaterialAssignments: stationMaterialAssignments.isNotEmpty,
    allMaterialsScanned: allMaterialsScanned,
    previousStage: previousStage,
    previousProgressRequired: previousProgressRequired,
    previousProgressReady:
        !previousProgressRequired || startInputProgressBatch != null,
    showStart: isActionable &&
        previousStageReady &&
        queueState == ApparatusQueueOrderState.pending,
    showPause:
        isActionable && queueState == ApparatusQueueOrderState.inProgress,
    showComplete:
        isActionable && queueState == ApparatusQueueOrderState.inProgress,
    showResume: isActionable && queueState == ApparatusQueueOrderState.paused,
    showWaitingForPrevious: canManageQueue &&
        previousStage != null &&
        !previousStageReady &&
        queueState == ApparatusQueueOrderState.pending,
  );
}

String _productTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return map.title;
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
