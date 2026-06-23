part of 'admin_production_map_orders_screen.dart';

_MoveApparatusDefaults _moveApparatusDefaults({
  required List<AdminWarehouse> source,
  required AdminWarehouse? currentTop,
  required AdminWarehouse? currentBottom,
}) {
  final pechat = source
      .where((item) => productionMapPechatColorCount(item.warehouse) != null)
      .toList(growable: false);
  final candidates = pechat.isEmpty ? source : pechat;
  if (candidates.isEmpty) {
    return const _MoveApparatusDefaults(top: null, bottom: null);
  }

  final top = currentTop ?? candidates.first;
  var bottom = currentBottom;
  if (bottom == null) {
    if (candidates.length > 1) {
      bottom = candidates[1];
    } else {
      for (final item in source) {
        if (item.warehouse != candidates.first.warehouse) {
          bottom = item;
          break;
        }
      }
    }
  }
  return _MoveApparatusDefaults(top: top, bottom: bottom);
}

ProductionMapDefinition? _returnAssignedMapToAlternatives(
  ProductionMapDefinition map,
  AdminWarehouse source,
) {
  final sourceTitle = source.warehouse.trim();
  final assignedGroupId = _assignedAlternativeGroupIdForApparatus(
    map,
    sourceTitle,
  );
  if (assignedGroupId == null) {
    return null;
  }
  return map.copyWith(
    nodes: [
      for (final node in map.nodes)
        node.alternativeGroupId.trim() == assignedGroupId
            ? node.copyWith(alternativeAssignedTitle: '')
            : node,
    ],
  );
}

ProductionMapDefinition _assignAlternativeMapToApparatus(
  ProductionMapDefinition map,
  AdminWarehouse apparatus,
) {
  final targetTitle = apparatus.warehouse.trim();
  final targetNode = map.nodes
      .where((node) {
        return node.kind == 'apparatus' &&
            node.alternativeGroupId.trim().isNotEmpty &&
            productionMapWarehouseTitlesMatch(node.title, targetTitle);
      })
      .cast<ProductionMapNode?>()
      .firstWhere((node) => node != null, orElse: () => null);
  if (targetNode == null) {
    return map;
  }
  final groupId = targetNode.alternativeGroupId.trim();
  return map.copyWith(
    nodes: [
      for (final node in map.nodes)
        node.alternativeGroupId.trim() == groupId
            ? node.copyWith(alternativeAssignedTitle: targetTitle)
            : node,
    ],
  );
}

bool _canMoveOrderToApparatus(
  ProductionMapSaved order,
  AdminWarehouse target, {
  required AdminWarehouse source,
}) {
  if (_isMoveUnassignedApparatus(source)) {
    return !_isMoveUnassignedApparatus(target) &&
        _isAlternativeOrderForApparatus(order, target);
  }
  if (_isMoveUnassignedApparatus(target)) {
    return _returnAssignedMapToAlternatives(order.map, source) != null;
  }
  return productionMapCanMoveOrderToApparatus(
    nodes: order.map.nodes,
    fromApparatus: source.warehouse,
    toApparatus: target.warehouse,
    rollCount: order.map.rollCount,
    widthMm: order.map.widthMm,
    isFlexoOrder: productionMapIsFlexoOrder(order.map),
  );
}

_MoveDragPayload _moveDragPayload({
  required ProductionMapSaved order,
  required AdminWarehouse source,
  required List<ProductionMapSaved> zoneOrders,
  required Set<String> selectedOrderIds,
}) {
  final orderId = order.map.id.trim();
  final selectedFromZone = zoneOrders
      .where((item) => selectedOrderIds.contains(item.map.id.trim()))
      .toList(growable: false);
  final orders = selectedFromZone.isEmpty
      ? [order]
      : [
          ...selectedFromZone,
          if (!selectedFromZone.any((item) => item.map.id.trim() == orderId))
            order,
        ];
  return _MoveDragPayload(orders: orders, source: source);
}

List<AdminWarehouse> _movePickerApparatusOptionsForList({
  required List<AdminWarehouse> apparatus,
  required AdminWarehouse? oppositeApparatus,
}) {
  if (oppositeApparatus == null ||
      _isMoveUnassignedApparatus(oppositeApparatus)) {
    return apparatus;
  }
  final oppositeTitle = oppositeApparatus.warehouse.trim();
  return apparatus
      .where(
        (item) => !productionMapWarehouseTitlesMatch(
          item.warehouse,
          oppositeTitle,
        ),
      )
      .toList(growable: false);
}

List<ProductionMapSaved> _alternativeOrdersForApparatusList({
  required List<ProductionMapSaved> orders,
  required AdminWarehouse apparatus,
}) {
  return orders
      .where(
        (order) =>
            !_isFlexoOrderBlockedForColorPechat(order.map, apparatus) &&
            _hasUnassignedAlternativeGroupForApparatus(order.map, apparatus),
      )
      .toList(growable: false);
}

Map<String, ProductionMapSaved> _savedProductionMapOrdersByIdOrThrow({
  required List<ProductionMapSaved> saved,
  required Set<String> expectedOrderIds,
  required String incompleteMessage,
}) {
  final savedById = {for (final item in saved) item.map.id.trim(): item};
  if (savedById.length != expectedOrderIds.length ||
      !expectedOrderIds.every(savedById.containsKey)) {
    throw MobileApiException(
      code: 'move_incomplete',
      message: incompleteMessage,
    );
  }
  return savedById;
}

List<ProductionMapSaved> _mergeSavedProductionMapOrders(
  List<ProductionMapSaved> current,
  Map<String, ProductionMapSaved> savedById,
) {
  return [
    for (final item in current)
      if (savedById.containsKey(item.map.id.trim()))
        savedById[item.map.id.trim()]!
      else
        item,
  ];
}

Set<String> _productionMapOrderIdSet(List<ProductionMapSaved> orders) {
  return orders.map((order) => order.map.id.trim()).toSet();
}
