part of '../mobile_api.dart';

final List<ProductionMapSaved> _testModeProductionMaps = [];
final List<AdminApparatus> _testModeApparatus = [];
final List<AdminApparatusCollection> _testModeApparatusCollections = [];
int _testModeApparatusCollectionCounter = 0;
final List<AdminWarehouse> _testModeWarehouses = [];
final List<AdminWarehouseAssignment> _testModeWarehouseAssignments = [];
final Map<String, List<String>> _testModeMaterialItemGroups = {};
final Set<String> _testModeDeletedWarehouseNames = {};
final List<AdminServerMonitorBackupSnapshot> _testModeBackupSnapshots = [];
final Map<String, List<String>> _testModeApparatusSequences = {};
final Map<String, Map<String, String>> _testModeApparatusQueueStates = {};
final Map<String, _TestModeApparatusTransferReceipt>
    _testModeApparatusTransfers = {};
final Map<String, AdminOrderControlState> _testModeOrderControls = {};
final Map<String, String> _testModeFrozenIssueNotesByOrderId = {};
final Set<String> _testModeRequeuedOrderIds = {};
final Map<String, AdminApparatusQueuePolicy> _testModeApparatusQueuePolicies =
    {};
final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
    _testModeQueueActionControlFixtures = {};
final Map<String, AdminApparatusCapacityProfile>
    _testModeApparatusCapacityProfiles = {};
final Map<String, AdminApparatusDowntime> _testModeApparatusDowntimes = {};
final Map<String, AdminApparatusScheduleReservation>
    _testModeApparatusScheduleReservations = {};
final List<_TestModeCompletedQueueOrder> _testModeCompletedQueueOrders = [];
final List<AdminCompletionRequestNotification> _testModeCompletionRequests = [];
final List<AdminCompletionRequestDecisionNotification>
    _testModeCompletionRequestDecisions = [];
final Map<String, AdminProgressBatch> _testModeProgressBatchesByQr = {};
final Map<String, List<Map<String, dynamic>>> _testModeRezkaFrameIssuesByQueue =
    {};
final Map<String, String> _testModeActiveProgressInputByQueue = {};
final Map<String, int> _testModeOrderStartedAtUnix = {};
final List<AdminLaminatsiyaAstatkaReport> _testModeLaminatsiyaAstatkaReports =
    [];
final List<AdminRezkaAstatkaReport> _testModeRezkaAstatkaReports = [];
final Map<String, AdminRawMaterialRule> _testModeRawMaterialRules = {};
final List<AdminRawMaterialAssignment> _testModeRawMaterialAssignments = [];
final Map<String, AdminQolipOrderNote> _testModeQolipOrderNotes = {};
final List<AdminWorker> _testModeWorkers = [];
final List<AdminWorkerGroup> _testModeWorkerGroups = [];
final List<AdminRoleAssignment> _testModeRoleAssignments = [
  ...TestModeDemoData.roleAssignments,
];
final Map<String, String> _testModeWorkerCodes = {};
final List<AdminSystemUser> _testModeSystemUsers = [];
final Map<String, String> _testModeSystemUserCodes = {};
bool _testModeForceSequenceSaveFailure = false;
bool _testModeForceCalculateTemplateSaveFailure = false;
bool _testModeForceProductionMapMenuLoadFailure = false;
bool _testModeForceProductionMapQueueSnapshotLoadFailure = false;
bool _testModeForceCompletedProductionMapOrdersLoadFailure = false;

class _TestModeApparatusTransferReceipt {
  const _TestModeApparatusTransferReceipt({
    required this.orderId,
    required this.fromApparatus,
    required this.toApparatus,
    required this.saved,
  });

  final String orderId;
  final String fromApparatus;
  final String toApparatus;
  final ProductionMapSaved saved;
}

void setMobileApiTestModeForceSequenceSaveFailure(bool value) {
  _testModeForceSequenceSaveFailure = value;
}

void setMobileApiTestModeForceCalculateTemplateSaveFailure(bool value) {
  _testModeForceCalculateTemplateSaveFailure = value;
}

void setMobileApiTestModeForceProductionMapMenuLoadFailure(bool value) {
  _testModeForceProductionMapMenuLoadFailure = value;
}

void setMobileApiTestModeForceProductionMapQueueSnapshotLoadFailure(
    bool value) {
  _testModeForceProductionMapQueueSnapshotLoadFailure = value;
}

void setMobileApiTestModeForceCompletedProductionMapOrdersLoadFailure(
    bool value) {
  _testModeForceCompletedProductionMapOrdersLoadFailure = value;
}

void setMobileApiTestModeQueueActionControlFixture({
  required String apparatus,
  required String orderId,
  required AdminApparatusQueueOrderActionControl control,
}) {
  final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) return;
  _testModeQueueActionControlFixtures.putIfAbsent(
    normalizedApparatus,
    () => {},
  )[normalizedOrderId] = control;
}

void resetMobileApiTestModeData() {
  _testModeProductionMaps.clear();
  _testModeAdminItemDetailOverrides.clear();
  _testModeDeletedAdminItemCodes.clear();
  _testModeApparatus.clear();
  _testModeApparatusCollections.clear();
  _testModeApparatusCollectionCounter = 0;
  _testModeWarehouses.clear();
  _testModeWarehouseAssignments.clear();
  _testModeMaterialItemGroups.clear();
  _testModeDeletedWarehouseNames.clear();
  _testModeBackupSnapshots.clear();
  _testModeApparatusSequences.clear();
  _testModeApparatusQueueStates.clear();
  _testModeApparatusTransfers.clear();
  _testModeOrderControls.clear();
  _testModeFrozenIssueNotesByOrderId.clear();
  _testModeRequeuedOrderIds.clear();
  _testModeApparatusQueuePolicies.clear();
  _testModeQueueActionControlFixtures.clear();
  _testModeApparatusCapacityProfiles.clear();
  _testModeApparatusDowntimes.clear();
  _testModeApparatusScheduleReservations.clear();
  _testModeCompletedQueueOrders.clear();
  _testModeCompletionRequests.clear();
  _testModeCompletionRequestDecisions.clear();
  _testModeProgressBatchesByQr.clear();
  _testModeRezkaFrameIssuesByQueue.clear();
  _resetTestModeTrainingInputBatches();
  _testModeActiveProgressInputByQueue.clear();
  _testModeOrderStartedAtUnix.clear();
  _testModeLaminatsiyaAstatkaReports.clear();
  _testModeRezkaAstatkaReports.clear();
  _testModeRawMaterialRules.clear();
  _testModeRawMaterialAssignments.clear();
  _testModeQolipOrderNotes.clear();
  resetMobileApiCalculateTestModeData();
  resetMobileApiQolipTestModeData();
  resetMobileApiInventoryMovementTestData();
  resetMobileApiTestModeWorkerSettingsData();
  _testModeForceSequenceSaveFailure = false;
  _testModeForceCalculateTemplateSaveFailure = false;
  _testModeForceProductionMapMenuLoadFailure = false;
  _testModeForceProductionMapQueueSnapshotLoadFailure = false;
  _testModeForceCompletedProductionMapOrdersLoadFailure = false;
}

int _testModeUnixSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _requireCanonicalApparatusId(
  String apparatusId, {
  bool allowEmpty = false,
}) {
  final normalized = apparatusId.trim();
  if ((allowEmpty && normalized.isEmpty) ||
      isCanonicalApparatusId(normalized)) {
    return normalized;
  }
  throw const MobileApiException(
    code: 'apparatus_id_invalid',
    message: 'Canonical apparatus ID noto‘g‘ri',
  );
}

List<String> _requireCanonicalApparatusIdList(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw const MobileApiException(
      code: 'apparatus_id_invalid',
      message: 'Canonical apparatus ID ro‘yxati noto‘g‘ri',
    );
  }
  final result = <String>[];
  for (final item in raw) {
    final apparatusId = _requireCanonicalApparatusId(item.toString());
    if (!result.contains(apparatusId)) result.add(apparatusId);
  }
  return List<String>.unmodifiable(result);
}

void _requireCanonicalProductionMapApparatusIds(
  ProductionMapDefinition map,
) {
  for (final node in map.nodes) {
    final apparatusId = node.apparatusId.trim();
    final assignedId = node.alternativeAssignedApparatusId.trim();
    if ((node.kind == 'apparatus' && !isCanonicalApparatusId(apparatusId)) ||
        (apparatusId.isNotEmpty && !isCanonicalApparatusId(apparatusId)) ||
        (assignedId.isNotEmpty && !isCanonicalApparatusId(assignedId))) {
      throw const MobileApiException(
        code: 'production_map_apparatus_id_invalid',
        message: 'Production map canonical apparatus ID talab qiladi',
      );
    }
  }
}

AdminApparatus _testModeRequiredApparatus(String apparatusId) {
  final normalizedId = _requireCanonicalApparatusId(apparatusId);
  for (final apparatus in _testModeApparatusCatalog()) {
    if (apparatus.id.trim() == normalizedId) {
      return apparatus;
    }
  }
  throw const MobileApiException(
    code: 'apparatus_not_found',
    message: 'Aparat topilmadi',
  );
}

String _testModeEffectiveNodeApparatusId(ProductionMapNode node) {
  final assigned = node.alternativeAssignedApparatusId.trim();
  return assigned.isEmpty ? node.apparatusId.trim() : assigned;
}

bool _testModeNodeHasOperation(ProductionMapNode node, String operation) {
  final apparatusId = _testModeEffectiveNodeApparatusId(node);
  if (apparatusId.isEmpty) return false;
  return _testModeRequiredApparatus(apparatusId)
          .operation
          .trim()
          .toLowerCase() ==
      operation.trim().toLowerCase();
}

AdminApparatusCapacityProfile _normalizeTestModeCapacityProfile(
  AdminApparatusCapacityProfile profile,
) {
  final canonical = _testModeRequiredApparatus(profile.apparatusId);
  final apparatusId = canonical.id.trim();
  final apparatus = canonical.name.trim();
  final capabilities = profile.capabilities
      .map((item) => item.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
  final levels = <String, int>{
    for (final entry in profile.capabilityLevels.entries)
      if (entry.key.trim().isNotEmpty)
        entry.key.trim().toLowerCase(): entry.value.clamp(1, 100),
  };
  for (final capability in capabilities) {
    levels.putIfAbsent(capability, () => 1);
  }
  return AdminApparatusCapacityProfile(
    apparatusId: apparatusId,
    apparatus: apparatus,
    capacitySlots: profile.capacitySlots.clamp(1, 64),
    setupMinutes: profile.setupMinutes.clamp(0, 30 * 24 * 60),
    cleanupMinutes: profile.cleanupMinutes.clamp(0, 30 * 24 * 60),
    efficiencyPercent: profile.efficiencyPercent.clamp(1, 200),
    finiteCapacity: profile.finiteCapacity,
    workingWindows: profile.workingWindows,
    capabilities: capabilities,
    capabilityLevels: levels,
    notes: profile.notes.trim(),
    updatedAtUnix: _testModeUnixSeconds(),
  );
}

AdminApparatusCapacityProfile _testModeProfileForApparatus({
  required String apparatusId,
}) {
  final canonical = _testModeRequiredApparatus(apparatusId);
  final normalizedId = canonical.id.trim();
  for (final profile in _testModeApparatusCapacityProfiles.values) {
    if (profile.apparatusId.trim() == normalizedId) {
      return profile;
    }
  }
  final inferredCapabilities = canonical.capabilities;
  final inferredProfiles = canonical.capabilityProfiles;
  return AdminApparatusCapacityProfile(
    apparatusId: normalizedId,
    apparatus: canonical.name.trim(),
    capabilities: inferredCapabilities,
    capabilityLevels: inferredProfiles.isEmpty
        ? {for (final capability in inferredCapabilities) capability: 1}
        : {
            for (final profile in inferredProfiles)
              if (profile.isValidAt(_testModeUnixSeconds()))
                profile.code: profile.level,
          },
  );
}

bool _testModeIntervalsOverlap(
  int leftStart,
  int leftEnd,
  int rightStart,
  int rightEnd,
) {
  return leftStart < rightEnd && rightStart < leftEnd;
}

bool _testModeFitsWorkingWindow(
  AdminApparatusCapacityProfile profile,
  int start,
  int end,
) {
  if (profile.workingWindows.isEmpty) return true;
  final startTime = DateTime.fromMillisecondsSinceEpoch(
    start * 1000,
    isUtc: true,
  );
  final endTime = DateTime.fromMillisecondsSinceEpoch(
    (end - 1) * 1000,
    isUtc: true,
  );
  if (startTime.weekday != endTime.weekday) return false;
  final startMinute = startTime.hour * 60 + startTime.minute;
  final endMinute = endTime.hour * 60 + endTime.minute + 1;
  return profile.workingWindows.any(
    (window) =>
        window.weekday == startTime.weekday &&
        startMinute >= window.startMinute &&
        endMinute <= window.endMinute,
  );
}

class _TestModeScheduledCandidate {
  const _TestModeScheduledCandidate({
    required this.index,
    required this.candidate,
    required this.profile,
    required this.reservedDurationMinutes,
    required this.startsAtUnix,
    required this.endsAtUnix,
  });

  final int index;
  final AdminApparatusScheduleCandidate candidate;
  final AdminApparatusCapacityProfile profile;
  final int reservedDurationMinutes;
  final int startsAtUnix;
  final int endsAtUnix;
}

({int startsAtUnix, int endsAtUnix})? _testModeFindScheduleSlot({
  required AdminApparatusCapacityProfile profile,
  required String apparatusId,
  required int earliestStartUnix,
  required int? latestEndUnix,
  required int reservedDurationMinutes,
}) {
  var cursor = earliestStartUnix < 60 ? 60 : earliestStartUnix;
  cursor = ((cursor + 59) ~/ 60) * 60;
  final horizon = cursor + 366 * 24 * 60 * 60;
  while (cursor < horizon) {
    final end = cursor + reservedDurationMinutes * 60;
    if (latestEndUnix != null && end > latestEndUnix) {
      return null;
    }
    if (!_testModeFitsWorkingWindow(profile, cursor, end)) {
      cursor += 60;
      continue;
    }
    final downtime = _testModeApparatusDowntimes.values.any(
      (item) =>
          item.active &&
          item.apparatusId.trim() == apparatusId &&
          _testModeIntervalsOverlap(
            cursor,
            end,
            item.startsAtUnix,
            item.endsAtUnix,
          ),
    );
    if (downtime) {
      cursor += 60;
      continue;
    }
    final conflicts = _testModeApparatusScheduleReservations.values
        .where(
          (item) =>
              (item.status == 'planned' || item.status == 'active') &&
              item.apparatusId.trim() == apparatusId &&
              _testModeIntervalsOverlap(
                cursor,
                end,
                item.startsAtUnix,
                item.endsAtUnix,
              ),
        )
        .length;
    final activeQueueOrderIds = <String>{};
    final apparatusStates =
        _testModeApparatusQueueStates[apparatusId] ?? const <String, String>{};
    for (final state in apparatusStates.entries) {
      if (apparatusQueueOrderStateFromRaw(state.value) ==
          ApparatusQueueOrderState.inProgress) {
        activeQueueOrderIds.add(state.key.trim());
      }
    }
    final scheduledActiveOrderIds = _testModeApparatusScheduleReservations
        .values
        .where(
          (item) =>
              item.status == 'active' && item.apparatusId.trim() == apparatusId,
        )
        .map((item) => item.orderId.trim())
        .toSet();
    final unscheduledActiveRuns = activeQueueOrderIds
        .where((orderId) => !scheduledActiveOrderIds.contains(orderId))
        .length;
    if (profile.finiteCapacity &&
        conflicts + unscheduledActiveRuns >= profile.capacitySlots) {
      cursor += 60;
      continue;
    }
    return (startsAtUnix: cursor, endsAtUnix: end);
  }
  return null;
}

bool _testModeCandidateAllowedForOrder(
  ProductionMapDefinition map,
  AdminApparatus source,
  AdminApparatus candidate,
) {
  final sourceId = source.id.trim();
  final candidateId = candidate.id.trim();
  if (sourceId == candidateId) {
    return map.nodes.any((node) {
      if (node.kind != 'apparatus') {
        return false;
      }
      final assignedId = node.alternativeAssignedApparatusId.trim();
      final effectiveId =
          assignedId.isEmpty ? node.apparatusId.trim() : assignedId;
      return effectiveId == sourceId;
    });
  }
  return productionMapCanMoveOrderToApparatus(
    nodes: map.nodes,
    fromApparatus: source,
    toApparatus: candidate,
    rollCount: map.rollCount,
    widthMm: map.widthMm,
  );
}

AdminApparatusScheduleReservation _testModeScheduleApparatusOrder({
  required String orderId,
  required String apparatusId,
  required String apparatus,
  required int earliestStartUnix,
  required int? latestEndUnix,
  required int durationMinutes,
  required int priority,
  required String source,
  required String reason,
  required String idempotencyKey,
  required List<AdminApparatusCapabilityRequirement> capabilityRequirements,
  required List<AdminApparatusScheduleCandidate> candidateApparatuses,
}) {
  final normalizedOrderId = orderId.trim();
  final sourceApparatus = _testModeRequiredApparatus(apparatusId);
  final normalizedId = sourceApparatus.id.trim();
  if (normalizedOrderId.isEmpty ||
      durationMinutes <= 0 ||
      earliestStartUnix <= 0 ||
      idempotencyKey.trim().isEmpty) {
    throw const MobileApiException(
      code: 'schedule_input_invalid',
      message: 'Jadval ma’lumotlari to‘liq emas',
    );
  }
  if (!_testModeProductionMaps.any(
    (saved) => saved.map.id.trim() == normalizedOrderId,
  )) {
    throw const MobileApiException(
      code: 'map_not_found',
      message: 'Zakaz topilmadi',
    );
  }
  for (final existing in _testModeApparatusScheduleReservations.values) {
    if (existing.idempotencyKey.trim() == idempotencyKey.trim()) {
      if (existing.orderId != normalizedOrderId ||
          existing.apparatusId != normalizedId) {
        throw const MobileApiException(
          code: 'schedule_idempotency_conflict',
          message: 'Bu idempotency kaliti boshqa jadvalga tegishli',
        );
      }
      return existing;
    }
  }
  final map = _testModeProductionMaps
      .firstWhere((saved) => saved.map.id.trim() == normalizedOrderId)
      .map;
  final candidates = <AdminApparatusScheduleCandidate>[];
  final seenCandidateKeys = <String>{};
  void addCandidate(String id) {
    final canonical = _testModeRequiredApparatus(id);
    final normalizedCandidateId = canonical.id.trim();
    if (!seenCandidateKeys.add(normalizedCandidateId)) return;
    candidates.add(
      AdminApparatusScheduleCandidate(
        apparatusId: normalizedCandidateId,
        apparatus: canonical.name.trim(),
      ),
    );
  }

  addCandidate(normalizedId);
  for (final candidate in candidateApparatuses) {
    addCandidate(candidate.apparatusId);
  }

  var routeCandidateCount = 0;
  var supportedCandidateCount = 0;
  var capabilityNotSupported = false;
  var capabilityLevelInsufficient = false;
  _TestModeScheduledCandidate? best;
  for (var index = 0; index < candidates.length; index++) {
    final candidate = candidates[index];
    final candidateApparatus =
        _testModeRequiredApparatus(candidate.apparatusId);
    if (!_testModeCandidateAllowedForOrder(
      map,
      sourceApparatus,
      candidateApparatus,
    )) {
      continue;
    }
    routeCandidateCount++;
    final profile = _testModeProfileForApparatus(
      apparatusId: candidate.apparatusId,
    );
    var supported = true;
    for (final requirement in capabilityRequirements) {
      final code = requirement.code.trim().toLowerCase();
      if (code.isEmpty) continue;
      final level = profile.capabilityLevels[code] ??
          (profile.capabilities.any((item) => item.toLowerCase() == code)
              ? 1
              : 0);
      if (level == 0) {
        capabilityNotSupported = true;
        supported = false;
        break;
      }
      if (level < requirement.minLevel) {
        capabilityLevelInsufficient = true;
        supported = false;
        break;
      }
    }
    if (!supported) continue;
    supportedCandidateCount++;
    final efficiency = profile.efficiencyPercent.clamp(1, 200);
    final runMinutes = (durationMinutes * 100 + efficiency - 1) ~/ efficiency;
    final reservedDuration =
        runMinutes + profile.setupMinutes + profile.cleanupMinutes;
    final slot = _testModeFindScheduleSlot(
      profile: profile,
      apparatusId: candidate.apparatusId,
      earliestStartUnix: earliestStartUnix,
      latestEndUnix: latestEndUnix,
      reservedDurationMinutes: reservedDuration,
    );
    if (slot == null) continue;
    final currentBest = best;
    final isBetter = currentBest == null ||
        slot.startsAtUnix < currentBest.startsAtUnix ||
        (slot.startsAtUnix == currentBest.startsAtUnix &&
            index < currentBest.index);
    if (isBetter) {
      best = _TestModeScheduledCandidate(
        index: index,
        candidate: candidate,
        profile: profile,
        reservedDurationMinutes: reservedDuration,
        startsAtUnix: slot.startsAtUnix,
        endsAtUnix: slot.endsAtUnix,
      );
    }
  }
  if (routeCandidateCount == 0) {
    throw const MobileApiException(
      code: 'move_not_allowed',
      message: 'Aparat bu order yo‘nalishiga mos emas',
    );
  }
  final selected = best;
  if (selected == null) {
    if (supportedCandidateCount == 0 && capabilityNotSupported) {
      throw const MobileApiException(
        code: 'capability_not_supported',
        message: 'Aparat bu capability’ni qo‘llamaydi',
      );
    }
    if (supportedCandidateCount == 0 && capabilityLevelInsufficient) {
      throw const MobileApiException(
        code: 'capability_level_insufficient',
        message: 'Aparat capability darajasi yetarli emas',
      );
    }
  } else {
    final reservation = AdminApparatusScheduleReservation(
      reservationId: 'apparatus-reservation:${idempotencyKey.trim()}',
      idempotencyKey: idempotencyKey.trim(),
      orderId: normalizedOrderId,
      apparatusId: selected.candidate.apparatusId,
      apparatus: selected.candidate.apparatus,
      startsAtUnix: selected.startsAtUnix,
      endsAtUnix: selected.endsAtUnix,
      requestedDurationMinutes: durationMinutes,
      reservedDurationMinutes: selected.reservedDurationMinutes,
      status: 'planned',
      priority: priority,
      source: source.trim(),
      reason: reason.trim(),
      capabilityRequirements: capabilityRequirements,
      createdAtUnix: _testModeUnixSeconds(),
    );
    _testModeApparatusScheduleReservations[reservation.reservationId] =
        reservation;
    return reservation;
  }
  throw const MobileApiException(
    code: 'capacity_no_working_window',
    message: 'Aparat uchun bo‘sh slot topilmadi',
  );
}

void _testModeSyncScheduleReservationStatus({
  required String orderId,
  required String apparatusId,
  required String status,
}) {
  final normalizedOrderId = orderId.trim();
  final normalizedApparatusId =
      _testModeRequiredApparatus(apparatusId).id.trim();
  for (final entry in _testModeApparatusScheduleReservations.entries.toList()) {
    final reservation = entry.value;
    if (reservation.orderId.trim() != normalizedOrderId ||
        reservation.apparatusId.trim() != normalizedApparatusId) {
      continue;
    }
    final current = reservation.status.trim().toLowerCase();
    final next = status.trim().toLowerCase();
    final allowed = current == next ||
        (next == 'active' &&
            (current == 'planned' ||
                current == 'paused' ||
                current == 'frozen')) ||
        (next == 'paused' && current == 'active') ||
        (next == 'frozen' &&
            (current == 'planned' ||
                current == 'active' ||
                current == 'paused')) ||
        (next == 'paused' && current == 'frozen') ||
        (next == 'completed' &&
            (current == 'planned' ||
                current == 'active' ||
                current == 'paused'));
    if (!allowed) continue;
    _testModeApparatusScheduleReservations[entry.key] =
        AdminApparatusScheduleReservation(
      reservationId: reservation.reservationId,
      idempotencyKey: reservation.idempotencyKey,
      orderId: reservation.orderId,
      apparatusId: reservation.apparatusId,
      apparatus: reservation.apparatus,
      startsAtUnix: reservation.startsAtUnix,
      endsAtUnix: reservation.endsAtUnix,
      requestedDurationMinutes: reservation.requestedDurationMinutes,
      reservedDurationMinutes: reservation.reservedDurationMinutes,
      status: next,
      priority: reservation.priority,
      source: reservation.source,
      reason: reservation.reason,
      capabilityRequirements: reservation.capabilityRequirements,
      createdAtUnix: reservation.createdAtUnix,
    );
  }
}

void _testModeMoveScheduleReservations({
  required String orderId,
  required String fromApparatusId,
  required String toApparatusId,
}) {
  final source = _testModeRequiredApparatus(fromApparatusId);
  final target = _testModeRequiredApparatus(toApparatusId);
  for (final entry in _testModeApparatusScheduleReservations.entries.toList()) {
    final reservation = entry.value;
    if (reservation.orderId.trim() != orderId.trim() ||
        reservation.status != 'paused' ||
        reservation.apparatusId.trim() != source.id.trim()) {
      continue;
    }
    _testModeApparatusScheduleReservations[entry.key] =
        AdminApparatusScheduleReservation(
      reservationId: reservation.reservationId,
      idempotencyKey: reservation.idempotencyKey,
      orderId: reservation.orderId,
      apparatusId: target.id.trim(),
      apparatus: target.name.trim(),
      startsAtUnix: reservation.startsAtUnix,
      endsAtUnix: reservation.endsAtUnix,
      requestedDurationMinutes: reservation.requestedDurationMinutes,
      reservedDurationMinutes: reservation.reservedDurationMinutes,
      status: reservation.status,
      priority: reservation.priority,
      source: reservation.source,
      reason: reservation.reason,
      capabilityRequirements: reservation.capabilityRequirements,
      createdAtUnix: reservation.createdAtUnix,
    );
  }
}

void _testModeEnsureApparatusExecutionCapacity({
  required String apparatusId,
  required String orderId,
}) {
  final profile = _testModeProfileForApparatus(
    apparatusId: apparatusId,
  );
  final now = _testModeUnixSeconds();
  bool isSameApparatus(String candidateId) =>
      candidateId.trim() == profile.apparatusId.trim();

  if (_testModeApparatusDowntimes.values.any(
    (downtime) =>
        downtime.active &&
        isSameApparatus(downtime.apparatusId) &&
        downtime.startsAtUnix <= now &&
        now < downtime.endsAtUnix,
  )) {
    throw const MobileApiException(
      code: 'capacity_unavailable',
      message: 'Aparat hozir nosozlik yoki downtime sababli mavjud emas',
    );
  }
  if (!_testModeFitsWorkingWindow(profile, now, now + 60)) {
    throw const MobileApiException(
      code: 'capacity_no_working_window',
      message: 'Aparatning hozirgi vaqtda ish oynasi yo‘q',
    );
  }
  final occupiedOrders = <String>{};
  for (final entry in _testModeApparatusQueueStates.entries) {
    if (entry.key.trim() != profile.apparatusId.trim()) continue;
    for (final state in entry.value.entries) {
      if (apparatusQueueOrderStateFromRaw(state.value) ==
          ApparatusQueueOrderState.inProgress) {
        if (state.key.trim() != orderId.trim()) {
          occupiedOrders.add(state.key.trim());
        }
      }
    }
  }
  for (final reservation in _testModeApparatusScheduleReservations.values) {
    if ((reservation.status != 'planned' && reservation.status != 'active') ||
        reservation.orderId.trim() == orderId.trim() ||
        !isSameApparatus(reservation.apparatusId) ||
        reservation.startsAtUnix > now ||
        now >= reservation.endsAtUnix) {
      continue;
    }
    occupiedOrders.add(reservation.orderId.trim());
  }
  if (profile.finiteCapacity &&
      occupiedOrders.length >= profile.capacitySlots) {
    throw const MobileApiException(
      code: 'capacity_conflict',
      message: 'Aparatning mavjud quvvati hozir band',
    );
  }
}

void _testModeEnsurePendingApparatusMove({
  required String orderId,
  required String fromApparatus,
}) {
  final storageKey = fromApparatus.trim();
  final rawState = _testModeApparatusQueueStates[storageKey]?[orderId.trim()];
  if (rawState == null ||
      apparatusQueueOrderStateFromRaw(rawState) ==
          ApparatusQueueOrderState.pending) {
    return;
  }
  throw const MobileApiException(
    code: 'started_order_move_requires_transfer',
    message: 'Ish boshlangan orderni avval pause qilib avariyaviy ko‘chiring',
  );
}

void resetMobileApiTestModeWorkerSettingsData() {
  _testModeWorkers.clear();
  _testModeWorkerGroups.clear();
  _testModeRoleAssignments
    ..clear()
    ..addAll(TestModeDemoData.roleAssignments);
  _testModeWorkerCodes.clear();
  _testModeSystemUsers.clear();
  _testModeSystemUserCodes.clear();
}

Map<String, List<String>> _testModeVisibleOrderIdsByApparatus() {
  final visible = <String, List<String>>{};
  for (final saved in _testModeProductionMaps) {
    final map = saved.map;
    final orderId = map.id.trim();
    if (!_testModeProductionMapIsVisibleQueueOrder(map)) {
      continue;
    }
    final seenApparatusIds = <String>{};
    for (final stage in productionMapLinearWorkStages(map)) {
      final apparatusId = stage.apparatusId;
      if (apparatusId == null || !seenApparatusIds.add(apparatusId)) {
        continue;
      }
      visible.putIfAbsent(apparatusId, () => <String>[]).add(orderId);
    }
  }
  return {
    for (final entry in visible.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  };
}

Map<String, List<AdminFrozenQueueOrder>> _testModeFrozenOrdersByApparatus() {
  final result = <String, List<AdminFrozenQueueOrder>>{};
  final seenOrderIds = <String>{};
  for (final entry in _testModeApparatusQueueStates.entries) {
    final apparatus = entry.key.trim();
    if (apparatus.isEmpty) {
      continue;
    }
    for (final stateEntry in entry.value.entries) {
      final orderId = stateEntry.key.trim();
      if (orderId.isEmpty ||
          stateEntry.value.trim().toLowerCase() != 'frozen' ||
          _testModeOrderControls[orderId] != AdminOrderControlState.frozen ||
          !seenOrderIds.add(orderId)) {
        continue;
      }
      result.putIfAbsent(apparatus, () => <AdminFrozenQueueOrder>[]).add(
            AdminFrozenQueueOrder(
              apparatus: apparatus,
              orderId: orderId,
              issueNote: _testModeFrozenIssueNotesByOrderId[orderId] ?? '',
              frozenAtUnix: 0,
              frozenBy: '',
            ),
          );
    }
  }
  return {
    for (final entry in result.entries)
      entry.key: List<AdminFrozenQueueOrder>.unmodifiable(entry.value),
  };
}

Map<String, List<String>> _testModeEffectiveQueueSequences() {
  final visible = _testModeVisibleOrderIdsByApparatus();
  final frozenIds = _frozenOrderIds(_testModeOrderControls);
  final knownKeys = <String>{
    ..._testModeApparatusSequences.keys,
    ...visible.keys,
  };
  return {
    for (final apparatus in knownKeys)
      apparatus: List<String>.unmodifiable(
        effectiveQueueSequence(
          sequence: _testModeApparatusSequences[apparatus] ?? const [],
          visibleOrderIds: visible[apparatus] ?? const [],
        ).where((orderId) => !frozenIds.contains(orderId.trim())),
      ),
  };
}

Set<String> _frozenOrderIds(Map<String, AdminOrderControlState> orderControls) {
  return {
    for (final entry in orderControls.entries)
      if (entry.value == AdminOrderControlState.frozen) entry.key.trim(),
  };
}

void _testModeRemoveOrderFromQueueSequence(String orderId) {
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) {
    return;
  }
  for (final sequence in _testModeApparatusSequences.values) {
    sequence.removeWhere((id) => id.trim() == normalizedOrderId);
  }
}

void _testModeRequeueOrderAtTail(String orderId) {
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) {
    return;
  }
  final visible = _testModeVisibleOrderIdsByApparatus();
  final knownKeys = <String>{
    ..._testModeApparatusSequences.keys,
    ...visible.keys,
  };
  for (final storageKey in knownKeys) {
    final apparatusVisible = visible[storageKey] ?? const <String>[];
    final sequence = List<String>.from(
      _testModeApparatusSequences[storageKey] ?? const [],
    )..removeWhere((id) => id.trim() == normalizedOrderId);
    if (apparatusVisible.any((id) => id.trim() == normalizedOrderId)) {
      sequence.add(normalizedOrderId);
      _testModeApparatusSequences[storageKey] = sequence;
    } else if (_testModeApparatusSequences.containsKey(storageKey)) {
      _testModeApparatusSequences[storageKey] = sequence;
    }
  }
}

MapEntry<String, Map<String, String>>? _testModeFrozenQueueTarget(
  String orderId,
) {
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) {
    return null;
  }
  for (final entry in _testModeApparatusQueueStates.entries) {
    if (apparatusQueueOrderStateFromRaw(entry.value[normalizedOrderId]) ==
        ApparatusQueueOrderState.inProgress) {
      return entry;
    }
  }
  for (final entry in _testModeApparatusQueueStates.entries) {
    if (apparatusQueueOrderStateFromRaw(entry.value[normalizedOrderId]) ==
        ApparatusQueueOrderState.paused) {
      return entry;
    }
  }
  return null;
}

void _testModeFreezeOrderQueue(String orderId) {
  final target = _testModeFrozenQueueTarget(orderId);
  if (target != null) {
    target.value[orderId.trim()] = 'frozen';
  }
  _testModeRemoveOrderFromQueueSequence(orderId);
}

Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
    _testModeQueueActionControls() {
  // This is a narrow fake server response. Widget code consumes this contract
  // exactly as it consumes a live backend response; it never derives controls.
  final result = <String, Map<String, AdminApparatusQueueOrderActionControl>>{};
  for (final fixtureEntry in _testModeQueueActionControlFixtures.entries) {
    result[fixtureEntry.key] = Map.unmodifiable(fixtureEntry.value);
  }
  return Map.unmodifiable(result);
}

bool _testModeProductionMapIsVisibleQueueOrder(ProductionMapDefinition map) {
  final orderId = map.id.trim();
  if (orderId.isEmpty || orderId.startsWith('template-')) {
    return false;
  }
  return map.code.trim().isNotEmpty ||
      map.orderNumber.trim().isNotEmpty ||
      orderId.startsWith('zakaz-');
}

String _adminWarehouseRoleToJson(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.supplier:
      return 'supplier';
    case UserRole.werka:
      return 'werka';
    case UserRole.customer:
      return 'customer';
    case UserRole.aparatchi:
      return 'aparatchi';
    case UserRole.qolipchi:
      return 'qolipchi';
    case UserRole.boyoqchi:
      return 'boyoqchi';
    case UserRole.materialTaminotchi:
      return 'material_taminotchi';
  }
}

List<String> _normalizedAdminScopeValues(Iterable<String> values) {
  final byKey = <String, String>{};
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      continue;
    }
    byKey.putIfAbsent(normalized.toLowerCase(), () => normalized);
  }
  final result = byKey.values.toList(growable: false);
  result.sort(
    (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return result;
}

bool _isMaterialRoleAssignmentForRef(
  AdminRoleAssignment assignment,
  String normalizedRef,
) {
  return assignment.principalRole == UserRole.materialTaminotchi &&
      assignment.principalRef.trim().toLowerCase() == normalizedRef;
}

class ProductionMapSaveWithOrderResult {
  const ProductionMapSaveWithOrderResult({
    required this.saved,
    required this.template,
  });

  final ProductionMapSaved saved;
  final CalculateOrderTemplate? template;
}

class AdminQolipOrderNote {
  const AdminQolipOrderNote({
    required this.orderId,
    required this.itemCode,
    required this.itemName,
    required this.qolipCodes,
    required this.status,
    this.updatedAt = '',
  });

  final String orderId;
  final String itemCode;
  final String itemName;
  final List<String> qolipCodes;
  final String status;
  final String updatedAt;

  bool get isGiven => status.trim().toLowerCase() == 'given';
  bool get isReturned => status.trim().toLowerCase() == 'returned';

  factory AdminQolipOrderNote.fromJson(Map<String, dynamic> json) {
    return AdminQolipOrderNote(
      orderId: json['order_id']?.toString().trim() ?? '',
      itemCode: json['item_code']?.toString().trim() ?? '',
      itemName: json['item_name']?.toString().trim() ?? '',
      qolipCodes: (json['qolip_codes'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      status: json['status']?.toString().trim() ?? '',
      updatedAt: json['updated_at']?.toString().trim() ?? '',
    );
  }
}

class AdminQolipOrderNoteDetails {
  const AdminQolipOrderNoteDetails({
    required this.orderId,
    required this.itemCode,
    required this.itemName,
    required this.requiredQolips,
    this.note,
  });

  final String orderId;
  final String itemCode;
  final String itemName;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final AdminQolipOrderNote? note;

  factory AdminQolipOrderNoteDetails.fromJson(Map<String, dynamic> json) {
    return AdminQolipOrderNoteDetails(
      orderId: json['order_id']?.toString().trim() ?? '',
      itemCode: json['item_code']?.toString().trim() ?? '',
      itemName: json['item_name']?.toString().trim() ?? '',
      requiredQolips: [
        for (final item in json['required_qolips'] as List? ?? const [])
          if (item is Map)
            AdminProductionMapRequiredQolip.fromJson(
              item.cast<String, dynamic>(),
            ),
      ],
      note: json['note'] is Map
          ? AdminQolipOrderNote.fromJson(
              (json['note'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

enum AdminQueueInteractionMode {
  freshStart,
  freshStartBlocked,
  requeuedWaiting,
  requeuedReady,
  inProgress,
  freezeRequested,
  paused,
  frozen,
  completed,
  waitingPreviousStage;

  static AdminQueueInteractionMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'fresh_start' => AdminQueueInteractionMode.freshStart,
      'fresh_start_blocked' => AdminQueueInteractionMode.freshStartBlocked,
      'requeued_waiting' => AdminQueueInteractionMode.requeuedWaiting,
      'requeued_ready' => AdminQueueInteractionMode.requeuedReady,
      'in_progress' => AdminQueueInteractionMode.inProgress,
      'freeze_requested' => AdminQueueInteractionMode.freezeRequested,
      'paused' => AdminQueueInteractionMode.paused,
      'frozen' => AdminQueueInteractionMode.frozen,
      'completed' => AdminQueueInteractionMode.completed,
      'waiting_previous_stage' =>
        AdminQueueInteractionMode.waitingPreviousStage,
      _ => null,
    };
  }
}

enum AdminQueueStartMaterialsMode {
  hidden,
  scanRequired;

  static AdminQueueStartMaterialsMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'hidden' => AdminQueueStartMaterialsMode.hidden,
      'scan_required' => AdminQueueStartMaterialsMode.scanRequired,
      _ => null,
    };
  }
}

enum AdminQueuePreviousWipMode {
  notRequired,
  scanRequired,
  waiting;

  static AdminQueuePreviousWipMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'not_required' => AdminQueuePreviousWipMode.notRequired,
      'scan_required' => AdminQueuePreviousWipMode.scanRequired,
      'waiting' => AdminQueuePreviousWipMode.waiting,
      _ => null,
    };
  }
}

enum AdminQueueQolipMode {
  notRequired,
  scanRequired;

  static AdminQueueQolipMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'not_required' => AdminQueueQolipMode.notRequired,
      'scan_required' => AdminQueueQolipMode.scanRequired,
      _ => null,
    };
  }
}

class AdminQueueWorkerInteraction {
  const AdminQueueWorkerInteraction({
    required this.mode,
    required this.startMaterialsMode,
    required this.materialScanRequired,
    required this.assignedMaterialsDisplayOnly,
    required this.materialIntakeAllowed,
    required this.previousWipMode,
    required this.qolipMode,
    this.blockingReasonCode = '',
  });

  final AdminQueueInteractionMode mode;
  final AdminQueueStartMaterialsMode startMaterialsMode;
  final bool materialScanRequired;
  final bool assignedMaterialsDisplayOnly;
  final bool materialIntakeAllowed;
  final AdminQueuePreviousWipMode previousWipMode;
  final AdminQueueQolipMode qolipMode;
  final String blockingReasonCode;

  static AdminQueueWorkerInteraction? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final mode = AdminQueueInteractionMode.tryParse(json['mode']);
    final startMaterialsMode = AdminQueueStartMaterialsMode.tryParse(
      json['start_materials_mode'],
    );
    final previousWipMode = AdminQueuePreviousWipMode.tryParse(
      json['previous_wip_mode'],
    );
    final qolipMode = AdminQueueQolipMode.tryParse(json['qolip_mode']);
    if (mode == null ||
        startMaterialsMode == null ||
        previousWipMode == null ||
        qolipMode == null ||
        json['material_scan_required'] is! bool ||
        json['assigned_materials_display_only'] is! bool ||
        json['material_intake_allowed'] is! bool) {
      return null;
    }
    return AdminQueueWorkerInteraction(
      mode: mode,
      startMaterialsMode: startMaterialsMode,
      materialScanRequired: json['material_scan_required'] as bool,
      assignedMaterialsDisplayOnly:
          json['assigned_materials_display_only'] as bool,
      materialIntakeAllowed: json['material_intake_allowed'] as bool,
      previousWipMode: previousWipMode,
      qolipMode: qolipMode,
      blockingReasonCode: json['blocking_reason_code']?.toString().trim() ?? '',
    );
  }
}

class AdminApparatusQueueOrderActionControl {
  const AdminApparatusQueueOrderActionControl({
    this.state = '',
    this.allowedActions = const {},
    this.interaction,
    this.hasOnlyKnownActions = false,
    this.hasRequiredFields = true,
    this.previousStage = '',
    this.previousStageReady = false,
    this.completeRequiresFullReport = false,
    this.freezeRequest,
  });

  final String state;
  final Set<String> allowedActions;
  final AdminQueueWorkerInteraction? interaction;
  final bool hasOnlyKnownActions;
  final bool hasRequiredFields;
  final String previousStage;
  final bool previousStageReady;
  final bool completeRequiresFullReport;
  final AdminProductionOrderFreezeDetails? freezeRequest;

  bool allows(String action) => allowedActions.contains(action.trim());

  bool get contractValid {
    final value = interaction;
    final normalizedState = state.trim().toLowerCase();
    if (value == null ||
        !hasOnlyKnownActions ||
        !hasRequiredFields ||
        !_knownApparatusQueueStates.contains(normalizedState) ||
        !_queueInteractionModeMatchesState(value.mode, normalizedState)) {
      return false;
    }
    for (final action in allowedActions) {
      if (!_queueActionMatchesInteractionMode(action, value.mode)) {
        return false;
      }
    }
    if (value.startMaterialsMode == AdminQueueStartMaterialsMode.scanRequired &&
        !value.materialScanRequired) {
      return false;
    }
    if (value.startMaterialsMode == AdminQueueStartMaterialsMode.hidden &&
        value.materialScanRequired) {
      return false;
    }
    if (value.previousWipMode != AdminQueuePreviousWipMode.notRequired &&
        previousStage.trim().isEmpty) {
      return false;
    }
    final expectedActions = switch (value.mode) {
      AdminQueueInteractionMode.freshStart => const {'start'},
      AdminQueueInteractionMode.requeuedReady => const {'resume'},
      AdminQueueInteractionMode.inProgress => null,
      AdminQueueInteractionMode.freezeRequested =>
        normalizedState == 'in_progress' ? const {'pause'} : const <String>{},
      AdminQueueInteractionMode.paused => null,
      AdminQueueInteractionMode.freshStartBlocked ||
      AdminQueueInteractionMode.requeuedWaiting ||
      AdminQueueInteractionMode.frozen ||
      AdminQueueInteractionMode.completed ||
      AdminQueueInteractionMode.waitingPreviousStage =>
        const <String>{},
    };
    if (expectedActions != null &&
        (allowedActions.length != expectedActions.length ||
            !allowedActions.containsAll(expectedActions))) {
      return false;
    }
    if (value.mode == AdminQueueInteractionMode.inProgress &&
        !allowedActions.contains('pause')) {
      return false;
    }
    if (value.mode == AdminQueueInteractionMode.freezeRequested) {
      final request = freezeRequest;
      if (request == null ||
          request.requestId.trim().isEmpty ||
          request.status.trim().toLowerCase() != 'pending' ||
          request.targetSessionId.trim().isEmpty ||
          request.targetApparatus.trim().isEmpty) {
        return false;
      }
    }
    if ((value.mode == AdminQueueInteractionMode.freshStartBlocked ||
            value.mode == AdminQueueInteractionMode.requeuedWaiting ||
            value.mode == AdminQueueInteractionMode.waitingPreviousStage) &&
        value.blockingReasonCode.trim().isEmpty) {
      return false;
    }
    return true;
  }

  bool isConsistentWith(
    AdminOrderControlState orderControlState, {
    String? queueState,
  }) {
    if (!contractValid) return false;
    if (queueState != null &&
        queueState.trim().isNotEmpty &&
        queueState.trim().toLowerCase() != state.trim().toLowerCase()) {
      return false;
    }
    final mode = interaction!.mode;
    if (orderControlState == AdminOrderControlState.frozen) {
      return mode == AdminQueueInteractionMode.frozen && allowedActions.isEmpty;
    }
    if (mode == AdminQueueInteractionMode.frozen ||
        state.trim().toLowerCase() == 'frozen') {
      return false;
    }
    if (orderControlState == AdminOrderControlState.freezeRequested) {
      return mode == AdminQueueInteractionMode.freezeRequested &&
          freezeRequest != null;
    }
    return mode != AdminQueueInteractionMode.freezeRequested;
  }

  factory AdminApparatusQueueOrderActionControl.fromJson(
    Map<String, dynamic> json,
  ) {
    const knownActions = {
      'start',
      'pause',
      'detach_roll',
      'resume',
      'roll_complete',
      'complete',
      'freeze',
    };
    final actions = <String>{};
    var hasOnlyKnownActions = true;
    final rawActions = json['allowed_actions'];
    if (rawActions is List) {
      for (final rawAction in rawActions) {
        if (rawAction is! String || rawAction.trim().isEmpty) {
          hasOnlyKnownActions = false;
          continue;
        }
        final action = rawAction.trim();
        actions.add(action);
        if (!knownActions.contains(action)) {
          hasOnlyKnownActions = false;
        }
      }
    } else {
      hasOnlyKnownActions = false;
    }
    return AdminApparatusQueueOrderActionControl(
      state: json['state']?.toString().trim() ?? '',
      allowedActions: Set<String>.unmodifiable(actions),
      interaction: AdminQueueWorkerInteraction.tryFromJson(json['interaction']),
      hasOnlyKnownActions: hasOnlyKnownActions,
      hasRequiredFields: json['state'] is String &&
          rawActions is List &&
          json['interaction'] is Map &&
          json['previous_stage_ready'] is bool &&
          json['complete_requires_full_report'] is bool,
      previousStage: json['previous_stage']?.toString().trim() ?? '',
      previousStageReady: json['previous_stage_ready'] == true,
      completeRequiresFullReport: json['complete_requires_full_report'] == true,
      freezeRequest: json['freeze_request'] is Map
          ? AdminProductionOrderFreezeDetails.fromJson(
              (json['freeze_request'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

const _knownApparatusQueueStates = {
  'pending',
  'in_progress',
  'paused',
  'frozen',
  'completed',
};

bool _queueInteractionModeMatchesState(
  AdminQueueInteractionMode mode,
  String state,
) {
  return switch (state) {
    'pending' => const {
        AdminQueueInteractionMode.freshStart,
        AdminQueueInteractionMode.freshStartBlocked,
        AdminQueueInteractionMode.requeuedWaiting,
        AdminQueueInteractionMode.requeuedReady,
        AdminQueueInteractionMode.waitingPreviousStage,
      }.contains(mode),
    'in_progress' => mode == AdminQueueInteractionMode.inProgress ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'paused' => mode == AdminQueueInteractionMode.paused ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'frozen' => mode == AdminQueueInteractionMode.frozen,
    'completed' => mode == AdminQueueInteractionMode.completed,
    _ => false,
  };
}

bool _queueActionMatchesInteractionMode(
  String action,
  AdminQueueInteractionMode mode,
) {
  return switch (action.trim()) {
    'start' => mode == AdminQueueInteractionMode.freshStart,
    'resume' => mode == AdminQueueInteractionMode.requeuedReady ||
        mode == AdminQueueInteractionMode.paused,
    'pause' => mode == AdminQueueInteractionMode.inProgress ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'detach_roll' => mode == AdminQueueInteractionMode.inProgress ||
        mode == AdminQueueInteractionMode.freezeRequested,
    'roll_complete' ||
    'complete' =>
      mode == AdminQueueInteractionMode.inProgress,
    'freeze' => mode == AdminQueueInteractionMode.inProgress,
    _ => false,
  };
}

Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
    _parseAdminQueueActionControls(Object? raw) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
      'queue_action_controls must be an object',
    );
  }
  final result = <String, Map<String, AdminApparatusQueueOrderActionControl>>{};
  for (final apparatusEntry in raw.entries) {
    if (apparatusEntry.key is! String ||
        !isCanonicalApparatusId(apparatusEntry.key.toString().trim())) {
      throw _productionMapQueueContractException(
        'queue_action_controls contains an invalid apparatus key',
      );
    }
    final apparatus = apparatusEntry.key.toString().trim();
    final rawOrders = apparatusEntry.value;
    if (rawOrders is! Map) {
      throw _productionMapQueueContractException(
        'queue_action_controls[$apparatus] must be an object',
      );
    }
    final orders = <String, AdminApparatusQueueOrderActionControl>{};
    for (final orderEntry in rawOrders.entries) {
      if (orderEntry.key is! String ||
          orderEntry.key.toString().trim().isEmpty ||
          orderEntry.value is! Map) {
        throw _productionMapQueueContractException(
          'queue_action_controls[$apparatus] contains an invalid order',
        );
      }
      final orderId = orderEntry.key.toString().trim();
      final rawControl = orderEntry.value;
      orders[orderId] = AdminApparatusQueueOrderActionControl.fromJson(
        (rawControl as Map).cast<String, dynamic>(),
      );
    }
    result[apparatus] =
        Map<String, AdminApparatusQueueOrderActionControl>.unmodifiable(orders);
  }
  return Map<String,
      Map<String, AdminApparatusQueueOrderActionControl>>.unmodifiable(result);
}

MobileApiException _productionMapQueueContractException(String detail) {
  return MobileApiException(
    code: 'production_map_snapshot_contract_invalid',
    message: 'Production map navbati server shartnomasiga mos emas: $detail',
  );
}

void _requireProductionMapSnapshotShape(
  Map<String, dynamic> json, {
  required bool includesMaps,
}) {
  if (includesMaps && json['maps'] is! List) {
    throw _productionMapQueueContractException('maps must be an array');
  }
  if (includesMaps) {
    for (final item in json['maps'] as List) {
      if (item is! Map) {
        throw _productionMapQueueContractException(
          'maps contains an invalid item',
        );
      }
    }
  }
  _requireProductionMapStringListMap(json['sequences'], 'sequences');
  _requireProductionMapStringListMap(
    json['visible_order_ids'],
    'visible_order_ids',
  );
  _requireProductionMapQueueStates(json['queue_states']);
  if (json['queue_action_controls'] is! Map) {
    throw _productionMapQueueContractException(
      'queue_action_controls must be an object',
    );
  }
  final rawPolicies = json['queue_policies'];
  if (rawPolicies is! List) {
    throw _productionMapQueueContractException(
      'queue_policies must be an array',
    );
  }
  for (final item in rawPolicies) {
    if (item is! Map ||
        item['apparatus_id'] is! String ||
        !isCanonicalApparatusId(
          (item['apparatus_id'] as String).trim(),
        ) ||
        item['policy'] is! String ||
        !const {
          'strict_sequence',
          'free_pick',
        }.contains((item['policy'] as String).trim())) {
      throw _productionMapQueueContractException(
        'queue_policies contains an invalid item',
      );
    }
  }
  final rawOrderControls = json['order_controls'];
  if (rawOrderControls is! Map) {
    throw _productionMapQueueContractException(
      'order_controls must be an object',
    );
  }
  for (final entry in rawOrderControls.entries) {
    final value = entry.value;
    final state = value is Map ? value['state'] : null;
    if (entry.key is! String ||
        entry.key.toString().trim().isEmpty ||
        state is! String ||
        !const {
          'active',
          'freeze_requested',
          'frozen',
        }.contains(state.trim())) {
      throw _productionMapQueueContractException(
        'order_controls contains an invalid item',
      );
    }
  }
}

void _requireProductionMapStringListMap(Object? raw, String field) {
  if (raw is! Map) {
    throw _productionMapQueueContractException('$field must be an object');
  }
  for (final entry in raw.entries) {
    if (entry.key is! String ||
        !isCanonicalApparatusId(entry.key.toString().trim()) ||
        entry.value is! List ||
        (entry.value as List).any(
          (value) => value is! String || value.trim().isEmpty,
        )) {
      throw _productionMapQueueContractException(
        '$field contains an invalid item',
      );
    }
  }
}

void _requireProductionMapQueueStates(Object? raw) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
      'queue_states must be an object',
    );
  }
  for (final apparatusEntry in raw.entries) {
    final states = apparatusEntry.value;
    if (apparatusEntry.key is! String ||
        !isCanonicalApparatusId(apparatusEntry.key.toString().trim()) ||
        states is! Map) {
      throw _productionMapQueueContractException(
        'queue_states contains an invalid apparatus',
      );
    }
    for (final stateEntry in states.entries) {
      final state = stateEntry.value;
      if (stateEntry.key is! String ||
          stateEntry.key.toString().trim().isEmpty ||
          state is! String ||
          !_knownApparatusQueueStates.contains(state.trim().toLowerCase())) {
        throw _productionMapQueueContractException(
          'queue_states contains an unknown order state',
        );
      }
    }
  }
}

void _validateProductionMapQueueContract({
  required Map<String, List<String>> sequences,
  required Map<String, List<String>> visibleOrderIds,
  required Map<String, Map<String, String>> queueStates,
  required Map<String, AdminApparatusQueuePolicy> queuePolicies,
  required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControls,
  required Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus,
}) {
  for (final entry in [...sequences.entries, ...visibleOrderIds.entries]) {
    if (!isCanonicalApparatusId(entry.key.trim()) ||
        entry.value.any((orderId) => orderId.trim().isEmpty)) {
      throw _productionMapQueueContractException(
        'queue order map contains an invalid apparatus or order',
      );
    }
  }
  for (final entry in queuePolicies.entries) {
    if (!isCanonicalApparatusId(entry.key.trim()) ||
        entry.value.apparatusId.trim() != entry.key.trim()) {
      throw _productionMapQueueContractException(
        'queue_policies contains an invalid apparatus',
      );
    }
  }
  for (final entry in frozenOrdersByApparatus.entries) {
    if (!isCanonicalApparatusId(entry.key.trim()) ||
        entry.value.any(
          (order) =>
              order.apparatus.trim() != entry.key.trim() ||
              order.orderId.trim().isEmpty,
        )) {
      throw _productionMapQueueContractException(
        'frozen_orders_by_apparatus contains an invalid order',
      );
    }
  }
  for (final apparatusEntry in queueStates.entries) {
    if (!isCanonicalApparatusId(apparatusEntry.key.trim())) {
      throw _productionMapQueueContractException(
        'queue_states contains an invalid apparatus key',
      );
    }
    for (final stateEntry in apparatusEntry.value.entries) {
      final state = stateEntry.value.trim().toLowerCase();
      if (stateEntry.key.trim().isEmpty ||
          !_knownApparatusQueueStates.contains(state)) {
        throw _productionMapQueueContractException(
          'queue_states contains an unknown order state',
        );
      }
    }
  }
  for (final apparatusEntry in queueActionControls.entries) {
    if (!isCanonicalApparatusId(apparatusEntry.key.trim())) {
      throw _productionMapQueueContractException(
        'queue_action_controls contains an invalid apparatus key',
      );
    }
    for (final orderEntry in apparatusEntry.value.entries) {
      final control = orderEntry.value;
      if (orderEntry.key.trim().isEmpty || !control.contractValid) {
        throw _productionMapQueueContractException(
          'queue_action_controls contains an invalid order control',
        );
      }
      final queueState = queueStates[apparatusEntry.key]?[orderEntry.key];
      if (queueState != null &&
          queueState.trim().isNotEmpty &&
          queueState.trim().toLowerCase() !=
              control.state.trim().toLowerCase()) {
        throw _productionMapQueueContractException(
          'queue state and action control state disagree',
        );
      }
    }
  }
}

class AdminApparatusQueueSnapshot {
  const AdminApparatusQueueSnapshot({
    required this.sequences,
    required this.visibleOrderIds,
    required this.queueStates,
    required this.queuePolicies,
    required this.orderControls,
    this.queueActionControls = const {},
    this.orderCustomers = const {},
    this.orderStatuses = const {},
    this.qolipOrderNotes = const {},
    this.frozenOrdersByApparatus = const {},
  });

  final Map<String, List<String>> sequences;
  final Map<String, List<String>> visibleOrderIds;
  final Map<String, Map<String, String>> queueStates;
  final Map<String, AdminApparatusQueuePolicy> queuePolicies;
  final Map<String, AdminOrderControlState> orderControls;
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControls;
  final Map<String, String> orderCustomers;
  final Map<String, AdminProductionOrderStatusDetail> orderStatuses;
  final Map<String, AdminQolipOrderNote> qolipOrderNotes;
  final Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus;

  AdminOrderControlState orderControlFor(String orderId) {
    // The backend serializes only non-active order-control overrides. Missing
    // records therefore mean the authoritative active state.
    return orderControls[orderId.trim()] ?? AdminOrderControlState.active;
  }

  void validateContract() {
    _validateProductionMapQueueContract(
      sequences: sequences,
      visibleOrderIds: visibleOrderIds,
      queueStates: queueStates,
      queuePolicies: queuePolicies,
      queueActionControls: queueActionControls,
      frozenOrdersByApparatus: frozenOrdersByApparatus,
    );
  }
}

enum AdminOrderControlState {
  active,
  freezeRequested,
  frozen;

  static AdminOrderControlState fromRaw(Object? raw) {
    return switch (raw?.toString().trim()) {
      'freeze_requested' => AdminOrderControlState.freezeRequested,
      'frozen' => AdminOrderControlState.frozen,
      _ => AdminOrderControlState.active,
    };
  }

  String get apiValue => switch (this) {
        AdminOrderControlState.active => 'active',
        AdminOrderControlState.freezeRequested => 'freeze_requested',
        AdminOrderControlState.frozen => 'frozen',
      };
}

AdminOrderControlState adminProductionMapOrderControlFor(
  Map<String, AdminOrderControlState> orderControls,
  String orderId,
) {
  // The backend publishes only freeze overrides; an absent record is the
  // authoritative active state, not a client-derived eligibility decision.
  return orderControls[orderId.trim()] ?? AdminOrderControlState.active;
}

enum AdminOrderControlAction {
  freeze,
  cancelFreeze,
  unfreeze,
  delete;

  String get apiValue => switch (this) {
        AdminOrderControlAction.freeze => 'freeze',
        AdminOrderControlAction.cancelFreeze => 'cancel_freeze',
        AdminOrderControlAction.unfreeze => 'unfreeze',
        AdminOrderControlAction.delete => 'delete',
      };
}

AdminOrderControlState? _applyTestModeOrderControl(
  String orderId,
  AdminOrderControlAction action,
) {
  final current =
      _testModeOrderControls[orderId] ?? AdminOrderControlState.active;
  final states = <String>[];
  for (final apparatusStates in _testModeApparatusQueueStates.values) {
    final state = apparatusStates[orderId]?.trim();
    if (state != null && state.isNotEmpty) states.add(state);
  }
  final started = states.any((state) => state != 'pending');
  final hasActiveWork = states.contains('in_progress');
  final hasFrozenState = states.any((state) => state == 'frozen');
  final completed = _testModeProductionMaps
      .where((saved) => saved.map.id.trim() == orderId)
      .map((saved) => saved.map)
      .any((map) {
    final stages = productionMapLinearWorkStages(map)
        .where((stage) => stage.isApparatus)
        .toList(growable: false);
    return stages.isNotEmpty &&
        stages.every((stage) {
          return _testModeApparatusQueueStates[stage.stageId]?[orderId] ==
              'completed';
        });
  });

  switch (action) {
    case AdminOrderControlAction.freeze:
      if (current != AdminOrderControlState.active) {
        throw const MobileApiException(
          code: 'order_control_action_not_allowed',
          message: 'Buyurtmaning hozirgi holatida bu amal mumkin emas',
        );
      }
      if (!started) {
        throw const MobileApiException(
          code: 'order_not_started',
          message: 'Boshlanmagan buyurtmani muzlatib bo‘lmaydi',
        );
      }
      if (completed) {
        throw const MobileApiException(
          code: 'order_already_completed',
          message: 'Tugallangan buyurtmani muzlatib bo‘lmaydi',
        );
      }
      if (hasFrozenState) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma boshqa apparatda muzlatilgan',
        );
      }
      final next = hasActiveWork
          ? AdminOrderControlState.freezeRequested
          : AdminOrderControlState.frozen;
      _testModeOrderControls[orderId] = next;
      if (next == AdminOrderControlState.frozen) {
        _testModeFreezeOrderQueue(orderId);
      }
      return next;
    case AdminOrderControlAction.cancelFreeze:
      if (current != AdminOrderControlState.freezeRequested) {
        throw const MobileApiException(
          code: 'order_control_action_not_allowed',
          message: 'Buyurtmaning hozirgi holatida bu amal mumkin emas',
        );
      }
      _testModeOrderControls[orderId] = AdminOrderControlState.active;
      return AdminOrderControlState.active;
    case AdminOrderControlAction.unfreeze:
      if (current != AdminOrderControlState.frozen) {
        throw const MobileApiException(
          code: 'order_control_action_not_allowed',
          message: 'Buyurtmaning hozirgi holatida bu amal mumkin emas',
        );
      }
      MapEntry<String, Map<String, String>>? target;
      for (final entry in _testModeApparatusQueueStates.entries) {
        if (entry.value[orderId]?.trim().toLowerCase() == 'frozen') {
          target = entry;
          break;
        }
      }
      if (target != null) {
        target.value[orderId] = 'pending';
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: target.key,
          status: 'active',
        );
      }
      _testModeRequeueOrderAtTail(orderId);
      _testModeFrozenIssueNotesByOrderId.remove(orderId);
      _testModeRequeuedOrderIds.add(orderId);
      _testModeOrderControls[orderId] = AdminOrderControlState.active;
      return AdminOrderControlState.active;
    case AdminOrderControlAction.delete:
      final blockers = <String>[];
      final visibleByApparatus = _testModeVisibleOrderIdsByApparatus();
      for (final apparatus in {
        ..._testModeApparatusSequences.keys,
        ...visibleByApparatus.keys,
      }) {
        final sequence = effectiveQueueSequence(
          sequence: _testModeApparatusSequences[apparatus] ?? const [],
          visibleOrderIds: visibleByApparatus[apparatus] ?? const [],
        );
        if (sequence.isNotEmpty && sequence.first == orderId) {
          blockers.add('Buyurtma $apparatus ketma-ketligida 1-o‘rinda turibdi');
        }
      }
      if (started) {
        blockers.add('Buyurtmada ish jarayoni allaqachon boshlangan');
      }
      final materialCount = _testModeRawMaterialAssignments
          .where((assignment) => assignment.orderId.trim() == orderId)
          .length;
      if (materialCount > 0) {
        blockers.add('Buyurtmaga $materialCount ta homashyo biriktirilgan');
      }
      if (blockers.isNotEmpty) {
        throw MobileApiException(
          code: 'order_delete_blocked',
          message: blockers.join('\n'),
          details: blockers,
        );
      }
      _testModeProductionMaps.removeWhere(
        (saved) => saved.map.id.trim() == orderId,
      );
      for (final sequence in _testModeApparatusSequences.values) {
        sequence.removeWhere((id) => id.trim() == orderId);
      }
      for (final apparatusStates in _testModeApparatusQueueStates.values) {
        apparatusStates.remove(orderId);
      }
      _testModeOrderControls.remove(orderId);
      _testModeFrozenIssueNotesByOrderId.remove(orderId);
      _testModeRequeuedOrderIds.remove(orderId);
      return null;
  }
}

Map<String, AdminOrderControlState> _parseAdminOrderControls(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key.toString().trim().isNotEmpty)
        entry.key.toString().trim(): AdminOrderControlState.fromRaw(
          entry.value is Map ? (entry.value as Map)['state'] : entry.value,
        ),
  };
}

Map<String, AdminProductionOrderStatusDetail> _parseAdminOrderStatuses(
  Object? raw,
) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key.toString().trim().isNotEmpty)
        entry.key.toString().trim(): AdminProductionOrderStatusDetail.fromJson(
          entry.value,
        ),
  };
}

Map<String, AdminQolipOrderNote> _parseAdminQolipOrderNotes(Object? raw) {
  if (raw is! List) {
    return const {};
  }
  final notes = <String, AdminQolipOrderNote>{};
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final note = AdminQolipOrderNote.fromJson(item.cast<String, dynamic>());
    if (note.orderId.isNotEmpty) {
      notes[note.orderId] = note;
    }
  }
  return notes;
}

Map<String, List<AdminFrozenQueueOrder>> _parseAdminFrozenOrdersByApparatus(
  Object? raw,
) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
      'frozen_orders_by_apparatus must be an object',
    );
  }
  final result = <String, List<AdminFrozenQueueOrder>>{};
  for (final entry in raw.entries) {
    final apparatus = entry.key.toString().trim();
    final rawOrders = entry.value;
    if (!isCanonicalApparatusId(apparatus) || rawOrders is! List) {
      throw _productionMapQueueContractException(
        'frozen_orders_by_apparatus contains an invalid apparatus',
      );
    }
    final orders = <AdminFrozenQueueOrder>[];
    for (final item in rawOrders) {
      if (item is! Map) {
        continue;
      }
      final frozen = AdminFrozenQueueOrder.fromJson(
        item.cast<String, dynamic>(),
        fallbackApparatus: apparatus,
      );
      if (frozen.orderId.trim().isNotEmpty) {
        orders.add(frozen);
      }
    }
    if (orders.isNotEmpty) {
      result[apparatus] = List<AdminFrozenQueueOrder>.unmodifiable(orders);
    }
  }
  return Map<String, List<AdminFrozenQueueOrder>>.unmodifiable(result);
}

Map<String, List<String>> _parseRequiredProductionMapVisibleOrderIds(
  Map<String, dynamic> json,
) {
  if (!json.containsKey('visible_order_ids') ||
      json['visible_order_ids'] == null) {
    throw const MobileApiException(
      code: 'production_map_visible_order_ids_missing',
      message: 'Production map navbati noto‘liq',
    );
  }
  _requireProductionMapStringListMap(
    json['visible_order_ids'],
    'visible_order_ids',
  );
  return MobileApi.instance.parseApparatusSequenceMap(
    json['visible_order_ids'],
  );
}

class AdminCompletedQueueOrder {
  const AdminCompletedQueueOrder({
    required this.apparatus,
    required this.orderId,
    required this.completedAtUnix,
    this.status = 'completed',
    this.issueNote = '',
  });

  final String apparatus;
  final String orderId;
  final int completedAtUnix;
  final String status;
  final String issueNote;

  factory AdminCompletedQueueOrder.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().trim() ?? '';
    return AdminCompletedQueueOrder(
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      status: status.isEmpty ? 'completed' : status,
      issueNote: json['issue_note']?.toString() ?? '',
    );
  }
}

class AdminFrozenQueueOrder {
  const AdminFrozenQueueOrder({
    required this.apparatus,
    required this.orderId,
    required this.issueNote,
    required this.frozenAtUnix,
    required this.frozenBy,
  });

  final String apparatus;
  final String orderId;
  final String issueNote;
  final int frozenAtUnix;
  final String frozenBy;

  factory AdminFrozenQueueOrder.fromJson(
    Map<String, dynamic> json, {
    String fallbackApparatus = '',
  }) {
    final rawApparatus = json['apparatus']?.toString().trim() ?? '';
    final apparatus = _requireCanonicalApparatusId(
      rawApparatus.isEmpty ? fallbackApparatus : rawApparatus,
    );
    return AdminFrozenQueueOrder(
      apparatus: apparatus,
      orderId: json['order_id']?.toString() ?? '',
      issueNote: json['issue_note']?.toString() ?? '',
      frozenAtUnix: (json['frozen_at_unix'] as num?)?.toInt() ?? 0,
      frozenBy: json['frozen_by']?.toString() ?? '',
    );
  }
}

class AdminCompletionRequestNotification {
  const AdminCompletionRequestNotification({
    required this.eventId,
    required this.apparatus,
    required this.orderId,
    required this.orderNumber,
    required this.orderTitle,
    required this.productCode,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    required this.description,
    this.zeroMetricCodes = const [],
    this.noticeKind = 'completion_request',
    this.decisionRequired = true,
    required this.createdAtUnix,
  });

  final String eventId;
  final String apparatus;
  final String orderId;
  final String orderNumber;
  final String orderTitle;
  final String productCode;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final List<String> zeroMetricCodes;
  final String noticeKind;
  final bool decisionRequired;
  final int createdAtUnix;

  factory AdminCompletionRequestNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminCompletionRequestNotification(
      eventId: json['event_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderTitle: json['order_title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      zeroMetricCodes: [
        if (json['zero_metric_codes'] is List)
          for (final code in json['zero_metric_codes'] as List)
            if (code.toString().trim().isNotEmpty) code.toString().trim(),
      ],
      noticeKind: json['notice_kind']?.toString() ?? 'completion_request',
      decisionRequired: json['decision_required'] is bool
          ? json['decision_required'] as bool
          : true,
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminCompletionRequestDecisionNotification {
  const AdminCompletionRequestDecisionNotification({
    required this.eventId,
    required this.requestEventId,
    required this.decision,
    required this.apparatus,
    required this.orderId,
    required this.orderNumber,
    required this.orderTitle,
    required this.productCode,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    required this.decidedByRole,
    required this.decidedByRef,
    required this.decidedByDisplayName,
    required this.description,
    required this.message,
    required this.createdAtUnix,
  });

  final String eventId;
  final String requestEventId;
  final String decision;
  final String apparatus;
  final String orderId;
  final String orderNumber;
  final String orderTitle;
  final String productCode;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String decidedByRole;
  final String decidedByRef;
  final String decidedByDisplayName;
  final String description;
  final String message;
  final int createdAtUnix;

  factory AdminCompletionRequestDecisionNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminCompletionRequestDecisionNotification(
      eventId: json['event_id']?.toString() ?? '',
      requestEventId: json['request_event_id']?.toString() ?? '',
      decision: json['decision']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderTitle: json['order_title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      decidedByRole: json['decided_by_role']?.toString() ?? '',
      decidedByRef: json['decided_by_ref']?.toString() ?? '',
      decidedByDisplayName: json['decided_by_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProductionOrderLogEntry {
  const AdminProductionOrderLogEntry({
    required this.eventId,
    required this.apparatus,
    required this.orderId,
    required this.action,
    required this.fromState,
    required this.toState,
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.createdAtUnix,
    this.completedWithIssue = false,
    this.issueNote = '',
    this.transfer,
    this.freeze,
  });

  final String eventId;
  final String apparatus;
  final String orderId;
  final String action;
  final String fromState;
  final String toState;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final int createdAtUnix;
  final bool completedWithIssue;
  final String issueNote;
  final AdminProductionOrderTransferDetails? transfer;
  final AdminProductionOrderFreezeDetails? freeze;

  factory AdminProductionOrderLogEntry.fromJson(Map<String, dynamic> json) {
    return AdminProductionOrderLogEntry(
      eventId: json['event_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      fromState: json['from_state']?.toString() ?? '',
      toState: json['to_state']?.toString() ?? '',
      actorRole: json['actor_role']?.toString() ?? '',
      actorRef: json['actor_ref']?.toString() ?? '',
      actorDisplayName: json['actor_display_name']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      completedWithIssue: json['completed_with_issue'] == true,
      issueNote: json['issue_note']?.toString() ?? '',
      transfer: json['transfer'] is Map
          ? AdminProductionOrderTransferDetails.fromJson(
              (json['transfer'] as Map).cast<String, dynamic>(),
            )
          : null,
      freeze: json['freeze'] is Map
          ? AdminProductionOrderFreezeDetails.fromJson(
              (json['freeze'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class AdminProductionOrderTransferDetails {
  const AdminProductionOrderTransferDetails({
    required this.transferId,
    required this.fromApparatus,
    required this.toApparatus,
    required this.reason,
    required this.sessionId,
    required this.progressBatchId,
    required this.materialBarcodes,
  });

  final String transferId;
  final String fromApparatus;
  final String toApparatus;
  final String reason;
  final String sessionId;
  final String progressBatchId;
  final List<String> materialBarcodes;

  factory AdminProductionOrderTransferDetails.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminProductionOrderTransferDetails(
      transferId: json['transfer_id']?.toString() ?? '',
      fromApparatus: _requireCanonicalApparatusId(
        json['from_apparatus']?.toString() ?? '',
      ),
      toApparatus: _requireCanonicalApparatusId(
        json['to_apparatus']?.toString() ?? '',
      ),
      reason: json['reason']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      progressBatchId: json['progress_batch_id']?.toString() ?? '',
      materialBarcodes: [
        for (final item in json['material_barcodes'] as List? ?? const [])
          item.toString(),
      ],
    );
  }
}

class AdminProductionOrderFreezeDetails {
  const AdminProductionOrderFreezeDetails({
    required this.requestId,
    required this.status,
    required this.targetSessionId,
    required this.targetApparatus,
    required this.targetWorkerRole,
    required this.targetWorkerRef,
    required this.targetWorkerDisplayName,
    required this.requestedAtUnix,
    required this.transitionedAtUnix,
  });

  final String requestId;
  final String status;
  final String targetSessionId;
  final String targetApparatus;
  final String targetWorkerRole;
  final String targetWorkerRef;
  final String targetWorkerDisplayName;
  final int requestedAtUnix;
  final int transitionedAtUnix;

  factory AdminProductionOrderFreezeDetails.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminProductionOrderFreezeDetails(
      requestId: json['request_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      targetSessionId: json['target_session_id']?.toString() ?? '',
      targetApparatus: _requireCanonicalApparatusId(
        json['target_apparatus']?.toString() ?? '',
      ),
      targetWorkerRole: json['target_worker_role']?.toString() ?? '',
      targetWorkerRef: json['target_worker_ref']?.toString() ?? '',
      targetWorkerDisplayName:
          json['target_worker_display_name']?.toString() ?? '',
      requestedAtUnix: (json['requested_at_unix'] as num?)?.toInt() ?? 0,
      transitionedAtUnix: (json['transitioned_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminClosedProductionOrder {
  const AdminClosedProductionOrder({
    required this.orderId,
    required this.orderNumber,
    required this.title,
    required this.productCode,
    required this.completedAtUnix,
    required this.closedByRole,
    required this.closedByRef,
    required this.closedByDisplayName,
    required this.logs,
    this.progressBatches = const [],
  });

  final String orderId;
  final String orderNumber;
  final String title;
  final String productCode;
  final int completedAtUnix;
  final String closedByRole;
  final String closedByRef;
  final String closedByDisplayName;
  final List<AdminProductionOrderLogEntry> logs;
  final List<AdminProgressBatch> progressBatches;

  factory AdminClosedProductionOrder.fromJson(Map<String, dynamic> json) {
    final logsRaw = json['logs'];
    return AdminClosedProductionOrder(
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      productCode: json['product_code']?.toString() ?? '',
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      closedByRole: json['closed_by_role']?.toString() ?? '',
      closedByRef: json['closed_by_ref']?.toString() ?? '',
      closedByDisplayName: json['closed_by_display_name']?.toString() ?? '',
      progressBatches: [
        for (final item in json['progress_batches'] as List? ?? const [])
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
      ],
      logs: [
        if (logsRaw is List)
          for (final item in logsRaw)
            AdminProductionOrderLogEntry.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
    );
  }
}

class _TestModeCompletedQueueOrder {
  const _TestModeCompletedQueueOrder({
    required this.actorRef,
    required this.order,
  });

  final String actorRef;
  final AdminCompletedQueueOrder order;
}

class AdminLaminatsiyaAstatkaReport {
  const AdminLaminatsiyaAstatkaReport({
    required this.reportId,
    required this.orderId,
    required this.apparatus,
    required this.fromAtUnix,
    required this.toAtUnix,
    required this.laminationPrintLeftoverRolls,
    required this.laminationFilmLeftoverRolls,
    required this.totalWaste,
    this.finishedGoodsMeter,
    this.finishedGoodsKg,
    this.bobinaKg,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    this.description = '',
    required this.createdAtUnix,
  });

  final String reportId;
  final String orderId;
  final String apparatus;
  final int fromAtUnix;
  final int toAtUnix;
  final double laminationPrintLeftoverRolls;
  final double laminationFilmLeftoverRolls;
  final double totalWaste;
  final double? finishedGoodsMeter;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final int createdAtUnix;

  factory AdminLaminatsiyaAstatkaReport.fromJson(Map<String, dynamic> json) {
    return AdminLaminatsiyaAstatkaReport(
      reportId: json['report_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      fromAtUnix: (json['from_at_unix'] as num?)?.toInt() ?? 0,
      toAtUnix: (json['to_at_unix'] as num?)?.toInt() ?? 0,
      laminationPrintLeftoverRolls:
          (json['lamination_print_leftover_rolls'] as num?)?.toDouble() ?? 0,
      laminationFilmLeftoverRolls:
          (json['lamination_film_leftover_rolls'] as num?)?.toDouble() ?? 0,
      totalWaste: (json['total_waste'] as num?)?.toDouble() ?? 0,
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble() ??
          (json['babina_kg'] as num?)?.toDouble(),
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminRezkaAstatkaReport {
  const AdminRezkaAstatkaReport({
    required this.reportId,
    required this.orderId,
    required this.apparatus,
    required this.fromAtUnix,
    required this.toAtUnix,
    required this.totalWaste,
    required this.rezkaBosmaWaste,
    required this.rezkaLaminationWaste,
    required this.rezkaEdgeWaste,
    this.finishedGoodsMeter,
    this.finishedGoodsKg,
    this.bobinaKg,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    this.description = '',
    required this.createdAtUnix,
  });

  final String reportId;
  final String orderId;
  final String apparatus;
  final int fromAtUnix;
  final int toAtUnix;
  final double totalWaste;
  final double rezkaBosmaWaste;
  final double rezkaLaminationWaste;
  final double rezkaEdgeWaste;
  final double? finishedGoodsMeter;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final int createdAtUnix;

  factory AdminRezkaAstatkaReport.fromJson(Map<String, dynamic> json) {
    return AdminRezkaAstatkaReport(
      reportId: json['report_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      fromAtUnix: (json['from_at_unix'] as num?)?.toInt() ?? 0,
      toAtUnix: (json['to_at_unix'] as num?)?.toInt() ?? 0,
      totalWaste: (json['total_waste'] as num?)?.toDouble() ?? 0,
      rezkaBosmaWaste: (json['rezka_bosma_waste'] as num?)?.toDouble() ?? 0,
      rezkaLaminationWaste:
          (json['rezka_lamination_waste'] as num?)?.toDouble() ?? 0,
      rezkaEdgeWaste: (json['rezka_edge_waste'] as num?)?.toDouble() ?? 0,
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble() ??
          (json['babina_kg'] as num?)?.toDouble(),
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProgressBatch {
  const AdminProgressBatch({
    required this.batchId,
    this.revision = 1,
    required this.sessionId,
    required this.apparatus,
    required this.orderId,
    required this.action,
    required this.status,
    required this.producedQty,
    required this.uom,
    required this.qrPayload,
    required this.labelItemCode,
    required this.labelItemName,
    required this.executorName,
    this.diameter,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.bobinaKg,
    this.finishedGoodsMeter,
    this.description = '',
    this.workerRole = '',
    this.workerRef = '',
    this.workerDisplayName = '',
    this.wipStatus = '',
    this.statusDetail = const AdminProgressBatchStatusDetail(),
    this.currentApparatus = '',
    this.currentApparatusKey = '',
    this.currentLocation = '',
    this.nextApparatus = '',
    this.parentBatchId = '',
    this.usedBySessionId = '',
    this.usedByApparatus = '',
    this.processedBySessionId = '',
    this.processedByApparatus = '',
    this.startedAtUnix = 0,
    this.completedAtUnix = 0,
    this.payloadJson = const {},
  });

  final String batchId;
  final int revision;
  final String sessionId;
  final String apparatus;
  final String orderId;
  final String action;
  final String status;
  final double producedQty;
  final String uom;
  final String qrPayload;
  final String labelItemCode;
  final String labelItemName;
  final String executorName;
  final double? diameter;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final double? finishedGoodsMeter;
  final String description;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String wipStatus;
  final AdminProgressBatchStatusDetail statusDetail;
  final String currentApparatus;
  final String currentApparatusKey;
  final String currentLocation;
  final String nextApparatus;
  final String parentBatchId;
  final String usedBySessionId;
  final String usedByApparatus;
  final String processedBySessionId;
  final String processedByApparatus;
  final int startedAtUnix;
  final int completedAtUnix;
  final Map<String, dynamic> payloadJson;

  factory AdminProgressBatch.fromJson(Map<String, dynamic> json) {
    final currentApparatus = _requireCanonicalApparatusId(
      json['current_apparatus']?.toString() ?? '',
      allowEmpty: true,
    );
    final currentApparatusKey = _requireCanonicalApparatusId(
      json['current_apparatus_key']?.toString() ?? '',
      allowEmpty: true,
    );
    if (currentApparatus.isNotEmpty &&
        currentApparatusKey.isNotEmpty &&
        currentApparatus != currentApparatusKey) {
      throw const MobileApiException(
        code: 'apparatus_id_mismatch',
        message: 'Progress aparat identity mos emas',
      );
    }
    return AdminProgressBatch(
      batchId: json['batch_id']?.toString() ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      sessionId: json['session_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      producedQty: (json['produced_qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString() ?? '',
      labelItemCode: json['label_item_code']?.toString() ?? '',
      labelItemName: json['label_item_name']?.toString() ?? '',
      executorName: json['executor_name']?.toString() ?? '',
      diameter: (json['diameter'] as num?)?.toDouble(),
      returnInkKg: (json['return_ink_kg'] as num?)?.toDouble(),
      laminationPrintLeftoverRolls:
          (json['lamination_print_leftover_rolls'] as num?)?.toDouble(),
      laminationFilmLeftoverRolls:
          (json['lamination_film_leftover_rolls'] as num?)?.toDouble(),
      rezkaBosmaWaste: (json['rezka_bosma_waste'] as num?)?.toDouble(),
      rezkaLaminationWaste:
          (json['rezka_lamination_waste'] as num?)?.toDouble(),
      rezkaEdgeWaste: (json['rezka_edge_waste'] as num?)?.toDouble(),
      totalWaste: (json['total_waste'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble() ??
          (json['babina_kg'] as num?)?.toDouble(),
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      wipStatus: json['wip_status']?.toString() ?? '',
      statusDetail: AdminProgressBatchStatusDetail.fromJsonOrBatchJson(json),
      currentApparatus: currentApparatus,
      currentApparatusKey: currentApparatusKey,
      currentLocation: json['current_location']?.toString() ?? '',
      nextApparatus: _requireCanonicalApparatusId(
        json['next_apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      parentBatchId: json['parent_batch_id']?.toString() ?? '',
      usedBySessionId: json['used_by_session_id']?.toString() ?? '',
      usedByApparatus: _requireCanonicalApparatusId(
        json['used_by_apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      processedBySessionId: json['processed_by_session_id']?.toString() ?? '',
      processedByApparatus: _requireCanonicalApparatusId(
        json['processed_by_apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      payloadJson: _jsonObject(json['payload_json']),
    );
  }

  AdminProgressBatch copyWith({
    int? revision,
    String? status,
    String? wipStatus,
    String? currentApparatus,
    String? currentLocation,
    String? nextApparatus,
    String? usedBySessionId,
    String? usedByApparatus,
    String? processedBySessionId,
    String? processedByApparatus,
    Map<String, dynamic>? payloadJson,
  }) {
    return AdminProgressBatch(
      batchId: batchId,
      revision: revision ?? this.revision,
      sessionId: sessionId,
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      status: status ?? this.status,
      producedQty: producedQty,
      uom: uom,
      qrPayload: qrPayload,
      labelItemCode: labelItemCode,
      labelItemName: labelItemName,
      executorName: executorName,
      diameter: diameter,
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      bobinaKg: bobinaKg,
      finishedGoodsMeter: finishedGoodsMeter,
      description: description,
      workerRole: workerRole,
      workerRef: workerRef,
      workerDisplayName: workerDisplayName,
      wipStatus: wipStatus ?? this.wipStatus,
      statusDetail: statusDetail,
      currentApparatus: currentApparatus ?? this.currentApparatus,
      currentApparatusKey: currentApparatusKey,
      currentLocation: currentLocation ?? this.currentLocation,
      nextApparatus: nextApparatus ?? this.nextApparatus,
      parentBatchId: parentBatchId,
      usedBySessionId: usedBySessionId ?? this.usedBySessionId,
      usedByApparatus: usedByApparatus ?? this.usedByApparatus,
      processedBySessionId: processedBySessionId ?? this.processedBySessionId,
      processedByApparatus: processedByApparatus ?? this.processedByApparatus,
      startedAtUnix: startedAtUnix,
      completedAtUnix: completedAtUnix,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }
}

class AdminProgressBatchCorrectionInput {
  const AdminProgressBatchCorrectionInput({
    required this.batchId,
    required this.expectedRevision,
    required this.producedQty,
    required this.uom,
    required this.reason,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.bobinaKg,
    this.finishedGoodsMeter,
    this.diameter,
    this.description = '',
  });

  final String batchId;
  final int expectedRevision;
  final double producedQty;
  final String uom;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final double? finishedGoodsMeter;
  final double? diameter;
  final String description;
  final String reason;

  Map<String, dynamic> toJson() => {
        'batch_id': batchId.trim(),
        'expected_revision': expectedRevision,
        'produced_qty': producedQty,
        'uom': uom.trim(),
        'return_ink_kg': returnInkKg,
        'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
        'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
        'rezka_bosma_waste': rezkaBosmaWaste,
        'rezka_lamination_waste': rezkaLaminationWaste,
        'rezka_edge_waste': rezkaEdgeWaste,
        'total_waste': totalWaste,
        'finished_goods_kg': finishedGoodsKg,
        'bobina_kg': bobinaKg,
        'finished_goods_meter': finishedGoodsMeter,
        'diameter': diameter,
        'description': description.trim(),
        'reason': reason.trim(),
      };
}

class AdminProgressBatchCorrectionRecord {
  const AdminProgressBatchCorrectionRecord({
    required this.batchId,
    required this.previousRevision,
    required this.newRevision,
    required this.reason,
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.oldValues,
    required this.newValues,
    required this.createdAtUnix,
  });

  final String batchId;
  final int previousRevision;
  final int newRevision;
  final String reason;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final int createdAtUnix;

  factory AdminProgressBatchCorrectionRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    final actor = json['actor'];
    final actorJson = actor is Map
        ? actor.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminProgressBatchCorrectionRecord(
      batchId: json['batch_id']?.toString() ?? '',
      previousRevision: (json['previous_revision'] as num?)?.toInt() ?? 0,
      newRevision: (json['new_revision'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
      actorRole: actorJson['role']?.toString() ?? '',
      actorRef:
          actorJson['ref_']?.toString() ?? actorJson['ref']?.toString() ?? '',
      actorDisplayName: actorJson['display_name']?.toString() ?? '',
      oldValues: _jsonObject(json['old_values']),
      newValues: _jsonObject(json['new_values']),
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProgressQrReprintResult {
  const AdminProgressQrReprintResult({
    required this.ok,
    required this.batch,
    this.printJob,
    this.printStatus = '',
  });

  final bool ok;
  final AdminProgressBatch batch;
  final UsbRpsPrintRequest? printJob;
  final String printStatus;
}

class AdminProgressBatchStatusDetail {
  const AdminProgressBatchStatusDetail({
    this.workStatus = '',
    this.wipStatus = '',
    this.flowStatus = '',
    this.stockStatus = '',
  });

  final String workStatus;
  final String wipStatus;
  final String flowStatus;
  final String stockStatus;

  factory AdminProgressBatchStatusDetail.fromJsonOrBatchJson(
    Map<String, dynamic> batchJson,
  ) {
    final raw = batchJson['status_detail'];
    if (raw is Map) {
      return AdminProgressBatchStatusDetail(
        workStatus: raw['work_status']?.toString() ?? '',
        wipStatus: raw['wip_status']?.toString() ?? '',
        flowStatus: raw['flow_status']?.toString() ?? '',
        stockStatus: raw['stock_status']?.toString() ?? '',
      );
    }
    final batchStatus = batchJson['status']?.toString().trim() ?? '';
    final action = batchJson['action']?.toString().trim() ?? '';
    final wipStatus = batchJson['wip_status']?.toString().trim() ?? '';
    final nextApparatus = batchJson['next_apparatus']?.toString().trim() ?? '';
    final processedBy =
        batchJson['processed_by_apparatus']?.toString().trim() ?? '';
    final workStatus = switch (batchStatus) {
      'paused' => 'paused',
      'roll_detached' => 'roll_detached',
      'resumed' => 'in_progress',
      'completed' => 'completed',
      _ => batchStatus,
    };
    final isFinalOutput = adminProgressBatchIsFinishedGoodsOutput(
      action: action,
      status: batchStatus,
      nextApparatus: nextApparatus,
    );
    final flowStatus = switch (wipStatus) {
      'waiting' when isFinalOutput => 'free_wip',
      'waiting' => 'waiting_next_stage',
      'in_use' => 'in_progress',
      'processed' when processedBy.toLowerCase().startsWith('warehouse:') =>
        'accepted_to_stock',
      'processed' => 'consumed_by_next_stage',
      _ => '',
    };
    final stockStatus = switch (flowStatus) {
      'accepted_to_stock' => 'accepted',
      _ => '',
    };
    return AdminProgressBatchStatusDetail(
      workStatus: workStatus,
      wipStatus: wipStatus,
      flowStatus: flowStatus,
      stockStatus: stockStatus,
    );
  }
}

bool adminProgressBatchIsFinishedGoodsOutput({
  required String action,
  required String status,
  required String nextApparatus,
}) {
  if (nextApparatus.trim().isNotEmpty) return false;
  final normalizedAction = action.trim();
  final normalizedStatus = status.trim();
  if (normalizedAction == 'pause') {
    return normalizedStatus == 'paused' || normalizedStatus == 'resumed';
  }
  if (normalizedAction == 'detach_roll') {
    return normalizedStatus == 'roll_detached' || normalizedStatus == 'resumed';
  }
  return (normalizedAction == 'roll_complete' ||
          normalizedAction == 'complete') &&
      normalizedStatus == 'completed';
}

class AdminProductionOrderStatusDetail {
  const AdminProductionOrderStatusDetail({
    this.orderStatus = '',
    this.workStatus = '',
    this.flowStatus = '',
    this.stockStatus = '',
    this.totalWipCount = 0,
    this.waitingWipCount = 0,
    this.inUseWipCount = 0,
    this.processedWipCount = 0,
    this.waitingNextStageCount = 0,
    this.consumedByNextStageCount = 0,
    this.freeWipCount = 0,
    this.acceptedWipCount = 0,
    this.activeSessionCount = 0,
    this.pausedSessionCount = 0,
    this.rollDetachedSessionCount = 0,
    this.completedQueueCount = 0,
    this.completedWithIssueCount = 0,
  });

  final String orderStatus;
  final String workStatus;
  final String flowStatus;
  final String stockStatus;
  final int totalWipCount;
  final int waitingWipCount;
  final int inUseWipCount;
  final int processedWipCount;
  final int waitingNextStageCount;
  final int consumedByNextStageCount;
  final int freeWipCount;
  final int acceptedWipCount;
  final int activeSessionCount;
  final int pausedSessionCount;
  final int rollDetachedSessionCount;
  final int completedQueueCount;
  final int completedWithIssueCount;

  factory AdminProductionOrderStatusDetail.fromJson(Object? raw) {
    if (raw is! Map) {
      return const AdminProductionOrderStatusDetail();
    }
    final json = raw.cast<String, dynamic>();
    return AdminProductionOrderStatusDetail(
      orderStatus: json['order_status']?.toString() ?? '',
      workStatus: json['work_status']?.toString() ?? '',
      flowStatus: json['flow_status']?.toString() ?? '',
      stockStatus: json['stock_status']?.toString() ?? '',
      totalWipCount: (json['total_wip_count'] as num?)?.toInt() ?? 0,
      waitingWipCount: (json['waiting_wip_count'] as num?)?.toInt() ?? 0,
      inUseWipCount: (json['in_use_wip_count'] as num?)?.toInt() ?? 0,
      processedWipCount: (json['processed_wip_count'] as num?)?.toInt() ?? 0,
      waitingNextStageCount:
          (json['waiting_next_stage_count'] as num?)?.toInt() ?? 0,
      consumedByNextStageCount:
          (json['consumed_by_next_stage_count'] as num?)?.toInt() ?? 0,
      freeWipCount: (json['free_wip_count'] as num?)?.toInt() ??
          (json['finished_pending_acceptance_count'] as num?)?.toInt() ??
          0,
      acceptedWipCount: (json['accepted_wip_count'] as num?)?.toInt() ?? 0,
      activeSessionCount: (json['active_session_count'] as num?)?.toInt() ?? 0,
      pausedSessionCount: (json['paused_session_count'] as num?)?.toInt() ?? 0,
      rollDetachedSessionCount:
          (json['roll_detached_session_count'] as num?)?.toInt() ?? 0,
      completedQueueCount:
          (json['completed_queue_count'] as num?)?.toInt() ?? 0,
      completedWithIssueCount:
          (json['completed_with_issue_count'] as num?)?.toInt() ?? 0,
    );
  }

  AdminProductionOrderStatusDetail copyWith({
    String? orderStatus,
    String? workStatus,
    String? flowStatus,
  }) {
    return AdminProductionOrderStatusDetail(
      orderStatus: orderStatus ?? this.orderStatus,
      workStatus: workStatus ?? this.workStatus,
      flowStatus: flowStatus ?? this.flowStatus,
      stockStatus: stockStatus,
      totalWipCount: totalWipCount,
      waitingWipCount: waitingWipCount,
      inUseWipCount: inUseWipCount,
      processedWipCount: processedWipCount,
      waitingNextStageCount: waitingNextStageCount,
      consumedByNextStageCount: consumedByNextStageCount,
      freeWipCount: freeWipCount,
      acceptedWipCount: acceptedWipCount,
      activeSessionCount: activeSessionCount,
      pausedSessionCount: pausedSessionCount,
      rollDetachedSessionCount: rollDetachedSessionCount,
      completedQueueCount: completedQueueCount,
      completedWithIssueCount: completedWithIssueCount,
    );
  }
}

class AdminWorkerRunSession {
  const AdminWorkerRunSession({
    required this.sessionId,
    required this.apparatus,
    required this.orderId,
    required this.status,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    required this.startedAtUnix,
    required this.updatedAtUnix,
    this.payloadJson = const {},
  });

  final String sessionId;
  final String apparatus;
  final String orderId;
  final String status;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final int startedAtUnix;
  final int updatedAtUnix;
  final Map<String, dynamic> payloadJson;

  factory AdminWorkerRunSession.fromJson(Map<String, dynamic> json) {
    return AdminWorkerRunSession(
      sessionId: json['session_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
      payloadJson: _jsonObject(json['payload_json']),
    );
  }
}

class AdminProgressQrOpenedBy {
  const AdminProgressQrOpenedBy({
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.openedAtUnix,
  });

  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final int openedAtUnix;

  factory AdminProgressQrOpenedBy.fromJson(Map<String, dynamic> json) {
    return AdminProgressQrOpenedBy(
      actorRole: json['actor_role']?.toString() ?? '',
      actorRef: json['actor_ref']?.toString() ?? '',
      actorDisplayName: json['actor_display_name']?.toString() ?? '',
      openedAtUnix: (json['opened_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProgressQrReport {
  const AdminProgressQrReport({
    required this.scannedBatch,
    required this.isStale,
    required this.staleReason,
    required this.queueStates,
    required this.logs,
    required this.progressBatches,
    required this.runSessions,
    required this.activeSessions,
    this.corrections = const [],
    this.currentBatch,
    this.order,
    this.orderStatus = const AdminProductionOrderStatusDetail(),
    this.openedBy,
  });

  final AdminProgressBatch scannedBatch;
  final AdminProgressBatch? currentBatch;
  final bool isStale;
  final String staleReason;
  final ProductionMapDefinition? order;
  final AdminProductionOrderStatusDetail orderStatus;
  final Map<String, Map<String, String>> queueStates;
  final List<AdminProductionOrderLogEntry> logs;
  final List<AdminProgressBatchCorrectionRecord> corrections;
  final List<AdminProgressBatch> progressBatches;
  final List<AdminWorkerRunSession> runSessions;
  final List<AdminWorkerRunSession> activeSessions;
  final AdminProgressQrOpenedBy? openedBy;

  factory AdminProgressQrReport.fromJson(Map<String, dynamic> json) {
    final scannedRaw = json['scanned_batch'];
    if (scannedRaw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    final currentRaw = json['current_batch'];
    final orderRaw = json['order'];
    final openedRaw = json['opened_by'];
    return AdminProgressQrReport(
      scannedBatch: AdminProgressBatch.fromJson(
        scannedRaw.cast<String, dynamic>(),
      ),
      currentBatch: currentRaw is Map
          ? AdminProgressBatch.fromJson(currentRaw.cast<String, dynamic>())
          : null,
      isStale: json['is_stale'] == true,
      staleReason: json['stale_reason']?.toString() ?? '',
      order: orderRaw is Map
          ? ProductionMapDefinition.fromJson(orderRaw.cast<String, dynamic>())
          : null,
      orderStatus: AdminProductionOrderStatusDetail.fromJson(
        json['order_status'],
      ),
      queueStates: MobileApi.instance.parseApparatusQueueStateMap(
        json['queue_states'],
      ),
      logs: [
        for (final item in (json['logs'] as List? ?? const []))
          AdminProductionOrderLogEntry.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      corrections: [
        for (final item in (json['corrections'] as List? ?? const []))
          AdminProgressBatchCorrectionRecord.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      progressBatches: [
        for (final item in (json['progress_batches'] as List? ?? const []))
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
      ],
      runSessions: [
        for (final item in (json['run_sessions'] as List? ?? const []))
          AdminWorkerRunSession.fromJson((item as Map).cast<String, dynamic>()),
      ],
      activeSessions: [
        for (final item in (json['active_sessions'] as List? ?? const []))
          AdminWorkerRunSession.fromJson((item as Map).cast<String, dynamic>()),
      ],
      openedBy: openedRaw is Map
          ? AdminProgressQrOpenedBy.fromJson(openedRaw.cast<String, dynamic>())
          : null,
    );
  }
}

Map<String, dynamic> _jsonObject(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  return {for (final entry in raw.entries) entry.key.toString(): entry.value};
}

Map<String, String> _stringMapOfStrings(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  return {
    for (final entry in raw.entries)
      if (entry.key.toString().trim().isNotEmpty &&
          entry.value.toString().trim().isNotEmpty)
        entry.key.toString().trim(): entry.value.toString().trim(),
  };
}

class AdminWorkerProfileDetail {
  const AdminWorkerProfileDetail({
    required this.worker,
    this.assignedApparatus = const [],
    required this.assignedGroups,
    required this.activeSessions,
    required this.recentBatches,
    required this.recentLogs,
  });

  final AdminWorkerDetail worker;
  final List<String> assignedApparatus;
  final List<AdminWorkerGroup> assignedGroups;
  final List<AdminWorkerRunSession> activeSessions;
  final List<AdminProgressBatch> recentBatches;
  final List<AdminProductionOrderLogEntry> recentLogs;

  factory AdminWorkerProfileDetail.fromJson(Map<String, dynamic> json) {
    return AdminWorkerProfileDetail(
      worker: AdminWorkerDetail.fromJson(
        (json['worker'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      assignedApparatus: _requireCanonicalApparatusIdList(
        json['assigned_apparatus'],
      ),
      assignedGroups: [
        for (final item in (json['assigned_groups'] as List? ?? const []))
          AdminWorkerGroup.fromJson((item as Map).cast<String, dynamic>()),
      ],
      activeSessions: [
        for (final item in (json['active_sessions'] as List? ?? const []))
          AdminWorkerRunSession.fromJson((item as Map).cast<String, dynamic>()),
      ],
      recentBatches: [
        for (final item in (json['recent_batches'] as List? ?? const []))
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
      ],
      recentLogs: [
        for (final item in (json['recent_logs'] as List? ?? const []))
          AdminProductionOrderLogEntry.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
    );
  }
}

class AdminWorkerDeletionDependency {
  const AdminWorkerDeletionDependency({
    required this.kind,
    required this.label,
    required this.apparatus,
    required this.orderId,
    required this.status,
  });

  final String kind;
  final String label;
  final String apparatus;
  final String orderId;
  final String status;

  factory AdminWorkerDeletionDependency.fromJson(Map<String, dynamic> json) {
    return AdminWorkerDeletionDependency(
      kind: json['kind']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      orderId: json['order_id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}

class AdminWorkerDeletionCheck {
  const AdminWorkerDeletionCheck({
    required this.workerId,
    required this.workerName,
    required this.blocked,
    required this.requiresConfirmation,
    required this.activeWork,
    required this.connections,
  });

  final String workerId;
  final String workerName;
  final bool blocked;
  final bool requiresConfirmation;
  final List<AdminWorkerDeletionDependency> activeWork;
  final List<AdminWorkerDeletionDependency> connections;

  factory AdminWorkerDeletionCheck.fromJson(Map<String, dynamic> json) {
    return AdminWorkerDeletionCheck(
      workerId: json['worker_id']?.toString() ?? '',
      workerName: json['worker_name']?.toString() ?? '',
      blocked: json['blocked'] == true,
      requiresConfirmation: json['requires_confirmation'] == true,
      activeWork: [
        for (final item in (json['active_work'] as List? ?? const []))
          AdminWorkerDeletionDependency.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      connections: [
        for (final item in (json['connections'] as List? ?? const []))
          AdminWorkerDeletionDependency.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
    );
  }
}

class AdminWorkerDeletionRejected implements Exception {
  const AdminWorkerDeletionRejected(this.check);

  final AdminWorkerDeletionCheck check;

  @override
  String toString() => check.blocked
      ? 'Ishchining faol ishi mavjud'
      : 'Mavjud ulanishlarni tasdiqlash kerak';
}

class AdminServerMonitorBackupFile {
  const AdminServerMonitorBackupFile({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.modifiedAtUnix,
    required this.ageSeconds,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final int modifiedAtUnix;
  final int ageSeconds;

  factory AdminServerMonitorBackupFile.fromJson(Map<String, dynamic> json) {
    return AdminServerMonitorBackupFile(
      name: json['name']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      modifiedAtUnix: (json['modified_at_unix'] as num?)?.toInt() ?? 0,
      ageSeconds: (json['age_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminServerMonitorBackupSnapshot {
  const AdminServerMonitorBackupSnapshot({
    required this.id,
    required this.status,
    required this.source,
    required this.requestedBy,
    required this.createdAtUnix,
    required this.startedAtUnix,
    required this.completedAtUnix,
    required this.sizeBytes,
    required this.artifactName,
    required this.checksumSha256,
    required this.verified,
    required this.error,
  });

  final String id;
  final String status;
  final String source;
  final String requestedBy;
  final int createdAtUnix;
  final int startedAtUnix;
  final int completedAtUnix;
  final int sizeBytes;
  final String artifactName;
  final String checksumSha256;
  final bool verified;
  final String error;

  bool get ready => status == 'ready' && verified;
  bool get running =>
      status == 'queued' || status == 'running' || status == 'verifying';

  factory AdminServerMonitorBackupSnapshot.fromJson(Map<String, dynamic> json) {
    return AdminServerMonitorBackupSnapshot(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      requestedBy: json['requested_by']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      artifactName: json['artifact_name']?.toString() ?? '',
      checksumSha256: json['checksum_sha256']?.toString() ?? '',
      verified: json['verified'] == true,
      error: json['error']?.toString() ?? '',
    );
  }
}

class AdminServerMonitorBackups {
  const AdminServerMonitorBackups({
    required this.directory,
    required this.exists,
    required this.fileCount,
    required this.latest,
    required this.files,
    required this.error,
    this.snapshotCount = 0,
    this.latestSnapshot,
    this.snapshots = const [],
    this.activeJob,
    this.healthy = false,
  });

  final String directory;
  final bool exists;
  final int fileCount;
  final AdminServerMonitorBackupFile? latest;
  final List<AdminServerMonitorBackupFile> files;
  final String error;
  final int snapshotCount;
  final AdminServerMonitorBackupSnapshot? latestSnapshot;
  final List<AdminServerMonitorBackupSnapshot> snapshots;
  final AdminServerMonitorBackupSnapshot? activeJob;
  final bool healthy;

  factory AdminServerMonitorBackups.fromJson(Map<String, dynamic> json) {
    final latestRaw = json['latest'];
    final latestSnapshotRaw = json['latest_snapshot'];
    final activeJobRaw = json['active_job'];
    final snapshots = [
      for (final item in (json['snapshots'] as List? ?? const []))
        AdminServerMonitorBackupSnapshot.fromJson(
          (item as Map).cast<String, dynamic>(),
        ),
    ];
    return AdminServerMonitorBackups(
      directory: json['directory']?.toString() ?? '',
      exists: json['exists'] == true,
      fileCount: (json['file_count'] as num?)?.toInt() ?? 0,
      latest: latestRaw is Map
          ? AdminServerMonitorBackupFile.fromJson(
              latestRaw.cast<String, dynamic>(),
            )
          : null,
      files: [
        for (final item in (json['files'] as List? ?? const []))
          AdminServerMonitorBackupFile.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      error: json['error']?.toString() ?? '',
      snapshotCount:
          (json['snapshot_count'] as num?)?.toInt() ?? snapshots.length,
      latestSnapshot: latestSnapshotRaw is Map
          ? AdminServerMonitorBackupSnapshot.fromJson(
              latestSnapshotRaw.cast<String, dynamic>(),
            )
          : null,
      snapshots: snapshots,
      activeJob: activeJobRaw is Map
          ? AdminServerMonitorBackupSnapshot.fromJson(
              activeJobRaw.cast<String, dynamic>(),
            )
          : null,
      healthy: json.containsKey('healthy')
          ? json['healthy'] == true
          : ((json['file_count'] as num?)?.toInt() ?? 0) > 0,
    );
  }
}

class AdminBackupDownload {
  const AdminBackupDownload({
    required this.filename,
    required this.contentType,
    required this.contentLength,
    required this.stream,
  });

  final String filename;
  final String contentType;
  final int contentLength;
  final Stream<List<int>> stream;
}

class AdminServerMonitorDatabase {
  const AdminServerMonitorDatabase({
    required this.configured,
    required this.reachable,
    required this.status,
    required this.pingMs,
    required this.error,
  });

  final bool configured;
  final bool reachable;
  final String status;
  final int pingMs;
  final String error;

  factory AdminServerMonitorDatabase.fromJson(Map<String, dynamic> json) {
    return AdminServerMonitorDatabase(
      configured: json['configured'] == true,
      reachable: json['reachable'] == true,
      status: json['status']?.toString() ?? '',
      pingMs: (json['ping_ms'] as num?)?.toInt() ?? 0,
      error: json['error']?.toString() ?? '',
    );
  }
}

class AdminServerMonitorServer {
  const AdminServerMonitorServer({
    required this.bindAddr,
    required this.startedAtUnix,
    required this.uptimeSeconds,
    required this.status,
  });

  final String bindAddr;
  final int startedAtUnix;
  final int uptimeSeconds;
  final String status;

  factory AdminServerMonitorServer.fromJson(Map<String, dynamic> json) {
    return AdminServerMonitorServer(
      bindAddr: json['bind_addr']?.toString() ?? '',
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

class AdminServerMonitorRuntime {
  const AdminServerMonitorRuntime({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.memoryUsedMb,
    required this.memoryTotalMb,
    required this.diskPath,
    required this.diskPercent,
    required this.diskUsedMb,
    required this.diskTotalMb,
    required this.diskAvailableMb,
    required this.loadAverage,
    required this.sampleSeconds,
  });

  final int cpuPercent;
  final int memoryPercent;
  final int memoryUsedMb;
  final int memoryTotalMb;
  final String diskPath;
  final int diskPercent;
  final int diskUsedMb;
  final int diskTotalMb;
  final int diskAvailableMb;
  final double loadAverage;
  final int sampleSeconds;

  factory AdminServerMonitorRuntime.fromJson(Map<String, dynamic> json) {
    return AdminServerMonitorRuntime(
      cpuPercent: (json['cpu_percent'] as num?)?.round() ?? 0,
      memoryPercent: (json['memory_percent'] as num?)?.round() ?? 0,
      memoryUsedMb: (json['memory_used_mb'] as num?)?.round() ?? 0,
      memoryTotalMb: (json['memory_total_mb'] as num?)?.round() ?? 0,
      diskPath: json['disk_path']?.toString() ?? '',
      diskPercent: (json['disk_percent'] as num?)?.round() ?? 0,
      diskUsedMb: (json['disk_used_mb'] as num?)?.round() ?? 0,
      diskTotalMb: (json['disk_total_mb'] as num?)?.round() ?? 0,
      diskAvailableMb: (json['disk_available_mb'] as num?)?.round() ?? 0,
      loadAverage: (json['load_average'] as num?)?.toDouble() ?? 0,
      sampleSeconds: (json['sample_seconds'] as num?)?.round() ?? 0,
    );
  }
}

class AdminServerMonitorReport {
  const AdminServerMonitorReport({
    required this.server,
    required this.database,
    required this.backups,
    required this.runtime,
  });

  final AdminServerMonitorServer server;
  final AdminServerMonitorDatabase database;
  final AdminServerMonitorBackups backups;
  final AdminServerMonitorRuntime runtime;

  factory AdminServerMonitorReport.fromJson(Map<String, dynamic> json) {
    return AdminServerMonitorReport(
      server: AdminServerMonitorServer.fromJson(
        (json['server'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      database: AdminServerMonitorDatabase.fromJson(
        (json['database'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      backups: AdminServerMonitorBackups.fromJson(
        (json['backups'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
      runtime: AdminServerMonitorRuntime.fromJson(
        (json['runtime'] as Map? ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}

class AdminServerMonitorLiveEvent {
  const AdminServerMonitorLiveEvent({this.report, this.latencyMs});

  final AdminServerMonitorReport? report;
  final int? latencyMs;

  factory AdminServerMonitorLiveEvent.fromJson(
    Map<String, dynamic> json, {
    int Function()? nowMs,
  }) {
    if (json['ok'] == true) {
      return AdminServerMonitorLiveEvent(
        report: AdminServerMonitorReport.fromJson(json),
      );
    }
    if (json['type'] == 'pong') {
      final sentAt = (json['sent_at_ms'] as num?)?.toInt();
      if (sentAt != null && sentAt > 0) {
        final now = nowMs?.call() ?? DateTime.now().millisecondsSinceEpoch;
        final latency = now - sentAt;
        return AdminServerMonitorLiveEvent(
          latencyMs: latency <= 0 ? 1 : latency,
        );
      }
    }
    return const AdminServerMonitorLiveEvent();
  }
}

class AdminProductionMapRequiredQolip {
  const AdminProductionMapRequiredQolip({
    required this.qolipCode,
    required this.color,
    this.isInUse = false,
  });

  final String qolipCode;
  final String color;
  final bool isInUse;

  factory AdminProductionMapRequiredQolip.fromJson(Map<String, dynamic> json) {
    return AdminProductionMapRequiredQolip(
      qolipCode: json['qolip_code']?.toString().trim() ?? '',
      color: json['color']?.toString().trim() ?? '',
      isInUse: json['in_use'] == true,
    );
  }
}

class AdminProductionMapQolipValidation {
  const AdminProductionMapQolipValidation({
    required this.qolipCode,
    this.requiredQolips = const [],
  });

  final String qolipCode;
  final List<AdminProductionMapRequiredQolip> requiredQolips;

  List<String> get requiredQolipCodes => [
        for (final qolip in requiredQolips) qolip.qolipCode,
      ];

  factory AdminProductionMapQolipValidation.fromJson(
    Map<String, dynamic> json,
  ) {
    final requiredQolips = <AdminProductionMapRequiredQolip>[];
    for (final rawQolip in json['required_qolips'] as List? ?? const []) {
      if (rawQolip is! Map) {
        continue;
      }
      final qolip = AdminProductionMapRequiredQolip.fromJson(
        rawQolip.cast<String, dynamic>(),
      );
      if (qolip.qolipCode.isNotEmpty) {
        requiredQolips.add(qolip);
      }
    }
    return AdminProductionMapQolipValidation(
      qolipCode: json['qolip_code']?.toString().trim() ?? '',
      requiredQolips: requiredQolips,
    );
  }
}

class AdminApparatusQueueActionResult {
  const AdminApparatusQueueActionResult({
    required this.states,
    this.orderStatus = const AdminProductionOrderStatusDetail(),
    this.orderControl,
    this.progressBatch,
    this.progressBatches = const [],
    this.completionRequest,
    this.printJob,
    this.printJobs = const [],
  });

  final Map<String, String> states;
  final AdminProductionOrderStatusDetail orderStatus;
  final AdminOrderControlState? orderControl;
  final AdminProgressBatch? progressBatch;
  final List<AdminProgressBatch> progressBatches;
  final AdminCompletionRequestNotification? completionRequest;
  final UsbRpsPrintRequest? printJob;
  final List<UsbRpsPrintRequest> printJobs;
}

enum ApparatusQueuePolicy {
  strictSequence('strict_sequence'),
  freePick('free_pick');

  const ApparatusQueuePolicy(this.apiValue);

  final String apiValue;

  static ApparatusQueuePolicy fromRaw(Object? raw) {
    return switch (raw?.toString().trim()) {
      'free_pick' => ApparatusQueuePolicy.freePick,
      _ => ApparatusQueuePolicy.strictSequence,
    };
  }
}

class AdminApparatusQueuePolicy {
  const AdminApparatusQueuePolicy({
    required this.apparatus,
    required this.policy,
    this.apparatusId = '',
    this.sourceRevision = 0,
    this.sourceAasxSha256 = '',
    this.locked = false,
    this.reason = '',
  });

  final String apparatusId;
  final String apparatus;
  final int sourceRevision;
  final String sourceAasxSha256;
  final ApparatusQueuePolicy policy;
  final bool locked;
  final String reason;

  factory AdminApparatusQueuePolicy.fromJson(Map<String, dynamic> json) {
    return AdminApparatusQueuePolicy(
      apparatusId: _requireCanonicalApparatusId(
        json['apparatus_id']?.toString() ?? '',
      ),
      apparatus: json['apparatus']?.toString() ?? '',
      sourceRevision: (json['source_revision'] as num?)?.toInt() ?? 0,
      sourceAasxSha256: json['source_aasx_sha256']?.toString().trim() ?? '',
      policy: ApparatusQueuePolicy.fromRaw(
        json['discipline'] ?? json['policy'],
      ),
      locked: json['locked'] == true,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'apparatus_id': apparatusId,
        'apparatus': apparatus,
        'source_revision': sourceRevision,
        'source_aasx_sha256': sourceAasxSha256,
        'discipline': policy.apiValue,
        'locked': locked,
        'reason': reason,
      };
}

enum AdminRawMaterialStartPolicy {
  stateAll,
  requirementGroups;

  String get apiValue => switch (this) {
        AdminRawMaterialStartPolicy.stateAll => 'state_all',
        AdminRawMaterialStartPolicy.requirementGroups => 'requirement_groups',
      };

  static AdminRawMaterialStartPolicy fromJson(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'requirement_groups' => AdminRawMaterialStartPolicy.requirementGroups,
      _ => AdminRawMaterialStartPolicy.stateAll,
    };
  }
}

class AdminRawMaterialRequirementGroup {
  const AdminRawMaterialRequirementGroup({
    required this.name,
    required this.itemGroups,
    this.minRequiredCount = 1,
  });

  final String name;
  final List<String> itemGroups;
  final int minRequiredCount;

  factory AdminRawMaterialRequirementGroup.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['item_group_ids'] ?? json['item_groups'];
    return AdminRawMaterialRequirementGroup(
      name: (json['requirement_id'] ?? json['name'])?.toString().trim() ?? '',
      itemGroups: [
        if (rawGroups is List)
          for (final item in rawGroups)
            if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ],
      minRequiredCount: int.tryParse(
            (json['minimum_required_count'] ?? json['min_required_count'])
                    ?.toString() ??
                '',
          ) ??
          1,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'item_groups': [
          for (final item in itemGroups)
            if (item.trim().isNotEmpty) item.trim(),
        ],
        'min_required_count': minRequiredCount < 1 ? 1 : minRequiredCount,
      };
}

class AdminRawMaterialRule {
  const AdminRawMaterialRule({
    required this.apparatusId,
    required this.sourceRevision,
    required this.sourceAasxSha256,
    required this.apparatus,
    required this.requiresMaterial,
    required this.itemGroups,
    this.startPolicy = AdminRawMaterialStartPolicy.stateAll,
    this.requirementGroups = const [],
    this.toolingMode = 'not_required',
    this.toolingClassId = '',
  });

  final String apparatusId;
  final int sourceRevision;
  final String sourceAasxSha256;

  /// Display-only label resolved from the canonical apparatus catalog.
  final String apparatus;
  final bool requiresMaterial;
  final List<String> itemGroups;
  final AdminRawMaterialStartPolicy startPolicy;
  final List<AdminRawMaterialRequirementGroup> requirementGroups;
  final String toolingMode;
  final String toolingClassId;

  AdminRawMaterialRule copyWith({
    String? apparatusId,
    int? sourceRevision,
    String? sourceAasxSha256,
    String? apparatus,
    bool? requiresMaterial,
    List<String>? itemGroups,
    AdminRawMaterialStartPolicy? startPolicy,
    List<AdminRawMaterialRequirementGroup>? requirementGroups,
    String? toolingMode,
    String? toolingClassId,
  }) {
    return AdminRawMaterialRule(
      apparatusId: apparatusId ?? this.apparatusId,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      sourceAasxSha256: sourceAasxSha256 ?? this.sourceAasxSha256,
      apparatus: apparatus ?? this.apparatus,
      requiresMaterial: requiresMaterial ?? this.requiresMaterial,
      itemGroups: itemGroups ?? this.itemGroups,
      startPolicy: startPolicy ?? this.startPolicy,
      requirementGroups: requirementGroups ?? this.requirementGroups,
      toolingMode: toolingMode ?? this.toolingMode,
      toolingClassId: toolingClassId ?? this.toolingClassId,
    );
  }

  factory AdminRawMaterialRule.fromJson(Map<String, dynamic> json) {
    final rawRevision = json['revision'];
    final revision = rawRevision is Map
        ? rawRevision.cast<String, dynamic>()
        : const <String, dynamic>{};
    final rawProjection = json['runtime_projection'];
    final projection =
        rawProjection is Map ? rawProjection.cast<String, dynamic>() : json;
    final rawPolicies = revision['policies'];
    final policies = rawPolicies is Map
        ? rawPolicies.cast<String, dynamic>()
        : const <String, dynamic>{};
    final rawPolicy = policies['material'] ?? projection['policy'];
    final policy = rawPolicy is Map
        ? rawPolicy.cast<String, dynamic>()
        : const <String, dynamic>{};
    final rawTooling = policies['tooling'] ?? projection['tooling'];
    final tooling = rawTooling is Map
        ? rawTooling.cast<String, dynamic>()
        : const <String, dynamic>{};
    final revisionMetadata = revision['revision_metadata'];
    final revisionMetadataMap = revisionMetadata is Map
        ? revisionMetadata.cast<String, dynamic>()
        : const <String, dynamic>{};
    final display = revision['display'];
    final displayMap = display is Map
        ? display.cast<String, dynamic>()
        : const <String, dynamic>{};
    final apparatusId = (projection['apparatus_id'] ?? revision['apparatus_id'])
            ?.toString()
            .trim() ??
        '';
    final sourceAasxSha256 =
        projection['source_aasx_sha256']?.toString().trim() ?? '';
    if (!isCanonicalApparatusId(apparatusId) ||
        !canonicalAasxSha256IsValid(sourceAasxSha256)) {
      throw const FormatException(
        'Canonical raw-material projection requires identity and source hash',
      );
    }
    final sourceRevision = (projection['source_revision'] as num?)?.toInt() ??
        (revisionMetadataMap['revision'] as num?)?.toInt() ??
        0;
    final mode = policy['mode']?.toString().trim().toLowerCase() ?? '';
    if (sourceRevision < 1 ||
        !const {
          'not_required',
          'all_required',
          'requirement_sets',
        }.contains(mode)) {
      throw const FormatException(
        'Canonical raw-material projection has invalid revision or policy',
      );
    }
    final rawGroups = policy['item_group_ids'];
    final rawRequirementGroups = policy['sets'];
    final requirementGroups = [
      if (rawRequirementGroups is List)
        for (final item in rawRequirementGroups)
          if (item is Map)
            AdminRawMaterialRequirementGroup.fromJson(
              item.cast<String, dynamic>(),
            ),
    ];
    final itemGroups = mode == 'requirement_sets'
        ? <String>{
            for (final group in requirementGroups) ...group.itemGroups,
          }.toList(growable: false)
        : [
            if (rawGroups is List)
              for (final item in rawGroups)
                if (item.toString().trim().isNotEmpty) item.toString().trim(),
          ];
    final toolingMode = tooling['mode']?.toString().trim().toLowerCase() ?? '';
    final toolingClassId = tooling['tooling_class_id']?.toString().trim() ?? '';
    if (!const {'not_required', 'qolip_scan_required'}.contains(toolingMode) ||
        (toolingMode == 'qolip_scan_required' && toolingClassId.isEmpty)) {
      throw const FormatException(
        'Canonical raw-material projection has invalid tooling policy',
      );
    }
    return AdminRawMaterialRule(
      apparatusId: apparatusId,
      sourceRevision: sourceRevision,
      sourceAasxSha256: sourceAasxSha256,
      apparatus: displayMap['display_name']?.toString().trim() ?? '',
      requiresMaterial: mode != 'not_required',
      startPolicy: mode == 'requirement_sets'
          ? AdminRawMaterialStartPolicy.requirementGroups
          : AdminRawMaterialStartPolicy.stateAll,
      itemGroups: itemGroups,
      requirementGroups: requirementGroups,
      toolingMode: toolingMode,
      toolingClassId: toolingClassId,
    );
  }

  Map<String, dynamic> materialPolicyJson() {
    final normalizedItemGroups = itemGroups
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (!requiresMaterial) {
      return {
        'mode': 'not_required',
        if (normalizedItemGroups.isNotEmpty)
          'item_group_ids': normalizedItemGroups,
      };
    }
    if (startPolicy == AdminRawMaterialStartPolicy.requirementGroups) {
      return {
        'mode': 'requirement_sets',
        'sets': [
          for (final group in requirementGroups)
            {
              'requirement_id': group.name.trim(),
              'item_group_ids': [
                for (final item in group.itemGroups)
                  if (item.trim().isNotEmpty) item.trim(),
              ],
              'minimum_required_count':
                  group.minRequiredCount < 1 ? 1 : group.minRequiredCount,
            },
        ],
      };
    }
    return {
      'mode': 'all_required',
      'item_group_ids': normalizedItemGroups,
    };
  }

  Map<String, dynamic> toolingPolicyJson() {
    if (toolingMode == 'qolip_scan_required' &&
        toolingClassId.trim().isNotEmpty) {
      return {
        'mode': 'qolip_scan_required',
        'tooling_class_id': toolingClassId.trim(),
      };
    }
    return const {'mode': 'not_required'};
  }
}

class AdminRawMaterialStartRequirements {
  const AdminRawMaterialStartRequirements({
    this.policy = AdminRawMaterialStartPolicy.stateAll,
    this.requiresMaterial = false,
    this.requirementGroups = const [],
    this.assignedBarcodes = const [],
    this.stagedBarcodes = const [],
    this.assignments = const [],
    this.startAssignments = const [],
    this.requiredScanCount = 0,
    this.matchedScanCount = 0,
    this.assignmentsSatisfied = true,
    this.scanSatisfied = false,
  });

  final AdminRawMaterialStartPolicy policy;
  final bool requiresMaterial;
  final List<AdminRawMaterialRequirementGroup> requirementGroups;
  final List<String> assignedBarcodes;
  final List<String> stagedBarcodes;

  /// Every raw material attached to the order, across apparatus.
  final List<AdminRawMaterialAssignment> assignments;

  /// Assignments selected by the backend policy for this apparatus start.
  final List<AdminRawMaterialAssignment> startAssignments;
  final int requiredScanCount;
  final int matchedScanCount;
  final bool assignmentsSatisfied;
  final bool scanSatisfied;

  factory AdminRawMaterialStartRequirements.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawRequirementGroups = json['requirement_groups'];
    final rawAssignedBarcodes = json['assigned_barcodes'];
    final rawStagedBarcodes = json['staged_barcodes'];
    final rawAssignments = json['assignments'];
    final rawStartAssignments = json['start_assignments'];
    return AdminRawMaterialStartRequirements(
      policy: AdminRawMaterialStartPolicy.fromJson(json['policy']),
      requiresMaterial: json['requires_material'] == true,
      requirementGroups: [
        if (rawRequirementGroups is List)
          for (final item in rawRequirementGroups)
            if (item is Map)
              AdminRawMaterialRequirementGroup.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
      assignedBarcodes: _normalizedRawMaterialBarcodeList(rawAssignedBarcodes),
      stagedBarcodes: _normalizedRawMaterialBarcodeList(rawStagedBarcodes),
      assignments: [
        if (rawAssignments is List)
          for (final item in rawAssignments)
            if (item is Map)
              AdminRawMaterialAssignment.fromJson(item.cast<String, dynamic>()),
      ],
      startAssignments: [
        if (rawStartAssignments is List)
          for (final item in rawStartAssignments)
            if (item is Map)
              AdminRawMaterialAssignment.fromJson(item.cast<String, dynamic>()),
      ],
      requiredScanCount:
          int.tryParse(json['required_scan_count']?.toString() ?? '') ?? 0,
      matchedScanCount:
          int.tryParse(json['matched_scan_count']?.toString() ?? '') ?? 0,
      assignmentsSatisfied: json['assignments_satisfied'] == true,
      scanSatisfied: json['scan_satisfied'] == true,
    );
  }

  Set<String> get normalizedAssignedBarcodes =>
      assignedBarcodes.map(_normalizeRawMaterialBarcode).toSet()..remove('');

  Set<String> get normalizedStagedBarcodes =>
      stagedBarcodes.map(_normalizeRawMaterialBarcode).toSet()..remove('');
}

String _normalizeRawMaterialBarcode(String value) => value.trim().toUpperCase();

List<String> _normalizedRawMaterialBarcodeList(Object? raw) {
  if (raw is! List) return const [];
  final seen = <String>{};
  return [
    for (final value in raw)
      if (_normalizeRawMaterialBarcode(value.toString()).isNotEmpty &&
          seen.add(_normalizeRawMaterialBarcode(value.toString())))
        _normalizeRawMaterialBarcode(value.toString()),
  ];
}

InventoryAsset? _testModeRawMaterialAssetAtApparatus({
  required String barcode,
  required String apparatus,
}) {
  final normalizedBarcode = _normalizeRawMaterialBarcode(barcode);
  for (final asset in _testModeInventoryAssets) {
    if (asset.kind != InventoryAssetKind.rawMaterial ||
        _normalizeRawMaterialBarcode(asset.identifier) != normalizedBarcode ||
        asset.physicalLocation.kind != InventoryLocationKind.state) {
      continue;
    }
    for (final location in _testModeInventoryLocations) {
      if (!location.active ||
          !location.isState ||
          location.id != asset.physicalLocation.id) {
        continue;
      }
      if (location.apparatus.any(
        (linked) => linked.id.trim() == apparatus.trim(),
      )) {
        return asset;
      }
    }
  }
  return null;
}

bool _testModeRawMaterialMatchesRule(
  AdminRawMaterialAssignment assignment,
  AdminRawMaterialRule? rule,
) {
  if (rule == null) return true;
  final itemGroup = assignment.itemGroup.trim().toLowerCase();
  if (itemGroup.isEmpty) return false;
  final allowedGroups = <String>{
    for (final group in rule.itemGroups) group.trim().toLowerCase(),
    for (final requirement in rule.requirementGroups)
      for (final group in requirement.itemGroups) group.trim().toLowerCase(),
  }..remove('');
  return allowedGroups.contains(itemGroup);
}

int _testModeMatchedRawMaterialRequirementCount({
  required List<AdminRawMaterialRequirementGroup> requirementGroups,
  required List<AdminRawMaterialAssignment> assignments,
  required Set<String> barcodes,
}) {
  final slots = <List<String>>[
    for (final group in requirementGroups)
      for (var index = 0;
          index < (group.minRequiredCount < 1 ? 1 : group.minRequiredCount);
          index += 1)
        group.itemGroups,
  ];
  final candidates = assignments
      .where(
        (assignment) =>
            barcodes.contains(_normalizeRawMaterialBarcode(assignment.barcode)),
      )
      .toList(growable: false);
  final matchedSlots = List<int?>.filled(slots.length, null);

  bool matchAssignment(int assignmentIndex, List<bool> visited) {
    final itemGroup = candidates[assignmentIndex].itemGroup.trim();
    for (var slotIndex = 0; slotIndex < slots.length; slotIndex += 1) {
      if (visited[slotIndex] ||
          !slots[slotIndex].any(
            (group) => group.trim().toLowerCase() == itemGroup.toLowerCase(),
          )) {
        continue;
      }
      visited[slotIndex] = true;
      final previousAssignment = matchedSlots[slotIndex];
      if (previousAssignment == null ||
          matchAssignment(previousAssignment, visited)) {
        matchedSlots[slotIndex] = assignmentIndex;
        return true;
      }
    }
    return false;
  }

  for (var index = 0; index < candidates.length; index += 1) {
    matchAssignment(index, List<bool>.filled(slots.length, false));
  }
  return matchedSlots.whereType<int>().length;
}

class AdminRawMaterialAssignment {
  const AdminRawMaterialAssignment({
    required this.orderId,
    required this.apparatus,
    required this.barcode,
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    this.assignedByRef = '',
    this.assignedByName = '',
    this.assignedAt = '',
    this.stockStatus = '',
    this.reservedOrderId = '',
    this.stockWarehouse = '',
    this.stockQty = 0,
    this.stockUom = '',
    this.receivedQty = 0,
    this.consumedQty = 0,
    this.remainingQty = 0,
  });

  final String orderId;
  final String apparatus;
  final String barcode;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final String assignedByRef;
  final String assignedByName;
  final String assignedAt;
  final String stockStatus;
  final String reservedOrderId;
  final String stockWarehouse;
  final double stockQty;
  final String stockUom;
  final double receivedQty;
  final double consumedQty;
  final double remainingQty;

  factory AdminRawMaterialAssignment.fromJson(Map<String, dynamic> json) {
    return AdminRawMaterialAssignment(
      orderId: json['order_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      barcode: json['barcode']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      itemGroup: json['item_group']?.toString() ?? '',
      assignedByRef: json['assigned_by_ref']?.toString() ?? '',
      assignedByName: json['assigned_by_display_name']?.toString() ??
          json['assigned_by_name']?.toString() ??
          '',
      assignedAt: json['assigned_at']?.toString() ?? '',
      stockStatus: json['stock_status']?.toString() ?? '',
      reservedOrderId: json['reserved_order_id']?.toString() ?? '',
      stockWarehouse: json['stock_warehouse']?.toString() ?? '',
      stockQty: (json['stock_qty'] as num?)?.toDouble() ?? 0,
      stockUom: json['stock_uom']?.toString() ?? '',
      receivedQty: (json['received_qty'] as num?)?.toDouble() ?? 0,
      consumedQty: (json['consumed_qty'] as num?)?.toDouble() ?? 0,
      remainingQty: (json['remaining_qty'] as num?)?.toDouble() ?? 0,
    );
  }

  AdminRawMaterialAssignment copyWith({
    String? stockStatus,
    String? reservedOrderId,
    String? stockWarehouse,
    double? stockQty,
    String? stockUom,
    double? receivedQty,
    double? consumedQty,
    double? remainingQty,
  }) {
    return AdminRawMaterialAssignment(
      orderId: orderId,
      apparatus: apparatus,
      barcode: barcode,
      itemCode: itemCode,
      itemName: itemName,
      itemGroup: itemGroup,
      assignedByRef: assignedByRef,
      assignedByName: assignedByName,
      assignedAt: assignedAt,
      stockStatus: stockStatus ?? this.stockStatus,
      reservedOrderId: reservedOrderId ?? this.reservedOrderId,
      stockWarehouse: stockWarehouse ?? this.stockWarehouse,
      stockQty: stockQty ?? this.stockQty,
      stockUom: stockUom ?? this.stockUom,
      receivedQty: receivedQty ?? this.receivedQty,
      consumedQty: consumedQty ?? this.consumedQty,
      remainingQty: remainingQty ?? this.remainingQty,
    );
  }
}

class AdminRawMaterialAssignmentCandidate {
  const AdminRawMaterialAssignmentCandidate({
    required this.barcode,
    required this.warehouse,
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    required this.qty,
    required this.uom,
    required this.apparatusOptions,
    this.orderWidthMm,
    this.rollWidthMm,
    this.leftoverWidthMm,
    this.matchType = 'compatible',
  });

  final String barcode;
  final String warehouse;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final double qty;
  final String uom;
  final List<String> apparatusOptions;
  final double? orderWidthMm;
  final double? rollWidthMm;
  final double? leftoverWidthMm;
  final String matchType;

  factory AdminRawMaterialAssignmentCandidate.fromJson(
    Map<String, dynamic> json,
  ) {
    final matchType = json['match_type']?.toString().trim() ?? '';
    return AdminRawMaterialAssignmentCandidate(
      barcode: json['barcode']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      itemGroup: json['item_group']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      apparatusOptions: _requireCanonicalApparatusIdList(
        json['apparatus_options'],
      ),
      orderWidthMm: (json['order_width_mm'] as num?)?.toDouble(),
      rollWidthMm: (json['roll_width_mm'] as num?)?.toDouble(),
      leftoverWidthMm: (json['leftover_width_mm'] as num?)?.toDouble(),
      matchType: matchType.isEmpty ? 'compatible' : matchType,
    );
  }
}

class AdminRawMaterialAssignmentOrderCandidate {
  const AdminRawMaterialAssignmentOrderCandidate({
    required this.order,
    required this.apparatusOptions,
  });

  final ProductionMapSaved order;
  final List<String> apparatusOptions;

  factory AdminRawMaterialAssignmentOrderCandidate.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminRawMaterialAssignmentOrderCandidate(
      order: ProductionMapSaved.fromJson(
        (json['order'] as Map).cast<String, dynamic>(),
      ),
      apparatusOptions: _requireCanonicalApparatusIdList(
        json['apparatus_options'],
      ),
    );
  }
}

class AdminRawMaterialEvent {
  const AdminRawMaterialEvent({
    required this.eventId,
    required this.eventType,
    required this.warehouse,
    required this.barcode,
    required this.itemCode,
    required this.itemName,
    required this.qtyDelta,
    required this.uom,
    required this.stockStatusBefore,
    required this.stockStatusAfter,
    required this.orderId,
    required this.apparatus,
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.ownerRole,
    required this.ownerRef,
    required this.ownerDisplayName,
    required this.sourceType,
    required this.sourceId,
    required this.occurredAtUnix,
    required this.recordedAtUnix,
  });

  final String eventId;
  final String eventType;
  final String warehouse;
  final String barcode;
  final String itemCode;
  final String itemName;
  final double qtyDelta;
  final String uom;
  final String stockStatusBefore;
  final String stockStatusAfter;
  final String orderId;
  final String apparatus;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final String ownerRole;
  final String ownerRef;
  final String ownerDisplayName;
  final String sourceType;
  final String sourceId;
  final int occurredAtUnix;
  final int recordedAtUnix;

  factory AdminRawMaterialEvent.fromJson(Map<String, dynamic> json) {
    return AdminRawMaterialEvent(
      eventId: json['event_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      qtyDelta: (json['qty_delta'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      stockStatusBefore: json['stock_status_before']?.toString() ?? '',
      stockStatusAfter: json['stock_status_after']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      actorRole: json['actor_role']?.toString() ?? '',
      actorRef: json['actor_ref']?.toString() ?? '',
      actorDisplayName: json['actor_display_name']?.toString() ?? '',
      ownerRole: json['owner_role']?.toString() ?? '',
      ownerRef: json['owner_ref']?.toString() ?? '',
      ownerDisplayName: json['owner_display_name']?.toString() ?? '',
      sourceType: json['source_type']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      occurredAtUnix: (json['occurred_at_unix'] as num?)?.toInt() ?? 0,
      recordedAtUnix: (json['recorded_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminRawMaterialLookup {
  const AdminRawMaterialLookup({
    required this.barcode,
    required this.warehouse,
    required this.itemCode,
    required this.itemName,
    required this.itemGroup,
    required this.qty,
    required this.uom,
    this.status = '',
    this.reservedOrderId = '',
    this.sourceReceiptId = '',
    this.assignment,
    this.order,
    this.queueStates = const {},
    this.logs = const [],
  });

  final String barcode;
  final String warehouse;
  final String itemCode;
  final String itemName;
  final String itemGroup;
  final double qty;
  final String uom;
  final String status;
  final String reservedOrderId;
  final String sourceReceiptId;
  final AdminRawMaterialAssignment? assignment;
  final ProductionMapDefinition? order;
  final Map<String, Map<String, String>> queueStates;
  final List<AdminProductionOrderLogEntry> logs;

  factory AdminRawMaterialLookup.fromJson(Map<String, dynamic> json) {
    final assignmentRaw = json['assignment'];
    final orderRaw = json['order'];
    return AdminRawMaterialLookup(
      barcode: json['barcode']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      itemGroup: json['item_group']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      reservedOrderId: json['reserved_order_id']?.toString() ?? '',
      sourceReceiptId: json['source_receipt_id']?.toString() ?? '',
      assignment: assignmentRaw is Map
          ? AdminRawMaterialAssignment.fromJson(
              assignmentRaw.cast<String, dynamic>(),
            )
          : null,
      order: orderRaw is Map
          ? ProductionMapDefinition.fromJson(orderRaw.cast<String, dynamic>())
          : null,
      queueStates: MobileApi.instance.parseApparatusQueueStateMap(
        json['queue_states'],
      ),
      logs: [
        for (final item in (json['logs'] as List? ?? const []))
          AdminProductionOrderLogEntry.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
    );
  }
}

class AdminProductionMapLiveSnapshot {
  const AdminProductionMapLiveSnapshot({
    required this.maps,
    required this.sequences,
    required this.visibleOrderIds,
    required this.queueStates,
    required this.queuePolicies,
    this.queueActionControls = const {},
    required this.completedOrders,
    required this.completionRequests,
    required this.completionRequestDecisions,
    required this.orderControls,
    this.orderCustomers = const {},
    this.orderStatuses = const {},
    this.frozenOrdersByApparatus = const {},
  });

  final List<ProductionMapSaved> maps;
  final Map<String, List<String>> sequences;
  final Map<String, List<String>> visibleOrderIds;
  final Map<String, Map<String, String>> queueStates;
  final Map<String, AdminApparatusQueuePolicy> queuePolicies;
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControls;
  final List<AdminCompletedQueueOrder> completedOrders;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<AdminCompletionRequestDecisionNotification>
      completionRequestDecisions;
  final Map<String, AdminOrderControlState> orderControls;
  final Map<String, String> orderCustomers;
  final Map<String, AdminProductionOrderStatusDetail> orderStatuses;
  final Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus;

  factory AdminProductionMapLiveSnapshot.fromJson(Map<String, dynamic> json) {
    final visibleOrderIds = _parseRequiredProductionMapVisibleOrderIds(json);
    _requireProductionMapSnapshotShape(json, includesMaps: true);
    final mapsRaw = json['maps'];
    final completedRaw = json['completed_orders'];
    final completionRequestsRaw = json['completion_requests'];
    final completionRequestDecisionsRaw = json['completion_request_decisions'];
    final orderControls = _parseAdminOrderControls(json['order_controls']);
    final snapshot = AdminProductionMapLiveSnapshot(
      maps: [
        if (mapsRaw is List)
          for (final item in mapsRaw)
            ProductionMapSaved.fromJson(item as Map<String, dynamic>),
      ],
      sequences: MobileApi.instance.parseApparatusSequenceMap(
        json['sequences'],
      ),
      visibleOrderIds: visibleOrderIds,
      queueStates: MobileApi.instance.parseApparatusQueueStateMap(
        json['queue_states'],
      ),
      queuePolicies: MobileApi.instance.parseApparatusQueuePolicyMap(
        json['queue_policies'],
      ),
      queueActionControls: _parseAdminQueueActionControls(
        json['queue_action_controls'],
      ),
      completedOrders: [
        if (completedRaw is List)
          for (final item in completedRaw)
            AdminCompletedQueueOrder.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      completionRequests: [
        if (completionRequestsRaw is List)
          for (final item in completionRequestsRaw)
            AdminCompletionRequestNotification.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      completionRequestDecisions: [
        if (completionRequestDecisionsRaw is List)
          for (final item in completionRequestDecisionsRaw)
            AdminCompletionRequestDecisionNotification.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
      ],
      orderControls: orderControls,
      orderCustomers: _stringMapOfStrings(json['order_customers']),
      orderStatuses: _parseAdminOrderStatuses(json['order_statuses']),
      frozenOrdersByApparatus: _parseAdminFrozenOrdersByApparatus(
        json['frozen_orders_by_apparatus'],
      ),
    );
    snapshot.validateContract();
    return snapshot;
  }

  void validateContract() {
    _validateProductionMapQueueContract(
      sequences: sequences,
      visibleOrderIds: visibleOrderIds,
      queueStates: queueStates,
      queuePolicies: queuePolicies,
      queueActionControls: queueActionControls,
      frozenOrdersByApparatus: frozenOrdersByApparatus,
    );
  }
}

MobileApiException _adminProductionMapException(
  http.Response response,
  String fallbackCode,
) {
  String code = fallbackCode;
  var apparatusOptions = const <String>[];
  var details = const <String>[];
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
      }
    }
    if (payload is Map && payload['apparatus_options'] is List) {
      apparatusOptions = [
        for (final option in payload['apparatus_options'] as List)
          if (option.toString().trim().isNotEmpty) option.toString().trim(),
      ];
    }
    if (payload is Map && payload['blockers'] is List) {
      details = [
        for (final blocker in payload['blockers'] as List)
          if (blocker is Map &&
              blocker['message']?.toString().trim().isNotEmpty == true)
            blocker['message'].toString().trim(),
      ];
    }
  } catch (_) {}
  return MobileApiException(
    code: code,
    apparatusOptions: apparatusOptions,
    details: details,
    message: switch (code.trim().toLowerCase()) {
      'duplicate_order_number' => 'Bu raqam boshqa zakazga berilgan',
      'order_number_immutable' => 'Zakaz raqamini o‘zgartirish mumkin emas',
      'order_number_exhausted' => 'Zakaz raqamlari limiti tugagan',
      'move_not_allowed' => 'Zakaz bu aparatga tushmaydi',
      'started_order_move_requires_transfer' =>
        'Ish boshlangan orderni avval pause qilib avariyaviy ko‘chiring',
      'production_map_started_stage_locked' =>
        'Ish boshlangan aparat bosqichlarini o‘zgartirib bo‘lmaydi',
      'apparatus_transfer_reason_required' => 'Avariya sababini kiriting',
      'apparatus_transfer_idempotency_required' =>
        'Avariya ko‘chirish identifikatori mavjud emas',
      'apparatus_transfer_idempotency_conflict' =>
        'Avariya ko‘chirish identifikatori boshqa amalda ishlatilgan',
      'apparatus_transfer_order_not_paused' =>
        'Ko‘chirishdan oldin orderni pause qiling',
      'apparatus_transfer_session_not_found' =>
        'Orderning ish sessiyasi topilmadi',
      'apparatus_transfer_progress_not_found' =>
        'Orderning pause progressi topilmadi',
      'apparatus_transfer_session_mismatch' =>
        'Order sessiyasi apparat bilan mos emas',
      'apparatus_transfer_progress_mismatch' =>
        'Order progressi apparat bilan mos emas',
      'apparatus_transfer_target_conflict' =>
        'Order tanlangan apparatda allaqachon mavjud',
      'apparatus_transfer_invalid_response' =>
        'Avariya ko‘chirish javobi noto‘g‘ri',
      'queue_action_not_allowed' =>
        'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
      'order_not_started' => 'Boshlanmagan buyurtmani muzlatib bo‘lmaydi',
      'order_already_completed' => 'Tugallangan buyurtmani muzlatib bo‘lmaydi',
      'order_freeze_requested' =>
        'Buyurtma muzlatish uchun worker pauzasini kutmoqda',
      'order_frozen' => 'Buyurtma muzlatilgan',
      'order_control_action_not_allowed' =>
        'Buyurtmaning hozirgi holatida bu amal mumkin emas',
      'order_delete_blocked' =>
        details.isEmpty ? 'Buyurtmani o‘chirib bo‘lmaydi' : details.join('\n'),
      'order_reset_confirmation_required' => 'Order reset tasdig‘i topilmadi',
      'order_reset_unavailable' => 'Order reset xizmati mavjud emas',
      'order_reset_failed' => 'Orderlar tozalanmadi',
      'order_reset_verification_failed' =>
        'Order reset yakuniy tekshiruvdan o‘tmadi',
      'order_reset_test_mode_unsupported' =>
        'Order reset test rejimida mavjud emas',
      'backup_failed' => 'Resetdan oldingi backup olinmadi',
      'backup_timed_out' => 'Resetdan oldingi backup vaqti tugadi',
      'previous_stage_not_completed' =>
        'Oldingi bosqich tugallanguncha kutilmoqda',
      'apparatus_not_assigned' => 'Bu aparat sizga biriktirilmagan',
      'queue_policy_locked' =>
        'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
      'bosma_completion_metrics_required' =>
        'Bosma tugatish uchun barcha majburiy fieldlarni kiriting',
      'laminatsiya_completion_metrics_required' =>
        'Laminatsiyani tugatish uchun barcha majburiy qiymatlarni kiriting',
      'laminatsiya_astatka_metrics_required' =>
        'Bosmadan, plyonkadan ortgan rulon va chiqindini kiriting',
      'laminatsiya_rubber_too_large' =>
        'Rezina razmeri 1050 mm dan katta bo‘lsa laminatsiya mumkin emas',
      'rezka_progress_metrics_required' =>
        'Rezka uchun barcha majburiy fieldlarni kiriting',
      'rezka_frame_issue_only_on_roll_progress' =>
        'Kadr muammosi faqat Rezka tugatish amalida belgilanadi',
      'rezka_kadr_count_required' =>
        'Rezka uchun kadr soni production mapda sozlanmagan',
      'rezka_final_roll_required' =>
        'Avval qolgan laminatsiya rulonlarini tugating; to‘liq tugatish faqat oxirgi rulonda mumkin',
      'zero_metric_explanation_required' =>
        '0 qiymat kiritilganda sababini yozing',
      'returned_paint_astatka_exceeds_rasxot' =>
        'Astatka Rasxotdan katta bo‘lishi mumkin emas',
      'astatka cannot exceed rasxot' =>
        'Astatka Rasxotdan katta bo‘lishi mumkin emas',
      'raw_material_scan_required' =>
        'Ishni boshlash uchun biriktirilgan homashyoni skaner qiling',
      'raw_material_state_not_ready' =>
        'Apparat oldiga homashyo olib kelinmagan',
      'raw_material_scan_incomplete' =>
        'Apparat oldidagi barcha homashyolarni skaner qiling',
      'raw_material_requirement_not_met' =>
        'Har bir majburiy guruhdan minimum homashyo skaner qiling',
      'raw_material_mismatch' => 'Bu homashyo ish boshlash uchun mos emas',
      'raw_material_stock_unavailable' =>
        'Bu homashyo omborda mavjud emas yoki boshqa zakaz uchun band',
      'raw_material_order_not_active' =>
        'Yana homashyo faqat ish boshlangan yoki pauzadagi zakazga olinadi',
      'qolip_scan_required' => 'Ishni boshlash uchun qolip QR scan qiling',
      'qolip_scan_incomplete' =>
        'Mahsulotga biriktirilgan barcha qoliplarni scan qiling',
      'qolip_code_not_found' => 'Qolip QR topilmadi',
      'qolip_code_mismatch' => 'Bu qolip ushbu zakaz mahsulotiga mos emas',
      'qolip_code_required' => 'Kamida bitta qolipni tanlang',
      'qolip_order_note_not_found' =>
        'Bu order uchun berilgan qolip qaydi topilmadi',
      'qolip_order_note_status_invalid' => 'Qolip qaydi holati noto‘g‘ri',
      'qolip_order_note_in_use' => 'Bu qolip boshqa order uchun band qilingan',
      'qolip_order_note_load_failed' => 'Qolip qaydi yuklanmadi',
      'qolip_order_note_save_failed' => 'Qolip qaydi saqlanmadi',
      'qolip_already_in_use' => 'Bu qolip boshqa aparatda ishlatilmoqda',
      'qolip_location_not_found' => 'Bu qolip hozir ombor yachaykasida emas',
      'insufficient_stock' => 'Bu qolip omborda qolmagan',
      'location_identity_mismatch' =>
        'Qolip joylashuvi o‘zgargan, qayta skanerlang',
      'raw_material_rule_not_found' => 'Bu homashyo uchun aparat qoidasi yo‘q',
      'raw_material_assignment_not_found' => 'Homashyo biriktirilmagan',
      'raw_material_assignment_locked' =>
        'Bu homashyo allaqachon ishga tushgan yoki ishlatilgan, uzib bo‘lmaydi',
      'raw_material_already_assigned' =>
        'Bu homashyo boshqa zakaz uchun band qilingan',
      'raw_material_already_assigned_to_order' =>
        'Bu homashyo allaqachon shu zakazga ulangan',
      'raw_material_group_not_allowed' =>
        'Bu homashyo ish boshlash uchun mos emas',
      'raw_material_group_ambiguous' =>
        'Bu homashyoni qaysi aparatga ulashni tanlang',
      'raw_material_roll_size_missing' => 'Rulon razmeri topilmadi',
      'raw_material_roll_size_mismatch' =>
        'Bu rulon bu buyurtma uchun mos emas',
      'raw_material_invalid_input' => 'Homashyo QR noto‘g‘ri',
      'item group is not assigned to material taminotchi' =>
        'Bu homashyo sizga biriktirilgan guruhlarga kirmaydi',
      'progress_input_invalid' => 'Chiqarilgan miqdorni kiriting',
      'progress_qr_required' => 'Oldingi bosqich QR sini scan qiling',
      'training_input_batch_required' =>
        'Avval admin training batch QR sini generatsiya qilishi kerak',
      'training_input_batch_not_found' => 'Training batch topilmadi',
      'progress_batch_not_found' => 'Progress QR topilmadi',
      'progress_batch_not_accepted' =>
        'Bu QR oldingi bosqich mahsulotiga mos emas',
      'progress_batch_not_resumable' =>
        'Bu progress QR davom ettirishga yaramaydi',
      'progress_batch_correction_reason_required' =>
        'O‘zgartirish sababini yozing',
      'progress_batch_correction_locked' =>
        'Ishlatilgan WIPni o‘zgartirib bo‘lmaydi',
      'progress_batch_correction_conflict' =>
        'WIP boshqa joyda yangilangan. Ma’lumotni qayta oching',
      'progress_batch_correction_unchanged' =>
        'WIP qiymatlarida o‘zgarish yo‘q',
      'paddon_invalid_input' => 'Paddon ma’lumoti noto‘g‘ri',
      'paddon_code_exhausted' => 'Paddon code raqamlari tugagan',
      'paddon_not_found' => 'Paddon topilmadi',
      'paddon_item_already_assigned' => 'Bu WIP boshqa paddonga biriktirilgan',
      'paddon_item_not_assigned' => 'Bu WIP ushbu paddonda yo‘q',
      'scale_driver_not_configured' => 'Printer ulanmagan',
      'unauthorized' => 'Sessiya tugagan. Qayta login qiling',
      'forbidden' => 'Bu amal sizning rolingiz uchun ruxsat etilmagan',
      'method not allowed' => 'Bu amal bu usulda qo‘llanmaydi',
      'invalid json' => 'Yuborilgan ma’lumot noto‘g‘ri',
      'production maps fetch failed' => 'Production maplar yuklanmadi',
      'training_order_number_exists' =>
        'Bu training order raqami allaqachon mavjud',
      'training_material_assignment_exists' =>
        'Bu QR kodi shu training orderga allaqachon ulangan',
      'training_material_assignment_not_found' => 'Training homashyo topilmadi',
      'training_material_assignment_required' => 'Training homashyo tanlanmadi',
      'training_order_not_found' => 'Tanlangan training order topilmadi',
      'training_map_not_found' => 'Training order topilmadi',
      'training_apparatus_required' => 'Training aparat tanlanmadi',
      'training_apparatus_not_found' => 'Training aparat topilmadi',
      'map_id_required' =>
        'Production map yoki aparat canonical ID si topilmadi',
      'map_product_code_required' => 'Mahsulot kodi kiritilmagan',
      'map_title_required' => 'Production map nomi kiritilmagan',
      'map_start_required' =>
        'Production mapda boshlang‘ich nuqta bo‘lishi kerak',
      'map_end_required' => 'Production mapda yakuniy nuqta bo‘lishi kerak',
      'duplicate_node_id' => 'Production mapda node ID takrorlangan',
      'missing_edge_node' => 'Production mapdagi bog‘lanish nuqtasi topilmadi',
      'production_map_cycle' => 'Production map ketma-ketligida aylanish bor',
      'formula_target_required' => 'Formula maqsadi kiritilmagan',
      'formula_expression_required' => 'Formula ifodasi kiritilmagan',
      'invalid_formula_target' => 'Formula maqsadi noto‘g‘ri',
      'invalid_formula_expression' => 'Formula ifodasi noto‘g‘ri',
      'invalid_order_qty' => 'Zakaz miqdori 0 dan katta bo‘lishi kerak',
      'invalid_node_qty' => 'Bosqich miqdori noto‘g‘ri',
      'invalid_location' => 'Joylashuv noto‘g‘ri',
      'unknown_formula_variable' => 'Formula ichidagi o‘zgaruvchi topilmadi',
      'formula_division_by_zero' => 'Formula 0 ga bo‘lishni o‘z ichiga oladi',
      'condition_branch_required' =>
        'Shart uchun true va false yo‘nalishlari kerak',
      'order_freeze_target_not_found' =>
        'Buyurtmani muzlatish uchun faol ish sessiyasi topilmadi',
      'order_freeze_target_ambiguous' =>
        'Buyurtmani muzlatish uchun bir nechta faol sessiya topildi',
      'order_freeze_request_mismatch' =>
        'Muzlatish so‘rovi bu ish sessiyasiga tegishli emas',
      'freeze_safe_stop_output_or_issue_note_required' =>
        'Miqdorlarni to‘liq kiriting yoki faqat muammo izohini yozing',
      'freeze_safe_stop_output_incomplete' =>
        'Miqdorlar to‘liq emas. Barcha majburiy qiymatlarni kiriting yoki maydonlarni tozalab, faqat muammo izohini yozing',
      'store_failed' ||
      'production_map_store_failed' =>
        fallbackCode == 'production_map_sequence'
            ? 'Ish rejasi navbati serverdan yuklanmadi'
            : 'Production map ma’lumotlarini saqlashda server xatosi',
      'training workspace store failed' =>
        'Training server bazasi yangilanmagan yoki ulanmagan. Serverni restart qiling',
      'capacity_profile_invalid' => 'Aparat quvvati profili noto‘g‘ri',
      'capacity_profile_not_found' => 'Aparat quvvati profili topilmadi',
      'capability_not_supported' => 'Bu aparat kerakli ish turini qo‘llamaydi',
      'capability_level_insufficient' =>
        'Bu aparatning imkoniyat darajasi yetarli emas',
      'capacity_conflict' => 'Bu aparatning quvvati tanlangan vaqt uchun band',
      'capacity_no_working_window' =>
        'Bu aparat uchun tanlangan vaqt oralig‘ida ish vaqti yo‘q',
      'capacity_unavailable' => 'Bu aparat tanlangan vaqtda ishlamaydi',
      'schedule_input_invalid' => 'Jadval ma’lumotlari noto‘g‘ri',
      'schedule_idempotency_conflict' =>
        'Bu jadval identifikatori boshqa orderga tegishli',
      'schedule_reservation_not_found' => 'Jadval bandlovi topilmadi',
      'schedule_reservation_locked' =>
        'Bu jadval bandlovini bekor qilib bo‘lmaydi',
      'map_not_found' => 'Zakaz topilmadi',
      _ => _adminProductionMapUnknownErrorMessage(
          code: code,
          fallbackCode: fallbackCode,
          statusCode: response.statusCode,
        ),
    },
    statusCode: response.statusCode,
  );
}

String _adminProductionMapUnknownErrorMessage({
  required String code,
  required String fallbackCode,
  required int statusCode,
}) {
  final operation = switch (fallbackCode.trim().toLowerCase()) {
    'production_maps_list' => 'Production maplar yuklanmadi',
    'training_maps_list' => 'Training orderlar yuklanmadi',
    'training_map_save' => 'Training order saqlanmadi',
    'training_map_save_with_order' => 'Training order va map saqlanmadi',
    'training_map_delete' => 'Training order o‘chirilmadi',
    'training_apparatus_modes' => 'Training apparatlar rejimi olinmadi',
    'training_apparatus_mode_save' => 'Training aparat rejimi saqlanmadi',
    'training_restart' => 'Training qayta boshlanmadi',
    'training_material_assignments' =>
      'Training homashyo biriktirmalari yuklanmadi',
    'training_material_assignment' => 'Training homashyo ulanmagan',
    'training_material_assignment_delete' => 'Training homashyo o‘chirilmadi',
    'training_input_batches' => 'Training batchlar yuklanmadi',
    'training_input_batch_generate' => 'Training batch generatsiya qilinmadi',
    'training_input_batch_delete' => 'Training batch o‘chirilmadi',
    'training_image_save' => 'Training order rasmi saqlanmadi',
    'production_map_audit' => 'Workflow audit yuklanmadi',
    'production_map_save' => 'Production map saqlanmadi',
    'production_map_save_with_order' => 'Zakaz va production map saqlanmadi',
    'production_map_move_batch' => 'WIP batch ko‘chirilmagan',
    'apparatus_transfer' =>
      'Orderni boshqa apparatga ko‘chirish amalga oshmadi',
    'production_map_move' => 'Order apparati o‘zgartirilmadi',
    'production_map_sequence' => 'Orderlar ketma-ketligi saqlanmadi',
    'order_control_failed' => 'Order holati o‘zgartirilmadi',
    'wip_batches' => 'WIP batchlar yuklanmadi',
    'completed_orders' => 'Yakunlangan orderlar yuklanmadi',
    'completion_requests' => 'Tugatish so‘rovlari yuklanmadi',
    'completion_request_decision' => 'Tugatish so‘rovi qarori saqlanmadi',
    'completion_request_decisions' => 'Tugatish qarorlari yuklanmadi',
    'queue_policies' => 'Aparat navbat qoidalari yuklanmadi',
    'apparatus_capacity' => 'Aparat quvvati ma’lumotlari olinmadi',
    'apparatus_downtime' => 'Aparat downtime ma’lumoti saqlanmadi',
    'apparatus_schedule' => 'Aparat jadvali saqlanmadi',
    'apparatus_schedule_cancel' => 'Aparat jadvali bekor qilinmadi',
    'raw_material_rules' => 'Homashyo qoidalari yuklanmadi',
    'raw_material_start_requirements' =>
      'Homashyo ish boshlash talablari yuklanmadi',
    'raw_material_assignments' => 'Homashyo biriktirmalari yuklanmadi',
    'raw_material_assignment_orders' => 'Homashyo uchun orderlar yuklanmadi',
    'raw_material_assignment_candidates' => 'Homashyo nomzodlari yuklanmadi',
    'raw_material_assignment_candidate_orders' =>
      'Homashyo uchun mos orderlar yuklanmadi',
    'raw_material_intake' => 'Homashyo qabul qilinmadi',
    'raw_material_intake_candidates' =>
      'Qabul qilinadigan homashyolar yuklanmadi',
    'raw_material_history' => 'Homashyo tarixi yuklanmadi',
    'qolip_code_not_found' => 'Qolip ma’lumotlari tekshirilmadi',
    'queue_action_not_allowed' => 'Order navbat amali bajarilmadi',
    'progress_batch_not_found' => 'Progress QR amali bajarilmadi',
    'progress_qr_reprint' => 'WIP QR qayta chop etilmadi',
    'paddons_list' => 'Paddonlar yuklanmadi',
    'paddon_not_found' => 'Paddon ma’lumoti olinmadi',
    'paddon_create' => 'Paddon yaratilmadi',
    'paddon_item_add' => 'WIP paddonga qo‘shilmadi',
    'paddon_item_remove' => 'WIP paddondan chiqarilmadi',
    'production_map_live_failed' => 'Production map jonli holati olinmadi',
    'production_map_run' => 'Production map ishga tushirilmadi',
    _ => 'So‘ralgan amal bajarilmadi',
  };
  final statusSuffix = statusCode > 0 ? ' (HTTP $statusCode)' : '';
  final normalizedCode = code.trim().toLowerCase();
  if (normalizedCode.isEmpty ||
      normalizedCode == fallbackCode.trim().toLowerCase()) {
    return '$operation$statusSuffix';
  }
  return '$operation: $code$statusSuffix';
}

MobileApiException _adminApiException(
  http.Response response, {
  required String fallbackCode,
  required String fallbackMessage,
}) {
  var code = fallbackCode;
  var message = fallbackMessage;
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map && payload['error'] is String) {
      final error = (payload['error'] as String).trim();
      if (error.isNotEmpty) {
        code = error;
        message = _adminErrorMessage(error);
      }
    }
  } catch (_) {}
  if (message == fallbackMessage) {
    message = '$fallbackMessage (HTTP ${response.statusCode})';
  }
  return MobileApiException(
    code: code,
    message: message,
    statusCode: response.statusCode,
  );
}

String _adminErrorMessage(String code) {
  return switch (code.trim().toLowerCase()) {
    'aasx_integrity_failed' => 'Aparat AASX ma’lumotlari tekshirilmadi',
    'apparatus_persistence_failed' => 'Aparatlar bazadan yuklanmadi',
    'apparatus_cutover_blocked' =>
      'Aparatlar canonical ma’lumotlari tayyor emas',
    'apparatus_projection_invalid' => 'Aparat ma’lumotlari formati noto‘g‘ri',
    'worker phone already exists' =>
      'Bu telefon raqami boshqa ishchiga biriktirilgan',
    'worker not found' => 'Ishchi topilmadi',
    'worker store failed' => 'Ishchi telefoni bazaga saqlanmadi',
    _ => code,
  };
}

class AdminProductionWorkflowAuditViolation {
  const AdminProductionWorkflowAuditViolation({
    required this.code,
    required this.orderId,
    required this.subject,
    required this.detail,
  });

  final String code;
  final String orderId;
  final String subject;
  final String detail;

  factory AdminProductionWorkflowAuditViolation.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminProductionWorkflowAuditViolation(
      code: json['code']?.toString().trim() ?? '',
      orderId: json['order_id']?.toString().trim() ?? '',
      subject: json['subject']?.toString().trim() ?? '',
      detail: json['detail']?.toString().trim() ?? '',
    );
  }
}

class AdminProductionWorkflowAuditReport {
  const AdminProductionWorkflowAuditReport({
    required this.ok,
    required this.checkedOrderCount,
    required this.checkedBatchCount,
    required this.checkedSessionCount,
    required this.violations,
  });

  final bool ok;
  final int checkedOrderCount;
  final int checkedBatchCount;
  final int checkedSessionCount;
  final List<AdminProductionWorkflowAuditViolation> violations;

  factory AdminProductionWorkflowAuditReport.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawViolations = json['violations'];
    return AdminProductionWorkflowAuditReport(
      ok: json['ok'] == true,
      checkedOrderCount: (json['checked_order_count'] as num?)?.toInt() ?? 0,
      checkedBatchCount: (json['checked_batch_count'] as num?)?.toInt() ?? 0,
      checkedSessionCount:
          (json['checked_session_count'] as num?)?.toInt() ?? 0,
      violations: [
        if (rawViolations is List)
          for (final item in rawViolations)
            if (item is Map)
              AdminProductionWorkflowAuditViolation.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
    );
  }
}

class AdminApparatusWorkingWindow {
  const AdminApparatusWorkingWindow({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });

  final int weekday;
  final int startMinute;
  final int endMinute;

  factory AdminApparatusWorkingWindow.fromJson(Map<String, dynamic> json) {
    return AdminApparatusWorkingWindow(
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      startMinute: (json['start_minute'] as num?)?.toInt() ?? 0,
      endMinute: (json['end_minute'] as num?)?.toInt() ?? 1440,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_minute': startMinute,
        'end_minute': endMinute,
      };
}

class AdminApparatusCapacityProfile {
  const AdminApparatusCapacityProfile({
    required this.apparatusId,
    required this.apparatus,
    this.sourceRevision = 0,
    this.sourceAasxSha256 = '',
    this.capacitySlots = 1,
    this.setupMinutes = 0,
    this.cleanupMinutes = 0,
    this.efficiencyPercent = 100,
    this.finiteCapacity = true,
    this.workingWindows = const [],
    this.capabilities = const [],
    this.capabilityLevels = const {},
    this.notes = '',
    this.updatedAtUnix = 0,
  });

  final String apparatusId;
  final String apparatus;
  final int sourceRevision;
  final String sourceAasxSha256;
  final int capacitySlots;
  final int setupMinutes;
  final int cleanupMinutes;
  final int efficiencyPercent;
  final bool finiteCapacity;
  final List<AdminApparatusWorkingWindow> workingWindows;
  final List<String> capabilities;
  final Map<String, int> capabilityLevels;
  final String notes;
  final int updatedAtUnix;

  factory AdminApparatusCapacityProfile.fromJson(Map<String, dynamic> json) {
    final rawLevels = json['capability_levels'];
    return AdminApparatusCapacityProfile(
      apparatusId: _requireCanonicalApparatusId(
        json['apparatus_id']?.toString() ?? '',
      ),
      apparatus: json['apparatus']?.toString().trim() ?? '',
      sourceRevision: (json['source_revision'] as num?)?.toInt() ?? 0,
      sourceAasxSha256: json['source_aasx_sha256']?.toString().trim() ?? '',
      capacitySlots: (json['capacity_slots'] as num?)?.toInt() ?? 1,
      setupMinutes: (json['setup_minutes'] as num?)?.toInt() ?? 0,
      cleanupMinutes: (json['cleanup_minutes'] as num?)?.toInt() ?? 0,
      efficiencyPercent: (json['efficiency_percent'] as num?)?.toInt() ?? 100,
      finiteCapacity: json['finite_capacity'] != false,
      workingWindows: [
        if (json['working_windows'] is List)
          for (final item in json['working_windows'] as List)
            if (item is Map)
              AdminApparatusWorkingWindow.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
      capabilities: [
        if (json['capabilities'] is List)
          for (final item in json['capabilities'] as List)
            if (item.toString().trim().isNotEmpty)
              item.toString().trim().toLowerCase(),
      ],
      capabilityLevels: {
        if (rawLevels is Map)
          for (final entry in rawLevels.entries)
            if (entry.key.toString().trim().isNotEmpty)
              entry.key.toString().trim().toLowerCase():
                  (entry.value as num?)?.toInt() ??
                      int.tryParse(entry.value.toString()) ??
                      1,
      },
      notes: json['notes']?.toString() ?? '',
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'apparatus_id': apparatusId.trim(),
        'apparatus': apparatus.trim(),
        'source_revision': sourceRevision,
        'source_aasx_sha256': sourceAasxSha256,
        'capacity_slots': capacitySlots,
        'setup_minutes': setupMinutes,
        'cleanup_minutes': cleanupMinutes,
        'efficiency_percent': efficiencyPercent,
        'finite_capacity': finiteCapacity,
        'working_windows': [
          for (final window in workingWindows) window.toJson()
        ],
        'capabilities': capabilities,
        'capability_levels': capabilityLevels,
        'notes': notes,
        'updated_at_unix': updatedAtUnix,
      };

  Map<String, dynamic> toCanonicalCapacityJson() => {
        'capacity_slots': capacitySlots,
        'setup_minutes': setupMinutes,
        'cleanup_minutes': cleanupMinutes,
        'efficiency_percent': efficiencyPercent,
        'finite_capacity': finiteCapacity,
        'availability': workingWindows.isEmpty
            ? {'mode': 'always'}
            : {
                'mode': 'scheduled',
                'working_windows': [
                  for (final window in workingWindows) window.toJson(),
                ],
              },
      };
}

class AdminApparatusDowntime {
  const AdminApparatusDowntime({
    required this.id,
    required this.apparatusId,
    required this.apparatus,
    required this.startsAtUnix,
    required this.endsAtUnix,
    required this.reason,
    this.active = true,
    this.actorRole = '',
    this.actorRef = '',
    this.actorDisplayName = '',
    this.createdAtUnix = 0,
  });

  final String id;
  final String apparatusId;
  final String apparatus;
  final int startsAtUnix;
  final int endsAtUnix;
  final String reason;
  final bool active;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final int createdAtUnix;

  factory AdminApparatusDowntime.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    final actorMap = actor is Map ? actor.cast<String, dynamic>() : const {};
    return AdminApparatusDowntime(
      id: json['id']?.toString() ?? '',
      apparatusId: _requireCanonicalApparatusId(
        json['apparatus_id']?.toString() ?? '',
      ),
      apparatus: json['apparatus']?.toString() ?? '',
      startsAtUnix: (json['starts_at_unix'] as num?)?.toInt() ?? 0,
      endsAtUnix: (json['ends_at_unix'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
      active: json['active'] != false,
      actorRole: actorMap['role']?.toString() ?? '',
      actorRef: actorMap['ref']?.toString() ?? '',
      actorDisplayName: actorMap['display_name']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'apparatus_id': apparatusId,
        'apparatus': apparatus,
        'starts_at_unix': startsAtUnix,
        'ends_at_unix': endsAtUnix,
        'reason': reason,
        'active': active,
        'actor': {
          'role': actorRole,
          'ref': actorRef,
          'display_name': actorDisplayName,
        },
        'created_at_unix': createdAtUnix,
      };
}

class AdminApparatusCapabilityRequirement {
  const AdminApparatusCapabilityRequirement({
    required this.code,
    this.minLevel = 1,
  });

  final String code;
  final int minLevel;

  factory AdminApparatusCapabilityRequirement.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminApparatusCapabilityRequirement(
      code: json['code']?.toString().trim() ?? '',
      minLevel: (json['min_level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {'code': code.trim(), 'min_level': minLevel};
}

class AdminApparatusScheduleCandidate {
  const AdminApparatusScheduleCandidate({
    required this.apparatusId,
    required this.apparatus,
  });

  final String apparatusId;
  final String apparatus;

  factory AdminApparatusScheduleCandidate.fromJson(Map<String, dynamic> json) {
    return AdminApparatusScheduleCandidate(
      apparatusId: _requireCanonicalApparatusId(
        json['apparatus_id']?.toString() ?? '',
      ),
      apparatus: json['apparatus']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'apparatus_id': apparatusId.trim(),
        'apparatus': apparatus.trim(),
      };
}

class AdminApparatusScheduleReservation {
  const AdminApparatusScheduleReservation({
    required this.reservationId,
    required this.idempotencyKey,
    required this.orderId,
    required this.apparatusId,
    required this.apparatus,
    required this.startsAtUnix,
    required this.endsAtUnix,
    required this.requestedDurationMinutes,
    required this.reservedDurationMinutes,
    required this.status,
    this.priority = 0,
    this.source = '',
    this.reason = '',
    this.capabilityRequirements = const [],
    this.createdAtUnix = 0,
  });

  final String reservationId;
  final String idempotencyKey;
  final String orderId;
  final String apparatusId;
  final String apparatus;
  final int startsAtUnix;
  final int endsAtUnix;
  final int requestedDurationMinutes;
  final int reservedDurationMinutes;
  final String status;
  final int priority;
  final String source;
  final String reason;
  final List<AdminApparatusCapabilityRequirement> capabilityRequirements;
  final int createdAtUnix;

  factory AdminApparatusScheduleReservation.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminApparatusScheduleReservation(
      reservationId: json['reservation_id']?.toString() ?? '',
      idempotencyKey: json['idempotency_key']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatusId: _requireCanonicalApparatusId(
        json['apparatus_id']?.toString() ?? '',
      ),
      apparatus: json['apparatus']?.toString() ?? '',
      startsAtUnix: (json['starts_at_unix'] as num?)?.toInt() ?? 0,
      endsAtUnix: (json['ends_at_unix'] as num?)?.toInt() ?? 0,
      requestedDurationMinutes:
          (json['requested_duration_minutes'] as num?)?.toInt() ?? 0,
      reservedDurationMinutes:
          (json['reserved_duration_minutes'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'planned',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      capabilityRequirements: [
        if (json['capability_requirements'] is List)
          for (final item in json['capability_requirements'] as List)
            if (item is Map)
              AdminApparatusCapabilityRequirement.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'reservation_id': reservationId,
        'idempotency_key': idempotencyKey,
        'order_id': orderId,
        'apparatus_id': apparatusId,
        'apparatus': apparatus,
        'starts_at_unix': startsAtUnix,
        'ends_at_unix': endsAtUnix,
        'requested_duration_minutes': requestedDurationMinutes,
        'reserved_duration_minutes': reservedDurationMinutes,
        'status': status,
        'priority': priority,
        'source': source,
        'reason': reason,
        'capability_requirements': [
          for (final item in capabilityRequirements) item.toJson(),
        ],
        'created_at_unix': createdAtUnix,
      };
}

class AdminApparatusCapacitySnapshot {
  const AdminApparatusCapacitySnapshot({
    this.profiles = const [],
    this.downtimes = const [],
    this.reservations = const [],
  });

  final List<AdminApparatusCapacityProfile> profiles;
  final List<AdminApparatusDowntime> downtimes;
  final List<AdminApparatusScheduleReservation> reservations;

  factory AdminApparatusCapacitySnapshot.fromJson(Map<String, dynamic> json) {
    return AdminApparatusCapacitySnapshot(
      profiles: [
        if (json['profiles'] is List)
          for (final item in json['profiles'] as List)
            if (item is Map)
              AdminApparatusCapacityProfile.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
      downtimes: [
        if (json['downtimes'] is List)
          for (final item in json['downtimes'] as List)
            if (item is Map)
              AdminApparatusDowntime.fromJson(item.cast<String, dynamic>()),
      ],
      reservations: [
        if (json['reservations'] is List)
          for (final item in json['reservations'] as List)
            if (item is Map)
              AdminApparatusScheduleReservation.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
    );
  }
}

extension MobileApiAdmin on MobileApi {
  String get baseUrl => MobileApi.baseUrl;

  Future<AdminSettings> adminSettings() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.adminSettings;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/settings'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin settings failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSettings> updateAdminSettings(AdminSettings settings) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/settings'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(settings.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin settings update failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSettings> adminRegenerateWerkaCode() async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/werka/code/regenerate'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin werka code regenerate failed');
    }
    return AdminSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<DispatchRecord>> adminActivity() async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/activity'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin activity failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => DispatchRecord.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminServerMonitorReport> adminServerMonitor() async {
    if (await TestModeController.instance.isEnabled()) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final seededSnapshot = AdminServerMonitorBackupSnapshot(
        id: 'test-backup-seed',
        status: 'ready',
        source: 'automatic',
        requestedBy: 'Backup Doctor',
        createdAtUnix: now - 1800,
        startedAtUnix: now - 1800,
        completedAtUnix: now - 1790,
        sizeBytes: 12 * 1024 * 1024,
        artifactName: 'mini_rs_erp_20260624_180448.dump',
        checksumSha256: List<String>.filled(64, 'a').join(),
        verified: true,
        error: '',
      );
      final snapshots = [seededSnapshot, ..._testModeBackupSnapshots];
      return AdminServerMonitorReport(
        server: AdminServerMonitorServer(
          bindAddr: '127.0.0.1:8081',
          startedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          uptimeSeconds: 3600,
          status: 'running',
        ),
        database: const AdminServerMonitorDatabase(
          configured: true,
          reachable: true,
          status: 'online',
          pingMs: 12,
          error: '',
        ),
        backups: AdminServerMonitorBackups(
          directory: 'backups/mini_rs_erp_db',
          exists: true,
          fileCount: 1,
          latest: AdminServerMonitorBackupFile(
            name: 'mini_rs_erp_20260624_180448.dump',
            path: 'backups/mini_rs_erp_db/mini_rs_erp_20260624_180448.dump',
            sizeBytes: 12 * 1024 * 1024,
            modifiedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ageSeconds: 1800,
          ),
          files: [
            AdminServerMonitorBackupFile(
              name: 'mini_rs_erp_20260624_180448.dump',
              path: 'backups/mini_rs_erp_db/mini_rs_erp_20260624_180448.dump',
              sizeBytes: 12 * 1024 * 1024,
              modifiedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ageSeconds: 1800,
            ),
          ],
          snapshotCount: snapshots.where((item) => item.ready).length,
          latestSnapshot: snapshots.first,
          snapshots: snapshots,
          activeJob: null,
          healthy: true,
          error: '',
        ),
        runtime: const AdminServerMonitorRuntime(
          cpuPercent: 26,
          memoryPercent: 42,
          memoryUsedMb: 1720,
          memoryTotalMb: 4096,
          diskPath: '/home/wikki/mini_rs_erp_deploy/src',
          diskPercent: 38,
          diskUsedMb: 190000,
          diskTotalMb: 500000,
          diskAvailableMb: 310000,
          loadAverage: 0.7,
          sampleSeconds: 2,
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/system/monitor'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw const MobileApiException(
        code: 'admin_server_monitor',
        message: 'Server monitor yuklanmadi',
      );
    }
    return AdminServerMonitorReport.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> adminResetOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_reset_test_mode_unsupported',
        message: 'Order reset test rejimida mavjud emas',
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/emergency-reset/orders'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'confirmation': 'RESET ORDERS'}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_reset_failed');
    }
  }

  Future<AdminServerMonitorBackupSnapshot> adminStartBackup() async {
    if (await TestModeController.instance.isEnabled()) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final id = 'test-backup-$now-${_testModeBackupSnapshots.length}';
      final ready = AdminServerMonitorBackupSnapshot(
        id: id,
        status: 'ready',
        source: 'manual',
        requestedBy: AppSession.instance.profile?.displayName ?? 'Admin',
        createdAtUnix: now,
        startedAtUnix: now,
        completedAtUnix: now,
        sizeBytes: 1024,
        artifactName: 'mini_rs_erp_$now.dump',
        checksumSha256: List<String>.filled(64, 'b').join(),
        verified: true,
        error: '',
      );
      _testModeBackupSnapshots.insert(0, ready);
      return AdminServerMonitorBackupSnapshot(
        id: id,
        status: 'queued',
        source: 'manual',
        requestedBy: ready.requestedBy,
        createdAtUnix: now,
        startedAtUnix: 0,
        completedAtUnix: 0,
        sizeBytes: 0,
        artifactName: '',
        checksumSha256: '',
        verified: false,
        error: '',
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/system/backups'),
        headers: _headers(requireToken()),
      ),
    );
    Map<String, dynamic> payload = const {};
    if (response.body.trim().isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        payload = const {};
      }
    }
    if (response.statusCode != 202) {
      throw MobileApiException(
        code: payload['error']?.toString() ?? 'backup_start_failed',
        message: _backupErrorMessage(payload['error']?.toString() ?? ''),
        statusCode: response.statusCode,
      );
    }
    return AdminServerMonitorBackupSnapshot.fromJson(payload);
  }

  Future<AdminServerMonitorBackupSnapshot> adminImportBackup({
    required String filename,
    required int contentLength,
    required Stream<List<int>> Function() openStream,
    void Function(int received, int total)? onProgress,
  }) async {
    final normalizedFilename = filename.trim();
    if (normalizedFilename.isEmpty ||
        contentLength <= 0 ||
        !normalizedFilename.toLowerCase().endsWith('.dump')) {
      throw const MobileApiException(
        code: 'backup_import_invalid',
        message: 'Backup fayli noto‘g‘ri',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      var received = 0;
      await for (final chunk in openStream()) {
        received += chunk.length;
        onProgress?.call(received, contentLength);
      }
      if (received != contentLength) {
        throw const MobileApiException(
          code: 'backup_import_invalid',
          message: 'Backup fayli to‘liq o‘qilmadi',
        );
      }
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final id = 'test-import-$now-${_testModeBackupSnapshots.length}';
      final ready = AdminServerMonitorBackupSnapshot(
        id: id,
        status: 'ready',
        source: 'imported',
        requestedBy: AppSession.instance.profile?.displayName ?? 'Admin',
        createdAtUnix: now,
        startedAtUnix: now,
        completedAtUnix: now,
        sizeBytes: contentLength,
        artifactName: normalizedFilename,
        checksumSha256: List<String>.filled(64, 'c').join(),
        verified: true,
        error: '',
      );
      _testModeBackupSnapshots.insert(0, ready);
      return ready;
    }

    final response = await _sendStreamedAuthorized(() async {
      final request = http.StreamedRequest(
        'POST',
        Uri.parse('$baseUrl/v1/mobile/admin/system/backups/import'),
      )
        ..headers.addAll(_headers(requireToken()))
        ..headers['Content-Type'] = 'application/octet-stream'
        ..headers['X-Backup-Filename'] = normalizedFilename
        ..contentLength = contentLength;
      // Start the request before closing the sink. StreamedRequest.close() may
      // wait for a listener, so awaiting close before send() deadlocks forever.
      final responseFuture = request.send();
      var received = 0;
      try {
        await request.sink.addStream(
          openStream().map((chunk) {
            received += chunk.length;
            onProgress?.call(received, contentLength);
            if (received > contentLength) {
              throw const MobileApiException(
                code: 'backup_import_invalid',
                message: 'Backup fayli kutilgan hajmdan katta',
              );
            }
            return chunk;
          }),
        );
        if (received != contentLength) {
          throw const MobileApiException(
            code: 'backup_import_invalid',
            message: 'Backup fayli to‘liq o‘qilmadi',
          );
        }
        await request.sink.close();
      } catch (_) {
        try {
          await request.sink.close();
        } catch (_) {
          // Preserve the original upload error.
        }
        rethrow;
      }
      return responseFuture;
    });
    final body = await http.Response.fromStream(response);
    Map<String, dynamic> payload = const {};
    if (body.body.trim().isNotEmpty) {
      try {
        payload = jsonDecode(body.body) as Map<String, dynamic>;
      } catch (_) {
        payload = const {};
      }
    }
    if (body.statusCode != 202) {
      final code = payload['error']?.toString() ?? 'backup_import_failed';
      throw MobileApiException(
        code: code,
        message: _backupErrorMessage(code),
        statusCode: body.statusCode,
      );
    }
    return AdminServerMonitorBackupSnapshot.fromJson(payload);
  }

  Future<AdminBackupDownload> adminDownloadBackup(String backupId) async {
    final id = backupId.trim();
    if (id.isEmpty) {
      throw const MobileApiException(
        code: 'backup_not_found',
        message: 'Backup topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      return AdminBackupDownload(
        filename: 'mini_rs_erp_test.dump',
        contentType: 'application/octet-stream',
        contentLength: 17,
        stream: Stream<List<int>>.value(utf8.encode('test-backup-bytes')),
      );
    }
    final uri = Uri.parse(
      '$baseUrl/v1/mobile/admin/system/backups/${Uri.encodeComponent(id)}/download',
    );
    final response = await _sendMultipartAuthorized(() {
      final request = http.Request('GET', uri)
        ..headers.addAll(_headers(requireToken()));
      return request.send();
    });
    if (response.statusCode != 200) {
      final failed = await http.Response.fromStream(response);
      var code = 'backup_download_failed';
      if (failed.body.trim().isNotEmpty) {
        try {
          code = (jsonDecode(failed.body) as Map<String, dynamic>)['error']
                  ?.toString() ??
              code;
        } catch (_) {
          // Keep the stable fallback error code for non-JSON proxy errors.
        }
      }
      throw MobileApiException(
        code: code,
        message: _backupErrorMessage(code),
        statusCode: response.statusCode,
      );
    }
    return AdminBackupDownload(
      filename: _downloadFilename(
        response.headers['content-disposition'] ?? '',
      ),
      contentType:
          response.headers['content-type'] ?? 'application/octet-stream',
      contentLength: response.contentLength ?? 0,
      stream: response.stream,
    );
  }

  String _downloadFilename(String contentDisposition) {
    final match = RegExp(
      r'filename="?([^";]+)"?',
    ).firstMatch(contentDisposition);
    final filename = match?.group(1)?.trim() ?? '';
    return filename.isEmpty ? 'mini_rs_erp.dump' : filename;
  }

  String _backupErrorMessage(String code) {
    return switch (code) {
      'backup_already_running' => 'Backup olish allaqachon boshlangan',
      'backup_service_unavailable' => 'Backup xizmati hozir mavjud emas',
      'backup_not_ready' => 'Backup hali yuklab olishga tayyor emas',
      'backup_not_found' => 'Backup topilmadi',
      'backup_download_failed' => 'Backup yuklab olinmadi',
      'backup_import_invalid' =>
        'Backup fayli noto‘g‘ri yoki qo‘llab-quvvatlanmaydi',
      'backup_import_too_large' => 'Backup fayli juda katta',
      'backup_import_upload_failed' => 'Backup serverga yuklanmadi',
      'backup_import_upload_timeout' =>
        'Backup yuklash uzoq vaqt javobsiz qoldi',
      'backup_import_failed' => 'Backup import qilinmadi',
      'backup_service_failed' => 'Backup xizmati xatolik berdi',
      _ => 'Backup olish boshlanmadi',
    };
  }

  Uri adminServerMonitorLiveUri() {
    final Uri base = Uri.parse(baseUrl);
    final String scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/v1/mobile/admin/system/monitor/live',
      queryParameters: {'token': requireToken()},
    );
  }

  Stream<AdminServerMonitorLiveEvent> adminServerMonitorLiveEvents() async* {
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    await for (final event in withLiveStreamSilenceTimeout(
      connectSystemMonitorLive(adminServerMonitorLiveUri()),
    )) {
      final liveEvent = AdminServerMonitorLiveEvent.fromJson(event);
      if (liveEvent.report != null || liveEvent.latencyMs != null) {
        yield liveEvent;
      }
    }
  }

  Future<List<AdminCapability>> adminCapabilities() async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/capabilities'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin capabilities failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminCapability.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<AdminRoleDefinition>> adminRoles() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.roles;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/roles'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin roles failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRoleDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ProductionMapSaved>> adminProductionMaps() async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceProductionMapMenuLoadFailure) {
        throw const MobileApiException(
          code: 'production_maps_list',
          message: 'Production maplar yuklanmadi',
        );
      }
      return List<ProductionMapSaved>.unmodifiable(_testModeProductionMaps);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_maps_list');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => ProductionMapSaved.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminProductionWorkflowAuditReport> adminProductionMapAudit() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminProductionWorkflowAuditReport(
        ok: true,
        checkedOrderCount: _testModeProductionMaps.length,
        checkedBatchCount: 0,
        checkedSessionCount: 0,
        violations: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/audit'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_audit');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map) {
      throw const MobileApiException(
        code: 'production_map_audit_invalid_response',
        message: 'Workflow audit javobi noto‘g‘ri',
      );
    }
    return AdminProductionWorkflowAuditReport.fromJson(
      payload.cast<String, dynamic>(),
    );
  }

  Future<ProductionMapSaved> adminProductionMap(String id) async {
    final normalized = id.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeProductionMaps.firstWhere(
        (item) => item.map.id.trim() == normalized,
        orElse: () => throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps',
        ).replace(queryParameters: {'id': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'map_not_found');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ProductionMapSaved> adminSaveProductionMap(
    ProductionMapDefinition map,
  ) async {
    _requireCanonicalProductionMapApparatusIds(map);
    if (await TestModeController.instance.isEnabled()) {
      final originalMapId = map.id.trim();
      final normalizedMap = _testModeAssignOrderNumberIfMissing(map);
      final duplicate = _testModeProductionMaps.any(
        (item) =>
            item.map.orderNumber.trim().isNotEmpty &&
            item.map.orderNumber.trim() == normalizedMap.orderNumber.trim() &&
            !_isSameProductionMapOrder(item.map, normalizedMap),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'duplicate_order_number',
          message: 'Bu raqam boshqa zakazga berilgan',
        );
      }
      final saved = ProductionMapSaved(
        map: normalizedMap,
        program: ProductionMapProgram(
          mapId: normalizedMap.id,
          productCode: normalizedMap.productCode,
          operations: [
            for (var i = 0; i < normalizedMap.nodes.length; i++)
              ProductionMapOperation(
                order: i + 1,
                nodeId: normalizedMap.nodes[i].id,
                opCode: normalizedMap.nodes[i].kind,
                args: {'title': normalizedMap.nodes[i].title},
              ),
          ],
        ),
      );
      _testModeProductionMaps.removeWhere(
        (item) =>
            item.map.id == originalMapId || item.map.id == normalizedMap.id,
      );
      _testModeProductionMaps.insert(0, saved);
      return saved;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(map.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_save');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ProductionMapSaveWithOrderResult> adminSaveProductionMapWithOrder({
    required ProductionMapDefinition map,
    required CalculateOrderTemplate template,
  }) async {
    _requireCanonicalProductionMapApparatusIds(map);
    if (await TestModeController.instance.isEnabled()) {
      final previousIndex = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == map.id.trim(),
      );
      ProductionMapSaved? previousMap;
      if (previousIndex >= 0) {
        previousMap = _testModeProductionMaps[previousIndex];
      }
      if (template.product.trim().isEmpty || template.widthMm <= 0) {
        throw const MobileApiException(
          code: 'calculate_order_save',
          message: 'Calculate order validation failed',
        );
      }
      ProductionMapSaved? savedMapForRollback;
      try {
        var orderMap =
            previousIndex < 0 ? _testModeAssignOrderNumberIfMissing(map) : map;
        if (previousIndex < 0) {
          orderMap = _orderMapWithTemplateRezkaKadrCount(orderMap, template);
        }
        final orderNumberWasGenerated =
            previousIndex < 0 && orderMap.id.trim() != map.id.trim();
        final savedMap = await adminSaveProductionMap(orderMap);
        savedMapForRollback = savedMap;
        final templateMap = _templateMapCopyForSave(savedMap.map, template);
        final savedTemplateMap = templateMap == null
            ? null
            : await adminSaveProductionMap(templateMap);
        final opensQuickTemplateAsOrder =
            template.sourceMapId.trim().isNotEmpty &&
                template.sourceMapId.trim() != savedMap.map.id.trim() &&
                _isSheetOrderMap(savedMap.map);
        final templateToSave = orderNumberWasGenerated
            ? template.copyWith(orderNumber: savedMap.map.orderNumber)
            : template;
        final savedTemplate = opensQuickTemplateAsOrder
            ? null
            : _testModeUpsertCalculateOrderTemplate(
                templateToSave.copyWith(
                  sourceMapId: savedTemplateMap?.map.id ??
                      _templateSourceMapIdForSave(savedMap.map, template),
                ),
              );
        return ProductionMapSaveWithOrderResult(
          saved: savedMap,
          template: savedTemplate,
        );
      } catch (error) {
        if (previousMap != null) {
          if (previousIndex >= 0) {
            _testModeProductionMaps[previousIndex] = previousMap;
          }
        } else {
          _testModeProductionMaps.removeWhere((item) {
            final itemId = item.map.id.trim();
            return itemId == map.id.trim() ||
                (savedMapForRollback != null &&
                    itemId == savedMapForRollback!.map.id.trim());
          });
        }
        rethrow;
      }
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/with-order'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'map': map.toJson(), 'template': template.toJson()}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'production_map_save_with_order',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaveWithOrderResult(
      saved: ProductionMapSaved.fromJson(
        (payload['saved'] as Map).cast<String, dynamic>(),
      ),
      template: payload['template'] is Map
          ? CalculateOrderTemplate.fromJson(
              (payload['template'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  Future<List<ProductionMapSaved>> adminMoveProductionMapOrdersBatch({
    required List<String> mapIds,
    required String fromApparatus,
    required String toApparatus,
  }) async {
    final normalizedFrom = _requireCanonicalApparatusId(fromApparatus);
    final normalizedTo = _requireCanonicalApparatusId(toApparatus);
    if (await TestModeController.instance.isEnabled()) {
      final sourceApparatus = _testModeRequiredApparatus(normalizedFrom);
      final targetApparatus = _testModeRequiredApparatus(normalizedTo);
      final normalizedIds = [
        for (final id in mapIds)
          if (id.trim().isNotEmpty) id.trim(),
      ];
      if (normalizedIds.isEmpty) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz tanlanmadi',
        );
      }
      final originals = <ProductionMapSaved>[];
      for (final mapId in normalizedIds) {
        final index = _testModeProductionMaps.indexWhere(
          (item) => item.map.id.trim() == mapId,
        );
        if (index < 0) {
          throw const MobileApiException(
            code: 'map_not_found',
            message: 'Zakaz topilmadi',
          );
        }
        originals.add(_testModeProductionMaps[index]);
      }
      final updated = <ProductionMapSaved>[];
      for (final current in originals) {
        _testModeEnsurePendingApparatusMove(
          orderId: current.map.id,
          fromApparatus: normalizedFrom,
        );
        if (!productionMapCanMoveOrderToApparatus(
          nodes: current.map.nodes,
          fromApparatus: sourceApparatus,
          toApparatus: targetApparatus,
          rollCount: current.map.rollCount,
          widthMm: current.map.widthMm,
        )) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        final nodes = productionMapReassignAlternativeApparatusAssignment(
              nodes: current.map.nodes,
              fromApparatus: sourceApparatus,
              toApparatus: targetApparatus,
            ) ??
            productionMapReassignApparatusNodes(
              nodes: current.map.nodes,
              fromApparatus: sourceApparatus,
              toApparatus: targetApparatus,
            );
        if (nodes == null) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        updated.add(
          ProductionMapSaved(
            map: current.map.copyWith(nodes: nodes),
            program: current.program,
          ),
        );
      }
      for (var i = 0; i < normalizedIds.length; i++) {
        final index = _testModeProductionMaps.indexWhere(
          (item) => item.map.id.trim() == normalizedIds[i],
        );
        if (index >= 0) {
          _testModeProductionMaps[index] = updated[i];
        }
      }
      return updated;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/move-batch'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'from_apparatus': normalizedFrom,
          'to_apparatus': normalizedTo,
          'map_ids': mapIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_move_batch');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['saved'];
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (item is Map)
          ProductionMapSaved.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<ProductionMapSaved> adminTransferProductionMapOrder({
    required String orderId,
    required String fromApparatus,
    required String toApparatus,
    required String reason,
    required String idempotencyKey,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedFrom = _requireCanonicalApparatusId(fromApparatus);
    final normalizedTo = _requireCanonicalApparatusId(toApparatus);
    final normalizedReason = reason.trim();
    final normalizedKey = idempotencyKey.trim();
    if (normalizedOrderId.isEmpty) {
      throw const MobileApiException(
        code: 'apparatus_transfer_order_not_paused',
        message: 'Avariya ko‘chirish ma’lumotlari to‘liq emas',
      );
    }
    if (normalizedReason.isEmpty) {
      throw const MobileApiException(
        code: 'apparatus_transfer_reason_required',
        message: 'Avariya sababini kiriting',
      );
    }
    if (normalizedKey.isEmpty || normalizedKey.length > 200) {
      throw const MobileApiException(
        code: 'apparatus_transfer_idempotency_required',
        message: 'Avariya ko‘chirish identifikatori mavjud emas',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final sourceApparatus = _testModeRequiredApparatus(normalizedFrom);
      final targetApparatus = _testModeRequiredApparatus(normalizedTo);
      final existing = _testModeApparatusTransfers[normalizedKey];
      if (existing != null) {
        if (existing.orderId != normalizedOrderId ||
            existing.fromApparatus != normalizedFrom ||
            existing.toApparatus != normalizedTo) {
          throw const MobileApiException(
            code: 'apparatus_transfer_idempotency_conflict',
            message:
                'Avariya ko‘chirish identifikatori boshqa amalda ishlatilgan',
          );
        }
        return existing.saved;
      }
      if (normalizedFrom == normalizedTo) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz shu apparatda qolmoqda',
        );
      }
      final sourceKey = normalizedFrom;
      final targetKey = normalizedTo;
      if (sourceKey == targetKey) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz shu apparatda qolmoqda',
        );
      }
      final sourceStates = Map<String, String>.from(
        _testModeApparatusQueueStates[sourceKey] ?? const {},
      );
      final targetStates = Map<String, String>.from(
        _testModeApparatusQueueStates[targetKey] ?? const {},
      );
      if (apparatusQueueOrderStateFromRaw(sourceStates[normalizedOrderId]) !=
          ApparatusQueueOrderState.paused) {
        throw const MobileApiException(
          code: 'apparatus_transfer_order_not_paused',
          message: 'Ko‘chirishdan oldin orderni pause qiling',
        );
      }
      if (targetStates.containsKey(normalizedOrderId)) {
        throw const MobileApiException(
          code: 'apparatus_transfer_target_conflict',
          message: 'Order tanlangan apparatda allaqachon mavjud',
        );
      }
      final index = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == normalizedOrderId,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        );
      }
      final current = _testModeProductionMaps[index];
      if (!productionMapCanMoveOrderToApparatus(
        nodes: current.map.nodes,
        fromApparatus: sourceApparatus,
        toApparatus: targetApparatus,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          );
      if (nodes == null) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final saved = ProductionMapSaved(
        map: current.map.copyWith(nodes: nodes),
        program: current.program,
      );
      final sourceSequence = List<String>.from(
        _testModeApparatusSequences[sourceKey] ?? const [],
      )..removeWhere((id) => id.trim() == normalizedOrderId);
      final targetSequence =
          List<String>.from(_testModeApparatusSequences[targetKey] ?? const [])
            ..removeWhere((id) => id.trim() == normalizedOrderId)
            ..add(normalizedOrderId);
      sourceStates.remove(normalizedOrderId);
      targetStates[normalizedOrderId] = 'paused';
      _testModeProductionMaps[index] = saved;
      _testModeApparatusSequences[sourceKey] = sourceSequence;
      _testModeApparatusSequences[targetKey] = targetSequence;
      _testModeApparatusQueueStates[sourceKey] = sourceStates;
      _testModeApparatusQueueStates[targetKey] = targetStates;
      _testModeMoveScheduleReservations(
        orderId: normalizedOrderId,
        fromApparatusId: sourceKey,
        toApparatusId: targetKey,
      );
      _testModeApparatusTransfers[normalizedKey] =
          _TestModeApparatusTransferReceipt(
        orderId: normalizedOrderId,
        fromApparatus: normalizedFrom,
        toApparatus: normalizedTo,
        saved: saved,
      );
      return saved;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/apparatus-transfer',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          'from_apparatus': normalizedFrom,
          'to_apparatus': normalizedTo,
          'reason': normalizedReason,
          'idempotency_key': normalizedKey,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_transfer');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawSaved = payload['saved'];
    if (rawSaved is! Map) {
      throw const MobileApiException(
        code: 'apparatus_transfer_invalid_response',
        message: 'Avariya ko‘chirish javobi noto‘g‘ri',
      );
    }
    return ProductionMapSaved.fromJson(rawSaved.cast<String, dynamic>());
  }

  Future<ProductionMapSaved> adminMoveProductionMapOrder({
    required String mapId,
    required String fromApparatus,
    required String toApparatus,
  }) async {
    final normalizedFrom = _requireCanonicalApparatusId(fromApparatus);
    final normalizedTo = _requireCanonicalApparatusId(toApparatus);
    if (await TestModeController.instance.isEnabled()) {
      final sourceApparatus = _testModeRequiredApparatus(normalizedFrom);
      final targetApparatus = _testModeRequiredApparatus(normalizedTo);
      final index = _testModeProductionMaps.indexWhere(
        (item) => item.map.id.trim() == mapId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Zakaz topilmadi',
        );
      }
      final current = _testModeProductionMaps[index];
      _testModeEnsurePendingApparatusMove(
        orderId: current.map.id,
        fromApparatus: normalizedFrom,
      );
      if (!productionMapCanMoveOrderToApparatus(
        nodes: current.map.nodes,
        fromApparatus: sourceApparatus,
        toApparatus: targetApparatus,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: sourceApparatus,
            toApparatus: targetApparatus,
          );
      if (nodes == null) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final saved = ProductionMapSaved(
        map: current.map.copyWith(nodes: nodes),
        program: current.program,
      );
      _testModeProductionMaps[index] = saved;
      return saved;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/move'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'map_id': mapId,
          'from_apparatus': normalizedFrom,
          'to_apparatus': normalizedTo,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_move');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaved.fromJson(
      (payload['saved'] as Map).cast<String, dynamic>(),
    );
  }

  Future<Map<String, List<String>>> adminProductionMapSequences() async {
    final snapshot = await adminProductionMapQueueSnapshot();
    return snapshot.sequences;
  }

  Future<AdminApparatusQueueSnapshot> adminProductionMapQueueSnapshot() async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceProductionMapQueueSnapshotLoadFailure) {
        throw const MobileApiException(
          code: 'store_failed',
          message: 'Ish rejasi navbati serverdan yuklanmadi',
        );
      }
      final orderControls = Map<String, AdminOrderControlState>.unmodifiable(
        _testModeOrderControls,
      );
      final snapshot = AdminApparatusQueueSnapshot(
        sequences: _testModeEffectiveQueueSequences(),
        visibleOrderIds: _testModeVisibleOrderIdsByApparatus(),
        queueStates: {
          for (final entry in _testModeApparatusQueueStates.entries)
            entry.key: Map<String, String>.unmodifiable(entry.value),
        },
        queuePolicies: Map<String, AdminApparatusQueuePolicy>.unmodifiable(
          _testModeApparatusQueuePolicies,
        ),
        queueActionControls: _testModeQueueActionControls(),
        orderControls: orderControls,
        orderCustomers: {
          for (final saved in _testModeProductionMaps)
            if (saved.map.id.trim().isNotEmpty &&
                saved.map.customerName.trim().isNotEmpty)
              saved.map.id.trim(): saved.map.customerName.trim(),
        },
        orderStatuses: const {},
        qolipOrderNotes: Map<String, AdminQolipOrderNote>.unmodifiable(
          _testModeQolipOrderNotes,
        ),
        frozenOrdersByApparatus: _testModeFrozenOrdersByApparatus(),
      );
      snapshot.validateContract();
      return snapshot;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final visibleOrderIds = _parseRequiredProductionMapVisibleOrderIds(payload);
    _requireProductionMapSnapshotShape(payload, includesMaps: false);
    final orderControls = _parseAdminOrderControls(payload['order_controls']);
    final snapshot = AdminApparatusQueueSnapshot(
      sequences: parseApparatusSequenceMap(payload['sequences']),
      visibleOrderIds: visibleOrderIds,
      queueStates: parseApparatusQueueStateMap(payload['queue_states']),
      queuePolicies: parseApparatusQueuePolicyMap(payload['queue_policies']),
      queueActionControls: _parseAdminQueueActionControls(
        payload['queue_action_controls'],
      ),
      orderControls: orderControls,
      orderCustomers: _stringMapOfStrings(payload['order_customers']),
      orderStatuses: _parseAdminOrderStatuses(payload['order_statuses']),
      qolipOrderNotes: _parseAdminQolipOrderNotes(payload['qolip_order_notes']),
      frozenOrdersByApparatus: _parseAdminFrozenOrdersByApparatus(
        payload['frozen_orders_by_apparatus'],
      ),
    );
    snapshot.validateContract();
    return snapshot;
  }

  Future<AdminOrderControlState?> adminProductionMapOrderControl({
    required String orderId,
    required AdminOrderControlAction action,
  }) async {
    final normalizedOrderId = orderId.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _applyTestModeOrderControl(normalizedOrderId, action);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/order-control'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          'action': action.apiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_control_failed');
    }
    if (action == AdminOrderControlAction.delete) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final control = payload['control'];
    if (control is! Map) {
      throw const MobileApiException(
        code: 'order_control_invalid_response',
        message: 'Buyurtma holati olinmadi',
      );
    }
    return AdminOrderControlState.fromRaw(control['state']);
  }

  Future<List<AdminProgressBatch>> adminWipBatches({
    String status = '',
    String apparatus = '',
    String nextApparatus = '',
    String currentLocation = '',
    String orderId = '',
    int limit = 100,
  }) async {
    final normalizedStatus = status.trim();
    final normalizedApparatus = _requireCanonicalApparatusId(
      apparatus,
      allowEmpty: true,
    );
    final normalizedNextApparatus = _requireCanonicalApparatusId(
      nextApparatus,
      allowEmpty: true,
    );
    final normalizedCurrentLocation = currentLocation.trim();
    final normalizedOrderId = orderId.trim();
    final boundedLimit = limit.clamp(1, 1000).toInt();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeProgressBatchesByQr.values
          .where((batch) {
            if (normalizedStatus.isNotEmpty &&
                !_wipStatusMatchesFilter(batch.wipStatus, normalizedStatus)) {
              return false;
            }
            if (normalizedApparatus.isNotEmpty &&
                batch.currentApparatus.trim() != normalizedApparatus &&
                batch.apparatus.trim() != normalizedApparatus) {
              return false;
            }
            if (normalizedNextApparatus.isNotEmpty &&
                batch.nextApparatus.trim().isNotEmpty &&
                batch.nextApparatus.trim() != normalizedNextApparatus) {
              return false;
            }
            if (normalizedCurrentLocation.isNotEmpty &&
                batch.currentLocation.trim() != normalizedCurrentLocation) {
              return false;
            }
            if (normalizedOrderId.isNotEmpty &&
                batch.orderId.trim() != normalizedOrderId) {
              return false;
            }
            return true;
          })
          .take(boundedLimit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/wip-batches',
        ).replace(
          queryParameters: {
            if (normalizedStatus.isNotEmpty) 'status': normalizedStatus,
            if (normalizedApparatus.isNotEmpty)
              'apparatus': normalizedApparatus,
            if (normalizedNextApparatus.isNotEmpty)
              'next_apparatus': normalizedNextApparatus,
            if (normalizedCurrentLocation.isNotEmpty)
              'current_location': normalizedCurrentLocation,
            if (normalizedOrderId.isNotEmpty) 'order_id': normalizedOrderId,
            'limit': boundedLimit.toString(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'wip_batches');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batches'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<List<AdminCompletedQueueOrder>>
      adminCompletedProductionMapOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceCompletedProductionMapOrdersLoadFailure) {
        throw const MobileApiException(
          code: 'completed_orders',
          message: 'Yakunlangan orderlar yuklanmadi',
        );
      }
      final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
      return [
        for (final item in _testModeCompletedQueueOrders)
          if (item.actorRef == actorRef) item.order,
      ];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/completed-orders'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'completed_orders');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['completed_orders'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminCompletedQueueOrder.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<List<AdminCompletionRequestNotification>>
      adminProductionMapCompletionRequests() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminCompletionRequestNotification>.unmodifiable(
        _testModeCompletionRequests,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/completion-requests',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'completion_requests');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['completion_requests'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminCompletionRequestNotification.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
    ];
  }

  Future<AdminCompletionRequestDecisionNotification>
      adminProductionMapCompletionRequestDecision({
    required String eventId,
    required String decision,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeCompletionRequests.indexWhere(
        (item) => item.eventId.trim() == eventId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Tugatish so‘rovi topilmadi',
        );
      }
      final request = _testModeCompletionRequests.removeAt(index);
      final normalized = decision.trim().toLowerCase().startsWith('reject')
          ? 'rejected'
          : 'approved';
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final message = normalized == 'rejected'
          ? "Sizni so'rovingiz rad etildi"
          : 'Muammo bilan yopildi';
      if (normalized == 'approved') {
        final states = Map<String, String>.from(
          _testModeApparatusQueueStates[request.apparatus] ?? const {},
        );
        states[request.orderId] = 'completed';
        _testModeApparatusQueueStates[request.apparatus] = states;
      }
      final notification = AdminCompletionRequestDecisionNotification(
        eventId: 'test-completion-decision-$now-${request.orderId}',
        requestEventId: request.eventId,
        decision: normalized,
        apparatus: request.apparatus,
        orderId: request.orderId,
        orderNumber: request.orderNumber,
        orderTitle: request.orderTitle,
        productCode: request.productCode,
        workerRole: request.workerRole,
        workerRef: request.workerRef,
        workerDisplayName: request.workerDisplayName,
        decidedByRole: AppSession.instance.profile?.role.name ?? '',
        decidedByRef: AppSession.instance.profile?.ref.trim() ?? '',
        decidedByDisplayName:
            AppSession.instance.profile?.displayName.trim() ?? '',
        description: request.description,
        message: message,
        createdAtUnix: now,
      );
      _testModeCompletionRequestDecisions.insert(0, notification);
      return notification;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/completion-requests/decision',
        ),
        headers: _headers(requireToken()),
        body: jsonEncode({'event_id': eventId, 'decision': decision}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'completion_request_decision',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminCompletionRequestDecisionNotification.fromJson(
      (payload['decision'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<AdminCompletionRequestDecisionNotification>>
      adminProductionMapCompletionRequestDecisions() async {
    if (await TestModeController.instance.isEnabled()) {
      final workerRef = AppSession.instance.profile?.ref.trim() ?? '';
      return List<AdminCompletionRequestDecisionNotification>.unmodifiable(
        _testModeCompletionRequestDecisions.where(
          (item) => workerRef.isEmpty || item.workerRef.trim() == workerRef,
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/completion-request-decisions',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'completion_request_decisions',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['completion_request_decisions'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminCompletionRequestDecisionNotification.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
    ];
  }

  Future<List<AdminClosedProductionOrder>>
      adminClosedProductionMapOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      return const [];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/closed-orders'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'closed_orders');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['closed_orders'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminClosedProductionOrder.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
    ];
  }

  Future<Map<String, AdminApparatusQueuePolicy>>
      adminApparatusQueuePolicies() async {
    if (await TestModeController.instance.isEnabled()) {
      return Map<String, AdminApparatusQueuePolicy>.unmodifiable(
        _testModeApparatusQueuePolicies,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-policies'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_policies');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return parseApparatusQueuePolicyMap(payload['policies']);
  }

  Future<AdminApparatusQueuePolicy> adminUpdateApparatusQueuePolicy({
    required String apparatusId,
    required int expectedRevision,
    required ApparatusQueuePolicy policy,
  }) async {
    final normalized = _requireCanonicalApparatusId(apparatusId);
    if (await TestModeController.instance.isEnabled()) {
      final catalog = _testModeApparatusCatalog();
      final apparatus = _firstOrNull(
        catalog.where((item) => item.id == normalized),
      );
      if (apparatus == null) {
        throw const MobileApiException(
          code: 'apparatus_not_found',
          message: 'Aparat topilmadi',
        );
      }
      final locked = apparatus.isPechat;
      if (locked && policy != ApparatusQueuePolicy.strictSequence) {
        throw const MobileApiException(
          code: 'queue_policy_locked',
          message: 'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
        );
      }
      final record = AdminApparatusQueuePolicy(
        apparatusId: normalized,
        apparatus: apparatus.name,
        sourceRevision: expectedRevision + 1,
        policy: locked ? ApparatusQueuePolicy.strictSequence : policy,
        locked: locked,
        reason: locked ? 'pechat_always_strict' : '',
      );
      _testModeApparatusQueuePolicies[normalized] = record;
      return record;
    }
    final idempotencyKey = _nextCanonicalMutationIdempotencyKey('queue-policy');
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-policies'),
        headers: _canonicalMutationHeaders(requireToken(), idempotencyKey),
        body: jsonEncode({
          'apparatus_id': normalized,
          'expected_revision': expectedRevision,
          'discipline': policy.apiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_policies');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final committed = payload['revision'];
    if (committed is! Map || committed['revision'] is! Map) {
      throw const MobileApiException(
        code: 'queue_policies_invalid_response',
        message: 'Aparat navbat qoidasi javobi noto‘g‘ri',
      );
    }
    final revision = (committed['revision'] as Map).cast<String, dynamic>();
    final metadata = revision['revision_metadata'];
    final policies = revision['policies'];
    return AdminApparatusQueuePolicy(
      apparatusId: revision['apparatus_id']?.toString().trim() ?? normalized,
      apparatus: '',
      sourceRevision: metadata is Map
          ? (metadata['revision'] as num?)?.toInt() ?? expectedRevision + 1
          : expectedRevision + 1,
      sourceAasxSha256: committed['aasx_sha256']?.toString().trim() ?? '',
      policy: ApparatusQueuePolicy.fromRaw(
        policies is Map ? policies['queue'] : null,
      ),
    );
  }

  Future<AdminApparatusCapacitySnapshot>
      adminApparatusCapacitySnapshot() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminApparatusCapacitySnapshot(
        profiles: List<AdminApparatusCapacityProfile>.unmodifiable(
          _testModeApparatusCapacityProfiles.values,
        ),
        downtimes: List<AdminApparatusDowntime>.unmodifiable(
          _testModeApparatusDowntimes.values,
        ),
        reservations: List<AdminApparatusScheduleReservation>.unmodifiable(
          _testModeApparatusScheduleReservations.values,
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/capacity'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_capacity');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['capacity'];
    if (raw is! List) {
      throw const MobileApiException(
        code: 'apparatus_capacity_invalid_response',
        message: 'Aparat quvvati olinmadi',
      );
    }
    return AdminApparatusCapacitySnapshot(
      profiles: [
        for (final item in raw)
          if (item is Map)
            AdminApparatusCapacityProfile.fromJson(
              item.cast<String, dynamic>(),
            ),
      ],
    );
  }

  Future<AdminApparatusCapacityProfile> adminSaveApparatusCapacityProfile(
    AdminApparatusCapacityProfile profile,
  ) async {
    _requireCanonicalApparatusId(profile.apparatusId);
    if (await TestModeController.instance.isEnabled()) {
      final normalized = _normalizeTestModeCapacityProfile(profile);
      _testModeApparatusCapacityProfiles[normalized.apparatusId] = normalized;
      return normalized;
    }
    final idempotencyKey = _nextCanonicalMutationIdempotencyKey('capacity');
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/capacity'),
        headers: _canonicalMutationHeaders(requireToken(), idempotencyKey),
        body: jsonEncode({
          'apparatus_id': profile.apparatusId.trim(),
          'expected_revision': profile.sourceRevision,
          'capacity': profile.toCanonicalCapacityJson(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_capacity');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final committed = payload['revision'];
    if (committed is! Map || committed['revision'] is! Map) {
      throw const MobileApiException(
        code: 'apparatus_capacity_invalid_response',
        message: 'Aparat profili saqlanmadi',
      );
    }
    final revision = (committed['revision'] as Map).cast<String, dynamic>();
    final metadata = revision['revision_metadata'];
    final capacity = revision['capacity'];
    if (capacity is! Map) {
      throw const MobileApiException(
        code: 'apparatus_capacity_invalid_response',
        message: 'Aparat profili saqlanmadi',
      );
    }
    final availability = capacity['availability'];
    final availabilityMap =
        availability is Map ? availability.cast<String, dynamic>() : const {};
    return AdminApparatusCapacityProfile.fromJson({
      'apparatus_id': revision['apparatus_id'],
      'apparatus': profile.apparatus,
      'source_revision': metadata is Map ? metadata['revision'] : 0,
      'source_aasx_sha256': committed['aasx_sha256'],
      ...capacity.cast<String, dynamic>(),
      'working_windows': availabilityMap['working_windows'] ?? const [],
    });
  }

  Future<AdminApparatusDowntime> adminSaveApparatusDowntime(
    AdminApparatusDowntime downtime,
  ) async {
    _requireCanonicalApparatusId(downtime.apparatusId);
    if (await TestModeController.instance.isEnabled()) {
      final normalized = downtime.id.trim().isEmpty
          ? AdminApparatusDowntime(
              id: 'apparatus-downtime:${DateTime.now().millisecondsSinceEpoch}',
              apparatusId: downtime.apparatusId,
              apparatus: downtime.apparatus,
              startsAtUnix: downtime.startsAtUnix,
              endsAtUnix: downtime.endsAtUnix,
              reason: downtime.reason,
              active: downtime.active,
              createdAtUnix: _testModeUnixSeconds(),
            )
          : downtime;
      _testModeApparatusDowntimes[normalized.id] = normalized;
      return normalized;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/capacity/downtime'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(downtime.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_downtime');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['downtime'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'apparatus_downtime_invalid_response',
        message: 'Aparat downtime saqlanmadi',
      );
    }
    return AdminApparatusDowntime.fromJson(raw.cast<String, dynamic>());
  }

  Future<AdminApparatusScheduleReservation> adminScheduleApparatusOrder({
    required String orderId,
    required String apparatusId,
    required String apparatus,
    required int earliestStartUnix,
    int? latestEndUnix,
    required int durationMinutes,
    int priority = 0,
    String source = 'admin',
    String reason = '',
    String idempotencyKey = '',
    List<AdminApparatusCapabilityRequirement> capabilityRequirements = const [],
    List<AdminApparatusScheduleCandidate> candidateApparatuses = const [],
  }) async {
    final normalizedApparatusId = _requireCanonicalApparatusId(apparatusId);
    for (final candidate in candidateApparatuses) {
      _requireCanonicalApparatusId(candidate.apparatusId);
    }
    final key = idempotencyKey.trim().isEmpty
        ? 'mobile-schedule:${orderId.trim()}:${DateTime.now().microsecondsSinceEpoch}'
        : idempotencyKey.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeScheduleApparatusOrder(
        orderId: orderId,
        apparatusId: normalizedApparatusId,
        apparatus: apparatus,
        earliestStartUnix: earliestStartUnix,
        latestEndUnix: latestEndUnix,
        durationMinutes: durationMinutes,
        priority: priority,
        source: source,
        reason: reason,
        idempotencyKey: key,
        capabilityRequirements: capabilityRequirements,
        candidateApparatuses: candidateApparatuses,
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/schedule'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': orderId.trim(),
          'apparatus_id': normalizedApparatusId,
          'apparatus': apparatus.trim(),
          'earliest_start_unix': earliestStartUnix,
          'latest_end_unix': latestEndUnix,
          'duration_minutes': durationMinutes,
          'priority': priority,
          'source': source,
          'reason': reason,
          'idempotency_key': key,
          'capability_requirements': [
            for (final item in capabilityRequirements) item.toJson(),
          ],
          'candidate_apparatuses': [
            for (final item in candidateApparatuses) item.toJson(),
          ],
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_schedule');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['reservation'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'apparatus_schedule_invalid_response',
        message: 'Aparat jadvali saqlanmadi',
      );
    }
    return AdminApparatusScheduleReservation.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<AdminApparatusScheduleReservation>
      adminCancelApparatusScheduleReservation({
    required String reservationId,
    String reason = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final reservation =
          _testModeApparatusScheduleReservations[reservationId.trim()];
      if (reservation == null) {
        throw const MobileApiException(
          code: 'schedule_reservation_not_found',
          message: 'Jadval bandi topilmadi',
        );
      }
      if (reservation.status != 'planned') {
        throw const MobileApiException(
          code: 'schedule_reservation_locked',
          message: 'Bu jadval bandini bekor qilib bo‘lmaydi',
        );
      }
      final cancelled = AdminApparatusScheduleReservation(
        reservationId: reservation.reservationId,
        idempotencyKey: reservation.idempotencyKey,
        orderId: reservation.orderId,
        apparatusId: reservation.apparatusId,
        apparatus: reservation.apparatus,
        startsAtUnix: reservation.startsAtUnix,
        endsAtUnix: reservation.endsAtUnix,
        requestedDurationMinutes: reservation.requestedDurationMinutes,
        reservedDurationMinutes: reservation.reservedDurationMinutes,
        status: 'cancelled',
        priority: reservation.priority,
        source: reservation.source,
        reason: reason.trim().isEmpty
            ? reservation.reason
            : '${reservation.reason}; cancelled: ${reason.trim()}',
        capabilityRequirements: reservation.capabilityRequirements,
        createdAtUnix: reservation.createdAtUnix,
      );
      _testModeApparatusScheduleReservations[cancelled.reservationId] =
          cancelled;
      return cancelled;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/schedule/cancel'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'reservation_id': reservationId.trim(),
          'reason': reason,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_schedule_cancel');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['reservation'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'apparatus_schedule_invalid_response',
        message: 'Jadval bandi bekor qilinmadi',
      );
    }
    return AdminApparatusScheduleReservation.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Uri adminProductionMapLiveUri() {
    final Uri base = Uri.parse(baseUrl);
    final String scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return base.replace(
      scheme: scheme,
      path: '/v1/mobile/admin/production-maps/live',
      queryParameters: {'token': requireToken()},
    );
  }

  Stream<AdminProductionMapLiveSnapshot> adminProductionMapLiveEvents() async* {
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    await for (final event in connectWarehouseLive(
      adminProductionMapLiveUri(),
    )) {
      if (event['ok'] == true) {
        yield AdminProductionMapLiveSnapshot.fromJson(event);
        continue;
      }
      final errorCode = event['error']?.toString().trim() ?? '';
      throw MobileApiException(
        code: errorCode.isEmpty ? 'production_map_live_failed' : errorCode,
        message: _adminProductionMapUnknownErrorMessage(
          code: errorCode,
          fallbackCode: 'production_map_live_failed',
          statusCode: 0,
        ),
      );
    }
  }

  Future<List<AdminRawMaterialRule>> adminRawMaterialRules() async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeRawMaterialRules.values.toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-rules'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_rules');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRawMaterialRule.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminRawMaterialRule> adminSaveRawMaterialRule({
    required AdminApparatus apparatus,
    required AdminRawMaterialRule currentRule,
    bool requiresMaterial = false,
    AdminRawMaterialStartPolicy startPolicy =
        AdminRawMaterialStartPolicy.stateAll,
    required List<String> itemGroups,
    List<AdminRawMaterialRequirementGroup> requirementGroups = const [],
  }) async {
    final apparatusId = apparatus.id.trim();
    if (apparatusId.isEmpty || currentRule.apparatusId != apparatusId) {
      throw const MobileApiException(
        code: 'canonical_apparatus_identity_required',
        message: 'Aparatning canonical ID ma’lumoti mos emas',
      );
    }
    if (currentRule.sourceRevision < 1) {
      throw const MobileApiException(
        code: 'canonical_apparatus_revision_required',
        message: 'Aparat revision ma’lumoti topilmadi. Qayta yuklang.',
      );
    }
    final normalizedGroups = itemGroups
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final normalizedRequirementGroups = [
      for (final item in requirementGroups)
        AdminRawMaterialRequirementGroup(
          name: item.name.trim(),
          itemGroups: item.itemGroups
              .map((group) => group.trim())
              .where((group) => group.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
          minRequiredCount: item.minRequiredCount,
        ),
    ]
      ..removeWhere(
        (item) => item.name.isEmpty || item.itemGroups.isEmpty,
      )
      ..sort((left, right) => left.name.compareTo(right.name));
    if (requiresMaterial &&
        (normalizedGroups.isEmpty ||
            (startPolicy == AdminRawMaterialStartPolicy.requirementGroups &&
                (normalizedRequirementGroups.isEmpty ||
                    normalizedRequirementGroups.any(
                      (group) =>
                          group.minRequiredCount < 1 ||
                          group.minRequiredCount > group.itemGroups.length,
                    ))))) {
      throw const MobileApiException(
        code: 'raw_material_policy_required',
        message: 'Canonical homashyo talabi to‘liq kiritilmadi',
      );
    }
    final pendingRule = currentRule.copyWith(
      apparatus: apparatus.name.trim(),
      requiresMaterial: requiresMaterial,
      startPolicy: startPolicy,
      itemGroups: normalizedGroups,
      requirementGroups: normalizedRequirementGroups,
    );
    if (await TestModeController.instance.isEnabled()) {
      final rule = pendingRule.copyWith(
        sourceRevision: currentRule.sourceRevision + 1,
      );
      _testModeRawMaterialRules[apparatusId] = rule;
      return rule;
    }
    final idempotencyKey =
        _nextCanonicalMutationIdempotencyKey('material-policy');
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-rules'),
        headers: _canonicalMutationHeaders(requireToken(), idempotencyKey),
        body: jsonEncode({
          'apparatus_id': apparatusId,
          'expected_revision': currentRule.sourceRevision,
          'material': pendingRule.materialPolicyJson(),
          'tooling': currentRule.toolingPolicyJson(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_rules');
    }
    final saved = AdminRawMaterialRule.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    if (saved.apparatusId != apparatusId ||
        saved.sourceRevision <= currentRule.sourceRevision) {
      throw const MobileApiException(
        code: 'raw_material_rule_commit_mismatch',
        message: 'Backend canonical material revisionni tasdiqlamadi',
      );
    }
    return saved.copyWith(apparatus: apparatus.name.trim());
  }

  Future<AdminRawMaterialStartRequirements> adminRawMaterialStartRequirements({
    required String orderId,
    required String apparatus,
    List<String> materialBarcodes = const [],
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      AdminRawMaterialRule? rule;
      for (final candidate in _testModeRawMaterialRules.values) {
        if (candidate.apparatusId.trim() == normalizedApparatus) {
          rule = candidate;
          break;
        }
      }
      final orderAssignments = _testModeRawMaterialAssignments
          .where((assignment) => assignment.orderId.trim() == normalizedOrderId)
          .toList(growable: false);
      final assignments = orderAssignments
          .where(
            (assignment) => assignment.apparatus.trim() == normalizedApparatus,
          )
          .toList(growable: false);
      final assignedBarcodes = {
        for (final assignment in assignments)
          _normalizeRawMaterialBarcode(assignment.barcode),
      }..remove('');
      final stagedBarcodes = <String>{};
      for (final asset in _testModeInventoryAssets) {
        final barcode = _normalizeRawMaterialBarcode(asset.identifier);
        if (asset.kind != InventoryAssetKind.rawMaterial ||
            asset.physicalLocation.kind != InventoryLocationKind.state ||
            asset.status.trim().toLowerCase() == 'consumed' ||
            !assignedBarcodes.contains(barcode)) {
          continue;
        }
        final locations = _testModeInventoryLocations.where(
          (location) =>
              location.active &&
              location.isState &&
              location.id == asset.physicalLocation.id,
        );
        if (locations.any(
          (location) => location.apparatus.any(
            (linked) => linked.id.trim() == normalizedApparatus,
          ),
        )) {
          stagedBarcodes.add(barcode);
        }
      }
      final requirementGroups = rule == null
          ? const <AdminRawMaterialRequirementGroup>[]
          : rule.requirementGroups.isNotEmpty
              ? rule.requirementGroups
              : [
                  for (final itemGroup in rule.itemGroups)
                    AdminRawMaterialRequirementGroup(
                      name: itemGroup,
                      itemGroups: [itemGroup],
                    ),
                ];
      final scannedBarcodes = materialBarcodes
          .map(_normalizeRawMaterialBarcode)
          .where((barcode) => barcode.isNotEmpty)
          .toSet();
      final policy = rule?.startPolicy ?? AdminRawMaterialStartPolicy.stateAll;
      final eligibleBarcodes = policy == AdminRawMaterialStartPolicy.stateAll
          ? stagedBarcodes
          : assignedBarcodes;
      final eligibleAssignments = assignments
          .where(
            (assignment) => eligibleBarcodes.contains(
              _normalizeRawMaterialBarcode(assignment.barcode),
            ),
          )
          .toList(growable: false);
      final policyRequiredScanCount =
          policy == AdminRawMaterialStartPolicy.stateAll
              ? stagedBarcodes.length
              : requirementGroups.fold<int>(
                  0,
                  (total, group) =>
                      total +
                      (group.minRequiredCount < 1 ? 1 : group.minRequiredCount),
                );
      final policyMatchedScanCount =
          policy == AdminRawMaterialStartPolicy.stateAll
              ? scannedBarcodes.intersection(stagedBarcodes).length
              : _testModeMatchedRawMaterialRequirementCount(
                  requirementGroups: requirementGroups,
                  assignments: assignments,
                  barcodes: scannedBarcodes,
                );
      final assignedMatchedCount = _testModeMatchedRawMaterialRequirementCount(
        requirementGroups: requirementGroups,
        assignments: assignments,
        barcodes: assignedBarcodes,
      );
      final requiresMaterial = rule?.requiresMaterial ?? false;
      final assignmentsSatisfied = assignments.isEmpty
          ? !requiresMaterial
          : !requiresMaterial ||
              policy != AdminRawMaterialStartPolicy.requirementGroups ||
              assignedMatchedCount == policyRequiredScanCount;
      final scanSatisfied = assignments.isEmpty && !requiresMaterial ||
          assignments.isNotEmpty &&
              scannedBarcodes.isNotEmpty &&
              assignedBarcodes.containsAll(scannedBarcodes) &&
              (policy == AdminRawMaterialStartPolicy.stateAll
                  ? setEquals(scannedBarcodes, stagedBarcodes)
                  : policyRequiredScanCount > 0 &&
                      policyMatchedScanCount == policyRequiredScanCount);
      return AdminRawMaterialStartRequirements(
        policy: policy,
        requiresMaterial: requiresMaterial,
        requirementGroups: requirementGroups,
        assignedBarcodes: assignedBarcodes.toList(growable: false),
        stagedBarcodes: stagedBarcodes.toList(growable: false),
        assignments: orderAssignments,
        startAssignments: eligibleAssignments,
        requiredScanCount: policyRequiredScanCount,
        matchedScanCount: policyMatchedScanCount,
        assignmentsSatisfied: assignmentsSatisfied,
        scanSatisfied: scanSatisfied,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-start-requirements',
        ).replace(
          queryParameters: {
            'order_id': normalizedOrderId,
            'apparatus': normalizedApparatus,
            if (materialBarcodes.isNotEmpty)
              'material_barcodes': materialBarcodes.join(','),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'raw_material_start_requirements',
      );
    }
    return AdminRawMaterialStartRequirements.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminRawMaterialAssignment>> adminRawMaterialAssignments({
    String orderId = '',
    String apparatus = '',
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(
      apparatus,
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminRawMaterialAssignment>.unmodifiable(
        _testModeRawMaterialAssignments.where(
          (assignment) =>
              (orderId.trim().isEmpty ||
                  assignment.orderId.trim() == orderId.trim()) &&
              (normalizedApparatus.isEmpty ||
                  assignment.apparatus.trim() == normalizedApparatus),
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments').replace(
          queryParameters: {
            if (orderId.trim().isNotEmpty) 'order_id': orderId.trim(),
            if (normalizedApparatus.isNotEmpty)
              'apparatus': normalizedApparatus,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminRawMaterialAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ProductionMapSaved>> adminRawMaterialAssignmentOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<ProductionMapSaved>.unmodifiable(
        _testModeProductionMaps.where(
          (saved) => saved.map.id.trim().startsWith('zakaz-'),
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments/orders'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'raw_material_assignment_orders',
      );
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => ProductionMapSaved.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AdminRawMaterialAssignmentCandidate>>
      adminRawMaterialAssignmentCandidates({
    required String orderId,
    String apparatus = '',
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = _requireCanonicalApparatusId(
      apparatus,
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      final profile = AppSession.instance.profile;
      final assignedApparatus = profile?.role == UserRole.materialTaminotchi
          ? profile?.assignedApparatus ?? const <String>[]
          : null;
      if (assignedApparatus != null &&
          normalizedApparatus.isNotEmpty &&
          !assignedApparatus.any(
            (assigned) => assigned.trim() == normalizedApparatus,
          )) {
        throw const MobileApiException(
          code: 'apparatus_not_assigned',
          message: 'Bu aparat sizga biriktirilmagan',
        );
      }
      final assignedBarcodes = _testModeRawMaterialAssignments
          .map((assignment) => assignment.barcode.trim().toUpperCase())
          .toSet();
      final items = {
        for (final item in TestModeDemoData.itemPage(limit: 0))
          item.code.trim().toLowerCase(): item,
      };
      final candidates = <AdminRawMaterialAssignmentCandidate>[];
      for (final stock in TestModeDemoData.rawMaterialStock) {
        final item = items[stock.itemCode.trim().toLowerCase()];
        if (item == null ||
            stock.status.trim().toLowerCase() != 'available' ||
            stock.reservedOrderId.trim().isNotEmpty ||
            assignedBarcodes.contains(stock.barcode.trim().toUpperCase())) {
          continue;
        }
        final apparatusOptions = _testModeRawMaterialRules.values
            .where(
              (rule) => rule.itemGroups.any(
                (group) =>
                    group.trim().toLowerCase() ==
                    item.itemGroup.trim().toLowerCase(),
              ),
            )
            .map((rule) => rule.apparatusId.trim())
            .where((apparatus) => apparatus.isNotEmpty)
            .where(
              (apparatus) =>
                  assignedApparatus == null ||
                  assignedApparatus.any(
                    (assigned) => assigned.trim() == apparatus,
                  ),
            )
            .where(
              (apparatus) =>
                  normalizedApparatus.isEmpty ||
                  apparatus == normalizedApparatus,
            )
            .toSet()
            .toList(growable: false);
        if (apparatusOptions.isEmpty) {
          continue;
        }
        candidates.add(
          AdminRawMaterialAssignmentCandidate(
            barcode: stock.barcode,
            warehouse: stock.warehouse,
            itemCode: stock.itemCode,
            itemName: item.name,
            itemGroup: item.itemGroup,
            qty: stock.qty,
            uom: stock.uom,
            apparatusOptions: apparatusOptions,
          ),
        );
      }
      return List<AdminRawMaterialAssignmentCandidate>.unmodifiable(candidates);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-assignments/candidates',
        ).replace(
          queryParameters: {
            'order_id': normalizedOrderId,
            if (normalizedApparatus.isNotEmpty)
              'apparatus': normalizedApparatus,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'raw_material_assignment_candidates',
      );
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRawMaterialAssignmentCandidate.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<AdminRawMaterialAssignmentOrderCandidate>>
      adminRawMaterialAssignmentCandidateOrders(
          {required String barcode}) async {
    final normalizedBarcode = barcode.trim();
    if (await TestModeController.instance.isEnabled()) {
      final assigned = _testModeRawMaterialAssignments.any(
        (assignment) =>
            assignment.barcode.trim().toUpperCase() ==
            normalizedBarcode.toUpperCase(),
      );
      if (assigned) {
        return const [];
      }
      final candidates = <AdminRawMaterialAssignmentOrderCandidate>[];
      for (final order in await adminRawMaterialAssignmentOrders()) {
        final materials = await adminRawMaterialAssignmentCandidates(
          orderId: order.map.id,
        );
        for (final material in materials) {
          if (material.barcode.trim().toUpperCase() ==
              normalizedBarcode.toUpperCase()) {
            candidates.add(
              AdminRawMaterialAssignmentOrderCandidate(
                order: order,
                apparatusOptions: material.apparatusOptions,
              ),
            );
            break;
          }
        }
      }
      return List<AdminRawMaterialAssignmentOrderCandidate>.unmodifiable(
        candidates,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-assignments/candidate-orders',
        ).replace(queryParameters: {'barcode': normalizedBarcode}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'raw_material_assignment_candidate_orders',
      );
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRawMaterialAssignmentOrderCandidate.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<AdminRawMaterialAssignment>> adminRawMaterialIntakeCandidates({
    required String orderId,
    required String apparatus,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      final isActive = _testModeApparatusQueueStates.entries.any(
        (entry) =>
            entry.key.trim() == normalizedApparatus &&
            switch (apparatusQueueOrderStateFromRaw(
              entry.value[normalizedOrderId],
            )) {
              ApparatusQueueOrderState.inProgress ||
              ApparatusQueueOrderState.paused =>
                true,
              _ => false,
            },
      );
      if (!isActive ||
          _testModeOrderControls[normalizedOrderId] ==
              AdminOrderControlState.frozen ||
          _testModeOrderControls[normalizedOrderId] ==
              AdminOrderControlState.freezeRequested) {
        return const [];
      }
      AdminRawMaterialRule? rule;
      for (final candidate in _testModeRawMaterialRules.values) {
        if (candidate.apparatusId.trim() == normalizedApparatus) {
          rule = candidate;
          break;
        }
      }
      return List<AdminRawMaterialAssignment>.unmodifiable(
        _testModeRawMaterialAssignments.where((assignment) {
          if (assignment.orderId.trim() != normalizedOrderId ||
              assignment.apparatus.trim() != normalizedApparatus ||
              !_testModeRawMaterialMatchesRule(assignment, rule)) {
            return false;
          }
          final asset = _testModeRawMaterialAssetAtApparatus(
            barcode: assignment.barcode,
            apparatus: normalizedApparatus,
          );
          if (asset == null ||
              asset.status.trim().toLowerCase() != 'available') {
            return false;
          }
          final status = assignment.stockStatus.trim().toLowerCase();
          return (status.isEmpty || status == 'available') &&
              assignment.reservedOrderId.trim().isEmpty;
        }),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-intake-candidates',
        ).replace(
          queryParameters: {
            'order_id': normalizedOrderId,
            'apparatus': normalizedApparatus,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'raw_material_intake_candidates',
      );
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminRawMaterialAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AdminRawMaterialEvent>> adminRawMaterialHistory({
    String warehouse = '',
    String eventType = '',
    int limit = 50,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return const [];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-history').replace(
          queryParameters: {
            if (warehouse.trim().isNotEmpty) 'warehouse': warehouse.trim(),
            if (eventType.trim().isNotEmpty) 'event_type': eventType.trim(),
            if (limit > 0) 'limit': '$limit',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw const MobileApiException(
          code: 'raw_material_history_not_found',
          message: 'Serverda tarix endpointi yo‘q',
          statusCode: 404,
        );
      }
      throw _adminProductionMapException(response, 'raw_material_history');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              AdminRawMaterialEvent.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminRawMaterialAssignment> adminAssignRawMaterialToOrder({
    required String orderId,
    required String barcode,
    String apparatus = '',
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(
      apparatus,
      allowEmpty: true,
    );
    final body = {
      'order_id': orderId.trim(),
      'barcode': barcode.trim(),
      if (normalizedApparatus.isNotEmpty) 'apparatus': normalizedApparatus,
    };
    if (await TestModeController.instance.isEnabled()) {
      final assignment = AdminRawMaterialAssignment(
        orderId: body['order_id']!,
        apparatus: body['apparatus'] ?? '',
        barcode: body['barcode']!,
        itemCode: '',
        itemName: '',
        itemGroup: '',
        assignedByRef: AppSession.instance.profile?.ref ?? '',
        assignedByName: AppSession.instance.profile?.displayName ?? '',
        stockStatus: 'available',
      );
      final assignmentBarcode = assignment.barcode.trim().toUpperCase();
      final existing = _testModeRawMaterialAssignments.where(
        (item) => item.barcode.trim().toUpperCase() == assignmentBarcode,
      );
      for (final item in existing) {
        if (item.orderId.trim() == assignment.orderId.trim()) {
          throw const MobileApiException(
            code: 'raw_material_already_assigned_to_order',
            message: 'Bu homashyo allaqachon shu zakazga ulangan',
          );
        }
        throw const MobileApiException(
          code: 'raw_material_already_assigned',
          message: 'Bu homashyo boshqa zakaz uchun band qilingan',
        );
      }
      _testModeRawMaterialAssignments.removeWhere(
        (item) =>
            item.orderId.trim() == assignment.orderId.trim() &&
            item.barcode.trim() == assignment.barcode.trim(),
      );
      _testModeRawMaterialAssignments.add(assignment);
      return assignment;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    return AdminRawMaterialAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminRawMaterialAssignment> adminReceiveRawMaterialForActiveOrder({
    required String orderId,
    required String apparatus,
    required String barcode,
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    final body = {
      'order_id': orderId.trim(),
      'apparatus': normalizedApparatus,
      'barcode': barcode.trim(),
    };
    if (await TestModeController.instance.isEnabled()) {
      final normalizedBarcode = body['barcode']!.toUpperCase();
      final existingIndex = _testModeRawMaterialAssignments.indexWhere(
        (item) => item.barcode.trim().toUpperCase() == normalizedBarcode,
      );
      if (existingIndex >= 0) {
        final existing = _testModeRawMaterialAssignments[existingIndex];
        if (existing.orderId.trim() != body['order_id'] ||
            existing.apparatus.trim() != body['apparatus']!) {
          throw const MobileApiException(
            code: 'raw_material_already_assigned',
            message: 'Bu homashyo boshqa zakaz uchun band qilingan',
          );
        }
        final active = _testModeApparatusQueueStates.entries.any(
          (entry) =>
              entry.key.trim() == body['apparatus']! &&
              switch (apparatusQueueOrderStateFromRaw(
                entry.value[body['order_id']],
              )) {
                ApparatusQueueOrderState.inProgress ||
                ApparatusQueueOrderState.paused =>
                  true,
                _ => false,
              },
        );
        if (!active) {
          throw const MobileApiException(
            code: 'raw_material_order_not_active',
            message:
                'Yana homashyo faqat ish boshlangan yoki pauzadagi zakazga olinadi',
          );
        }
        final asset = _testModeRawMaterialAssetAtApparatus(
          barcode: existing.barcode,
          apparatus: existing.apparatus,
        );
        if (asset == null) {
          throw const MobileApiException(
            code: 'raw_material_state_not_ready',
            message: 'Apparat oldiga homashyo olib kelinmagan',
          );
        }
        if ((existing.stockStatus.trim().isNotEmpty &&
                existing.stockStatus.trim().toLowerCase() != 'available') ||
            asset.status.trim().toLowerCase() != 'available') {
          throw const MobileApiException(
            code: 'raw_material_stock_unavailable',
            message: 'Bu homashyo allaqachon ishga olingan yoki mavjud emas',
          );
        }
        final updated = existing.copyWith(
          stockStatus: 'in_use',
          reservedOrderId: body['order_id'],
          stockWarehouse: asset.custodyWarehouse,
          stockQty: asset.qty,
          stockUom: asset.uom,
          receivedQty: asset.qty,
          remainingQty: asset.qty,
        );
        _testModeRawMaterialAssignments[existingIndex] = updated;
        final assetIndex = _testModeInventoryAssets.indexOf(asset);
        if (assetIndex >= 0) {
          _testModeInventoryAssets[assetIndex] = asset.copyWith(
            status: 'in_use',
          );
        }
        return updated;
      }
      if (body['order_id']!.isEmpty || body['apparatus']!.isEmpty) {
        throw const MobileApiException(
          code: 'raw_material_invalid_input',
          message: 'Homashyo QR noto‘g‘ri',
        );
      }
      throw const MobileApiException(
        code: 'raw_material_assignment_not_found',
        message: 'Homashyo biriktirilmagan',
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-intake'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_intake');
    }
    return AdminRawMaterialAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminRawMaterialAssignment> adminUnlinkRawMaterialAssignment({
    required String orderId,
    required String barcode,
  }) async {
    final body = {'order_id': orderId.trim(), 'barcode': barcode.trim()};
    if (await TestModeController.instance.isEnabled()) {
      final normalizedOrderId = body['order_id']!;
      final normalizedBarcode = body['barcode']!.toUpperCase();
      final index = _testModeRawMaterialAssignments.indexWhere(
        (item) =>
            item.orderId.trim() == normalizedOrderId &&
            item.barcode.trim().toUpperCase() == normalizedBarcode,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'raw_material_assignment_not_found',
          message: 'Homashyo biriktirilmagan',
        );
      }
      return _testModeRawMaterialAssignments.removeAt(index);
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(body),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final assignment = decoded['assignment'];
    return AdminRawMaterialAssignment.fromJson(
      assignment is Map<String, dynamic> ? assignment : decoded,
    );
  }

  Future<AdminRawMaterialLookup> adminRawMaterialLookup({
    required String barcode,
  }) async {
    final normalized = barcode.trim();
    if (await TestModeController.instance.isEnabled()) {
      AdminRawMaterialAssignment? assignment;
      for (final item in _testModeRawMaterialAssignments) {
        if (item.barcode.trim().toUpperCase() == normalized.toUpperCase()) {
          assignment = item;
          break;
        }
      }
      ProductionMapDefinition? order;
      if (assignment != null) {
        for (final saved in _testModeProductionMaps) {
          if (saved.map.id.trim() == assignment.orderId.trim()) {
            order = saved.map;
            break;
          }
        }
      }
      return AdminRawMaterialLookup(
        barcode: normalized,
        warehouse: assignment?.stockWarehouse ?? '',
        itemCode: assignment?.itemCode ?? '',
        itemName: assignment?.itemName ?? '',
        itemGroup: assignment?.itemGroup ?? '',
        qty: assignment?.stockQty ?? 0,
        uom: assignment?.stockUom ?? '',
        status: assignment?.stockStatus ?? '',
        reservedOrderId: assignment?.reservedOrderId ?? '',
        assignment: assignment,
        order: order,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-assignments/lookup',
        ).replace(queryParameters: {'barcode': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_assignments');
    }
    return AdminRawMaterialLookup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Map<String, List<String>> parseApparatusSequenceMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final apparatusId = entry.key.toString().trim();
      if (!isCanonicalApparatusId(apparatusId) || entry.value is! List) {
        throw _productionMapQueueContractException(
          'sequences contains an invalid apparatus',
        );
      }
      final orderIds = <String>[];
      for (final rawOrderId in entry.value as List) {
        final orderId = rawOrderId.toString().trim();
        if (orderId.isEmpty) {
          throw _productionMapQueueContractException(
            'sequences contains an invalid order',
          );
        }
        orderIds.add(orderId);
      }
      result[apparatusId] = List<String>.unmodifiable(orderIds);
    }
    return Map<String, List<String>>.unmodifiable(result);
  }

  Map<String, Map<String, List<String>>> parseNestedSequenceMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        entry.key.toString(): {
          if (entry.value is Map)
            for (final nested in (entry.value as Map).entries)
              nested.key.toString(): [
                if (nested.value is List)
                  for (final id in nested.value as List) id.toString(),
              ],
        },
    };
  }

  Map<String, Map<String, String>> parseApparatusQueueStateMap(Object? raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <String, Map<String, String>>{};
    for (final entry in raw.entries) {
      final apparatusId = entry.key.toString().trim();
      if (!isCanonicalApparatusId(apparatusId) || entry.value is! Map) {
        throw _productionMapQueueContractException(
          'queue_states contains an invalid apparatus',
        );
      }
      final states = <String, String>{};
      for (final stateEntry in (entry.value as Map).entries) {
        final orderId = stateEntry.key.toString().trim();
        final state = stateEntry.value.toString().trim().toLowerCase();
        if (orderId.isEmpty || !_knownApparatusQueueStates.contains(state)) {
          throw _productionMapQueueContractException(
            'queue_states contains an invalid order state',
          );
        }
        states[orderId] = state;
      }
      result[apparatusId] = Map<String, String>.unmodifiable(states);
    }
    return Map<String, Map<String, String>>.unmodifiable(result);
  }

  Map<String, AdminApparatusQueuePolicy> parseApparatusQueuePolicyMap(
    Object? raw,
  ) {
    final values = raw is Map
        ? raw.values
        : raw is List
            ? raw
            : const [];
    final policies = <String, AdminApparatusQueuePolicy>{};
    for (final item in values) {
      if (item is! Map) {
        throw _productionMapQueueContractException(
          'queue_policies contains an invalid item',
        );
      }
      final policy = AdminApparatusQueuePolicy.fromJson(
        item.cast<String, dynamic>(),
      );
      final apparatusId = _requireCanonicalApparatusId(policy.apparatusId);
      policies[apparatusId] = policy;
    }
    return policies;
  }

  Future<Map<String, String>> adminApparatusQueueAction({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    String qolipCode = '',
    List<String> qolipCodes = const [],
    double? producedQty,
    double? grossQty,
    double? bobinaKg,
    double? diameter,
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    List<Map<String, dynamic>> rezkaFrames = const [],
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String customerName = '',
    String driverUrl = '',
    PrintTransport printTransport = PrintTransport.wifi,
    String printer = '',
    String printMode = '',
    String completionRequestNote = '',
    List<ReturnedPaintItemInput> returnedPaintItems = const [],
    String returnedPaintImageId = '',
    bool fullCompletionReportRequired = false,
  }) async {
    final result = await adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      materialBarcode: materialBarcode,
      materialBarcodes: materialBarcodes,
      qolipCode: qolipCode,
      qolipCodes: qolipCodes,
      producedQty: producedQty,
      grossQty: grossQty,
      bobinaKg: bobinaKg,
      diameter: diameter,
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      finishedGoodsMeter: finishedGoodsMeter,
      rezkaFrames: rezkaFrames,
      uom: uom,
      qrPayload: qrPayload,
      progressBatchId: progressBatchId,
      customerName: customerName,
      driverUrl: driverUrl,
      printTransport: printTransport,
      printer: printer,
      printMode: printMode,
      completionRequestNote: completionRequestNote,
      returnedPaintItems: returnedPaintItems,
      returnedPaintImageId: returnedPaintImageId,
      fullCompletionReportRequired: fullCompletionReportRequired,
    );
    return result.states;
  }

  Future<String> adminValidateProductionMapQolip({
    required String apparatus,
    required String orderId,
    required String qolipCode,
  }) async {
    final validation = await adminValidateProductionMapQolipDetails(
      apparatus: apparatus,
      orderId: orderId,
      qolipCode: qolipCode,
    );
    return validation.qolipCode;
  }

  Future<AdminProductionMapQolipValidation>
      adminProductionMapQolipRequirements({
    required String apparatus,
    required String orderId,
  }) {
    return adminValidateProductionMapQolipDetails(
      apparatus: apparatus,
      orderId: orderId,
      qolipCode: '',
    );
  }

  Future<AdminProductionMapQolipValidation>
      adminValidateProductionMapQolipDetails({
    required String apparatus,
    required String orderId,
    required String qolipCode,
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      if (qolipCode.trim().isEmpty) {
        ProductionMapSaved? order;
        for (final candidate in _testModeProductionMaps) {
          if (candidate.map.id.trim() == orderId.trim()) {
            order = candidate;
            break;
          }
        }
        final itemCode = order?.map.productCode.trim() ?? '';
        final products = itemCode.isEmpty
            ? const <QolipProduct>[]
            : await qolipProducts(
                query: itemCode,
                limit: 20000,
                withQolipOnly: true,
              );
        return AdminProductionMapQolipValidation(
          qolipCode: '',
          requiredQolips: [
            for (final product in products)
              if (product.code.trim().toLowerCase() == itemCode.toLowerCase() &&
                  product.qolipCode.trim().isNotEmpty)
                AdminProductionMapRequiredQolip(
                  qolipCode: product.qolipCode.trim(),
                  color: product.qolipColor.trim(),
                ),
          ],
        );
      }
      final product = await qolipProductByQr(qolipCode);
      final products = await qolipProducts(
        query: product.code,
        limit: 20000,
        withQolipOnly: true,
      );
      return AdminProductionMapQolipValidation(
        qolipCode: product.qolipCode.trim().isEmpty
            ? qolipCode.trim()
            : product.qolipCode.trim(),
        requiredQolips: [
          for (final candidate in products)
            if (candidate.code.trim().toLowerCase() ==
                    product.code.trim().toLowerCase() &&
                candidate.qolipCode.trim().isNotEmpty)
              AdminProductionMapRequiredQolip(
                qolipCode: candidate.qolipCode.trim(),
                color: candidate.qolipColor.trim(),
              ),
        ],
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/qolip-validate'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': orderId.trim(),
          'qolip_code': qolipCode.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'qolip_code_not_found');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawQolip = payload['qolip'];
    if (rawQolip is Map) {
      return AdminProductionMapQolipValidation.fromJson(
        rawQolip.cast<String, dynamic>(),
      );
    }
    return AdminProductionMapQolipValidation(qolipCode: qolipCode.trim());
  }

  Future<AdminQolipOrderNoteDetails> adminProductionMapQolipOrderNoteDetails({
    required String orderId,
  }) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw const MobileApiException(
        code: 'order_id_required',
        message: 'Order identifikatori topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      ProductionMapSaved? order;
      for (final candidate in _testModeProductionMaps) {
        if (candidate.map.id.trim() == normalizedOrderId) {
          order = candidate;
          break;
        }
      }
      if (order == null) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Order topilmadi',
        );
      }
      final itemCode = order.map.productCode.trim();
      final products = itemCode.isEmpty
          ? const <QolipProduct>[]
          : await qolipProducts(
              query: itemCode,
              limit: 20000,
              withQolipOnly: true,
            );
      final requiredQolips = <AdminProductionMapRequiredQolip>[];
      final seen = <String>{};
      final inUseCodes = <String>{};
      for (final entry in _testModeQolipOrderNotes.entries) {
        if (entry.key == normalizedOrderId || !entry.value.isGiven) {
          continue;
        }
        inUseCodes.addAll(
          entry.value.qolipCodes.map((code) => code.trim().toLowerCase()),
        );
      }
      for (final product in products) {
        final code = product.qolipCode.trim();
        if (product.code.trim().toLowerCase() != itemCode.toLowerCase() ||
            code.isEmpty ||
            !seen.add(code.toLowerCase())) {
          continue;
        }
        requiredQolips.add(
          AdminProductionMapRequiredQolip(
            qolipCode: code,
            color: product.qolipColor.trim(),
            isInUse: inUseCodes.contains(code.toLowerCase()),
          ),
        );
      }
      return AdminQolipOrderNoteDetails(
        orderId: normalizedOrderId,
        itemCode: itemCode,
        itemName: order.map.title.trim(),
        requiredQolips: requiredQolips,
        note: _testModeQolipOrderNotes[normalizedOrderId],
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/qolip-order-notes',
        ).replace(queryParameters: {'order_id': normalizedOrderId}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'qolip_order_note_load_failed',
      );
    }
    return AdminQolipOrderNoteDetails.fromJson(
      await decodeJsonMapPayload(response.body),
    );
  }

  Future<List<AdminQolipOrderNote>> adminProductionMapQolipOrderNotes() async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeQolipOrderNotes.values.toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/qolip-order-notes'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'qolip_order_notes_load_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawNotes = payload['notes'];
    return [
      if (rawNotes is List)
        for (final item in rawNotes)
          if (item is Map)
            AdminQolipOrderNote.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<AdminQolipOrderNote> adminSaveProductionMapQolipOrderNote({
    required String orderId,
    required String status,
    List<String> qolipCodes = const [],
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedStatus = status.trim().toLowerCase();
    if (await TestModeController.instance.isEnabled()) {
      final details = await adminProductionMapQolipOrderNoteDetails(
        orderId: normalizedOrderId,
      );
      if (normalizedStatus == 'returned') {
        final existing = details.note;
        if (existing == null) {
          throw const MobileApiException(
            code: 'qolip_order_note_not_found',
            message: 'Bu order uchun berilgan qolip qaydi topilmadi',
          );
        }
        final returned = AdminQolipOrderNote(
          orderId: existing.orderId,
          itemCode: existing.itemCode,
          itemName: existing.itemName,
          qolipCodes: existing.qolipCodes,
          status: 'returned',
        );
        _testModeQolipOrderNotes[normalizedOrderId] = returned;
        return returned;
      }
      if (normalizedStatus != 'given') {
        throw const MobileApiException(
          code: 'qolip_order_note_status_invalid',
          message: 'Qolip qaydi holati noto‘g‘ri',
        );
      }
      final requiredCodes = details.requiredQolips
          .map((item) => item.qolipCode.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
      final selectedCodes = <String>[];
      for (final rawCode in qolipCodes) {
        final code = rawCode.trim();
        if (code.isEmpty) continue;
        if (!requiredCodes.contains(code.toLowerCase())) {
          throw const MobileApiException(
            code: 'qolip_code_mismatch',
            message: 'Tanlangan qolip bu order mahsulotiga tegishli emas',
          );
        }
        if (!selectedCodes.any(
          (saved) => saved.toLowerCase() == code.toLowerCase(),
        )) {
          selectedCodes.add(code);
        }
      }
      if (selectedCodes.isEmpty) {
        throw const MobileApiException(
          code: 'qolip_code_required',
          message: 'Kamida bitta qolipni tanlang',
        );
      }
      for (final entry in _testModeQolipOrderNotes.entries) {
        if (entry.key == normalizedOrderId || !entry.value.isGiven) {
          continue;
        }
        final occupied = entry.value.qolipCodes.any(
          (saved) => selectedCodes.any(
            (selected) => saved.trim().toLowerCase() == selected.toLowerCase(),
          ),
        );
        if (occupied) {
          throw const MobileApiException(
            code: 'qolip_order_note_in_use',
            message: 'Bu qolip boshqa order uchun band qilingan',
          );
        }
      }
      final note = AdminQolipOrderNote(
        orderId: details.orderId,
        itemCode: details.itemCode,
        itemName: details.itemName,
        qolipCodes: selectedCodes,
        status: 'given',
      );
      _testModeQolipOrderNotes[normalizedOrderId] = note;
      return note;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/qolip-order-notes'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          'status': normalizedStatus,
          'qolip_codes': qolipCodes
              .map((code) => code.trim())
              .where((code) => code.isNotEmpty)
              .toList(growable: false),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'qolip_order_note_save_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawNote = payload['note'];
    if (rawNote is! Map) {
      throw const MobileApiException(
        code: 'qolip_order_note_invalid_response',
        message: 'Qolip qaydi javobi noto‘g‘ri',
      );
    }
    return AdminQolipOrderNote.fromJson(rawNote.cast<String, dynamic>());
  }

  Future<AdminLaminatsiyaAstatkaReport> adminLaminatsiyaAstatkaReport({
    required String apparatus,
    required String orderId,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? totalWaste,
    double? finishedGoodsMeter,
    double? finishedGoodsKg,
    double? bobinaKg,
    String description = '',
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedOrderId = orderId.trim();
    bool isNonNegative(double? value) =>
        value != null && value.isFinite && value >= 0;
    bool isPositive(double? value) =>
        value != null && value.isFinite && value > 0;
    if (!isCanonicalApparatusId(normalizedApparatus) ||
        normalizedOrderId.isEmpty ||
        !isNonNegative(laminationPrintLeftoverRolls) ||
        !isNonNegative(laminationFilmLeftoverRolls) ||
        !isNonNegative(totalWaste) ||
        (finishedGoodsMeter != null && !isPositive(finishedGoodsMeter)) ||
        (finishedGoodsKg != null && !isPositive(finishedGoodsKg)) ||
        (bobinaKg != null && !isPositive(bobinaKg))) {
      throw const MobileApiException(
        code: 'laminatsiya_astatka_metrics_required',
        message: 'Metraj, og‘irlik, babina va chiqindini to‘g‘ri kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeRequiredApparatus(normalizedApparatus)
              .operation
              .trim()
              .toLowerCase() !=
          'laminate') {
        throw const MobileApiException(
          code: 'laminatsiya_astatka_metrics_required',
          message: 'Tanlangan aparat laminatsiya apparati emas',
        );
      }
      final previous = _testModeLaminatsiyaAstatkaReports
          .where((report) => report.orderId.trim() == normalizedOrderId)
          .fold<AdminLaminatsiyaAstatkaReport?>(null, (current, report) {
        if (current == null || report.toAtUnix > current.toAtUnix) {
          return report;
        }
        return current;
      });
      final fromAtUnix =
          previous?.toAtUnix ?? _testModeOrderStartedAtUnix[normalizedOrderId];
      if (fromAtUnix == null) {
        throw const MobileApiException(
          code: 'order_not_started',
          message: 'Order hali boshlanmagan',
        );
      }
      final now = _testModeUnixSeconds();
      final report = AdminLaminatsiyaAstatkaReport(
        reportId:
            'test-laminatsiya-astatka-${DateTime.now().microsecondsSinceEpoch}-$normalizedOrderId',
        orderId: normalizedOrderId,
        apparatus: normalizedApparatus,
        fromAtUnix: fromAtUnix,
        toAtUnix: now,
        laminationPrintLeftoverRolls: laminationPrintLeftoverRolls!,
        laminationFilmLeftoverRolls: laminationFilmLeftoverRolls!,
        totalWaste: totalWaste!,
        finishedGoodsMeter: finishedGoodsMeter,
        finishedGoodsKg: finishedGoodsKg,
        bobinaKg: bobinaKg,
        workerRole: AppSession.instance.profile?.role.name ?? '',
        workerRef: AppSession.instance.profile?.ref.trim() ?? '',
        workerDisplayName:
            AppSession.instance.profile?.displayName.trim() ?? '',
        description: description.trim(),
        createdAtUnix: now,
      );
      _testModeLaminatsiyaAstatkaReports.add(report);
      return report;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/laminatsiya-astatka',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': normalizedOrderId,
          'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
          'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
          'total_waste': totalWaste,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (description.trim().isNotEmpty) 'description': description.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'laminatsiya_astatka_report_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawReport = payload['report'];
    if (rawReport is! Map) {
      throw const MobileApiException(
        code: 'laminatsiya_astatka_invalid_response',
        message: 'Astatka qaydi javobi noto‘g‘ri',
      );
    }
    return AdminLaminatsiyaAstatkaReport.fromJson(
      rawReport.cast<String, dynamic>(),
    );
  }

  Future<AdminRezkaAstatkaReport> adminRezkaAstatkaReport({
    required String apparatus,
    required String orderId,
    double? totalWaste,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? finishedGoodsMeter,
    double? finishedGoodsKg,
    double? bobinaKg,
    String description = '',
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedOrderId = orderId.trim();
    bool isNonNegative(double? value) =>
        value != null && value.isFinite && value >= 0;
    bool isPositive(double? value) =>
        value != null && value.isFinite && value > 0;
    if (!isCanonicalApparatusId(normalizedApparatus) ||
        normalizedOrderId.isEmpty ||
        !isNonNegative(totalWaste) ||
        !isNonNegative(rezkaBosmaWaste) ||
        !isNonNegative(rezkaLaminationWaste) ||
        !isNonNegative(rezkaEdgeWaste) ||
        (finishedGoodsMeter != null && !isPositive(finishedGoodsMeter)) ||
        (finishedGoodsKg != null && !isPositive(finishedGoodsKg)) ||
        (bobinaKg != null && !isPositive(bobinaKg))) {
      throw const MobileApiException(
        code: 'rezka_astatka_metrics_required',
        message:
            'Rezka metraj, og‘irlik, babina va chiqindisini to‘g‘ri kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeRequiredApparatus(normalizedApparatus)
              .operation
              .trim()
              .toLowerCase() !=
          'cut') {
        throw const MobileApiException(
          code: 'rezka_astatka_metrics_required',
          message: 'Tanlangan aparat kesish apparati emas',
        );
      }
      final previous = _testModeRezkaAstatkaReports
          .where((report) => report.orderId.trim() == normalizedOrderId)
          .fold<AdminRezkaAstatkaReport?>(null, (current, report) {
        if (current == null || report.toAtUnix > current.toAtUnix) {
          return report;
        }
        return current;
      });
      final fromAtUnix =
          previous?.toAtUnix ?? _testModeOrderStartedAtUnix[normalizedOrderId];
      if (fromAtUnix == null) {
        throw const MobileApiException(
          code: 'order_not_started',
          message: 'Order hali boshlanmagan',
        );
      }
      final now = _testModeUnixSeconds();
      final report = AdminRezkaAstatkaReport(
        reportId:
            'test-rezka-astatka-${DateTime.now().microsecondsSinceEpoch}-$normalizedOrderId',
        orderId: normalizedOrderId,
        apparatus: normalizedApparatus,
        fromAtUnix: fromAtUnix,
        toAtUnix: now,
        totalWaste: totalWaste!,
        rezkaBosmaWaste: rezkaBosmaWaste!,
        rezkaLaminationWaste: rezkaLaminationWaste!,
        rezkaEdgeWaste: rezkaEdgeWaste!,
        finishedGoodsMeter: finishedGoodsMeter,
        finishedGoodsKg: finishedGoodsKg,
        bobinaKg: bobinaKg,
        workerRole: AppSession.instance.profile?.role.name ?? '',
        workerRef: AppSession.instance.profile?.ref.trim() ?? '',
        workerDisplayName:
            AppSession.instance.profile?.displayName.trim() ?? '',
        description: description.trim(),
        createdAtUnix: now,
      );
      _testModeRezkaAstatkaReports.add(report);
      return report;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/rezka-astatka'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': normalizedOrderId,
          'total_waste': totalWaste,
          'rezka_bosma_waste': rezkaBosmaWaste,
          'rezka_lamination_waste': rezkaLaminationWaste,
          'rezka_edge_waste': rezkaEdgeWaste,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (description.trim().isNotEmpty) 'description': description.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'rezka_astatka_report_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawReport = payload['report'];
    if (rawReport is! Map) {
      throw const MobileApiException(
        code: 'rezka_astatka_invalid_response',
        message: 'Rezka astatka javobi noto‘g‘ri',
      );
    }
    return AdminRezkaAstatkaReport.fromJson(rawReport.cast<String, dynamic>());
  }

  Future<AdminApparatusQueueActionResult> adminApparatusQueueActionResult({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    String qolipCode = '',
    List<String> qolipCodes = const [],
    double? producedQty,
    double? grossQty,
    double? bobinaKg,
    double? diameter,
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    List<Map<String, dynamic>> rezkaFrames = const [],
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String customerName = '',
    String driverUrl = '',
    PrintTransport printTransport = PrintTransport.wifi,
    String printer = '',
    String printMode = '',
    String completionRequestNote = '',
    List<ReturnedPaintItemInput> returnedPaintItems = const [],
    String returnedPaintImageId = '',
    bool fullCompletionReportRequired = false,
    bool workerHandoff = false,
    bool removeRollFromApparatus = false,
    String freezeRequestId = '',
    bool freezeWithIssue = false,
    String issueNote = '',
  }) async {
    final normalizedApparatusId = apparatus.trim();
    if (!isCanonicalApparatusId(normalizedApparatusId)) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Canonical apparatus ID noto‘g‘ri',
      );
    }
    final trimmedIssueNote = issueNote.trim();
    if (freezeWithIssue && trimmedIssueNote.isEmpty) {
      throw const MobileApiException(
        code: 'issue_note_required',
        message: 'Muammo izohini kiriting',
      );
    }
    if (freezeWithIssue && action != 'freeze') {
      throw const MobileApiException(
        code: 'freeze_with_issue_only_on_freeze',
        message: 'Muammo bilan yakunlash faqat muzlatish amalida mumkin',
      );
    }
    if (action == 'freeze' && !freezeWithIssue) {
      throw const MobileApiException(
        code: 'freeze_action_requires_issue',
        message: 'Muzlatish amalida muammo izohi majburiy',
      );
    }
    final issueFreezeRequested = action == 'freeze' && freezeWithIssue;
    if (await TestModeController.instance.isEnabled()) {
      final canonicalApparatus =
          _testModeRequiredApparatus(normalizedApparatusId);
      final operation = canonicalApparatus.operation.trim().toLowerCase();
      final storageKey = canonicalApparatus.id.trim();
      final sequence = _testModeApparatusSequences[storageKey] ?? const [];
      final states = Map<String, String>.from(
        _testModeApparatusQueueStates[storageKey] ?? const {},
      );
      final control = _testModeOrderControls[orderId.trim()] ??
          AdminOrderControlState.active;
      final freezeRequestSafeStop =
          control == AdminOrderControlState.freezeRequested &&
              (action == 'pause' || action == 'detach_roll');
      if (control == AdminOrderControlState.frozen) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma muzlatilgan',
        );
      }
      if (control == AdminOrderControlState.freezeRequested &&
          action != 'pause' &&
          action != 'detach_roll' &&
          !issueFreezeRequested) {
        throw const MobileApiException(
          code: 'order_freeze_requested',
          message: 'Buyurtmani muzlatish uchun worker pauzasi kutilmoqda',
        );
      }
      if (freezeRequestSafeStop &&
          freezeRequestId.trim() != 'test-freeze-${orderId.trim()}') {
        throw const MobileApiException(
          code: 'order_freeze_request_mismatch',
          message: 'Muzlatish so‘rovi yangilangan. Sahifani qayta oching',
        );
      }
      final frozenOnAnotherApparatus =
          _testModeApparatusQueueStates.entries.any(
        (entry) =>
            entry.key != storageKey &&
            entry.value[orderId.trim()]?.trim().toLowerCase() == 'frozen',
      );
      if (issueFreezeRequested &&
          control == AdminOrderControlState.active &&
          frozenOnAnotherApparatus) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma boshqa apparatda muzlatilgan',
        );
      }
      final actionableStates = Map<String, String>.from(states)
        ..removeWhere(
          (id, _) =>
              _testModeOrderControls[id] == AdminOrderControlState.frozen,
        );
      final policy = _effectiveTestModeQueuePolicy(
        storageKey,
      ).policy;
      final progressKey =
          qrPayload.trim().isEmpty ? progressBatchId.trim() : qrPayload.trim();
      final startUsesProgressQr = action == 'start' && progressKey.isNotEmpty;
      final startInputBatch = startUsesProgressQr
          ? _testModeProgressBatchForKey(progressKey)
          : null;
      final queueInputKey = _testModeProgressQueueKey(
        storageKey,
        orderId.trim(),
      );
      final sessionInputBatch = action == 'start'
          ? null
          : _testModeProgressBatchForKey(
              _testModeActiveProgressInputByQueue[queueInputKey] ?? '',
            );
      final activeInputBatch = action == 'start'
          ? null
          : _testModeProgressBatchForKey(
              progressKey.isEmpty
                  ? (_testModeActiveProgressInputByQueue[queueInputKey] ?? '')
                  : progressKey,
            );
      final isLaminatsiya = operation == 'laminate';
      final laminatsiyaWipCanReuseMaterial = isLaminatsiya &&
          startInputBatch != null &&
          startInputBatch.wipStatus.trim().toLowerCase() == 'waiting' &&
          (startInputBatch.nextApparatus.trim().isEmpty ||
              startInputBatch.nextApparatus.trim() == storageKey);
      if (!sequence.map((id) => id.trim()).contains(orderId.trim())) {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
        );
      }
      if (policy == ApparatusQueuePolicy.strictSequence &&
          !startUsesProgressQr) {
        final actionable = firstActionableQueueOrderId(
          sequence: sequence,
          states: actionableStates,
        );
        if (actionable != orderId.trim()) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
      }
      final current = apparatusQueueOrderStateFromRaw(states[orderId.trim()]);
      final isRezka = operation == 'cut';
      final isPauseOrDetach = action == 'pause' || action == 'detach_roll';
      final isRezkaProgressAction =
          isPauseOrDetach || action == 'roll_complete' || action == 'complete';
      bool isPositive(double? value) =>
          value != null && value.isFinite && value > 0;
      double? frameMetric(Map<String, dynamic> frame, String key) {
        final value = frame[key];
        return value is num ? value.toDouble() : null;
      }

      final configuredRezkaKadrCount = isRezka
          ? _testModeRezkaKadrCount(orderId: orderId, apparatus: apparatus)
          : null;
      final hasRezkaFrameIssues = rezkaFrames.any(
        (frame) => (frame['issue_note']?.toString().trim() ?? '').isNotEmpty,
      );
      if (hasRezkaFrameIssues &&
          action != 'roll_complete' &&
          action != 'complete') {
        throw const MobileApiException(
          code: 'rezka_frame_issue_only_on_roll_progress',
          message: 'Kadr muammosi faqat Rezka tugatish amalida belgilanadi',
        );
      }
      final hasExplicitRezkaFrameMetrics = isRezka &&
          rezkaFrames.isNotEmpty &&
          configuredRezkaKadrCount != null &&
          rezkaFrames.length == configuredRezkaKadrCount &&
          rezkaFrames.every(
            (frame) =>
                (frame['issue_note']?.toString().trim() ?? '').isNotEmpty ||
                (isPositive(
                      frameMetric(frame, 'produced_qty') ??
                          frameMetric(frame, 'finished_goods_meter'),
                    ) &&
                    isPositive(
                      frameMetric(frame, 'gross_qty') ??
                          frameMetric(frame, 'finished_goods_kg'),
                    ) &&
                    isPositive(frameMetric(frame, 'diameter'))),
          );
      if (rezkaFrames.isNotEmpty && (!isRezka || !isRezkaProgressAction)) {
        throw const MobileApiException(
          code: 'rezka_frames_only_on_rezka_progress',
          message: 'Kadr qiymatlari faqat Rezka progress amalida yuboriladi',
        );
      }
      if (isRezkaProgressAction &&
          rezkaFrames.isNotEmpty &&
          configuredRezkaKadrCount != null &&
          rezkaFrames.length != configuredRezkaKadrCount) {
        throw const MobileApiException(
          code: 'rezka_frame_count_mismatch',
          message: 'Kadr qiymatlari soni sozlangan kadr soniga teng emas',
        );
      }
      if (isRezkaProgressAction &&
          rezkaFrames.isNotEmpty &&
          configuredRezkaKadrCount != null &&
          rezkaFrames.length == configuredRezkaKadrCount &&
          !hasExplicitRezkaFrameMetrics) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message: 'Har bir kadr uchun metraj, og‘irlik va diametrni kiriting',
        );
      }
      if (issueFreezeRequested) {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Muammo faqat jarayondagi zakaz uchun bildiriladi',
          );
        }
        states[orderId.trim()] = 'frozen';
        _testModeOrderControls[orderId.trim()] = AdminOrderControlState.frozen;
        _testModeFrozenIssueNotesByOrderId[orderId.trim()] = trimmedIssueNote;
        _testModeApparatusQueueStates[storageKey] = states;
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'frozen',
        );
        _testModeRemoveOrderFromQueueSequence(orderId);
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          orderStatus: const AdminProductionOrderStatusDetail(
            orderStatus: 'frozen',
            workStatus: 'frozen',
            flowStatus: 'frozen',
          ),
          orderControl: AdminOrderControlState.frozen,
        );
      }
      final hasRezkaQuantityMetrics =
          isPositive(producedQty ?? finishedGoodsMeter) &&
              isPositive(grossQty ?? finishedGoodsKg);
      final hasRezkaDiameter = isPositive(diameter);
      final hasRezkaWaste = [
        totalWaste,
        rezkaBosmaWaste,
        rezkaLaminationWaste,
        rezkaEdgeWaste,
      ].any(isPositive);
      final hasRezkaFrameWaste = rezkaFrames.any(
        (frame) => [
          frameMetric(frame, 'total_waste'),
          frameMetric(frame, 'rezka_bosma_waste'),
          frameMetric(frame, 'rezka_lamination_waste'),
          frameMetric(frame, 'rezka_edge_waste'),
        ].any(isPositive),
      );
      if (isRezka &&
          (isPauseOrDetach ||
              action == 'roll_complete' ||
              action == 'complete') &&
          (!hasExplicitRezkaFrameMetrics &&
              (!hasRezkaQuantityMetrics || !hasRezkaDiameter))) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message: 'Rezka uchun metraj, og‘irlik va diametrni kiriting',
        );
      }
      if (isRezka &&
          (isPauseOrDetach ||
              action == 'roll_complete' ||
              action == 'complete') &&
          configuredRezkaKadrCount == null) {
        throw const MobileApiException(
          code: 'rezka_kadr_count_required',
          message: 'Rezka uchun kadr soni sozlanmagan',
        );
      }
      final testModeOrderMap = _testModeOrderById(orderId)?.map;
      final previousStage = testModeOrderMap == null
          ? null
          : _testModeTrainingPreviousStage(
              map: testModeOrderMap,
              station: apparatus,
            );
      final hasPreviousStage = previousStage != null;
      final usesVirtualTrainingInput = testModeOrderMap != null &&
          _testModeUsesVirtualTrainingInput(
            map: testModeOrderMap,
            station: apparatus,
          );
      final previousStageCompleted = hasPreviousStage &&
          (usesVirtualTrainingInput
              ? _testModeTrainingInputBatchGeneratedOrderIds.contains(
                  orderId.trim(),
                )
              : _testModeApparatusQueueStates.entries.any((entry) {
                  final state = apparatusQueueOrderStateFromRaw(
                    entry.value[orderId.trim()],
                  );
                  return entry.key.trim() == previousStage &&
                      state == ApparatusQueueOrderState.completed;
                }));
      bool isPreviousStageBatch(AdminProgressBatch batch) {
        if (!hasPreviousStage ||
            batch.orderId.trim() != orderId.trim() ||
            batch.apparatus.trim() != previousStage ||
            (batch.nextApparatus.trim().isNotEmpty &&
                batch.nextApparatus.trim() != storageKey)) {
          return false;
        }
        final actionName = batch.action.trim().toLowerCase();
        if (actionName != 'pause' &&
            actionName != 'detach_roll' &&
            actionName != 'roll_complete' &&
            actionName != 'complete') {
          return false;
        }
        final wipStatus = batch.wipStatus.trim().toLowerCase();
        return wipStatus == 'waiting' ||
            (wipStatus == 'in_use' &&
                (batch.usedByApparatus.trim().isEmpty
                        ? batch.currentApparatus.trim()
                        : batch.usedByApparatus.trim()) ==
                    storageKey);
      }

      final hasUnprocessedPreviousWip = (isLaminatsiya || isRezka) &&
          hasPreviousStage &&
          (!previousStageCompleted ||
              _testModeProgressBatchesByQr.values.any((batch) {
                if (!isPreviousStageBatch(batch)) {
                  return false;
                }
                if (activeInputBatch != null &&
                    (batch.batchId.trim() == activeInputBatch.batchId.trim() ||
                        batch.qrPayload.trim().toLowerCase() ==
                            activeInputBatch.qrPayload.trim().toLowerCase())) {
                  return false;
                }
                return true;
              }));
      final allowPartialStationCompletion = (isLaminatsiya || isRezka) &&
          action == 'complete' &&
          !fullCompletionReportRequired &&
          hasUnprocessedPreviousWip;
      if (isRezka &&
          action == 'complete' &&
          !allowPartialStationCompletion &&
          !hasRezkaWaste &&
          !hasRezkaFrameWaste) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message: 'Yakuniy Rezka tugatishida chiqindi hisoboti shart',
        );
      }
      if (isRezka &&
          (isPauseOrDetach ||
              action == 'roll_complete' ||
              action == 'complete') &&
          hasPreviousStage &&
          activeInputBatch == null) {
        throw const MobileApiException(
          code: 'progress_qr_required',
          message: 'Rezka uchun keyingi laminatsiya ruloni QR sini scan qiling',
        );
      }
      if (isLaminatsiya &&
          hasPreviousStage &&
          (isPauseOrDetach || action == 'complete') &&
          activeInputBatch == null) {
        throw const MobileApiException(
          code: 'progress_qr_required',
          message: 'Laminatsiya uchun oldingi bosqich QR sini scan qiling',
        );
      }
      if (activeInputBatch != null &&
          (activeInputBatch.orderId.trim() != orderId.trim() ||
              activeInputBatch.wipStatus.trim().toLowerCase() == 'processed')) {
        throw const MobileApiException(
          code: 'progress_batch_not_accepted',
          message: 'Bu WIP ushbu Rezka orderi uchun yaroqsiz',
        );
      }
      final explicitProgressInput =
          action != 'start' && action != 'resume' && progressKey.isNotEmpty;
      if (explicitProgressInput && hasPreviousStage) {
        final input = activeInputBatch;
        final inputWipStatus = input?.wipStatus.trim().toLowerCase() ?? '';
        final inputNextApparatus = input?.nextApparatus.trim() ?? '';
        final inputUsedByApparatus =
            input?.usedByApparatus.trim().isNotEmpty == true
                ? input!.usedByApparatus.trim()
                : input?.currentApparatus.trim() ?? '';
        if (input == null) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
          );
        }
        final sessionInputIsDifferent = sessionInputBatch != null &&
            sessionInputBatch.wipStatus.trim().toLowerCase() == 'in_use' &&
            sessionInputBatch.batchId.trim() != input.batchId.trim();
        if (sessionInputIsDifferent) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Avval joriy Rezka rulonini tugating',
          );
        }
        final inputWipIsUsable = inputWipStatus == 'waiting' ||
            (inputWipStatus == 'in_use' && inputUsedByApparatus == storageKey);
        if (!inputWipIsUsable ||
            input.apparatus.trim() != previousStage ||
            (inputNextApparatus.isNotEmpty &&
                inputNextApparatus != storageKey)) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
          );
        }
      }
      if (action == 'start') {
        if (_testModeRequeuedOrderIds.contains(orderId.trim())) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message:
                'Muzlatishdan qaytgan order Resume orqali davom ettiriladi',
          );
        }
        if (hasPreviousStage && startInputBatch == null) {
          throw const MobileApiException(
            code: 'progress_qr_required',
            message: 'Oldingi bosqich QR sini scan qiling',
          );
        }
        if (progressKey.isNotEmpty) {
          final batch = startInputBatch;
          final batchAction = batch?.action.trim().toLowerCase() ?? '';
          final batchStatus = batch?.status.trim().toLowerCase() ?? '';
          final batchWipStatus = batch?.wipStatus.trim().toLowerCase() ?? '';
          final batchNextApparatus = batch?.nextApparatus.trim() ?? '';
          if (batch == null) {
            throw const MobileApiException(
              code: 'progress_batch_not_accepted',
              message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
            );
          }
          if ((progressBatchId.trim().isNotEmpty &&
                  batch.batchId.trim() != progressBatchId.trim()) ||
              batch.orderId.trim() != orderId.trim() ||
              (batchAction != 'pause' &&
                  batchAction != 'detach_roll' &&
                  batchAction != 'roll_complete' &&
                  batchAction != 'complete') ||
              (batchStatus != 'paused' &&
                  batchStatus != 'roll_detached' &&
                  batchStatus != 'completed' &&
                  batchStatus != 'resumed') ||
              (hasPreviousStage &&
                  ((batchWipStatus.isNotEmpty && batchWipStatus != 'waiting') ||
                      batch.apparatus.trim() != previousStage ||
                      (batchNextApparatus.isNotEmpty &&
                          batchNextApparatus != storageKey)))) {
            throw const MobileApiException(
              code: 'progress_batch_not_accepted',
              message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
            );
          }
        }
        if (current != ApparatusQueueOrderState.pending) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final requiredMaterials = _testModeRawMaterialAssignments
            .where(
              (assignment) =>
                  assignment.orderId.trim() == orderId.trim() &&
                  assignment.apparatus.trim() == storageKey,
            )
            .toList(growable: false);
        final requiredBarcodes = {
          for (final assignment in requiredMaterials)
            _normalizeRawMaterialBarcode(assignment.barcode),
        }..remove('');
        final scannedBarcodes = {
          for (final barcode in [
            ...materialBarcodes,
            if (materialBarcode.trim().isNotEmpty) materialBarcode,
          ])
            _normalizeRawMaterialBarcode(barcode),
        }..remove('');
        if (!laminatsiyaWipCanReuseMaterial) {
          final requirements = await adminRawMaterialStartRequirements(
            orderId: orderId,
            apparatus: apparatus,
            materialBarcodes: scannedBarcodes.toList(growable: false),
          );
          if (requiredBarcodes.isEmpty &&
              requirements.requiresMaterial &&
              !isLaminatsiya) {
            throw const MobileApiException(
              code: 'raw_material_assignment_not_found',
              message: 'Homashyo biriktirilmagan',
            );
          }
          if (requiredBarcodes.isNotEmpty && scannedBarcodes.isEmpty) {
            throw const MobileApiException(
              code: 'raw_material_scan_required',
              message:
                  'Ishni boshlash uchun biriktirilgan homashyolarni skaner qiling',
            );
          }
          if (!requiredBarcodes.containsAll(scannedBarcodes)) {
            throw const MobileApiException(
              code: 'raw_material_mismatch',
              message: 'Bu homashyo ish boshlash uchun mos emas',
            );
          }
          if (requirements.policy == AdminRawMaterialStartPolicy.stateAll &&
              requiredBarcodes.isNotEmpty &&
              requirements.normalizedStagedBarcodes.isEmpty) {
            throw const MobileApiException(
              code: 'raw_material_state_not_ready',
              message: 'Apparat oldiga homashyo olib kelinmagan',
            );
          }
          if (!requirements.assignmentsSatisfied &&
              !(isLaminatsiya && requiredBarcodes.isEmpty)) {
            throw const MobileApiException(
              code: 'raw_material_assignment_not_found',
              message: 'Majburiy homashyo guruhlari to‘liq biriktirilmagan',
            );
          }
          if (requiredBarcodes.isNotEmpty && !requirements.scanSatisfied) {
            throw MobileApiException(
              code: requirements.policy == AdminRawMaterialStartPolicy.stateAll
                  ? 'raw_material_scan_incomplete'
                  : 'raw_material_requirement_not_met',
              message: requirements.policy ==
                      AdminRawMaterialStartPolicy.stateAll
                  ? 'Apparat oldidagi barcha homashyolarni skaner qiling'
                  : 'Har bir majburiy guruhdan minimum homashyo skaner qiling',
            );
          }
        }
        if (startInputBatch != null) {
          final inputForStation = startInputBatch.copyWith(
            wipStatus: 'in_use',
            currentApparatus: apparatus,
            currentLocation: apparatus,
            usedBySessionId: 'test-session-${orderId.trim()}',
            usedByApparatus: apparatus,
          );
          _testModeProgressBatchesByQr[inputForStation.qrPayload] =
              inputForStation;
          _testModeActiveProgressInputByQueue[queueInputKey] =
              inputForStation.qrPayload;
          if (inputForStation.payloadJson['training_input'] == true) {
            _testModeTrainingInputBatchSetClosedOrderIds.add(orderId.trim());
          }
        }
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: storageKey,
          orderId: orderId,
        );
        states[orderId.trim()] = 'in_progress';
        _testModeOrderStartedAtUnix.putIfAbsent(
          orderId.trim(),
          _testModeUnixSeconds,
        );
        for (var index = 0;
            index < _testModeRawMaterialAssignments.length;
            index += 1) {
          final assignment = _testModeRawMaterialAssignments[index];
          if (assignment.orderId.trim() == orderId.trim() &&
              assignment.apparatus.trim() == storageKey &&
              scannedBarcodes.contains(
                assignment.barcode.trim().toUpperCase(),
              )) {
            _testModeRawMaterialAssignments[index] = assignment.copyWith(
              stockStatus: 'in_use',
              reservedOrderId: orderId.trim(),
            );
          }
        }
      } else if ((action == 'pause' && workerHandoff) ||
          (action == 'detach_roll' && removeRollFromApparatus)) {
        if (!isLaminatsiya ||
            (workerHandoff && removeRollFromApparatus) ||
            (workerHandoff && current != ApparatusQueueOrderState.inProgress) ||
            (removeRollFromApparatus &&
                current != ApparatusQueueOrderState.paused)) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Bu laminatsiya worker handoff amali hozir mumkin emas',
          );
        }
        bool isNonNegative(double? value) =>
            value != null && value.isFinite && value >= 0;
        final handoffMetricsReady =
            isNonNegative(laminationPrintLeftoverRolls) &&
                isNonNegative(laminationFilmLeftoverRolls) &&
                isNonNegative(totalWaste);
        if (workerHandoff && !handoffMetricsReady) {
          throw const MobileApiException(
            code: 'laminatsiya_completion_metrics_required',
            message: 'Bosmadan, plyonkadan ortgan rulon va chiqindini kiriting',
          );
        }
        final handoffInput = activeInputBatch;
        if (handoffInput == null ||
            handoffInput.wipStatus.trim().toLowerCase() != 'in_use') {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Apparatdagi joriy laminatsiya ruloni topilmadi',
          );
        }
        final isHandoff = handoffInput.payloadJson['worker_handoff'] == true;
        if (removeRollFromApparatus && !isHandoff) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu rulon worker handoff holatida emas',
          );
        }
        if (removeRollFromApparatus &&
            (!isPositive(finishedGoodsMeter ?? producedQty) ||
                !isPositive(finishedGoodsKg ?? grossQty))) {
          throw const MobileApiException(
            code: 'laminatsiya_completion_metrics_required',
            message: 'Rulonni yechish uchun metraj va og‘irlikni kiriting',
          );
        }
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final updatedInput = removeRollFromApparatus
            ? handoffInput.copyWith(
                wipStatus: 'waiting',
                currentApparatus: storageKey,
                currentLocation: '$storageKey olib tashlandi',
                usedBySessionId: '',
                usedByApparatus: '',
                payloadJson: {
                  ...handoffInput.payloadJson,
                  'worker_handoff': false,
                  'roll_removed_from_apparatus': true,
                  'roll_removed_at_unix': now,
                  'roll_removed_finished_goods_meter':
                      finishedGoodsMeter ?? producedQty,
                  'roll_removed_finished_goods_kg': finishedGoodsKg ?? grossQty,
                  if (bobinaKg != null) 'roll_removed_bobina_kg': bobinaKg,
                },
              )
            : handoffInput.copyWith(
                wipStatus: 'in_use',
                currentApparatus: storageKey,
                currentLocation: storageKey,
                usedBySessionId: 'test-session-${orderId.trim()}',
                usedByApparatus: storageKey,
                payloadJson: {
                  ...handoffInput.payloadJson,
                  'worker_handoff': true,
                  'roll_removed_from_apparatus': false,
                  'worker_handoff_at_unix': now,
                  'lamination_print_leftover_rolls':
                      laminationPrintLeftoverRolls,
                  'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
                  'total_waste': totalWaste,
                  if (bobinaKg != null) 'bobina_kg': bobinaKg,
                },
              );
        _testModeProgressBatchesByQr[updatedInput.qrPayload] = updatedInput;
        _testModeActiveProgressInputByQueue[queueInputKey] =
            updatedInput.qrPayload;
        states[orderId.trim()] = 'paused';
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'paused',
        );
        if (control == AdminOrderControlState.freezeRequested) {
          _testModeOrderControls[orderId.trim()] =
              AdminOrderControlState.frozen;
        }
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
        );
      } else if (isPauseOrDetach) {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final hasFreezeSafeStopOutput = rezkaFrames.isNotEmpty ||
            producedQty != null ||
            grossQty != null ||
            finishedGoodsMeter != null ||
            finishedGoodsKg != null ||
            bobinaKg != null ||
            diameter != null ||
            returnInkKg != null ||
            laminationPrintLeftoverRolls != null ||
            laminationFilmLeftoverRolls != null ||
            rezkaBosmaWaste != null ||
            rezkaLaminationWaste != null ||
            rezkaEdgeWaste != null ||
            totalWaste != null;
        final freezeSafeStopIssueNote = completionRequestNote.trim();
        if (freezeRequestSafeStop &&
            !hasFreezeSafeStopOutput &&
            freezeSafeStopIssueNote.isNotEmpty) {
          states[orderId.trim()] = 'frozen';
          _testModeOrderControls[orderId.trim()] =
              AdminOrderControlState.frozen;
          _testModeFrozenIssueNotesByOrderId[orderId.trim()] =
              freezeSafeStopIssueNote;
          _testModeSyncScheduleReservationStatus(
            orderId: orderId,
            apparatusId: storageKey,
            status: 'paused',
          );
          _testModeApparatusQueueStates[storageKey] = states;
          return AdminApparatusQueueActionResult(
            states: Map<String, String>.unmodifiable(states),
            orderControl: AdminOrderControlState.frozen,
          );
        }
        final qty = producedQty ?? finishedGoodsMeter ?? 1;
        final outputBatches = isRezka
            ? _testModeRezkaProgressBatches(
                apparatus: storageKey,
                orderId: orderId.trim(),
                action: action,
                status: action == 'detach_roll' ? 'roll_detached' : 'paused',
                producedQty: qty,
                uom: uom.trim().isEmpty ? 'm' : uom.trim(),
                frameCount: configuredRezkaKadrCount!,
                inputBatch: activeInputBatch,
                rezkaFrames: rezkaFrames,
                diameter: diameter,
                laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                rezkaBosmaWaste: rezkaBosmaWaste,
                rezkaLaminationWaste: rezkaLaminationWaste,
                rezkaEdgeWaste: rezkaEdgeWaste,
                totalWaste: totalWaste,
                finishedGoodsKg: finishedGoodsKg ?? grossQty,
                finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
                bobinaKg: bobinaKg,
              )
            : [
                _testModeProgressBatch(
                  apparatus: storageKey,
                  orderId: orderId.trim(),
                  action: action,
                  status: action == 'detach_roll' ? 'roll_detached' : 'paused',
                  producedQty: qty,
                  uom: uom.trim().isEmpty && finishedGoodsMeter != null
                      ? 'm'
                      : (uom.trim().isEmpty ? 'kg' : uom.trim()),
                  parentBatchId: activeInputBatch?.batchId ?? '',
                  laminationPrintLeftoverRolls: null,
                  laminationFilmLeftoverRolls:
                      isLaminatsiya ? null : laminationFilmLeftoverRolls,
                  rezkaBosmaWaste: rezkaBosmaWaste,
                  rezkaLaminationWaste: rezkaLaminationWaste,
                  rezkaEdgeWaste: rezkaEdgeWaste,
                  totalWaste: isLaminatsiya ? null : totalWaste,
                  finishedGoodsKg: finishedGoodsKg,
                  finishedGoodsMeter: finishedGoodsMeter,
                  bobinaKg: bobinaKg,
                ),
              ];
        for (final batch in outputBatches) {
          _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        }
        states[orderId.trim()] =
            control == AdminOrderControlState.freezeRequested
                ? 'frozen'
                : 'paused';
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'paused',
        );
        if (control == AdminOrderControlState.freezeRequested) {
          _testModeOrderControls[orderId.trim()] =
              AdminOrderControlState.frozen;
        }
        _testModeApparatusQueueStates[storageKey] = states;
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
          customerName: customerName,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          orderControl: control == AdminOrderControlState.freezeRequested
              ? AdminOrderControlState.frozen
              : null,
          progressBatch: outputBatches.first,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
      } else if (action == 'roll_complete') {
        if (!isRezka || current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Rulonni faqat faol Rezka orderida tugatish mumkin',
          );
        }
        final frameCount = configuredRezkaKadrCount;
        if (frameCount == null) {
          throw const MobileApiException(
            code: 'rezka_kadr_count_required',
            message: 'Rezka uchun kadr soni sozlanmagan',
          );
        }
        final rezkaFrameIssues = _testModeRezkaFrameIssues(
          rezkaFrames: rezkaFrames,
          frameCount: frameCount,
          inputProgressBatchId: activeInputBatch?.batchId ?? '',
        );
        _testModeRezkaFrameIssuesByQueue[queueInputKey] = rezkaFrameIssues;
        final outputBatches = _testModeRezkaProgressBatches(
          apparatus: storageKey,
          orderId: orderId.trim(),
          action: 'roll_complete',
          status: 'completed',
          producedQty: producedQty ?? finishedGoodsMeter ?? 1,
          uom: uom.trim().isEmpty ? 'm' : uom.trim(),
          frameCount: frameCount,
          inputBatch: activeInputBatch,
          rezkaFrames: rezkaFrames,
          diameter: diameter,
          rezkaBosmaWaste: rezkaBosmaWaste,
          rezkaLaminationWaste: rezkaLaminationWaste,
          rezkaEdgeWaste: rezkaEdgeWaste,
          totalWaste: totalWaste,
          finishedGoodsKg: finishedGoodsKg ?? grossQty,
          finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
          bobinaKg: bobinaKg,
          rezkaFrameIssues: rezkaFrameIssues,
        );
        for (final batch in outputBatches) {
          _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        }
        if (activeInputBatch != null) {
          final processedInput = _testModeMarkProgressInputProcessed(
            batch: activeInputBatch,
            apparatus: storageKey,
            orderId: orderId,
            rezkaFrameIssues: rezkaFrameIssues,
          );
          _testModeProgressBatchesByQr[processedInput.qrPayload] =
              processedInput;
        }
        _testModeActiveProgressInputByQueue.remove(queueInputKey);
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: storageKey,
          orderId: orderId,
        );
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'active',
        );
        _testModeApparatusQueueStates[storageKey] = states;
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
          customerName: customerName,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: outputBatches.isEmpty ? null : outputBatches.first,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
      } else if (action == 'resume') {
        final requeued = _testModeRequeuedOrderIds.contains(orderId.trim());
        if (current != ApparatusQueueOrderState.paused &&
            current != ApparatusQueueOrderState.frozen &&
            !(requeued && current == ApparatusQueueOrderState.pending)) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        AdminProgressBatch? resumed;
        final resumedBatches = <AdminProgressBatch>[];
        if (progressKey.isNotEmpty) {
          final batch = _testModeProgressBatchForKey(progressKey);
          if (batch == null ||
              (batch.status != 'paused' && batch.status != 'roll_detached') ||
              batch.orderId != orderId.trim() ||
              batch.apparatus.trim() != storageKey) {
            throw const MobileApiException(
              code: 'progress_batch_not_resumable',
              message: 'Bu progress QR davom ettirishga yaramaydi',
            );
          }
          final siblings = _testModeProgressBatchesByQr.values
              .where(
                (candidate) =>
                    candidate.orderId.trim() == orderId.trim() &&
                    candidate.apparatus.trim() == storageKey &&
                    (candidate.action.trim().toLowerCase() == 'pause' ||
                        candidate.action.trim().toLowerCase() ==
                            'detach_roll') &&
                    (candidate.status.trim().toLowerCase() == 'paused' ||
                        candidate.status.trim().toLowerCase() ==
                            'roll_detached') &&
                    candidate.sessionId.trim() == batch.sessionId.trim() &&
                    candidate.parentBatchId.trim() ==
                        batch.parentBatchId.trim(),
              )
              .toList(growable: false);
          for (final sibling in siblings) {
            final updated = sibling.copyWith(status: 'resumed');
            _testModeProgressBatchesByQr[updated.qrPayload] = updated;
            resumedBatches.add(updated);
          }
          resumed = resumedBatches.isEmpty
              ? batch.copyWith(status: 'resumed')
              : resumedBatches.first;
          if (resumedBatches.isEmpty) {
            _testModeProgressBatchesByQr[resumed.qrPayload] = resumed;
            resumedBatches.add(resumed);
          }
        } else if (activeInputBatch != null &&
            (activeInputBatch.payloadJson['worker_handoff'] == true ||
                activeInputBatch.payloadJson['roll_removed_from_apparatus'] ==
                    true)) {
          resumed = activeInputBatch.copyWith(
            wipStatus: 'in_use',
            currentApparatus: storageKey,
            currentLocation: storageKey,
            usedBySessionId: 'test-session-${orderId.trim()}',
            usedByApparatus: storageKey,
            payloadJson: {
              ...activeInputBatch.payloadJson,
              'worker_handoff': false,
              'roll_removed_from_apparatus': false,
              'roll_claimed_after_handoff_at_unix':
                  DateTime.now().millisecondsSinceEpoch ~/ 1000,
            },
          );
          _testModeProgressBatchesByQr[resumed.qrPayload] = resumed;
          _testModeActiveProgressInputByQueue[queueInputKey] =
              resumed.qrPayload;
        } else if (activeInputBatch != null) {
          final pausedOutputs = _testModeProgressBatchesByQr.values
              .where(
                (batch) =>
                    batch.orderId.trim() == orderId.trim() &&
                    batch.apparatus.trim() == storageKey &&
                    (batch.action.trim().toLowerCase() == 'pause' ||
                        batch.action.trim().toLowerCase() == 'detach_roll') &&
                    (batch.status.trim().toLowerCase() == 'paused' ||
                        batch.status.trim().toLowerCase() == 'roll_detached') &&
                    batch.parentBatchId.trim() ==
                        activeInputBatch.batchId.trim(),
              )
              .toList(growable: false);
          for (final batch in pausedOutputs) {
            final updated = batch.copyWith(status: 'resumed');
            _testModeProgressBatchesByQr[updated.qrPayload] = updated;
            resumedBatches.add(updated);
          }
          if (resumedBatches.isNotEmpty) {
            resumed = resumedBatches.first;
          }
        }
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: storageKey,
          orderId: orderId,
        );
        states[orderId.trim()] = 'in_progress';
        _testModeRequeuedOrderIds.remove(orderId.trim());
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'active',
        );
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: resumed,
          progressBatches: List<AdminProgressBatch>.unmodifiable(
            resumedBatches,
          ),
        );
      } else if (action == 'complete') {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final note = completionRequestNote.trim();
        final hasReturnedPaintReport = returnedPaintItems.isNotEmpty ||
            returnedPaintImageId.trim().isNotEmpty;
        final hasCompleteMetrics =
            (returnInkKg != null || hasReturnedPaintReport) &&
                totalWaste != null &&
                finishedGoodsKg != null &&
                finishedGoodsMeter != null;
        final hasLaminatsiyaCompleteMetrics = allowPartialStationCompletion
            ? isPositive(finishedGoodsKg) && isPositive(finishedGoodsMeter)
            : (laminationPrintLeftoverRolls != null ||
                    laminationFilmLeftoverRolls != null) &&
                isPositive(totalWaste) &&
                isPositive(finishedGoodsKg) &&
                isPositive(finishedGoodsMeter);
        final zeroMetricCodes = <String>[
          if (producedQty == 0) 'produced_qty',
          if (grossQty == 0) 'gross_qty',
          if (returnInkKg == 0) 'return_ink_kg',
          if (laminationPrintLeftoverRolls == 0)
            'lamination_print_leftover_rolls',
          if (laminationFilmLeftoverRolls == 0)
            'lamination_film_leftover_rolls',
          if (rezkaBosmaWaste == 0) 'rezka_bosma_waste',
          if (rezkaLaminationWaste == 0) 'rezka_lamination_waste',
          if (rezkaEdgeWaste == 0) 'rezka_edge_waste',
          if (totalWaste == 0) 'total_waste',
          if (finishedGoodsKg == 0) 'finished_goods_kg',
          if (finishedGoodsMeter == 0) 'finished_goods_meter',
          if (bobinaKg == 0) 'bobina_kg',
        ];
        if (zeroMetricCodes.isNotEmpty && note.isEmpty) {
          throw const MobileApiException(
            code: 'zero_metric_explanation_required',
            message: '0 qiymat kiritilganda sababini yozing',
          );
        }
        if (isLaminatsiya && !hasLaminatsiyaCompleteMetrics && note.isEmpty) {
          throw const MobileApiException(
            code: 'laminatsiya_completion_metrics_required',
            message: 'Laminatsiya uchun metraj va og‘irlikni kiriting',
          );
        }
        final missingOutputWithReason = note.isNotEmpty &&
            !hasCompleteMetrics &&
            !hasLaminatsiyaCompleteMetrics &&
            !hasRezkaQuantityMetrics &&
            !hasExplicitRezkaFrameMetrics &&
            grossQty == null;
        if (zeroMetricCodes.isNotEmpty || missingOutputWithReason) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final map = _testModeProductionMaps
              .where((item) => item.map.id.trim() == orderId.trim())
              .cast<ProductionMapSaved?>()
              .firstWhere((item) => item != null, orElse: () => null);
          _testModeCompletionRequests.insert(
            0,
            AdminCompletionRequestNotification(
              eventId: 'test-completion-request-$now-${orderId.trim()}',
              apparatus: storageKey,
              orderId: orderId.trim(),
              orderNumber: map?.map.orderNumber.trim() ?? '',
              orderTitle: map?.map.title.trim() ?? '',
              productCode: map?.map.productCode.trim() ?? '',
              workerRole: AppSession.instance.profile?.role.name ?? '',
              workerRef: AppSession.instance.profile?.ref.trim() ?? '',
              workerDisplayName:
                  AppSession.instance.profile?.displayName.trim() ?? '',
              description: note,
              zeroMetricCodes: zeroMetricCodes,
              createdAtUnix: now,
            ),
          );
          return AdminApparatusQueueActionResult(
            states: Map<String, String>.unmodifiable(states),
            completionRequest: _testModeCompletionRequests.first,
          );
        }
        final rezkaFrameCount = isRezka
            ? _testModeRezkaKadrCount(orderId: orderId, apparatus: apparatus)
            : null;
        final rezkaFrameIssues = isRezka && rezkaFrameCount != null
            ? _testModeRezkaFrameIssues(
                rezkaFrames: rezkaFrames,
                frameCount: rezkaFrameCount,
                inputProgressBatchId: activeInputBatch?.batchId ?? '',
              )
            : const <Map<String, dynamic>>[];
        if (isRezka && rezkaFrameCount == null) {
          throw const MobileApiException(
            code: 'rezka_kadr_count_required',
            message: 'Rezka uchun kadr soni sozlanmagan',
          );
        }
        if (isRezka) {
          _testModeRezkaFrameIssuesByQueue[queueInputKey] = rezkaFrameIssues;
        }
        final outputBatches = isRezka
            ? _testModeRezkaProgressBatches(
                apparatus: storageKey,
                orderId: orderId.trim(),
                action: 'complete',
                status: 'completed',
                producedQty: producedQty ?? finishedGoodsMeter ?? 1,
                uom: uom.trim().isEmpty && finishedGoodsMeter != null
                    ? 'm'
                    : (uom.trim().isEmpty ? 'kg' : uom.trim()),
                frameCount: rezkaFrameCount!,
                inputBatch: activeInputBatch,
                rezkaFrames: rezkaFrames,
                diameter: diameter,
                returnInkKg: returnInkKg,
                laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                rezkaBosmaWaste:
                    allowPartialStationCompletion ? null : rezkaBosmaWaste,
                rezkaLaminationWaste:
                    allowPartialStationCompletion ? null : rezkaLaminationWaste,
                rezkaEdgeWaste:
                    allowPartialStationCompletion ? null : rezkaEdgeWaste,
                totalWaste: allowPartialStationCompletion ? null : totalWaste,
                finishedGoodsKg: finishedGoodsKg ?? grossQty,
                finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
                bobinaKg: bobinaKg,
                rezkaFrameIssues: rezkaFrameIssues,
              )
            : [
                _testModeProgressBatch(
                  apparatus: storageKey,
                  orderId: orderId.trim(),
                  action: 'complete',
                  status: 'completed',
                  producedQty: producedQty ?? finishedGoodsMeter ?? 1,
                  uom: uom.trim().isEmpty && finishedGoodsMeter != null
                      ? 'm'
                      : (uom.trim().isEmpty ? 'kg' : uom.trim()),
                  parentBatchId: activeInputBatch?.batchId ?? '',
                  returnInkKg: returnInkKg,
                  laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                  laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                  rezkaBosmaWaste: rezkaBosmaWaste,
                  rezkaLaminationWaste: rezkaLaminationWaste,
                  rezkaEdgeWaste: rezkaEdgeWaste,
                  totalWaste: totalWaste,
                  finishedGoodsKg: finishedGoodsKg,
                  finishedGoodsMeter: finishedGoodsMeter,
                  bobinaKg: bobinaKg,
                ),
              ];
        for (final batch in outputBatches) {
          _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        }
        if (activeInputBatch != null) {
          final processedInput = _testModeMarkProgressInputProcessed(
            batch: activeInputBatch,
            apparatus: storageKey,
            orderId: orderId,
            rezkaFrameIssues: rezkaFrameIssues,
          );
          _testModeProgressBatchesByQr[processedInput.qrPayload] =
              processedInput;
        }
        _testModeActiveProgressInputByQueue.remove(queueInputKey);
        final batch = outputBatches.isEmpty ? null : outputBatches.first;
        states[orderId.trim()] =
            hasUnprocessedPreviousWip ? 'pending' : 'completed';
        _testModeApparatusQueueStates[storageKey] = states;
        final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
        final completedOrderId = orderId.trim();
        final historyStatus = _testModeQueueHistoryStatus(
          apparatus: storageKey,
          orderId: completedOrderId,
          fallbackStatus: 'completed',
        );
        if (actorRef.isNotEmpty &&
            completedOrderId.isNotEmpty &&
            historyStatus.isNotEmpty) {
          _testModeRecordCompletedQueueOrder(
            actorRef: actorRef,
            apparatus: storageKey,
            orderId: completedOrderId,
            status: historyStatus,
          );
        }
        if (returnedPaintItems.isNotEmpty ||
            returnedPaintImageId.trim().isNotEmpty) {
          final reportId =
              'returned-paint-complete:$completedOrderId:$storageKey';
          if (!_testModeReturnedPaintRequests.any(
            (request) => request.id == reportId,
          )) {
            final map = _testModeProductionMaps
                .where((item) => item.map.id.trim() == completedOrderId)
                .cast<ProductionMapSaved?>()
                .firstWhere((item) => item != null, orElse: () => null);
            final profile = AppSession.instance.profile;
            final operatorName = profile?.displayName.trim().isNotEmpty == true
                ? profile!.displayName.trim()
                : 'Operator';
            final orderCode = map?.map.code.trim().isNotEmpty == true
                ? map!.map.code.trim()
                : map?.map.orderNumber.trim() ?? '';
            final image =
                _testModeReturnedPaintImages[returnedPaintImageId.trim()];
            final waiting = returnedPaintItems.isEmpty && image != null;
            _testModeReturnedPaintRequests.insert(
              0,
              ReturnedPaintRequest(
                id: reportId,
                orderId: completedOrderId,
                orderCode: orderCode,
                orderName: map?.map.title.trim() ?? '',
                apparatus: storageKey,
                senderRole: profile?.role ?? UserRole.aparatchi,
                senderRef: profile?.ref.trim() ?? 'test-user',
                senderDisplayName: operatorName,
                items: returnedPaintItems,
                status: waiting
                    ? ReturnedPaintStatus.waitingForBoyoqchiInput
                    : ReturnedPaintStatus.completed,
                image: image,
                calculation: waiting
                    ? null
                    : const ReturnedPaintCalculation(
                        rasxotMixTotal: '0',
                        astatkaMixTotal: '0',
                        rasxotAlcohol: '0',
                        astatkaAlcohol: '0',
                        finalUsedAlcohol: '0',
                        rasxotPurePaint: '0',
                        astatkaPurePaint: '0',
                        finalUsedPaint: '0',
                      ),
                message:
                    '$operatorName orderni $completedOrderId apparatida muvaffaqiyatli yopdi. Rasxot bo‘yoq sarfi va Astatka qolgan bo‘yoq miqdorlari qayd etildi.',
                createdAt: DateTime.now(),
              ),
            );
          }
        }
        _testModeSyncScheduleReservationStatus(
          orderId: completedOrderId,
          apparatusId: storageKey,
          status: 'completed',
        );
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
          customerName: customerName,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: batch,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
      } else {
        throw const MobileApiException(
          code: 'queue_action_not_allowed',
          message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
        );
      }
      if (action == 'start') {
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatusId: storageKey,
          status: 'active',
        );
      }
      _testModeApparatusQueueStates[storageKey] = states;
      return AdminApparatusQueueActionResult(
        states: Map<String, String>.unmodifiable(states),
      );
    }
    final trimmedBarcode = materialBarcode.trim();
    final trimmedQolipCode = qolipCode.trim();
    final trimmedQolipCodes = <String>[];
    for (final code in qolipCodes) {
      final trimmed = code.trim();
      if (trimmed.isEmpty ||
          trimmedQolipCodes.any(
            (existing) => existing.toLowerCase() == trimmed.toLowerCase(),
          )) {
        continue;
      }
      trimmedQolipCodes.add(trimmed);
    }
    final trimmedBarcodes = [
      for (final barcode in materialBarcodes)
        if (barcode.trim().isNotEmpty) barcode.trim(),
    ];
    final trimmedDriverUrl = driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final trimmedCompletionRequestNote = completionRequestNote.trim();
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-action'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus,
          'order_id': orderId,
          'action': action,
          if (freezeWithIssue) 'freeze_with_issue': true,
          if (freezeWithIssue) 'issue_note': trimmedIssueNote,
          if (freezeRequestId.trim().isNotEmpty)
            'freeze_request_id': freezeRequestId.trim(),
          if (trimmedBarcodes.isNotEmpty) 'material_barcodes': trimmedBarcodes,
          if (trimmedBarcodes.isEmpty && trimmedBarcode.isNotEmpty)
            'material_barcode': trimmedBarcode,
          if (trimmedQolipCodes.isNotEmpty) 'qolip_codes': trimmedQolipCodes,
          if (trimmedQolipCodes.isEmpty && trimmedQolipCode.isNotEmpty)
            'qolip_code': trimmedQolipCode,
          if (producedQty != null) 'produced_qty': producedQty,
          if (grossQty != null) 'gross_qty': grossQty,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (diameter != null) 'diameter': diameter,
          if (returnInkKg != null) 'return_ink_kg': returnInkKg,
          if (laminationPrintLeftoverRolls != null)
            'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
          if (laminationFilmLeftoverRolls != null)
            'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
          if (rezkaBosmaWaste != null) 'rezka_bosma_waste': rezkaBosmaWaste,
          if (rezkaLaminationWaste != null)
            'rezka_lamination_waste': rezkaLaminationWaste,
          if (rezkaEdgeWaste != null) 'rezka_edge_waste': rezkaEdgeWaste,
          if (totalWaste != null) 'total_waste': totalWaste,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (rezkaFrames.isNotEmpty) 'rezka_frames': rezkaFrames,
          if (uom.trim().isNotEmpty) 'uom': uom.trim(),
          if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          if (progressBatchId.trim().isNotEmpty)
            'progress_batch_id': progressBatchId.trim(),
          if (customerName.trim().isNotEmpty)
            'customer_name': customerName.trim(),
          if (trimmedDriverUrl.isNotEmpty) 'driver_url': trimmedDriverUrl,
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
          if (trimmedCompletionRequestNote.isNotEmpty)
            'completion_request_note': trimmedCompletionRequestNote,
          if (fullCompletionReportRequired)
            'full_completion_report_required': true,
          if (workerHandoff) 'worker_handoff': true,
          if (removeRollFromApparatus) 'remove_roll_from_apparatus': true,
          if (returnedPaintItems.isNotEmpty)
            'returned_paint_items': returnedPaintItems
                .map((item) => item.toJson())
                .toList(growable: false),
          if (returnedPaintImageId.trim().isNotEmpty)
            'returned_paint_image_id': returnedPaintImageId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_action_not_allowed');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['states'];
    final rawOrderControl = payload['order_control'];
    final orderControl = rawOrderControl is Map
        ? AdminOrderControlState.fromRaw(rawOrderControl['state'])
        : null;
    final orderStatus = AdminProductionOrderStatusDetail.fromJson(
      payload['order_status'],
    );
    if (raw is! Map) {
      return AdminApparatusQueueActionResult(
        states: const {},
        orderStatus: orderStatus,
        orderControl: orderControl,
      );
    }
    final progressRaw = payload['progress_batch'];
    final progressBatches = <AdminProgressBatch>[
      if (payload['progress_batches'] is List)
        for (final item in payload['progress_batches'] as List)
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
    ];
    final requestRaw = payload['completion_request'];
    final printRaw = payload['print'];
    final parsedPrintJobs = <UsbRpsPrintRequest>[
      if (payload['prints'] is List)
        for (final item in payload['prints'] as List)
          if (item is Map && item['ok'] == true)
            UsbRpsPrintRequest.fromPrintJson(item.cast<String, dynamic>()),
    ];
    final trainingLocalPrintJobs = orderId.trim().startsWith('training-') &&
            printTransport.isLocal &&
            parsedPrintJobs.isEmpty
        ? _testModeProgressPrintJobs(
            batches: progressBatches,
            printer: printer,
            printMode: printMode,
            customerName: customerName,
          )
        : const <UsbRpsPrintRequest>[];
    final printJobs = <UsbRpsPrintRequest>[
      ...parsedPrintJobs,
      ...trainingLocalPrintJobs,
    ];
    final legacyProgressBatch = progressRaw is Map
        ? AdminProgressBatch.fromJson(progressRaw.cast<String, dynamic>())
        : (progressBatches.isEmpty ? null : progressBatches.first);
    final legacyPrintJob = printRaw is Map && printRaw['ok'] == true
        ? UsbRpsPrintRequest.fromPrintJson(printRaw.cast<String, dynamic>())
        : (printJobs.isEmpty ? null : printJobs.first);
    final parsedStates = <String, String>{
      for (final entry in raw.entries)
        entry.key.toString(): entry.value.toString(),
    };
    return AdminApparatusQueueActionResult(
      states: Map<String, String>.unmodifiable(parsedStates),
      orderStatus: orderStatus,
      orderControl: orderControl,
      progressBatch: legacyProgressBatch,
      progressBatches: progressBatches,
      completionRequest: requestRaw is Map
          ? AdminCompletionRequestNotification.fromJson(
              requestRaw.cast<String, dynamic>(),
            )
          : null,
      printJob: legacyPrintJob,
      printJobs: printJobs,
    );
  }

  Future<AdminProgressBatch> adminProgressQrLookup(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchForKey(normalized);
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      return batch;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/progress-qr/lookup',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'qr_payload': normalized}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_batch_not_found');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batch'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    return AdminProgressBatch.fromJson(raw.cast<String, dynamic>());
  }

  Future<List<AdminProgressBatch>> adminProgressQrHistory({
    int limit = 200,
  }) async {
    final boundedLimit = limit.clamp(1, 200).toInt();
    final profile = AppSession.instance.profile;
    final workerRef = profile?.ref.trim() ?? '';
    final workerName = profile?.displayName.trim() ?? '';
    if (await TestModeController.instance.isEnabled()) {
      if (workerRef.isEmpty && workerName.isEmpty) {
        return const [];
      }
      return _testModeProgressBatchesByQr.values
          .where(
            (batch) =>
                (workerRef.isNotEmpty && batch.workerRef.trim() == workerRef) ||
                (workerName.isNotEmpty &&
                    (batch.workerDisplayName.trim() == workerName ||
                        batch.executorName.trim() == workerName)),
          )
          .take(boundedLimit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/progress-qr/history',
        ).replace(queryParameters: {'limit': boundedLimit.toString()}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_qr_history');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batches'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<AdminProgressBatch> adminProgressBatchCorrect(
    AdminProgressBatchCorrectionInput input,
  ) async {
    if (input.batchId.trim().isEmpty ||
        input.expectedRevision <= 0 ||
        !input.producedQty.isFinite ||
        input.producedQty <= 0 ||
        input.uom.trim().isEmpty ||
        input.reason.trim().isEmpty) {
      throw const MobileApiException(
        code: 'progress_input_invalid',
        message: 'WIP o‘zgartirish ma’lumoti to‘liq emas',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      AdminProgressBatch? current;
      for (final batch in _testModeProgressBatchesByQr.values) {
        if (batch.batchId.trim() == input.batchId.trim()) {
          current = batch;
          break;
        }
      }
      if (current == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      if (current.wipStatus.trim().toLowerCase() != 'waiting') {
        throw const MobileApiException(
          code: 'progress_batch_correction_locked',
          message: 'Ishlatilgan WIPni o‘zgartirib bo‘lmaydi',
        );
      }
      if (current.revision != input.expectedRevision) {
        throw const MobileApiException(
          code: 'progress_batch_correction_conflict',
          message: 'WIP boshqa joyda yangilangan',
        );
      }
      final corrected = AdminProgressBatch(
        batchId: current.batchId,
        revision: current.revision + 1,
        sessionId: current.sessionId,
        apparatus: current.apparatus,
        orderId: current.orderId,
        action: current.action,
        status: current.status,
        producedQty: input.producedQty,
        uom: input.uom.trim(),
        qrPayload: current.qrPayload,
        labelItemCode: current.labelItemCode,
        labelItemName: current.labelItemName,
        executorName: current.executorName,
        diameter: input.diameter,
        returnInkKg: input.returnInkKg,
        laminationPrintLeftoverRolls: input.laminationPrintLeftoverRolls,
        laminationFilmLeftoverRolls: input.laminationFilmLeftoverRolls,
        rezkaBosmaWaste: input.rezkaBosmaWaste,
        rezkaLaminationWaste: input.rezkaLaminationWaste,
        rezkaEdgeWaste: input.rezkaEdgeWaste,
        totalWaste: input.totalWaste,
        finishedGoodsKg: input.finishedGoodsKg,
        bobinaKg: input.bobinaKg,
        finishedGoodsMeter: input.finishedGoodsMeter,
        description: input.description.trim(),
        workerRole: current.workerRole,
        workerRef: current.workerRef,
        workerDisplayName: current.workerDisplayName,
        wipStatus: current.wipStatus,
        statusDetail: current.statusDetail,
        currentApparatus: current.currentApparatus,
        currentApparatusKey: current.currentApparatusKey,
        currentLocation: current.currentLocation,
        nextApparatus: current.nextApparatus,
        parentBatchId: current.parentBatchId,
        usedBySessionId: current.usedBySessionId,
        usedByApparatus: current.usedByApparatus,
        processedBySessionId: current.processedBySessionId,
        processedByApparatus: current.processedByApparatus,
        startedAtUnix: current.startedAtUnix,
        completedAtUnix: current.completedAtUnix,
        payloadJson: current.payloadJson,
      );
      _testModeProgressBatchesByQr[current.qrPayload] = corrected;
      return corrected;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/progress-qr/correct',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'progress_batch_correction_failed',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batch'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_correction_failed',
        message: 'Yangilangan WIP ma’lumoti kelmadi',
      );
    }
    return AdminProgressBatch.fromJson(raw.cast<String, dynamic>());
  }

  Future<AdminProgressQrReprintResult> adminProgressQrReprint({
    required String qrPayload,
    String progressBatchId = '',
    String driverUrl = '',
    String printer = '',
    String printMode = '',
    int printCount = 1,
    PrintTransport printTransport = PrintTransport.wifi,
  }) async {
    final normalizedQrPayload = qrPayload.trim();
    final normalizedBatchId = progressBatchId.trim();
    if (normalizedQrPayload.isEmpty && normalizedBatchId.isEmpty) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    final boundedPrintCount = printCount.clamp(1, 100).toInt();
    final normalizedDriverUrl = driverUrl.trim().replaceFirst(
          RegExp(r'/+$'),
          '',
        );
    final normalizedPrinter = printer.trim();
    final normalizedPrintMode = printMode.trim();

    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchForKey(
        normalizedQrPayload.isNotEmpty
            ? normalizedQrPayload
            : normalizedBatchId,
      );
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      final printJob = UsbRpsPrintRequest(
        epc: batch.qrPayload,
        itemCode: batch.labelItemCode,
        itemName: batch.labelItemName,
        apparatus: batch.apparatus,
        warehouse: 'Ijrochi: ${batch.executorName}',
        printer: normalizedPrinter.isEmpty ? 'godex' : normalizedPrinter,
        printMode: normalizedPrintMode.isEmpty ? 'label' : normalizedPrintMode,
        grossQty: (batch.payloadJson['gross_qty'] as num?)?.toDouble() ??
            batch.finishedGoodsKg ??
            batch.producedQty,
        unit: 'kg',
        tareEnabled: (batch.bobinaKg ?? 0) > 0,
        tareKg: batch.bobinaKg ?? 0,
        printCount: boundedPrintCount,
        labelKind: 'progress',
        executorName: batch.executorName,
        progressQty: batch.finishedGoodsMeter ?? batch.producedQty,
        progressUnit: batch.uom.isEmpty ? 'm' : batch.uom,
        customerName: batch.payloadJson['customer_name']?.toString() ?? '',
      );
      return AdminProgressQrReprintResult(
        ok: true,
        batch: batch,
        printJob: printJob,
        printStatus: 'prepared',
      );
    }

    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/progress-qr/reprint',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          if (normalizedBatchId.isNotEmpty)
            'progress_batch_id': normalizedBatchId,
          if (normalizedQrPayload.isNotEmpty) 'qr_payload': normalizedQrPayload,
          if (normalizedDriverUrl.isNotEmpty) 'driver_url': normalizedDriverUrl,
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
          if (normalizedPrinter.isNotEmpty) 'printer': normalizedPrinter,
          if (normalizedPrintMode.isNotEmpty) 'print_mode': normalizedPrintMode,
          'print_count': boundedPrintCount,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_qr_reprint');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawBatch = payload['batch'];
    if (rawBatch is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    final rawPrint = payload['print'];
    final printMap = rawPrint is Map
        ? rawPrint.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminProgressQrReprintResult(
      ok: payload['ok'] == true,
      batch: AdminProgressBatch.fromJson(rawBatch.cast<String, dynamic>()),
      printJob: printMap['ok'] == true
          ? UsbRpsPrintRequest.fromPrintJson(printMap)
          : null,
      printStatus: printMap['status']?.toString() ?? '',
    );
  }

  Future<AdminProgressQrReport> adminProgressQrReport(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchForKey(normalized);
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      final progressBatches = _testModeProgressBatchesByQr.values
          .where((item) => item.orderId.trim() == batch.orderId.trim())
          .toList(growable: false);
      return AdminProgressQrReport(
        scannedBatch: batch,
        currentBatch: batch,
        isStale: false,
        staleReason: '',
        queueStates: const {},
        logs: const [],
        progressBatches: progressBatches.isEmpty ? [batch] : progressBatches,
        runSessions: const [],
        activeSessions: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/progress-qr/report',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'qr_payload': normalized}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_batch_not_found');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminProgressQrReport.fromJson(payload);
  }

  Future<void> adminSaveProductionMapSequence({
    required String apparatus,
    required List<String> orderIds,
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceSequenceSaveFailure) {
        throw const MobileApiException(
          code: 'production_map_sequence',
          message: 'Ketma-ketlik saqlanmadi (test)',
        );
      }
      _testModeApparatusSequences[normalizedApparatus] = List<String>.from(
        orderIds,
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_ids': orderIds,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
  }

  Future<ProductionMapRunResult> adminRunProductionMap(
    ProductionMapRunRequest input,
  ) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/run'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_run');
    }
    return ProductionMapRunResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminRoleDefinition> adminUpsertRole(AdminRoleDefinition role) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/roles'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(role.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin role save failed');
    }
    return AdminRoleDefinition.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminRoleAssignment>> adminRoleAssignments() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminRoleAssignment>.unmodifiable(_testModeRoleAssignments);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/role-assignments'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin role assignments failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) => AdminRoleAssignment.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<AdminWorker>> adminWorkers({
    String query = '',
    String role = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final needle = query.trim().toLowerCase();
      return _testModeWorkers
          .where(
            (worker) =>
                needle.isEmpty ||
                worker.name.toLowerCase().contains(needle) ||
                worker.level.toLowerCase().contains(needle),
          )
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/workers').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (role.trim().isNotEmpty) 'role': role.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin workers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminWorker.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<AdminWorker> adminCreateWorker({
    required String name,
    required String level,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = AdminWorker(
        id: 'worker-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        phone: '',
        level: level.trim(),
      );
      _testModeWorkers.add(worker);
      return worker;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'level': level}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker create failed');
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSystemUser> adminCreateSystemUser({
    required UserRole role,
    required String name,
    required String phone,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      if (role != UserRole.qolipchi &&
          role != UserRole.boyoqchi &&
          role != UserRole.materialTaminotchi) {
        throw Exception('Unsupported system user role');
      }
      final user = AdminSystemUser(
        id: '${userRoleToJson(role)}-${DateTime.now().microsecondsSinceEpoch}',
        role: role,
        name: name.trim(),
        phone: phone.trim(),
      );
      _testModeSystemUsers.add(user);
      return user;
    }
    if (role != UserRole.qolipchi && role != UserRole.boyoqchi) {
      throw Exception('Unsupported system user role');
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/system-users'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'role': userRoleToJson(role),
          'name': name,
          'phone': phone,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user create failed');
    }
    return AdminSystemUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSystemUser> adminUpdateSystemUserPhone({
    required String id,
    required UserRole role,
    required String name,
    required String phone,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeSystemUsers.indexWhere((user) => user.id == id);
      if (index < 0) throw Exception('Admin system user not found');
      final updated = _testModeSystemUsers[index].copyWith(phone: phone.trim());
      _testModeSystemUsers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/system-users'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'id': id,
          'role': userRoleToJson(role),
          'name': name,
          'phone': phone,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user phone update failed');
    }
    return AdminSystemUser.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSystemUserDetail> adminSystemUserDetail(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final user = _testModeSystemUsers.firstWhere(
        (user) => user.id == id,
        orElse: () => throw Exception('Admin system user not found'),
      );
      return AdminSystemUserDetail(
        id: user.id,
        role: user.role,
        name: user.name,
        phone: user.phone,
        avatarUrl: '',
        code: _testModeSystemUserCodes[user.id] ?? '',
        blocked: false,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/system-users/detail',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user detail failed');
    }
    return AdminSystemUserDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSystemUserDetail> adminRegenerateSystemUserCode(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final user = _testModeSystemUsers.firstWhere(
        (user) => user.id == id,
        orElse: () => throw Exception('Admin system user not found'),
      );
      final prefix = user.role == UserRole.boyoqchi ? '80' : '50';
      final code =
          '$prefix${DateTime.now().microsecondsSinceEpoch.toString().padLeft(10, '0').substring(0, 10)}';
      _testModeSystemUserCodes[id] = code;
      return AdminSystemUserDetail(
        id: user.id,
        role: user.role,
        name: user.name,
        phone: user.phone,
        avatarUrl: '',
        code: code,
        blocked: false,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/system-users/code/regenerate',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin system user code regenerate failed');
    }
    return AdminSystemUserDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWorker> adminUpdateWorkerLevel({
    required String id,
    required String level,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWorkers.indexWhere((worker) => worker.id == id);
      if (index < 0) {
        throw Exception('Admin worker not found');
      }
      final updated = _testModeWorkers[index].copyWith(level: level.trim());
      _testModeWorkers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'name': '', 'level': level}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker level update failed');
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWorker> adminUpdateWorkerName({
    required String id,
    required String name,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Admin worker name is required');
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWorkers.indexWhere((worker) => worker.id == id);
      if (index < 0) {
        throw Exception('Admin worker not found');
      }
      final updated = _testModeWorkers[index].copyWith(name: trimmedName);
      _testModeWorkers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'name': trimmedName}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_worker_name_update_failed',
        fallbackMessage: 'Ishchi ismi saqlanmadi',
      );
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWorker> adminUpdateWorkerPhone({
    required String id,
    required String phone,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeWorkers.indexWhere((worker) => worker.id == id);
      if (index < 0) {
        throw Exception('Admin worker not found');
      }
      final updated = _testModeWorkers[index].copyWith(phone: phone.trim());
      _testModeWorkers[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/workers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'id': id, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_worker_phone_update_failed',
        fallbackMessage: 'Ishchi telefoni saqlanmadi',
      );
    }
    return AdminWorker.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWorkerDetail> adminWorkerDetail(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = _testModeWorkers.firstWhere(
        (worker) => worker.id == id,
        orElse: () => throw Exception('Admin worker not found'),
      );
      return AdminWorkerDetail(
        id: worker.id,
        name: worker.name,
        phone: worker.phone,
        avatarUrl: '',
        level: worker.level,
        code: _testModeWorkerCodes[worker.id] ?? '',
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/workers/detail',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker detail failed');
    }
    return AdminWorkerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWorkerProfileDetail> adminWorkerProfileDetail(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = await adminWorkerDetail(id);
      final groups = _testModeWorkerGroups
          .where((group) => group.workerIds.any((workerId) => workerId == id))
          .map(_hydrateTestModeWorkerGroup)
          .toList(growable: false);
      return AdminWorkerProfileDetail(
        worker: worker,
        assignedGroups: groups,
        activeSessions: const [],
        recentBatches: const [],
        recentLogs: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/workers/profile-detail',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker profile detail failed');
    }
    return AdminWorkerProfileDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminWorkerDeletionCheck> adminWorkerDeletionCheck(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = _testModeWorkers.firstWhere(
        (worker) => worker.id == id,
        orElse: () => throw Exception('Admin worker not found'),
      );
      final groups = _testModeWorkerGroups.where(
        (group) => group.workerIds.any((workerId) => workerId == id),
      );
      final apparatuses = groups
          .map((group) => group.apparatus.trim())
          .where(
            (apparatus) =>
                apparatus.isNotEmpty && apparatus != 'worker-settings',
          )
          .toSet();
      final connections = <AdminWorkerDeletionDependency>[
        for (final group in groups)
          AdminWorkerDeletionDependency(
            kind: 'worker_group',
            label: group.groupCode,
            apparatus: group.apparatus,
            orderId: '',
            status: '',
          ),
        for (final apparatus in apparatuses)
          AdminWorkerDeletionDependency(
            kind: 'apparatus',
            label: apparatus,
            apparatus: apparatus,
            orderId: '',
            status: '',
          ),
      ];
      return AdminWorkerDeletionCheck(
        workerId: worker.id,
        workerName: worker.name,
        blocked: false,
        requiresConfirmation: connections.isNotEmpty,
        activeWork: const [],
        connections: connections,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/workers/delete-check',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'worker_delete_check_failed',
        fallbackMessage: 'Ishchi ulanishlari tekshirilmadi',
      );
    }
    return AdminWorkerDeletionCheck.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> adminDeactivateWorker({
    required String id,
    required bool confirmConnections,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final check = await adminWorkerDeletionCheck(id);
      if (check.blocked || check.requiresConfirmation && !confirmConnections) {
        throw AdminWorkerDeletionRejected(check);
      }
      for (var index = 0; index < _testModeWorkerGroups.length; index++) {
        final group = _testModeWorkerGroups[index];
        _testModeWorkerGroups[index] = group.copyWith(
          workerIds: group.workerIds
              .where((workerId) => workerId != id)
              .toList(growable: false),
        );
      }
      final workerExists = _testModeWorkers.any((worker) => worker.id == id);
      if (!workerExists) {
        throw Exception('Admin worker not found');
      }
      _testModeWorkers.removeWhere((worker) => worker.id == id);
      _testModeRoleAssignments.removeWhere(
        (assignment) =>
            assignment.principalRole == UserRole.aparatchi &&
            assignment.principalRef.trim() == id.trim(),
      );
      _testModeWorkerCodes.remove(id);
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('$baseUrl/v1/mobile/admin/workers').replace(
          queryParameters: {
            'id': id,
            if (confirmConnections) 'confirm_connections': 'true',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode == 409) {
      throw AdminWorkerDeletionRejected(
        AdminWorkerDeletionCheck.fromJson(
          (jsonDecode(response.body) as Map).cast<String, dynamic>(),
        ),
      );
    }
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'worker_delete_failed',
        fallbackMessage: 'Ishchi faolsizlantirilmadi',
      );
    }
  }

  Future<AdminWorkerDetail> adminRegenerateWorkerCode(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final worker = _testModeWorkers.firstWhere(
        (worker) => worker.id == id,
        orElse: () => throw Exception('Admin worker not found'),
      );
      final code =
          '40${DateTime.now().microsecondsSinceEpoch.toString().padLeft(10, '0').substring(0, 10)}';
      _testModeWorkerCodes[worker.id] = code;
      return AdminWorkerDetail(
        id: worker.id,
        name: worker.name,
        phone: worker.phone,
        avatarUrl: '',
        level: worker.level,
        code: code,
        codeLocked: false,
        codeRetryAfterSec: 0,
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/workers/code/regenerate',
        ).replace(queryParameters: {'id': id}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker code regenerate failed');
    }
    return AdminWorkerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminWorkerGroup>> adminWorkerGroups({
    String apparatusId = '',
  }) async {
    final normalizedApparatusId = _requireCanonicalApparatusId(
      apparatusId,
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      final key = normalizedApparatusId;
      return _testModeWorkerGroups
          .where(
            (group) => key.isEmpty || group.apparatusId.trim() == key,
          )
          .map(_hydrateTestModeWorkerGroup)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/worker-groups').replace(
          queryParameters: {
            if (normalizedApparatusId.isNotEmpty)
              'apparatus_id': normalizedApparatusId,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker groups failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminWorkerGroup.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<AdminWorkerGroup> adminSaveWorkerGroup(
    AdminWorkerGroup group, {
    String? previousApparatusId,
    String? previousGroupCode,
  }) async {
    _requireCanonicalApparatusId(group.apparatusId);
    final validatedPreviousApparatusId = _requireCanonicalApparatusId(
      previousApparatusId ?? '',
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      final normalized = _normalizeTestModeWorkerGroup(group);
      final key = normalized.apparatusId.trim();
      final code = normalized.groupCode.trim().toUpperCase();
      final previousKey = previousApparatusId?.trim();
      final previousCode = previousGroupCode == null
          ? null
          : previousGroupCode
              .trim()
              .split(RegExp(r'\s+'))
              .join(' ')
              .toUpperCase();
      final hasPreviousIdentity = previousKey != null &&
          previousKey.isNotEmpty &&
          previousCode != null &&
          previousCode.isNotEmpty;
      final previousExists = !hasPreviousIdentity ||
          _testModeWorkerGroups.any(
            (item) =>
                item.apparatusId.trim() == previousKey &&
                item.groupCode.trim().toUpperCase() == previousCode,
          );
      if (!previousExists) {
        throw const MobileApiException(
          code: 'worker_group_not_found',
          message: 'Guruh topilmadi',
        );
      }
      final isPreviousGroup = (AdminWorkerGroup item) {
        if (hasPreviousIdentity) {
          return item.apparatusId.trim() == previousKey &&
              item.groupCode.trim().toUpperCase() == previousCode;
        }
        return item.apparatusId.trim() == key &&
            item.groupCode.trim().toUpperCase() == code;
      };
      final duplicateName = _testModeWorkerGroups.any(
        (item) =>
            item.apparatusId.trim() == key &&
            item.groupCode.trim().toUpperCase() == code &&
            !isPreviousGroup(item),
      );
      if (duplicateName) {
        throw const MobileApiException(
          code: 'worker_group_name_exists',
          message: 'Bu guruh nomi allaqachon bor',
        );
      }
      final duplicate = _testModeWorkerGroups.any(
        (item) =>
            item.apparatusId.trim() == key &&
            !isPreviousGroup(item) &&
            item.workerIds.any(normalized.workerIds.toSet().contains),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'worker_duplicated_in_group',
          message: 'Ishchi boshqa guruhga ulangan',
        );
      }
      _testModeWorkerGroups.removeWhere(isPreviousGroup);
      _testModeWorkerGroups.add(normalized);
      return _hydrateTestModeWorkerGroup(normalized);
    }
    final payload = group.toJson();
    final normalizedPreviousApparatusId = validatedPreviousApparatusId;
    final normalizedPreviousGroupCode = previousGroupCode?.trim() ?? '';
    if (normalizedPreviousApparatusId.isNotEmpty) {
      payload['previous_apparatus_id'] = normalizedPreviousApparatusId;
    }
    if (normalizedPreviousGroupCode.isNotEmpty) {
      payload['previous_group_code'] = normalizedPreviousGroupCode;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/worker-groups'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(payload),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin worker group save failed');
    }
    return AdminWorkerGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  AdminWorkerGroup _normalizeTestModeWorkerGroup(AdminWorkerGroup group) {
    final canonical = _testModeRequiredApparatus(group.apparatusId);
    final workerIds = group.workerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final groupCode =
        group.groupCode.trim().split(RegExp(r'\s+')).join(' ').toUpperCase();
    return AdminWorkerGroup(
      apparatus: canonical.name.trim(),
      apparatusId: canonical.id.trim(),
      groupCode: groupCode,
      shift: group.shift.trim().isEmpty ? 'kunduz' : group.shift.trim(),
      startTime:
          group.startTime.trim().isEmpty ? '08:00' : group.startTime.trim(),
      endTime: group.endTime.trim().isEmpty ? '20:00' : group.endTime.trim(),
      workDaysPerWeek: group.workDaysPerWeek.clamp(1, 7).toInt(),
      startDay:
          group.startDay.trim().isEmpty ? 'monday' : group.startDay.trim(),
      accountingEnabled: group.accountingEnabled,
      workerIds: workerIds,
    );
  }

  AdminWorkerGroup _hydrateTestModeWorkerGroup(AdminWorkerGroup group) {
    return group.copyWith(
      workers: [
        for (final id in group.workerIds)
          for (final worker in _testModeWorkers)
            if (worker.id == id) worker,
      ],
    );
  }

  Future<AdminRoleAssignment> adminUpsertRoleAssignment(
    AdminRoleAssignment assignment,
  ) async {
    final invalidApparatusId = assignment.assignedApparatus.any(
      (item) => !isCanonicalApparatusId(item),
    );
    if (invalidApparatusId) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Canonical apparatus ID noto‘g‘ri',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final normalized = AdminRoleAssignment(
        principalRole: assignment.principalRole,
        principalRef: assignment.principalRef.trim(),
        roleId: assignment.roleId.trim(),
        assignedApparatus: assignment.assignedApparatus
            .map((item) => item.trim())
            .where(isCanonicalApparatusId)
            .toSet()
            .toList(growable: false),
        assignedItemGroups: assignment.assignedItemGroups
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet()
            .toList(growable: false),
      );
      final index = _testModeRoleAssignments.indexWhere(
        (item) =>
            item.principalRole == normalized.principalRole &&
            item.principalRef.trim() == normalized.principalRef,
      );
      if (index >= 0) {
        _testModeRoleAssignments[index] = normalized;
      } else {
        _testModeRoleAssignments.add(normalized);
      }
      return normalized;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/role-assignments'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(assignment.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_role_assignment_save_failed',
        fallbackMessage: 'Role biriktirish saqlanmadi',
      );
    }
    return AdminRoleAssignment.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSuppliersPage> adminSuppliersPage() async {
    if (await TestModeController.instance.isEnabled()) {
      return AdminSuppliersPage(
        summary: TestModeDemoData.supplierSummary,
        suppliers: TestModeDemoData.suppliers,
        customers: TestModeDemoData.customers,
        settings: TestModeDemoData.adminSettings,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin suppliers page failed');
    }
    return AdminSuppliersPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminSupplier>> adminSuppliers({
    int limit = 20,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierPage(limit: limit, offset: offset);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers/list').replace(
          queryParameters: {
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin suppliers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminSupplier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminUserListPage> adminUserList({
    String query = '',
    int limit = 20,
    int offset = 0,
    String role = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final pageLimit = limit <= 0 ? 20 : limit.clamp(1, 50);
      final normalizedRole = role.trim().toLowerCase();
      final systemRole = switch (normalizedRole) {
        'qolipchi' => UserRole.qolipchi,
        'boyoqchi' => UserRole.boyoqchi,
        'material_taminotchi' ||
        'material-taminotchi' =>
          UserRole.materialTaminotchi,
        _ => null,
      };
      if (systemRole != null) {
        final needle = query.trim().toLowerCase();
        final items = _testModeSystemUsers
            .where(
              (user) =>
                  user.role == systemRole &&
                  (needle.isEmpty ||
                      user.name.toLowerCase().contains(needle) ||
                      user.phone.toLowerCase().contains(needle)),
            )
            .map(
              (user) => AdminUserListEntry(
                id: user.id,
                name: user.name,
                phone: user.phone,
                kind: switch (systemRole) {
                  UserRole.qolipchi => AdminUserKind.qolipchi,
                  UserRole.materialTaminotchi =>
                    AdminUserKind.materialTaminotchi,
                  _ => AdminUserKind.boyoqchi,
                },
                principalRole: systemRole,
                roleLabelOverride: userRoleLabel(systemRole),
              ),
            )
            .toList(growable: false);
        return AdminUserListPage(
          items: items.skip(offset).take(pageLimit).toList(growable: false),
          hasMore: items.length > offset + pageLimit,
        );
      }
      if (normalizedRole == 'worker' ||
          normalizedRole == 'ishchi' ||
          normalizedRole == 'aparatchi') {
        final needle = query.trim().toLowerCase();
        final items = _testModeWorkers
            .where(
              (worker) =>
                  needle.isEmpty ||
                  worker.name.toLowerCase().contains(needle) ||
                  worker.phone.toLowerCase().contains(needle) ||
                  worker.level.toLowerCase().contains(needle),
            )
            .map(
              (worker) => AdminUserListEntry(
                id: worker.id,
                name: worker.name,
                phone: worker.phone,
                kind: AdminUserKind.worker,
                principalRole: UserRole.aparatchi,
                roleLabelOverride: worker.level,
              ),
            )
            .toList(growable: false);
        return AdminUserListPage(
          items: items.skip(offset).take(pageLimit).toList(growable: false),
          hasMore: items.length > offset + pageLimit,
        );
      }
      if (normalizedRole == 'werka') {
        final page = TestModeDemoData.userListPage(
          query: query,
          limit: pageLimit,
          offset: offset,
        );
        final items = page.items
            .where(
              (item) =>
                  item.kind == AdminUserKind.werka ||
                  item.principalRole == UserRole.werka,
            )
            .toList(growable: false);
        return AdminUserListPage(items: items, hasMore: false);
      }
      return TestModeDemoData.userListPage(
        query: query,
        limit: pageLimit,
        offset: offset,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/users/list').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
            if (role.trim().isNotEmpty) 'role': role.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin user list failed');
    }
    return AdminUserListPage.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSupplierSummary> adminSupplierSummary() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierSummary;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers/summary'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier summary failed');
    }
    return AdminSupplierSummary.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<AdminSupplier>> adminInactiveSuppliers() async {
    if (await TestModeController.instance.isEnabled()) {
      return const <AdminSupplier>[];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers/inactive'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin inactive suppliers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => AdminSupplier.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminSupplierDetail> adminSupplierDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.supplierDetail(ref);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/detail',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier detail failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminCustomerDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.customerDetail(ref);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/detail',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer detail failed');
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminMaterialTaminotchiDetail(String ref) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalizedRef = ref.trim().toLowerCase();
      final assignedWarehouses = _testModeWarehouseAssignments
          .where(
            (assignment) =>
                assignment.principalRole == UserRole.materialTaminotchi &&
                assignment.principalRef.trim().toLowerCase() == normalizedRef,
          )
          .map((assignment) => assignment.warehouse.trim())
          .where((warehouse) => warehouse.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
      return TestModeDemoData.customerDetail(ref).copyWith(
        ref: ref.trim(),
        assignedItemGroups:
            _testModeMaterialItemGroups[normalizedRef] ?? const [],
        assignedWarehouses: assignedWarehouses,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/material-taminotchilar/detail',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin material taminotchi detail failed');
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> _adminMaterialTaminotchiDetailFromPayload(
    String ref,
    Map<String, dynamic> payload,
  ) async {
    var detail = AdminCustomerDetail.fromJson(payload);
    final normalizedRef = ref.trim().toLowerCase();

    // Older test backends do not expose scopes on the profile detail DTO.
    // Hydrate them through the stable assignment APIs until every runtime is
    // upgraded to the richer response contract.
    if (!payload.containsKey('assigned_item_groups')) {
      final assignments = await adminRoleAssignments();
      final assignedGroups = <String>[];
      for (final assignment in assignments) {
        if (_isMaterialRoleAssignmentForRef(assignment, normalizedRef)) {
          assignedGroups.addAll(assignment.assignedItemGroups);
          break;
        }
      }
      detail = detail.copyWith(
        assignedItemGroups: _normalizedAdminScopeValues(assignedGroups),
      );
    }

    if (!payload.containsKey('assigned_warehouses')) {
      final assignments = await adminWarehouseAssignments();
      detail = detail.copyWith(
        assignedWarehouses: _normalizedAdminScopeValues(
          assignments
              .where(
                (assignment) =>
                    assignment.principalRole == UserRole.materialTaminotchi &&
                    assignment.principalRef.trim().toLowerCase() ==
                        normalizedRef,
              )
              .map((assignment) => assignment.warehouse),
        ),
      );
    }
    return detail;
  }

  Future<AdminCustomerDetail> adminUpdateMaterialTaminotchiPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/material-taminotchilar/phone',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin material taminotchi phone update failed');
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminRegenerateMaterialTaminotchiCode(
    String ref,
  ) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/material-taminotchilar/code/regenerate',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin material taminotchi code regenerate failed');
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminUpdateMaterialTaminotchiItemGroups({
    required String ref,
    required List<String> assignedItemGroups,
  }) async {
    final normalizedGroups = _normalizedAdminScopeValues(assignedItemGroups);
    if (normalizedGroups.isEmpty) {
      throw const MobileApiException(
        code: 'material_item_groups_required',
        message: 'Kamida bitta mahsulot guruhini tanlang',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      _testModeMaterialItemGroups[ref.trim().toLowerCase()] = normalizedGroups;
      return (await adminMaterialTaminotchiDetail(
        ref,
      ))
          .copyWith(assignedItemGroups: normalizedGroups);
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/material-taminotchilar/item-groups',
        ).replace(queryParameters: {'ref': ref.trim()}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'assigned_item_groups': normalizedGroups}),
      ),
    );
    if (response.statusCode == 404) {
      final normalizedRef = ref.trim().toLowerCase();
      AdminRoleAssignment? existing;
      for (final assignment in await adminRoleAssignments()) {
        if (_isMaterialRoleAssignmentForRef(assignment, normalizedRef)) {
          existing = assignment;
          break;
        }
      }
      await adminUpsertRoleAssignment(
        AdminRoleAssignment(
          principalRole: UserRole.materialTaminotchi,
          principalRef: ref.trim(),
          roleId: existing == null || existing.roleId.trim().isEmpty
              ? 'material_taminotchi'
              : existing.roleId,
          assignedApparatus: existing?.assignedApparatus ?? const [],
          assignedItemGroups: normalizedGroups,
        ),
      );
      return adminMaterialTaminotchiDetail(ref);
    }
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_material_item_groups_update_failed',
        fallbackMessage: 'Mahsulot guruhlari saqlanmadi',
      );
    }
    return _adminMaterialTaminotchiDetailFromPayload(
      ref,
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminUpdateCustomerPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/phone',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer phone update failed');
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminRegenerateCustomerCode(String ref) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/code/regenerate',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer code regenerate failed');
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> adminRemoveCustomer(String ref) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/customers/remove',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customer remove failed');
    }
  }

  Future<AdminSupplier> adminCreateSupplier({
    required String name,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/suppliers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier create failed');
    }
    return AdminSupplier.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<CustomerDirectoryEntry> adminCreateCustomer({
    required String name,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/customers'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'name': name, 'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_customer_create_failed',
        fallbackMessage: 'Foydalanuvchi yaratilmadi',
      );
    }
    return CustomerDirectoryEntry.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminCustomerDetail> adminCreateMaterialTaminotchi({
    required String name,
    required String phone,
    required List<String> assignedItemGroups,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/admin/material-taminotchilar'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'assigned_item_groups': assignedItemGroups,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'admin_material_taminotchi_create_failed',
        fallbackMessage: 'Foydalanuvchi yaratilmadi',
      );
    }
    return AdminCustomerDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<CustomerDirectoryEntry>> adminCustomers({
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.customerPage(limit: limit, offset: offset);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/customers/list').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin customers failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map(
          (item) =>
              CustomerDirectoryEntry.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminSupplierDetail> adminSetSupplierBlocked({
    required String ref,
    required bool blocked,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/status',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'blocked': blocked}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier status failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSupplierDetail> adminUpdateSupplierPhone({
    required String ref,
    required String phone,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/phone',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'phone': phone}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier phone update failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSupplierDetail> adminRegenerateSupplierCode(String ref) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/code/regenerate',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier code regenerate failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSupplierDetail> adminUpdateSupplierItems({
    required String ref,
    required List<String> itemCodes,
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'item_codes': itemCodes}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier item update failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<SupplierItem>> adminAssignedSupplierItems(String ref) async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items/assigned',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin assigned supplier items failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AdminSupplierDetail> adminAssignSupplierItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items/add',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'item_code': itemCode}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin assign supplier item failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminSupplierDetail> adminRemoveSupplierItem({
    required String ref,
    required String itemCode,
  }) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/items/remove',
        ).replace(queryParameters: {'ref': ref, 'item_code': itemCode}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin remove supplier item failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> adminRemoveSupplier(String ref) async {
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/remove',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier remove failed');
    }
  }

  Future<AdminSupplierDetail> adminRestoreSupplier(String ref) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '$baseUrl/v1/mobile/admin/suppliers/restore',
        ).replace(queryParameters: {'ref': ref}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin supplier restore failed');
    }
    return AdminSupplierDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

bool _isSameProductionMapOrder(
  ProductionMapDefinition current,
  ProductionMapDefinition next,
) {
  return current.id.trim() == next.id.trim() &&
      current.title.trim() == next.title.trim() &&
      current.productCode.trim() == next.productCode.trim();
}

bool _isSheetOrderMap(ProductionMapDefinition map) {
  final id = map.id.trim();
  final orderNumber = map.orderNumber.trim();
  return id.startsWith('zakaz-') && RegExp(r'^\d{4}$').hasMatch(orderNumber);
}

ProductionMapDefinition _testModeAssignOrderNumberIfMissing(
  ProductionMapDefinition map,
) {
  if (map.orderNumber.trim().isNotEmpty ||
      !map.id.trim().toLowerCase().startsWith('zakaz-draft-')) {
    return map;
  }
  var maxOrderNumber = 0;
  for (final saved in _testModeProductionMaps) {
    final value = saved.map.orderNumber.trim();
    if (!RegExp(r'^\d{1,4}$').hasMatch(value)) {
      continue;
    }
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > maxOrderNumber) {
      maxOrderNumber = parsed;
    }
  }
  final nextOrderNumber = maxOrderNumber + 1;
  if (nextOrderNumber > 9999) {
    throw const MobileApiException(
      code: 'order_number_exhausted',
      message: 'Zakaz raqamlari limiti tugagan',
    );
  }
  final orderNumber = nextOrderNumber.toString().padLeft(4, '0');
  return map.copyWith(
    id: 'zakaz-$orderNumber',
    code: orderNumber,
    orderNumber: orderNumber,
  );
}

ProductionMapDefinition _orderMapWithTemplateRezkaKadrCount(
  ProductionMapDefinition map,
  CalculateOrderTemplate template,
) {
  if ((!_isSheetOrderMap(map) && !_isTrainingOrderMap(map)) ||
      !template.frameCount.isFinite ||
      template.frameCount <= 0) {
    return map;
  }
  final frameCount = template.frameCount.round();
  if (frameCount <= 0) {
    return map;
  }
  var changed = false;
  final nodes = map.nodes.map((node) {
    if (node.kind == 'apparatus' && _testModeNodeHasOperation(node, 'cut')) {
      if (node.rezkaKadrCount == frameCount) {
        return node;
      }
      changed = true;
      return node.copyWith(rezkaKadrCount: frameCount);
    }
    return node;
  }).toList(growable: false);
  return changed ? map.copyWith(nodes: nodes) : map;
}

String _templateSourceMapIdForSave(
  ProductionMapDefinition map,
  CalculateOrderTemplate template,
) {
  final sourceMapId = template.sourceMapId.trim();
  if (sourceMapId.isEmpty && !_isSheetOrderMap(map)) {
    return map.id.trim();
  }
  return sourceMapId;
}

ProductionMapDefinition? _templateMapCopyForSave(
  ProductionMapDefinition map,
  CalculateOrderTemplate template,
) {
  if (template.sourceMapId.trim().isNotEmpty || !_isSheetOrderMap(map)) {
    return null;
  }
  final mapId = map.id.trim();
  if (mapId.isEmpty) {
    return null;
  }
  return ProductionMapDefinition(
    id: 'template-$mapId',
    productCode: map.productCode,
    title: map.title,
    code: '',
    orderNumber: '',
    rollCount: map.rollCount,
    widthMm: map.widthMm,
    nodes: map.nodes,
    edges: map.edges,
  );
}

bool _wipStatusMatchesFilter(String rawStatus, String rawFilter) {
  final status = rawStatus.trim().toLowerCase();
  final filter = rawFilter.trim().toLowerCase();
  if (filter.isEmpty || filter == 'all') {
    return true;
  }
  if (filter == 'open' || filter == 'active') {
    return status != 'processed';
  }
  return status == filter;
}

AdminApparatusQueuePolicy _effectiveTestModeQueuePolicy(
  String apparatusId,
) {
  final canonical = _testModeRequiredApparatus(apparatusId);
  final locked = canonical.operation.trim().toLowerCase() == 'print';
  if (locked) {
    return AdminApparatusQueuePolicy(
      apparatusId: canonical.id,
      apparatus: canonical.name,
      policy: ApparatusQueuePolicy.strictSequence,
      locked: true,
      reason: 'pechat_always_strict',
    );
  }
  return _testModeApparatusQueuePolicies[canonical.id] ??
      AdminApparatusQueuePolicy(
        apparatusId: canonical.id,
        apparatus: canonical.name,
        policy: ApparatusQueuePolicy.strictSequence,
      );
}

String _testModeQueueHistoryStatus({
  required String apparatus,
  required String orderId,
  required String fallbackStatus,
}) {
  final normalizedOrderId = orderId.trim();
  final normalizedFallback = fallbackStatus.trim().toLowerCase();
  if (normalizedFallback != 'completed') {
    return 'in_progress';
  }
  final stageCompleted = _testModeApparatusQueueStates.entries.any(
    (entry) =>
        entry.key.trim() == apparatus.trim() &&
        entry.value[normalizedOrderId]?.trim().toLowerCase() == 'completed',
  );
  return stageCompleted ? 'completed' : 'in_progress';
}

void _testModeRecordCompletedQueueOrder({
  required String actorRef,
  required String apparatus,
  required String orderId,
  required String status,
  String issueNote = '',
}) {
  final normalizedActorRef = actorRef.trim();
  final normalizedOrderId = orderId.trim();
  if (normalizedActorRef.isEmpty || normalizedOrderId.isEmpty) {
    return;
  }
  _testModeCompletedQueueOrders.removeWhere(
    (item) =>
        item.actorRef == normalizedActorRef &&
        item.order.orderId == normalizedOrderId,
  );
  _testModeCompletedQueueOrders.insert(
    0,
    _TestModeCompletedQueueOrder(
      actorRef: normalizedActorRef,
      order: AdminCompletedQueueOrder(
        apparatus: apparatus.trim(),
        orderId: normalizedOrderId,
        completedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        status: status.trim().isEmpty ? 'completed' : status.trim(),
        issueNote: issueNote.trim(),
      ),
    ),
  );
}

AdminProgressBatch _testModeProgressBatch({
  required String apparatus,
  required String orderId,
  required String action,
  required String status,
  required double producedQty,
  required String uom,
  String? batchIdOverride,
  String? qrPayloadOverride,
  String parentBatchId = '',
  Map<String, dynamic> payloadJson = const {},
  double? diameter,
  double? returnInkKg,
  double? laminationPrintLeftoverRolls,
  double? laminationFilmLeftoverRolls,
  double? rezkaBosmaWaste,
  double? rezkaLaminationWaste,
  double? rezkaEdgeWaste,
  double? totalWaste,
  double? finishedGoodsKg,
  double? finishedGoodsMeter,
  double? bobinaKg,
}) {
  final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final batchId = batchIdOverride?.trim().isNotEmpty == true
      ? batchIdOverride!.trim()
      : _testModeProductionProgressBatchId(
          apparatus: apparatus,
          orderId: orderId,
          action: action,
        );
  final qrPayload = qrPayloadOverride?.trim().isNotEmpty == true
      ? qrPayloadOverride!.trim()
      : _testModeProductionProgressQrPayload(batchId);
  final executor = AppSession.instance.profile?.displayName.trim() ?? '';
  final orderMap = _testModeOrderById(orderId)?.map;
  final nextApparatus = orderMap == null
      ? ''
      : productionMapNextWorkStageStation(map: orderMap, station: apparatus) ??
          '';
  final isFinalOutput = orderMap != null &&
      productionMapIsFinalWorkStageStation(map: orderMap, station: apparatus);
  final orderTitle = orderMap == null
      ? orderId
      : (orderMap.title.trim().isNotEmpty
          ? orderMap.title.trim()
          : orderMap.productCode.trim());
  final productKind =
      isFinalOutput ? 'tayyor mahsulot' : 'yarim tayyor mahsulot';
  final actionLabel = switch (action.trim()) {
    'pause' => 'chiqarildi',
    'detach_roll' => 'rulon yechildi',
    'roll_complete' => 'rulon tugatildi',
    'complete' => 'ish tugatildi',
    _ => status.trim(),
  };
  final statusDetail = AdminProgressBatchStatusDetail.fromJsonOrBatchJson({
    'action': action,
    'status': status,
    'wip_status': 'waiting',
    'next_apparatus': nextApparatus,
  });
  return AdminProgressBatch(
    batchId: batchId,
    sessionId: 'test-session-$orderId',
    apparatus: apparatus,
    orderId: orderId,
    action: action,
    status: status,
    producedQty: producedQty,
    uom: uom,
    qrPayload: qrPayload,
    labelItemCode: orderId,
    labelItemName:
        '$orderTitle $productKind, apparat: $apparatus, $actionLabel',
    executorName: executor,
    diameter: diameter,
    returnInkKg: returnInkKg,
    laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
    laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
    rezkaBosmaWaste: rezkaBosmaWaste,
    rezkaLaminationWaste: rezkaLaminationWaste,
    rezkaEdgeWaste: rezkaEdgeWaste,
    totalWaste: totalWaste,
    finishedGoodsKg: finishedGoodsKg,
    finishedGoodsMeter: finishedGoodsMeter,
    bobinaKg: bobinaKg,
    wipStatus: 'waiting',
    statusDetail: statusDetail,
    currentApparatus: apparatus,
    currentLocation: apparatus,
    nextApparatus: nextApparatus,
    parentBatchId: parentBatchId,
    startedAtUnix: nowUnix,
    completedAtUnix: nowUnix,
    payloadJson: payloadJson,
  );
}

String _testModeProductionProgressBatchId({
  required String apparatus,
  required String orderId,
  required String action,
}) {
  final stamp =
      BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000);
  return 'progress-batch:$stamp:'
      '${_testModeProgressSanitizeId(apparatus)}:'
      '${_testModeProgressSanitizeId(orderId)}:'
      '${action.trim().toLowerCase()}';
}

String _testModeProductionProgressQrPayload(String batchId) {
  final parts = batchId.split(':');
  final stamp = parts.length > 1
      ? BigInt.tryParse(parts[1]) ??
          BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000)
      : BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000);
  final stampHex = (stamp & BigInt.parse('ffffffffffffffff', radix: 16))
      .toRadixString(16)
      .padLeft(16, '0');
  final hashHex = _testModeProductionProgressQrHash(
    batchId,
  ).toRadixString(16).padLeft(4, '0');
  return '4001$stampHex$hashHex'.toUpperCase();
}

bool _isProductionProgressQrPayload(String value) =>
    RegExp(r'^4001[0-9A-F]{20}$', caseSensitive: false).hasMatch(value.trim());

int _testModeProductionProgressQrHash(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in utf8.encode(value.trim())) {
    hash = hash ^ BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  return (hash & BigInt.from(0xffff)).toInt();
}

String _testModeProgressSanitizeId(String value) {
  final out = StringBuffer();
  for (final rune in value.trim().runes) {
    final isAsciiNumber = rune >= 0x30 && rune <= 0x39;
    final isAsciiUpper = rune >= 0x41 && rune <= 0x5a;
    final isAsciiLower = rune >= 0x61 && rune <= 0x7a;
    if (isAsciiNumber || isAsciiUpper || isAsciiLower) {
      out.writeCharCode(isAsciiUpper ? rune + 0x20 : rune);
    } else {
      out.write('-');
    }
  }
  final sanitized = out.toString().replaceAll(RegExp(r'^-+|-+$'), '');
  return sanitized.isEmpty ? 'blank' : sanitized;
}

String _testModeProgressQueueKey(String apparatus, String orderId) =>
    '${apparatus.trim()}|${orderId.trim()}';

AdminProgressBatch? _testModeProgressBatchForKey(String key) {
  final normalized = key.trim();
  if (normalized.isEmpty) return null;
  for (final batch in _testModeProgressBatchesByQr.values) {
    if (batch.qrPayload.trim().toLowerCase() == normalized.toLowerCase() ||
        batch.batchId.trim().toLowerCase() == normalized.toLowerCase()) {
      return batch;
    }
  }
  return null;
}

ProductionMapSaved? _testModeOrderById(String orderId) {
  final normalized = orderId.trim();
  for (final saved in _testModeProductionMaps) {
    if (saved.map.id.trim() == normalized) return saved;
  }
  return null;
}

int? _testModeRezkaKadrCount({
  required String orderId,
  required String apparatus,
}) {
  final map = _testModeOrderById(orderId)?.map;
  if (map == null) return null;
  for (final node in map.nodes) {
    if (node.kind == 'apparatus' &&
        _testModeNodeHasOperation(node, 'cut') &&
        _testModeProductionMapNodeMatchesStation(node, apparatus) &&
        node.rezkaKadrCount != null &&
        node.rezkaKadrCount! > 0) {
      return node.rezkaKadrCount;
    }
  }
  for (final template in _testModeCalculateOrderTemplates) {
    final matchesOrder = template.sourceMapId.trim() == map.id.trim() ||
        (map.orderNumber.trim().isNotEmpty &&
            template.orderNumber.trim() == map.orderNumber.trim());
    if (!matchesOrder ||
        !template.frameCount.isFinite ||
        template.frameCount <= 0) {
      continue;
    }
    final frameCount = template.frameCount.round();
    if (frameCount > 0) {
      return frameCount;
    }
  }
  return null;
}

bool _testModeProductionMapNodeMatchesStation(
  ProductionMapNode node,
  String station,
) {
  return _testModeEffectiveNodeApparatusId(node) == station.trim();
}

AdminProgressBatch _testModeMarkProgressInputProcessed({
  required AdminProgressBatch batch,
  required String apparatus,
  required String orderId,
  List<Map<String, dynamic>> rezkaFrameIssues = const [],
}) {
  final payloadJson = <String, dynamic>{...batch.payloadJson};
  if (rezkaFrameIssues.isNotEmpty) {
    payloadJson['rezka_frame_issues'] = rezkaFrameIssues;
    payloadJson['rezka_issue'] = true;
  }
  return batch.copyWith(
    wipStatus: 'processed',
    currentApparatus: apparatus,
    currentLocation: apparatus,
    processedBySessionId: 'test-session-${orderId.trim()}',
    processedByApparatus: apparatus,
    payloadJson: payloadJson,
  );
}

List<Map<String, dynamic>> _testModeRezkaFrameIssues({
  required List<Map<String, dynamic>> rezkaFrames,
  required int frameCount,
  required String inputProgressBatchId,
}) {
  return [
    for (var index = 0; index < rezkaFrames.length; index += 1)
      if ((rezkaFrames[index]['issue_note']?.toString().trim() ?? '')
          .isNotEmpty)
        {
          'frame_index': index + 1,
          'frame_count': frameCount,
          'issue_note': rezkaFrames[index]['issue_note'].toString().trim(),
          'input_progress_batch_id': inputProgressBatchId.trim(),
        },
  ];
}

List<AdminProgressBatch> _testModeRezkaProgressBatches({
  required String apparatus,
  required String orderId,
  required String action,
  required String status,
  required double producedQty,
  required String uom,
  required int frameCount,
  required AdminProgressBatch? inputBatch,
  List<Map<String, dynamic>> rezkaFrames = const [],
  double? diameter,
  double? returnInkKg,
  double? laminationPrintLeftoverRolls,
  double? laminationFilmLeftoverRolls,
  double? rezkaBosmaWaste,
  double? rezkaLaminationWaste,
  double? rezkaEdgeWaste,
  double? totalWaste,
  double? finishedGoodsKg,
  double? finishedGoodsMeter,
  double? bobinaKg,
  List<Map<String, dynamic>> rezkaFrameIssues = const [],
}) {
  final baseBatchId = _testModeProductionProgressBatchId(
    apparatus: apparatus,
    orderId: orderId,
    action: action,
  );
  final parentBatchId = inputBatch?.batchId.trim() ?? '';
  final map = _testModeOrderById(orderId)?.map;
  double? labelLength;
  if (map != null) {
    for (final node in map.nodes) {
      final value = node.rezkaLabelLength;
      if (node.kind == 'apparatus' &&
          _testModeNodeHasOperation(node, 'cut') &&
          _testModeProductionMapNodeMatchesStation(node, apparatus) &&
          value != null &&
          value > 0) {
        labelLength = value;
        break;
      }
    }
  }
  AdminProgressBatch buildFrame(int index) {
    final frame = index < rezkaFrames.length
        ? rezkaFrames[index]
        : const <String, dynamic>{};
    double? frameMetric(String key) {
      final value = frame[key];
      return value is num ? value.toDouble() : null;
    }

    final explicitFrameValues = rezkaFrames.isNotEmpty;
    final frameProducedQty = explicitFrameValues
        ? (frameMetric('produced_qty') ??
            frameMetric('finished_goods_meter') ??
            producedQty)
        : producedQty;
    final frameFinishedGoodsKg = explicitFrameValues
        ? (frameMetric('finished_goods_kg') ??
            frameMetric('gross_qty') ??
            finishedGoodsKg)
        : finishedGoodsKg;
    final frameFinishedGoodsMeter = explicitFrameValues
        ? (frameMetric('finished_goods_meter') ??
            frameMetric('produced_qty') ??
            finishedGoodsMeter)
        : finishedGoodsMeter;
    final frameGrossQty = explicitFrameValues
        ? (frameMetric('gross_qty') ??
            frameMetric('finished_goods_kg') ??
            frameFinishedGoodsKg)
        : null;
    final frameHasWaste = [
      'rezka_bosma_waste',
      'rezka_lamination_waste',
      'rezka_edge_waste',
      'total_waste',
    ].any(frame.containsKey);
    final frameRezkaBosmaWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('rezka_bosma_waste')
            : (index == 0 ? rezkaBosmaWaste : null))
        : (index == 0 ? rezkaBosmaWaste : null);
    final frameRezkaLaminationWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('rezka_lamination_waste')
            : (index == 0 ? rezkaLaminationWaste : null))
        : (index == 0 ? rezkaLaminationWaste : null);
    final frameRezkaEdgeWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('rezka_edge_waste')
            : (index == 0 ? rezkaEdgeWaste : null))
        : (index == 0 ? rezkaEdgeWaste : null);
    final frameTotalWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('total_waste')
            : (index == 0 ? totalWaste : null))
        : (index == 0 ? totalWaste : null);
    final frameDiameter = explicitFrameValues
        ? (frameMetric('diameter') ?? diameter)
        : (index == 0 ? diameter : null);
    final frameBobinaKg = explicitFrameValues
        ? (frameMetric('bobina_kg') ?? frameMetric('babina_kg'))
        : (index == 0 ? bobinaKg : null);
    return _testModeProgressBatch(
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      status: status,
      producedQty: frameProducedQty,
      uom: uom,
      batchIdOverride: '$baseBatchId:frame:${index + 1}',
      parentBatchId: parentBatchId,
      diameter: frameDiameter,
      returnInkKg: index == 0 ? returnInkKg : null,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: frameRezkaBosmaWaste,
      rezkaLaminationWaste: frameRezkaLaminationWaste,
      rezkaEdgeWaste: frameRezkaEdgeWaste,
      totalWaste: frameTotalWaste,
      finishedGoodsKg: frameFinishedGoodsKg,
      finishedGoodsMeter: frameFinishedGoodsMeter,
      bobinaKg: frameBobinaKg,
      payloadJson: {
        'rezka_frame_index': index + 1,
        'rezka_frame_count': frameCount,
        'rezka_output_kind': 'frame',
        'rezka_metrics_owner': explicitFrameValues || index == 0,
        if (frameGrossQty != null) 'gross_qty': frameGrossQty,
        if (labelLength != null) 'rezka_label_length': labelLength,
        if (rezkaFrameIssues.isNotEmpty) 'rezka_frame_issues': rezkaFrameIssues,
      },
    );
  }

  return [
    for (var index = 0; index < frameCount; index += 1)
      if (index >= rezkaFrames.length ||
          (rezkaFrames[index]['issue_note']?.toString().trim() ?? '').isEmpty)
        buildFrame(index),
  ];
}

List<UsbRpsPrintRequest> _testModeProgressPrintJobs({
  required List<AdminProgressBatch> batches,
  required String printer,
  required String printMode,
  String customerName = '',
}) {
  return [
    for (final batch in batches)
      UsbRpsPrintRequest(
        epc: batch.qrPayload,
        itemCode: batch.labelItemCode,
        itemName: batch.labelItemName,
        warehouse: 'Ijrochi: ${batch.executorName}',
        printer: printer.trim().isEmpty ? 'godex' : printer.trim(),
        printMode: printMode.trim().isEmpty ? 'label' : printMode.trim(),
        grossQty: (batch.payloadJson['gross_qty'] as num?)?.toDouble() ??
            batch.finishedGoodsKg ??
            batch.producedQty,
        unit: 'kg',
        labelKind: 'progress',
        executorName: batch.executorName,
        progressQty: batch.finishedGoodsMeter ?? batch.producedQty,
        progressUnit: batch.uom.isEmpty ? 'm' : batch.uom,
        tareEnabled: (batch.bobinaKg ?? 0) > 0,
        tareKg: batch.bobinaKg ?? 0,
        customerName: customerName.trim().isEmpty
            ? (batch.payloadJson['customer_name']?.toString() ?? '')
            : customerName.trim(),
      ),
  ];
}
