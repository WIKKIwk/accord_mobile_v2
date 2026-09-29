import '../../../core/api/mobile_api.dart';
import '../models/production_map_models.dart';
import 'apparatus_queue_state.dart';
import 'production_map_wip_facts.dart';

/// Display states shared by the map label and its apparatus sheet.
enum FactoryMapStatus {
  printPreflight('print_preflight', 0xFF7E86A8),
  printPreflightPassed('print_preflight_passed', 0xFF568326),
  inProgress('in_progress', 0xFF278263),
  paused('paused', 0xFFB37B22),
  frozen('frozen', 0xFFC62828),
  wipReady('wip_ready', 0xFF278263),
  wipWaiting('wip_waiting', 0xFFB37B22),
  wipProduced('wip_produced', 0xFF81618B),
  wipAvailable('wip_available', 0xFF81618B),
  wipReceived('wip_received', 0xFF81618B),
  waitingWip('waiting_wip', 0xFF597BA3),
  requeuedReady('requeued_ready', 0xFF278263),
  requeuedWaiting('requeued_waiting', 0xFFB37B22),
  pending('pending', 0xFF597BA3),
  completed('completed', 0xFF77827D),
  idle('idle', 0xFF77827D),
  unknown('unknown', 0xFF8B8984);

  const FactoryMapStatus(this.value, this.colorValue);

  final String value;
  final int colorValue;

  String get labelKey => this == completed
      ? 'factory_map.filter.completed'
      : 'factory_map.live.$value';
  String get cssColor =>
      '#${(colorValue & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  bool get isCurrentWork => switch (this) {
        printPreflight || printPreflightPassed || inProgress || paused => true,
        _ => false,
      };
  bool get isReady => this == wipReady || this == requeuedReady;
}

FactoryMapStatus factoryMapOrderStatus({
  required AdminApparatusQueueSnapshot? snapshot,
  required String apparatusId,
  required String orderId,
}) {
  if (snapshot == null) return FactoryMapStatus.unknown;
  final id = orderId.trim();
  final apparatus = apparatusId.trim();
  return productionQueueDisplayStatus(
    queueState: snapshot.queueStates[apparatus]?[id],
    control: snapshot.queueActionControls[apparatus]?[id],
    orderControl: snapshot.orderControls[id] ?? AdminOrderControlState.active,
    lifecycle: snapshot.orderStatuses[id]?.lifecycleStatus,
  );
}

/// Queue position, input availability and a resumable session are separate
/// facts. Use the server interaction contract to describe pending work.
FactoryMapStatus productionQueueDisplayStatus({
  required String? queueState,
  AdminApparatusQueueOrderActionControl? control,
  AdminOrderControlState orderControl = AdminOrderControlState.active,
  String? lifecycle,
}) {
  if (const {'production_completed', 'closed', 'cancelled'}
      .contains(lifecycle)) {
    return FactoryMapStatus.completed;
  }
  if (orderControl == AdminOrderControlState.frozen) {
    return FactoryMapStatus.frozen;
  }
  final raw = (queueState ?? control?.state ?? 'pending').trim().toLowerCase();
  if (control != null &&
      !control.isConsistentWith(orderControl, queueState: queueState)) {
    return FactoryMapStatus.unknown;
  }
  final interaction = control?.interaction;
  if (interaction?.mode == AdminQueueInteractionMode.requeuedReady) {
    return FactoryMapStatus.requeuedReady;
  }
  if (interaction?.mode == AdminQueueInteractionMode.requeuedWaiting) {
    return FactoryMapStatus.requeuedWaiting;
  }
  if (raw == 'pending' && interaction != null) {
    final hasWip = interaction.previousWipMode ==
            AdminQueuePreviousWipMode.scanRequired ||
        interaction.openingWipMode == AdminQueuePreviousWipMode.scanRequired;
    if (hasWip) {
      return control!.allows('start')
          ? FactoryMapStatus.wipReady
          : FactoryMapStatus.wipWaiting;
    }
    if (interaction.previousWipMode == AdminQueuePreviousWipMode.waiting ||
        interaction.openingWipMode == AdminQueuePreviousWipMode.waiting) {
      return FactoryMapStatus.waitingWip;
    }
  }
  return switch (raw) {
    'print_preflight' => control?.printPreflight?.isPassed == true
        ? FactoryMapStatus.printPreflightPassed
        : FactoryMapStatus.printPreflight,
    'in_progress' => FactoryMapStatus.inProgress,
    'paused' => FactoryMapStatus.paused,
    'frozen' => FactoryMapStatus.frozen,
    'pending' => FactoryMapStatus.pending,
    'completed' => FactoryMapStatus.completed,
    _ => FactoryMapStatus.unknown,
  };
}

