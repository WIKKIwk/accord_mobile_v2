part of '../mobile_api.dart';

class AdminProductionMapLiveStateReady
    implements AdminProductionMapLiveMessage {
  const AdminProductionMapLiveStateReady({
    required this.epoch,
    required this.revision,
    required this.resync,
    this.scope = '',
    this.recovered = false,
    this.recoverySupported = false,
  });
  final String epoch;
  final int revision;
  final bool resync;
  final String scope;

  /// Explicit confirmation that the retained cursor is current. Older
  /// servers omit this field and retain the snapshot recovery path.
  final bool recovered;
  final bool recoverySupported;

  factory AdminProductionMapLiveStateReady.fromJson(Map<String, dynamic> json) {
    final revision = parseProductionMapSnapshotRevisionFromJson(json);
    final epoch = json['epoch'];
    if (revision == null || epoch is! String || epoch.isEmpty) {
      throw _productionMapQueueContractException('invalid state cursor');
    }
    return AdminProductionMapLiveStateReady(
      epoch: epoch,
      scope: json['scope'] is String ? json['scope'] as String : '',
      revision: revision,
      resync: json['type'] == 'state_resync' || json['resync'] == true,
      recovered: json['recovered'] == true,
      recoverySupported: json['recovery_supported'] == true,
    );
  }
}

Map<String, T> _applyProductionMapFieldPatch<T>(
  Map<String, T> before,
  Object? raw,
  T Function(Object?) decode,
) {
  if (raw == null) return before;
  if (raw is! Map || raw['upsert'] is! Map || raw['remove'] is! List) {
    throw _productionMapQueueContractException('invalid state field patch');
  }
  final result = Map<String, T>.from(before);
  for (final key in raw['remove'] as List) {
    if (key is! String || key.isEmpty)
      throw _productionMapQueueContractException('invalid removed key');
    result.remove(key);
  }
  for (final entry in (raw['upsert'] as Map).entries) {
    if (entry.key is! String || (entry.key as String).isEmpty) {
      throw _productionMapQueueContractException('invalid updated key');
    }
    result[entry.key as String] = decode(entry.value);
  }
  return result;
}

Map<String, Map<String, T>> _applyProductionMapNestedPatch<T>(
  Map<String, Map<String, T>> before,
  Object? raw,
  T Function(Object?) decode,
) {
  if (raw == null) return before;
  if (raw is! Map || raw['scopes'] is! Map || raw['remove'] is! List) {
    throw _productionMapQueueContractException('invalid nested state patch');
  }
  final result = Map<String, Map<String, T>>.from(before);
  for (final key in raw['remove'] as List) {
    if (key is! String || key.isEmpty)
      throw _productionMapQueueContractException('invalid removed scope');
    result.remove(key);
  }
  for (final entry in (raw['scopes'] as Map).entries) {
    if (entry.key is! String || (entry.key as String).isEmpty) {
      throw _productionMapQueueContractException('invalid updated scope');
    }
    final scope = entry.key as String;
    result[scope] = _applyProductionMapFieldPatch(
        before[scope] ?? const {}, entry.value, decode);
  }
  return result;
}

Map<String, dynamic> _productionMapPatchObject(Object? raw) {
  if (raw is! Map)
    throw _productionMapQueueContractException('state object required');
  return raw.cast<String, dynamic>();
}

String _productionMapPatchString(Object? raw) {
  if (raw is! String)
    throw _productionMapQueueContractException('state string required');
  return raw;
}

String _productionMapSequenceFingerprint(List<String> values) =>
    sequence_delta.sequenceFingerprint(values);

List<String> _applyProductionMapSequenceEdit(List<String> before, Object? raw) {
  try {
    return sequence_delta.applySequenceEdit(before, raw);
  } on FormatException catch (error) {
    throw _productionMapQueueContractException(error.message.toString());
  }
}

Map<String, List<String>> _applyProductionMapSequencePatch(
  Map<String, List<String>> before,
  Object? raw, {
  required bool compact,
}) {
  final result =
      _applyProductionMapFieldPatch(before, raw, _productionMapPatchStrings);
  if (raw is! Map || !raw.containsKey('edit')) return result;
  if (!compact || raw['edit'] is! Map) {
    throw _productionMapQueueContractException('unnegotiated sequence edit');
  }
  // Every edit reads the immutable old snapshot. A late failure can never
  // mutate a list already published to the UI or partially install a delta.
  for (final entry in (raw['edit'] as Map).entries) {
    final key = entry.key;
    if (key is! String ||
        key.isEmpty ||
        !before.containsKey(key) ||
        (raw['upsert'] as Map).containsKey(key) ||
        (raw['remove'] as List).contains(key)) {
      throw _productionMapQueueContractException('conflicting sequence edit');
    }
    result[key] = _applyProductionMapSequenceEdit(before[key]!, entry.value);
  }
  return result;
}

List<String> _productionMapPatchStrings(Object? raw) {
  if (raw is! List || raw.any((value) => value is! String || value.isEmpty)) {
    throw _productionMapQueueContractException('state string list required');
  }
  return raw.cast<String>();
}

