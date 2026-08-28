part of '../mobile_api.dart';

extension MobileApiAdminSuppliersCustomers on MobileApi {
Future<AdminSuppliersPage> adminSuppliersPage() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminSuppliersPage(
        summary: TestModeDemoData.supplierSummary,
        suppliers: TestModeDemoData.suppliers,
        customers: TestModeDemoData.customers,
        settings: TestModeDemoData.adminSettings,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/suppliers'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin suppliers page failed');
    }
    return AdminSuppliersPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<AdminSupplier>> adminSuppliers({
    int limit = 20,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierPage(limit: limit, offset: offset);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/suppliers/list').replace(
          queryParameters: {
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin suppliers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminSupplier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

Future<AdminSupplierSummary> adminSupplierSummary() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierSummary;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/suppliers/summary'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier summary failed');
    }
    return AdminSupplierSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<AdminSupplier>> adminInactiveSuppliers() async {
    if (await TestModeController.instance.isEnabled()) {
      return const <AdminSupplier>[];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/suppliers/inactive'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin inactive suppliers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminSupplier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

Future<AdminSupplierDetail> adminSupplierDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierDetail(ref);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/detail',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier detail failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminCustomerDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.customerDetail(ref);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/customers/detail',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer detail failed');
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminMaterialTaminotchiDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalizedRef = ref.trim().toLowerCase();
      final assignedWarehouses = _testModeWarehouseAssignments
          .where(
            (assignment) =>
                assignment.principalRole == UserRole.materialTaminotchi &&
                assignment.principalRef.trim().toLowerCase() == normalizedRef,
          )
          .map((assignment) => assignment.warehouse.trim())
          .where((warehouse) => warehouse.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
      return TestModeDemoData.customerDetail(ref).copyWith(
        ref: ref.trim(),
        assignedItemGroups:
            _testModeMaterialItemGroups[normalizedRef] ?? const [],
        assignedWarehouses: assignedWarehouses,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/material-taminotchilar/detail',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin material taminotchi detail failed');
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> _adminMaterialTaminotchiDetailFromPayload(
    String ref,
    Map<String, dynamic> payload,
  ) async {
    var detail = AdminCustomerDetail.fromJson(payload);
    final normalizedRef = ref.trim().toLowerCase();

    // Older test backends do not expose scopes on the profile detail DTO.
    // Hydrate them through the stable assignment APIs until every runtime is
    // upgraded to the richer response contract.
    if (!payload.containsKey('assigned_item_groups')) {
      final assignments = await adminRoleAssignments();
      final assignedGroups = <String>[];
      for (final assignment in assignments) {
        if (_isMaterialRoleAssignmentForRef(assignment, normalizedRef)) {
          assignedGroups.addAll(assignment.assignedItemGroups);
          break;
        }
      }
      detail = detail.copyWith(
        assignedItemGroups: _normalizedAdminScopeValues(assignedGroups),
      );
    }

    if (!payload.containsKey('assigned_warehouses')) {
      final assignments = await adminWarehouseAssignments();
      detail = detail.copyWith(
        assignedWarehouses: _normalizedAdminScopeValues(
          assignments
              .where(
                (assignment) =>
                    assignment.principalRole == UserRole.materialTaminotchi &&
                    assignment.principalRef.trim().toLowerCase() ==
                        normalizedRef,
              )
              .map((assignment) => assignment.warehouse),
        ),
      );
    }
    return detail;
  }

Future<AdminCustomerDetail> adminUpdateMaterialTaminotchiPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/material-taminotchilar/phone',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin material taminotchi phone update failed');
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminRegenerateMaterialTaminotchiCode(
    String ref,
  ) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/material-taminotchilar/code/regenerate',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin material taminotchi code regenerate failed');
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminUpdateMaterialTaminotchiItemGroups({
    required String ref,
    required List<String> assignedItemGroups,
  }) async {
    final normalizedGroups = _normalizedAdminScopeValues(assignedItemGroups);
    if (normalizedGroups.isEmpty) {
      throw const MobileApiException(
        code: 'material_item_groups_required',
        message: 'Kamida bitta mahsulot guruhini tanlang',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      _testModeMaterialItemGroups[ref.trim().toLowerCase()] = normalizedGroups;
      return (await adminMaterialTaminotchiDetail(
        ref,
      ))
          .copyWith(assignedItemGroups: normalizedGroups);
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/material-taminotchilar/item-groups',
        ).replace(queryParameters: {'ref': ref.trim()}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'assigned_item_groups': normalizedGroups}),
      ),
    );
    if (response.statusCode == 404) {
      final normalizedRef = ref.trim().toLowerCase();
      AdminRoleAssignment? existing;
      for (final assignment in await adminRoleAssignments()) {
        if (_isMaterialRoleAssignmentForRef(assignment, normalizedRef)) {
          existing = assignment;
          break;
        }
      }
      await adminUpsertRoleAssignment(
        AdminRoleAssignment(
          principalRole: UserRole.materialTaminotchi,
          principalRef: ref.trim(),
          roleId: existing == null || existing.roleId.trim().isEmpty
              ? 'material_taminotchi'
              : existing.roleId,
          assignedApparatus: existing?.assignedApparatus ?? const [],
          assignedItemGroups: normalizedGroups,
        ),
      );
      return adminMaterialTaminotchiDetail(ref);
    }
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_material_item_groups_update_failed',
        fallbackMessage: 'Mahsulot guruhlari saqlanmadi',
      );
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminUpdateCustomerPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/customers/phone',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer phone update failed');
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminRegenerateCustomerCode(String ref) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/customers/code/regenerate',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer code regenerate failed');
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<void> adminRemoveCustomer(String ref) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/customers/remove',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer remove failed');
    }
  }

