part of '../mobile_api.dart';

final Map<String, AdminItemDetail> _testModeAdminItemDetailOverrides = {};
final Set<String> _testModeDeletedAdminItemCodes = {};
int _canonicalApparatusOpaqueCounter = 0;

const Map<String, dynamic> _testModeCanonicalApparatusOptions = {
  'contract': 'canonical_apparatus_revision',
  'schema_version': 1,
  'vocabulary': {
    'equipment_capabilities': [
      'print',
      'laminate',
      'cut',
      'package',
      'glue',
      'tooling',
      'virtual_task',
      'training',
    ],
    'execution_operations': ['print', 'laminate', 'cut', 'package', 'glue'],
    'process_technologies': [
      'rotogravure',
      'flexographic',
      'adhesive_lamination',
      'extrusion_lamination',
      'slitting',
      'bag_making',
      'cold_glue',
    ],
  },
};

const Set<String> _canonicalApparatusCapabilities = {
  'print',
  'laminate',
  'cut',
  'package',
  'glue',
  'tooling',
  'virtual_task',
  'training',
};

extension MobileApiAdminItems on MobileApi {
  Future<List<String>> adminItemUoms() async {
    if (await TestModeController.instance.isEnabled()) {
      final settings = await adminSettings();
      final values = <String>[
        settings.defaultUom,
        ...TestModeDemoData.itemPage(limit: 0).map((item) => item.uom),
      ];
      final seen = <String>{};
      return values
          .where((value) {
            final normalized = value.trim().toLowerCase();
            return normalized.isNotEmpty && seen.add(normalized);
          })
          .map((value) => value.trim())
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/items/uoms'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin item UOMs failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<CustomerDirectoryEntry>> adminCustomersForItem({
    required String itemCode,
    String itemName = '',
    String query = '',
    int limit = 200,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final trimmedCode = itemCode.trim().toLowerCase();
      final trimmedName = itemName.trim().toLowerCase();
      final normalizedQuery = query.trim().toLowerCase();
      final matches = <CustomerDirectoryEntry>[];
      final seen = <String>{};
      for (final customer in TestModeDemoData.customerPage(
        limit: 0,
        offset: 0,
      )) {
        final detail = TestModeDemoData.customerDetail(customer.ref);
        final hasItem = detail.assignedItems.any((item) {
          final code = item.code.trim().toLowerCase();
          final name = item.name.trim().toLowerCase();
          if (trimmedCode.isNotEmpty && code == trimmedCode) {
            return true;
          }
          return trimmedName.isNotEmpty && name == trimmedName;
        });
        if (!hasItem) {
          continue;
        }
        if (normalizedQuery.isNotEmpty &&
            !searchMatches(normalizedQuery, [
              customer.name,
              customer.phone,
              customer.ref,
            ])) {
          continue;
        }
        if (seen.add(customer.ref)) {
          matches.add(customer);
        }
      }
      if (offset >= matches.length) {
        return const <CustomerDirectoryEntry>[];
      }
      final end = limit <= 0 || offset + limit > matches.length
          ? matches.length
          : offset + limit;
      return matches.sublist(offset, end);
    }
    return werkaCustomersForItem(
      itemCode: itemCode,
      itemName: itemName,
      query: query,
      limit: limit,
      offset: offset,
    );
  }