/// Resolve a physical stage without borrowing state from another occurrence
/// of a repeated machine. A pending stage may have an active machine queue.
ApparatusQueueOrderState? productionMapStageQueueState({
  required ProductionMapDefinition map,
  required ProductionMapNode node,
  required String orderId,
  required Map<String, Map<String, String>> queueStates,
  required Map<String, String> stageStates,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      controls,
}) {
  if (node.kind != 'apparatus') return null;
  ApparatusQueueOrderState? parse(String? raw) =>
      switch (raw?.trim().toLowerCase()) {
        'pending' => ApparatusQueueOrderState.pending,
        'in_progress' => ApparatusQueueOrderState.inProgress,
        'print_preflight' => ApparatusQueueOrderState.printPreflight,
        'paused' => ApparatusQueueOrderState.paused,
        'frozen' => ApparatusQueueOrderState.frozen,
        'completed' => ApparatusQueueOrderState.completed,
        _ => null,
      };
  final stage = parse(stageStates[node.id.trim()]);
  final apparatus = node.alternativeGroupId.trim().isEmpty &&
          node.alternativeAssignedApparatusId.trim().isNotEmpty
      ? node.alternativeAssignedApparatusId.trim()
      : node.apparatusId.trim();
  final control = controls[apparatus]?[orderId.trim()];
  final occurrence = control?.stageNodeId.trim() ?? '';
  final matchingOccurrence = occurrence == node.id.trim() ||
      (node.alternativeGroupId.trim().isNotEmpty &&
          map.nodes.any((candidate) =>
              candidate.id.trim() == occurrence &&
              candidate.alternativeGroupId.trim() ==
                  node.alternativeGroupId.trim()));
  final unambiguous = map.nodes
          .where((candidate) =>
              candidate.kind == 'apparatus' &&
              candidate.apparatusId.trim() == apparatus)
          .length ==
      1;
  final queue = (occurrence.isNotEmpty ? matchingOccurrence : unambiguous)
      ? parse(queueStates[apparatus]?[orderId.trim()] ?? control?.state)
      : null;
  if (stage == ApparatusQueueOrderState.pending &&
      const {
        ApparatusQueueOrderState.inProgress,
        ApparatusQueueOrderState.printPreflight,
        ApparatusQueueOrderState.paused,
      }.contains(queue)) {
    return queue;
  }
  return stage ?? queue;
}

/// The display chain keeps one node per alternative group. Select the peer
/// with actual current work instead of keeping the first pending candidate.
ProductionMapNode productionMapLiveStageNode({
  required ProductionMapDefinition map,
  required ProductionMapNode node,
  required String orderId,
  required Map<String, Map<String, String>> queueStates,
  required Map<String, String> stageStates,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      controls,
}) {
  final group = node.alternativeGroupId.trim();
  if (node.kind != 'apparatus' || group.isEmpty) return node;
  int rank(ProductionMapNode candidate) => switch (productionMapStageQueueState(
        map: map,
        node: candidate,
        orderId: orderId,
        queueStates: queueStates,
        stageStates: stageStates,
        controls: controls,
      )) {
        ApparatusQueueOrderState.inProgress => 6,
        ApparatusQueueOrderState.printPreflight => 5,
        ApparatusQueueOrderState.paused => 4,
        ApparatusQueueOrderState.completed => 3,
        ApparatusQueueOrderState.frozen => 2,
        ApparatusQueueOrderState.pending => 1,
        null => 0,
      };
  var selected = node;
  for (final candidate in map.nodes.where((candidate) =>
      candidate.kind == 'apparatus' &&
      candidate.alternativeGroupId.trim() == group)) {
    if (rank(candidate) > rank(selected)) selected = candidate;
  }
  return selected;
}

