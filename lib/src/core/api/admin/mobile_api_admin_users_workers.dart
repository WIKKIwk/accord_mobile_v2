part of '../mobile_api.dart';

void resetMobileApiTestModeWorkerSettingsData() {
  _testModeWorkers.clear();
  _testModeWorkerGroups.clear();
  _testModeRoleAssignments
    ..clear()
    ..addAll(TestModeDemoData.roleAssignments);
  _testModeWorkerCodes.clear();
  _testModeSystemUsers.clear();
  _testModeSystemUserCodes.clear();
}

String _adminWarehouseRoleToJson(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.supplier:
      return 'supplier';
    case UserRole.werka:
      return 'werka';
    case UserRole.customer:
      return 'customer';
    case UserRole.aparatchi:
      return 'aparatchi';
    case UserRole.qolipchi:
      return 'qolipchi';
    case UserRole.boyoqchi:
      return 'boyoqchi';
    case UserRole.materialTaminotchi:
      return 'material_taminotchi';
  }
}

bool _isMaterialRoleAssignmentForRef(
  AdminRoleAssignment assignment,
  String normalizedRef,
) {
  return assignment.principalRole == UserRole.materialTaminotchi &&
      assignment.principalRef.trim().toLowerCase() == normalizedRef;
}

class AdminQueueWorkerInteraction {
  const AdminQueueWorkerInteraction({
    required this.mode,
    required this.startMaterialsMode,
    required this.materialScanRequired,
    required this.assignedMaterialsDisplayOnly,
    required this.materialIntakeAllowed,
    required this.previousWipMode,
    required this.qolipMode,
    this.openingWipMode = AdminQueuePreviousWipMode.notRequired,
    this.blockingReasonCode = '',
  });

  final AdminQueueInteractionMode mode;
  final AdminQueueStartMaterialsMode startMaterialsMode;
  final bool materialScanRequired;
  final bool assignedMaterialsDisplayOnly;
  final bool materialIntakeAllowed;
  final AdminQueuePreviousWipMode previousWipMode;
  final AdminQueueQolipMode qolipMode;
  final AdminQueuePreviousWipMode openingWipMode;
  final String blockingReasonCode;

  static AdminQueueWorkerInteraction? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final mode = AdminQueueInteractionMode.tryParse(json['mode']);
    final startMaterialsMode = AdminQueueStartMaterialsMode.tryParse(
      json['start_materials_mode'],
    );
    final previousWipMode = AdminQueuePreviousWipMode.tryParse(
      json['previous_wip_mode'],
    );
    final rawOpeningWipMode = json['opening_wip_mode'];
    final openingWipMode = rawOpeningWipMode == null
        ? AdminQueuePreviousWipMode.notRequired
        : AdminQueuePreviousWipMode.tryParse(rawOpeningWipMode);
    final qolipMode = AdminQueueQolipMode.tryParse(json['qolip_mode']);
    if (mode == null ||
        startMaterialsMode == null ||
        previousWipMode == null ||
        openingWipMode == null ||
        qolipMode == null ||
        json['material_scan_required'] is! bool ||
        json['assigned_materials_display_only'] is! bool ||
        json['material_intake_allowed'] is! bool) {
      return null;
    }
    return AdminQueueWorkerInteraction(
      mode: mode,
      startMaterialsMode: startMaterialsMode,
      materialScanRequired: json['material_scan_required'] as bool,
      assignedMaterialsDisplayOnly:
          json['assigned_materials_display_only'] as bool,
      materialIntakeAllowed: json['material_intake_allowed'] as bool,
      previousWipMode: previousWipMode,
      qolipMode: qolipMode,
      openingWipMode: openingWipMode,
      blockingReasonCode: json['blocking_reason_code']?.toString().trim() ?? '',
    );
  }
}

class AdminWorkerRunSession {
  const AdminWorkerRunSession({
    required this.sessionId,
    required this.apparatus,
    required this.orderId,
    required this.status,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    required this.startedAtUnix,
    required this.updatedAtUnix,
    this.payloadJson = const {},
  });

