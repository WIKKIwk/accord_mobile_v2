part of 'admin_production_map_orders_screen.dart';

String _openedOrderDisplayCode(ProductionMapDefinition map) {
  final code = map.code.trim();
  if (code.isNotEmpty) {
    return code;
  }
  final orderNumber = map.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = map.id.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return '';
}

String _openedOrderPrimaryTitle(ProductionMapDefinition map) {
  final title = map.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  final product = _openedOrderProductTitle(map);
  if (product.isNotEmpty) {
    return product;
  }
  return 'Zakaz';
}

String _openedOrderProductTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return '';
}

String _openedOrderSubtitle(
  ProductionMapDefinition map, {
  bool includeApparatusCount = false,
}) {
  final productTitle = _openedOrderProductTitle(map);
  final apparatusCount =
      map.nodes.where((node) => node.kind == 'apparatus').length;
  return [
    if (productTitle.isNotEmpty) productTitle,
    if (map.productCode.trim().isNotEmpty) map.productCode.trim(),
    if (includeApparatusCount && apparatusCount > 0)
      '$apparatusCount ta aparat',
  ].join(' • ');
}

String _closedOrderDisplayCode(AdminClosedProductionOrder order) {
  final orderNumber = order.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = order.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _completionRequestDisplayCode(
  AdminCompletionRequestNotification request,
) {
  final orderNumber = request.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = request.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _closedOrderTitle(AdminClosedProductionOrder order) {
  final title = order.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  return 'Zakaz';
}

String _closedActorLabel({
  required String displayName,
  required String role,
  required String ref,
}) {
  final display = displayName.trim();
  if (display.isNotEmpty) {
    return display;
  }
  final actorRef = ref.trim();
  if (actorRef.isNotEmpty) {
    return actorRef;
  }
  final actorRole = role.trim();
  if (actorRole.isNotEmpty) {
    return actorRole;
  }
  return 'Noma’lum ijrochi';
}

String _closedLogActionLabel(String action) {
  return switch (action.trim()) {
    'start' => 'Boshladi',
    'pause' => 'Pauza qildi',
    'resume' => 'Davom ettirdi',
    'complete' => 'Tugatdi',
    final value when value.isNotEmpty => value,
    _ => 'Harakat',
  };
}

String _closedLogTitle(AdminProductionOrderLogEntry log) {
  if (log.completedWithIssue) {
    final note = log.issueNote.trim();
    return note.isNotEmpty ? note : 'Muammo bilan yopildi';
  }
  return _closedLogActionLabel(log.action);
}

String _closedLogStateLabel(AdminProductionOrderLogEntry log) {
  final from = log.fromState.trim();
  final to = log.toState.trim();
  if (from.isNotEmpty && to.isNotEmpty) {
    return '$from → $to';
  }
  if (to.isNotEmpty) {
    return to;
  }
  return from;
}

String _closedLogTimeLabel(int unixSeconds) {
  return formatUnixSecondsLocalDateTime(unixSeconds);
}

List<ProductionMapNode> _linearProductionMapNodes(ProductionMapDefinition map) {
  final byId = {for (final node in map.nodes) node.id: node};
  final byFrom = <String, List<ProductionMapEdge>>{};
  for (final edge in map.edges) {
    byFrom.putIfAbsent(edge.from, () => <ProductionMapEdge>[]).add(edge);
  }
  final start = map.nodes
      .where((node) => node.kind == 'start')
      .map((node) => node.id)
      .cast<String?>()
      .firstWhere((id) => id != null, orElse: () => null);
  if (start == null || !byId.containsKey(start)) {
    return map.nodes;
  }
  final result = <ProductionMapNode>[];
  final seen = <String>{};
  var current = start;
  while (seen.add(current)) {
    final node = byId[current];
    if (node != null) {
      result.add(node);
    }
    final next = byFrom[current]
        ?.map((edge) => edge.to)
        .where((id) => byId.containsKey(id))
        .cast<String?>()
        .firstWhere((id) => id != null, orElse: () => null);
    if (next == null) {
      break;
    }
    current = next;
  }
  return result.isEmpty ? map.nodes : result;
}

String _productionMapNodeDisplayTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  if (assigned.isNotEmpty) {
    return assigned;
  }
  return node.title.trim();
}

String _productionMapResultSummary(
  ProductionMapDefinition map, {
  double? baseMetraj,
  double? orderKg,
}) {
  final product = _openedOrderProductTitle(map);
  final title = product.isNotEmpty ? product : map.title.trim();
  if (title.isEmpty) {
    return '';
  }
  final details = <String>[];
  if (orderKg != null && orderKg > 0) {
    details.add('${_productionMapQtyLabel(orderKg)} kg');
  }
  if (baseMetraj != null && baseMetraj > 0) {
    details.add('${_productionMapMetrajLabel(baseMetraj)} m metraj');
  }
  final rollCount = map.rollCount;
  if (rollCount != null && rollCount > 0) {
    details.add('${_productionMapQtyLabel(rollCount)} rulon');
  }
  final widthMm = map.widthMm;
  if (widthMm != null && widthMm > 0) {
    details.add('${_productionMapQtyLabel(widthMm)} mm en');
  }
  if (map.productCode.trim().isNotEmpty) {
    details.add(map.productCode.trim());
  }
  if (details.isEmpty) {
    return '$title tayyor bo‘ladi';
  }
  return '$title tayyor bo‘ladi (${details.join(', ')})';
}

String _productionMapQtyLabel(double value) => formatRawQuantity(value);

String _productionMapMetrajLabel(double value) {
  return value.toStringAsFixed(1);
}

bool _queueSnapshotChanged({
  required AdminApparatusQueueSnapshot snapshot,
  required Map<String, List<String>> sequenceByApparatus,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, AdminApparatusQueuePolicy> queuePoliciesByApparatus,
}) {
  if (sequenceByApparatus.length != snapshot.sequences.length ||
      queueStatesByApparatus.length != snapshot.queueStates.length ||
      queuePoliciesByApparatus.length != snapshot.queuePolicies.length) {
    return true;
  }
  for (final entry in snapshot.sequences.entries) {
    final current = sequenceByApparatus[entry.key];
    if (current == null ||
        current.length != entry.value.length ||
        !_stringListsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.queueStates.entries) {
    final current = queueStatesByApparatus[entry.key];
    if (current == null || !_stringMapsEqual(current, entry.value)) {
      return true;
    }
  }
  for (final entry in snapshot.queuePolicies.entries) {
    final current = queuePoliciesByApparatus[entry.key];
    if (current == null ||
        current.policy != entry.value.policy ||
        current.locked != entry.value.locked) {
      return true;
    }
  }
  return false;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _stringMapsEqual(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

int _ordersRevision(List<ProductionMapSaved> orders) {
  return Object.hashAll(
    orders.map(
      (item) => Object.hash(
        item.map.id,
        item.map.code,
        item.map.orderNumber,
        item.map.title,
        item.map.productCode,
        item.map.rollCount,
        item.map.widthMm,
        item.map.nodes.length,
        Object.hashAll(
          item.map.nodes.map(
            (node) => Object.hash(
              node.id,
              node.kind,
              node.title,
              node.alternativeGroupId,
              node.alternativeAssignedTitle,
            ),
          ),
        ),
        item.map.edges.length,
        Object.hashAll(
          item.map.edges.map(
            (edge) => Object.hash(edge.from, edge.to, edge.branch),
          ),
        ),
      ),
    ),
  );
}

bool _apparatusTitlesMatch(String left, String right) {
  return productionMapWarehouseTitlesMatch(left, right);
}

Map<String, String> _queueStatesForApparatus(
  AdminWarehouse apparatus, {
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  final title = apparatus.warehouse.trim();
  final direct = queueStatesByApparatus[title];
  if (direct != null) {
    return direct;
  }
  final color = productionMapPechatColorCount(title);
  if (color != null) {
    for (final entry in queueStatesByApparatus.entries) {
      if (productionMapPechatColorCount(entry.key) == color) {
        return entry.value;
      }
    }
  }
  return const {};
}

List<String> _sequenceOrderIdsForApparatus(
  AdminWarehouse apparatus, {
  required Map<String, List<String>> sequenceByApparatus,
}) {
  final title = apparatus.warehouse.trim();
  final direct = sequenceByApparatus[title];
  if (direct != null) {
    return direct;
  }
  final color = productionMapPechatColorCount(title);
  if (color != null) {
    for (final entry in sequenceByApparatus.entries) {
      if (productionMapPechatColorCount(entry.key) == color) {
        return entry.value;
      }
    }
  }
  return const [];
}

ApparatusQueuePolicy _queuePolicyForApparatus(
  AdminWarehouse apparatus, {
  required Map<String, AdminApparatusQueuePolicy> queuePoliciesByApparatus,
}) {
  final title = apparatus.warehouse.trim();
  if (productionMapPechatColorCount(title) != null) {
    return ApparatusQueuePolicy.strictSequence;
  }
  final direct = queuePoliciesByApparatus[title];
  if (direct != null) {
    return direct.policy;
  }
  for (final entry in queuePoliciesByApparatus.entries) {
    if (productionMapWarehouseTitlesMatch(entry.key, title)) {
      return entry.value.policy;
    }
  }
  return ApparatusQueuePolicy.strictSequence;
}

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

List<_WorkerCompletedOrderEntry> _workerCompletedOrders({
  required List<ProductionMapSaved> orders,
  required List<AdminCompletedQueueOrder> completedOrders,
  required List<AdminWarehouse> apparatus,
  required String query,
}) {
  final byId = {for (final order in orders) order.map.id.trim(): order};
  final seen = <String>{};
  final entries = <_WorkerCompletedOrderEntry>[];
  for (final completed in completedOrders) {
    final orderId = completed.orderId.trim();
    if (orderId.isEmpty || !seen.add(orderId)) {
      continue;
    }
    final order = byId[orderId];
    if (order != null) {
      entries.add(
        _WorkerCompletedOrderEntry(
          order: order,
          apparatus: _completedOrderApparatus(
            completed: completed,
            apparatus: apparatus,
          ),
        ),
      );
    }
  }
  final filtered = _filterOrdersBySearch(
    entries.map((entry) => entry.order).toList(growable: false),
    query: query,
  );
  final visibleIds = filtered.map((order) => order.map.id.trim()).toSet();
  return entries
      .where((entry) => visibleIds.contains(entry.order.map.id.trim()))
      .toList(growable: false);
}

AdminWarehouse? _completedOrderApparatus({
  required AdminCompletedQueueOrder completed,
  required List<AdminWarehouse> apparatus,
}) {
  final title = completed.apparatus.trim();
  if (title.isEmpty) {
    return null;
  }
  for (final item in apparatus) {
    if (_apparatusTitlesMatch(item.warehouse, title)) {
      return item;
    }
  }
  return AdminWarehouse(warehouse: title, parentWarehouse: 'aparat - A');
}
