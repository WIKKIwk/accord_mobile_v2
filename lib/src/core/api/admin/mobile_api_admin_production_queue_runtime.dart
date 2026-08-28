part of '../mobile_api.dart';

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

void setMobileApiTestModeProductionMapStageStates({
  required String orderId,
  required Map<String, String> states,
}) {
  final normalizedOrderId = orderId.trim();
  if (normalizedOrderId.isEmpty) return;
  _testModeProductionMapStageStates[normalizedOrderId] = {
    for (final entry in states.entries)
      if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value.trim(),
  };
}

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

bool _testModeProductionMapNodeMatchesStation(
  ProductionMapNode node,
  String station,
) {
  return _testModeEffectiveNodeApparatusId(node) == station.trim();
}
