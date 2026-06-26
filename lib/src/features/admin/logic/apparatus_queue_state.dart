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

List<String> effectiveQueueSequence({
  required List<String> sequence,
  required Iterable<String> visibleOrderIds,
}) {
  final visible = <String>[];
  final visibleSeen = <String>{};
  for (final id in visibleOrderIds) {
    final normalized = id.trim();
    if (normalized.isNotEmpty && visibleSeen.add(normalized)) {
      visible.add(normalized);
    }
  }
  if (visible.isEmpty) {
    final normalizedSequence = <String>[];
    final seen = <String>{};
    for (final id in sequence) {
      final normalized = id.trim();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        normalizedSequence.add(normalized);
      }
    }
    return normalizedSequence;
  }
  final visibleSet = visible.toSet();
  final effective = <String>[];
  final seen = <String>{};
  for (final id in sequence) {
    final normalized = id.trim();
    if (visibleSet.contains(normalized) && seen.add(normalized)) {
      effective.add(normalized);
    }
  }
  for (final id in visible) {
    if (seen.add(id)) {
      effective.add(id);
    }
  }
  return effective;
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
  final effectiveSequence = visibleOrderIds == null
      ? sequence
      : effectiveQueueSequence(
          sequence: sequence,
          visibleOrderIds: visibleOrderIds,
        );
  final active = firstActiveQueueOrderId(
    sequence: effectiveSequence,
    states: states,
  );
  if (active != null) {
    return active;
  }
  for (final id in effectiveSequence) {
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
  final effectiveSequence = visibleOrderIds == null
      ? sequence
      : effectiveQueueSequence(
          sequence: sequence,
          visibleOrderIds: visibleOrderIds,
        );
  for (final id in effectiveSequence) {
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
