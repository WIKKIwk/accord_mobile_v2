import '../models/production_map_models.dart';
import 'apparatus_queue_state.dart';
import 'production_map_pechat_rules.dart';

Set<String> productionMapLockedNodeIds({
  required ProductionMapDefinition map,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  final orderId = map.id.trim();
  if (orderId.isEmpty) {
    return const {};
  }
  final startedApparatus = <String>[];
  for (final entry in queueStatesByApparatus.entries) {
    final state = apparatusQueueOrderStateFromRaw(entry.value[orderId]);
    if (state != ApparatusQueueOrderState.pending) {
      startedApparatus.add(entry.key);
    }
  }
  if (startedApparatus.isEmpty) {
    return const {};
  }

  final lockedNodeIds = <String>{};
  for (final node in map.nodes) {
    if (node.kind != 'apparatus') {
      continue;
    }
    final title = productionMapEffectiveApparatusTitle(node);
    if (startedApparatus.any(
      (apparatus) => productionMapWarehouseTitlesMatch(title, apparatus),
    )) {
      lockedNodeIds.add(node.id.trim());
    }
  }
  final lockedGroupIds = map.nodes
      .where((node) => lockedNodeIds.contains(node.id.trim()))
      .map((node) => node.alternativeGroupId.trim())
      .where((groupId) => groupId.isNotEmpty)
      .toSet();
  if (lockedGroupIds.isNotEmpty) {
    lockedNodeIds.addAll(
      map.nodes
          .where(
            (node) => lockedGroupIds.contains(node.alternativeGroupId.trim()),
          )
          .map((node) => node.id.trim()),
    );
  }
  lockedNodeIds.remove('');
  return Set<String>.unmodifiable(lockedNodeIds);
}

String productionMapEffectiveApparatusTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  return assigned.isEmpty ? node.title.trim() : assigned;
}

bool productionMapIncomingEdgeIsLocked(
  ProductionMapEdge edge,
  Set<String> lockedNodeIds,
) {
  return lockedNodeIds.contains(edge.to.trim());
}
