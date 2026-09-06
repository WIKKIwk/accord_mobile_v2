enum ApparatusQueueOrderState {
  pending,
  inProgress,
  paused,
  frozen,
  completed,
}

enum OrderQueueActivityState {
  pending,
  inProgress,
  waitingNextStage,
  paused,
  frozen,
  completed,
}

const _queuePendingFlag = 1 << 0;
const _queueInProgressFlag = 1 << 1;
const _queuePausedFlag = 1 << 2;
const _queueFrozenFlag = 1 << 3;
const _queueCompletedFlag = 1 << 4;

ApparatusQueueOrderState apparatusQueueOrderStateFromRaw(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'in_progress':
      return ApparatusQueueOrderState.inProgress;
    case 'paused':
      return ApparatusQueueOrderState.paused;
    case 'frozen':
      return ApparatusQueueOrderState.frozen;
    case 'completed':
      return ApparatusQueueOrderState.completed;
    default:
      return ApparatusQueueOrderState.pending;
  }
}

OrderQueueActivityState? queueActivityStateForOrder({
  required String orderId,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  Map<String, List<String>>? visibleOrderIdsByApparatus,
}) {
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) {
    return null;
  }

  return queueActivityStatesForOrders(
    orderIds: [normalizedOrderId],
    queueStatesByApparatus: queueStatesByApparatus,
    visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
  )[normalizedOrderId];
}

Map<String, OrderQueueActivityState> queueActivityStatesForOrders({
  required Iterable<String> orderIds,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  Map<String, List<String>>? visibleOrderIdsByApparatus,
}) {
  final normalizedOrderIds = <String>{
    for (final orderId in orderIds)
      if (orderId.trim().isNotEmpty) orderId.trim(),
  };
  if (normalizedOrderIds.isEmpty) {
    return const {};
  }

  final flagsByOrderId = <String, int>{
    for (final orderId in normalizedOrderIds) orderId: 0,
  };
  final knownOrderIdsByApparatus = <String, Set<String>>{};
  for (final apparatusEntry in queueStatesByApparatus.entries) {
    final knownOrderIds = <String>{};
    knownOrderIdsByApparatus[apparatusEntry.key] = knownOrderIds;
    final states = apparatusEntry.value;
    for (final entry in states.entries) {
      final normalizedOrderId = entry.key.trim();
      if (normalizedOrderId.isEmpty) {
        continue;
      }
      knownOrderIds.add(normalizedOrderId);
      if (!flagsByOrderId.containsKey(normalizedOrderId)) {
        continue;
      }
      final state = apparatusQueueOrderStateFromRaw(entry.value);
      flagsByOrderId[normalizedOrderId] =
          flagsByOrderId[normalizedOrderId]! | _queueStateFlag(state);
    }
  }
  if (visibleOrderIdsByApparatus != null) {
    for (final apparatusEntry in visibleOrderIdsByApparatus.entries) {
      final knownOrderIds =
          knownOrderIdsByApparatus[apparatusEntry.key] ?? const <String>{};
      for (final orderId in apparatusEntry.value) {
        final normalizedOrderId = orderId.trim();
        if (!flagsByOrderId.containsKey(normalizedOrderId) ||
            knownOrderIds.contains(normalizedOrderId)) {
          continue;
        }
        flagsByOrderId[normalizedOrderId] =
            flagsByOrderId[normalizedOrderId]! | _queuePendingFlag;
      }
    }
  }

  final result = <String, OrderQueueActivityState>{};
  for (final orderId in normalizedOrderIds) {
    final state = _orderQueueActivityStateFromFlags(flagsByOrderId[orderId]!);
    if (state != null) {
      result[orderId] = state;
    }
  }
  return Map.unmodifiable(result);
}

int _queueStateFlag(ApparatusQueueOrderState state) {
  return switch (state) {
    ApparatusQueueOrderState.pending => _queuePendingFlag,
    ApparatusQueueOrderState.inProgress => _queueInProgressFlag,
    ApparatusQueueOrderState.paused => _queuePausedFlag,
    ApparatusQueueOrderState.frozen => _queueFrozenFlag,
    ApparatusQueueOrderState.completed => _queueCompletedFlag,
  };
}

OrderQueueActivityState? _orderQueueActivityStateFromFlags(int flags) {
  if ((flags & _queueFrozenFlag) != 0) {
    return OrderQueueActivityState.frozen;
  }
  if ((flags & _queuePausedFlag) != 0) {
    return OrderQueueActivityState.paused;
  }
  if ((flags & _queueInProgressFlag) != 0) {
    return OrderQueueActivityState.inProgress;
  }
  if ((flags & _queueCompletedFlag) != 0 && (flags & _queuePendingFlag) != 0) {
    return OrderQueueActivityState.waitingNextStage;
  }
  if ((flags & _queueCompletedFlag) != 0) {
    return OrderQueueActivityState.completed;
  }
  if ((flags & _queuePendingFlag) != 0) {
    return OrderQueueActivityState.pending;
  }
  return null;
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
  // Backend order ids are loaded newest-first. Keep saved sequence entries in
  // their explicit order, then append any new entries oldest-first.
  for (final id in visible.reversed) {
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
        state == ApparatusQueueOrderState.frozen ||
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
    if (state == ApparatusQueueOrderState.inProgress) {
      return normalized;
    }
  }
  return null;
}
