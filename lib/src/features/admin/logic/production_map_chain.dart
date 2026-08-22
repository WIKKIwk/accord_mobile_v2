import '../models/production_map_models.dart';
import 'apparatus_queue_state.dart';
import 'canonical_apparatus_groups.dart';

class ProductionMapChainStage {
  const ProductionMapChainStage({
    required this.nodeId,
    required this.stageId,
    required this.displayTitle,
    this.apparatusId,
  });

  final String nodeId;
  final String stageId;
  final String displayTitle;
  final String? apparatusId;

  bool get isApparatus => apparatusId != null;
}

List<ProductionMapChainStage> productionMapLinearWorkStages(
  ProductionMapDefinition map,
) {
  final byId = {for (final node in map.nodes) node.id: node};
  final stages = <ProductionMapChainStage>[];
  final seenStageIds = <String>{};
  var seenApparatus = false;
  for (final nodeId in _reachableNodeIds(map)) {
    final node = byId[nodeId];
    if (node == null) continue;
    if (_isWorkStage(node, seenApparatus)) {
      final nodeStages = _stagesForNode(map, node);
      if (node.kind == 'apparatus' && nodeStages.isNotEmpty) {
        seenApparatus = true;
      }
      for (final stage in nodeStages) {
        if (stage.stageId.isEmpty || !seenStageIds.add(stage.stageId)) {
          continue;
        }
        stages.add(stage);
      }
    }
  }
  return List<ProductionMapChainStage>.unmodifiable(stages);
}

List<String> productionMapAuthorizedOrderApparatus({
  required ProductionMapDefinition map,
  required Iterable<String> assignedApparatus,
}) {
  final assignedIds = {
    for (final value in assignedApparatus)
      if (isCanonicalApparatusId(value)) value.trim(),
  };
  final result = <String>[];
  final seen = <String>{};
  for (final stage in productionMapLinearWorkStages(map)) {
    final apparatusId = stage.apparatusId;
    if (apparatusId == null ||
        !assignedIds.contains(apparatusId) ||
        !seen.add(apparatusId)) {
      continue;
    }
    result.add(apparatusId);
  }
  return List<String>.unmodifiable(result);
}

String? productionMapPreviousWorkStageStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  final stages = _previousPhysicalStageIds(map, station);
  return stages.isEmpty ? null : stages.first;
}

String? productionMapNextWorkStageStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  final stages = _nextPhysicalStageIds(map, station);
  return stages.isEmpty ? null : stages.first;
}

bool productionMapIsFinalWorkStageStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  final stationId = station.trim();
  return productionMapLinearWorkStages(map).any(
        (stage) => stage.isApparatus && stage.stageId == stationId,
      ) &&
      productionMapNextWorkStageStation(map: map, station: stationId) == null;
}

bool productionMapMapHasWorkStageForStation({
  required ProductionMapDefinition map,
  required String station,
}) {
  final stationId = station.trim();
  return productionMapLinearWorkStages(map).any(
    (stage) => stage.stageId == stationId,
  );
}

