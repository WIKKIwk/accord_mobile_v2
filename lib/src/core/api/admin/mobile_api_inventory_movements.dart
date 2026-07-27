part of '../mobile_api.dart';

final List<InventoryLocation> _testModeInventoryLocations = [];
final List<InventoryAsset> _testModeInventoryAssets = [];
final List<InventoryTransfer> _testModeInventoryTransfers = [];
final Map<String, String> _testModeInventoryPlacementOwnerRefs = {};

String _inventoryAssetKey(InventoryAssetKind kind, String assetRef) =>
    '${kind.apiValue}:${assetRef.trim().toLowerCase()}';

void resetMobileApiInventoryMovementTestData() {
  _testModeInventoryLocations.clear();
  _testModeInventoryAssets.clear();
  _testModeInventoryTransfers.clear();
  _testModeInventoryPlacementOwnerRefs.clear();
}

void seedMobileApiInventoryMovementTestData({
  List<InventoryLocation> locations = const [],
  List<InventoryAsset> assets = const [],
  List<InventoryTransfer> transfers = const [],
}) {
  _testModeInventoryLocations
    ..clear()
    ..addAll(locations);
  _testModeInventoryAssets
    ..clear()
    ..addAll(assets);
  _testModeInventoryTransfers
    ..clear()
    ..addAll(transfers);
  _testModeInventoryPlacementOwnerRefs.clear();
}

