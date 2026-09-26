import '../../../core/api/mobile_api.dart';
import 'apparatus_queue_state.dart';

/// Display states shared by the map label and its apparatus sheet.
enum FactoryMapStatus {
  printPreflight('print_preflight', 0xFF7E86A8),
  printPreflightPassed('print_preflight_passed', 0xFF568326),
  inProgress('in_progress', 0xFF278263),
  paused('paused', 0xFFB37B22),
  frozen('frozen', 0xFFC62828),
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
}

FactoryMapStatus factoryMapOrderStatus({
  required AdminApparatusQueueSnapshot? snapshot,
  required String apparatusId,
  required String orderId,
}) {
  if (snapshot == null) return FactoryMapStatus.unknown;
  final id = orderId.trim();
  final apparatus = apparatusId.trim();
  final lifecycle = snapshot.orderStatuses[id]?.lifecycleStatus;
  if (const {'production_completed', 'closed', 'cancelled'}
      .contains(lifecycle)) {
    return FactoryMapStatus.completed;
  }
  if (snapshot.orderControls[id] == AdminOrderControlState.frozen) {
    return FactoryMapStatus.frozen;
  }
  final control = snapshot.queueActionControls[apparatus]?[id];
  final raw =
      (control?.state ?? snapshot.queueStates[apparatus]?[id] ?? 'pending')
          .trim()
          .toLowerCase();
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
  // Keep the first unfinished order even if materials are not ready yet.
  // 'Queued' describes its position, not permission to bypass start checks.
  return candidates.isEmpty
      ? const FactoryMapMachineStatus(FactoryMapStatus.idle)
      : candidates.first;
}
