part of '../mobile_api.dart';

AdminOrderControlState? _applyTestModeOrderControl(
  String orderId,
  AdminOrderControlAction action,
) {
  final current =
      _testModeOrderControls[orderId] ?? AdminOrderControlState.active;
  final states = <String>[];
  for (final apparatusStates in _testModeApparatusQueueStates.values) {
    final state = apparatusStates[orderId]?.trim();
    if (state != null && state.isNotEmpty) states.add(state);
  }
  final started = states.any((state) => state != 'pending');
  final hasActiveWork = states.contains('in_progress');
  final hasFrozenState = states.any((state) => state == 'frozen');
  final completed = _testModeProductionMaps
      .where((saved) => saved.map.id.trim() == orderId)
      .map((saved) => saved.map)
      .any((map) {
    final stages = productionMapLinearWorkStages(map)
        .where((stage) => stage.isApparatus)
        .toList(growable: false);
    return stages.isNotEmpty &&
        stages.every((stage) {
          return _testModeApparatusQueueStates[stage.stageId]?[orderId] ==
              'completed';
        });
  });

  switch (action) {
    case AdminOrderControlAction.freeze:
      if (current != AdminOrderControlState.active) {
        throw const MobileApiException(
          code: 'order_control_action_not_allowed',
          message: 'Buyurtmaning hozirgi holatida bu amal mumkin emas',
        );
      }
      if (!started) {
        throw const MobileApiException(
          code: 'order_not_started',
          message: 'Boshlanmagan buyurtmani muzlatib bo‘lmaydi',
        );
      }
      if (completed) {
        throw const MobileApiException(
          code: 'order_already_completed',
          message: 'Tugallangan buyurtmani muzlatib bo‘lmaydi',
        );
      }
      if (hasFrozenState) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma boshqa apparatda muzlatilgan',
        );
      }
      final next = hasActiveWork
          ? AdminOrderControlState.freezeRequested
          : AdminOrderControlState.frozen;
      _testModeOrderControls[orderId] = next;
      if (next == AdminOrderControlState.frozen) {
        _testModeFreezeOrderQueue(orderId);
      }
      return next;
    case AdminOrderControlAction.cancelFreeze:
      if (current != AdminOrderControlState.freezeRequested) {
        throw const MobileApiException(
          code: 'order_control_action_not_allowed',
          message: 'Buyurtmaning hozirgi holatida bu amal mumkin emas',
        );
      }
      _testModeOrderControls[orderId] = AdminOrderControlState.active;
      return AdminOrderControlState.active;
    case AdminOrderControlAction.unfreeze:
      if (current != AdminOrderControlState.frozen) {
        throw const MobileApiException(
          code: 'order_control_action_not_allowed',
          message: 'Buyurtmaning hozirgi holatida bu amal mumkin emas',
        );
      }
      MapEntry<String, Map<String, String>>? target;
      for (final entry in _testModeApparatusQueueStates.entries) {
        if (entry.value[orderId]?.trim().toLowerCase() == 'frozen') {
          target = entry;
          break;
        }
      }
      if (target != null) {
        target.value[orderId] = 'pending';
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: target.key,
          status: 'active',
        );
      }
      _testModeRequeueOrderAtTail(orderId);
      _testModeFrozenIssueNotesByOrderId.remove(orderId);
      _testModeRequeuedOrderIds.add(orderId);
      _testModeOrderControls[orderId] = AdminOrderControlState.active;
      return AdminOrderControlState.active;
    case AdminOrderControlAction.delete:
      final blockers = <String>[];
      final visibleByApparatus = _testModeVisibleOrderIdsByApparatus();
      for (final apparatus in {
        ..._testModeApparatusSequences.keys,
        ...visibleByApparatus.keys,
      }) {
        final sequence = effectiveQueueSequence(
          sequence: _testModeApparatusSequences[apparatus] ?? const [],
          visibleOrderIds: visibleByApparatus[apparatus] ?? const [],
        );
        if (sequence.isNotEmpty && sequence.first == orderId) {
          blockers.add('Buyurtma $apparatus ketma-ketligida 1-o‘rinda turibdi');
        }
      }
      if (started) {
        blockers.add('Buyurtmada ish jarayoni allaqachon boshlangan');
      }
      final materialCount = _testModeRawMaterialAssignments
          .where((assignment) => assignment.orderId.trim() == orderId)
          .length;
      if (materialCount > 0) {
        blockers.add('Buyurtmaga $materialCount ta homashyo biriktirilgan');
      }
      if (blockers.isNotEmpty) {
        throw MobileApiException(
          code: 'order_delete_blocked',
          message: blockers.join('\n'),
          details: blockers,
        );
      }
      _testModeProductionMaps.removeWhere(
        (saved) => saved.map.id.trim() == orderId,
      );
      for (final sequence in _testModeApparatusSequences.values) {
        sequence.removeWhere((id) => id.trim() == orderId);
      }
      for (final apparatusStates in _testModeApparatusQueueStates.values) {
        apparatusStates.remove(orderId);
      }
      _testModeOrderControls.remove(orderId);
      _testModeFrozenIssueNotesByOrderId.remove(orderId);
      _testModeRequeuedOrderIds.remove(orderId);
      return null;
  }
}