Future<AdminSupplier> adminCreateSupplier({
    required String name,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/suppliers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier create failed');
    }
    return AdminSupplier.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<CustomerDirectoryEntry> adminCreateCustomer({
    required String name,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/customers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_customer_create_failed',
        fallbackMessage: 'Foydalanuvchi yaratilmadi',
      );
    }
    return CustomerDirectoryEntry.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminCustomerDetail> adminCreateMaterialTaminotchi({
    required String name,
    required String phone,
    required List<String> assignedItemGroups,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/material-taminotchilar'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'assigned_item_groups': assignedItemGroups,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_material_taminotchi_create_failed',
        fallbackMessage: 'Foydalanuvchi yaratilmadi',
      );
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<CustomerDirectoryEntry>> adminCustomers({
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.customerPage(limit: limit, offset: offset);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/customers/list').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              CustomerDirectoryEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

Future<AdminSupplierDetail> adminSetSupplierBlocked({
    required String ref,
    required bool blocked,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/status',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'blocked': blocked}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier status failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSupplierDetail> adminUpdateSupplierPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/phone',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier phone update failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSupplierDetail> adminRegenerateSupplierCode(String ref) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/code/regenerate',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier code regenerate failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSupplierDetail> adminUpdateSupplierItems({
    required String ref,
    required List<String> itemCodes,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/items',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'item_codes': itemCodes}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier item update failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<SupplierItem>> adminAssignedSupplierItems(String ref) async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/items/assigned',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin assigned supplier items failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

Future<AdminSupplierDetail> adminAssignSupplierItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/items/add',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'item_code': itemCode}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin assign supplier item failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSupplierDetail> adminRemoveSupplierItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/items/remove',
        ).replace(queryParameters: {'ref': ref, 'item_code': itemCode}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin remove supplier item failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<void> adminRemoveSupplier(String ref) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/remove',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier remove failed');
    }
  }

Future<AdminSupplierDetail> adminRestoreSupplier(String ref) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/suppliers/restore',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier restore failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
