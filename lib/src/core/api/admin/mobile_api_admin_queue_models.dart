part of '../mobile_api.dart';

enum AdminQueueInteractionMode {
  freshStart,
  freshStartBlocked,
  requeuedWaiting,
  requeuedReady,
  inProgress,
  freezeRequested,
  paused,
  frozen,
  completed,
  waitingPreviousStage;

  static AdminQueueInteractionMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'fresh_start' => AdminQueueInteractionMode.freshStart,
      'fresh_start_blocked' => AdminQueueInteractionMode.freshStartBlocked,
      'requeued_waiting' => AdminQueueInteractionMode.requeuedWaiting,
      'requeued_ready' => AdminQueueInteractionMode.requeuedReady,
      'in_progress' => AdminQueueInteractionMode.inProgress,
      'freeze_requested' => AdminQueueInteractionMode.freezeRequested,
      'paused' => AdminQueueInteractionMode.paused,
      'frozen' => AdminQueueInteractionMode.frozen,
      'completed' => AdminQueueInteractionMode.completed,
      'waiting_previous_stage' =>
        AdminQueueInteractionMode.waitingPreviousStage,
      _ => null,
    };
  }
}

enum AdminQueueStartMaterialsMode {
  hidden,
  scanRequired;

  static AdminQueueStartMaterialsMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'hidden' => AdminQueueStartMaterialsMode.hidden,
      'scan_required' => AdminQueueStartMaterialsMode.scanRequired,
      _ => null,
    };
  }
}

enum AdminQueuePreviousWipMode {
  notRequired,
  scanRequired,
  waiting;

  static AdminQueuePreviousWipMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'not_required' => AdminQueuePreviousWipMode.notRequired,
      'scan_required' => AdminQueuePreviousWipMode.scanRequired,
      'waiting' => AdminQueuePreviousWipMode.waiting,
      _ => null,
    };
  }
}

class AdminApparatusQueueOrderActionControl {
  const AdminApparatusQueueOrderActionControl({
    this.state = '',
    this.allowedActions = const {},
    this.interaction,
    this.hasOnlyKnownActions = false,
    this.hasRequiredFields = true,
    this.previousStage = '',
    this.stageNodeId = '',
    this.previousStageReady = false,
    this.rezkaOutputKadrCounts = const [],
    this.completeRequiresFullReport = false,
    this.completeRequiresRezkaTotalWasteOnly = false,
    this.freezeRequest,
  });

  final String state;
  final Set<String> allowedActions;
  final AdminQueueWorkerInteraction? interaction;
  final bool hasOnlyKnownActions;
  final bool hasRequiredFields;
  final String previousStage;
  final String stageNodeId;
  final bool previousStageReady;
  final List<int> rezkaOutputKadrCounts;
  final bool completeRequiresFullReport;
  final bool completeRequiresRezkaTotalWasteOnly;
  final AdminProductionOrderFreezeDetails? freezeRequest;

  bool allows(String action) => allowedActions.contains(action.trim());