  final String sessionId;
  final String apparatus;
  final String orderId;
  final String status;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final int startedAtUnix;
  final int updatedAtUnix;
  final Map<String, dynamic> payloadJson;

  factory AdminWorkerRunSession.fromJson(Map<String, dynamic> json) {
    return AdminWorkerRunSession(
      sessionId: json['session_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
      payloadJson: _jsonObject(json['payload_json']),
    );
  }
}

class AdminWorkerProfileDetail {
  const AdminWorkerProfileDetail({
    required this.worker,
    this.assignedApparatus = const [],
    required this.assignedGroups,
    required this.activeSessions,
    required this.recentBatches,
    required this.recentLogs,
  });

  final AdminWorkerDetail worker;
  final List<String> assignedApparatus;
  final List<AdminWorkerGroup> assignedGroups;
  final List<AdminWorkerRunSession> activeSessions;
  final List<AdminProgressBatch> recentBatches;
  final List<AdminProductionOrderLogEntry> recentLogs;

  factory AdminWorkerProfileDetail.fromJson(Map<String, dynamic> json) {
    return AdminWorkerProfileDetail(
      worker: AdminWorkerDetail.fromJson(
        (json['worker'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      assignedApparatus: _requireCanonicalApparatusIdList(
        json['assigned_apparatus'],
      ),
      assignedGroups: [
        for (final item in (json['assigned_groups'] as List? ?? const []))
          AdminWorkerGroup.fromJson((item as Map).cast<String, dynamic>()),
      ],
      activeSessions: [
        for (final item in (json['active_sessions'] as List? ?? const []))
          AdminWorkerRunSession.fromJson((item as Map).cast<String, dynamic>()),
      ],
      recentBatches: [
        for (final item in (json['recent_batches'] as List? ?? const []))
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
      ],
      recentLogs: [
        for (final item in (json['recent_logs'] as List? ?? const []))
          AdminProductionOrderLogEntry.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
    );
  }
}

class AdminWorkerDeletionDependency {
  const AdminWorkerDeletionDependency({
    required this.kind,
    required this.label,
    required this.apparatus,
    required this.orderId,
    required this.status,
  });

  final String kind;
  final String label;
  final String apparatus;
  final String orderId;
  final String status;

  factory AdminWorkerDeletionDependency.fromJson(Map<String, dynamic> json) {
    return AdminWorkerDeletionDependency(
      kind: json['kind']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class AdminWorkerDeletionCheck {
  const AdminWorkerDeletionCheck({
    required this.workerId,
    required this.workerName,
    required this.blocked,
    required this.requiresConfirmation,
    required this.activeWork,
    required this.connections,
  });

  final String workerId;
  final String workerName;
  final bool blocked;
  final bool requiresConfirmation;
  final List<AdminWorkerDeletionDependency> activeWork;
  final List<AdminWorkerDeletionDependency> connections;

  factory AdminWorkerDeletionCheck.fromJson(Map<String, dynamic> json) {
    return AdminWorkerDeletionCheck(
      workerId: json['worker_id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? '',
      blocked: json['blocked'] == true,
      requiresConfirmation: json['requires_confirmation'] == true,
      activeWork: [
        for (final item in (json['active_work'] as List? ?? const []))
          AdminWorkerDeletionDependency.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      connections: [
        for (final item in (json['connections'] as List? ?? const []))
          AdminWorkerDeletionDependency.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
    );
  }
}

class AdminWorkerDeletionRejected implements Exception {
  const AdminWorkerDeletionRejected(this.check);

  final AdminWorkerDeletionCheck check;

  @override
  String toString() => check.blocked
      ? 'Ishchining faol ishi mavjud'
      : 'Mavjud ulanishlarni tasdiqlash kerak';
}

class AdminApparatusCapabilityRequirement {
  const AdminApparatusCapabilityRequirement({
    required this.code,
    this.minLevel = 1,
  });

  final String code;
  final int minLevel;

  factory AdminApparatusCapabilityRequirement.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminApparatusCapabilityRequirement(
      code: json['code']?.toString().trim() ?? '',
      minLevel: (json['min_level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {'code': code.trim(), 'min_level': minLevel};
}

extension MobileApiAdminUsersWorkers on MobileApi {
Future<List<AdminRoleDefinition>> adminRoles() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.roles;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/roles'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin roles failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRoleDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

Future<AdminRoleDefinition> adminUpsertRole(AdminRoleDefinition role) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/roles'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(role.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin role save failed');
    }
    return AdminRoleDefinition.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<AdminRoleAssignment>> adminRoleAssignments() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminRoleAssignment>.unmodifiable(_testModeRoleAssignments);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/role-assignments'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin role assignments failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRoleAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

Future<List<AdminWorker>> adminWorkers({
    String query = '',
    String role = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final needle = query.trim().toLowerCase();
      return _testModeWorkers
          .where(
            (worker) =>
                needle.isEmpty ||
                worker.name.toLowerCase().contains(needle) ||
                worker.level.toLowerCase().contains(needle),
          )
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/workers').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (role.trim().isNotEmpty) 'role': role.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin workers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminWorker.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

Future<AdminWorker> adminCreateWorker({
    required String name,
    required String level,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = AdminWorker(
        id: 'worker-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: '',
        level: level.trim(),
      );
      _testModeWorkers.add(worker);
      return worker;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'level': level}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker create failed');
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSystemUser> adminCreateSystemUser({
    required UserRole role,
    required String name,
    required String phone,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      if (role != UserRole.qolipchi &&
          role != UserRole.boyoqchi &&
          role != UserRole.materialTaminotchi) {
        throw Exception('Unsupported system user role');
      }
      final user = AdminSystemUser(
        id: '${userRoleToJson(role)}-${DateTime.now().microsecondsSinceEpoch}',
        role: role,
        name: name.trim(),
        phone: phone.trim(),
      );
      _testModeSystemUsers.add(user);
      return user;
    }
    if (role != UserRole.qolipchi && role != UserRole.boyoqchi) {
      throw Exception('Unsupported system user role');
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/system-users'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'role': userRoleToJson(role),
          'name': name,
          'phone': phone,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user create failed');
    }
    return AdminSystemUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSystemUser> adminUpdateSystemUserPhone({
    required String id,
    required UserRole role,
    required String name,
    required String phone,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeSystemUsers.indexWhere((user) => user.id == id);
      if (index < 0) throw Exception('Admin system user not found');
      final updated = _testModeSystemUsers[index].copyWith(phone: phone.trim());
      _testModeSystemUsers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/system-users'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'id': id,
          'role': userRoleToJson(role),
          'name': name,
          'phone': phone,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user phone update failed');
    }
    return AdminSystemUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSystemUserDetail> adminSystemUserDetail(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final user = _testModeSystemUsers.firstWhere(
        (user) => user.id == id,
        orElse: () => throw Exception('Admin system user not found'),
      );
      return AdminSystemUserDetail(
        id: user.id,
        role: user.role,
        name: user.name,
        phone: user.phone,
        avatarUrl: '',
        code: _testModeSystemUserCodes[user.id] ?? '',
        blocked: false,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/system-users/detail',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user detail failed');
    }
    return AdminSystemUserDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminSystemUserDetail> adminRegenerateSystemUserCode(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final user = _testModeSystemUsers.firstWhere(
        (user) => user.id == id,
        orElse: () => throw Exception('Admin system user not found'),
      );
      final prefix = user.role == UserRole.boyoqchi ? '80' : '50';
      final code =
          '$prefix${DateTime.now().microsecondsSinceEpoch.toString().padLeft(10, '0').substring(0, 10)}';
      _testModeSystemUserCodes[id] = code;
      return AdminSystemUserDetail(
        id: user.id,
        role: user.role,
        name: user.name,
        phone: user.phone,
        avatarUrl: '',
        code: code,
        blocked: false,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/system-users/code/regenerate',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user code regenerate failed');
    }
    return AdminSystemUserDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminWorker> adminUpdateWorkerLevel({
    required String id,
    required String level,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWorkers.indexWhere((worker) => worker.id == id);
      if (index < 0) {
        throw Exception('Admin worker not found');
      }
      final updated = _testModeWorkers[index].copyWith(level: level.trim());
      _testModeWorkers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'name': '', 'level': level}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker level update failed');
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminWorker> adminUpdateWorkerName({
    required String id,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Admin worker name is required');
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWorkers.indexWhere((worker) => worker.id == id);
      if (index < 0) {
        throw Exception('Admin worker not found');
      }
      final updated = _testModeWorkers[index].copyWith(name: trimmedName);
      _testModeWorkers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'name': trimmedName}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_worker_name_update_failed',
        fallbackMessage: 'Ishchi ismi saqlanmadi',
      );
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminWorker> adminUpdateWorkerPhone({
    required String id,
    required String phone,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWorkers.indexWhere((worker) => worker.id == id);
      if (index < 0) {
        throw Exception('Admin worker not found');
      }
      final updated = _testModeWorkers[index].copyWith(phone: phone.trim());
      _testModeWorkers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_worker_phone_update_failed',
        fallbackMessage: 'Ishchi telefoni saqlanmadi',
      );
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminWorkerDetail> adminWorkerDetail(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = _testModeWorkers.firstWhere(
        (worker) => worker.id == id,
        orElse: () => throw Exception('Admin worker not found'),
      );
      return AdminWorkerDetail(
        id: worker.id,
        name: worker.name,
        phone: worker.phone,
        avatarUrl: '',
        level: worker.level,
        code: _testModeWorkerCodes[worker.id] ?? '',
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/workers/detail',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker detail failed');
    }
    return AdminWorkerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminWorkerProfileDetail> adminWorkerProfileDetail(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = await adminWorkerDetail(id);
      final groups = _testModeWorkerGroups
          .where((group) => group.workerIds.any((workerId) => workerId == id))
          .map(_hydrateTestModeWorkerGroup)
          .toList(growable: false);
      return AdminWorkerProfileDetail(
        worker: worker,
        assignedGroups: groups,
        activeSessions: const [],
        recentBatches: const [],
        recentLogs: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/workers/profile-detail',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker profile detail failed');
    }
    return AdminWorkerProfileDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<AdminWorkerDeletionCheck> adminWorkerDeletionCheck(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = _testModeWorkers.firstWhere(
        (worker) => worker.id == id,
        orElse: () => throw Exception('Admin worker not found'),
      );
      final groups = _testModeWorkerGroups.where(
        (group) => group.workerIds.any((workerId) => workerId == id),
      );
      final apparatuses = groups
          .map((group) => group.apparatus.trim())
          .where(
            (apparatus) =>
                apparatus.isNotEmpty && apparatus != 'worker-settings',
          )
          .toSet();
      final connections = <AdminWorkerDeletionDependency>[
        for (final group in groups)
          AdminWorkerDeletionDependency(
            kind: 'worker_group',
            label: group.groupCode,
            apparatus: group.apparatus,
            orderId: '',
            status: '',
          ),
        for (final apparatus in apparatuses)
          AdminWorkerDeletionDependency(
            kind: 'apparatus',
            label: apparatus,
            apparatus: apparatus,
            orderId: '',
            status: '',
          ),
      ];
      return AdminWorkerDeletionCheck(
        workerId: worker.id,
        workerName: worker.name,
        blocked: false,
        requiresConfirmation: connections.isNotEmpty,
        activeWork: const [],
        connections: connections,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/workers/delete-check',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'worker_delete_check_failed',
        fallbackMessage: 'Ishchi ulanishlari tekshirilmadi',
      );
    }
    return AdminWorkerDeletionCheck.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

Future<void> adminDeactivateWorker({
    required String id,
    required bool confirmConnections,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final check = await adminWorkerDeletionCheck(id);
      if (check.blocked || check.requiresConfirmation && !confirmConnections) {
        throw AdminWorkerDeletionRejected(check);
      }
      for (var index = 0; index < _testModeWorkerGroups.length; index++) {
        final group = _testModeWorkerGroups[index];
        _testModeWorkerGroups[index] = group.copyWith(
          workerIds: group.workerIds
              .where((workerId) => workerId != id)
              .toList(growable: false),
        );
      }
      final workerExists = _testModeWorkers.any((worker) => worker.id == id);
      if (!workerExists) {
        throw Exception('Admin worker not found');
      }
      _testModeWorkers.removeWhere((worker) => worker.id == id);
      _testModeRoleAssignments.removeWhere(
        (assignment) =>
            assignment.principalRole == UserRole.aparatchi &&
            assignment.principalRef.trim() == id.trim(),
      );
      _testModeWorkerCodes.remove(id);
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/workers').replace(
          queryParameters: {
            'id': id,
            if (confirmConnections) 'confirm_connections': 'true',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode == 409) {
      throw AdminWorkerDeletionRejected(
        AdminWorkerDeletionCheck.fromJson(
          (jsonDecode(response.body) as Map).cast<String, dynamic>(),
        ),
      );
    }
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'worker_delete_failed',
        fallbackMessage: 'Ishchi faolsizlantirilmadi',
      );
    }
  }

Future<AdminWorkerDetail> adminRegenerateWorkerCode(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = _testModeWorkers.firstWhere(
        (worker) => worker.id == id,
        orElse: () => throw Exception('Admin worker not found'),
      );
      final code =
          '40${DateTime.now().microsecondsSinceEpoch.toString().padLeft(10, '0').substring(0, 10)}';
      _testModeWorkerCodes[worker.id] = code;
      return AdminWorkerDetail(
        id: worker.id,
        name: worker.name,
        phone: worker.phone,
        avatarUrl: '',
        level: worker.level,
        code: code,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/workers/code/regenerate',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker code regenerate failed');
    }
    return AdminWorkerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

Future<List<AdminWorkerGroup>> adminWorkerGroups({
    String apparatusId = '',
  }) async {
    final normalizedApparatusId = _requireCanonicalApparatusId(
      apparatusId,
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      final key = normalizedApparatusId;
      return _testModeWorkerGroups
          .where(
            (group) => key.isEmpty || group.apparatusId.trim() == key,
          )
          .map(_hydrateTestModeWorkerGroup)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/worker-groups').replace(
          queryParameters: {
            if (normalizedApparatusId.isNotEmpty)
              'apparatus_id': normalizedApparatusId,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker groups failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminWorkerGroup.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

Future<AdminWorkerGroup> adminSaveWorkerGroup(
    AdminWorkerGroup group, {
    String? previousApparatusId,
    String? previousGroupCode,
  }) async {
    _requireCanonicalApparatusId(group.apparatusId);
    final validatedPreviousApparatusId = _requireCanonicalApparatusId(
      previousApparatusId ?? '',
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      final normalized = _normalizeTestModeWorkerGroup(group);
      final key = normalized.apparatusId.trim();
      final code = normalized.groupCode.trim().toUpperCase();
      final previousKey = previousApparatusId?.trim();
      final previousCode = previousGroupCode == null
          ? null
          : previousGroupCode
              .trim()
              .split(RegExp(r'\s+'))
              .join(' ')
              .toUpperCase();
      final hasPreviousIdentity = previousKey != null &&
          previousKey.isNotEmpty &&
          previousCode != null &&
          previousCode.isNotEmpty;
      final previousExists = !hasPreviousIdentity ||
          _testModeWorkerGroups.any(
            (item) =>
                item.apparatusId.trim() == previousKey &&
                item.groupCode.trim().toUpperCase() == previousCode,
          );
      if (!previousExists) {
        throw const MobileApiException(
          code: 'worker_group_not_found',
          message: 'Guruh topilmadi',
        );
      }
      final isPreviousGroup = (AdminWorkerGroup item) {
        if (hasPreviousIdentity) {
          return item.apparatusId.trim() == previousKey &&
              item.groupCode.trim().toUpperCase() == previousCode;
        }
        return item.apparatusId.trim() == key &&
            item.groupCode.trim().toUpperCase() == code;
      };
      final duplicateName = _testModeWorkerGroups.any(
        (item) =>
            item.apparatusId.trim() == key &&
            item.groupCode.trim().toUpperCase() == code &&
            !isPreviousGroup(item),
      );
      if (duplicateName) {
        throw const MobileApiException(
          code: 'worker_group_name_exists',
          message: 'Bu guruh nomi allaqachon bor',
        );
      }
      final duplicate = _testModeWorkerGroups.any(
        (item) =>
            item.apparatusId.trim() == key &&
            !isPreviousGroup(item) &&
            item.workerIds.any(normalized.workerIds.toSet().contains),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'worker_duplicated_in_group',
          message: 'Ishchi boshqa guruhga ulangan',
        );
      }
      _testModeWorkerGroups.removeWhere(isPreviousGroup);
      _testModeWorkerGroups.add(normalized);
      return _hydrateTestModeWorkerGroup(normalized);
    }
    final payload = group.toJson();
    final normalizedPreviousApparatusId = validatedPreviousApparatusId;
    final normalizedPreviousGroupCode = previousGroupCode?.trim() ?? '';
    if (normalizedPreviousApparatusId.isNotEmpty) {
      payload['previous_apparatus_id'] = normalizedPreviousApparatusId;
    }
    if (normalizedPreviousGroupCode.isNotEmpty) {
      payload['previous_group_code'] = normalizedPreviousGroupCode;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/worker-groups'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(payload),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker group save failed');
    }
    return AdminWorkerGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

AdminWorkerGroup _normalizeTestModeWorkerGroup(AdminWorkerGroup group) {
    final canonical = _testModeRequiredApparatus(group.apparatusId);
    final workerIds = group.workerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final groupCode =
        group.groupCode.trim().split(RegExp(r'\s+')).join(' ').toUpperCase();
    return AdminWorkerGroup(
      apparatus: canonical.name.trim(),
      apparatusId: canonical.id.trim(),
      groupCode: groupCode,
      shift: group.shift.trim().isEmpty ? 'kunduz' : group.shift.trim(),
      startTime:
          group.startTime.trim().isEmpty ? '08:00' : group.startTime.trim(),
      endTime: group.endTime.trim().isEmpty ? '20:00' : group.endTime.trim(),
      workDaysPerWeek: group.workDaysPerWeek.clamp(1, 7).toInt(),
      startDay:
          group.startDay.trim().isEmpty ? 'monday' : group.startDay.trim(),
      accountingEnabled: group.accountingEnabled,
      workerIds: workerIds,
    );
  }

AdminWorkerGroup _hydrateTestModeWorkerGroup(AdminWorkerGroup group) {
    return group.copyWith(
      workers: [
        for (final id in group.workerIds)
          for (final worker in _testModeWorkers)
            if (worker.id == id) worker,
      ],
    );
  }

Future<AdminRoleAssignment> adminUpsertRoleAssignment(
    AdminRoleAssignment assignment,
  ) async {
    final invalidApparatusId = assignment.assignedApparatus.any(
      (item) => !isCanonicalApparatusId(item),
    );
    if (invalidApparatusId) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Canonical apparatus ID noto‘g‘ri',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final normalized = AdminRoleAssignment(
        principalRole: assignment.principalRole,
        principalRef: assignment.principalRef.trim(),
        roleId: assignment.roleId.trim(),
        assignedApparatus: assignment.assignedApparatus
            .map((item) => item.trim())
            .where(isCanonicalApparatusId)
            .toSet()
            .toList(growable: false),
        assignedItemGroups: assignment.assignedItemGroups
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false),
      );
      final index = _testModeRoleAssignments.indexWhere(
        (item) =>
            item.principalRole == normalized.principalRole &&
            item.principalRef.trim() == normalized.principalRef,
      );
      if (index >= 0) {
        _testModeRoleAssignments[index] = normalized;
      } else {
        _testModeRoleAssignments.add(normalized);
      }
      return normalized;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/role-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(assignment.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_role_assignment_save_failed',
        fallbackMessage: 'Role biriktirish saqlanmadi',
      );
    }
    return AdminRoleAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
