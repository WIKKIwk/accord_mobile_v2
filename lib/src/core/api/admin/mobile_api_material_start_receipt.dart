part of '../mobile_api.dart';

class AdminMaterialDeliverer {
  const AdminMaterialDeliverer(
      {required this.role, required this.ref, required this.name});
  final String role;
  final String ref;
  final String name;

  factory AdminMaterialDeliverer.fromJson(Map<String, dynamic> json) =>
      AdminMaterialDeliverer(
        role: json['role']?.toString() ?? '',
        ref: json['ref']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
}

class AdminMaterialDeliveryCandidates {
  const AdminMaterialDeliveryCandidates(
      {required this.alreadyAtApparatus, required this.deliverers});
  final bool alreadyAtApparatus;
  final List<AdminMaterialDeliverer> deliverers;
}

extension MobileApiMaterialStartReceipt on MobileApi {
  Future<AdminMaterialDeliveryCandidates> adminMaterialStartDeliveryCandidates({
    required String orderId,
    required String apparatus,
    required String barcode,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final station = _requireCanonicalApparatusId(apparatus);
      final assignment = _testModeRawMaterialAssignments
          .where((value) =>
              value.orderId == orderId.trim() &&
              value.apparatus == station &&
              value.barcode.trim().toUpperCase() ==
                  barcode.trim().toUpperCase())
          .firstOrNull;
      final asset = _testModeInventoryAssets
          .where((value) =>
              value.kind == InventoryAssetKind.rawMaterial &&
              value.identifier.trim().toUpperCase() ==
                  barcode.trim().toUpperCase())
          .firstOrNull;
      if (assignment == null ||
          asset == null ||
          !asset.isAvailable ||
          asset.qty <= 0) {
        throw const MobileApiException(
            code: 'raw_material_stock_unavailable',
            message: 'Homashyo mavjud emas');
      }
      return AdminMaterialDeliveryCandidates(
        alreadyAtApparatus: _testModeRawMaterialAssetAtApparatus(
                barcode: barcode, apparatus: station) !=
            null,
        deliverers: [
          for (final user in _testModeWarehouseAssignments)
            if (user.warehouse.trim().toLowerCase() ==
                    asset.custodyWarehouse.trim().toLowerCase() &&
                const {
                  UserRole.werka,
                  UserRole.materialTaminotchi,
                  UserRole.qolipchi,
                  UserRole.aparatchi,
                }.contains(user.principalRole))
              AdminMaterialDeliverer(
                  role: _adminWarehouseRoleToJson(user.principalRole),
                  ref: user.principalRef,
                  name: user.displayName),
        ],
      );
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-start-receipt')
              .replace(queryParameters: {
            'order_id': orderId.trim(),
            'apparatus': _requireCanonicalApparatusId(apparatus),
            'barcode': barcode.trim(),
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'material_delivery_candidates');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminMaterialDeliveryCandidates(
      alreadyAtApparatus: json['already_at_apparatus'] == true,
      deliverers: [
        for (final user in (json['deliverers'] as List? ?? const []))
          AdminMaterialDeliverer.fromJson(
              (user as Map).cast<String, dynamic>()),
      ],
    );
  }

  Future<void> adminReceiveMaterialForStart({
    required String orderId,
    required String apparatus,
    required String barcode,
    required AdminMaterialDeliverer deliveredBy,
    required String idempotencyKey,
  }) async {
    final station = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      final candidates = await adminMaterialStartDeliveryCandidates(
          orderId: orderId, apparatus: station, barcode: barcode);
      if (!candidates.deliverers.any((value) =>
          value.role == deliveredBy.role && value.ref == deliveredBy.ref)) {
        throw const MobileApiException(
            code: 'material_deliverer_not_allowed',
            message: 'Xodimga ko‘chirish ruxsati berilmagan');
      }
      final destination = _testModeInventoryLocations
          .where((value) =>
              value.active &&
              value.isState &&
              value.apparatus.any((machine) => machine.id == station))
          .firstOrNull;
      final asset = _testModeInventoryAssets
          .where((value) =>
              value.identifier.trim().toUpperCase() ==
              barcode.trim().toUpperCase())
          .first;
      if (destination == null) {
        throw const MobileApiException(
            code: 'material_delivery_location_missing',
            message: 'Apparat oldidagi joy sozlanmagan');
      }
      await inventoryRelocate(
          assetKind: InventoryAssetKind.rawMaterial,
          assetRef: asset.assetRef,
          physicalLocationId: destination.id,
          idempotencyKey: idempotencyKey,
          note:
              'Olib keldi: ${deliveredBy.name}. Qabul qildi: ${AppSession.instance.profile?.displayName ?? ""}.');
      return;
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-start-receipt'),
          headers: _headers(requireToken()),
          body: jsonEncode({
            'order_id': orderId.trim(),
            'apparatus': station,
            'barcode': barcode.trim(),
            'delivered_by_role': deliveredBy.role,
            'delivered_by_ref': deliveredBy.ref,
            'idempotency_key': idempotencyKey,
          }),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'material_delivery_receipt');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['ok'] != true ||
        json['apparatus'] != station ||
        json['barcode']?.toString().toUpperCase() !=
            barcode.trim().toUpperCase()) {
      throw const MobileApiException(
          code: 'material_delivery_receipt_unconfirmed',
          message: 'Material delivery was not confirmed');
    }
  }
}