FactoryMapStatus productionMapStageDisplayStatus({
  required ProductionMapDefinition map,
  required ProductionMapNode node,
  required ApparatusQueueOrderState? queueState,
  AdminApparatusQueueOrderActionControl? control,
  AdminOrderControlState orderControl = AdminOrderControlState.active,
  ProductionMapStageWipFacts wip = const ProductionMapStageWipFacts(),
}) {
  // Freezing the order does not undo work already completed on an earlier step.
  if (queueState == ApparatusQueueOrderState.completed) {
    return FactoryMapStatus.completed;
  }
  if (orderControl == AdminOrderControlState.frozen) {
    return FactoryMapStatus.frozen;
  }
  final controlNodeId = control?.stageNodeId.trim() ?? '';
  if (controlNodeId.isNotEmpty && controlNodeId != node.id.trim()) {
    final group = node.alternativeGroupId.trim();
    final sameStage = group.isNotEmpty &&
        map.nodes.any((candidate) =>
            candidate.id.trim() == controlNodeId &&
            candidate.kind == 'apparatus' &&
            candidate.alternativeGroupId.trim() == group);
    if (!sameStage) control = null;
  } else if (controlNodeId.isEmpty &&
      map.nodes
              .where((candidate) =>
                  candidate.kind == 'apparatus' &&
                  candidate.apparatusId.trim() == node.apparatusId.trim())
              .length >
          1) {
    // Without an occurrence id, a machine-level control cannot label every
    // use of that machine as ready or requeued.
    control = null;
  }
  final status = queueState == null && control == null
      ? FactoryMapStatus.unknown
      : productionQueueDisplayStatus(
          queueState: switch (queueState) {
            ApparatusQueueOrderState.printPreflight => 'print_preflight',
            ApparatusQueueOrderState.inProgress => 'in_progress',
            _ => queueState?.name,
          },
          control: control,
          orderControl: orderControl,
        );
  if (const {
    FactoryMapStatus.pending,
    FactoryMapStatus.unknown,
    FactoryMapStatus.waitingWip
  }.contains(status)) {
    if (wip.produced > 0) return FactoryMapStatus.wipProduced;
    if (wip.inUseInput + wip.processedInput > 0) {
      return FactoryMapStatus.wipReceived;
    }
    if (wip.waitingInput > 0) return FactoryMapStatus.wipAvailable;
  }
  return status;
}

class FactoryMapMachineStatus {
  const FactoryMapMachineStatus(this.status, {this.orderId = ''});

  final FactoryMapStatus status;
  final String orderId;
}

FactoryMapMachineStatus factoryMapMachineStatus({
  required AdminApparatusQueueSnapshot? snapshot,
  required String apparatusId,
}) {
  if (snapshot == null) {
    return const FactoryMapMachineStatus(FactoryMapStatus.unknown);
  }
  final apparatus = apparatusId.trim();
  final visible = snapshot.visibleOrderIds[apparatus] ?? const <String>[];
  final visibleSet = visible.map((id) => id.trim()).toSet();
  // Persisted states can retain frozen, completed and transferred orders.
  // Membership and ordering must come from the current visible queue.
  final ids = effectiveQueueSequence(
    sequence: snapshot.sequences[apparatus] ?? const <String>[],
    visibleOrderIds: visible,
  ).where(visibleSet.contains);
  final candidates = <FactoryMapMachineStatus>[];
  for (final id in ids) {
    final status = factoryMapOrderStatus(
      snapshot: snapshot,
      apparatusId: apparatus,
      orderId: id,
    );
    if (status == FactoryMapStatus.frozen ||
        status == FactoryMapStatus.completed) {
      continue;
    }
    // A freeze request still has a current worker until it is acknowledged,
    // but must never be advertised as the next order to start.
    if (snapshot.orderControls[id] == AdminOrderControlState.freezeRequested &&
        !status.isCurrentWork) {
      continue;
    }
    candidates.add(FactoryMapMachineStatus(status, orderId: id));
  }
  for (final status in const [
    FactoryMapStatus.inProgress,
    FactoryMapStatus.printPreflight,
    FactoryMapStatus.printPreflightPassed,
    FactoryMapStatus.paused,
  ]) {
    for (final candidate in candidates) {
      if (candidate.status == status) return candidate;
    }
  }
  // Free-pick queues can have a ready order after an order waiting for WIP.
  // Only the server can advertise Start/Resume, including sequence checks.
  for (final candidate in candidates) {
    if (candidate.status.isReady) return candidate;
  }
  return candidates.isEmpty
      ? const FactoryMapMachineStatus(FactoryMapStatus.idle)
      : candidates.first;
}
