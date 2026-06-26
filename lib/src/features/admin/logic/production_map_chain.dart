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
      final title = _stageTitle(node);
      if (title.isNotEmpty) {
        if (node.kind == 'apparatus') {
          seenApparatus = true;
        }
        stages.add(
          ProductionMapChainStage(nodeId: node.id, stationTitle: title),
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
  if (!_isWorkStage(node, true)) {
    return false;
  }
  return productionMapStationTitlesMatch(_stageTitle(node), station);
}

bool productionMapStationTitlesMatch(String left, String right) {
  return productionMapWarehouseTitlesMatch(left, right);
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

String _stageTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  if (node.kind == 'apparatus' && assigned.isNotEmpty) {
    return assigned;
  }
  return node.title.trim();
}
