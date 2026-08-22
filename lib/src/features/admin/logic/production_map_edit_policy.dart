import '../models/production_map_models.dart';
import 'apparatus_queue_state.dart';

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
    final apparatusId = productionMapEffectiveApparatusId(node);
    if (startedApparatus.contains(apparatusId)) {
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

String productionMapEffectiveApparatusId(ProductionMapNode node) {
  final assigned = node.alternativeAssignedApparatusId.trim();
  return assigned.isEmpty ? node.apparatusId.trim() : assigned;
}

bool productionMapIncomingEdgeIsLocked(
  ProductionMapEdge edge,
  Set<String> lockedNodeIds,
) {
  return lockedNodeIds.contains(edge.to.trim());
}
