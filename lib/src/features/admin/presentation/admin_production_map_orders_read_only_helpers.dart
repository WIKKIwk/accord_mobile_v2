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

_ReadOnlyOrderDetailUiState _readOnlyOrderDetailUiState({
  required ProductionMapSaved order,
  required AdminWarehouse? apparatus,
  required Map<String, String> queueStates,
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
  final sequence =
      sequenceOrderIds.isNotEmpty ? sequenceOrderIds : visibleOrderIds;
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
    showStart: isActionable && queueState == ApparatusQueueOrderState.pending,
    showPause:
        isActionable && queueState == ApparatusQueueOrderState.inProgress,
    showComplete:
        isActionable && queueState == ApparatusQueueOrderState.inProgress,
    showResume: isActionable && queueState == ApparatusQueueOrderState.paused,
    showWaitingForPrevious: false,
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
