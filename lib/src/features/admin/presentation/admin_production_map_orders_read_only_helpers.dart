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

String _productTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return map.title;
}
