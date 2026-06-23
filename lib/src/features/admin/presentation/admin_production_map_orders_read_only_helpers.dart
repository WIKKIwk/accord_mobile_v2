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

String _productTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return map.title;
}