extension MobileApiInventoryMovements on MobileApi {
  Future<List<InventoryLocation>> inventoryLocations() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<InventoryLocation>.unmodifiable(
        [..._testModeInventoryLocations]..sort((left, right) {
            final kind = left.kind.index.compareTo(right.kind.index);
            return kind != 0
                ? kind
                : left.name.toLowerCase().compareTo(right.name.toLowerCase());
          }),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/inventory/locations',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _inventoryApiException(
        response,
        fallbackCode: 'inventory_locations_load_failed',
        fallbackMessage: 'Joylashuvlar yuklanmadi',
      );
    }
    final payload = await decodeJsonListPayload(response.body);
    return payload
        .whereType<Map>()
        .map(
          (item) => InventoryLocation.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<List<InventoryAsset>> inventoryAssets({
    String warehouseId = '',
    String query = '',
    InventoryAssetKind? assetKind,
    bool currentUserStatesOnly = false,
    int limit = 100,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final needle = query.trim().toLowerCase();
      final warehouseLocationIds = _testModeInventoryLocations
          .where(
            (location) =>
                location.isWarehouse &&
                location.warehouseId == warehouseId.trim(),
          )
          .map((location) => location.id)
          .toSet();
      final currentProfileRef = AppSession.instance.profile?.ref.trim() ?? '';
      return _testModeInventoryAssets
          .where(
            (asset) =>
                (warehouseId.trim().isEmpty ||
                    (asset.physicalLocation.kind ==
                            InventoryLocationKind.warehouse &&
                        warehouseLocationIds.contains(
                          asset.physicalLocation.id,
                        ))) &&
                (!currentUserStatesOnly ||
                    (asset.physicalLocation.kind ==
                            InventoryLocationKind.state &&
                        currentProfileRef.isNotEmpty &&
                        _testModeInventoryPlacementOwnerRefs[_inventoryAssetKey(
                              asset.kind,
                              asset.assetRef,
                            )] ==
                            currentProfileRef)) &&
                (assetKind == null || asset.kind == assetKind) &&
                (needle.isEmpty ||
                    [
                      asset.itemCode,
                      asset.itemName,
                      asset.identifier,
                      asset.assetRef,
                    ].any((value) => value.toLowerCase().contains(needle))),
          )
          .skip(offset)
          .take(limit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/inventory/assets',
        ).replace(
          queryParameters: {
            if (warehouseId.trim().isNotEmpty)
              'warehouse_id': warehouseId.trim(),
            if (query.trim().isNotEmpty) 'query': query.trim(),
            if (assetKind != null) 'asset_kind': assetKind.apiValue,
            if (currentUserStatesOnly) 'current_user_states_only': 'true',
            'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _inventoryApiException(
        response,
        fallbackCode: 'inventory_assets_load_failed',
        fallbackMessage: 'Ombordagi mahsulotlar yuklanmadi',
      );
    }
    final payload = await decodeJsonListPayload(response.body);
    return payload
        .whereType<Map>()
        .map((item) => InventoryAsset.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<InventoryAsset> inventoryRelocate({
    required InventoryAssetKind assetKind,
    required String assetRef,
    required String physicalLocationId,
    required String idempotencyKey,
    String note = '',
  }) async {
    final normalizedRef = assetRef.trim();
    final normalizedLocationId = physicalLocationId.trim();
    final normalizedKey = idempotencyKey.trim();
    if (normalizedRef.isEmpty ||
        normalizedLocationId.isEmpty ||
        normalizedKey.isEmpty) {
      throw const MobileApiException(
        code: 'inventory_relocation_invalid',
        message: 'Mahsulot va joylashuvni tanlang',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final assetIndex = _testModeInventoryAssets.indexWhere(
        (asset) =>
            asset.kind == assetKind &&
            asset.assetRef.toLowerCase() == normalizedRef.toLowerCase(),
      );
      final location = _testModeInventoryLocations.where(
        (item) => item.id == normalizedLocationId && item.active,
      );
      if (assetIndex < 0 || location.isEmpty) {
        throw const MobileApiException(
          code: 'inventory_asset_or_location_not_found',
          message: 'Mahsulot yoki joylashuv topilmadi',
          statusCode: 404,
        );
      }
      final current = _testModeInventoryAssets[assetIndex];
      final destination = location.first;
      if (!current.isAvailable) {
        throw const MobileApiException(
          code: 'inventory_asset_unavailable',
          message: 'Mahsulot hozir ko‘chirish uchun mavjud emas',
          statusCode: 409,
        );
      }
      if (destination.isWarehouse &&
          destination.warehouseId != current.custodyWarehouseId) {
        throw const MobileApiException(
          code: 'inventory_cross_warehouse_requires_transfer',
          message: 'Boshqa omborga faqat transfer orqali yuboriladi',
          statusCode: 409,
        );
      }
      final updated = current.copyWith(
        physicalLocation: InventoryLocationReference(
          id: destination.id,
          kind: destination.kind,
          name: destination.name,
        ),
        placementVersion: current.placementVersion + 1,
      );
      _testModeInventoryAssets[assetIndex] = updated;
      _testModeInventoryPlacementOwnerRefs[
              _inventoryAssetKey(updated.kind, updated.assetRef)] =
          AppSession.instance.profile?.ref.trim() ?? '';
      return updated;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/inventory/relocations',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'asset_kind': assetKind.apiValue,
          'asset_ref': normalizedRef,
          'physical_location_id': normalizedLocationId,
          'idempotency_key': normalizedKey,
          if (note.trim().isNotEmpty) 'note': note.trim(),
        }),
      ),
    );
    return _decodeInventoryMutation<InventoryAsset>(
      response,
      InventoryAsset.fromJson,
      fallbackCode: 'inventory_relocation_failed',
      fallbackMessage: 'Joylashuv o‘zgartirilmadi',
    );
  }

  Future<List<InventoryTransfer>> inventoryTransfers({
    String direction = 'all',
    InventoryTransferStatus? status,
    int limit = 100,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final assigned = AppSession.instance.profile?.assignedWarehouses
              .map((item) => item.trim().toLowerCase())
              .toSet() ??
          const <String>{};
      return _testModeInventoryTransfers
          .where((transfer) {
            final incoming =
                assigned.contains(transfer.destinationWarehouse.toLowerCase());
            final outgoing =
                assigned.contains(transfer.sourceWarehouse.toLowerCase());
            final matchesDirection = switch (direction) {
              'incoming' => incoming,
              'outgoing' => outgoing,
              _ => incoming || outgoing,
            };
            return matchesDirection &&
                (status == null || transfer.status == status);
          })
          .skip(offset)
          .take(limit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/inventory/transfers',
        ).replace(
          queryParameters: {
            'direction': direction,
            if (status != null) 'status': status.apiValue,
            'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _inventoryApiException(
        response,
        fallbackCode: 'inventory_transfers_load_failed',
        fallbackMessage: 'Transferlar yuklanmadi',
      );
    }
    final payload = await decodeJsonListPayload(response.body);
    return payload
        .whereType<Map>()
        .map((item) => InventoryTransfer.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<InventoryTransfer> inventoryCreateTransfer({
    required String sourceWarehouseId,
    required String destinationWarehouseId,
    required List<InventoryAsset> assets,
    required String idempotencyKey,
    String note = '',
  }) async {
    if (sourceWarehouseId.trim().isEmpty ||
        destinationWarehouseId.trim().isEmpty ||
        sourceWarehouseId.trim() == destinationWarehouseId.trim() ||
        assets.isEmpty ||
        idempotencyKey.trim().isEmpty) {
      throw const MobileApiException(
        code: 'inventory_transfer_invalid',
        message: 'Manba, qabul qiluvchi va mahsulotni tanlang',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final source = _testModeInventoryLocations.where(
        (item) =>
            item.isWarehouse && item.warehouseId == sourceWarehouseId.trim(),
      );
      final destination = _testModeInventoryLocations.where(
        (item) =>
            item.isWarehouse &&
            item.warehouseId == destinationWarehouseId.trim(),
      );
      if (source.isEmpty || destination.isEmpty) {
        throw const MobileApiException(
          code: 'inventory_warehouse_not_found',
          message: 'Ombor topilmadi',
          statusCode: 404,
        );
      }
      final transferId =
          'inventory_transfer_${DateTime.now().microsecondsSinceEpoch}';
      final lines = <InventoryTransferLine>[];
      for (final requested in assets) {
        final index = _testModeInventoryAssets.indexWhere(
          (asset) =>
              asset.kind == requested.kind &&
              asset.assetRef == requested.assetRef &&
              asset.custodyWarehouseId == sourceWarehouseId.trim(),
        );
        if (index < 0 || !_testModeInventoryAssets[index].isAvailable) {
          throw const MobileApiException(
            code: 'inventory_asset_unavailable',
            message: 'Tanlangan mahsulot mavjud emas',
            statusCode: 409,
          );
        }
        final current = _testModeInventoryAssets[index];
        if (current.physicalLocation.kind != InventoryLocationKind.warehouse ||
            current.physicalLocation.id != source.first.id) {
          throw const MobileApiException(
            code: 'inventory_asset_not_in_source_warehouse',
            message: 'Mahsulotni transferdan oldin omborga qaytaring',
            statusCode: 409,
          );
        }
        lines.add(
          InventoryTransferLine(
            assetKind: current.kind,
            assetRef: current.assetRef,
            itemCode: current.itemCode,
            itemName: current.itemName,
            identifier: current.identifier,
            qty: current.qty,
            uom: current.uom,
            sourcePhysicalLocationId: current.physicalLocation.id,
          ),
        );
        _testModeInventoryAssets[index] = current.copyWith(
          status: 'transfer_reserved',
          transferId: transferId,
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final actorName = AppSession.instance.profile?.displayName ?? '';
      var transfer = InventoryTransfer(
        id: transferId,
        sourceWarehouseId: sourceWarehouseId.trim(),
        sourceWarehouse: source.first.name,
        destinationWarehouseId: destinationWarehouseId.trim(),
        destinationWarehouse: destination.first.name,
        status: InventoryTransferStatus.requested,
        note: note.trim(),
        requestedByName: actorName,
        approvedByName: '',
        dispatchedByName: '',
        receivedByName: '',
        rejectedByName: '',
        cancelledByName: '',
        createdAtUnix: now,
        lines: lines,
      );
      if (_testModeActorManagesTransferInternally(
        transfer.sourceWarehouse,
        transfer.destinationWarehouse,
      )) {
        transfer = transfer.copyWith(
          status: InventoryTransferStatus.received,
          approvedByName: actorName,
          dispatchedByName: actorName,
          receivedByName: actorName,
          approvedAtUnix: now,
          dispatchedAtUnix: now,
          receivedAtUnix: now,
        );
        _receiveTestModeTransferAssets(transfer);
      }
      _testModeInventoryTransfers.insert(0, transfer);
      return transfer;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/inventory/transfers',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'source_warehouse_id': sourceWarehouseId.trim(),
          'destination_warehouse_id': destinationWarehouseId.trim(),
          'assets': [
            for (final asset in assets)
              {
                'asset_kind': asset.kind.apiValue,
                'asset_ref': asset.assetRef,
              },
          ],
          'idempotency_key': idempotencyKey.trim(),
          if (note.trim().isNotEmpty) 'note': note.trim(),
        }),
      ),
    );
    return _decodeInventoryMutation<InventoryTransfer>(
      response,
      InventoryTransfer.fromJson,
      fallbackCode: 'inventory_transfer_create_failed',
      fallbackMessage: 'Transfer yaratilmadi',
    );
  }

  Future<InventoryTransfer> inventoryTransferAction({
    required String transferId,
    required String action,
    required String idempotencyKey,
    String note = '',
  }) async {
    final normalizedAction = action.trim().toLowerCase();
    const allowed = {'approve', 'reject', 'dispatch', 'receive', 'cancel'};
    if (transferId.trim().isEmpty ||
        !allowed.contains(normalizedAction) ||
        idempotencyKey.trim().isEmpty) {
      throw const MobileApiException(
        code: 'inventory_transfer_action_invalid',
        message: 'Transfer amali noto‘g‘ri',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeInventoryTransfers.indexWhere(
        (item) => item.id == transferId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'inventory_transfer_not_found',
          message: 'Transfer topilmadi',
          statusCode: 404,
        );
      }
      final current = _testModeInventoryTransfers[index];
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final actorName = AppSession.instance.profile?.displayName ?? '';
      final internalTransfer = _testModeActorManagesTransferInternally(
        current.sourceWarehouse,
        current.destinationWarehouse,
      );
      final updated = switch (normalizedAction) {
        'approve'
            when current.status == InventoryTransferStatus.requested &&
                internalTransfer =>
          current.copyWith(
            status: InventoryTransferStatus.received,
            approvedByName: actorName,
            dispatchedByName: actorName,
            receivedByName: actorName,
            approvedAtUnix: now,
            dispatchedAtUnix: now,
            receivedAtUnix: now,
          ),
        'approve' when current.status == InventoryTransferStatus.requested =>
          current.copyWith(
            status: InventoryTransferStatus.approved,
            approvedByName: actorName,
            approvedAtUnix: now,
          ),
        'reject' when current.status == InventoryTransferStatus.requested =>
          current.copyWith(
            status: InventoryTransferStatus.rejected,
            rejectedByName: actorName,
            rejectedAtUnix: now,
          ),
        'dispatch'
            when current.status == InventoryTransferStatus.approved &&
                internalTransfer =>
          current.copyWith(
            status: InventoryTransferStatus.received,
            dispatchedByName: actorName,
            receivedByName: actorName,
            dispatchedAtUnix: now,
            receivedAtUnix: now,
          ),
        'dispatch' when current.status == InventoryTransferStatus.approved =>
          current.copyWith(
            status: InventoryTransferStatus.inTransit,
            dispatchedByName: actorName,
            dispatchedAtUnix: now,
          ),
        'receive' when current.status == InventoryTransferStatus.inTransit =>
          current.copyWith(
            status: InventoryTransferStatus.received,
            receivedByName: actorName,
            receivedAtUnix: now,
          ),
        'cancel'
            when current.status == InventoryTransferStatus.requested ||
                current.status == InventoryTransferStatus.approved =>
          current.copyWith(
            status: InventoryTransferStatus.cancelled,
            cancelledByName: actorName,
            cancelledAtUnix: now,
          ),
        _ => throw const MobileApiException(
            code: 'inventory_transfer_transition_invalid',
            message: 'Transfer bu bosqichda o‘zgartirilmaydi',
            statusCode: 409,
          ),
      };
      _testModeInventoryTransfers[index] = updated;
      if (updated.status == InventoryTransferStatus.rejected ||
          updated.status == InventoryTransferStatus.cancelled) {
        _releaseTestModeTransferAssets(updated);
      } else if (updated.status == InventoryTransferStatus.inTransit) {
        _markTestModeTransferAssetsInTransit(updated);
      } else if (updated.status == InventoryTransferStatus.received) {
        _receiveTestModeTransferAssets(updated);
      }
      return updated;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/inventory/transfers/'
          '${Uri.encodeComponent(transferId.trim())}/'
          '${Uri.encodeComponent(normalizedAction)}',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'idempotency_key': idempotencyKey.trim(),
          if (note.trim().isNotEmpty) 'note': note.trim(),
        }),
      ),
    );
    return _decodeInventoryMutation<InventoryTransfer>(
      response,
      InventoryTransfer.fromJson,
      fallbackCode: 'inventory_transfer_action_failed',
      fallbackMessage: 'Transfer yangilanmadi',
    );
  }
}

bool _testModeActorManagesTransferInternally(
  String sourceWarehouse,
  String destinationWarehouse,
) {
  final assigned = AppSession.instance.profile?.assignedWarehouses
          .map((warehouse) => warehouse.trim().toLowerCase())
          .where((warehouse) => warehouse.isNotEmpty)
          .toSet() ??
      const <String>{};
  return assigned.contains(sourceWarehouse.trim().toLowerCase()) &&
      assigned.contains(destinationWarehouse.trim().toLowerCase());
}

T _decodeInventoryMutation<T>(
  http.Response response,
  T Function(Map<String, dynamic>) decode, {
  required String fallbackCode,
  required String fallbackMessage,
}) {
  if (response.statusCode != 200) {
    throw _inventoryApiException(
      response,
      fallbackCode: fallbackCode,
      fallbackMessage: fallbackMessage,
    );
  }
  final payload = jsonDecode(response.body);
  if (payload is! Map) {
    throw MobileApiException(
      code: fallbackCode,
      message: fallbackMessage,
      statusCode: response.statusCode,
    );
  }
  return decode(payload.cast<String, dynamic>());
}

MobileApiException _inventoryApiException(
  http.Response response, {
  required String fallbackCode,
  required String fallbackMessage,
}) {
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map) {
      return MobileApiException(
        code: payload['error']?.toString() ?? fallbackCode,
        message: _inventoryErrorMessage(
          payload['error']?.toString() ?? fallbackCode,
          fallbackMessage,
        ),
        statusCode: response.statusCode,
      );
    }
  } catch (_) {
    // Fall through to the stable client-side fallback.
  }
  return MobileApiException(
    code: fallbackCode,
    message: fallbackMessage,
    statusCode: response.statusCode,
  );
}