  bool get contractValid {
    final value = interaction;
    final normalizedState = state.trim().toLowerCase();
    if (value == null ||
        !hasOnlyKnownActions ||
        !hasRequiredFields ||
        !_knownApparatusQueueStates.contains(normalizedState) ||
        !_queueInteractionModeMatchesState(value.mode, normalizedState)) {
      return false;
    }
    for (final action in allowedActions) {
      if (!_queueActionMatchesInteractionMode(action, value.mode)) {
        return false;
      }
    }
    if (value.startMaterialsMode == AdminQueueStartMaterialsMode.scanRequired &&
        !value.materialScanRequired) {
      return false;
    }
    if (value.startMaterialsMode == AdminQueueStartMaterialsMode.hidden &&
        value.materialScanRequired) {
      return false;
    }
    if (value.previousWipMode != AdminQueuePreviousWipMode.notRequired &&
        previousStage.trim().isEmpty) {
      return false;
    }
    if (value.openingWipMode != AdminQueuePreviousWipMode.notRequired &&
        value.previousWipMode != AdminQueuePreviousWipMode.notRequired) {
      return false;
    }
    final expectedActions = switch (value.mode) {
      AdminQueueInteractionMode.freshStart => const {'start'},
      AdminQueueInteractionMode.requeuedReady => const {'resume'},
      AdminQueueInteractionMode.inProgress => null,
      AdminQueueInteractionMode.freezeRequested =>
        normalizedState == 'in_progress' ? const {'pause'} : const <String>{},
      AdminQueueInteractionMode.paused => null,
      AdminQueueInteractionMode.freshStartBlocked ||
      AdminQueueInteractionMode.requeuedWaiting ||
      AdminQueueInteractionMode.frozen ||
      AdminQueueInteractionMode.completed ||
      AdminQueueInteractionMode.waitingPreviousStage =>
        const <String>{},
    };
    if (expectedActions != null &&
        (allowedActions.length != expectedActions.length ||
            !allowedActions.containsAll(expectedActions))) {
      return false;
    }
    if (value.mode == AdminQueueInteractionMode.inProgress &&
        !allowedActions.contains('pause')) {
      return false;
    }
    if (value.mode == AdminQueueInteractionMode.freezeRequested) {
      final request = freezeRequest;
      if (request == null ||
          request.requestId.trim().isEmpty ||
          request.status.trim().toLowerCase() != 'pending' ||
          request.targetSessionId.trim().isEmpty ||
          request.targetApparatus.trim().isEmpty) {
        return false;
      }
    }
    if ((value.mode == AdminQueueInteractionMode.freshStartBlocked ||
            value.mode == AdminQueueInteractionMode.requeuedWaiting ||
            value.mode == AdminQueueInteractionMode.waitingPreviousStage) &&
        value.blockingReasonCode.trim().isEmpty) {
      return false;
    }
    return true;
  }

  bool isConsistentWith(
    AdminOrderControlState orderControlState, {
    String? queueState,
  }) {
    if (!contractValid) return false;
    if (queueState != null &&
        queueState.trim().isNotEmpty &&
        queueState.trim().toLowerCase() != state.trim().toLowerCase()) {
      return false;
    }
    final mode = interaction!.mode;
    if (orderControlState == AdminOrderControlState.frozen) {
      return mode == AdminQueueInteractionMode.frozen && allowedActions.isEmpty;
    }
    if (mode == AdminQueueInteractionMode.frozen ||
        state.trim().toLowerCase() == 'frozen') {
      return false;
    }
    if (orderControlState == AdminOrderControlState.freezeRequested) {
      return mode == AdminQueueInteractionMode.freezeRequested &&
          freezeRequest != null;
    }
    return mode != AdminQueueInteractionMode.freezeRequested;
  }

