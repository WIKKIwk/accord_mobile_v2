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

Future<List<AdminCompletionRequestDecisionNotification>>
    _loadProductionMapCompletionRequestDecisions() {
  return MobileApi.instance.adminProductionMapCompletionRequestDecisions();
}

Future<List<AdminClosedProductionOrder>> _loadClosedProductionMapOrders() {
  return MobileApi.instance.adminClosedProductionMapOrders();
}

Future<List<AdminCompletionRequestNotification>>
    _loadProductionMapCompletionRequests() {
  return MobileApi.instance.adminProductionMapCompletionRequests();
}

Future<List<AdminApparatus>> _loadProductionMapApparatus() {
  return MobileApi.instance.adminApparatus(limit: 200);
}

Future<_ProductionMapOrdersAndApparatus>
    _loadProductionMapOrdersAndApparatus() async {
  final results = await Future.wait([
    MobileApi.instance.adminProductionMaps(),
    _loadProductionMapApparatus(),
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

bool _shouldRefreshWorkerOnlyData(bool workerMode) {
  return workerMode;
}

bool _shouldRefreshAdminOnlyData(bool workerMode) {
  return !workerMode;
}
