part of 'admin_production_map_orders_screen.dart';

_MoveApparatusDefaults _moveApparatusDefaults({
  required List<AdminApparatus> source,
  required AdminApparatus? currentTop,
  required AdminApparatus? currentBottom,
}) {
  final pechat = source.where((item) => item.isPechat).toList(growable: false);
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
        if (item.id != candidates.first.id) {
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
  AdminApparatus source,
) {
  final assignedGroupId = _assignedAlternativeGroupIdForApparatus(
    map,
    source,
  );
  if (assignedGroupId == null) {
    return null;
  }
  return map.copyWith(
    nodes: [
      for (final node in map.nodes)
        node.alternativeGroupId.trim() == assignedGroupId
            ? node.copyWith(
                alternativeAssignedTitle: '',
                alternativeAssignedApparatusId: '',
              )
            : node,
    ],
  );
}

List<ProductionMapDefinition>? _returnAssignedMapsToAlternatives({
  required List<ProductionMapSaved> orders,
  required AdminApparatus source,
}) {
  final converted = <ProductionMapDefinition>[];
  for (final order in orders) {
    final map = _returnAssignedMapToAlternatives(order.map, source);
    if (map == null) {
      return null;
    }
    converted.add(map);
  }
  return converted;
}

ProductionMapDefinition _assignAlternativeMapToApparatus(
  ProductionMapDefinition map,
  AdminApparatus apparatus,
) {
  final targetTitle = apparatus.name.trim();
  final targetNode = map.nodes
      .where((node) {
        return node.kind == 'apparatus' &&
            node.alternativeGroupId.trim().isNotEmpty &&
            node.apparatusId == apparatus.id;
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
            ? node.copyWith(
                alternativeAssignedTitle: targetTitle,
                alternativeAssignedApparatusId: apparatus.id,
              )
            : node,
    ],
  );
}

List<ProductionMapDefinition> _assignAlternativeMapsToApparatus({
  required List<ProductionMapSaved> orders,
  required AdminApparatus apparatus,
}) {
  return [
    for (final order in orders)
      _assignAlternativeMapToApparatus(order.map, apparatus),
  ];
}

bool _canMoveOrderToApparatus(
  ProductionMapSaved order,
  AdminApparatus target, {
  required AdminApparatus source,
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
    fromApparatus: source,
    toApparatus: target,
    rollCount: order.map.rollCount,
    widthMm: order.map.widthMm,
  );
}

_MoveDragPayload _moveDragPayload({
  required ProductionMapSaved order,
  required AdminApparatus source,
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

List<AdminApparatus> _movePickerApparatusOptionsForList({
  required List<AdminApparatus> apparatus,
  required AdminApparatus? oppositeApparatus,
}) {
  if (oppositeApparatus == null ||
      _isMoveUnassignedApparatus(oppositeApparatus)) {
    return apparatus;
  }
  return apparatus
      .where((item) => item.id != oppositeApparatus.id)
      .toList(growable: false);
}

List<ProductionMapSaved> _alternativeOrdersForApparatusList({
  required List<ProductionMapSaved> orders,
  required AdminApparatus apparatus,
}) {
  return orders
      .where(
        (order) =>
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

String _adminActionErrorText(Object error, String fallback) {
  return error is MobileApiException ? error.message : fallback;
}

String _moveOrdersSuccessText(AppLocalizations l10n, int count) {
  return l10n.adminText('production.move.success', values: {'count': count});
}

String _returnOrdersToUnassignedSuccessText(
  AppLocalizations l10n,
  int count,
) {
  return l10n.adminText(
    'production.move.return_success',
    values: {'count': count},
  );
}

String _assignAlternativeOrdersSuccessText(
  AppLocalizations l10n,
  int count,
) {
  return l10n.adminText(
    'production.move.assign_success',
    values: {'count': count},
  );
}

Future<List<ProductionMapSaved>> _saveProductionMapDefinitions(
  List<ProductionMapDefinition> maps,
) async {
  final saved = <ProductionMapSaved>[];
  for (final map in maps) {
    saved.add(await MobileApi.instance.adminSaveProductionMap(map));
  }
  return saved;
}
