import '../../../../core/api/mobile_api.dart';
import '../../../admin/models/production_map_models.dart';
import '../../../shared/models/inventory_movement_models.dart';

class RawMaterialListAssignment {
  const RawMaterialListAssignment({
    required this.orderId,
    required this.orderLabel,
    this.orderControl = AdminOrderControlState.active,
  });

  final String orderId;
  final String orderLabel;
  final AdminOrderControlState orderControl;

  bool get isFrozen => orderControl == AdminOrderControlState.frozen;
}

Map<String, RawMaterialListAssignment> rawMaterialListAssignmentsByBarcode({
  required List<AdminRawMaterialAssignment> assignments,
  required List<ProductionMapSaved> orders,
  Map<String, AdminOrderControlState> orderControlsByOrderId = const {},
}) {
  final ordersById = <String, ProductionMapSaved>{
    for (final order in orders) order.map.id.trim().toLowerCase(): order,
  };
  final normalizedOrderControls = <String, AdminOrderControlState>{
    for (final entry in orderControlsByOrderId.entries)
      if (entry.key.trim().isNotEmpty)
        entry.key.trim().toLowerCase(): entry.value,
  };
  return <String, RawMaterialListAssignment>{
    for (final assignment in assignments)
      if (assignment.barcode.trim().isNotEmpty)
        assignment.barcode.trim().toUpperCase(): RawMaterialListAssignment(
          orderId: assignment.orderId.trim(),
          orderLabel: _rawMaterialOrderLabel(
            ordersById[assignment.orderId.trim().toLowerCase()],
            assignment.orderId,
          ),
          orderControl: normalizedOrderControls[
                  assignment.orderId.trim().toLowerCase()] ??
              AdminOrderControlState.active,
        ),
  };
}

String rawMaterialAssetBarcode(InventoryAsset asset) {
  final identifier = asset.identifier.trim();
  if (identifier.isNotEmpty) {
    return identifier.toUpperCase();
  }
  final assetRef = asset.assetRef.trim();
  final separator = assetRef.indexOf(':');
  final barcode = separator < 0 ? assetRef : assetRef.substring(separator + 1);
  return barcode.trim().toUpperCase();
}

String _rawMaterialOrderLabel(ProductionMapSaved? order, String fallbackId) {
  if (order == null) {
    return fallbackId.trim();
  }
  final map = order.map;
  final code = map.code.trim().isNotEmpty
      ? map.code.trim()
      : map.orderNumber.trim().isNotEmpty
          ? map.orderNumber.trim()
          : map.id.trim();
  final title = map.title.trim();
  return title.isEmpty ? code : '$code · $title';
}
