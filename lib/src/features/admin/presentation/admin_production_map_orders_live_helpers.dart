part of 'admin_production_map_orders_screen.dart';

List<ProductionMapSaved> _productionMapZakazOrders(
  List<ProductionMapSaved> maps,
) {
  return maps
      .where((item) => item.map.id.trim().startsWith('zakaz-'))
      .toList(growable: false);
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

bool _apparatusListsSameByWarehouse(
  List<AdminWarehouse> current,
  List<AdminWarehouse> next,
) {
  return current.length == next.length &&
      current.every(
        (item) =>
            next.any((candidate) => candidate.warehouse == item.warehouse),
      );
}

Future<List<AdminCompletedQueueOrder>> _loadCompletedProductionMapOrders() {
  return MobileApi.instance.adminCompletedProductionMapOrders();
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

Future<List<AdminWarehouse>> _loadProductionMapApparatus() {
  return MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200);
}

Future<_ProductionMapOrdersAndApparatus>
    _loadProductionMapOrdersAndApparatus() async {
  final results = await Future.wait([
    MobileApi.instance.adminProductionMaps(),
    _loadProductionMapApparatus(),
  ]);
  final maps = results[0] as List<ProductionMapSaved>;
  final apparatus = results[1] as List<AdminWarehouse>;
  return _ProductionMapOrdersAndApparatus(
    orders: _productionMapZakazOrders(maps),
    apparatus: apparatus,
  );
}

bool _productionMapOrdersOrApparatusChanged({
  required List<ProductionMapSaved> currentOrders,
  required List<ProductionMapSaved> nextOrders,
  required List<AdminWarehouse> currentApparatus,
  required List<AdminWarehouse> nextApparatus,
}) {
  return _ordersRevision(nextOrders) != _ordersRevision(currentOrders) ||
      !_apparatusListsSameByWarehouse(currentApparatus, nextApparatus);
}

bool _shouldRefreshWorkerOnlyData(bool workerMode) {
  return workerMode;
}

bool _shouldRefreshAdminOnlyData(bool workerMode) {
  return !workerMode;
}