  factory AdminApparatusQueueOrderActionControl.fromJson(
    Map<String, dynamic> json,
  ) {
    const knownActions = {
      'start',
      'pause',
      'detach_roll',
      'resume',
      'roll_complete',
      'complete',
      'freeze',
    };
    final actions = <String>{};
    var hasOnlyKnownActions = true;
    final rawActions = json['allowed_actions'];
    if (rawActions is List) {
      for (final rawAction in rawActions) {
        if (rawAction is! String || rawAction.trim().isEmpty) {
          hasOnlyKnownActions = false;
          continue;
        }
        final action = rawAction.trim();
        actions.add(action);
        if (!knownActions.contains(action)) {
          hasOnlyKnownActions = false;
        }
      }
    } else {
      hasOnlyKnownActions = false;
    }
    return AdminApparatusQueueOrderActionControl(
      state: json['state']?.toString().trim() ?? '',
      allowedActions: Set<String>.unmodifiable(actions),
      interaction: AdminQueueWorkerInteraction.tryFromJson(json['interaction']),
      hasOnlyKnownActions: hasOnlyKnownActions,
      hasRequiredFields: json['state'] is String &&
          rawActions is List &&
          json['interaction'] is Map &&
          json['previous_stage_ready'] is bool &&
          json['complete_requires_full_report'] is bool,
      previousStage: json['previous_stage']?.toString().trim() ?? '',
      stageNodeId: json['stage_node_id']?.toString().trim() ?? '',
      previousStageReady: json['previous_stage_ready'] == true,
      rezkaOutputKadrCounts: List<int>.unmodifiable(
        (json['rezka_output_kadr_counts'] as List? ?? const [])
            .whereType<num>()
            .map((value) => value.toInt())
            .where((value) => value > 0),
      ),
      completeRequiresFullReport: json['complete_requires_full_report'] == true,
      completeRequiresRezkaTotalWasteOnly:
          json['complete_requires_rezka_total_waste_only'] == true,
      freezeRequest: json['freeze_request'] is Map
          ? AdminProductionOrderFreezeDetails.fromJson(
              (json['freeze_request'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

bool _queueInteractionModeMatchesState(
  AdminQueueInteractionMode mode,
  String state,
) {
  return switch (state) {
    'pending' => const {
        AdminQueueInteractionMode.freshStart,
        AdminQueueInteractionMode.freshStartBlocked,
        AdminQueueInteractionMode.requeuedWaiting,
        AdminQueueInteractionMode.requeuedReady,
        AdminQueueInteractionMode.waitingPreviousStage,
      }.contains(mode),
    'in_progress' => mode == AdminQueueInteractionMode.inProgress ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'paused' => mode == AdminQueueInteractionMode.paused ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'frozen' => mode == AdminQueueInteractionMode.frozen,
    'completed' => mode == AdminQueueInteractionMode.completed,
    _ => false,
  };
}

bool _queueActionMatchesInteractionMode(
  String action,
  AdminQueueInteractionMode mode,
) {
  return switch (action.trim()) {
    'start' => mode == AdminQueueInteractionMode.freshStart,
    'resume' => mode == AdminQueueInteractionMode.requeuedReady ||
        mode == AdminQueueInteractionMode.paused,
    'pause' => mode == AdminQueueInteractionMode.inProgress ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'detach_roll' => mode == AdminQueueInteractionMode.inProgress ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'roll_complete' ||
    'complete' =>
      mode == AdminQueueInteractionMode.inProgress,
    'freeze' => mode == AdminQueueInteractionMode.inProgress,
    _ => false,
  };
}

Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
    _parseAdminQueueActionControls(Object? raw) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
      'queue_action_controls must be an object',
    );
  }
  final result = <String, Map<String, AdminApparatusQueueOrderActionControl>>{};
  for (final apparatusEntry in raw.entries) {
    if (apparatusEntry.key is! String ||
        !isCanonicalApparatusId(apparatusEntry.key.toString().trim())) {
      throw _productionMapQueueContractException(
        'queue_action_controls contains an invalid apparatus key',
      );
    }
    final apparatus = apparatusEntry.key.toString().trim();
    final rawOrders = apparatusEntry.value;
    if (rawOrders is! Map) {
      throw _productionMapQueueContractException(
        'queue_action_controls[$apparatus] must be an object',
      );
    }
    final orders = <String, AdminApparatusQueueOrderActionControl>{};
    for (final orderEntry in rawOrders.entries) {
      if (orderEntry.key is! String ||
          orderEntry.key.toString().trim().isEmpty ||
          orderEntry.value is! Map) {
        throw _productionMapQueueContractException(
          'queue_action_controls[$apparatus] contains an invalid order',
        );
      }
      final orderId = orderEntry.key.toString().trim();
      final rawControl = orderEntry.value;
      orders[orderId] = AdminApparatusQueueOrderActionControl.fromJson(
        (rawControl as Map).cast<String, dynamic>(),
      );
    }
    result[apparatus] =
        Map<String, AdminApparatusQueueOrderActionControl>.unmodifiable(orders);
  }
  return Map<String,
      Map<String, AdminApparatusQueueOrderActionControl>>.unmodifiable(result);
}

MobileApiException _productionMapQueueContractException(String detail) {
  return MobileApiException(
    code: 'production_map_snapshot_contract_invalid',
    message: 'Production map navbati server shartnomasiga mos emas: $detail',
  );
}

void _requireProductionMapSnapshotShape(
  Map<String, dynamic> json, {
  required bool includesMaps,
}) {
  if (includesMaps && json['maps'] is! List) {
    throw _productionMapQueueContractException('maps must be an array');
  }
  if (includesMaps) {
    for (final item in json['maps'] as List) {
      if (item is! Map) {
        throw _productionMapQueueContractException(
          'maps contains an invalid item',
        );
      }
    }
  }
  _requireProductionMapStringListMap(json['sequences'], 'sequences');
  _requireProductionMapStringListMap(
    json['visible_order_ids'],
    'visible_order_ids',
  );
  _requireProductionMapQueueStates(json['queue_states']);
  if (json['queue_action_controls'] is! Map) {
    throw _productionMapQueueContractException(
      'queue_action_controls must be an object',
    );
  }
  final rawPolicies = json['queue_policies'];
  if (rawPolicies is! List) {
    throw _productionMapQueueContractException(
      'queue_policies must be an array',
    );
  }
  for (final item in rawPolicies) {
    if (item is! Map ||
        item['apparatus_id'] is! String ||
        !isCanonicalApparatusId(
          (item['apparatus_id'] as String).trim(),
        ) ||
        item['policy'] is! String ||
        !const {
          'strict_sequence',
          'free_pick',
        }.contains((item['policy'] as String).trim())) {
      throw _productionMapQueueContractException(
        'queue_policies contains an invalid item',
      );
    }
  }
  final rawOrderControls = json['order_controls'];
  if (rawOrderControls is! Map) {
    throw _productionMapQueueContractException(
      'order_controls must be an object',
    );
  }
  for (final entry in rawOrderControls.entries) {
    final value = entry.value;
    final state = value is Map ? value['state'] : null;
    if (entry.key is! String ||
        entry.key.toString().trim().isEmpty ||
        state is! String ||
        !const {
          'active',
          'freeze_requested',
          'frozen',
        }.contains(state.trim())) {
      throw _productionMapQueueContractException(
        'order_controls contains an invalid item',
      );
    }
  }
}

void _requireProductionMapStringListMap(Object? raw, String field) {
  if (raw is! Map) {
    throw _productionMapQueueContractException('$field must be an object');
  }
  for (final entry in raw.entries) {
    if (entry.key is! String ||
        !isCanonicalApparatusId(entry.key.toString().trim()) ||
        entry.value is! List ||
        (entry.value as List).any(
          (value) => value is! String || value.trim().isEmpty,
        )) {
      throw _productionMapQueueContractException(
        '$field contains an invalid item',
      );
    }
  }
}

void _requireProductionMapQueueStates(Object? raw) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
      'queue_states must be an object',
    );
  }
  for (final apparatusEntry in raw.entries) {
    final states = apparatusEntry.value;
    if (apparatusEntry.key is! String ||
        !isCanonicalApparatusId(apparatusEntry.key.toString().trim()) ||
        states is! Map) {
      throw _productionMapQueueContractException(
        'queue_states contains an invalid apparatus',
      );
    }
    for (final stateEntry in states.entries) {
      final state = stateEntry.value;
      if (stateEntry.key is! String ||
          stateEntry.key.toString().trim().isEmpty ||
          state is! String ||
          !_knownApparatusQueueStates.contains(state.trim().toLowerCase())) {
        throw _productionMapQueueContractException(
          'queue_states contains an unknown order state',
        );
      }
    }
  }
}

