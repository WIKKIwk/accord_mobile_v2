import '../models/production_map_models.dart';
import 'apparatus_queue_state.dart';
import 'production_map_pechat_rules.dart';

class ProductionMapChainStage {
  const ProductionMapChainStage({
    required this.nodeId,
    required this.stationTitle,
  });

  final String nodeId;
  final String stationTitle;
}

List<ProductionMapChainStage> productionMapLinearWorkStages(
  ProductionMapDefinition map,
) {
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
    return const [];
  }
  final stages = <ProductionMapChainStage>[];
  final seen = <String>{};
  final seenStageTitles = <String>{};
  var seenApparatus = false;
  var current = start;
  while (seen.add(current)) {
    final node = byId[current];
    if (node == null) {
      break;
    }
    if (node.kind == 'end') {
      break;
    }
    if (_isWorkStage(node, seenApparatus)) {
      for (final stage in _stageTitlesForNode(map, node)) {
        if (node.kind == 'apparatus') {
          seenApparatus = true;
        }
        if (stage.stationTitle.isEmpty ||
            !seenStageTitles.add(stage.stationTitle.toLowerCase())) {
          continue;
        }
        stages.add(
          stage,
        );
      }
    } else if (node.kind == 'apparatus') {
      seenApparatus = true;
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
  return stages;
}

String? productionMapPreviousWorkStageStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  final stages = productionMapLinearWorkStages(map);
  final index = stages.indexWhere(
    (stage) => productionMapStationTitlesMatch(stage.stationTitle, station),
  );
  if (index <= 0) {
    return null;
  }
  return stages[index - 1].stationTitle;
}

bool productionMapMapHasWorkStageForStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  return productionMapLinearWorkStages(map).any(
    (stage) => productionMapStationTitlesMatch(stage.stationTitle, station),
  );
}

bool productionMapOrderReadyForStation({
  required ProductionMapDefinition map,
  required String orderId,
  required String station,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  final previous = productionMapPreviousWorkStageStation(
    map: map,
    station: station,
  );
  if (previous == null) {
    return true;
  }
  final states = _queueStatesForStation(previous, queueStatesByApparatus);
  return apparatusQueueOrderStateFromRaw(states[orderId.trim()]) ==
      ApparatusQueueOrderState.completed;
}

bool productionMapNodeMatchesStation({
  required ProductionMapNode node,
  required String station,
}) {
  if (_isUnassignedAlternativeApparatus(node)) {
    return productionMapStationTitlesMatch(node.title, station);
  }
  if (!_isWorkStage(node, true)) {
    return false;
  }
  return productionMapStationTitlesMatch(_stageTitle(node), station);
}

bool productionMapStationTitlesMatch(String left, String right) {
  return productionMapWarehouseTitlesMatch(left, right);
}

List<String>? productionMapVisibleOrderIdsForStation({
  required Map<String, List<String>> visibleOrderIdsByApparatus,
  required String station,
}) {
  final title = station.trim();
  if (title.isEmpty) {
    return null;
  }
  final direct = visibleOrderIdsByApparatus[title];
  if (direct != null) {
    return direct;
  }
  final color = productionMapPechatColorCount(title);
  if (color != null) {
    for (final entry in visibleOrderIdsByApparatus.entries) {
      if (productionMapPechatColorCount(entry.key) == color) {
        return entry.value;
      }
    }
  }
  for (final entry in visibleOrderIdsByApparatus.entries) {
    if (productionMapStationTitlesMatch(entry.key, title)) {
      return entry.value;
    }
  }
  return null;
}

List<ProductionMapSaved> productionMapOrdersVisibleByBackendIds({
  required List<ProductionMapSaved> orders,
  required Map<String, List<String>> visibleOrderIdsByApparatus,
  required String station,
}) {
  final backendOrderIds = productionMapVisibleOrderIdsForStation(
    visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
    station: station,
  );
  if (backendOrderIds == null || backendOrderIds.isEmpty) {
    return const [];
  }
  final byId = {for (final order in orders) order.map.id.trim(): order};
  return [
    for (final orderId in backendOrderIds)
      if (byId.containsKey(orderId.trim())) byId[orderId.trim()]!,
  ];
}

Map<String, String> _queueStatesForStation(
  String station,
  Map<String, Map<String, String>> queueStatesByApparatus,
) {
  final direct = queueStatesByApparatus[station.trim()];
  if (direct != null) {
    return direct;
  }
  final color = productionMapPechatColorCount(station);
  if (color != null) {
    for (final entry in queueStatesByApparatus.entries) {
      if (productionMapPechatColorCount(entry.key) == color) {
        return entry.value;
      }
    }
  }
  for (final entry in queueStatesByApparatus.entries) {
    if (productionMapStationTitlesMatch(entry.key, station)) {
      return entry.value;
    }
  }
  return const {};
}

bool _isWorkStage(ProductionMapNode node, bool seenApparatus) {
  if (node.kind == 'apparatus') {
    return true;
  }
  if (node.kind == 'task') {
    return seenApparatus;
  }
  return false;
}

bool _isUnassignedAlternativeApparatus(ProductionMapNode node) {
  return node.kind == 'apparatus' &&
      node.alternativeGroupId.trim().isNotEmpty &&
      node.alternativeAssignedTitle.trim().isEmpty;
}

List<ProductionMapChainStage> _stageTitlesForNode(
  ProductionMapDefinition map,
  ProductionMapNode node,
) {
  if (!_isUnassignedAlternativeApparatus(node)) {
    final title = _stageTitle(node);
    return title.isEmpty
        ? const []
        : [ProductionMapChainStage(nodeId: node.id, stationTitle: title)];
  }
  final groupId = node.alternativeGroupId.trim();
  return [
    for (final candidate in map.nodes)
      if (candidate.kind == 'apparatus' &&
          candidate.alternativeGroupId.trim() == groupId &&
          candidate.alternativeAssignedTitle.trim().isEmpty &&
          candidate.title.trim().isNotEmpty)
        ProductionMapChainStage(
          nodeId: candidate.id,
          stationTitle: candidate.title.trim(),
        ),
  ];
}

String _stageTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  if (node.kind == 'apparatus' && assigned.isNotEmpty) {
    return assigned;
  }
  return node.title.trim();
}