Map<String, AdminOrderControlState> _parseAdminOrderControls(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key.toString().trim().isNotEmpty)
        entry.key.toString().trim(): AdminOrderControlState.fromRaw(
          entry.value is Map ? (entry.value as Map)['state'] : entry.value,
        ),
  };
}

Map<String, List<AdminFrozenQueueOrder>> _parseAdminFrozenOrdersByApparatus(
  Object? raw,
) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
      'frozen_orders_by_apparatus must be an object',
    );
  }
  final result = <String, List<AdminFrozenQueueOrder>>{};
  for (final entry in raw.entries) {
    final apparatus = entry.key.toString().trim();
    final rawOrders = entry.value;
    if (!isCanonicalApparatusId(apparatus) || rawOrders is! List) {
      throw _productionMapQueueContractException(
        'frozen_orders_by_apparatus contains an invalid apparatus',
      );
    }
    final orders = <AdminFrozenQueueOrder>[];
    for (final item in rawOrders) {
      if (item is! Map) {
        continue;
      }
      final frozen = AdminFrozenQueueOrder.fromJson(
        item.cast<String, dynamic>(),
        fallbackApparatus: apparatus,
      );
      if (frozen.orderId.trim().isNotEmpty) {
        orders.add(frozen);
      }
    }
    if (orders.isNotEmpty) {
      result[apparatus] = List<AdminFrozenQueueOrder>.unmodifiable(orders);
    }
  }
  return Map<String, List<AdminFrozenQueueOrder>>.unmodifiable(result);
}

AdminApparatusQueuePolicy _effectiveTestModeQueuePolicy(
  String apparatusId,
) {
  final canonical = _testModeRequiredApparatus(apparatusId);
  final locked = canonical.operation.trim().toLowerCase() == 'print';
  if (locked) {
    return AdminApparatusQueuePolicy(
      apparatusId: canonical.id,
      apparatus: canonical.name,
      policy: ApparatusQueuePolicy.strictSequence,
      locked: true,
      reason: 'pechat_always_strict',
    );
  }
  return _testModeApparatusQueuePolicies[canonical.id] ??
      AdminApparatusQueuePolicy(
        apparatusId: canonical.id,
        apparatus: canonical.name,
        policy: ApparatusQueuePolicy.strictSequence,
      );
}

