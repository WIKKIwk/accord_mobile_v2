part of '../mobile_api.dart';

final List<ProductionMapSaved> _testModeProductionMaps = [];
final List<AdminApparatusGroup> _testModeApparatusGroups = [
  ...TestModeDemoData.apparatusGroups,
];
final List<AdminWarehouse> _testModeApparatusWarehouses = [];
final List<AdminWarehouse> _testModeWarehouses = [];
final List<AdminWarehouseAssignment> _testModeWarehouseAssignments = [];
final Map<String, List<String>> _testModeApparatusSequences = {};
final Map<String, Map<String, String>> _testModeApparatusQueueStates = {};
final Map<String, AdminApparatusQueuePolicy> _testModeApparatusQueuePolicies =
    {};
final List<_TestModeCompletedQueueOrder> _testModeCompletedQueueOrders = [];
final List<AdminCompletionRequestNotification> _testModeCompletionRequests = [];
final List<AdminCompletionRequestDecisionNotification>
    _testModeCompletionRequestDecisions = [];
final Map<String, AdminProgressBatch> _testModeProgressBatchesByQr = {};
final Map<String, AdminRawMaterialRule> _testModeRawMaterialRules = {};
final List<AdminRawMaterialAssignment> _testModeRawMaterialAssignments = [];
final List<AdminWorker> _testModeWorkers = [];
final List<AdminWorkerGroup> _testModeWorkerGroups = [];
final Map<String, String> _testModeWorkerCodes = {};
bool _testModeForceSequenceSaveFailure = false;
bool _testModeForceCalculateTemplateSaveFailure = false;

void setMobileApiTestModeForceSequenceSaveFailure(bool value) {
  _testModeForceSequenceSaveFailure = value;
}

void setMobileApiTestModeForceCalculateTemplateSaveFailure(bool value) {
  _testModeForceCalculateTemplateSaveFailure = value;
}

void resetMobileApiTestModeData() {
  _testModeProductionMaps.clear();
  _testModeApparatusGroups
    ..clear()
    ..addAll(TestModeDemoData.apparatusGroups);
  _testModeApparatusWarehouses.clear();
  _testModeWarehouses.clear();
  _testModeWarehouseAssignments.clear();
  _testModeApparatusSequences.clear();
  _testModeApparatusQueueStates.clear();
  _testModeApparatusQueuePolicies.clear();
  _testModeCompletedQueueOrders.clear();
  _testModeCompletionRequests.clear();
  _testModeCompletionRequestDecisions.clear();
  _testModeProgressBatchesByQr.clear();
  _testModeRawMaterialRules.clear();
  _testModeRawMaterialAssignments.clear();
  resetMobileApiTestModeWorkerSettingsData();
  _testModeForceSequenceSaveFailure = false;
  _testModeForceCalculateTemplateSaveFailure = false;
}

void resetMobileApiTestModeWorkerSettingsData() {
  _testModeWorkers.clear();
  _testModeWorkerGroups.clear();
  _testModeWorkerCodes.clear();
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
  }
}

class ProductionMapSaveWithOrderResult {
  const ProductionMapSaveWithOrderResult({
    required this.saved,
    required this.template,
  });

  final ProductionMapSaved saved;
  final CalculateOrderTemplate? template;
}

class AdminApparatusQueueSnapshot {
  const AdminApparatusQueueSnapshot({
    required this.sequences,
    required this.queueStates,
    required this.queuePolicies,
  });

  final Map<String, List<String>> sequences;
  final Map<String, Map<String, String>> queueStates;
  final Map<String, AdminApparatusQueuePolicy> queuePolicies;
}

class AdminCompletedQueueOrder {
  const AdminCompletedQueueOrder({
    required this.apparatus,
    required this.orderId,
    required this.completedAtUnix,
  });

  final String apparatus;
  final String orderId;
  final int completedAtUnix;

