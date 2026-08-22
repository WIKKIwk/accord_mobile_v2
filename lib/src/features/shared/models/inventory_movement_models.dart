import 'app_models.dart';

enum InventoryAssetKind {
  rawMaterial,
  finishedGoods,
  qolip;

  String get apiValue => switch (this) {
        InventoryAssetKind.rawMaterial => 'raw_material',
        InventoryAssetKind.finishedGoods => 'finished_goods',
        InventoryAssetKind.qolip => 'qolip',
      };

  static InventoryAssetKind fromJson(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'finished_goods' => InventoryAssetKind.finishedGoods,
      'qolip' => InventoryAssetKind.qolip,
      _ => InventoryAssetKind.rawMaterial,
    };
  }
}

enum InventoryLocationKind {
  warehouse,
  state,
  transit;

  static InventoryLocationKind fromJson(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'state' => InventoryLocationKind.state,
      'transit' => InventoryLocationKind.transit,
      _ => InventoryLocationKind.warehouse,
    };
  }
}

enum InventoryTransferStatus {
  requested,
  approved,
  inTransit,
  received,
  rejected,
  cancelled;

  String get apiValue => switch (this) {
        InventoryTransferStatus.requested => 'requested',
        InventoryTransferStatus.approved => 'approved',
        InventoryTransferStatus.inTransit => 'in_transit',
        InventoryTransferStatus.received => 'received',
        InventoryTransferStatus.rejected => 'rejected',
        InventoryTransferStatus.cancelled => 'cancelled',
      };

  bool get isActive => switch (this) {
        InventoryTransferStatus.requested ||
        InventoryTransferStatus.approved ||
        InventoryTransferStatus.inTransit =>
          true,
        _ => false,
      };

  static InventoryTransferStatus fromJson(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'approved' => InventoryTransferStatus.approved,
      'in_transit' => InventoryTransferStatus.inTransit,
      'received' => InventoryTransferStatus.received,
      'rejected' => InventoryTransferStatus.rejected,
      'cancelled' => InventoryTransferStatus.cancelled,
      _ => InventoryTransferStatus.requested,
    };
  }
}

class InventoryLocationApparatus {
  const InventoryLocationApparatus({required this.id, required this.name});

  final String id;
  final String name;

  factory InventoryLocationApparatus.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    if (!canonicalApparatusIdIsValid(id)) {
      throw const FormatException(
        'Inventory location requires canonical apparatus ID',
      );
    }
    return InventoryLocationApparatus(
      id: id,
      name: json['name']?.toString() ?? '',
    );
  }
}

class InventoryLocation {
  const InventoryLocation({
    required this.id,
    required this.kind,
    required this.name,
    this.warehouseId = '',
    this.factoryLocationId = '',
    this.active = true,
    this.apparatus = const [],
  });

  final String id;
  final InventoryLocationKind kind;
  final String name;
  final String warehouseId;
  final String factoryLocationId;
  final bool active;
  final List<InventoryLocationApparatus> apparatus;

  bool get isWarehouse => kind == InventoryLocationKind.warehouse;
  bool get isState => kind == InventoryLocationKind.state;