extension MobileApiAdminQueueState on MobileApi {
Future<Map<String, List<String>>> adminProductionMapSequences() async {
    final snapshot = await adminProductionMapQueueSnapshot();
    return snapshot.sequences;
  }

Future<AdminApparatusQueueSnapshot> adminProductionMapQueueSnapshot() async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceProductionMapQueueSnapshotLoadFailure) {
        throw const MobileApiException(
          code: 'store_failed',
          message: 'Ish rejasi navbati serverdan yuklanmadi',
        );
      }
      final orderControls = Map<String, AdminOrderControlState>.unmodifiable(
        _testModeOrderControls,
      );
      final snapshot = AdminApparatusQueueSnapshot(
        sequences: _testModeEffectiveQueueSequences(),
        visibleOrderIds: _testModeVisibleOrderIdsByApparatus(),
        queueStates: {
          for (final entry in _testModeApparatusQueueStates.entries)
            entry.key: Map<String, String>.unmodifiable(entry.value),
        },
        queuePolicies: Map<String, AdminApparatusQueuePolicy>.unmodifiable(
          _testModeApparatusQueuePolicies,
        ),
        queueActionControls: _testModeQueueActionControls(),
        stageStates: {
          for (final entry in _testModeProductionMapStageStates.entries)
            entry.key: Map<String, String>.unmodifiable(entry.value),
        },
        orderControls: orderControls,
        orderCustomers: {
          for (final saved in _testModeProductionMaps)
            if (saved.map.id.trim().isNotEmpty &&
                saved.map.customerName.trim().isNotEmpty)
              saved.map.id.trim(): saved.map.customerName.trim(),
        },
        orderStatuses: const {},
        qolipOrderNotes: Map<String, AdminQolipOrderNote>.unmodifiable(
          _testModeQolipOrderNotes,
        ),
        frozenOrdersByApparatus: _testModeFrozenOrdersByApparatus(),
      );
      snapshot.validateContract();
      return snapshot;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final visibleOrderIds = _parseRequiredProductionMapVisibleOrderIds(payload);
    _requireProductionMapSnapshotShape(payload, includesMaps: false);
    final orderControls = _parseAdminOrderControls(payload['order_controls']);
    final snapshot = AdminApparatusQueueSnapshot(
      sequences: parseApparatusSequenceMap(payload['sequences']),
      visibleOrderIds: visibleOrderIds,
      queueStates: parseApparatusQueueStateMap(payload['queue_states']),
      stageStates: _parseProductionMapStageStates(payload['stage_states']),
      queuePolicies: parseApparatusQueuePolicyMap(payload['queue_policies']),
      queueActionControls: _parseAdminQueueActionControls(
        payload['queue_action_controls'],
      ),
      orderControls: orderControls,
      orderCustomers: _stringMapOfStrings(payload['order_customers']),
      orderStatuses: _parseAdminOrderStatuses(payload['order_statuses']),
      qolipOrderNotes: _parseAdminQolipOrderNotes(payload['qolip_order_notes']),
      frozenOrdersByApparatus: _parseAdminFrozenOrdersByApparatus(
        payload['frozen_orders_by_apparatus'],
      ),
    );
    snapshot.validateContract();
    return snapshot;
  }

Future<AdminOrderControlState?> adminProductionMapOrderControl({
    required String orderId,
    required AdminOrderControlAction action,
  }) async {
    final normalizedOrderId = orderId.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _applyTestModeOrderControl(normalizedOrderId, action);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-control'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          'action': action.apiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_control_failed');
    }
    if (action == AdminOrderControlAction.delete) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final control = payload['control'];
    if (control is! Map) {
      throw const MobileApiException(
        code: 'order_control_invalid_response',
        message: 'Buyurtma holati olinmadi',
      );
    }
    return AdminOrderControlState.fromRaw(control['state']);
  }