  factory AdminCompletedQueueOrder.fromJson(Map<String, dynamic> json) {
    return AdminCompletedQueueOrder(
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminCompletionRequestNotification {
  const AdminCompletionRequestNotification({
    required this.eventId,
    required this.apparatus,
    required this.orderId,
    required this.orderNumber,
    required this.orderTitle,
    required this.productCode,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    required this.description,
    required this.createdAtUnix,
  });

  final String eventId;
  final String apparatus;
  final String orderId;
  final String orderNumber;
  final String orderTitle;
  final String productCode;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final int createdAtUnix;

  factory AdminCompletionRequestNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminCompletionRequestNotification(
      eventId: json['event_id']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderTitle: json['order_title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminCompletionRequestDecisionNotification {
  const AdminCompletionRequestDecisionNotification({
    required this.eventId,
    required this.requestEventId,
    required this.decision,
    required this.apparatus,
    required this.orderId,
    required this.orderNumber,
    required this.orderTitle,
    required this.productCode,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    required this.decidedByRole,
    required this.decidedByRef,
    required this.decidedByDisplayName,
    required this.description,
    required this.message,
    required this.createdAtUnix,
  });

  final String eventId;
  final String requestEventId;
  final String decision;
  final String apparatus;
  final String orderId;
  final String orderNumber;
  final String orderTitle;
  final String productCode;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String decidedByRole;
  final String decidedByRef;
  final String decidedByDisplayName;
  final String description;
  final String message;
  final int createdAtUnix;

  factory AdminCompletionRequestDecisionNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminCompletionRequestDecisionNotification(
      eventId: json['event_id']?.toString() ?? '',
      requestEventId: json['request_event_id']?.toString() ?? '',
      decision: json['decision']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderTitle: json['order_title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      decidedByRole: json['decided_by_role']?.toString() ?? '',
      decidedByRef: json['decided_by_ref']?.toString() ?? '',
      decidedByDisplayName: json['decided_by_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProductionOrderLogEntry {
  const AdminProductionOrderLogEntry({
    required this.eventId,
    required this.apparatus,
    required this.orderId,
    required this.action,
    required this.fromState,
    required this.toState,
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.createdAtUnix,
    this.completedWithIssue = false,
    this.issueNote = '',
  });

  final String eventId;
  final String apparatus;
  final String orderId;
  final String action;
  final String fromState;
  final String toState;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final int createdAtUnix;
  final bool completedWithIssue;
  final String issueNote;

  factory AdminProductionOrderLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminProductionOrderLogEntry(
      eventId: json['event_id']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      fromState: json['from_state']?.toString() ?? '',
      toState: json['to_state']?.toString() ?? '',
      actorRole: json['actor_role']?.toString() ?? '',
      actorRef: json['actor_ref']?.toString() ?? '',
      actorDisplayName: json['actor_display_name']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      completedWithIssue: json['completed_with_issue'] == true,
      issueNote: json['issue_note']?.toString() ?? '',
    );
  }
}

class AdminClosedProductionOrder {
  const AdminClosedProductionOrder({
    required this.orderId,
    required this.orderNumber,
    required this.title,
    required this.productCode,
    required this.completedAtUnix,
    required this.closedByRole,
    required this.closedByRef,
    required this.closedByDisplayName,
    required this.logs,
  });

  final String orderId;
  final String orderNumber;
  final String title;
  final String productCode;
  final int completedAtUnix;
  final String closedByRole;
  final String closedByRef;
  final String closedByDisplayName;
  final List<AdminProductionOrderLogEntry> logs;

  factory AdminClosedProductionOrder.fromJson(Map<String, dynamic> json) {
    final logsRaw = json['logs'];
    return AdminClosedProductionOrder(
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      closedByRole: json['closed_by_role']?.toString() ?? '',
      closedByRef: json['closed_by_ref']?.toString() ?? '',
      closedByDisplayName: json['closed_by_display_name']?.toString() ?? '',
      logs: [
        if (logsRaw is List)
          for (final item in logsRaw)
            AdminProductionOrderLogEntry.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
    );
  }
}

class _TestModeCompletedQueueOrder {
  const _TestModeCompletedQueueOrder({
    required this.actorRef,
    required this.order,
  });

  final String actorRef;
  final AdminCompletedQueueOrder order;
}

class AdminProgressBatch {
  const AdminProgressBatch({
    required this.batchId,
    required this.sessionId,
    required this.apparatus,
    required this.orderId,
    required this.action,
    required this.status,
    required this.producedQty,
    required this.uom,
    required this.qrPayload,
    required this.labelItemCode,
    required this.labelItemName,
    required this.executorName,
    this.returnInkKg,
    this.totalWaste,
    this.finishedGoodsKg,
    this.finishedGoodsMeter,
    this.description = '',
  });

  final String batchId;
  final String sessionId;
  final String apparatus;
  final String orderId;
  final String action;
  final String status;
  final double producedQty;
  final String uom;
  final String qrPayload;
  final String labelItemCode;
  final String labelItemName;
  final String executorName;
  final double? returnInkKg;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? finishedGoodsMeter;
  final String description;

  factory AdminProgressBatch.fromJson(Map<String, dynamic> json) {
    return AdminProgressBatch(
      batchId: json['batch_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      producedQty: (json['produced_qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString() ?? '',
      labelItemCode: json['label_item_code']?.toString() ?? '',
      labelItemName: json['label_item_name']?.toString() ?? '',
      executorName: json['executor_name']?.toString() ?? '',
      returnInkKg: (json['return_ink_kg'] as num?)?.toDouble(),
      totalWaste: (json['total_waste'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
    );
  }

  AdminProgressBatch copyWith({String? status}) {
    return AdminProgressBatch(
      batchId: batchId,
      sessionId: sessionId,
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      status: status ?? this.status,
      producedQty: producedQty,
      uom: uom,
      qrPayload: qrPayload,
      labelItemCode: labelItemCode,
      labelItemName: labelItemName,
      executorName: executorName,
      returnInkKg: returnInkKg,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      finishedGoodsMeter: finishedGoodsMeter,
      description: description,
    );
  }
}

class AdminApparatusQueueActionResult {
  const AdminApparatusQueueActionResult({
    required this.states,
    this.progressBatch,
    this.completionRequest,
  });

  final Map<String, String> states;
  final AdminProgressBatch? progressBatch;
  final AdminCompletionRequestNotification? completionRequest;
}

enum ApparatusQueuePolicy {
  strictSequence('strict_sequence'),
  freePick('free_pick');

  const ApparatusQueuePolicy(this.apiValue);

  final String apiValue;

  static ApparatusQueuePolicy fromRaw(Object? raw) {
    return switch (raw?.toString().trim()) {
      'free_pick' => ApparatusQueuePolicy.freePick,
      _ => ApparatusQueuePolicy.strictSequence,
    };
  }
}

class AdminApparatusQueuePolicy {
  const AdminApparatusQueuePolicy({
    required this.apparatus,
    required this.policy,
    this.locked = false,
    this.reason = '',
  });

  final String apparatus;
  final ApparatusQueuePolicy policy;
  final bool locked;
  final String reason;

  factory AdminApparatusQueuePolicy.fromJson(Map<String, dynamic> json) {
    return AdminApparatusQueuePolicy(
      apparatus: json['apparatus']?.toString() ?? '',
      policy: ApparatusQueuePolicy.fromRaw(json['policy']),
      locked: json['locked'] == true,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'apparatus': apparatus,
        'policy': policy.apiValue,
        'locked': locked,
        'reason': reason,
      };
}

class AdminRawMaterialRule {
  const AdminRawMaterialRule({
    required this.apparatus,
    required this.requiresMaterial,
    required this.itemGroups,
  });

  final String apparatus;
  final bool requiresMaterial;
  final List<String> itemGroups;

  factory AdminRawMaterialRule.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['item_groups'];
    return AdminRawMaterialRule(
      apparatus: json['apparatus']?.toString() ?? '',
      requiresMaterial: json['requires_material'] == true,
      itemGroups: [
        if (rawGroups is List)
          for (final item in rawGroups)
            if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ],
    );
  }
}

class AdminRawMaterialAssignment {
  const AdminRawMaterialAssignment({
    required this.orderId,
    required this.apparatus,
    required this.barcode,
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    this.assignedByRef = '',
    this.assignedByName = '',
    this.assignedAt = '',
    this.stockStatus = '',
    this.reservedOrderId = '',
    this.stockWarehouse = '',
  });

  final String orderId;
  final String apparatus;
  final String barcode;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final String assignedByRef;
  final String assignedByName;
  final String assignedAt;
  final String stockStatus;
  final String reservedOrderId;
  final String stockWarehouse;

  factory AdminRawMaterialAssignment.fromJson(Map<String, dynamic> json) {
    return AdminRawMaterialAssignment(
      orderId: json['order_id']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      itemGroup: json['item_group']?.toString() ?? '',
      assignedByRef: json['assigned_by_ref']?.toString() ?? '',
      assignedByName: json['assigned_by_display_name']?.toString() ??
          json['assigned_by_name']?.toString() ??
          '',
      assignedAt: json['assigned_at']?.toString() ?? '',
      stockStatus: json['stock_status']?.toString() ?? '',
      reservedOrderId: json['reserved_order_id']?.toString() ?? '',
      stockWarehouse: json['stock_warehouse']?.toString() ?? '',
    );
  }

  AdminRawMaterialAssignment copyWith({
    String? stockStatus,
    String? reservedOrderId,
    String? stockWarehouse,
  }) {
    return AdminRawMaterialAssignment(
      orderId: orderId,
      apparatus: apparatus,
      barcode: barcode,
      itemCode: itemCode,
      itemName: itemName,
      itemGroup: itemGroup,
      assignedByRef: assignedByRef,
      assignedByName: assignedByName,
      assignedAt: assignedAt,
      stockStatus: stockStatus ?? this.stockStatus,
      reservedOrderId: reservedOrderId ?? this.reservedOrderId,
      stockWarehouse: stockWarehouse ?? this.stockWarehouse,
    );
  }
}

class AdminRawMaterialLookup {
  const AdminRawMaterialLookup({
    required this.barcode,
    required this.warehouse,
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    required this.qty,
    required this.uom,
  });

  final String barcode;
  final String warehouse;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final double qty;
  final String uom;

  factory AdminRawMaterialLookup.fromJson(Map<String, dynamic> json) {
    return AdminRawMaterialLookup(
      barcode: json['barcode']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      itemGroup: json['item_group']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
    );
  }
}

class AdminProductionMapLiveSnapshot {
  const AdminProductionMapLiveSnapshot({
    required this.maps,
    required this.sequences,
    required this.queueStates,
    required this.queuePolicies,
    required this.completedOrders,
    required this.completionRequests,
    required this.completionRequestDecisions,
  });

  final List<ProductionMapSaved> maps;
  final Map<String, List<String>> sequences;
  final Map<String, Map<String, String>> queueStates;
  final Map<String, AdminApparatusQueuePolicy> queuePolicies;
  final List<AdminCompletedQueueOrder> completedOrders;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<AdminCompletionRequestDecisionNotification>
      completionRequestDecisions;

  factory AdminProductionMapLiveSnapshot.fromJson(Map<String, dynamic> json) {
    final mapsRaw = json['maps'];
    final completedRaw = json['completed_orders'];
    final completionRequestsRaw = json['completion_requests'];
    final completionRequestDecisionsRaw = json['completion_request_decisions'];
    return AdminProductionMapLiveSnapshot(
      maps: [
        if (mapsRaw is List)
          for (final item in mapsRaw)
            ProductionMapSaved.fromJson(item as Map<String, dynamic>),
      ],
      sequences: MobileApi.instance.parseApparatusSequenceMap(
        json['sequences'],
      ),
      queueStates: MobileApi.instance.parseApparatusQueueStateMap(
        json['queue_states'],
      ),
      queuePolicies: MobileApi.instance.parseApparatusQueuePolicyMap(
        json['queue_policies'],
      ),
      completedOrders: [
        if (completedRaw is List)
          for (final item in completedRaw)
            AdminCompletedQueueOrder.fromJson(item as Map<String, dynamic>),
      ],
      completionRequests: [
        if (completionRequestsRaw is List)
          for (final item in completionRequestsRaw)
            AdminCompletionRequestNotification.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      completionRequestDecisions: [
        if (completionRequestDecisionsRaw is List)
          for (final item in completionRequestDecisionsRaw)
            AdminCompletionRequestDecisionNotification.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
    );
  }
}

MobileApiException _adminProductionMapException(
  http.Response response,
  String fallbackCode,
) {
  String code = fallbackCode;
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
    message: switch (code) {
      'duplicate_order_number' => 'Bu raqam boshqa zakazga berilgan',
      'order_number_immutable' => 'Zakaz raqamini o‘zgartirish mumkin emas',
      'move_not_allowed' => 'Zakaz bu aparatga tushmaydi',
      'queue_action_not_allowed' =>
        'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
      'previous_stage_not_completed' =>
        'Oldingi bosqich tugallanguncha kutilmoqda',
      'apparatus_not_assigned' => 'Bu aparat sizga biriktirilmagan',
      'queue_policy_locked' =>
        'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
      'bosma_completion_metrics_required' =>
        'Bosma tugatish uchun barcha majburiy fieldlarni kiriting',
      'raw_material_scan_required' =>
        'Ishni boshlash uchun biriktirilgan homashyoni skaner qiling',
      'raw_material_mismatch' => 'Bu homashyo ish boshlash uchun mos emas',
      'raw_material_rule_not_found' => 'Bu homashyo uchun aparat qoidasi yo‘q',
      'raw_material_assignment_not_found' => 'Homashyo biriktirilmagan',
      'raw_material_assignment_locked' =>
        'Bu homashyo allaqachon ishga tushgan yoki ishlatilgan, uzib bo‘lmaydi',
      'raw_material_already_assigned' =>
        'Bu homashyo boshqa zakaz uchun band qilingan',
      'raw_material_already_assigned_to_order' =>
        'Bu homashyo allaqachon shu zakazga ulangan',
      'raw_material_group_not_allowed' =>
        'Bu homashyo ish boshlash uchun mos emas',
      'raw_material_roll_size_missing' => 'Rulon razmeri topilmadi',
      'raw_material_roll_size_mismatch' =>
        'Bu rulon bu buyurtma uchun mos emas',
      'raw_material_invalid_input' => 'Homashyo QR noto‘g‘ri',
      'progress_input_invalid' => 'Chiqarilgan miqdorni kiriting',
      'progress_batch_not_found' => 'Progress QR topilmadi',
      'progress_batch_not_resumable' =>
        'Bu progress QR davom ettirishga yaramaydi',
      'scale_driver_not_configured' => 'Printer ulanmagan',
      'map_not_found' => 'Zakaz topilmadi',
      _ => 'Production map amali bajarilmadi',
    },
    statusCode: response.statusCode,
  );
}

extension MobileApiAdmin on MobileApi {
  String get baseUrl => MobileApi.baseUrl;

  Future<AdminSettings> adminSettings() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.adminSettings;
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/settings'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin settings failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSettings> updateAdminSettings(AdminSettings settings) async {
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/settings'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(settings.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin settings update failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSettings> adminRegenerateWerkaCode() async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/werka/code/regenerate'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin werka code regenerate failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<DispatchRecord>> adminActivity() async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/activity'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin activity failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => DispatchRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminApparatusGroup>> adminApparatusGroups() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminApparatusGroup>.from(_testModeApparatusGroups);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/apparatus-groups'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin apparatus groups failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => AdminApparatusGroup.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<AdminApparatusGroup> adminSaveApparatusGroup(
    AdminApparatusGroup group,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = AdminApparatusGroup.fromJson(group.toJson());
      final key = normalized.name.toLowerCase();
      final index = _testModeApparatusGroups.indexWhere(
        (item) => item.name.toLowerCase() == key,
      );
      if (index >= 0) {
        _testModeApparatusGroups[index] = normalized;
      } else {
        _testModeApparatusGroups.add(normalized);
      }
      return normalized;
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/apparatus-groups'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(group.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin apparatus group save failed');
    }
    return AdminApparatusGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminCapability>> adminCapabilities() async {
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/capabilities'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin capabilities failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => AdminCapability.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminRoleDefinition>> adminRoles() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.roles;
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/roles'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin roles failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => AdminRoleDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ProductionMapSaved>> adminProductionMaps() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<ProductionMapSaved>.unmodifiable(_testModeProductionMaps);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin production maps failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => ProductionMapSaved.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ProductionMapSaved> adminProductionMap(String id) async {
    final normalized = id.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeProductionMaps.firstWhere(
        (item) => item.map.id.trim() == normalized,
        orElse: () => throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        ),
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps',
        ).replace(queryParameters: {'id': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'map_not_found');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ProductionMapSaved> adminSaveProductionMap(
    ProductionMapDefinition map,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final duplicate = _testModeProductionMaps.any(
        (item) =>
            item.map.orderNumber.trim().isNotEmpty &&
            item.map.orderNumber.trim() == map.orderNumber.trim() &&
            !_isSameProductionMapOrder(item.map, map),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'duplicate_order_number',
          message: 'Bu raqam boshqa zakazga berilgan',
        );
      }
      final saved = ProductionMapSaved(
        map: map,
        program: ProductionMapProgram(
          mapId: map.id,
          productCode: map.productCode,
          operations: [
            for (var i = 0; i < map.nodes.length; i++)
              ProductionMapOperation(
                order: i + 1,
                nodeId: map.nodes[i].id,
                opCode: map.nodes[i].kind,
                args: {'title': map.nodes[i].title},
              ),
          ],
        ),
      );
      _testModeProductionMaps.removeWhere((item) => item.map.id == map.id);
      _testModeProductionMaps.insert(0, saved);
      return saved;
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(map.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_save');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ProductionMapSaveWithOrderResult> adminSaveProductionMapWithOrder({
    required ProductionMapDefinition map,
    required CalculateOrderTemplate template,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final previousIndex = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == map.id.trim(),
      );
      ProductionMapSaved? previousMap;
      if (previousIndex >= 0) {
        previousMap = _testModeProductionMaps[previousIndex];
      }
      if (template.product.trim().isEmpty || template.widthMm <= 0) {
        throw const MobileApiException(
          code: 'calculate_order_save',
          message: 'Calculate order validation failed',
        );
      }
      try {
        final savedMap = await adminSaveProductionMap(map);
        final savedTemplate = _testModeUpsertCalculateOrderTemplate(
          template.copyWith(sourceMapId: savedMap.map.id),
        );
        return ProductionMapSaveWithOrderResult(
          saved: savedMap,
          template: savedTemplate,
        );
      } catch (error) {
        if (previousMap != null) {
          if (previousIndex >= 0) {
            _testModeProductionMaps[previousIndex] = previousMap;
          }
        } else {
          _testModeProductionMaps.removeWhere(
            (item) => item.map.id.trim() == map.id.trim(),
          );
        }
        rethrow;
      }
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/with-order'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'map': map.toJson(), 'template': template.toJson()}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'production_map_save_with_order',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaveWithOrderResult(
      saved: ProductionMapSaved.fromJson(
        (payload['saved'] as Map).cast<String, dynamic>(),
      ),
      template: payload['template'] is Map
          ? CalculateOrderTemplate.fromJson(
              (payload['template'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  Future<List<ProductionMapSaved>> adminMoveProductionMapOrdersBatch({
    required List<String> mapIds,
    required String fromApparatus,
    required String toApparatus,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalizedIds = [
        for (final id in mapIds)
          if (id.trim().isNotEmpty) id.trim(),
      ];
      if (normalizedIds.isEmpty) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz tanlanmadi',
        );
      }
      final originals = <ProductionMapSaved>[];
      for (final mapId in normalizedIds) {
        final index = _testModeProductionMaps.indexWhere(
          (item) => item.map.id.trim() == mapId,
        );
        if (index < 0) {
          throw const MobileApiException(
            code: 'map_not_found',
            message: 'Zakaz topilmadi',
          );
        }
        originals.add(_testModeProductionMaps[index]);
      }
      final updated = <ProductionMapSaved>[];
      for (final current in originals) {
        if (!productionMapCanMoveOrderToApparatus(
          nodes: current.map.nodes,
          fromApparatus: fromApparatus,
          toApparatus: toApparatus,
          rollCount: current.map.rollCount,
          widthMm: current.map.widthMm,
          isFlexoOrder: productionMapIsFlexoOrder(current.map),
        )) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        final nodes = productionMapReassignAlternativeApparatusAssignment(
              nodes: current.map.nodes,
              fromApparatus: fromApparatus,
              toApparatus: toApparatus,
            ) ??
            productionMapReassignApparatusNodes(
              nodes: current.map.nodes,
              fromApparatus: fromApparatus,
              toApparatus: toApparatus,
            );
        if (nodes == null) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        updated.add(
          ProductionMapSaved(
            map: current.map.copyWith(nodes: nodes),
            program: current.program,
          ),
        );
      }
      for (var i = 0; i < normalizedIds.length; i++) {
        final index = _testModeProductionMaps.indexWhere(
          (item) => item.map.id.trim() == normalizedIds[i],
        );
        if (index >= 0) {
          _testModeProductionMaps[index] = updated[i];
        }
      }
      return updated;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/move-batch'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'from_apparatus': fromApparatus,
          'to_apparatus': toApparatus,
          'map_ids': mapIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_move_batch');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['saved'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map)
          ProductionMapSaved.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<ProductionMapSaved> adminMoveProductionMapOrder({
    required String mapId,
    required String fromApparatus,
    required String toApparatus,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == mapId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        );
      }
      final current = _testModeProductionMaps[index];
      if (!productionMapCanMoveOrderToApparatus(
        nodes: current.map.nodes,
        fromApparatus: fromApparatus,
        toApparatus: toApparatus,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
        isFlexoOrder: productionMapIsFlexoOrder(current.map),
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: fromApparatus,
            toApparatus: toApparatus,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: fromApparatus,
            toApparatus: toApparatus,
          );
      if (nodes == null) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final saved = ProductionMapSaved(
        map: current.map.copyWith(nodes: nodes),
        program: current.program,
      );
      _testModeProductionMaps[index] = saved;
      return saved;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/move'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'map_id': mapId,
          'from_apparatus': fromApparatus,
          'to_apparatus': toApparatus,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_move');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaved.fromJson(
      (payload['saved'] as Map).cast<String, dynamic>(),
    );
  }

  Future<Map<String, List<String>>> adminProductionMapSequences() async {
    final snapshot = await adminProductionMapQueueSnapshot();
    return snapshot.sequences;
  }

  Future<AdminApparatusQueueSnapshot> adminProductionMapQueueSnapshot() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminApparatusQueueSnapshot(
        sequences: {
          for (final entry in _testModeApparatusSequences.entries)
            entry.key: List<String>.unmodifiable(entry.value),
        },
        queueStates: {
          for (final entry in _testModeApparatusQueueStates.entries)
            entry.key: Map<String, String>.unmodifiable(entry.value),
        },
        queuePolicies: Map<String, AdminApparatusQueuePolicy>.unmodifiable(
          _testModeApparatusQueuePolicies,
        ),
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminApparatusQueueSnapshot(
      sequences: parseApparatusSequenceMap(payload['sequences']),
      queueStates: parseApparatusQueueStateMap(payload['queue_states']),
      queuePolicies: parseApparatusQueuePolicyMap(payload['queue_policies']),
    );
  }

  Future<List<AdminCompletedQueueOrder>>
      adminCompletedProductionMapOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
      return [
        for (final item in _testModeCompletedQueueOrders)
          if (item.actorRef == actorRef) item.order,
      ];
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/completed-orders'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'completed_orders');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['completed_orders'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminCompletedQueueOrder.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<AdminCompletionRequestNotification>>
      adminProductionMapCompletionRequests() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminCompletionRequestNotification>.unmodifiable(
        _testModeCompletionRequests,
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/completion-requests',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'completion_requests');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['completion_requests'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminCompletionRequestNotification.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
    ];
  }

  Future<AdminCompletionRequestDecisionNotification>
      adminProductionMapCompletionRequestDecision({
    required String eventId,
    required String decision,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeCompletionRequests.indexWhere(
        (item) => item.eventId.trim() == eventId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Tugatish so‘rovi topilmadi',
        );
      }
      final request = _testModeCompletionRequests.removeAt(index);
      final normalized = decision.trim().toLowerCase().startsWith('reject')
          ? 'rejected'
          : 'approved';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final message = normalized == 'rejected'
          ? "Sizni so'rovingiz rad etildi"
          : 'Muammo bilan yopildi';
      if (normalized == 'approved') {
        final states = Map<String, String>.from(
          _testModeApparatusQueueStates[request.apparatus] ?? const {},
        );
        states[request.orderId] = 'completed';
        _testModeApparatusQueueStates[request.apparatus] = states;
      }
      final notification = AdminCompletionRequestDecisionNotification(
        eventId: 'test-completion-decision-$now-${request.orderId}',
        requestEventId: request.eventId,
        decision: normalized,
        apparatus: request.apparatus,
        orderId: request.orderId,
        orderNumber: request.orderNumber,
        orderTitle: request.orderTitle,
        productCode: request.productCode,
        workerRole: request.workerRole,
        workerRef: request.workerRef,
        workerDisplayName: request.workerDisplayName,
        decidedByRole: AppSession.instance.profile?.role.name ?? '',
        decidedByRef: AppSession.instance.profile?.ref.trim() ?? '',
        decidedByDisplayName:
            AppSession.instance.profile?.displayName.trim() ?? '',
        description: request.description,
        message: message,
        createdAtUnix: now,
      );
      _testModeCompletionRequestDecisions.insert(0, notification);
      return notification;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/completion-requests/decision',
        ),
        headers: _headers(requireToken()),
        body: jsonEncode({
          'event_id': eventId,
          'decision': decision,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'completion_request_decision');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminCompletionRequestDecisionNotification.fromJson(
      (payload['decision'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<AdminCompletionRequestDecisionNotification>>
      adminProductionMapCompletionRequestDecisions() async {
    if (await TestModeController.instance.isEnabled()) {
      final workerRef = AppSession.instance.profile?.ref.trim() ?? '';
      return List<AdminCompletionRequestDecisionNotification>.unmodifiable(
        _testModeCompletionRequestDecisions.where(
          (item) => workerRef.isEmpty || item.workerRef.trim() == workerRef,
        ),
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/completion-request-decisions',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'completion_request_decisions',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['completion_request_decisions'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminCompletionRequestDecisionNotification.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
    ];
  }

  Future<List<AdminClosedProductionOrder>>
      adminClosedProductionMapOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      return const [];
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/closed-orders'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'closed_orders');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['closed_orders'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminClosedProductionOrder.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
    ];
  }

  Future<Map<String, AdminApparatusQueuePolicy>>
      adminApparatusQueuePolicies() async {
    if (await TestModeController.instance.isEnabled()) {
      return Map<String, AdminApparatusQueuePolicy>.unmodifiable(
        _testModeApparatusQueuePolicies,
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-policies'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_policies');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return parseApparatusQueuePolicyMap(payload['policies']);
  }

  Future<AdminApparatusQueuePolicy> adminUpdateApparatusQueuePolicy({
    required String apparatus,
    required ApparatusQueuePolicy policy,
  }) async {
    final normalized = apparatus.trim();
    if (await TestModeController.instance.isEnabled()) {
      final locked = productionMapPechatColorCount(normalized) != null;
      if (locked && policy != ApparatusQueuePolicy.strictSequence) {
        throw const MobileApiException(
          code: 'queue_policy_locked',
          message: 'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
        );
      }
      final record = AdminApparatusQueuePolicy(
        apparatus: normalized,
        policy: locked ? ApparatusQueuePolicy.strictSequence : policy,
        locked: locked,
        reason: locked ? 'pechat_always_strict' : '',
      );
      _testModeApparatusQueuePolicies[normalized] = record;
      return record;
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-policies'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalized,
          'policy': policy.apiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_policies');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['policy'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'queue_policies',
        message: 'Production map amali bajarilmadi',
      );
    }
    return AdminApparatusQueuePolicy.fromJson(raw.cast<String, dynamic>());
  }

  Future<http.StreamedResponse> adminProductionMapLiveConnect() async {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/v1/mobile/admin/production-maps/live'),
    );
    request.headers.addAll({
      ..._headers(requireToken()),
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    });
    return _sendAuthorizedStream(() => http.Client().send(request));
  }

  Future<List<AdminRawMaterialRule>> adminRawMaterialRules() async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeRawMaterialRules.values.toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-rules'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_rules');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => AdminRawMaterialRule.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminRawMaterialRule> adminSaveRawMaterialRule({
    required String apparatus,
    bool requiresMaterial = false,
    required List<String> itemGroups,
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedGroups = itemGroups
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (await TestModeController.instance.isEnabled()) {
      final rule = AdminRawMaterialRule(
        apparatus: normalizedApparatus,
        requiresMaterial: requiresMaterial,
        itemGroups: normalizedGroups,
      );
      _testModeRawMaterialRules[normalizedApparatus] = rule;
      return rule;
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-rules'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'requires_material': requiresMaterial,
          'item_groups': normalizedGroups,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_rules');
    }
    return AdminRawMaterialRule.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminRawMaterialAssignment>> adminRawMaterialAssignments() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminRawMaterialAssignment>.unmodifiable(
        _testModeRawMaterialAssignments,
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => AdminRawMaterialAssignment.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<AdminRawMaterialAssignment> adminAssignRawMaterialToOrder({
    required String orderId,
    required String barcode,
  }) async {
    final body = {
      'order_id': orderId.trim(),
      'barcode': barcode.trim(),
    };
    if (await TestModeController.instance.isEnabled()) {
      final assignment = AdminRawMaterialAssignment(
        orderId: body['order_id']!,
        apparatus: '',
        barcode: body['barcode']!,
        itemCode: '',
        itemName: '',
        itemGroup: '',
        assignedByRef: AppSession.instance.profile?.ref ?? '',
        assignedByName: AppSession.instance.profile?.displayName ?? '',
      );
      final assignmentBarcode = assignment.barcode.trim().toUpperCase();
      final existing = _testModeRawMaterialAssignments.where(
        (item) => item.barcode.trim().toUpperCase() == assignmentBarcode,
      );
      for (final item in existing) {
        if (item.orderId.trim() == assignment.orderId.trim()) {
          throw const MobileApiException(
            code: 'raw_material_already_assigned_to_order',
            message: 'Bu homashyo allaqachon shu zakazga ulangan',
          );
        }
        throw const MobileApiException(
          code: 'raw_material_already_assigned',
          message: 'Bu homashyo boshqa zakaz uchun band qilingan',
        );
      }
      _testModeRawMaterialAssignments.removeWhere(
        (item) =>
            item.orderId.trim() == assignment.orderId.trim() &&
            item.barcode.trim() == assignment.barcode.trim(),
      );
      _testModeRawMaterialAssignments.add(assignment);
      return assignment;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    return AdminRawMaterialAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminRawMaterialAssignment> adminUnlinkRawMaterialAssignment({
    required String orderId,
    required String barcode,
  }) async {
    final body = {
      'order_id': orderId.trim(),
      'barcode': barcode.trim(),
    };
    if (await TestModeController.instance.isEnabled()) {
      final normalizedOrderId = body['order_id']!;
      final normalizedBarcode = body['barcode']!.toUpperCase();
      final index = _testModeRawMaterialAssignments.indexWhere(
        (item) =>
            item.orderId.trim() == normalizedOrderId &&
            item.barcode.trim().toUpperCase() == normalizedBarcode,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'raw_material_assignment_not_found',
          message: 'Homashyo biriktirilmagan',
        );
      }
      return _testModeRawMaterialAssignments.removeAt(index);
    }
    final response = await _sendAuthorized(
      () => http.delete(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final assignment = decoded['assignment'];
    return AdminRawMaterialAssignment.fromJson(
      assignment is Map<String, dynamic> ? assignment : decoded,
    );
  }

  Future<AdminRawMaterialLookup> adminRawMaterialLookup({
    required String barcode,
  }) async {
    final normalized = barcode.trim();
    if (await TestModeController.instance.isEnabled()) {
      return AdminRawMaterialLookup(
        barcode: normalized,
        warehouse: '',
        itemCode: '',
        itemName: '',
        itemGroup: '',
        qty: 0,
        uom: '',
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-assignments/lookup',
        ).replace(queryParameters: {'barcode': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    return AdminRawMaterialLookup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Map<String, List<String>> parseApparatusSequenceMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List)
            for (final id in entry.value as List) id.toString(),
        ],
    };
  }

  Map<String, Map<String, List<String>>> parseNestedSequenceMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        entry.key.toString(): {
          if (entry.value is Map)
            for (final nested in (entry.value as Map).entries)
              nested.key.toString(): [
                if (nested.value is List)
                  for (final id in nested.value as List) id.toString(),
              ],
        },
    };
  }

  Map<String, Map<String, String>> parseApparatusQueueStateMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        entry.key.toString(): {
          if (entry.value is Map)
            for (final stateEntry in (entry.value as Map).entries)
              stateEntry.key.toString(): stateEntry.value.toString(),
        },
    };
  }

  Map<String, AdminApparatusQueuePolicy> parseApparatusQueuePolicyMap(
    Object? raw,
  ) {
    final values = raw is Map
        ? raw.values
        : raw is List
            ? raw
            : const [];
    final policies = <String, AdminApparatusQueuePolicy>{};
    for (final item in values) {
      if (item is! Map) {
        continue;
      }
      final policy = AdminApparatusQueuePolicy.fromJson(
        item.cast<String, dynamic>(),
      );
      if (policy.apparatus.trim().isNotEmpty) {
        policies[policy.apparatus.trim()] = policy;
      }
    }
    return policies;
  }

  Future<Map<String, String>> adminApparatusQueueAction({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    double? producedQty,
    double? grossQty,
    double? returnInkKg,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String driverUrl = '',
    String completionRequestNote = '',
  }) async {
    final result = await adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      materialBarcode: materialBarcode,
      materialBarcodes: materialBarcodes,
      producedQty: producedQty,
      grossQty: grossQty,
      returnInkKg: returnInkKg,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      finishedGoodsMeter: finishedGoodsMeter,
      uom: uom,
      qrPayload: qrPayload,
      progressBatchId: progressBatchId,
      driverUrl: driverUrl,
      completionRequestNote: completionRequestNote,
    );
    return result.states;
  }

  Future<AdminApparatusQueueActionResult> adminApparatusQueueActionResult({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    double? producedQty,
    double? grossQty,
    double? returnInkKg,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String driverUrl = '',
    String completionRequestNote = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final knownKeys = {
        ..._testModeApparatusSequences.keys,
        ..._testModeApparatusQueueStates.keys,
      };
      final storageKey = resolveApparatusStorageKey(apparatus, knownKeys);
      final sequence = _testModeApparatusSequences[storageKey] ?? const [];
      final states = Map<String, String>.from(
        _testModeApparatusQueueStates[storageKey] ?? const {},
      );
      final policy =
          _effectiveTestModeQueuePolicy(apparatus, storageKey).policy;
      if (!sequence.map((id) => id.trim()).contains(orderId.trim())) {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
        );
      }
      if (policy == ApparatusQueuePolicy.strictSequence) {
        final actionable = firstActionableQueueOrderId(
          sequence: sequence,
          states: states,
        );
        if (actionable != orderId.trim()) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
      }
      final current = apparatusQueueOrderStateFromRaw(states[orderId.trim()]);
      if (action == 'start') {
        if (current != ApparatusQueueOrderState.pending) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final requiredMaterials = _testModeRawMaterialAssignments.where(
          (assignment) =>
              assignment.orderId.trim() == orderId.trim() &&
              productionMapWarehouseTitlesMatch(
                assignment.apparatus,
                apparatus,
              ),
        );
        final requiredBarcodes = {
          for (final assignment in requiredMaterials)
            assignment.barcode.trim().toUpperCase(),
        }..remove('');
        final scannedBarcodes = {
          for (final barcode in [
            ...materialBarcodes,
            if (materialBarcode.trim().isNotEmpty) materialBarcode,
          ])
            barcode.trim().toUpperCase(),
        }..remove('');
        if (requiredBarcodes.isNotEmpty && scannedBarcodes.isEmpty) {
          throw const MobileApiException(
            code: 'raw_material_scan_required',
            message:
                'Ishni boshlash uchun biriktirilgan homashyolarni skaner qiling',
          );
        }
        if (requiredBarcodes.isNotEmpty &&
            !setEquals(requiredBarcodes, scannedBarcodes)) {
          throw const MobileApiException(
            code: 'raw_material_mismatch',
            message: 'Bu homashyo ish boshlash uchun mos emas',
          );
        }
        states[orderId.trim()] = 'in_progress';
        for (var index = 0;
            index < _testModeRawMaterialAssignments.length;
            index += 1) {
          final assignment = _testModeRawMaterialAssignments[index];
          if (assignment.orderId.trim() == orderId.trim() &&
              productionMapWarehouseTitlesMatch(
                assignment.apparatus,
                apparatus,
              ) &&
              scannedBarcodes
                  .contains(assignment.barcode.trim().toUpperCase())) {
            _testModeRawMaterialAssignments[index] = assignment.copyWith(
              stockStatus: 'in_use',
              reservedOrderId: orderId.trim(),
            );
          }
        }
      } else if (action == 'pause') {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final qty = producedQty ?? 1;
        final batch = _testModeProgressBatch(
          apparatus: storageKey,
          orderId: orderId.trim(),
          action: 'pause',
          status: 'paused',
          producedQty: qty,
          uom: uom.trim().isEmpty ? 'kg' : uom.trim(),
          totalWaste: totalWaste,
          finishedGoodsKg: finishedGoodsKg,
          finishedGoodsMeter: finishedGoodsMeter,
        );
        _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        states[orderId.trim()] = 'paused';
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: batch,
        );
      } else if (action == 'resume') {
        if (current != ApparatusQueueOrderState.paused) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final progressKey = qrPayload.trim().isEmpty
            ? progressBatchId.trim()
            : qrPayload.trim();
        AdminProgressBatch? resumed;
        if (progressKey.isNotEmpty) {
          final batch = _testModeProgressBatchesByQr[progressKey];
          if (batch == null ||
              batch.status != 'paused' ||
              batch.orderId != orderId.trim() ||
              !productionMapWarehouseTitlesMatch(batch.apparatus, storageKey)) {
            throw const MobileApiException(
              code: 'progress_batch_not_resumable',
              message: 'Bu progress QR davom ettirishga yaramaydi',
            );
          }
          resumed = batch.copyWith(status: 'resumed');
          _testModeProgressBatchesByQr[batch.qrPayload] = resumed;
        }
        states[orderId.trim()] = 'in_progress';
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: resumed,
        );
      } else if (action == 'complete') {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final note = completionRequestNote.trim();
        final hasCompleteMetrics = returnInkKg != null &&
            totalWaste != null &&
            finishedGoodsKg != null &&
            finishedGoodsMeter != null;
        if (note.isNotEmpty && !hasCompleteMetrics && grossQty == null) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final map = _testModeProductionMaps
              .where((item) => item.map.id.trim() == orderId.trim())
              .cast<ProductionMapSaved?>()
              .firstWhere((item) => item != null, orElse: () => null);
          _testModeCompletionRequests.insert(
            0,
            AdminCompletionRequestNotification(
              eventId: 'test-completion-request-$now-${orderId.trim()}',
              apparatus: storageKey,
              orderId: orderId.trim(),
              orderNumber: map?.map.orderNumber.trim() ?? '',
              orderTitle: map?.map.title.trim() ?? '',
              productCode: map?.map.productCode.trim() ?? '',
              workerRole: AppSession.instance.profile?.role.name ?? '',
              workerRef: AppSession.instance.profile?.ref.trim() ?? '',
              workerDisplayName:
                  AppSession.instance.profile?.displayName.trim() ?? '',
              description: note,
              createdAtUnix: now,
            ),
          );
          return AdminApparatusQueueActionResult(
            states: Map<String, String>.unmodifiable(states),
            completionRequest: _testModeCompletionRequests.first,
          );
        }
        final batch = _testModeProgressBatch(
          apparatus: storageKey,
          orderId: orderId.trim(),
          action: 'complete',
          status: 'completed',
          producedQty: producedQty ?? finishedGoodsMeter ?? 1,
          uom: uom.trim().isEmpty && finishedGoodsMeter != null
              ? 'm'
              : (uom.trim().isEmpty ? 'kg' : uom.trim()),
          returnInkKg: returnInkKg,
          totalWaste: totalWaste,
          finishedGoodsKg: finishedGoodsKg,
          finishedGoodsMeter: finishedGoodsMeter,
        );
        _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        states[orderId.trim()] = 'completed';
        final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
        final completedOrderId = orderId.trim();
        if (actorRef.isNotEmpty && completedOrderId.isNotEmpty) {
          _testModeCompletedQueueOrders.removeWhere(
            (item) =>
                item.actorRef == actorRef &&
                item.order.orderId == completedOrderId,
          );
          _testModeCompletedQueueOrders.insert(
            0,
            _TestModeCompletedQueueOrder(
              actorRef: actorRef,
              order: AdminCompletedQueueOrder(
                apparatus: storageKey,
                orderId: completedOrderId,
                completedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            ),
          );
        }
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: batch,
        );
      } else {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Production map amali bajarilmadi',
        );
      }
      _testModeApparatusQueueStates[storageKey] = states;
      return AdminApparatusQueueActionResult(
        states: Map<String, String>.unmodifiable(states),
      );
    }
    final trimmedBarcode = materialBarcode.trim();
    final trimmedBarcodes = [
      for (final barcode in materialBarcodes)
        if (barcode.trim().isNotEmpty) barcode.trim(),
    ];
    final trimmedDriverUrl = driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final trimmedCompletionRequestNote = completionRequestNote.trim();
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-action'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus,
          'order_id': orderId,
          'action': action,
          if (trimmedBarcodes.isNotEmpty) 'material_barcodes': trimmedBarcodes,
          if (trimmedBarcodes.isEmpty && trimmedBarcode.isNotEmpty)
            'material_barcode': trimmedBarcode,
          if (producedQty != null) 'produced_qty': producedQty,
          if (grossQty != null) 'gross_qty': grossQty,
          if (returnInkKg != null) 'return_ink_kg': returnInkKg,
          if (totalWaste != null) 'total_waste': totalWaste,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (uom.trim().isNotEmpty) 'uom': uom.trim(),
          if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          if (progressBatchId.trim().isNotEmpty)
            'progress_batch_id': progressBatchId.trim(),
          if (trimmedDriverUrl.isNotEmpty) 'driver_url': trimmedDriverUrl,
          if (trimmedCompletionRequestNote.isNotEmpty)
            'completion_request_note': trimmedCompletionRequestNote,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_action_not_allowed');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['states'];
    if (raw is! Map) {
      return const AdminApparatusQueueActionResult(states: {});
    }
    final progressRaw = payload['progress_batch'];
    final requestRaw = payload['completion_request'];
    return AdminApparatusQueueActionResult(
      states: {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value.toString(),
      },
      progressBatch: progressRaw is Map
          ? AdminProgressBatch.fromJson(progressRaw.cast<String, dynamic>())
          : null,
      completionRequest: requestRaw is Map
          ? AdminCompletionRequestNotification.fromJson(
              requestRaw.cast<String, dynamic>(),
            )
          : null,
    );
  }

  Future<AdminProgressBatch> adminProgressQrLookup(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchesByQr[normalized];
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      return batch;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse(
            '$baseUrl/v1/mobile/admin/production-maps/progress-qr/lookup'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'qr_payload': normalized}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_batch_not_found');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batch'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    return AdminProgressBatch.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> adminSaveProductionMapSequence({
    required String apparatus,
    required List<String> orderIds,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceSequenceSaveFailure) {
        throw const MobileApiException(
          code: 'production_map_sequence',
          message: 'Ketma-ketlik saqlanmadi (test)',
        );
      }
      _testModeApparatusSequences[apparatus.trim()] = List<String>.from(
        orderIds,
      );
      return;
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'apparatus': apparatus, 'order_ids': orderIds}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
  }

  Future<ProductionMapRunResult> adminRunProductionMap(
    ProductionMapRunRequest input,
  ) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/run'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin production map run failed');
    }
    return ProductionMapRunResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminRoleDefinition> adminUpsertRole(AdminRoleDefinition role) async {
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/roles'),
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
      return TestModeDemoData.roleAssignments;
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/role-assignments'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin role assignments failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map(
          (item) => AdminRoleAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AdminWorker>> adminWorkers({String query = ''}) async {
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
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/workers').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin workers failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
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
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
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
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
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
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker phone update failed');
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
        level: worker.level,
        code: _testModeWorkerCodes[worker.id] ?? '',
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/workers/detail',
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
        level: worker.level,
        code: code,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/workers/code/regenerate',
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
    String apparatus = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final key = apparatus.trim().toLowerCase();
      return _testModeWorkerGroups
          .where(
            (group) =>
                key.isEmpty || group.apparatus.trim().toLowerCase() == key,
          )
          .map(_hydrateTestModeWorkerGroup)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/worker-groups').replace(
          queryParameters: {
            if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker groups failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => AdminWorkerGroup.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<AdminWorkerGroup> adminSaveWorkerGroup(AdminWorkerGroup group) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = _normalizeTestModeWorkerGroup(group);
      final key = normalized.apparatus.trim().toLowerCase();
      final code = normalized.groupCode.trim().toUpperCase();
      final duplicate = _testModeWorkerGroups.any(
        (item) =>
            item.apparatus.trim().toLowerCase() == key &&
            item.groupCode.trim().toUpperCase() != code &&
            item.workerIds.any(normalized.workerIds.toSet().contains),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'worker_duplicated_in_group',
          message: 'Ishchi boshqa guruhga ulangan',
        );
      }
      _testModeWorkerGroups.removeWhere(
        (item) => item.groupCode.trim().toUpperCase() == code,
      );
      _testModeWorkerGroups.add(normalized);
      return _hydrateTestModeWorkerGroup(normalized);
    }
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/worker-groups'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(group.toJson()),
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
    final workerIds = group.workerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final groupCode =
        group.groupCode.trim().split(RegExp(r'\s+')).join(' ').toUpperCase();
    return AdminWorkerGroup(
      apparatus: group.apparatus.trim(),
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
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse('$baseUrl/v1/mobile/admin/role-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(assignment.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin role assignment save failed');
    }
    return AdminRoleAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

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
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers'),
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
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers/list').replace(
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => AdminSupplier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUserListPage> adminUserList({
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.userListPage(
        query: query,
        limit: limit,
        offset: offset,
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/users/list').replace(
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
      throw Exception('Admin user list failed');
    }
    return AdminUserListPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSupplierSummary> adminSupplierSummary() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierSummary;
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers/summary'),
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
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers/inactive'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin inactive suppliers failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => AdminSupplier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminSupplierDetail> adminSupplierDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierDetail(ref);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/detail',
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
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/detail',
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

  Future<AdminCustomerDetail> adminUpdateCustomerPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => http.put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/phone',
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
      () => http.post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/code/regenerate',
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
      () => http.delete(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/remove',
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
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers'),
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
      () => http.post(
        Uri.parse('$baseUrl/v1/mobile/admin/customers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer create failed');
    }
    return CustomerDirectoryEntry.fromJson(
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
      () => http.get(
        Uri.parse('$baseUrl/v1/mobile/admin/customers/list').replace(
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
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
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
      () => http.put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/status',
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
      () => http.put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/phone',
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
      () => http.post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/code/regenerate',
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
      () => http.put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items',
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
      () => http.get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items/assigned',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin assigned supplier items failed');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminSupplierDetail> adminAssignSupplierItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items/add',
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
      () => http.delete(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items/remove',
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
      () => http.delete(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/remove',
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
      () => http.post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/restore',
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

bool _isSameProductionMapOrder(
  ProductionMapDefinition current,
  ProductionMapDefinition next,
) {
  return current.id.trim() == next.id.trim() &&
      current.title.trim() == next.title.trim() &&
      current.productCode.trim() == next.productCode.trim();
}

AdminApparatusQueuePolicy _effectiveTestModeQueuePolicy(
  String apparatus,
  String storageKey,
) {
  final title =
      storageKey.trim().isEmpty ? apparatus.trim() : storageKey.trim();
  final locked = productionMapPechatColorCount(title) != null ||
      productionMapPechatColorCount(apparatus) != null;
  if (locked) {
    return AdminApparatusQueuePolicy(
      apparatus: title,
      policy: ApparatusQueuePolicy.strictSequence,
      locked: true,
      reason: 'pechat_always_strict',
    );
  }
  return _testModeApparatusQueuePolicies[title] ??
      _testModeApparatusQueuePolicies[apparatus.trim()] ??
      AdminApparatusQueuePolicy(
        apparatus: title,
        policy: ApparatusQueuePolicy.strictSequence,
      );
}

AdminProgressBatch _testModeProgressBatch({
  required String apparatus,
  required String orderId,
  required String action,
  required String status,
  required double producedQty,
  required String uom,
  double? returnInkKg,
  double? totalWaste,
  double? finishedGoodsKg,
  double? finishedGoodsMeter,
}) {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final batchId = 'test-progress-$stamp-$orderId-$action';
  final qrPayload = 'GSP:$batchId'.toUpperCase();
  final executor = AppSession.instance.profile?.displayName.trim() ?? '';
  return AdminProgressBatch(
    batchId: batchId,
    sessionId: 'test-session-$orderId',
    apparatus: apparatus,
    orderId: orderId,
    action: action,
    status: status,
    producedQty: producedQty,
    uom: uom,
    qrPayload: qrPayload,
    labelItemCode: orderId,
    labelItemName: '$orderId yarim tayyor, $apparatus holatda, $status',
    executorName: executor,
    returnInkKg: returnInkKg,
    totalWaste: totalWaste,
    finishedGoodsKg: finishedGoodsKg,
    finishedGoodsMeter: finishedGoodsMeter,
  );
}
