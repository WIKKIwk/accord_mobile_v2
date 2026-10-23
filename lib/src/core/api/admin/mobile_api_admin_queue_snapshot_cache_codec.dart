part of '../mobile_api.dart';

/// Accept decoded local values so a background cache reader need not encode
/// a multi-megabyte snapshot again before converting it to typed models.
AdminApparatusQueueSnapshot decodeCachedProductionMapQueueSnapshot(
        Map<String, dynamic> value) =>
    _productionMapQueueSnapshotFromJson(value);

/// A local wire representation of a canonical snapshot, never an optimistic
/// screen overlay. Action contracts retain their complete server payload.
Map<String, dynamic> encodeProductionMapQueueSnapshot(
  AdminApparatusQueueSnapshot snapshot, {
  List<AdminCompletedQueueOrder>? completedOrders,
  List<AdminCompletionRequestNotification>? completionRequests,
  List<AdminCompletionRequestDecisionNotification>? completionRequestDecisions,
}) {
  snapshot.validateContract();
  final live = snapshot is AdminProductionMapLiveSnapshot ? snapshot : null;
  final encoded = <String, dynamic>{
    'ok': true,
    'rev': snapshot.revision,
    'epoch': snapshot.epoch,
    'scope': snapshot.scope,
    'worker_show_all_apparatus_tabs': snapshot.workerShowAllApparatusTabs,
    'maps': [
      for (final saved in snapshot.maps) encodeCachedProductionMap(saved)
    ],
    if (snapshot.calculationTemplates.isNotEmpty)
      'calculation_templates': {
        for (final entry in snapshot.calculationTemplates.entries)
          entry.key: entry.value.toJson(),
      },
    'sequences': snapshot.sequences,
    'sequence_versions': snapshot.sequenceVersions,
    'sequence_revisions': snapshot.sequenceRevisions,
    'sequence_positions_by_apparatus': snapshot.sequencePositionsByApparatus,
    'visible_order_ids': snapshot.visibleOrderIds,
    'queue_states': snapshot.queueStates,
    'stage_states': snapshot.stageStates,
    'queue_policies': [
      for (final policy in snapshot.queuePolicies.values)
        {...policy.toJson(), 'policy': policy.policy.apiValue},
    ],
    'queue_action_controls': {
      for (final apparatus in snapshot.queueActionControls.entries)
        apparatus.key: {
          for (final order in apparatus.value.entries)
            order.key: _cachedQueueActionContract(order.value),
        },
    },
    if (snapshot.stageFreezeSupported)
      'stage_order_controls': [
        for (final control in snapshot.stageOrderControls) control.payload,
      ],
    'order_controls': {
      for (final id in {
        ...snapshot.orderControls.keys,
        ...snapshot.earlyClosingOrderIds
      })
        id: {
          'state': snapshot.orderControlFor(id).apiValue,
          if (snapshot.earlyClosingOrderIds.contains(id))
            'early_close': <String, dynamic>{},
        },
    },
    'order_customers': snapshot.orderCustomers,
    'order_statuses': {
      for (final entry in snapshot.orderStatuses.entries)
        entry.key: {
          'lifecycle_status': entry.value.lifecycleStatus,
          'order_status': entry.value.orderStatus,
          'work_status': entry.value.workStatus,
          'flow_status': entry.value.flowStatus,
          'stock_status': entry.value.stockStatus,
          'completed_with_issue_count': entry.value.completedWithIssueCount,
        },
    },
    'frozen_orders_by_apparatus': {
      for (final entry in snapshot.frozenOrdersByApparatus.entries)
        entry.key: [
          for (final value in entry.value)
            {
              'apparatus': value.apparatus,
              'order_id': value.orderId,
              'issue_note': value.issueNote,
              'frozen_at_unix': value.frozenAtUnix,
              'frozen_by': value.frozenBy,
            },
        ],
    },
    'completed_orders': [
      for (final value in completedOrders ??
          live?.completedOrders ??
          const <AdminCompletedQueueOrder>[])
        {
          'apparatus': value.apparatus,
          'order_id': value.orderId,
          'completed_at_unix': value.completedAtUnix,
          'status': value.status,
          'issue_note': value.issueNote,
        },
    ],
    'completion_requests': [
      for (final value in completionRequests ??
          live?.completionRequests ??
          const <AdminCompletionRequestNotification>[])
        {
          'event_id': value.eventId,
          'apparatus': value.apparatus,
          'order_id': value.orderId,
          'order_number': value.orderNumber,
          'order_title': value.orderTitle,
          'product_code': value.productCode,
          'worker_role': value.workerRole,
          'worker_ref': value.workerRef,
          'worker_display_name': value.workerDisplayName,
          'description': value.description,
          'zero_metric_codes': value.zeroMetricCodes,
          'notice_kind': value.noticeKind,
          'decision_required': value.decisionRequired,
          'created_at_unix': value.createdAtUnix,
        },
    ],
    'completion_request_decisions': [
      for (final value in completionRequestDecisions ??
          live?.completionRequestDecisions ??
          const <AdminCompletionRequestDecisionNotification>[])
        {
          'event_id': value.eventId,
          'request_event_id': value.requestEventId,
          'decision': value.decision,
          'apparatus': value.apparatus,
          'order_id': value.orderId,
          'order_number': value.orderNumber,
          'order_title': value.orderTitle,
          'product_code': value.productCode,
          'worker_role': value.workerRole,
          'worker_ref': value.workerRef,
          'worker_display_name': value.workerDisplayName,
          'decided_by_role': value.decidedByRole,
          'decided_by_ref': value.decidedByRef,
          'decided_by_display_name': value.decidedByDisplayName,
          'description': value.description,
          'message': value.message,
          'created_at_unix': value.createdAtUnix,
        },
    ],
  };
  if (snapshot.isWorkerList) {
    encoded.removeWhere((key, _) => _workerListForbiddenFields.contains(key));
    encoded.addAll({
      'projection': workerOrderListProjection,
      'worker_list_rows': {
        for (final entry in snapshot.workerListRows.entries)
          entry.key: entry.value.toJson(),
      },
      'worker_display_states': snapshot.workerDisplayStates,
      'worker_pending_report_ids': snapshot.workerPendingReportIds,
      'worker_report_prompts': {
        for (final scope in snapshot.workerReportPrompts.entries)
          scope.key: {
            for (final entry in scope.value.entries)
              entry.key: entry.value.toJson(),
          },
      },
    });
  } else if (snapshot.projection.isNotEmpty) {
    encoded['projection'] = snapshot.projection;
  }
  return encoded;
}