Future<Map<String, AdminApparatusQueuePolicy>>
      adminApparatusQueuePolicies() async {
    if (await TestModeController.instance.isEnabled()) {
      return Map<String, AdminApparatusQueuePolicy>.unmodifiable(
        _testModeApparatusQueuePolicies,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/queue-policies'),
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
    required String apparatusId,
    required int expectedRevision,
    required ApparatusQueuePolicy policy,
  }) async {
    final normalized = _requireCanonicalApparatusId(apparatusId);
    if (await TestModeController.instance.isEnabled()) {
      final catalog = _testModeApparatusCatalog();
      final apparatus = _firstOrNull(
        catalog.where((item) => item.id == normalized),
      );
      if (apparatus == null) {
        throw const MobileApiException(
          code: 'apparatus_not_found',
          message: 'Aparat topilmadi',
        );
      }
      final locked = apparatus.isPechat;
      if (locked && policy != ApparatusQueuePolicy.strictSequence) {
        throw const MobileApiException(
          code: 'queue_policy_locked',
          message: 'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
        );
      }
      final record = AdminApparatusQueuePolicy(
        apparatusId: normalized,
        apparatus: apparatus.name,
        sourceRevision: expectedRevision + 1,
        policy: locked ? ApparatusQueuePolicy.strictSequence : policy,
        locked: locked,
        reason: locked ? 'pechat_always_strict' : '',
      );
      _testModeApparatusQueuePolicies[normalized] = record;
      return record;
    }
    final idempotencyKey = _nextCanonicalMutationIdempotencyKey('queue-policy');
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/queue-policies'),
        headers: _canonicalMutationHeaders(requireToken(), idempotencyKey),
        body: jsonEncode({
          'apparatus_id': normalized,
          'expected_revision': expectedRevision,
          'discipline': policy.apiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_policies');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final committed = payload['revision'];
    if (committed is! Map || committed['revision'] is! Map) {
      throw const MobileApiException(
        code: 'queue_policies_invalid_response',
        message: 'Aparat navbat qoidasi javobi noto‘g‘ri',
      );
    }
    final revision = (committed['revision'] as Map).cast<String, dynamic>();
    final metadata = revision['revision_metadata'];
    final policies = revision['policies'];
    return AdminApparatusQueuePolicy(
      apparatusId: revision['apparatus_id']?.toString().trim() ?? normalized,
      apparatus: '',
      sourceRevision: metadata is Map
          ? (metadata['revision'] as num?)?.toInt() ?? expectedRevision + 1
          : expectedRevision + 1,
      sourceAasxSha256: committed['aasx_sha256']?.toString().trim() ?? '',
      policy: ApparatusQueuePolicy.fromRaw(
        policies is Map ? policies['queue'] : null,
      ),
    );
  }

Map<String, List<String>> parseApparatusSequenceMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final apparatusId = entry.key.toString().trim();
      if (!isCanonicalApparatusId(apparatusId) || entry.value is! List) {
        throw _productionMapQueueContractException(
          'sequences contains an invalid apparatus',
        );
      }
      final orderIds = <String>[];
      for (final rawOrderId in entry.value as List) {
        final orderId = rawOrderId.toString().trim();
        if (orderId.isEmpty) {
          throw _productionMapQueueContractException(
            'sequences contains an invalid order',
          );
        }
        orderIds.add(orderId);
      }
      result[apparatusId] = List<String>.unmodifiable(orderIds);
    }
    return Map<String, List<String>>.unmodifiable(result);
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
    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      final apparatusId = entry.key.toString().trim();
      if (!isCanonicalApparatusId(apparatusId) || entry.value is! Map) {
        throw _productionMapQueueContractException(
          'queue_states contains an invalid apparatus',
        );
      }
      final states = <String, String>{};
      for (final stateEntry in (entry.value as Map).entries) {
        final orderId = stateEntry.key.toString().trim();
        final state = stateEntry.value.toString().trim().toLowerCase();
        if (orderId.isEmpty || !_knownApparatusQueueStates.contains(state)) {
          throw _productionMapQueueContractException(
            'queue_states contains an invalid order state',
          );
        }
        states[orderId] = state;
      }
      result[apparatusId] = Map<String, String>.unmodifiable(states);
    }
    return Map<String, Map<String, String>>.unmodifiable(result);
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
        throw _productionMapQueueContractException(
          'queue_policies contains an invalid item',
        );
      }
      final policy = AdminApparatusQueuePolicy.fromJson(
        item.cast<String, dynamic>(),
      );
      final apparatusId = _requireCanonicalApparatusId(policy.apparatusId);
      policies[apparatusId] = policy;
    }
    return policies;
  }

Future<void> adminSaveProductionMapSequence({
    required String apparatus,
    required List<String> orderIds,
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceSequenceSaveFailure) {
        throw const MobileApiException(
          code: 'production_map_sequence',
          message: 'Ketma-ketlik saqlanmadi (test)',
        );
      }
      _testModeApparatusSequences[normalizedApparatus] = List<String>.from(
        orderIds,
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_ids': orderIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
  }
}