  Future<AdminCustomerDetail> adminAssignCustomerItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/customers/items/add',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'item_code': itemCode}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemMutationException(
        response,
        fallbackCode: 'item_customer_add_failed',
        fallbackMessage: 'Customer itemga ulanmadi',
      );
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminRemoveCustomerItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/customers/items/remove',
        ).replace(queryParameters: {'ref': ref, 'item_code': itemCode}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemMutationException(
        response,
        fallbackCode: 'item_customer_remove_failed',
        fallbackMessage: 'Customer itemdan uzilmadi',
      );
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SupplierItem>> adminItems({
    String query = '',
    String group = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.itemPage(query: query, group: group, limit: 0);
    }
    const pageSize = 200;
    final items = <SupplierItem>[];
    for (var offset = 0;; offset += pageSize) {
      final page = await adminItemsPage(
        query: query,
        group: group,
        limit: pageSize,
        offset: offset,
      );
      items.addAll(page);
      if (page.length < pageSize) {
        break;
      }
    }
    return items;
  }

  Future<List<SupplierItem>> adminItemsPage({
    String query = '',
    String group = '',
    int limit = 50,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final items = TestModeDemoData.itemPage(
        query: query,
        group: group,
        limit: 0,
        offset: 0,
      )
          .where(
            (item) => !_testModeDeletedAdminItemCodes.contains(
              item.code.trim().toLowerCase(),
            ),
          )
          .toList(growable: false);
      if (offset >= items.length) {
        return const <SupplierItem>[];
      }
      final end = limit <= 0 || offset + limit > items.length
          ? items.length
          : offset + limit;
      return items.sublist(offset, end);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/items').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (group.trim().isNotEmpty) 'group': group.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin items failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminWarehouseStockItem>> adminWarehouseItemsPage({
    required String warehouse,
    String query = '',
    int limit = 80,
    int offset = 0,
  }) async {
    final normalizedWarehouse = warehouse.trim().toLowerCase();
    if (normalizedWarehouse.isEmpty) {
      return const <AdminWarehouseStockItem>[];
    }
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.warehouseItemPage(
        warehouse: normalizedWarehouse,
        query: query,
        limit: limit,
        offset: offset,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/warehouses/items',
        ).replace(
          queryParameters: {
            'warehouse': warehouse.trim(),
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin warehouse items failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminWarehouseStockItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AdminWarehouse>> adminWarehouses({
    String query = '',
    String parent = '',
    int limit = 50,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = query.trim().toLowerCase();
      final normalizedParent = parent.trim().toLowerCase();
      final seenWarehouseNames = <String>{};
      return [
        ...TestModeDemoData.warehouses,
        ..._testModeWarehouses,
      ]
          .where(
            (warehouse) =>
                !_testModeDeletedWarehouseNames.contains(
                  warehouse.warehouse.trim().toLowerCase(),
                ) &&
                (normalized.isEmpty ||
                    warehouse.warehouse.toLowerCase().contains(normalized)) &&
                (normalizedParent.isEmpty ||
                    warehouse.parentWarehouse.toLowerCase() ==
                        normalizedParent),
          )
          .where(
            (warehouse) => seenWarehouseNames.add(
              warehouse.warehouse.trim().toLowerCase(),
            ),
          )
          .take(limit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/warehouses').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (parent.trim().isNotEmpty) 'parent': parent.trim(),
            if (limit > 0) 'limit': '$limit',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin warehouses failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminWarehouse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminApparatus>> adminApparatus({
    String query = '',
    int limit = 50,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeApparatusCatalog()
          .where(
            (apparatus) =>
                normalized.isEmpty ||
                apparatus.name.toLowerCase().contains(normalized),
          )
          .take(limit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/apparatus').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'apparatus_list_failed',
        fallbackMessage: 'Aparatlar yuklanmadi',
      );
    }
    final json = await decodeJsonListPayload(response.body);
    final apparatus = <AdminApparatus>[];
    for (var index = 0; index < json.length; index++) {
      final item = json[index];
      if (item is! Map) {
        throw MobileApiException(
          code: 'apparatus_projection_invalid',
          message:
              'Canonical apparat projection noto‘g‘ri (${index + 1}-qator)',
          details: ['item_index=${index + 1}'],
        );
      }
      try {
        final parsed = AdminApparatus.fromJson(item.cast<String, dynamic>());
        apparatus.add(parsed);
      } catch (error) {
        throw MobileApiException(
          code: 'apparatus_projection_invalid',
          message:
              'Canonical apparat projection noto‘g‘ri (${index + 1}-qator)',
          details: [
            'item_index=${index + 1}',
            'error=$error',
          ],
        );
      }
    }
    return apparatus;
  }

  Future<List<AdminApparatusCollection>> adminApparatusCollections() async {
    if (await TestModeController.instance.isEnabled()) {
      final collections = [..._testModeApparatusCollections]..sort(
          (left, right) =>
              left.name.toLowerCase().compareTo(right.name.toLowerCase()),
        );
      return List.unmodifiable(collections);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/apparatus-collections',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode == 404) {
      return const <AdminApparatusCollection>[];
    }
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'apparatus_collections_list_failed',
        fallbackMessage: 'Aparat guruhlari yuklanmadi',
      );
    }
    final json = await decodeJsonListPayload(response.body);
    return [
      for (final item in json)
        AdminApparatusCollection.fromJson(
          (item as Map).cast<String, dynamic>(),
        ),
    ];
  }

  Future<AdminApparatusCollection> adminCreateApparatusCollection({
    required String name,
    required Iterable<String> apparatusIds,
  }) async {
    final normalizedName = _normalizedApparatusCollectionName(name);
    final normalizedIds = _normalizedApparatusCollectionIds(apparatusIds);
    if (await TestModeController.instance.isEnabled()) {
      _testModeValidateApparatusCollectionMembers(normalizedIds);
      if (_testModeApparatusCollections.any(
        (item) => item.name.toLowerCase() == normalizedName.toLowerCase(),
      )) {
        throw const MobileApiException(
          code: 'apparatus_collection_name_exists',
          message: 'Bu nomdagi aparat guruhi mavjud',
          statusCode: 409,
        );
      }
      _testModeApparatusCollectionCounter++;
      final opaque = _testModeApparatusCollectionCounter
          .toRadixString(16)
          .padLeft(32, '0');
      final collection = AdminApparatusCollection(
        id: 'apparatus-collection:$opaque',
        name: normalizedName,
        apparatusIds: normalizedIds,
        revision: 1,
      );
      _testModeApparatusCollections.add(collection);
      return collection;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/apparatus-collections',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'name': normalizedName,
          'apparatus_ids': normalizedIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'apparatus_collection_create_failed',
        fallbackMessage: 'Aparat guruhi yaratilmadi',
      );
    }
    return AdminApparatusCollection.fromJson(
      await decodeJsonMapPayload(response.body),
    );
  }

  Future<AdminApparatusCollection> adminUpdateApparatusCollection({
    required AdminApparatusCollection collection,
    required String name,
    required Iterable<String> apparatusIds,
  }) async {
    final normalizedName = _normalizedApparatusCollectionName(name);
    final normalizedIds = _normalizedApparatusCollectionIds(apparatusIds);
    if (await TestModeController.instance.isEnabled()) {
      _testModeValidateApparatusCollectionMembers(normalizedIds);
      final index = _testModeApparatusCollections.indexWhere(
        (item) => item.id == collection.id,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'apparatus_collection_not_found',
          message: 'Aparat guruhi topilmadi',
          statusCode: 404,
        );
      }
      final current = _testModeApparatusCollections[index];
      if (current.revision != collection.revision) {
        throw const MobileApiException(
          code: 'apparatus_collection_revision_conflict',
          message: 'Aparat guruhi boshqa joyda o‘zgartirilgan',
          statusCode: 409,
        );
      }
      if (_testModeApparatusCollections.any(
        (item) =>
            item.id != collection.id &&
            item.name.toLowerCase() == normalizedName.toLowerCase(),
      )) {
        throw const MobileApiException(
          code: 'apparatus_collection_name_exists',
          message: 'Bu nomdagi aparat guruhi mavjud',
          statusCode: 409,
        );
      }
      final updated = AdminApparatusCollection(
        id: current.id,
        name: normalizedName,
        apparatusIds: normalizedIds,
        revision: current.revision + 1,
      );
      _testModeApparatusCollections[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        _apparatusCollectionUri(collection.id),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'expected_revision': collection.revision,
          'name': normalizedName,
          'apparatus_ids': normalizedIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'apparatus_collection_update_failed',
        fallbackMessage: 'Aparat guruhi saqlanmadi',
      );
    }
    return AdminApparatusCollection.fromJson(
      await decodeJsonMapPayload(response.body),
    );
  }

  Future<void> adminDeleteApparatusCollection(
    AdminApparatusCollection collection,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeApparatusCollections.indexWhere(
        (item) => item.id == collection.id,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'apparatus_collection_not_found',
          message: 'Aparat guruhi topilmadi',
          statusCode: 404,
        );
      }
      if (_testModeApparatusCollections[index].revision !=
          collection.revision) {
        throw const MobileApiException(
          code: 'apparatus_collection_revision_conflict',
          message: 'Aparat guruhi boshqa joyda o‘zgartirilgan',
          statusCode: 409,
        );
      }
      _testModeApparatusCollections.removeAt(index);
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        _apparatusCollectionUri(collection.id),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'expected_revision': collection.revision}),
      ),
    );
    if (response.statusCode != 204) {
      throw _adminApiException(
        response,
        fallbackCode: 'apparatus_collection_delete_failed',
        fallbackMessage: 'Aparat guruhi o‘chirilmadi',
      );
    }
  }

  Future<AdminApparatusMasterOptions> adminApparatusMasterOptions() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminApparatusMasterOptions.fromJson(
        _testModeCanonicalApparatusOptions,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/apparatus/options'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin apparatus options failed');
    }
    return AdminApparatusMasterOptions.fromJson(
      await decodeJsonMapPayload(response.body),
    );
  }

  Future<List<AdminWarehouseSummary>> adminWarehouseSummaries({
    String query = '',
    int limit = 50,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeWarehouseSummaries(query: query, limit: limit);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/warehouses/summary',
        ).replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin warehouse summaries failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminWarehouseSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AdminRawMaterialStockEntry>> adminRawMaterialStock({
    String warehouse = '',
    int limit = 500,
  }) async {
    final normalizedWarehouse = warehouse.trim().toLowerCase();
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.rawMaterialStock
          .where(
            (item) =>
                normalizedWarehouse.isEmpty ||
                item.warehouse.trim().toLowerCase() == normalizedWarehouse,
          )
          .take(limit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-stock',
        ).replace(
          queryParameters: {
            if (warehouse.trim().isNotEmpty) 'warehouse': warehouse.trim(),
            if (limit > 0) 'limit': '$limit',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin raw material stock failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminRawMaterialStockEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminRawMaterialStockEntry> adminUpdateRawMaterialStock({
    required String barcode,
    required String itemCode,
    required double qty,
  }) async {
    final normalizedBarcode = barcode.trim();
    final normalizedItemCode = itemCode.trim();
    if (normalizedBarcode.isEmpty ||
        normalizedItemCode.isEmpty ||
        !qty.isFinite ||
        qty <= 0) {
      throw const MobileApiException(
        code: 'raw_material_stock_update_invalid',
        message: 'Mahsulot va musbat miqdorni kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final stock = TestModeDemoData.rawMaterialStock.where(
        (item) =>
            item.barcode.trim().toLowerCase() ==
            normalizedBarcode.toLowerCase(),
      );
      if (stock.isEmpty) {
        throw const MobileApiException(
          code: 'raw_material_stock_not_found',
          message: 'Homashyo omborda topilmadi',
        );
      }
      final current = stock.first;
      if (current.status.trim().toLowerCase() != 'available' ||
          current.reservedOrderId.trim().isNotEmpty) {
        throw const MobileApiException(
          code: 'raw_material_stock_locked',
          message: 'Band qilingan homashyoni tahrirlab bo‘lmaydi',
        );
      }
      final catalog = TestModeDemoData.itemPage(
        query: normalizedItemCode,
        limit: 0,
      );
      final selected = catalog.where(
        (item) =>
            item.code.trim().toLowerCase() == normalizedItemCode.toLowerCase(),
      );
      if (selected.isEmpty) {
        throw const MobileApiException(
          code: 'raw_material_item_not_found',
          message: 'Tanlangan mahsulot topilmadi',
        );
      }
      final item = selected.first;
      return AdminRawMaterialStockEntry(
        id: current.id,
        warehouse: current.warehouse,
        itemCode: item.code,
        itemName: item.name,
        barcode: current.barcode,
        qty: qty,
        uom: current.uom,
        status: current.status,
        reservedOrderId: current.reservedOrderId,
        sourceReceiptId: current.sourceReceiptId,
      );
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-stock'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'barcode': normalizedBarcode,
          'item_code': normalizedItemCode,
          'qty': qty,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _rawMaterialStockUpdateException(response);
    }
    return AdminRawMaterialStockEntry.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> adminDeleteRawMaterialStock({required String barcode}) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      throw const MobileApiException(
        code: 'raw_material_stock_delete_invalid',
        message: 'QR kodi topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeInventoryAssets.indexWhere(
        (asset) {
          final identifier = asset.identifier.trim();
          final assetRef = asset.assetRef.trim();
          final separator = assetRef.indexOf(':');
          final assetBarcode = identifier.isNotEmpty
              ? identifier
              : separator < 0
                  ? assetRef
                  : assetRef.substring(separator + 1).trim();
          return asset.kind == InventoryAssetKind.rawMaterial &&
              assetBarcode.toLowerCase() == normalizedBarcode.toLowerCase();
        },
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'raw_material_stock_not_found',
          message: 'Homashyo omborda topilmadi',
        );
      }
      final current = _testModeInventoryAssets[index];
      final assigned = _testModeRawMaterialAssignments.any(
        (assignment) =>
            assignment.barcode.trim().toLowerCase() ==
            normalizedBarcode.toLowerCase(),
      );
      if (!current.isAvailable ||
          current.physicalLocation.kind != InventoryLocationKind.warehouse ||
          assigned) {
        throw const MobileApiException(
          code: 'raw_material_stock_locked',
          message: 'Band yoki omborda bo‘lmagan homashyoni o‘chirib bo‘lmaydi',
        );
      }
      _testModeInventoryAssets.removeAt(index);
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-stock'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'barcode': normalizedBarcode}),
      ),
    );
    if (response.statusCode != 200) {
      throw _rawMaterialStockDeleteException(response);
    }
  }

  Future<AdminRawMaterialStockReprintPreparation>
      adminPrepareRawMaterialStockReprint({required String barcode}) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      throw const MobileApiException(
        code: 'raw_material_stock_reprint_invalid',
        message: 'QR kodi topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final matches = TestModeDemoData.rawMaterialStock.where(
        (item) =>
            item.barcode.trim().toLowerCase() ==
            normalizedBarcode.toLowerCase(),
      );
      if (matches.isEmpty) {
        throw const MobileApiException(
          code: 'raw_material_stock_not_found',
          message: 'Homashyo omborda topilmadi',
        );
      }
      final stock = matches.first;
      if (stock.status.trim().toLowerCase() != 'available' ||
          stock.reservedOrderId.trim().isNotEmpty) {
        throw const MobileApiException(
          code: 'raw_material_stock_locked',
          message: 'Band qilingan homashyo QR kodini qayta chop etib bo‘lmaydi',
        );
      }
      return AdminRawMaterialStockReprintPreparation(
        reprintId: 'test-${stock.barcode}',
        stock: stock,
        printRequest: UsbRpsPrintRequest(
          epc: stock.barcode,
          itemCode: stock.itemCode,
          itemName: stock.itemName,
          warehouse: stock.warehouse,
          printer: 'godex',
          printMode: 'label',
          grossQty: stock.qty,
          unit: stock.uom,
          labelKind: 'material_product',
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-stock/reprint/prepare',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'barcode': normalizedBarcode}),
      ),
    );
    if (response.statusCode != 200) {
      throw _rawMaterialStockReprintException(response);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminRawMaterialStockReprintPreparation.fromJson(payload);
  }

  Future<void> adminConfirmRawMaterialStockReprint({
    required String barcode,
    required String reprintId,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-stock/reprint/confirm',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'barcode': barcode.trim(),
          'reprint_id': reprintId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _rawMaterialStockReprintException(response);
    }
  }

  Future<AdminWarehouse> adminCreateWarehouse(String warehouse) async {
    final name = warehouse.trim();
    if (name.isEmpty) {
      throw Exception('Admin warehouse name required');
    }
    if (await TestModeController.instance.isEnabled()) {
      final item = AdminWarehouse(
        warehouse: name,
        company: '',
        isGroup: false,
        parentWarehouse: '',
      );
      _testModeDeletedWarehouseNames.remove(name.toLowerCase());
      final index = _testModeWarehouses.indexWhere(
        (existing) => existing.warehouse.toLowerCase() == name.toLowerCase(),
      );
      if (index >= 0) {
        _testModeWarehouses[index] = item;
      } else {
        _testModeWarehouses.add(item);
      }
      _testModeWarehouses.sort(
        (left, right) => left.warehouse.toLowerCase().compareTo(
              right.warehouse.toLowerCase(),
            ),
      );
      return item;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/warehouses'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'warehouse': name}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin warehouse create failed');
    }
    return AdminWarehouse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> adminDeleteWarehouse({
    required String warehouse,
    required bool deleteProducts,
  }) async {
    final normalizedWarehouse = warehouse.trim();
    if (normalizedWarehouse.isEmpty) {
      throw const MobileApiException(
        code: 'warehouse_required',
        message: 'Ombor tanlanmagan',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final summary = _testModeWarehouseSummaries(
        query: normalizedWarehouse,
        limit: 500,
      ).where(
        (item) =>
            item.warehouse.trim().toLowerCase() ==
            normalizedWarehouse.toLowerCase(),
      );
      if (summary.isEmpty) {
        throw const MobileApiException(
          code: 'warehouse_not_found',
          message: 'Ombor topilmadi',
        );
      }
      final current = summary.first;
      if (current.reservedCount > 0) {
        throw const MobileApiException(
          code: 'warehouse_has_active_reservations',
          message: 'Omborda faol band qilingan mahsulotlar bor',
        );
      }
      if (current.productCount > 0 && !deleteProducts) {
        throw const MobileApiException(
          code: 'warehouse_not_empty',
          message: 'Omborda mahsulotlar bor',
        );
      }
      _testModeDeletedWarehouseNames.add(normalizedWarehouse.toLowerCase());
      _testModeWarehouses.removeWhere(
        (item) =>
            item.warehouse.trim().toLowerCase() ==
            normalizedWarehouse.toLowerCase(),
      );
      _testModeWarehouseAssignments.removeWhere(
        (item) =>
            item.warehouse.trim().toLowerCase() ==
            normalizedWarehouse.toLowerCase(),
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/warehouses'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'warehouse': normalizedWarehouse,
          'delete_products': deleteProducts,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'warehouse_delete_failed',
        fallbackMessage: 'Ombor o‘chirilmadi',
      );
    }
  }

  Future<List<AdminWarehouseAssignment>> adminWarehouseAssignments({
    String warehouse = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = warehouse.trim().toLowerCase();
      return _testModeWarehouseAssignments
          .where(
            (item) =>
                normalized.isEmpty ||
                item.warehouse.trim().toLowerCase() == normalized,
          )
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/warehouses/assignments',
        ).replace(
          queryParameters: {
            if (warehouse.trim().isNotEmpty) 'warehouse': warehouse.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin warehouse assignments failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminWarehouseAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminWarehouseAssignment> adminAssignWarehouse({
    required String warehouse,
    required UserRole principalRole,
    required String principalRef,
    required String displayName,
  }) async {
    final normalizedWarehouse = warehouse.trim();
    final normalizedRef = principalRef.trim();
    if (normalizedWarehouse.isEmpty || normalizedRef.isEmpty) {
      throw Exception('Admin warehouse assignment input required');
    }
    if (await TestModeController.instance.isEnabled()) {
      final assignment = AdminWarehouseAssignment(
        warehouse: normalizedWarehouse,
        principalRole: principalRole,
        principalRef: normalizedRef,
        displayName: displayName.trim(),
      );
      final index = _testModeWarehouseAssignments.indexWhere(
        (item) =>
            item.warehouse.trim().toLowerCase() ==
                normalizedWarehouse.toLowerCase() &&
            item.principalRole == principalRole &&
            item.principalRef.trim().toLowerCase() ==
                normalizedRef.toLowerCase(),
      );
      if (index >= 0) {
        _testModeWarehouseAssignments[index] = assignment;
      } else {
        _testModeWarehouseAssignments.add(assignment);
      }
      return assignment;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/warehouses/assignments',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'warehouse': normalizedWarehouse,
          'principal_role': _adminWarehouseRoleToJson(principalRole),
          'principal_ref': normalizedRef,
          'display_name': displayName.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin warehouse assignment failed');
    }
    return AdminWarehouseAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWarehouseAssignment> adminUnassignWarehouse({
    required String warehouse,
    required UserRole principalRole,
    required String principalRef,
  }) async {
    final normalizedWarehouse = warehouse.trim();
    final normalizedRef = principalRef.trim();
    if (normalizedWarehouse.isEmpty || normalizedRef.isEmpty) {
      throw const MobileApiException(
        code: 'warehouse_assignment_input_required',
        message: 'Ombor assignment ma’lumoti to‘liq emas',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWarehouseAssignments.indexWhere(
        (item) =>
            item.warehouse.trim().toLowerCase() ==
                normalizedWarehouse.toLowerCase() &&
            item.principalRole == principalRole &&
            item.principalRef.trim().toLowerCase() ==
                normalizedRef.toLowerCase(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'warehouse_assignment_not_found',
          message: 'Ombor assignmenti topilmadi',
        );
      }
      return _testModeWarehouseAssignments.removeAt(index);
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/warehouses/assignments',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'warehouse': normalizedWarehouse,
          'principal_role': _adminWarehouseRoleToJson(principalRole),
          'principal_ref': normalizedRef,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'warehouse_assignment_remove_failed',
        fallbackMessage: 'Ombor assignmenti olib tashlanmadi',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminWarehouseAssignment.fromJson(
      (payload['assignment'] as Map).cast<String, dynamic>(),
    );
  }

  Future<AdminApparatus> adminCreateApparatus(
    String apparatusName, {
    String id = '',
    String family = '',
    String kind = '',
    Iterable<String> capabilities = const <String>[],
    Iterable<AdminApparatusCapabilityProfile> capabilityProfiles =
        const <AdminApparatusCapabilityProfile>[],
    int? colorStations,
    String? factoryMapObjectId,
    bool? trainingEnabled,
  }) async {
    final name = apparatusName.trim();
    if (name.isEmpty) {
      throw const MobileApiException(
        code: 'apparatus_display_name_required',
        message: 'Aparat nomi kiritilmadi',
      );
    }
    final normalizedId = id.trim();
    if (normalizedId.isNotEmpty && !isCanonicalApparatusId(normalizedId)) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Canonical apparatus ID noto‘g‘ri',
      );
    }
    final normalizedFactoryMapObjectId = factoryMapObjectId?.trim() ?? '';
    final normalizedFamily = family.trim().toLowerCase();
    final normalizedKind = kind.trim().toLowerCase();
    final testMode = await TestModeController.instance.isEnabled();
    var operation = _canonicalOperationForFamily(normalizedFamily);
    var technology = _canonicalTechnologyForKind(normalizedKind);
    if (testMode && operation.isEmpty && technology.isEmpty) {
      operation = 'package';
      technology = 'bag_making';
    }
    if (operation.isEmpty ||
        technology.isEmpty ||
        _canonicalOperationForTechnology(technology) != operation) {
      throw const MobileApiException(
        code: 'canonical_execution_profile_required',
        message: 'Aparat turi va texnologiyasi canonical contractga mos emas',
      );
    }
    final normalizedProfiles = capabilityProfiles
        .map(
          (profile) => AdminApparatusCapabilityProfile(
            code: profile.code.trim().toLowerCase(),
            level: profile.level.clamp(1, 100),
            validFromUnix: profile.validFromUnix,
            validToUnix: profile.validToUnix,
            enabled: profile.enabled,
          ),
        )
        .where(
          (profile) =>
              profile.enabled &&
              _canonicalApparatusCapabilities.contains(profile.code),
        )
        .toList(growable: false);
    final normalizedCapabilities = <String>{
      ...capabilities
          .map((item) => item.trim().toLowerCase())
          .where(_canonicalApparatusCapabilities.contains)
          .toSet(),
      ...normalizedProfiles
          .map((profile) => profile.code)
          .where(_canonicalApparatusCapabilities.contains),
      operation,
      if (trainingEnabled == true) 'training',
    }.toList(growable: false)
      ..sort();
    if (testMode) {
      final existingIndex = normalizedId.isEmpty
          ? -1
          : _testModeApparatus.indexWhere(
              (existing) => existing.id == normalizedId,
            );
      final existing = existingIndex >= 0
          ? _testModeApparatus[existingIndex]
          : normalizedId.isEmpty
              ? null
              : _firstOrNull(
                  _testModeApparatusCatalog().where(
                    (apparatus) => apparatus.id == normalizedId,
                  ),
                );
      final effectiveTrainingEnabled =
          trainingEnabled ?? existing?.trainingEnabled ?? false;
      final effectiveProfiles = normalizedProfiles.isEmpty
          ? [
              for (final capability in normalizedCapabilities)
                AdminApparatusCapabilityProfile(code: capability),
            ]
          : normalizedProfiles;
      final opaque = _nextCanonicalApparatusOpaqueKey();
      final item = AdminApparatus(
        id: normalizedId.isNotEmpty
            ? normalizedId
            : existing?.id ?? 'apparatus:test:$opaque',
        name: name,
        source: 'canonical',
        sortOrder: existing?.sortOrder ?? 10000,
        family: normalizedFamily,
        kind: normalizedKind,
        capabilities: normalizedCapabilities,
        capabilityProfiles: effectiveProfiles,
        colorStations: colorStations,
        factoryMapObjectId: normalizedFactoryMapObjectId,
        trainingEnabled: effectiveTrainingEnabled,
        sourceRevision: (existing?.sourceRevision ?? 0) + 1,
        sourceAasxSha256: existing?.sourceAasxSha256 ?? '',
        description: existing?.description ?? '',
        equipmentClassId: existing?.equipmentClassId ??
            'equipment-class:mini-rs-erp:$operation:$technology',
        physicalAssetId:
            existing?.physicalAssetId ?? 'physical-asset:test:$opaque',
        enterpriseId: existing?.enterpriseId ?? 'enterprise:accord',
        siteId: existing?.siteId ?? 'site:main',
        areaId: existing?.areaId ?? 'area:production',
        workCenterId: existing?.workCenterId ?? 'work-center:$operation',
        workUnitId: existing?.workUnitId ?? 'work-unit:test:$opaque',
        operation: operation,
        technology: technology,
        maxWebWidthMm: existing?.maxWebWidthMm,
        virtualTasks: existing?.virtualTasks ?? 'disabled',
        capabilityCompatibleReroute:
            existing?.capabilityCompatibleReroute ?? true,
        trainingQueueEnabled: effectiveTrainingEnabled &&
            (existing?.trainingQueueEnabled ?? true),
        trainingMaterialTrackingEnabled: effectiveTrainingEnabled &&
            (existing?.trainingMaterialTrackingEnabled ?? true),
        lifecycleState: existing?.lifecycleState ?? 'active',
      );
      if (existingIndex >= 0) {
        _testModeApparatus[existingIndex] = item;
      } else {
        _testModeApparatus.add(item);
      }
      _testModeApparatus.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
      return item;
    }
    AdminApparatus? current;
    if (normalizedId.isNotEmpty) {
      final catalog = await adminApparatus(limit: 500);
      current = _firstOrNull(catalog.where((item) => item.id == normalizedId));
      if (current == null) {
        throw const MobileApiException(
          code: 'apparatus_not_found',
          message: 'Aparat topilmadi',
        );
      }
    }
    final operationKey = current == null ? 'create' : 'update';
    final idempotencyKey = _nextCanonicalMutationIdempotencyKey(operationKey);
    final createOpaqueKey =
        current == null ? _nextCanonicalApparatusOpaqueKey() : '';
    final response = await _sendAuthorized(() {
      final headers = _canonicalMutationHeaders(
        requireToken(),
        idempotencyKey,
      );
      if (current == null) {
        return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/apparatus'),
          headers: headers,
          body: jsonEncode(
            _canonicalApparatusDraft(
              name: name,
              operation: operation,
              technology: technology,
              capabilities: normalizedProfiles,
              capabilityCodes: normalizedCapabilities,
              colorStations: colorStations,
              factoryMapObjectId: normalizedFactoryMapObjectId,
              trainingEnabled: trainingEnabled ?? false,
              opaqueKey: createOpaqueKey,
            ),
          ),
        );
      }
      final patchCapabilities = [
        for (final code in normalizedCapabilities)
          {
            'code': code,
            'level': _firstOrNull(
                  normalizedProfiles.where((profile) => profile.code == code),
                )?.level ??
                _firstOrNull(
                  current.capabilityProfiles.where(
                    (profile) => profile.code == code,
                  ),
                )?.level ??
                1,
          },
      ];
      return _patch(
        _canonicalApparatusUri(current.id),
        headers: headers,
        body: jsonEncode({
          'expected_revision': current.sourceRevision,
          'patch': {
            'display': {
              'display_name': name,
              'description': current.description,
              'catalog_order': current.sortOrder,
            },
            'equipment_class_id':
                'equipment-class:mini-rs-erp:$operation:$technology',
            'capabilities': patchCapabilities,
            'execution_profile': {
              'operation': operation,
              'technology': technology,
              'color_station_count': colorStations,
              if (current.maxWebWidthMm != null)
                'max_web_width_mm': current.maxWebWidthMm,
              'virtual_tasks': current.virtualTasks,
              'capability_compatible_reroute':
                  current.capabilityCompatibleReroute,
            },
            if (factoryMapObjectId != null &&
                normalizedFactoryMapObjectId.isNotEmpty)
              'placement': {
                'factory_map_object_id': normalizedFactoryMapObjectId,
              },
            if (trainingEnabled != null)
              'training': {
                'enabled': trainingEnabled,
                'queue_enabled':
                    trainingEnabled && current.trainingQueueEnabled,
                'material_tracking_enabled':
                    trainingEnabled && current.trainingMaterialTrackingEnabled,
              },
          },
        }),
      );
    });
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'canonical_apparatus_save_failed',
        fallbackMessage: 'Canonical aparat saqlanmadi',
      );
    }
    return AdminApparatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminApparatus> adminPatchCanonicalApparatus({
    required AdminApparatus apparatus,
    required Map<String, dynamic> patch,
  }) async {
    if (apparatus.id.trim().isEmpty || apparatus.sourceRevision <= 0) {
      throw const MobileApiException(
        code: 'canonical_apparatus_revision_required',
        message: 'Canonical aparat revisioni topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'canonical_patch_not_available_in_test_mode',
        message: 'Canonical patch test rejimida mavjud emas',
      );
    }
    final idempotencyKey = _nextCanonicalMutationIdempotencyKey('patch');
    final response = await _sendAuthorized(
      () => _patch(
        _canonicalApparatusUri(apparatus.id),
        headers: _canonicalMutationHeaders(requireToken(), idempotencyKey),
        body: jsonEncode({
          'expected_revision': apparatus.sourceRevision,
          'patch': patch,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'canonical_apparatus_patch_failed',
        fallbackMessage: 'Canonical aparat yangilanmadi',
      );
    }
    return AdminApparatus.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminItemGroupBulkMoveResult> adminMoveItemsToGroup({
    required List<String> itemCodes,
    required String itemGroup,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/items/bulk-move-group'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'item_codes': itemCodes, 'item_group': itemGroup}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemMutationException(
        response,
        fallbackCode: 'item_group_bulk_move_failed',
        fallbackMessage: 'Mahsulotlar groupga ko‘chirilmadi',
      );
    }
    return AdminItemGroupBulkMoveResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SupplierItem> adminCreateItem({
    required String code,
    required String name,
    required String uom,
    required String itemGroup,
    String customerRef = '',
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/items'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'code': code,
          'name': name,
          'uom': uom,
          'item_group': itemGroup,
          if (customerRef.trim().isNotEmpty) 'customer_ref': customerRef.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemCreateException(response);
    }
    return SupplierItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminItemDetail> adminItemDetail(String itemCode) async {
    final code = itemCode.trim();
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeDeletedAdminItemCodes.contains(code.toLowerCase())) {
        throw const MobileApiException(
          code: 'item_not_found',
          message: 'Item topilmadi',
          statusCode: 404,
        );
      }
      final override = _testModeAdminItemDetailOverrides[code.toLowerCase()];
      if (override != null) {
        return override;
      }
      final items = TestModeDemoData.itemPage(query: code, limit: 0);
      SupplierItem? matched;
      for (final item in items) {
        if (item.code.trim().toLowerCase() == code.toLowerCase()) {
          matched = item;
          break;
        }
      }
      if (matched == null) {
        throw const MobileApiException(
          code: 'item_not_found',
          message: 'Item topilmadi',
          statusCode: 404,
        );
      }
      final customers = await adminCustomersForItem(
        itemCode: matched.code,
        itemName: matched.name,
      );
      final normalizedGroup = matched.itemGroup.toLowerCase();
      return AdminItemDetail(
        code: matched.code,
        name: matched.name,
        uom: matched.uom,
        itemGroup: matched.itemGroup,
        isFinishedGoods: normalizedGroup.contains('tayyor') &&
            normalizedGroup.contains('mahsulot'),
        createdAtUnix: 0,
        updatedAtUnix: 0,
        customers: customers,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/items/detail',
        ).replace(queryParameters: {'code': code}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemDetailException(response);
    }
    return AdminItemDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminItemDetail> adminUpdateItem({
    required String originalCode,
    required String code,
    required String name,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final current = await adminItemDetail(originalCode);
      final updated = current.copyWith(
        code: code.trim(),
        name: name.trim(),
        updatedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      final originalKey = originalCode.trim().toLowerCase();
      final updatedKey = updated.code.toLowerCase();
      _testModeAdminItemDetailOverrides
        ..remove(originalKey)
        ..[updatedKey] = updated;
      if (originalKey != updatedKey) {
        _testModeDeletedAdminItemCodes.add(originalKey);
      }
      _testModeDeletedAdminItemCodes.remove(updatedKey);
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/items/detail'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'original_code': originalCode.trim(),
          'code': code.trim(),
          'name': name.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemDetailException(response);
    }
    return AdminItemDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminItemDetail> adminUpdateItemGroup({
    required String itemCode,
    required String itemGroup,
  }) async {
    final code = itemCode.trim();
    final group = itemGroup.trim();
    if (code.isEmpty || group.isEmpty) {
      throw const MobileApiException(
        code: 'item_group_update_invalid',
        message: 'Item va groupni tanlang',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final current = await adminItemDetail(code);
      final tree = await adminItemGroupTree();
      final requiresCustomer = adminItemGroupRequiresCustomer(group, tree);
      if (requiresCustomer && current.customers.isEmpty) {
        throw const MobileApiException(
          code: 'tayyor mahsulot uchun kamida bitta customer kerak',
          message: 'Tayyor mahsulot uchun kamida bitta customer kerak',
        );
      }
      final updated = current.copyWith(
        itemGroup: group,
        isFinishedGoods: requiresCustomer,
        updatedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _testModeAdminItemDetailOverrides[code.toLowerCase()] = updated;
      return updated;
    }
    final result = await adminMoveItemsToGroup(
      itemCodes: <String>[code],
      itemGroup: group,
    );
    final updated = result.failedCount == 0 &&
        result.updatedItemCodes.any(
          (itemCode) => itemCode.trim().toLowerCase() == code.toLowerCase(),
        );
    if (!updated) {
      throw const MobileApiException(
        code: 'item_group_update_failed',
        message: 'Item group o‘zgartirilmadi',
      );
    }
    return adminItemDetail(code);
  }

  Future<AdminItemDetail> adminSetItemCustomerAssigned({
    required String itemCode,
    required CustomerDirectoryEntry customer,
    required bool assigned,
  }) async {
    final code = itemCode.trim();
    final customerRef = customer.ref.trim();
    if (code.isEmpty || customerRef.isEmpty) {
      throw const MobileApiException(
        code: 'item_customer_update_invalid',
        message: 'Item va customerni tanlang',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final current = await adminItemDetail(code);
      final removesExistingCustomer = !assigned &&
          current.customers.any(
            (existing) =>
                existing.ref.trim().toLowerCase() == customerRef.toLowerCase(),
          );
      if (current.isFinishedGoods &&
          removesExistingCustomer &&
          current.customers.length <= 1) {
        throw const MobileApiException(
          code: 'tayyor mahsulot uchun kamida bitta customer kerak',
          message: 'Tayyor mahsulot uchun kamida bitta customer kerak',
        );
      }
      final customers = <CustomerDirectoryEntry>[
        for (final existing in current.customers)
          if (existing.ref.trim().toLowerCase() != customerRef.toLowerCase())
            existing,
        if (assigned) customer,
      ]..sort(
          (left, right) =>
              left.name.toLowerCase().compareTo(right.name.toLowerCase()),
        );
      final updated = current.copyWith(
        customers: List<CustomerDirectoryEntry>.unmodifiable(customers),
        updatedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _testModeAdminItemDetailOverrides[code.toLowerCase()] = updated;
      return updated;
    }
    if (assigned) {
      await adminAssignCustomerItem(ref: customerRef, itemCode: code);
    } else {
      await adminRemoveCustomerItem(ref: customerRef, itemCode: code);
    }
    return adminItemDetail(code);
  }

  Future<void> adminDeleteItem(String itemCode) async {
    final code = itemCode.trim();
    if (code.isEmpty) {
      throw const MobileApiException(
        code: 'item code is required',
        message: 'Item code kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final current = await adminItemDetail(code);
      final key = current.code.trim().toLowerCase();
      _testModeAdminItemDetailOverrides.remove(key);
      _testModeDeletedAdminItemCodes.add(key);
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/items/detail',
        ).replace(queryParameters: {'code': code}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminItemDeleteException(response);
    }
  }
}

List<AdminApparatus> _testModeApparatusCatalog() {
  final seen = <String>{};
  final overrides = {
    for (final apparatus in _testModeApparatus) apparatus.id.trim(): apparatus,
  };
  final items = [
    for (final apparatus in TestModeDemoData.apparatus)
      overrides.remove(apparatus.id.trim()) ?? apparatus,
    ...overrides.values,
  ];
  return items.indexed.where((entry) {
    final apparatus = entry.$2;
    final key = apparatus.id.trim();
    return key.isNotEmpty && seen.add(key);
  }).map((entry) {
    final index = entry.$1;
    final apparatus = entry.$2;
    final operation = apparatus.operation.trim();
    final technology = apparatus.technology.trim();
    final stableTestKey = 'catalog-${index.toString().padLeft(3, '0')}';
    return AdminApparatus(
      id: apparatus.id,
      name: apparatus.name,
      source: apparatus.source,
      sortOrder: apparatus.sortOrder == 10000 ? index : apparatus.sortOrder,
      family: apparatus.family,
      kind: apparatus.kind,
      capabilities: apparatus.capabilities,
      capabilityProfiles: apparatus.capabilityProfiles,
      colorStations: apparatus.colorStations,
      factoryMapObjectId: apparatus.factoryMapObjectId,
      trainingEnabled: apparatus.trainingEnabled,
      sourceRevision:
          apparatus.sourceRevision > 0 ? apparatus.sourceRevision : 1,
      sourceAasxSha256: apparatus.sourceAasxSha256,
      description: apparatus.description,
      equipmentClassId: apparatus.equipmentClassId.isNotEmpty
          ? apparatus.equipmentClassId
          : 'equipment-class:test:${operation.isEmpty ? 'package' : operation}',
      physicalAssetId: apparatus.physicalAssetId.isNotEmpty
          ? apparatus.physicalAssetId
          : 'physical-asset:test:$stableTestKey',
      enterpriseId: 'enterprise:accord',
      siteId: 'site:test',
      areaId: 'area:production',
      workCenterId: 'work-center:${operation.isEmpty ? 'package' : operation}',
      workUnitId: 'work-unit:test:$stableTestKey',
      operation: operation.isEmpty ? 'package' : operation,
      technology: technology.isEmpty ? 'bag_making' : technology,
      capabilityCompatibleReroute: true,
      trainingQueueEnabled: apparatus.trainingEnabled,
      trainingMaterialTrackingEnabled: apparatus.trainingEnabled,
    );
  }).toList(growable: false);
}

String _normalizedApparatusCollectionName(String value) {
  final name = value.trim();
  if (name.isEmpty) {
    throw const MobileApiException(
      code: 'apparatus_collection_name_required',
      message: 'Aparat guruhi nomi kiritilmadi',
    );
  }
  if (name.runes.length > 80) {
    throw const MobileApiException(
      code: 'apparatus_collection_name_too_long',
      message: 'Aparat guruhi nomi juda uzun',
    );
  }
  return name;
}

List<String> _normalizedApparatusCollectionIds(Iterable<String> values) {
  final raw = values.toList(growable: false);
  if (raw.length > 500) {
    throw const MobileApiException(
      code: 'apparatus_collection_too_many_apparatus',
      message: 'Aparat guruhida juda ko‘p aparat bor',
    );
  }
  final ids = <String>{};
  for (final value in raw) {
    final id = value.trim();
    if (!canonicalApparatusIdIsValid(id)) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Canonical apparat ID noto‘g‘ri',
      );
    }
    ids.add(id);
  }
  return List.unmodifiable(ids.toList()..sort());
}

void _testModeValidateApparatusCollectionMembers(List<String> apparatusIds) {
  final activeIds = {
    for (final apparatus in _testModeApparatusCatalog())
      if (apparatus.isActive) apparatus.id,
  };
  if (apparatusIds.any((id) => !activeIds.contains(id))) {
    throw const MobileApiException(
      code: 'apparatus_id_invalid',
      message: 'Canonical apparat ID noto‘g‘ri',
    );
  }
}

Uri _apparatusCollectionUri(String id) {
  return Uri.parse(
    '${MobileApi.baseUrl}/v1/mobile/admin/apparatus-collections/'
    '${Uri.encodeComponent(id.trim())}',
  );
}

MobileApiException _adminItemCreateException(http.Response response) {
  return _adminItemMutationException(
    response,
    fallbackCode: 'item_create_failed',
    fallbackMessage: 'Item yaratilmadi',
  );
}

MobileApiException _adminItemDeleteException(http.Response response) {
  return _adminItemMutationException(
    response,
    fallbackCode: 'item_delete_failed',
    fallbackMessage: 'Item o‘chirilmadi',
  );
}

MobileApiException _adminItemMutationException(
  http.Response response, {
  required String fallbackCode,
  required String fallbackMessage,
}) {
  var code = fallbackCode;
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
      }
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    statusCode: response.statusCode,
    message: switch (code) {
      'item code already exists' => 'Bu item code allaqachon mavjud',
      'item code is required' => 'Item code kiriting',
      'tayyor mahsulot uchun kamida bitta customer kerak' =>
        'Tayyor mahsulot uchun kamida bitta customer kerak',
      'customer_ref is required for tayyor mahsulot' =>
        'Tayyor mahsulot uchun customer tanlang',
      'customer not found' => 'Customer topilmadi',
      'item not found' => 'Item topilmadi',
      'item is used by active order' =>
        'Item faol buyurtmada ishlatilgan. Avval buyurtmani yakunlang yoki bekor qiling',
      'item has active stock' =>
        'Item bo‘yicha faol ombor qoldig‘i bor. Avval qoldiqni yakunlang',
      'item has pending receipt' => 'Item uchun yakunlanmagan qabul mavjud',
      'item is used by active rps batch' =>
        'Item faol RPS partiyasida ishlatilgan',
      'item is used by active qolip operation' =>
        'Item faol qolip jarayonida ishlatilgan',
      'item is used by quick order template' =>
        'Item tezkor buyurtma shablonida ishlatilgan',
      'item is used by unresolved material assignment' =>
        'Item yakunlanmagan material biriktirishda ishlatilgan',
      'item is still referenced' =>
        'Item boshqa ma’lumotlarga bog‘langanligi sababli o‘chirilmadi',
      _ => response.statusCode == 403
          ? 'Bu amal uchun admin huquqi kerak'
          : fallbackMessage,
    },
  );
}

MobileApiException _adminItemDetailException(http.Response response) {
  var code = 'item_update_failed';
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      code = (payload['error'] as String).trim();
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    statusCode: response.statusCode,
    message: switch (code) {
      'item not found' => 'Item topilmadi',
      'item code already exists' => 'Bu item code allaqachon mavjud',
      'item code is required' => 'Item code kiriting',
      'item name is required' => 'Item nomini kiriting',
      _ => response.statusCode == 403
          ? 'Itemni tahrirlash uchun admin huquqi kerak'
          : 'Item ma’lumotlari saqlanmadi',
    },
  );
}

MobileApiException _rawMaterialStockUpdateException(http.Response response) {
  var code = 'raw_material_stock_update_failed';
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
      }
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    statusCode: response.statusCode,
    message: switch (code) {
      'raw_material_stock_locked' =>
        'Bu homashyo zakazga to‘liq yoki qisman band qilingan. Uni tahrirlab bo‘lmaydi',
      'raw_material_stock_not_found' => 'Homashyo omborda topilmadi',
      'raw_material_stock_qty_invalid' => 'Miqdor musbat son bo‘lishi kerak',
      'raw_material_item_not_found' => 'Tanlangan mahsulot topilmadi',
      'raw_material_uom_mismatch' =>
        'Tanlangan mahsulotning o‘lchov birligi mos emas',
      'item group is not assigned to material taminotchi' =>
        'Bu mahsulot guruhi sizga biriktirilmagan',
      _ => 'Homashyo ma’lumotlarini o‘zgartirib bo‘lmadi',
    },
  );
}

MobileApiException _rawMaterialStockDeleteException(http.Response response) {
  var code = 'raw_material_stock_delete_failed';
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
      }
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    statusCode: response.statusCode,
    message: switch (code) {
      'raw_material_stock_locked' =>
        'Zakazga biriktirilgan, transferdagi yoki State’dagi homashyoni o‘chirib bo‘lmaydi',
      'raw_material_stock_not_found' => 'Homashyo omborda topilmadi',
      'forbidden' => 'Bu homashyo sizga biriktirilgan omborda emas',
      _ => 'Homashyoni o‘chirib bo‘lmadi',
    },
  );
}

class AdminRawMaterialStockReprintPreparation {
  const AdminRawMaterialStockReprintPreparation({
    required this.reprintId,
    required this.stock,
    required this.printRequest,
  });

  factory AdminRawMaterialStockReprintPreparation.fromJson(
    Map<String, dynamic> json,
  ) {
    final stockJson =
        (json['stock'] as Map?)?.cast<String, dynamic>() ?? const {};
    final printJson =
        (json['print'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdminRawMaterialStockReprintPreparation(
      reprintId: json['reprint_id']?.toString() ?? '',
      stock: AdminRawMaterialStockEntry.fromJson(stockJson),
      printRequest: UsbRpsPrintRequest.fromPrintJson(printJson),
    );
  }

  final String reprintId;
  final AdminRawMaterialStockEntry stock;
  final UsbRpsPrintRequest printRequest;
}

MobileApiException _rawMaterialStockReprintException(http.Response response) {
  var code = 'raw_material_stock_reprint_failed';
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
      }
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    statusCode: response.statusCode,
    message: switch (code) {
      'raw_material_stock_locked' =>
        'Bu homashyo zakazga to‘liq yoki qisman band qilingan. QR kodini qayta chop etib bo‘lmaydi',
      'raw_material_stock_not_found' => 'Homashyo omborda topilmadi',
      'forbidden' => 'Bu homashyo sizga biriktirilgan omborda emas',
      _ => 'QR kodini qayta chop etib bo‘lmadi',
    },
  );
}

List<AdminWarehouseSummary> _testModeWarehouseSummaries({
  required String query,
  required int limit,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  final warehouses = [...TestModeDemoData.warehouses, ..._testModeWarehouses]
      .where(
        (warehouse) =>
            !_testModeDeletedWarehouseNames.contains(
              warehouse.warehouse.trim().toLowerCase(),
            ) &&
            warehouse.parentWarehouse.trim().isEmpty,
      )
      .toList();
  final productCounts = <String, int>{};
  final stockWarehouseByBarcode = <String, String>{};

  void addProduct(String warehouse) {
    final normalized = warehouse.trim();
    if (normalized.isEmpty) {
      return;
    }
    productCounts[normalized] = (productCounts[normalized] ?? 0) + 1;
  }

  for (final stock in TestModeDemoData.warehouseStockItems) {
    if (stock.onHandQty > 0) {
      addProduct(stock.warehouse);
    }
  }
  for (final stock in TestModeDemoData.rawMaterialStock) {
    if (stock.status.trim().toLowerCase() != 'available' || stock.qty <= 0) {
      continue;
    }
    final inventoryAsset = _testModeInventoryAssets.where(
      (asset) =>
          asset.kind == InventoryAssetKind.rawMaterial &&
          asset.assetRef.trim().toLowerCase() == stock.id.trim().toLowerCase(),
    );
    if (inventoryAsset.isNotEmpty &&
        (inventoryAsset.first.physicalLocation.kind !=
                InventoryLocationKind.warehouse ||
            inventoryAsset.first.physicalLocation.name.trim().toLowerCase() !=
                stock.warehouse.trim().toLowerCase())) {
      continue;
    }
    addProduct(stock.warehouse);
    stockWarehouseByBarcode[stock.barcode.trim().toLowerCase()] =
        stock.warehouse.trim();
  }

  final reservedCounts = <String, int>{};
  for (final assignment in _testModeRawMaterialAssignments) {
    final warehouse =
        stockWarehouseByBarcode[assignment.barcode.trim().toLowerCase()] ?? '';
    if (warehouse.isEmpty) {
      continue;
    }
    reservedCounts[warehouse] = (reservedCounts[warehouse] ?? 0) + 1;
  }

  final assignmentsByWarehouse = <String, List<AdminWarehouseAssignment>>{};
  for (final assignment in _testModeWarehouseAssignments) {
    assignmentsByWarehouse
        .putIfAbsent(assignment.warehouse.trim(), () => [])
        .add(assignment);
  }

  final names = <String>{};
  for (final warehouse in warehouses) {
    names.add(warehouse.warehouse.trim());
  }
  names.addAll(productCounts.keys);
  names.addAll(reservedCounts.keys);
  names.addAll(assignmentsByWarehouse.keys);
  final summaries = names
      .where(
    (name) =>
        name.trim().isNotEmpty &&
        !_testModeDeletedWarehouseNames.contains(
          name.trim().toLowerCase(),
        ) &&
        (normalizedQuery.isEmpty ||
            name.toLowerCase().contains(normalizedQuery)),
  )
      .map((warehouse) {
    final assignments = assignmentsByWarehouse[warehouse] ?? const [];
    return AdminWarehouseSummary(
      warehouse: warehouse,
      productCount: productCounts[warehouse] ?? 0,
      reservedCount: reservedCounts[warehouse] ?? 0,
      assignmentCount: assignments.length,
      assignedDisplayNames: assignments
          .map(
            (item) => item.displayName.trim().isEmpty
                ? item.principalRef
                : item.displayName,
          )
          .toList(growable: false),
    );
  }).toList()
    ..sort(
      (left, right) => left.warehouse.toLowerCase().compareTo(
            right.warehouse.toLowerCase(),
          ),
    );
  return summaries.take(limit).toList(growable: false);
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
  return null;
}

String _nextCanonicalApparatusOpaqueKey() {
  _canonicalApparatusOpaqueCounter++;
  final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final counter = _canonicalApparatusOpaqueCounter.toRadixString(36);
  return '$micros-$counter';
}

Uri _canonicalApparatusUri(String apparatusId) {
  return Uri.parse(
    '${MobileApi.baseUrl}/v1/mobile/admin/apparatus/'
    '${Uri.encodeComponent(apparatusId.trim())}',
  );
}

String _canonicalOperationForFamily(String family) {
  return switch (family.trim().toLowerCase()) {
    'pechat' => 'print',
    'laminatsiya' => 'laminate',
    'rezka' => 'cut',
    'paket' => 'package',
    'kley' => 'glue',
    _ => '',
  };
}

String _canonicalTechnologyForKind(String kind) {
  return switch (kind.trim().toLowerCase()) {
    'color_pechat' => 'rotogravure',
    'flexo' => 'flexographic',
    'laminatsiya' => 'adhesive_lamination',
    'extruder_laminatsiya' => 'extrusion_lamination',
    'rezka' => 'slitting',
    'paket' => 'bag_making',
    'holodniy_kley' => 'cold_glue',
    _ => '',
  };
}

String _canonicalOperationForTechnology(String technology) {
  return switch (technology.trim().toLowerCase()) {
    'rotogravure' || 'flexographic' => 'print',
    'adhesive_lamination' || 'extrusion_lamination' => 'laminate',
    'slitting' => 'cut',
    'bag_making' => 'package',
    'cold_glue' => 'glue',
    _ => '',
  };
}

Map<String, dynamic> _canonicalApparatusDraft({
  required String name,
  required String operation,
  required String technology,
  required List<AdminApparatusCapabilityProfile> capabilities,
  required List<String> capabilityCodes,
  required int? colorStations,
  required String factoryMapObjectId,
  required bool trainingEnabled,
  required String opaqueKey,
}) {
  final capabilityLevels = {
    for (final profile in capabilities) profile.code: profile.level,
  };
  final effectiveCodes = <String>{
    ...capabilityCodes,
    operation,
    if (trainingEnabled) 'training',
  }.toList(growable: false)
    ..sort();
  return {
    'display': {
      'display_name': name,
      'description': '',
      'catalog_order': 10000,
    },
    'equipment_class_id': 'equipment-class:mini-rs-erp:$operation:$technology',
    'physical_asset_id': 'physical-asset:mobile:$opaqueKey',
    'hierarchy': {
      'enterprise_id': 'enterprise:accord',
      'site_id': 'site:main',
      'area_id': 'area:production',
      'work_center_id': 'work-center:$operation',
      'work_unit_id': 'work-unit:mobile:$opaqueKey',
    },
    'capabilities': [
      for (final code in effectiveCodes)
        {'code': code, 'level': capabilityLevels[code] ?? 1},
    ],
    'execution_profile': {
      'operation': operation,
      'technology': technology,
      'color_station_count': colorStations,
      'virtual_tasks': 'disabled',
      'capability_compatible_reroute': true,
    },
    'policies': {
      'queue': 'strict_sequence',
      'material': {'mode': 'not_required'},
      'tooling': {'mode': 'not_required'},
    },
    'capacity': {
      'capacity_slots': 1,
      'setup_minutes': 0,
      'cleanup_minutes': 0,
      'efficiency_percent': 100,
      'finite_capacity': true,
      'availability': {'mode': 'always'},
    },
    'placement': factoryMapObjectId.isEmpty
        ? null
        : {'factory_map_object_id': factoryMapObjectId},
    'training': {
      'enabled': trainingEnabled,
      'queue_enabled': trainingEnabled,
      'material_tracking_enabled': trainingEnabled,
    },
    'lifecycle': {'state': 'active', 'retirement_reason': null},
  };
}
