part of '../mobile_api.dart';

extension MobileApiAdminItems on MobileApi {
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
      throw Exception('Admin customer item add failed');
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
      throw Exception('Admin customer item remove failed');
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
      return TestModeDemoData.itemPage(
        query: query,
        group: group,
        limit: limit,
        offset: offset,
      );
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => AdminWarehouseStockItem.fromJson(
            item as Map<String, dynamic>,
          ),
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
      return [
        ...TestModeDemoData.warehouses,
        ..._testModeWarehouses,
        ..._testModeApparatusWarehouses,
      ]
          .where(
            (warehouse) =>
                !_testModeDeletedWarehouseNames
                    .contains(warehouse.warehouse.trim().toLowerCase()) &&
                (normalized.isEmpty ||
                    warehouse.warehouse.toLowerCase().contains(normalized)) &&
                (normalizedParent.isEmpty ||
                    warehouse.parentWarehouse.toLowerCase() ==
                        normalizedParent),
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => AdminWarehouse.fromJson(item as Map<String, dynamic>))
        .toList();
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/warehouses/summary')
            .replace(
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) =>
            AdminWarehouseSummary.fromJson(item as Map<String, dynamic>))
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-stock')
            .replace(
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) =>
            AdminRawMaterialStockEntry.fromJson(item as Map<String, dynamic>))
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
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
            '${MobileApi.baseUrl}/v1/mobile/admin/warehouses/assignments'),
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

  Future<AdminWarehouse> adminCreateApparatus(String warehouse) async {
    final name = warehouse.trim();
    if (name.isEmpty) {
      throw Exception('Admin apparatus name required');
    }
    if (await TestModeController.instance.isEnabled()) {
      final item = AdminWarehouse(
        warehouse: name,
        company: '',
        isGroup: false,
        parentWarehouse: 'aparat - A',
      );
      final index = _testModeApparatusWarehouses.indexWhere(
        (existing) => existing.warehouse.toLowerCase() == name.toLowerCase(),
      );
      if (index >= 0) {
        _testModeApparatusWarehouses[index] = item;
      } else {
        _testModeApparatusWarehouses.add(item);
      }
      _testModeApparatusWarehouses.sort(
        (left, right) => left.warehouse.toLowerCase().compareTo(
              right.warehouse.toLowerCase(),
            ),
      );
      return item;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/apparatus'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'warehouse': name}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin apparatus create failed');
    }
    return AdminWarehouse.fromJson(
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
      throw Exception('Admin item group bulk move failed');
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
      throw Exception('Admin item create failed');
    }
    return SupplierItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
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
  final warehouses = [
    ...TestModeDemoData.warehouses,
    ..._testModeWarehouses,
  ]
      .where(
        (warehouse) =>
            !_testModeDeletedWarehouseNames
                .contains(warehouse.warehouse.trim().toLowerCase()) &&
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
      .where((name) =>
          name.trim().isNotEmpty &&
          !_testModeDeletedWarehouseNames.contains(name.trim().toLowerCase()) &&
          (normalizedQuery.isEmpty ||
              name.toLowerCase().contains(normalizedQuery)))
      .map((warehouse) {
    final assignments = assignmentsByWarehouse[warehouse] ?? const [];
    return AdminWarehouseSummary(
      warehouse: warehouse,
      productCount: productCounts[warehouse] ?? 0,
      reservedCount: reservedCounts[warehouse] ?? 0,
      assignmentCount: assignments.length,
      assignedDisplayNames: assignments
          .map((item) => item.displayName.trim().isEmpty
              ? item.principalRef
              : item.displayName)
          .toList(growable: false),
    );
  }).toList()
    ..sort(
      (left, right) =>
          left.warehouse.toLowerCase().compareTo(right.warehouse.toLowerCase()),
    );
  return summaries.take(limit).toList(growable: false);
}
