part of '../mobile_api.dart';

class AdminCompletedQueueOrder {
  const AdminCompletedQueueOrder({
    required this.apparatus,
    required this.orderId,
    required this.completedAtUnix,
    this.status = 'completed',
    this.issueNote = '',
  });

  final String apparatus;
  final String orderId;
  final int completedAtUnix;
  final String status;
  final String issueNote;

  factory AdminCompletedQueueOrder.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().trim() ?? '';
    return AdminCompletedQueueOrder(
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      status: status.isEmpty ? 'completed' : status,
      issueNote: json['issue_note']?.toString() ?? '',
    );
  }
}

class AdminFrozenQueueOrder {
  const AdminFrozenQueueOrder({
    required this.apparatus,
    required this.orderId,
    required this.issueNote,
    required this.frozenAtUnix,
    required this.frozenBy,
  });

  final String apparatus;
  final String orderId;
  final String issueNote;
  final int frozenAtUnix;
  final String frozenBy;

  factory AdminFrozenQueueOrder.fromJson(
    Map<String, dynamic> json, {
    String fallbackApparatus = '',
  }) {
    final rawApparatus = json['apparatus']?.toString().trim() ?? '';
    final apparatus = _requireCanonicalApparatusId(
      rawApparatus.isEmpty ? fallbackApparatus : rawApparatus,
    );
    return AdminFrozenQueueOrder(
      apparatus: apparatus,
      orderId: json['order_id']?.toString() ?? '',
      issueNote: json['issue_note']?.toString() ?? '',
      frozenAtUnix: (json['frozen_at_unix'] as num?)?.toInt() ?? 0,
      frozenBy: json['frozen_by']?.toString() ?? '',
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
    this.zeroMetricCodes = const [],
    this.noticeKind = 'completion_request',
    this.decisionRequired = true,
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
  final List<String> zeroMetricCodes;
  final String noticeKind;
  final bool decisionRequired;
  final int createdAtUnix;

  factory AdminCompletionRequestNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminCompletionRequestNotification(
      eventId: json['event_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderTitle: json['order_title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      zeroMetricCodes: [
        if (json['zero_metric_codes'] is List)
          for (final code in json['zero_metric_codes'] as List)
            if (code.toString().trim().isNotEmpty) code.toString().trim(),
      ],
      noticeKind: json['notice_kind']?.toString() ?? 'completion_request',
      decisionRequired: json['decision_required'] is bool
          ? json['decision_required'] as bool
          : true,
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
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
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
    this.transfer,
    this.freeze,
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
  final AdminProductionOrderTransferDetails? transfer;
  final AdminProductionOrderFreezeDetails? freeze;

  factory AdminProductionOrderLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminProductionOrderLogEntry(
      eventId: json['event_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
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
      transfer: json['transfer'] is Map
          ? AdminProductionOrderTransferDetails.fromJson(
              (json['transfer'] as Map).cast<String, dynamic>(),
            )
          : null,
      freeze: json['freeze'] is Map
          ? AdminProductionOrderFreezeDetails.fromJson(
              (json['freeze'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class AdminProductionOrderTransferDetails {
  const AdminProductionOrderTransferDetails({
    required this.transferId,
    required this.fromApparatus,
    required this.toApparatus,
    required this.reason,
    required this.sessionId,
    required this.progressBatchId,
    required this.materialBarcodes,
  });

  final String transferId;
  final String fromApparatus;
  final String toApparatus;
  final String reason;
  final String sessionId;
  final String progressBatchId;
  final List<String> materialBarcodes;

  factory AdminProductionOrderTransferDetails.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminProductionOrderTransferDetails(
      transferId: json['transfer_id']?.toString() ?? '',
      fromApparatus: _requireCanonicalApparatusId(
        json['from_apparatus']?.toString() ?? '',
      ),
      toApparatus: _requireCanonicalApparatusId(
        json['to_apparatus']?.toString() ?? '',
      ),
      reason: json['reason']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      progressBatchId: json['progress_batch_id']?.toString() ?? '',
      materialBarcodes: [
        for (final item in json['material_barcodes'] as List? ?? const [])
          item.toString(),
      ],
    );
  }
}

class AdminProductionOrderFreezeDetails {
  const AdminProductionOrderFreezeDetails({
    required this.requestId,
    required this.status,
    required this.targetSessionId,
    required this.targetApparatus,
    required this.targetWorkerRole,
    required this.targetWorkerRef,
    required this.targetWorkerDisplayName,
    required this.requestedAtUnix,
    required this.transitionedAtUnix,
  });

  final String requestId;
  final String status;
  final String targetSessionId;
  final String targetApparatus;
  final String targetWorkerRole;
  final String targetWorkerRef;
  final String targetWorkerDisplayName;
  final int requestedAtUnix;
  final int transitionedAtUnix;

  factory AdminProductionOrderFreezeDetails.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminProductionOrderFreezeDetails(
      requestId: json['request_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      targetSessionId: json['target_session_id']?.toString() ?? '',
      targetApparatus: _requireCanonicalApparatusId(
        json['target_apparatus']?.toString() ?? '',
      ),
      targetWorkerRole: json['target_worker_role']?.toString() ?? '',
      targetWorkerRef: json['target_worker_ref']?.toString() ?? '',
      targetWorkerDisplayName:
          json['target_worker_display_name']?.toString() ?? '',
      requestedAtUnix: (json['requested_at_unix'] as num?)?.toInt() ?? 0,
      transitionedAtUnix: (json['transitioned_at_unix'] as num?)?.toInt() ?? 0,
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
    this.progressBatches = const [],
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
  final List<AdminProgressBatch> progressBatches;

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
      progressBatches: [
        for (final item in json['progress_batches'] as List? ?? const [])
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
      ],
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

class AdminProductionOrderStatusDetail {
  const AdminProductionOrderStatusDetail({
    this.lifecycleStatus = '',
    this.orderStatus = '',
    this.workStatus = '',
    this.flowStatus = '',
    this.stockStatus = '',
    this.totalWipCount = 0,
    this.waitingWipCount = 0,
    this.inUseWipCount = 0,
    this.processedWipCount = 0,
    this.waitingNextStageCount = 0,
    this.consumedByNextStageCount = 0,
    this.freeWipCount = 0,
    this.acceptedWipCount = 0,
    this.activeSessionCount = 0,
    this.pausedSessionCount = 0,
    this.rollDetachedSessionCount = 0,
    this.completedQueueCount = 0,
    this.completedWithIssueCount = 0,
  });

  final String lifecycleStatus;
  final String orderStatus;
  final String workStatus;
  final String flowStatus;
  final String stockStatus;
  final int totalWipCount;
  final int waitingWipCount;
  final int inUseWipCount;
  final int processedWipCount;
  final int waitingNextStageCount;
  final int consumedByNextStageCount;
  final int freeWipCount;
  final int acceptedWipCount;
  final int activeSessionCount;
  final int pausedSessionCount;
  final int rollDetachedSessionCount;
  final int completedQueueCount;
  final int completedWithIssueCount;

  factory AdminProductionOrderStatusDetail.fromJson(Object? raw) {
    if (raw is! Map) {
      return const AdminProductionOrderStatusDetail();
    }
    final json = raw.cast<String, dynamic>();
    return AdminProductionOrderStatusDetail(
      lifecycleStatus: json['lifecycle_status']?.toString() ?? '',
      orderStatus: json['order_status']?.toString() ?? '',
      workStatus: json['work_status']?.toString() ?? '',
      flowStatus: json['flow_status']?.toString() ?? '',
      stockStatus: json['stock_status']?.toString() ?? '',
      totalWipCount: (json['total_wip_count'] as num?)?.toInt() ?? 0,
      waitingWipCount: (json['waiting_wip_count'] as num?)?.toInt() ?? 0,
      inUseWipCount: (json['in_use_wip_count'] as num?)?.toInt() ?? 0,
      processedWipCount: (json['processed_wip_count'] as num?)?.toInt() ?? 0,
      waitingNextStageCount:
          (json['waiting_next_stage_count'] as num?)?.toInt() ?? 0,
      consumedByNextStageCount:
          (json['consumed_by_next_stage_count'] as num?)?.toInt() ?? 0,
      freeWipCount: (json['free_wip_count'] as num?)?.toInt() ??
          (json['finished_pending_acceptance_count'] as num?)?.toInt() ??
          0,
      acceptedWipCount: (json['accepted_wip_count'] as num?)?.toInt() ?? 0,
      activeSessionCount: (json['active_session_count'] as num?)?.toInt() ?? 0,
      pausedSessionCount: (json['paused_session_count'] as num?)?.toInt() ?? 0,
      rollDetachedSessionCount:
          (json['roll_detached_session_count'] as num?)?.toInt() ?? 0,
      completedQueueCount:
          (json['completed_queue_count'] as num?)?.toInt() ?? 0,
      completedWithIssueCount:
          (json['completed_with_issue_count'] as num?)?.toInt() ?? 0,
    );
  }

  AdminProductionOrderStatusDetail copyWith({
    String? lifecycleStatus,
    String? orderStatus,
    String? workStatus,
    String? flowStatus,
  }) {
    return AdminProductionOrderStatusDetail(
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      orderStatus: orderStatus ?? this.orderStatus,
      workStatus: workStatus ?? this.workStatus,
      flowStatus: flowStatus ?? this.flowStatus,
      stockStatus: stockStatus,
      totalWipCount: totalWipCount,
      waitingWipCount: waitingWipCount,
      inUseWipCount: inUseWipCount,
      processedWipCount: processedWipCount,
      waitingNextStageCount: waitingNextStageCount,
      consumedByNextStageCount: consumedByNextStageCount,
      freeWipCount: freeWipCount,
      acceptedWipCount: acceptedWipCount,
      activeSessionCount: activeSessionCount,
      pausedSessionCount: pausedSessionCount,
      rollDetachedSessionCount: rollDetachedSessionCount,
      completedQueueCount: completedQueueCount,
      completedWithIssueCount: completedWithIssueCount,
    );
  }
}

Map<String, Map<String, String>> _parseProductionMapStageStates(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  final result = <String, Map<String, String>>{};
  for (final orderEntry in raw.entries) {
    final orderId = orderEntry.key.toString().trim();
    final stages = orderEntry.value;
    if (orderId.isEmpty || stages is! Map) {
      continue;
    }
    result[orderId] = Map<String, String>.unmodifiable({
      for (final stageEntry in stages.entries)
        if (stageEntry.key.toString().trim().isNotEmpty)
          stageEntry.key.toString().trim():
              stageEntry.value.toString().trim().toLowerCase(),
    });
  }
  return Map<String, Map<String, String>>.unmodifiable(result);
}

extension MobileApiAdminOrderLifecycle on MobileApi {
Future<List<AdminProgressBatch>> adminWipBatches({
    String status = '',
    String apparatus = '',
    String nextApparatus = '',
    String currentLocation = '',
    String orderId = '',
    int limit = 100,
  }) async {
    final normalizedStatus = status.trim();
    final normalizedApparatus = _requireCanonicalApparatusId(
      apparatus,
      allowEmpty: true,
    );
    final normalizedNextApparatus = _requireCanonicalApparatusId(
      nextApparatus,
      allowEmpty: true,
    );
    final normalizedCurrentLocation = currentLocation.trim();
    final normalizedOrderId = orderId.trim();
    final boundedLimit = limit.clamp(1, 1000).toInt();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeProgressBatchesByQr.values
          .where((batch) {
            if (normalizedStatus.isNotEmpty &&
                !_wipStatusMatchesFilter(batch.wipStatus, normalizedStatus)) {
              return false;
            }
            if (normalizedApparatus.isNotEmpty &&
                batch.currentApparatus.trim() != normalizedApparatus &&
                batch.apparatus.trim() != normalizedApparatus) {
              return false;
            }
            if (normalizedNextApparatus.isNotEmpty &&
                batch.nextApparatus.trim().isNotEmpty &&
                batch.nextApparatus.trim() != normalizedNextApparatus) {
              return false;
            }
            if (normalizedCurrentLocation.isNotEmpty &&
                batch.currentLocation.trim() != normalizedCurrentLocation) {
              return false;
            }
            if (normalizedOrderId.isNotEmpty &&
                batch.orderId.trim() != normalizedOrderId) {
              return false;
            }
            return true;
          })
          .take(boundedLimit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/wip-batches',
        ).replace(
          queryParameters: {
            if (normalizedStatus.isNotEmpty) 'status': normalizedStatus,
            if (normalizedApparatus.isNotEmpty)
              'apparatus': normalizedApparatus,
            if (normalizedNextApparatus.isNotEmpty)
              'next_apparatus': normalizedNextApparatus,
            if (normalizedCurrentLocation.isNotEmpty)
              'current_location': normalizedCurrentLocation,
            if (normalizedOrderId.isNotEmpty) 'order_id': normalizedOrderId,
            'limit': boundedLimit.toString(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'wip_batches');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batches'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

Future<List<AdminCompletedQueueOrder>>
      adminCompletedProductionMapOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceCompletedProductionMapOrdersLoadFailure) {
        throw const MobileApiException(
          code: 'completed_orders',
          message: 'Yakunlangan orderlar yuklanmadi',
        );
      }
      final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
      return [
        for (final item in _testModeCompletedQueueOrders)
          if (item.actorRef == actorRef) item.order,
      ];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/completed-orders'),
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
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/completion-requests',
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
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/completion-requests/decision',
        ),
        headers: _headers(requireToken()),
        body: jsonEncode({'event_id': eventId, 'decision': decision}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'completion_request_decision',
      );
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
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/completion-request-decisions',
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
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/closed-orders'),
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

Future<AdminLaminatsiyaAstatkaReport> adminLaminatsiyaAstatkaReport({
    required String apparatus,
    required String orderId,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? totalWaste,
    double? finishedGoodsMeter,
    double? finishedGoodsKg,
    double? bobinaKg,
    String description = '',
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedOrderId = orderId.trim();
    bool isNonNegative(double? value) =>
        value != null && value.isFinite && value >= 0;
    bool isPositive(double? value) =>
        value != null && value.isFinite && value > 0;
    if (!isCanonicalApparatusId(normalizedApparatus) ||
        normalizedOrderId.isEmpty ||
        !isNonNegative(laminationPrintLeftoverRolls) ||
        !isNonNegative(laminationFilmLeftoverRolls) ||
        !isNonNegative(totalWaste) ||
        (finishedGoodsMeter != null && !isPositive(finishedGoodsMeter)) ||
        (finishedGoodsKg != null && !isPositive(finishedGoodsKg)) ||
        (bobinaKg != null && !isPositive(bobinaKg))) {
      throw const MobileApiException(
        code: 'laminatsiya_astatka_metrics_required',
        message: 'Metraj, og‘irlik, babina va chiqindini to‘g‘ri kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeRequiredApparatus(normalizedApparatus)
              .operation
              .trim()
              .toLowerCase() !=
          'laminate') {
        throw const MobileApiException(
          code: 'laminatsiya_astatka_metrics_required',
          message: 'Tanlangan aparat laminatsiya apparati emas',
        );
      }
      final previous = _testModeLaminatsiyaAstatkaReports
          .where((report) => report.orderId.trim() == normalizedOrderId)
          .fold<AdminLaminatsiyaAstatkaReport?>(null, (current, report) {
        if (current == null || report.toAtUnix > current.toAtUnix) {
          return report;
        }
        return current;
      });
      final fromAtUnix =
          previous?.toAtUnix ?? _testModeOrderStartedAtUnix[normalizedOrderId];
      if (fromAtUnix == null) {
        throw const MobileApiException(
          code: 'order_not_started',
          message: 'Order hali boshlanmagan',
        );
      }
      final now = _testModeUnixSeconds();
      final report = AdminLaminatsiyaAstatkaReport(
        reportId:
            'test-laminatsiya-astatka-${DateTime.now().microsecondsSinceEpoch}-$normalizedOrderId',
        orderId: normalizedOrderId,
        apparatus: normalizedApparatus,
        fromAtUnix: fromAtUnix,
        toAtUnix: now,
        laminationPrintLeftoverRolls: laminationPrintLeftoverRolls!,
        laminationFilmLeftoverRolls: laminationFilmLeftoverRolls!,
        totalWaste: totalWaste!,
        finishedGoodsMeter: finishedGoodsMeter,
        finishedGoodsKg: finishedGoodsKg,
        bobinaKg: bobinaKg,
        workerRole: AppSession.instance.profile?.role.name ?? '',
        workerRef: AppSession.instance.profile?.ref.trim() ?? '',
        workerDisplayName:
            AppSession.instance.profile?.displayName.trim() ?? '',
        description: description.trim(),
        createdAtUnix: now,
      );
      _testModeLaminatsiyaAstatkaReports.add(report);
      return report;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/laminatsiya-astatka',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': normalizedOrderId,
          'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
          'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
          'total_waste': totalWaste,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (description.trim().isNotEmpty) 'description': description.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'laminatsiya_astatka_report_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawReport = payload['report'];
    if (rawReport is! Map) {
      throw const MobileApiException(
        code: 'laminatsiya_astatka_invalid_response',
        message: 'Astatka qaydi javobi noto‘g‘ri',
      );
    }
    return AdminLaminatsiyaAstatkaReport.fromJson(
      rawReport.cast<String, dynamic>(),
    );
  }

Future<AdminRezkaAstatkaReport> adminRezkaAstatkaReport({
    required String apparatus,
    required String orderId,
    double? totalWaste,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? finishedGoodsMeter,
    double? finishedGoodsKg,
    double? bobinaKg,
    String description = '',
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedOrderId = orderId.trim();
    bool isNonNegative(double? value) =>
        value != null && value.isFinite && value >= 0;
    bool isPositive(double? value) =>
        value != null && value.isFinite && value > 0;
    if (!isCanonicalApparatusId(normalizedApparatus) ||
        normalizedOrderId.isEmpty ||
        !isNonNegative(totalWaste) ||
        !isNonNegative(rezkaBosmaWaste) ||
        !isNonNegative(rezkaLaminationWaste) ||
        !isNonNegative(rezkaEdgeWaste) ||
        (finishedGoodsMeter != null && !isPositive(finishedGoodsMeter)) ||
        (finishedGoodsKg != null && !isPositive(finishedGoodsKg)) ||
        (bobinaKg != null && !isPositive(bobinaKg))) {
      throw const MobileApiException(
        code: 'rezka_astatka_metrics_required',
        message:
            'Rezka metraj, og‘irlik, babina va chiqindisini to‘g‘ri kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeRequiredApparatus(normalizedApparatus)
              .operation
              .trim()
              .toLowerCase() !=
          'cut') {
        throw const MobileApiException(
          code: 'rezka_astatka_metrics_required',
          message: 'Tanlangan aparat kesish apparati emas',
        );
      }
      final previous = _testModeRezkaAstatkaReports
          .where((report) => report.orderId.trim() == normalizedOrderId)
          .fold<AdminRezkaAstatkaReport?>(null, (current, report) {
        if (current == null || report.toAtUnix > current.toAtUnix) {
          return report;
        }
        return current;
      });
      final fromAtUnix =
          previous?.toAtUnix ?? _testModeOrderStartedAtUnix[normalizedOrderId];
      if (fromAtUnix == null) {
        throw const MobileApiException(
          code: 'order_not_started',
          message: 'Order hali boshlanmagan',
        );
      }
      final now = _testModeUnixSeconds();
      final report = AdminRezkaAstatkaReport(
        reportId:
            'test-rezka-astatka-${DateTime.now().microsecondsSinceEpoch}-$normalizedOrderId',
        orderId: normalizedOrderId,
        apparatus: normalizedApparatus,
        fromAtUnix: fromAtUnix,
        toAtUnix: now,
        totalWaste: totalWaste!,
        rezkaBosmaWaste: rezkaBosmaWaste!,
        rezkaLaminationWaste: rezkaLaminationWaste!,
        rezkaEdgeWaste: rezkaEdgeWaste!,
        finishedGoodsMeter: finishedGoodsMeter,
        finishedGoodsKg: finishedGoodsKg,
        bobinaKg: bobinaKg,
        workerRole: AppSession.instance.profile?.role.name ?? '',
        workerRef: AppSession.instance.profile?.ref.trim() ?? '',
        workerDisplayName:
            AppSession.instance.profile?.displayName.trim() ?? '',
        description: description.trim(),
        createdAtUnix: now,
      );
      _testModeRezkaAstatkaReports.add(report);
      return report;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/rezka-astatka'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': normalizedOrderId,
          'total_waste': totalWaste,
          'rezka_bosma_waste': rezkaBosmaWaste,
          'rezka_lamination_waste': rezkaLaminationWaste,
          'rezka_edge_waste': rezkaEdgeWaste,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (description.trim().isNotEmpty) 'description': description.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'rezka_astatka_report_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawReport = payload['report'];
    if (rawReport is! Map) {
      throw const MobileApiException(
        code: 'rezka_astatka_invalid_response',
        message: 'Rezka astatka javobi noto‘g‘ri',
      );
    }
    return AdminRezkaAstatkaReport.fromJson(rawReport.cast<String, dynamic>());
  }
}