String _inventoryErrorMessage(String code, String fallback) {
  return switch (code) {
    'inventory_asset_not_found' => 'Mahsulot topilmadi',
    'inventory_asset_unavailable' =>
      'Mahsulot band qilingan yoki hozir mavjud emas',
    'inventory_asset_not_in_source_warehouse' =>
      'Mahsulotni transferdan oldin omborga qaytaring',
    'inventory_location_not_found' => 'Joylashuv topilmadi',
    'inventory_location_inactive' => 'Bu state faol emas',
    'inventory_cross_warehouse_requires_transfer' =>
      'Boshqa omborga faqat transfer orqali yuboriladi',
    'inventory_destination_warehouse_unassigned' =>
      'Qabul qiluvchi omborga mas’ul foydalanuvchi biriktirilmagan',
    'inventory_transfer_transition_invalid' =>
      'Transfer bu bosqichda o‘zgartirilmaydi',
    'inventory_idempotency_conflict' => 'Amal takrorlandi yoki mos kelmadi',
    _ => fallback,
  };
}

void _releaseTestModeTransferAssets(InventoryTransfer transfer) {
  for (final line in transfer.lines) {
    final index = _testModeInventoryAssets.indexWhere(
      (asset) =>
          asset.kind == line.assetKind &&
          asset.assetRef == line.assetRef &&
          asset.transferId == transfer.id,
    );
    if (index >= 0) {
      _testModeInventoryAssets[index] =
          _testModeInventoryAssets[index].copyWith(
        status: 'available',
        transferId: '',
      );
    }
  }
}

