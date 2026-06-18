import 'production_map_pechat_rules.dart';

enum ApparatusQueueOrderState { pending, inProgress, paused, completed }

ApparatusQueueOrderState apparatusQueueOrderStateFromRaw(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'in_progress':
      return ApparatusQueueOrderState.inProgress;
    case 'paused':
      return ApparatusQueueOrderState.paused;
    case 'completed':
      return ApparatusQueueOrderState.completed;
    default:
      return ApparatusQueueOrderState.pending;
  }
}

String? firstActionableQueueOrderId({
  required List<String> sequence,
  required Map<String, String> states,
  Iterable<String>? visibleOrderIds,
  bool Function(String orderId)? isOrderReady,
}) {
  final visible = visibleOrderIds
      ?.map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final active = firstActiveQueueOrderId(
    sequence: sequence,
    states: states,
    visibleOrderIds: visible,
  );
  if (active != null) {
    return active;
  }
  for (final id in sequence) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      continue;
    }
    if (visible != null && !visible.contains(normalized)) {
      continue;
    }
    if (isOrderReady != null && !isOrderReady(normalized)) {
      continue;
    }
    final state = apparatusQueueOrderStateFromRaw(states[normalized]);
    if (state == ApparatusQueueOrderState.completed ||
        state == ApparatusQueueOrderState.paused ||
        state == ApparatusQueueOrderState.inProgress) {
      continue;
    }
    return normalized;
  }
  return null;
}

String? firstInProgressQueueOrderId({
  required List<String> sequence,
  required Map<String, String> states,
  Iterable<String>? visibleOrderIds,
}) {
  return firstActiveQueueOrderId(
    sequence: sequence,
    states: states,
    visibleOrderIds: visibleOrderIds,
  );
}

String? firstActiveQueueOrderId({
  required List<String> sequence,
  required Map<String, String> states,
  Iterable<String>? visibleOrderIds,
}) {
  final visible = visibleOrderIds
      ?.map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  for (final id in sequence) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      continue;
    }
    if (visible != null && !visible.contains(normalized)) {
      continue;
    }
    final state = apparatusQueueOrderStateFromRaw(states[normalized]);
    if (state == ApparatusQueueOrderState.inProgress ||
        state == ApparatusQueueOrderState.paused) {
      return normalized;
    }
  }
  return null;
}

String resolveApparatusStorageKey(
  String apparatus,
  Iterable<String> knownKeys,
) {
  final normalized = apparatus.trim();
  if (normalized.isEmpty) {
    return normalized;
  }
  final keys =
      knownKeys.map((key) => key.trim()).where((key) => key.isNotEmpty);
  if (keys.contains(normalized)) {
    return normalized;
  }
  for (final key in keys) {
    if (productionMapApparatusNodeMatchesFrom(
          nodeTitle: normalized,
          fromApparatus: key,
        ) ||
        productionMapApparatusNodeMatchesFrom(
          nodeTitle: key,
          fromApparatus: normalized,
        )) {
      return key;
    }
  }
  return normalized;
}