Map<String, dynamic> _cachedQueueActionContract(
    AdminApparatusQueueOrderActionControl control) {
  // Rebuilding this from presentation fields could lose future authority
  // fields. A locally constructed control without its wire payload is not a
  // persistable server baseline.
  final raw = jsonDecode(control.serverContractSignature);
  if (raw is! Map) {
    throw const FormatException('Missing server action contract');
  }
  return raw.cast<String, dynamic>();
}

Map<String, dynamic> encodeCachedProductionMap(ProductionMapSaved saved) => {
      'map': {
        ...saved.map.toJson(),
        // The edit serializer trims labels. A cache must preserve what the
        // server actually supplied, including whitespace in display strings.
        'code': saved.map.code,
        'order_number': saved.map.orderNumber,
        'customer_name': saved.map.customerName,
        'image_id': saved.map.imageId,
        'nodes': [
          for (final node in saved.map.nodes)
            {
              ...node.toJson(),
              'apparatus_id': node.apparatusId,
              'role_code': node.roleCode,
              'item_code': node.itemCode,
              'qty_formula': node.qtyFormula,
              'from_location': node.fromLocation,
              'to_location': node.toLocation,
              'alternative_group_id': node.alternativeGroupId,
              'alternative_group_label': node.alternativeGroupLabel,
              'alternative_assigned_title': node.alternativeAssignedTitle,
            },
        ],
        'edges': [
          for (final edge in saved.map.edges)
            {...edge.toJson(), 'branch': edge.branch},
        ],
      },
      'program': {
        'map_id': saved.program.mapId,
        'product_code': saved.program.productCode,
        'operations': [
          for (final operation in saved.program.operations)
            {
              'order': operation.order,
              'node_id': operation.nodeId,
              'op_code': operation.opCode,
              'args': operation.args,
            },
        ],
      },
    };