class AdminApparatusQueueSnapshot {
  const AdminApparatusQueueSnapshot({
    required this.sequences,
    required this.visibleOrderIds,
    required this.queueStates,
    required this.queuePolicies,
    required this.orderControls,
    this.queueActionControls = const {},
    this.stageStates = const {},
    this.orderCustomers = const {},
    this.orderStatuses = const {},
    this.qolipOrderNotes = const {},
    this.frozenOrdersByApparatus = const {},
  });

  final Map<String, List<String>> sequences;
  final Map<String, List<String>> visibleOrderIds;
  final Map<String, Map<String, String>> queueStates;
  final Map<String, Map<String, String>> stageStates;
  final Map<String, AdminApparatusQueuePolicy> queuePolicies;
  final Map<String, AdminOrderControlState> orderControls;
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControls;
  final Map<String, String> orderCustomers;
  final Map<String, AdminProductionOrderStatusDetail> orderStatuses;
  final Map<String, AdminQolipOrderNote> qolipOrderNotes;
  final Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus;

  AdminOrderControlState orderControlFor(String orderId) {
    // The backend serializes only non-active order-control overrides. Missing
    // records therefore mean the authoritative active state.
    return orderControls[orderId.trim()] ?? AdminOrderControlState.active;
  }

  void validateContract() {
    _validateProductionMapQueueContract(
      sequences: sequences,
      visibleOrderIds: visibleOrderIds,
      queueStates: queueStates,
      stageStates: stageStates,
      queuePolicies: queuePolicies,
      queueActionControls: queueActionControls,
      frozenOrdersByApparatus: frozenOrdersByApparatus,
    );
  }
}

