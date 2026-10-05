part of '../mobile_api.dart';

class AdminProductionMapLiveStateReady
    implements AdminProductionMapLiveMessage {
  const AdminProductionMapLiveStateReady({
    required this.epoch,
    required this.revision,
    required this.resync,
    this.scope = '',
  });
  final String epoch;
  final int revision;
  final bool resync;
  final String scope;

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
  });
  final String epoch;
  final int baseRevision;
  final int revision;
  final Map<String, dynamic> patch;
  final String scope;

  factory AdminProductionMapLiveStateDelta.fromJson(Map<String, dynamic> json) {
    final revision = parseProductionMapSnapshotRevisionFromJson(json);
    final base = json['base_rev'];
    final epoch = json['epoch'];
    if (revision == null ||
        base is! int ||
        base < 0 ||
        revision < base ||
        epoch is! String ||
        epoch.isEmpty ||
        json['patch'] is! Map) {
      throw _productionMapQueueContractException('invalid state delta');
    }
    final patch = _productionMapPatchObject(json['patch']);
    const known = {
      'maps',
      'map_order',
      'sequences',
      'sequence_versions',
      'sequence_revisions',
      'visible_order_ids',
      'queue_states',
      'stage_states',
      'queue_policies',
      'queue_action_controls',
      'order_controls',
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
    return AdminProductionMapLiveStateDelta(
      epoch: epoch,
      baseRevision: base,
      revision: revision,
      patch: patch,
      scope: json['scope'] is String ? json['scope'] as String : '',
    );
  }

  AdminApparatusQueueSnapshot applyTo(AdminApparatusQueueSnapshot before) {
    // A delta cannot fill missing history or cross a server restart.
    if (before.epoch != epoch ||
        before.revision != baseRevision ||
        before.scope != scope) {
      throw _productionMapQueueContractException('state delta cursor mismatch');
    }
    var maps = before.maps;
    if (patch.containsKey('maps') || patch.containsKey('map_order')) {
      final indexed = _applyProductionMapFieldPatch<ProductionMapSaved>(
        {for (final saved in maps) saved.map.id: saved},
        patch['maps'],
        (raw) => parseProductionMapSnapshotMaps([raw]).single,
      );
      if (indexed.entries.any((entry) => entry.key != entry.value.map.id)) {
        throw _productionMapQueueContractException('map identity mismatch');
      }
      final order = patch['map_order'];
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
      maps: maps,
      revision: revision,
      epoch: epoch,
      scope: scope,
      workerShowAllApparatusTabs: before.workerShowAllApparatusTabs,
      sequences: _applyProductionMapFieldPatch(
          before.sequences, patch['sequences'], _productionMapPatchStrings),
      sequenceVersions: _applyProductionMapFieldPatch(before.sequenceVersions,
          patch['sequence_versions'], _productionMapPatchString),
      sequenceRevisions: _applyProductionMapFieldPatch(
          before.sequenceRevisions,
          patch['sequence_revisions'],
          (raw) => _parseSequenceRevisions({'revision': raw})['revision']!),
      visibleOrderIds: _applyProductionMapFieldPatch(before.visibleOrderIds,
          patch['visible_order_ids'], _productionMapPatchStrings),
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
