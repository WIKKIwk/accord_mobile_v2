part of '../mobile_api.dart';

extension MobileApiAdminTraining on MobileApi {
  /// Creates the complete test-mode representation of a training material:
  /// order assignment, an inventory asset, and a state location in front of
  /// the selected apparatus.
  ///
  /// Production persistence is intentionally left to the production training
  /// contract. Failing explicitly here prevents a local-only assignment from
  /// being mistaken for a server-backed one.
  Future<AdminRawMaterialAssignment> adminLinkTrainingRawMaterial({
    required String orderId,
    required String apparatus,
    required String materialId,
    required String materialName,
    required int micron,
    required String barcode,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = apparatus.trim();
    final normalizedMaterialId = materialId.trim();
    final normalizedMaterialName = materialName.trim();
    final normalizedBarcode = barcode.trim().toUpperCase();
    if (normalizedOrderId.isEmpty ||
        normalizedApparatus.isEmpty ||
        normalizedMaterialName.isEmpty ||
        normalizedBarcode.isEmpty ||
        micron <= 0) {
      throw const MobileApiException(
        code: 'training_material_invalid',
        message: 'Order, aparat, homashyo va micronni to‘liq kiriting',
      );
    }
    if (!await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'training_material_test_mode_only',
        message: 'Training homashyosi hozircha faqat test rejimida ulanadi',
      );
    }

    final orderExists = _testModeProductionMaps.any(
      (saved) => saved.map.id.trim() == normalizedOrderId,
    );
    if (!orderExists) {
      throw const MobileApiException(
        code: 'training_order_not_found',
        message: 'Tanlangan training order topilmadi',
      );
    }
    final duplicate = _testModeRawMaterialAssignments.any(
      (assignment) =>
          assignment.barcode.trim().toUpperCase() == normalizedBarcode,
    );
    if (duplicate) {
      throw const MobileApiException(
        code: 'training_material_barcode_exists',
        message: 'Bu training QR kodi allaqachon ishlatilgan',
      );
    }

    final displayName = '$normalizedMaterialName / $micron mikron';
    final itemCode = normalizedMaterialId.isEmpty
        ? 'TRAINING-MATERIAL'
        : normalizedMaterialId;
    final locationId =
        'training-apparatus:${_trainingStorageKey(normalizedApparatus)}';
    final locationName = 'Training: $normalizedApparatus';
    final locationReference = InventoryLocationReference(
      id: locationId,
      kind: InventoryLocationKind.state,
      name: locationName,
    );
    _upsertTrainingApparatusLocation(
      locationId: locationId,
      locationName: locationName,
      apparatus: normalizedApparatus,
    );

    final assignment = AdminRawMaterialAssignment(
      orderId: normalizedOrderId,
      apparatus: normalizedApparatus,
      barcode: normalizedBarcode,
      itemCode: itemCode,
      itemName: displayName,
      itemGroup: normalizedMaterialName,
      assignedByRef: AppSession.instance.profile?.ref ?? '',
      assignedByName: AppSession.instance.profile?.displayName ?? '',
      assignedAt: DateTime.now().toUtc().toIso8601String(),
      stockStatus: 'available',
      stockWarehouse: 'Training',
      stockQty: 1,
      stockUom: 'kg',
      remainingQty: 1,
    );
    _testModeRawMaterialAssignments.add(assignment);
    _testModeInventoryAssets.add(
      InventoryAsset(
        kind: InventoryAssetKind.rawMaterial,
        assetRef: 'training-raw-material:$normalizedBarcode',
        custodyWarehouseId: 'training',
        custodyWarehouse: 'Training',
        itemCode: itemCode,
        itemName: displayName,
        identifier: normalizedBarcode,
        qty: 1,
        uom: 'kg',
        status: 'available',
        physicalLocation: locationReference,
      ),
    );
    return assignment;
  }
}

void _upsertTrainingApparatusLocation({
  required String locationId,
  required String locationName,
  required String apparatus,
}) {
  final index = _testModeInventoryLocations.indexWhere(
    (location) => location.id == locationId,
  );
  if (index < 0) {
    _testModeInventoryLocations.add(
      InventoryLocation(
        id: locationId,
        kind: InventoryLocationKind.state,
        name: locationName,
        apparatus: [
          InventoryLocationApparatus(
            id: 'training-apparatus:${_trainingStorageKey(apparatus)}',
            name: apparatus,
          ),
        ],
      ),
    );
    return;
  }
  final current = _testModeInventoryLocations[index];
  final hasApparatus = current.apparatus.any(
    (linked) => productionMapWarehouseTitlesMatch(linked.name, apparatus),
  );
  if (hasApparatus) {
    return;
  }
  _testModeInventoryLocations[index] = InventoryLocation(
    id: current.id,
    kind: current.kind,
    name: current.name,
    warehouseId: current.warehouseId,
    factoryLocationId: current.factoryLocationId,
    active: current.active,
    apparatus: [
      ...current.apparatus,
      InventoryLocationApparatus(
        id: 'training-apparatus:${_trainingStorageKey(apparatus)}',
        name: apparatus,
      ),
    ],
  );
}

String _trainingStorageKey(String value) {
  final normalized =
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return normalized.replaceAll(RegExp(r'^-+|-+$'), '');
}