bool productionMapOrderReadyForStation({
  required ProductionMapDefinition map,
  required String orderId,
  required String station,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  if (!productionMapMapHasWorkStageForStation(map: map, station: station)) {
    return false;
  }
  final previous = productionMapPreviousWorkStageStation(
    map: map,
    station: station,
  );
  if (previous == null) {
    return true;
  }
  final states = queueStatesByApparatus[previous] ?? const <String, String>{};
  return apparatusQueueOrderStateFromRaw(states[orderId.trim()]) ==
      ApparatusQueueOrderState.completed;
}

bool productionMapNodeMatchesStation({
  required ProductionMapNode node,
  required String station,
}) {
  final stationId = station.trim();
  if (stationId.isEmpty || !_isWorkStage(node, true)) {
    return false;
  }
  return _stageIdentity(node) == stationId;
}

String productionMapStageDisplayTitle({
  required ProductionMapDefinition map,
  required String station,
}) {
  final stationId = station.trim();
  for (final stage in productionMapLinearWorkStages(map)) {
    if (stage.stageId == stationId) {
      return stage.displayTitle;
    }
  }
  return stationId;
}

List<String>? productionMapVisibleOrderIdsForStation({
  required Map<String, List<String>> visibleOrderIdsByApparatus,
  required String station,
}) {
  final apparatusId = station.trim();
  if (!isCanonicalApparatusId(apparatusId)) {
    return null;
  }
  return visibleOrderIdsByApparatus[apparatusId];
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

List<String> _previousPhysicalStageIds(
  ProductionMapDefinition map,
  String station,
) {
  final physicalNodeIds = productionMapLinearWorkStages(map)
      .where((stage) => stage.isApparatus)
      .map((stage) => stage.nodeId)
      .toSet();
  final found = <String>[];
  final seenIds = <String>{};
  for (final node in map.nodes) {
    if (!_isStationNode(node) ||
        !productionMapNodeMatchesStation(node: node, station: station)) {
      continue;
    }
    _collectPhysicalStageIds(
      map: map,
      startId: node.id,
      physicalNodeIds: physicalNodeIds,
      reverse: true,
      found: found,
      seenIds: seenIds,
    );
  }
  return found;
}

List<String> _nextPhysicalStageIds(
  ProductionMapDefinition map,
  String station,
) {
  final physicalNodeIds = productionMapLinearWorkStages(map)
      .where((stage) => stage.isApparatus)
      .map((stage) => stage.nodeId)
      .toSet();
  final found = <String>[];
  final seenIds = <String>{};
  for (final node in map.nodes) {
    if (!_isStationNode(node) ||
        !productionMapNodeMatchesStation(node: node, station: station)) {
      continue;
    }
    _collectPhysicalStageIds(
      map: map,
      startId: node.id,
      physicalNodeIds: physicalNodeIds,
      reverse: false,
      found: found,
      seenIds: seenIds,
    );
  }
  return found;
}

void _collectPhysicalStageIds({
  required ProductionMapDefinition map,
  required String startId,
  required Set<String> physicalNodeIds,
  required bool reverse,
  required List<String> found,
  required Set<String> seenIds,
}) {
  final queue = <String>[
    ...(reverse
        ? _routePredecessors(map, startId)
        : _routeSuccessors(map, startId)),
  ];
  final visited = <String>{};
  for (var index = 0; index < queue.length; index += 1) {
    final nodeId = queue[index];
    if (!visited.add(nodeId)) continue;
    final node = _nodeById(map, nodeId);
    if (node == null || node.kind == (reverse ? 'start' : 'end')) {
      continue;
    }
    if (node.kind == 'apparatus' && physicalNodeIds.contains(node.id)) {
      final apparatusId = _canonicalApparatusIdentity(node);
      if (apparatusId != null && seenIds.add(apparatusId)) {
        found.add(apparatusId);
      }
      continue;
    }
    queue.addAll(
      reverse ? _routePredecessors(map, nodeId) : _routeSuccessors(map, nodeId),
    );
  }
}

List<String> _reachableNodeIds(ProductionMapDefinition map) {
  String? start;
  for (final node in map.nodes) {
    if (node.kind == 'start') {
      start = node.id;
      break;
    }
  }
  if (start == null) return const [];
  final queue = <String>[start];
  final visited = <String>{};
  final result = <String>[];
  for (var index = 0; index < queue.length; index += 1) {
    final nodeId = queue[index];
    if (!visited.add(nodeId) || _nodeById(map, nodeId) == null) continue;
    result.add(nodeId);
    queue.addAll(_routeSuccessors(map, nodeId));
  }
  return result;
}

List<String> _routeSuccessors(ProductionMapDefinition map, String nodeId) {
  final node = _nodeById(map, nodeId);
  if (node == null) return const [];
  return [
    for (final edge in map.edges)
      if (edge.from == nodeId && _routeEdgeAllowed(node, edge)) edge.to,
  ];
}

List<String> _routePredecessors(ProductionMapDefinition map, String nodeId) {
  final result = <String>[];
  for (final edge in map.edges) {
    if (edge.to != nodeId) continue;
    final source = _nodeById(map, edge.from);
    if (source != null && _routeEdgeAllowed(source, edge)) {
      result.add(edge.from);
    }
  }
  return result;
}

bool _routeEdgeAllowed(ProductionMapNode node, ProductionMapEdge edge) {
  if (node.kind != 'condition') return true;
  final branch = _normalizeBranch(edge.branch);
  return branch == 'true' || branch == 'false';
}

String _normalizeBranch(String branch) {
  return switch (branch.trim().toLowerCase()) {
    'ha' || 'yes' || 'true' || '1' => 'true',
    "yo'q" || 'yoq' || 'no' || 'false' || '0' => 'false',
    final value => value,
  };
}

ProductionMapNode? _nodeById(ProductionMapDefinition map, String nodeId) {
  for (final node in map.nodes) {
    if (node.id == nodeId) return node;
  }
  return null;
}

bool _isWorkStage(ProductionMapNode node, bool seenApparatus) {
  return node.kind == 'apparatus' || (node.kind == 'task' && seenApparatus);
}

bool _isStationNode(ProductionMapNode node) {
  return node.kind == 'apparatus' || node.kind == 'task';
}

bool _isUnassignedAlternativeApparatus(ProductionMapNode node) {
  return node.kind == 'apparatus' &&
      node.alternativeGroupId.trim().isNotEmpty &&
      node.alternativeAssignedApparatusId.trim().isEmpty;
}

List<ProductionMapChainStage> _stagesForNode(
  ProductionMapDefinition map,
  ProductionMapNode node,
) {
  if (!_isUnassignedAlternativeApparatus(node)) {
    final stageId = _stageIdentity(node);
    if (stageId.isEmpty) return const [];
    final apparatusId = node.kind == 'apparatus' ? stageId : null;
    return [
      ProductionMapChainStage(
        nodeId: node.id,
        stageId: stageId,
        displayTitle: _displayTitle(node),
        apparatusId: apparatusId,
      ),
    ];
  }
  final groupId = node.alternativeGroupId.trim();
  return [
    for (final candidate in map.nodes)
      if (candidate.kind == 'apparatus' &&
          candidate.alternativeGroupId.trim() == groupId &&
          candidate.alternativeAssignedApparatusId.trim().isEmpty &&
          isCanonicalApparatusId(candidate.apparatusId))
        ProductionMapChainStage(
          nodeId: candidate.id,
          stageId: candidate.apparatusId.trim(),
          displayTitle: _displayTitle(candidate),
          apparatusId: candidate.apparatusId.trim(),
        ),
  ];
}

String _stageIdentity(ProductionMapNode node) {
  if (node.kind != 'apparatus') {
    return 'task:${node.id.trim()}';
  }
  return _canonicalApparatusIdentity(node) ?? '';
}

String? _canonicalApparatusIdentity(ProductionMapNode node) {
  if (node.kind != 'apparatus') return null;
  final assignedId = node.alternativeAssignedApparatusId.trim();
  final apparatusId = assignedId.isEmpty ? node.apparatusId.trim() : assignedId;
  return isCanonicalApparatusId(apparatusId) ? apparatusId : null;
}

String _displayTitle(ProductionMapNode node) {
  final assignedTitle = node.alternativeAssignedTitle.trim();
  if (node.kind == 'apparatus' && assignedTitle.isNotEmpty) {
    return assignedTitle;
  }
  return node.title.trim();
}
