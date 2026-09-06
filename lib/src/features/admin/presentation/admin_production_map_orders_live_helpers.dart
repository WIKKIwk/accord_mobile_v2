part of 'admin_production_map_orders_screen.dart';

List<ProductionMapSaved> _productionMapZakazOrders(
  List<ProductionMapSaved> maps,
) {
  return maps.where((item) {
    final id = item.map.id.trim();
    return id.startsWith('zakaz-') || id.startsWith('training-zakaz-');
  }).toList(growable: false);
}

List<ProductionMapSaved> _activeProductionMapOrders({
  required List<ProductionMapSaved> orders,
  required Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  return orders.where((order) {
    final orderId = order.map.id.trim();
    final lifecycleStatus =
        orderStatusesByOrderId[orderId]?.lifecycleStatus.trim().toLowerCase() ??
            '';
    if (lifecycleStatus.isNotEmpty) {
      return lifecycleStatus != 'production_completed' &&
          lifecycleStatus != 'closed' &&
          lifecycleStatus != 'cancelled';
    }

    // Legacy and test snapshots do not carry the persisted lifecycle header.
    // Only use per-apparatus states as a compatibility fallback.
    final apparatusIds = productionMapLinearWorkStages(order.map)
        .map((stage) => stage.apparatusId?.trim() ?? '')
        .where((apparatusId) => apparatusId.isNotEmpty)
        .toSet();
    if (apparatusIds.isEmpty) {
      return true;
    }
    final allApparatusCompleted = apparatusIds.every((apparatusId) {
      final rawState = queueStatesByApparatus[apparatusId]?[orderId];
      return rawState != null &&
          apparatusQueueOrderStateFromRaw(rawState) ==
              ApparatusQueueOrderState.completed;
    });
    return !allApparatusCompleted;
  }).toList(growable: false);
}

List<AdminCompletionRequestDecisionNotification>
    _newRejectedCompletionRequestDecisions({
  required List<AdminCompletionRequestDecisionNotification> decisions,
  required Set<String> shownDecisionIds,
}) {
  return decisions
      .where(
        (decision) =>
            decision.decision.trim() == 'rejected' &&
            decision.eventId.trim().isNotEmpty &&
            !shownDecisionIds.contains(decision.eventId.trim()),
      )
      .toList(growable: false);
}

String _completionRejectedNoticeText(
  AdminCompletionRequestDecisionNotification decision,
) {
  final message = decision.message.trim();
  return message.isNotEmpty ? message : "Sizni so'rovingiz rad etildi";
}

bool _apparatusListsHaveSameCanonicalRevisions(
  List<AdminApparatus> current,
  List<AdminApparatus> next,
) {
  return current.length == next.length &&
      current.every(
        (item) => next.any(
          (candidate) =>
              candidate.id == item.id &&
              candidate.sourceRevision == item.sourceRevision &&
              candidate.sourceAasxSha256 == item.sourceAasxSha256,
        ),
      );
}

Future<List<AdminCompletedQueueOrder>>
    _loadCompletedProductionMapOrders() async {
  final productionOrders =
      await MobileApi.instance.adminCompletedProductionMapOrders();
  List<AdminCompletedQueueOrder> trainingOrders = const [];
  try {
    trainingOrders =
        await MobileApi.instance.adminTrainingCompletedProductionMapOrders();
  } catch (_) {
    // Training is an optional overlay; production completed orders remain
    // available when the training workspace is unavailable.
  }
  final seenOrderIds = <String>{};
  return [
    for (final order in [...productionOrders, ...trainingOrders])
      if (order.orderId.trim().isNotEmpty &&
          seenOrderIds.add(order.orderId.trim()))
        order,
  ];
}

Future<_ProductionMapOrdersAndApparatus>
    _loadProductionMapOrdersAndApparatus() async {
  final results = await Future.wait([
    MobileApi.instance.adminProductionMaps(),
    MobileApi.instance.adminApparatus(limit: 200),
  ]);
  final maps = results[0] as List<ProductionMapSaved>;
  final apparatus = results[1] as List<AdminApparatus>;
  return _ProductionMapOrdersAndApparatus(
    orders: _productionMapZakazOrders(maps),
    apparatus: apparatus,
  );
}

bool _productionMapOrdersOrApparatusChanged({
  required List<ProductionMapSaved> currentOrders,
  required List<ProductionMapSaved> nextOrders,
  required List<AdminApparatus> currentApparatus,
  required List<AdminApparatus> nextApparatus,
}) {
  return _ordersRevision(nextOrders) != _ordersRevision(currentOrders) ||
      !_apparatusListsHaveSameCanonicalRevisions(
        currentApparatus,
        nextApparatus,
      );
}

/// Canonical snapshot apply decision for the revision guard.
///
/// - null incoming revision (legacy backend) => [applyLegacy] so the caller
///   falls back to content comparison instead of crashing.
/// - incoming < last => stale, ignore.
/// - incoming == last => duplicate, do not rewrite `_orders`.
/// - incoming > last (or no last yet) => apply once.
enum CanonicalSnapshotDecision {
  apply,
  ignoreStale,
  ignoreDuplicate,
  applyLegacy
}

CanonicalSnapshotDecision canonicalSnapshotDecision({
  required int? incomingRevision,
  required int? lastAppliedRevision,
}) {
  if (incomingRevision == null) return CanonicalSnapshotDecision.applyLegacy;
  if (lastAppliedRevision == null) return CanonicalSnapshotDecision.apply;
  if (incomingRevision < lastAppliedRevision) {
    return CanonicalSnapshotDecision.ignoreStale;
  }
  if (incomingRevision == lastAppliedRevision) {
    return CanonicalSnapshotDecision.ignoreDuplicate;
  }
  return CanonicalSnapshotDecision.apply;
}

/// Customer/subtitle authority: snapshot first, map fallback immediately.
///
/// Never returns empty when the map itself carries a customer name, so the
/// first frame already shows the final subtitle (no flicker).
String resolveCanonicalOrderCustomer({
  required ProductionMapDefinition map,
  required Map<String, String> customersByMapId,
}) {
  final snapshotCustomer = customersByMapId[map.id.trim()]?.trim() ?? '';
  if (snapshotCustomer.isNotEmpty) return snapshotCustomer;
  return map.customerName.trim();
}

/// Bounded exponential backoff for live-stream reconnects:
/// 1s -> 2s -> 4s -> 8s -> ... capped at 30s. Deterministic (no jitter) so
/// tests stay stable.
Duration productionMapLiveReconnectDelay(int attempt) {
  final normalized = attempt < 0 ? 0 : attempt;
  var seconds = 1 << (normalized > 5 ? 5 : normalized);
  if (seconds > 30) seconds = 30;
  // 1,2,4,8,16,32->30,30,...
  if (normalized >= 5) seconds = 30;
  return Duration(seconds: seconds);
}
