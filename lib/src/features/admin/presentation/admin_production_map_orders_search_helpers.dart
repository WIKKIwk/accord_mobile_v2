part of 'admin_production_map_orders_screen.dart';

List<ProductionMapSaved> _visibleOrders({
  required List<ProductionMapSaved> orders,
  required String query,
}) {
  return _filterOrdersBySearch(orders, query: query);
}

List<AdminClosedProductionOrder> _visibleClosedOrders({
  required List<AdminClosedProductionOrder> orders,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return orders;
  }
  return orders.where((order) {
    final haystack = [
      order.orderId,
      _closedOrderDisplayCode(order),
      order.orderNumber,
      order.title,
      order.productCode,
      order.closedByRole,
      order.closedByRef,
      order.closedByDisplayName,
      for (final log in order.logs) ...[
        log.apparatus,
        log.action,
        log.fromState,
        log.toState,
        log.actorRole,
        log.actorRef,
        log.actorDisplayName,
      ],
    ].join(' ').toLowerCase();
    return haystack.contains(normalizedQuery);
  }).toList(growable: false);
}

List<ProductionMapSaved> _filterOrdersBySearch(
  List<ProductionMapSaved> orders, {
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return orders;
  }
  return orders
      .where(
        (order) => _orderMatchesSearch(order, query: normalizedQuery),
      )
      .toList(growable: false);
}

bool _orderMatchesSearch(
  ProductionMapSaved order, {
  required String query,
}) {
  if (query.isEmpty) {
    return true;
  }
  final map = order.map;
  final haystack = [
    _openedOrderDisplayCode(map),
    map.code,
    map.orderNumber,
    map.title,
    map.productCode,
    for (final node in map.nodes) node.title,
  ].join(' ').toLowerCase();
  return haystack.contains(query);
}