  factory InventoryLocation.fromJson(Map<String, dynamic> json) {
    final apparatus = json['apparatus'];
    return InventoryLocation(
      id: json['id']?.toString() ?? '',
      kind: InventoryLocationKind.fromJson(json['kind']),
      name: json['name']?.toString() ?? '',
      warehouseId: json['warehouse_id']?.toString() ?? '',
      factoryLocationId: json['factory_location_id']?.toString() ?? '',
      active: json['active'] as bool? ?? true,
      apparatus: apparatus is List
          ? apparatus
              .whereType<Map>()
              .map(
                (item) => InventoryLocationApparatus.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class InventoryLocationReference {
  const InventoryLocationReference({
    required this.id,
    required this.kind,
    required this.name,
  });

  final String id;
  final InventoryLocationKind kind;
  final String name;

  factory InventoryLocationReference.fromJson(Map<String, dynamic> json) {
    return InventoryLocationReference(
      id: json['id']?.toString() ?? '',
      kind: InventoryLocationKind.fromJson(json['kind']),
      name: json['name']?.toString() ?? '',
    );
  }
}

class InventoryAsset {
  const InventoryAsset({
    required this.kind,
    required this.assetRef,
    required this.custodyWarehouseId,
    required this.custodyWarehouse,
    required this.itemCode,
    required this.itemName,
    required this.identifier,
    required this.qty,
    required this.uom,
    required this.status,
    required this.physicalLocation,
    this.transferId = '',
    this.placementVersion = 1,
  });

  final InventoryAssetKind kind;
  final String assetRef;
  final String custodyWarehouseId;
  final String custodyWarehouse;
  final String itemCode;
  final String itemName;
  final String identifier;
  final double qty;
  final String uom;
  final String status;
  final InventoryLocationReference physicalLocation;
  final String transferId;
  final int placementVersion;

  bool get isAvailable =>
      status.trim().toLowerCase() == 'available' && transferId.trim().isEmpty;

  factory InventoryAsset.fromJson(Map<String, dynamic> json) {
    final location = json['physical_location'];
    return InventoryAsset(
      kind: InventoryAssetKind.fromJson(json['kind']),
      assetRef: json['asset_ref']?.toString() ?? '',
      custodyWarehouseId: json['custody_warehouse_id']?.toString() ?? '',
      custodyWarehouse: json['custody_warehouse']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      physicalLocation: InventoryLocationReference.fromJson(
        location is Map ? location.cast<String, dynamic>() : const {},
      ),
      transferId: json['transfer_id']?.toString() ?? '',
      placementVersion: (json['placement_version'] as num?)?.toInt() ?? 1,
    );
  }

  InventoryAsset copyWith({
    String? custodyWarehouseId,
    String? custodyWarehouse,
    String? status,
    InventoryLocationReference? physicalLocation,
    String? transferId,
    int? placementVersion,
  }) {
    return InventoryAsset(
      kind: kind,
      assetRef: assetRef,
      custodyWarehouseId: custodyWarehouseId ?? this.custodyWarehouseId,
      custodyWarehouse: custodyWarehouse ?? this.custodyWarehouse,
      itemCode: itemCode,
      itemName: itemName,
      identifier: identifier,
      qty: qty,
      uom: uom,
      status: status ?? this.status,
      physicalLocation: physicalLocation ?? this.physicalLocation,
      transferId: transferId ?? this.transferId,
      placementVersion: placementVersion ?? this.placementVersion,
    );
  }
}

class InventoryTransferLine {
  const InventoryTransferLine({
    required this.assetKind,
    required this.assetRef,
    required this.itemCode,
    required this.itemName,
    required this.identifier,
    required this.qty,
    required this.uom,
    required this.sourcePhysicalLocationId,
  });

  final InventoryAssetKind assetKind;
  final String assetRef;
  final String itemCode;
  final String itemName;
  final String identifier;
  final double qty;
  final String uom;
  final String sourcePhysicalLocationId;

  factory InventoryTransferLine.fromJson(Map<String, dynamic> json) {
    return InventoryTransferLine(
      assetKind: InventoryAssetKind.fromJson(json['asset_kind']),
      assetRef: json['asset_ref']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      sourcePhysicalLocationId:
          json['source_physical_location_id']?.toString() ?? '',
    );
  }
}

class InventoryTransfer {
  const InventoryTransfer({
    required this.id,
    required this.sourceWarehouseId,
    required this.sourceWarehouse,
    required this.destinationWarehouseId,
    required this.destinationWarehouse,
    required this.status,
    required this.note,
    required this.requestedByName,
    required this.approvedByName,
    required this.dispatchedByName,
    required this.receivedByName,
    required this.rejectedByName,
    required this.cancelledByName,
    required this.createdAtUnix,
    required this.lines,
    this.approvedAtUnix,
    this.dispatchedAtUnix,
    this.receivedAtUnix,
    this.rejectedAtUnix,
    this.cancelledAtUnix,
  });

  final String id;
  final String sourceWarehouseId;
  final String sourceWarehouse;
  final String destinationWarehouseId;
  final String destinationWarehouse;
  final InventoryTransferStatus status;
  final String note;
  final String requestedByName;
  final String approvedByName;
  final String dispatchedByName;
  final String receivedByName;
  final String rejectedByName;
  final String cancelledByName;
  final int createdAtUnix;
  final int? approvedAtUnix;
  final int? dispatchedAtUnix;
  final int? receivedAtUnix;
  final int? rejectedAtUnix;
  final int? cancelledAtUnix;
  final List<InventoryTransferLine> lines;

  factory InventoryTransfer.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return InventoryTransfer(
      id: json['id']?.toString() ?? '',
      sourceWarehouseId: json['source_warehouse_id']?.toString() ?? '',
      sourceWarehouse: json['source_warehouse']?.toString() ?? '',
      destinationWarehouseId:
          json['destination_warehouse_id']?.toString() ?? '',
      destinationWarehouse: json['destination_warehouse']?.toString() ?? '',
      status: InventoryTransferStatus.fromJson(json['status']),
      note: json['note']?.toString() ?? '',
      requestedByName: json['requested_by_name']?.toString() ?? '',
      approvedByName: json['approved_by_name']?.toString() ?? '',
      dispatchedByName: json['dispatched_by_name']?.toString() ?? '',
      receivedByName: json['received_by_name']?.toString() ?? '',
      rejectedByName: json['rejected_by_name']?.toString() ?? '',
      cancelledByName: json['cancelled_by_name']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      approvedAtUnix: (json['approved_at_unix'] as num?)?.toInt(),
      dispatchedAtUnix: (json['dispatched_at_unix'] as num?)?.toInt(),
      receivedAtUnix: (json['received_at_unix'] as num?)?.toInt(),
      rejectedAtUnix: (json['rejected_at_unix'] as num?)?.toInt(),
      cancelledAtUnix: (json['cancelled_at_unix'] as num?)?.toInt(),
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map(
                (item) => InventoryTransferLine.fromJson(
                  item.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }

  InventoryTransfer copyWith({
    InventoryTransferStatus? status,
    String? approvedByName,
    String? dispatchedByName,
    String? receivedByName,
    String? rejectedByName,
    String? cancelledByName,
    int? approvedAtUnix,
    int? dispatchedAtUnix,
    int? receivedAtUnix,
    int? rejectedAtUnix,
    int? cancelledAtUnix,
  }) {
    return InventoryTransfer(
      id: id,
      sourceWarehouseId: sourceWarehouseId,
      sourceWarehouse: sourceWarehouse,
      destinationWarehouseId: destinationWarehouseId,
      destinationWarehouse: destinationWarehouse,
      status: status ?? this.status,
      note: note,
      requestedByName: requestedByName,
      approvedByName: approvedByName ?? this.approvedByName,
      dispatchedByName: dispatchedByName ?? this.dispatchedByName,
      receivedByName: receivedByName ?? this.receivedByName,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      cancelledByName: cancelledByName ?? this.cancelledByName,
      createdAtUnix: createdAtUnix,
      approvedAtUnix: approvedAtUnix ?? this.approvedAtUnix,
      dispatchedAtUnix: dispatchedAtUnix ?? this.dispatchedAtUnix,
      receivedAtUnix: receivedAtUnix ?? this.receivedAtUnix,
      rejectedAtUnix: rejectedAtUnix ?? this.rejectedAtUnix,
      cancelledAtUnix: cancelledAtUnix ?? this.cancelledAtUnix,
      lines: lines,
    );
  }
}
