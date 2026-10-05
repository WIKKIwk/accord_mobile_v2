part of '../mobile_api.dart';

/// Large snapshots are decoded AND converted to typed models in one isolate.
/// Small action-control responses avoid isolate startup/copying overhead.
Future<AdminApparatusQueueSnapshot> decodeProductionMapQueueSnapshotPayload(
  String source, {
  int backgroundThresholdCodeUnits = defaultBackgroundJsonThresholdCodeUnits,
}) async {
  if (!kIsWeb && source.length >= backgroundThresholdCodeUnits) {
    return compute(_decodeProductionMapQueueSnapshot, source,
        debugLabel: 'production-queue-snapshot');
  }
  return _decodeProductionMapQueueSnapshot(source);
}

AdminApparatusQueueSnapshot _decodeProductionMapQueueSnapshot(String source) {
  final payload = (jsonDecode(source) as Map).cast<String, dynamic>();
  if (payload['completed_orders'] is List && payload['completion_requests'] is List &&
      payload['completion_request_decisions'] is List) {
    return AdminProductionMapLiveSnapshot.fromJson(payload);
  }
  final visibleOrderIds = _parseRequiredProductionMapVisibleOrderIds(payload);
  _requireProductionMapSnapshotShape(payload, includesMaps: false);
  final orderControls = _parseAdminOrderControls(payload['order_controls']);
  final snapshot = AdminApparatusQueueSnapshot(
    sequenceVersions: _stringMapOfStrings(payload['sequence_versions']),
    sequenceRevisions: _parseSequenceRevisions(payload['sequence_revisions']),
    sequences:
        MobileApi.instance.parseApparatusSequenceMap(payload['sequences']),
    visibleOrderIds: visibleOrderIds,
    queueStates:
        MobileApi.instance.parseApparatusQueueStateMap(payload['queue_states']),
    stageStates: _parseProductionMapStageStates(payload['stage_states']),
    queuePolicies: MobileApi.instance
        .parseApparatusQueuePolicyMap(payload['queue_policies']),
    queueActionControls:
        _parseAdminQueueActionControls(payload['queue_action_controls']),
    orderControls: orderControls,
    orderCustomers: _stringMapOfStrings(payload['order_customers']),
    earlyClosingOrderIds: _parseEarlyClosingOrderIds(payload['order_controls']),
    orderStatuses: _parseAdminOrderStatuses(payload['order_statuses']),
    frozenOrdersByApparatus: _parseAdminFrozenOrdersByApparatus(
        payload['frozen_orders_by_apparatus']),
    maps: parseProductionMapSnapshotMaps(payload['maps']),
    revision: parseProductionMapSnapshotRevisionFromJson(payload),
    epoch: payload['epoch'] is String ? payload['epoch'] as String : '',
    scope: payload['scope'] is String ? payload['scope'] as String : '',
    workerShowAllApparatusTabs: payload['worker_show_all_apparatus_tabs'] == true,
  );
  snapshot.validateContract();
  return snapshot;
}

AdminProductionMapLiveSnapshot _decodeProductionMapLiveSnapshot(
        Map<String, dynamic> payload) =>
    AdminProductionMapLiveSnapshot.fromJson(payload);
