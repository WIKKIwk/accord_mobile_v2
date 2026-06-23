part of 'admin_production_map_orders_screen.dart';

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