void _markTestModeTransferAssetsInTransit(InventoryTransfer transfer) {
  for (final line in transfer.lines) {
    final index = _testModeInventoryAssets.indexWhere(
      (asset) =>
          asset.kind == line.assetKind &&
          asset.assetRef == line.assetRef &&
          asset.transferId == transfer.id,
    );
    if (index >= 0) {
      _testModeInventoryAssets[index] =
          _testModeInventoryAssets[index].copyWith(status: 'in_transit');
    }
  }
}

void _receiveTestModeTransferAssets(InventoryTransfer transfer) {
  final destination = _testModeInventoryLocations.where(
    (location) =>
        location.isWarehouse &&
        location.warehouseId == transfer.destinationWarehouseId,
  );
  if (destination.isEmpty) {
    return;
  }
  final location = destination.first;
  for (final line in transfer.lines) {
    final index = _testModeInventoryAssets.indexWhere(
      (asset) =>
          asset.kind == line.assetKind &&
          asset.assetRef == line.assetRef &&
          asset.transferId == transfer.id,
    );
    if (index >= 0) {
      final asset = _testModeInventoryAssets[index];
      _testModeInventoryAssets[index] = asset.copyWith(
        custodyWarehouseId: transfer.destinationWarehouseId,
        custodyWarehouse: transfer.destinationWarehouse,
        status: 'available',
        transferId: '',
        physicalLocation: InventoryLocationReference(
          id: location.id,
          kind: location.kind,
          name: location.name,
        ),
        placementVersion: asset.placementVersion + 1,
      );
    }
  }
}