class AdminProductionMapLiveStateDelta
    implements AdminProductionMapLiveMessage {
  const AdminProductionMapLiveStateDelta({
    required this.epoch,
    required this.baseRevision,
    required this.revision,
    required this.patch,
    this.scope = '',
    this.protocol = 'state_delta_v1',
  });
  final String epoch;
  final int baseRevision;
  final int revision;
  final Map<String, dynamic> patch;
  final String scope;
  final String protocol;

  factory AdminProductionMapLiveStateDelta.fromJson(Map<String, dynamic> json) {
    final revision = parseProductionMapSnapshotRevisionFromJson(json);
    final base = json['base_rev'];
    final epoch = json['epoch'];
    final protocol = json['protocol'] ?? 'state_delta_v1';
    if (revision == null ||
        base is! int ||
        base < 0 ||
        revision < base ||
        epoch is! String ||
        epoch.isEmpty ||
        json['patch'] is! Map ||
        !const {'state_delta_v1', 'state_delta_v2'}.contains(protocol)) {
      throw _productionMapQueueContractException('invalid state delta');
    }
    final patch = _productionMapPatchObject(json['patch']);
    const known = {
      'worker_list_rows', 'worker_display_states', 'worker_report_prompts',
      'worker_pending_report_ids',
      'maps',
      'map_order',
      'map_order_edit',
      'sequences',
      'sequence_versions',
      'sequence_revisions',
      'sequence_positions_by_apparatus',
      'visible_order_ids',
      'queue_states',
      'stage_states',
      'queue_policies',
      'queue_action_controls',
      'order_controls',
      'stage_order_controls',
      'order_statuses',
      'frozen_orders_by_apparatus',
      'order_customers',
      'completed_orders',
      'completion_requests',
      'completion_request_decisions'
    };
    if (patch.keys.any((key) => !known.contains(key))) {
      throw _productionMapQueueContractException('unknown state patch field');
    }
    if (patch.containsKey('map_order_edit') &&
        (protocol != 'state_delta_v2' || patch.containsKey('map_order'))) {
      throw _productionMapQueueContractException('unnegotiated map order edit');
    }
    return AdminProductionMapLiveStateDelta(
      epoch: epoch,
      baseRevision: base,
      revision: revision,
      patch: patch,
      scope: json['scope'] is String ? json['scope'] as String : '',
      protocol: protocol as String,
    );
  }

  AdminApparatusQueueSnapshot applyTo(AdminApparatusQueueSnapshot before) {
    if (!const {'state_delta_v1', 'state_delta_v2'}.contains(protocol) ||
        (patch.containsKey('map_order_edit') &&
            (protocol != 'state_delta_v2' || patch.containsKey('map_order')))) {
      throw _productionMapQueueContractException(
          'invalid state delta protocol');
    }
    // A delta cannot fill missing history or cross a server restart.
    if (before.epoch != epoch ||
        before.revision != baseRevision ||
        before.scope != scope) {
      throw _productionMapQueueContractException('state delta cursor mismatch');
    }
    if (before.isWorkerList) {
      if (protocol != 'state_delta_v2' ||
          patch.keys.any((key) => _workerListForbiddenFields.contains(key) ||
              key == 'map_order' || key == 'map_order_edit')) {
        throw _productionMapQueueContractException('worker list received canonical patch');
      }
      final controls = patch['order_controls'];
      if (controls is Map && controls.containsKey('upsert')) {
        _validateWorkerListControls(controls['upsert']);
      }
    } else if (patch.keys.any(_workerListFields.contains)) {
      throw _productionMapQueueContractException('canonical snapshot received worker rows');
    }
    var maps = before.maps;
    if (patch.containsKey('maps') ||
        patch.containsKey('map_order') ||
        patch.containsKey('map_order_edit')) {
      final indexed = _applyProductionMapFieldPatch<ProductionMapSaved>(
        {for (final saved in maps) saved.map.id: saved},
        patch['maps'],
        (raw) => parseProductionMapSnapshotMaps([raw]).single,
      );
      if (indexed.entries.any((entry) => entry.key != entry.value.map.id)) {
        throw _productionMapQueueContractException('map identity mismatch');
      }
      final order = patch.containsKey('map_order_edit')
          ? _applyProductionMapSequenceEdit(
              [for (final saved in before.maps) saved.map.id],
              patch['map_order_edit'])
          : patch['map_order'];
      if (order == null) {
        maps = indexed.values.toList();
      } else {
        final ids = _productionMapPatchStrings(order);
        if (ids.length != indexed.length ||
            ids.toSet().length != ids.length ||
            ids.any((id) => !indexed.containsKey(id))) {
          throw _productionMapQueueContractException('invalid map order');
        }
        maps = [for (final id in ids) indexed[id]!];
      }
    }
    final controls = _applyProductionMapFieldPatch<AdminOrderControlState>(
      before.orderControls,
      patch['order_controls'],
      (raw) => _parseAdminOrderControls({'order': raw})['order']!,
    );
    var earlyClosing = before.earlyClosingOrderIds;
    final controlPatch = patch['order_controls'];
    if (controlPatch is Map) {
      earlyClosing = Set<String>.from(earlyClosing)
        ..removeAll((controlPatch['remove'] as List).cast<String>())
        ..removeAll((controlPatch['upsert'] as Map).keys.cast<String>())
        ..addAll(_parseEarlyClosingOrderIds(controlPatch['upsert']));
    }
    final snapshot = AdminApparatusQueueSnapshot(
      projection: before.projection,
      workerPendingReportIds: _applyProductionMapSequencePatch(
          before.workerPendingReportIds, patch['worker_pending_report_ids'],
          compact: protocol == 'state_delta_v2'),
      workerListRows: _applyProductionMapFieldPatch(before.workerListRows,
          patch['worker_list_rows'], (raw) => WorkerOrderListRow.fromJson(_productionMapPatchObject(raw))),
      workerDisplayStates: _applyProductionMapNestedPatch(before.workerDisplayStates,
          patch['worker_display_states'], _workerDisplayState),
      workerReportPrompts: _applyProductionMapNestedPatch(before.workerReportPrompts,
          patch['worker_report_prompts'], (raw) => WorkerStageReportPrompt.fromJson(_productionMapPatchObject(raw))),
      maps: maps,
      calculationTemplates: before.calculationTemplates,
      revision: revision,
      epoch: epoch,
      scope: scope,
      workerShowAllApparatusTabs: before.workerShowAllApparatusTabs,
      sequences: _applyProductionMapSequencePatch(
          before.sequences, patch['sequences'],
          compact: protocol == 'state_delta_v2'),
      sequenceVersions: _applyProductionMapFieldPatch(before.sequenceVersions,
          patch['sequence_versions'], _productionMapPatchString),
      sequenceRevisions: _applyProductionMapFieldPatch(
          before.sequenceRevisions,
          patch['sequence_revisions'],
          (raw) => _parseSequenceRevisions({'revision': raw})['revision']!),
      sequencePositionsByApparatus: _applyProductionMapNestedPatch(
          before.sequencePositionsByApparatus,
          patch['sequence_positions_by_apparatus'], _productionMapSequencePosition),
      visibleOrderIds: _applyProductionMapSequencePatch(
          before.visibleOrderIds, patch['visible_order_ids'],
          compact: protocol == 'state_delta_v2'),
      queueStates: _applyProductionMapNestedPatch(
          before.queueStates, patch['queue_states'], _productionMapPatchString),
      stageStates: _applyProductionMapNestedPatch(
          before.stageStates, patch['stage_states'], _productionMapPatchString),
      queuePolicies: _applyProductionMapFieldPatch(
          before.queuePolicies,
          patch['queue_policies'],
          (raw) => AdminApparatusQueuePolicy.fromJson(
              _productionMapPatchObject(raw))),
      queueActionControls: _applyProductionMapNestedPatch(
          before.queueActionControls,
          patch['queue_action_controls'],
          (raw) => AdminApparatusQueueOrderActionControl.fromJson(
              _productionMapPatchObject(raw))),
      orderControls: controls,
      stageFreezeSupported: before.stageFreezeSupported,
      stageOrderControls: patch.containsKey('stage_order_controls')
          ? _parseStageOrderControls(patch['stage_order_controls'])
          : before.stageOrderControls,
      earlyClosingOrderIds: earlyClosing,
      orderCustomers: _applyProductionMapFieldPatch(before.orderCustomers,
          patch['order_customers'], _productionMapPatchString),
      orderStatuses: _applyProductionMapFieldPatch(
          before.orderStatuses,
          patch['order_statuses'],
          (raw) => AdminProductionOrderStatusDetail.fromJson(
              _productionMapPatchObject(raw))),
      frozenOrdersByApparatus: _applyProductionMapFieldPatch(
          before.frozenOrdersByApparatus, patch['frozen_orders_by_apparatus'],
          (raw) {
        if (raw is! List)
          throw _productionMapQueueContractException(
              'frozen order list required');
        return raw
            .map((item) =>
                AdminFrozenQueueOrder.fromJson(_productionMapPatchObject(item)))
            .toList();
      }),
    );
    snapshot.validateContract();
    if (before.isWorkerList) {
      final rawCompleted = patch['completed_orders'];
      final completed = rawCompleted == null
          ? (before is AdminProductionMapLiveSnapshot
              ? before.completedOrders : const <AdminCompletedQueueOrder>[])
          : rawCompleted is List
              ? [for (final raw in rawCompleted)
                  AdminCompletedQueueOrder.fromJson(_productionMapPatchObject(raw))]
              : throw _productionMapQueueContractException('invalid completed worker rows');
      if (completed.any((order) => !snapshot.workerListRows.containsKey(order.orderId))) {
        throw _productionMapQueueContractException('missing completed worker row');
      }
    }
    for (final apparatus in snapshot.queueActionControls.entries) {
      for (final order in apparatus.value.entries) {
        if (!order.value.isConsistentWith(snapshot.orderControlFor(order.key),
            queueState: snapshot.queueStates[apparatus.key]?[order.key])) {
          throw _productionMapQueueContractException(
              'state delta control mismatch');
        }
      }
    }
    return snapshot;
  }
}