enum AdminOrderControlState {
  active,
  freezeRequested,
  frozen;

  static AdminOrderControlState fromRaw(Object? raw) {
    return switch (raw?.toString().trim()) {
      'freeze_requested' => AdminOrderControlState.freezeRequested,
      'frozen' => AdminOrderControlState.frozen,
      _ => AdminOrderControlState.active,
    };
  }

  String get apiValue => switch (this) {
        AdminOrderControlState.active => 'active',
        AdminOrderControlState.freezeRequested => 'freeze_requested',
        AdminOrderControlState.frozen => 'frozen',
      };
}

AdminOrderControlState adminProductionMapOrderControlFor(
  Map<String, AdminOrderControlState> orderControls,
  String orderId,
) {
  // The backend publishes only freeze overrides; an absent record is the
  // authoritative active state, not a client-derived eligibility decision.
  return orderControls[orderId.trim()] ?? AdminOrderControlState.active;
}

enum AdminOrderControlAction {
  freeze,
  cancelFreeze,
  unfreeze,
  delete;

  String get apiValue => switch (this) {
        AdminOrderControlAction.freeze => 'freeze',
        AdminOrderControlAction.cancelFreeze => 'cancel_freeze',
        AdminOrderControlAction.unfreeze => 'unfreeze',
        AdminOrderControlAction.delete => 'delete',
      };
}

Map<String, List<String>> _parseRequiredProductionMapVisibleOrderIds(
  Map<String, dynamic> json,
) {
  if (!json.containsKey('visible_order_ids') ||
      json['visible_order_ids'] == null) {
    throw const MobileApiException(
      code: 'production_map_visible_order_ids_missing',
      message: 'Production map navbati noto‘liq',
    );
  }
  _requireProductionMapStringListMap(
    json['visible_order_ids'],
    'visible_order_ids',
  );
  return MobileApi.instance.parseApparatusSequenceMap(
    json['visible_order_ids'],
  );
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
    this.apparatusId = '',
    this.sourceRevision = 0,
    this.sourceAasxSha256 = '',
    this.locked = false,
    this.reason = '',
  });

  final String apparatusId;
  final String apparatus;
  final int sourceRevision;
  final String sourceAasxSha256;
  final ApparatusQueuePolicy policy;
  final bool locked;
  final String reason;

  factory AdminApparatusQueuePolicy.fromJson(Map<String, dynamic> json) {
    return AdminApparatusQueuePolicy(
      apparatusId: _requireCanonicalApparatusId(
        json['apparatus_id']?.toString() ?? '',
      ),
      apparatus: json['apparatus']?.toString() ?? '',
      sourceRevision: (json['source_revision'] as num?)?.toInt() ?? 0,
      sourceAasxSha256: json['source_aasx_sha256']?.toString().trim() ?? '',
      policy: ApparatusQueuePolicy.fromRaw(
        json['discipline'] ?? json['policy'],
      ),
      locked: json['locked'] == true,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'apparatus_id': apparatusId,
        'apparatus': apparatus,
        'source_revision': sourceRevision,
        'source_aasx_sha256': sourceAasxSha256,
        'discipline': policy.apiValue,
        'locked': locked,
        'reason': reason,
      };
}
