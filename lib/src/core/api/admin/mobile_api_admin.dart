part of '../mobile_api.dart';

final List<ProductionMapSaved> _testModeProductionMaps = [];
final List<AdminApparatusGroup> _testModeApparatusGroups = [
  ...TestModeDemoData.apparatusGroups,
];
final List<AdminApparatus> _testModeApparatus = [];
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
final Map<String, AdminApparatusQueuePolicy> _testModeApparatusQueuePolicies =
    {};
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
final Map<String, String> _testModeActiveProgressInputByQueue = {};
final Map<String, int> _testModeOrderStartedAtUnix = {};
final List<AdminLaminatsiyaAstatkaReport> _testModeLaminatsiyaAstatkaReports =
    [];
final Map<String, AdminRawMaterialRule> _testModeRawMaterialRules = {};
final List<AdminRawMaterialAssignment> _testModeRawMaterialAssignments = [];
final Map<String, AdminQolipOrderNote> _testModeQolipOrderNotes = {};
final List<AdminWorker> _testModeWorkers = [];
final List<AdminWorkerGroup> _testModeWorkerGroups = [];
final Map<String, String> _testModeWorkerCodes = {};
final List<AdminSystemUser> _testModeSystemUsers = [];
final Map<String, String> _testModeSystemUserCodes = {};
bool _testModeForceSequenceSaveFailure = false;
bool _testModeForceCalculateTemplateSaveFailure = false;
bool _testModeForceProductionMapMenuLoadFailure = false;

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

const _defaultBosmaApparatusGroupName = 'Bosma aparat';

String _defaultBosmaApparatusName(int colorCount) {
  return '$colorCount ta rangli bosma aparat';
}

bool _adminApparatusGroupIsBosma(AdminApparatusGroup group) {
  if (productionMapIsPechatApparatus(group.name)) {
    return true;
  }
  return group.apparatus.any(
    productionMapIsPechatApparatus,
  );
}

List<AdminApparatusGroup> _normalizeDefaultAdminApparatusGroups(
  List<AdminApparatusGroup> groups,
) {
  final normalized = <AdminApparatusGroup>[];
  var hasBosma = false;
  var bosmaInsertIndex = -1;
  for (final group in groups) {
    if (_adminApparatusGroupIsBosma(group)) {
      hasBosma = true;
      if (bosmaInsertIndex < 0) {
        bosmaInsertIndex = normalized.length;
      }
      continue;
    }
    if (productionMapIsLaminatsiyaApparatus(group.name) ||
        group.apparatus.any(productionMapIsLaminatsiyaApparatus)) {
      normalized.add(
        AdminApparatusGroup(name: 'Laminatsiya', apparatus: group.apparatus),
      );
      continue;
    }
    normalized.add(group);
  }
  if (hasBosma) {
    final bosmaGroup = AdminApparatusGroup(
      name: _defaultBosmaApparatusGroupName,
      apparatus: [
        ...[7, 8, 9].map(_defaultBosmaApparatusName),
        'Flexo pechat',
      ],
    );
    normalized.insert(bosmaInsertIndex < 0 ? 0 : bosmaInsertIndex, bosmaGroup);
  }
  return normalized;
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

void resetMobileApiTestModeData() {
  _testModeProductionMaps.clear();
  _testModeAdminItemDetailOverrides.clear();
  _testModeDeletedAdminItemCodes.clear();
  _testModeApparatusGroups
    ..clear()
    ..addAll(TestModeDemoData.apparatusGroups);
  _testModeApparatus.clear();
  _testModeWarehouses.clear();
  _testModeWarehouseAssignments.clear();
  _testModeMaterialItemGroups.clear();
  _testModeDeletedWarehouseNames.clear();
  _testModeBackupSnapshots.clear();
  _testModeApparatusSequences.clear();
  _testModeApparatusQueueStates.clear();
  _testModeApparatusTransfers.clear();
  _testModeOrderControls.clear();
  _testModeApparatusQueuePolicies.clear();
  _testModeApparatusCapacityProfiles.clear();
  _testModeApparatusDowntimes.clear();
  _testModeApparatusScheduleReservations.clear();
  _testModeCompletedQueueOrders.clear();
  _testModeCompletionRequests.clear();
  _testModeCompletionRequestDecisions.clear();
  _testModeProgressBatchesByQr.clear();
  _testModeActiveProgressInputByQueue.clear();
  _testModeOrderStartedAtUnix.clear();
  _testModeLaminatsiyaAstatkaReports.clear();
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
}

int _testModeUnixSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

AdminApparatusCapacityProfile _normalizeTestModeCapacityProfile(
  AdminApparatusCapacityProfile profile,
) {
  final apparatusId = profile.apparatusId.trim().isEmpty
      ? 'apparatus:${profile.apparatus.trim().toLowerCase()}'
      : profile.apparatusId.trim();
  final apparatus =
      profile.apparatus.trim().isEmpty ? apparatusId : profile.apparatus.trim();
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
  required String apparatus,
}) {
  final normalizedId = apparatusId.trim().toLowerCase();
  final normalizedName = apparatus.trim().toLowerCase();
  for (final profile in _testModeApparatusCapacityProfiles.values) {
    if (profile.apparatusId.trim().toLowerCase() == normalizedId ||
        (normalizedName.isNotEmpty &&
            profile.apparatus.trim().toLowerCase() == normalizedName)) {
      return profile;
    }
  }
  AdminApparatus? catalogItem;
  for (final item in _testModeApparatusCatalog()) {
    if (item.name.trim().toLowerCase() == normalizedName) {
      catalogItem = item;
      break;
    }
  }
  final inferredCapabilities = catalogItem?.capabilities ?? const <String>[];
  final inferredProfiles = catalogItem?.capabilityProfiles ?? const [];
  return AdminApparatusCapacityProfile(
    apparatusId: apparatusId.trim().isEmpty
        ? 'apparatus:${apparatus.trim().toLowerCase()}'
        : apparatusId.trim(),
    apparatus: apparatus.trim(),
    capabilities: inferredCapabilities,
    capabilityLevels: inferredProfiles.isEmpty
        ? {
            for (final capability in inferredCapabilities) capability: 1,
          }
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
  final startTime =
      DateTime.fromMillisecondsSinceEpoch(start * 1000, isUtc: true);
  final endTime =
      DateTime.fromMillisecondsSinceEpoch((end - 1) * 1000, isUtc: true);
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
  required String apparatus,
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
          item.apparatusId.toLowerCase() == apparatusId.toLowerCase() &&
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
              item.apparatusId.toLowerCase() == apparatusId.toLowerCase() &&
              _testModeIntervalsOverlap(
                cursor,
                end,
                item.startsAtUnix,
                item.endsAtUnix,
              ),
        )
        .length;
    final activeQueueOrderIds = <String>{};
    for (final entry in _testModeApparatusQueueStates.entries) {
      if (!productionMapWarehouseTitlesMatch(entry.key, apparatus)) continue;
      for (final state in entry.value.entries) {
        if (apparatusQueueOrderStateFromRaw(state.value) ==
            ApparatusQueueOrderState.inProgress) {
          activeQueueOrderIds.add(state.key.trim());
        }
      }
    }
    final scheduledActiveOrderIds =
        _testModeApparatusScheduleReservations.values
            .where(
              (item) =>
                  item.status == 'active' &&
                  productionMapWarehouseTitlesMatch(item.apparatus, apparatus),
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

String? _testModeKnownApparatusFamily(String title) {
  final normalized = productionMapWarehouseBaseTitle(title).toLowerCase();
  if (productionMapIsPechatApparatus(normalized)) return 'pechat';
  for (final entry in const {
    'laminatsiya': 'laminatsiya',
    'rezka': 'rezka',
    'paket': 'paket',
    'kley': 'kley',
  }.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return null;
}

bool _testModeCandidateAllowedForOrder(
  ProductionMapDefinition map,
  String source,
  String candidate,
) {
  source = source.trim();
  if (source.isEmpty) return false;
  final apparatusNodes = map.nodes
      .where((node) => node.kind == 'apparatus')
      .map((node) => node.title.trim())
      .where((title) => title.isNotEmpty)
      .toList(growable: false);
  if (apparatusNodes.isEmpty) return true;
  if (!apparatusNodes.any(
    (title) => productionMapWarehouseTitlesMatch(title, source),
  )) {
    return false;
  }
  final sourceFamily = _testModeKnownApparatusFamily(source);
  final candidateFamily = _testModeKnownApparatusFamily(candidate);
  if (sourceFamily != null &&
      candidateFamily != null &&
      sourceFamily != candidateFamily) {
    return false;
  }
  final sourceIsFlexo = productionMapIsFlexoApparatus(source);
  final candidateIsFlexo = productionMapIsFlexoApparatus(candidate);
  if (sourceIsFlexo != candidateIsFlexo) return false;
  return productionMapCanMoveOrderToApparatus(
    nodes: map.nodes,
    fromApparatus: source,
    toApparatus: candidate,
    rollCount: map.rollCount,
    widthMm: map.widthMm,
    isFlexoOrder: productionMapIsFlexoOrder(map),
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
  final normalizedId = apparatusId.trim().isEmpty
      ? 'apparatus:${apparatus.trim().toLowerCase()}'
      : apparatusId.trim();
  final normalizedApparatus =
      apparatus.trim().isEmpty ? normalizedId : apparatus.trim();
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
  void addCandidate(String id, String name) {
    final normalizedCandidateId = id.trim().isEmpty
        ? 'apparatus:${name.trim().toLowerCase()}'
        : id.trim();
    final normalizedCandidateName =
        name.trim().isEmpty ? normalizedCandidateId : name.trim();
    final key = normalizedCandidateId.toLowerCase();
    if (key.isEmpty || !seenCandidateKeys.add(key)) return;
    candidates.add(
      AdminApparatusScheduleCandidate(
        apparatusId: normalizedCandidateId,
        apparatus: normalizedCandidateName,
      ),
    );
  }

  addCandidate(normalizedId, normalizedApparatus);
  for (final candidate in candidateApparatuses) {
    addCandidate(candidate.apparatusId, candidate.apparatus);
  }

  var routeCandidateCount = 0;
  var supportedCandidateCount = 0;
  var capabilityNotSupported = false;
  var capabilityLevelInsufficient = false;
  _TestModeScheduledCandidate? best;
  for (var index = 0; index < candidates.length; index++) {
    final candidate = candidates[index];
    if (!_testModeCandidateAllowedForOrder(
      map,
      normalizedApparatus,
      candidate.apparatus,
    )) {
      continue;
    }
    routeCandidateCount++;
    final profile = _testModeProfileForApparatus(
      apparatusId: candidate.apparatusId,
      apparatus: candidate.apparatus,
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
      apparatus: candidate.apparatus,
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
  required String apparatus,
  required String status,
}) {
  final normalizedOrderId = orderId.trim();
  final normalizedApparatus = apparatus.trim();
  for (final entry in _testModeApparatusScheduleReservations.entries.toList()) {
    final reservation = entry.value;
    if (reservation.orderId.trim() != normalizedOrderId ||
        !productionMapWarehouseTitlesMatch(
          reservation.apparatus,
          normalizedApparatus,
        )) {
      continue;
    }
    final current = reservation.status.trim().toLowerCase();
    final next = status.trim().toLowerCase();
    final allowed = current == next ||
        (next == 'active' && (current == 'planned' || current == 'paused')) ||
        (next == 'paused' && current == 'active') ||
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
  required String fromApparatus,
  required String toApparatus,
}) {
  final targetName = toApparatus.trim();
  if (targetName.isEmpty) return;
  final targetId = _testModeApparatusCatalog()
      .where(
        (item) => item.name.trim().toLowerCase() == targetName.toLowerCase(),
      )
      .map((item) => item.id.trim())
      .firstWhere(
        (id) => id.isNotEmpty,
        orElse: () => 'apparatus:${targetName.toLowerCase()}',
      );
  for (final entry in _testModeApparatusScheduleReservations.entries.toList()) {
    final reservation = entry.value;
    if (reservation.orderId.trim() != orderId.trim() ||
        reservation.status != 'paused' ||
        !productionMapWarehouseTitlesMatch(
          reservation.apparatus,
          fromApparatus,
        )) {
      continue;
    }
    _testModeApparatusScheduleReservations[entry.key] =
        AdminApparatusScheduleReservation(
      reservationId: reservation.reservationId,
      idempotencyKey: reservation.idempotencyKey,
      orderId: reservation.orderId,
      apparatusId: targetId,
      apparatus: targetName,
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
  required String apparatus,
  required String orderId,
}) {
  final profile = _testModeProfileForApparatus(
    apparatusId: apparatusId,
    apparatus: apparatus,
  );
  final now = _testModeUnixSeconds();
  bool isSameApparatus(String candidateId, String candidateName) {
    return candidateId.trim().toLowerCase() ==
            profile.apparatusId.trim().toLowerCase() ||
        productionMapWarehouseTitlesMatch(candidateName, apparatus);
  }

  if (_testModeApparatusDowntimes.values.any(
    (downtime) =>
        downtime.active &&
        isSameApparatus(downtime.apparatusId, downtime.apparatus) &&
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
    if (!productionMapWarehouseTitlesMatch(entry.key, apparatus)) continue;
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
        !isSameApparatus(reservation.apparatusId, reservation.apparatus) ||
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
  final knownKeys = {
    ..._testModeApparatusSequences.keys,
    ..._testModeApparatusQueueStates.keys,
  };
  final storageKey = resolveApparatusStorageKey(fromApparatus, knownKeys);
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
    final seenTitles = <String>{};
    for (final stage in productionMapLinearWorkStages(map)) {
      final title = stage.stationTitle.trim();
      if (title.isEmpty ||
          _testModeFlexoOrderBlockedForColorPechat(map, title) ||
          !seenTitles.add(title.toLowerCase())) {
        continue;
      }
      visible.putIfAbsent(title, () => <String>[]).add(orderId);
    }
  }
  return {
    for (final entry in visible.entries)
      entry.key: List<String>.unmodifiable(entry.value),
  };
}

Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
    _testModeQueueActionControls() {
  final visible = _testModeVisibleOrderIdsByApparatus();
  final knownKeys = <String>{
    ..._testModeApparatusSequences.keys,
    ..._testModeApparatusQueueStates.keys,
    ..._testModeApparatusQueuePolicies.keys,
    ...visible.keys,
  };
  final result = <String, Map<String, AdminApparatusQueueOrderActionControl>>{};

  for (final apparatus in knownKeys) {
    final storageKey = resolveApparatusStorageKey(apparatus, knownKeys);
    final sequence = effectiveQueueSequence(
      sequence: _testModeApparatusSequences[storageKey] ??
          _testModeApparatusSequences[apparatus] ??
          const [],
      visibleOrderIds: visible[storageKey] ?? visible[apparatus] ?? const [],
    );
    final states = _testModeApparatusQueueStates[storageKey] ??
        _testModeApparatusQueueStates[apparatus] ??
        const <String, String>{};
    final policy = _effectiveTestModeQueuePolicy(apparatus, storageKey).policy;
    String? activeOrderId;
    for (final orderId in sequence) {
      if (apparatusQueueOrderStateFromRaw(states[orderId]) ==
          ApparatusQueueOrderState.inProgress) {
        activeOrderId = orderId;
        break;
      }
    }
    final actionableOrderId = firstActionableQueueOrderId(
      sequence: sequence,
      states: states,
      visibleOrderIds: visible[storageKey] ?? visible[apparatus] ?? const [],
    );
    final apparatusControls = <String, AdminApparatusQueueOrderActionControl>{};

    for (final orderId in sequence) {
      final order = _testModeOrderById(orderId)?.map;
      final state = apparatusQueueOrderStateFromRaw(states[orderId]);
      final orderControl =
          _testModeOrderControls[orderId] ?? AdminOrderControlState.active;
      final previousStage = order == null
          ? null
          : productionMapPreviousWorkStageStation(
              map: order,
              station: apparatus,
            );
      final previousStageReady = order != null &&
          productionMapOrderReadyForStation(
            map: order,
            orderId: orderId,
            station: apparatus,
            queueStatesByApparatus: _testModeApparatusQueueStates,
          );
      final queueActionable = state == ApparatusQueueOrderState.inProgress ||
          state == ApparatusQueueOrderState.paused ||
          actionableOrderId == orderId ||
          (state == ApparatusQueueOrderState.pending &&
              previousStage != null &&
              previousStageReady &&
              (activeOrderId == null || activeOrderId == orderId));
      final allowedActions = <String>[];
      var completeRequiresFullReport = false;

      if (queueActionable && orderControl != AdminOrderControlState.frozen) {
        switch (state) {
          case ApparatusQueueOrderState.pending:
            if (orderControl == AdminOrderControlState.active &&
                (policy == ApparatusQueuePolicy.freePick ||
                    activeOrderId == null ||
                    activeOrderId == orderId ||
                    actionableOrderId == orderId)) {
              allowedActions.add('start');
            }
            break;
          case ApparatusQueueOrderState.inProgress:
            if (orderControl == AdminOrderControlState.active ||
                orderControl == AdminOrderControlState.freezeRequested) {
              allowedActions.add('pause');
            }
            if (orderControl == AdminOrderControlState.active) {
              final hasUnprocessedPreviousWip = previousStage != null &&
                  (!previousStageReady ||
                      _testModeProgressBatchesByQr.values.any(
                        (batch) =>
                            batch.orderId.trim() == orderId.trim() &&
                            productionMapWarehouseTitlesMatch(
                              batch.apparatus,
                              previousStage,
                            ) &&
                            (batch.nextApparatus.trim().isEmpty ||
                                productionMapNextStageTitleMatchesApparatus(
                                  batch.nextApparatus,
                                  apparatus,
                                )) &&
                            batch.wipStatus.trim().toLowerCase() == 'waiting',
                      ));
              if (productionMapIsRezkaApparatus(storageKey) &&
                  hasUnprocessedPreviousWip) {
                allowedActions.add('roll_complete');
              } else {
                allowedActions.add('complete');
              }
              completeRequiresFullReport =
                  !productionMapIsLaminatsiyaApparatus(storageKey) ||
                      !hasUnprocessedPreviousWip;
            }
            break;
          case ApparatusQueueOrderState.paused:
            if (orderControl == AdminOrderControlState.active) {
              allowedActions.add('resume');
            }
            break;
          case ApparatusQueueOrderState.completed:
            break;
        }
      }

      apparatusControls[orderId.trim()] = AdminApparatusQueueOrderActionControl(
        state: state.name == 'inProgress' ? 'in_progress' : state.name,
        allowedActions: allowedActions.toSet(),
        previousStage: previousStage ?? '',
        previousStageReady: previousStageReady,
        completeRequiresFullReport: completeRequiresFullReport,
      );
    }
    if (apparatusControls.isNotEmpty) {
      result[storageKey] = Map.unmodifiable(apparatusControls);
    }
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

bool _testModeFlexoOrderBlockedForColorPechat(
  ProductionMapDefinition map,
  String apparatus,
) {
  return productionMapIsFlexoOrder(map) &&
      productionMapPechatColorCount(apparatus) != null;
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

class AdminApparatusQueueOrderActionControl {
  const AdminApparatusQueueOrderActionControl({
    this.state = '',
    this.allowedActions = const {},
    this.previousStage = '',
    this.previousStageReady = false,
    this.completeRequiresFullReport = false,
  });

  final String state;
  final Set<String> allowedActions;
  final String previousStage;
  final bool previousStageReady;
  final bool completeRequiresFullReport;

  bool allows(String action) => allowedActions.contains(action.trim());

  factory AdminApparatusQueueOrderActionControl.fromJson(
    Map<String, dynamic> json,
  ) {
    final actions = <String>{};
    final rawActions = json['allowed_actions'];
    if (rawActions is List) {
      for (final rawAction in rawActions) {
        final action = rawAction?.toString().trim();
        if (action != null && action.isNotEmpty) {
          actions.add(action);
        }
      }
    }
    return AdminApparatusQueueOrderActionControl(
      state: json['state']?.toString().trim() ?? '',
      allowedActions: Set<String>.unmodifiable(actions),
      previousStage: json['previous_stage']?.toString().trim() ?? '',
      previousStageReady: json['previous_stage_ready'] == true,
      completeRequiresFullReport: json['complete_requires_full_report'] == true,
    );
  }
}

Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
    _parseAdminQueueActionControls(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  final result = <String, Map<String, AdminApparatusQueueOrderActionControl>>{};
  for (final apparatusEntry in raw.entries) {
    final apparatus = apparatusEntry.key.toString();
    final rawOrders = apparatusEntry.value;
    if (rawOrders is! Map) {
      continue;
    }
    final orders = <String, AdminApparatusQueueOrderActionControl>{};
    for (final orderEntry in rawOrders.entries) {
      final orderId = orderEntry.key.toString();
      final rawControl = orderEntry.value;
      if (rawControl is Map) {
        orders[orderId] = AdminApparatusQueueOrderActionControl.fromJson(
          rawControl.cast<String, dynamic>(),
        );
      }
    }
    if (orders.isNotEmpty) {
      result[apparatus] =
          Map<String, AdminApparatusQueueOrderActionControl>.unmodifiable(
        orders,
      );
    }
  }
  return Map<String,
      Map<String, AdminApparatusQueueOrderActionControl>>.unmodifiable(
    result,
  );
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
  final completed = _testModeProductionMaps
      .where((saved) => saved.map.id.trim() == orderId)
      .map((saved) => saved.map)
      .any((map) {
    final stages = productionMapLinearWorkStages(map);
    return stages.isNotEmpty &&
        stages.every((stage) {
          final knownKeys = {
            ..._testModeApparatusSequences.keys,
            ..._testModeApparatusQueueStates.keys,
          };
          final storageKey = resolveApparatusStorageKey(
            stage.stationTitle,
            knownKeys,
          );
          return _testModeApparatusQueueStates[storageKey]?[orderId] ==
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
      final next = hasActiveWork
          ? AdminOrderControlState.freezeRequested
          : AdminOrderControlState.frozen;
      _testModeOrderControls[orderId] = next;
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
          blockers.add(
            'Buyurtma $apparatus ketma-ketligida 1-o‘rinda turibdi',
          );
        }
      }
      if (started) {
        blockers.add('Buyurtmada ish jarayoni allaqachon boshlangan');
      }
      final materialCount = _testModeRawMaterialAssignments
          .where((assignment) => assignment.orderId.trim() == orderId)
          .length;
      if (materialCount > 0) {
        blockers.add(
          'Buyurtmaga $materialCount ta homashyo biriktirilgan',
        );
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
        entry.key.toString().trim():
            AdminProductionOrderStatusDetail.fromJson(entry.value),
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
  });

  final String apparatus;
  final String orderId;
  final int completedAtUnix;
  final String status;

  factory AdminCompletedQueueOrder.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().trim() ?? '';
    return AdminCompletedQueueOrder(
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      status: status.isEmpty ? 'completed' : status,
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
      apparatus: json['apparatus']?.toString() ?? '',
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
      apparatus: json['apparatus']?.toString() ?? '',
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
      apparatus: json['apparatus']?.toString() ?? '',
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
      fromApparatus: json['from_apparatus']?.toString() ?? '',
      toApparatus: json['to_apparatus']?.toString() ?? '',
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
      targetApparatus: json['target_apparatus']?.toString() ?? '',
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
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final int createdAtUnix;

  factory AdminLaminatsiyaAstatkaReport.fromJson(Map<String, dynamic> json) {
    return AdminLaminatsiyaAstatkaReport(
      reportId: json['report_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      fromAtUnix: (json['from_at_unix'] as num?)?.toInt() ?? 0,
      toAtUnix: (json['to_at_unix'] as num?)?.toInt() ?? 0,
      laminationPrintLeftoverRolls:
          (json['lamination_print_leftover_rolls'] as num?)?.toDouble() ?? 0,
      laminationFilmLeftoverRolls:
          (json['lamination_film_leftover_rolls'] as num?)?.toDouble() ?? 0,
      totalWaste: (json['total_waste'] as num?)?.toDouble() ?? 0,
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
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
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
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
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
    return AdminProgressBatch(
      batchId: json['batch_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      apparatus: json['apparatus']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      producedQty: (json['produced_qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString() ?? '',
      labelItemCode: json['label_item_code']?.toString() ?? '',
      labelItemName: json['label_item_name']?.toString() ?? '',
      executorName: json['executor_name']?.toString() ?? '',
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
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      wipStatus: json['wip_status']?.toString() ?? '',
      statusDetail: AdminProgressBatchStatusDetail.fromJsonOrBatchJson(json),
      currentApparatus: json['current_apparatus']?.toString() ?? '',
      currentApparatusKey: json['current_apparatus_key']?.toString() ?? '',
      currentLocation: json['current_location']?.toString() ?? '',
      nextApparatus: json['next_apparatus']?.toString() ?? '',
      parentBatchId: json['parent_batch_id']?.toString() ?? '',
      usedBySessionId: json['used_by_session_id']?.toString() ?? '',
      usedByApparatus: json['used_by_apparatus']?.toString() ?? '',
      processedBySessionId: json['processed_by_session_id']?.toString() ?? '',
      processedByApparatus: json['processed_by_apparatus']?.toString() ?? '',
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      payloadJson: _jsonObject(json['payload_json']),
    );
  }

  AdminProgressBatch copyWith({
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
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
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
      'resumed' => 'in_progress',
      'completed' => 'completed',
      _ => batchStatus,
    };
    final isFinalOutput = (action == 'roll_complete' || action == 'complete') &&
        batchStatus == 'completed' &&
        nextApparatus.isEmpty;
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
      completedQueueCount:
          (json['completed_queue_count'] as num?)?.toInt() ?? 0,
      completedWithIssueCount:
          (json['completed_with_issue_count'] as num?)?.toInt() ?? 0,
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
      apparatus: json['apparatus']?.toString() ?? '',
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
      queueStates: _stringMapOfStringMaps(json['queue_states']),
      logs: [
        for (final item in (json['logs'] as List? ?? const []))
          AdminProductionOrderLogEntry.fromJson(
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

Map<String, Map<String, String>> _stringMapOfStringMaps(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  return {
    for (final entry in raw.entries)
      entry.key.toString(): {
        if (entry.value is Map)
          for (final child in (entry.value as Map).entries)
            child.key.toString(): child.value.toString(),
      },
  };
}

Map<String, dynamic> _jsonObject(Object? raw) {
  if (raw is! Map) {
    return const {};
  }
  return {
    for (final entry in raw.entries) entry.key.toString(): entry.value,
  };
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
    required this.assignedGroups,
    required this.activeSessions,
    required this.recentBatches,
    required this.recentLogs,
  });

  final AdminWorkerDetail worker;
  final List<AdminWorkerGroup> assignedGroups;
  final List<AdminWorkerRunSession> activeSessions;
  final List<AdminProgressBatch> recentBatches;
  final List<AdminProductionOrderLogEntry> recentLogs;

  factory AdminWorkerProfileDetail.fromJson(Map<String, dynamic> json) {
    return AdminWorkerProfileDetail(
      worker: AdminWorkerDetail.fromJson(
        (json['worker'] as Map? ?? const {}).cast<String, dynamic>(),
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
      apparatus: json['apparatus']?.toString() ?? '',
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

  factory AdminServerMonitorBackupSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
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
  const AdminServerMonitorLiveEvent({
    this.report,
    this.latencyMs,
  });

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

  factory AdminProductionMapRequiredQolip.fromJson(
    Map<String, dynamic> json,
  ) {
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
    this.progressBatch,
    this.progressBatches = const [],
    this.completionRequest,
    this.printJob,
    this.printJobs = const [],
  });

  final Map<String, String> states;
  final AdminProductionOrderStatusDetail orderStatus;
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
    this.locked = false,
    this.reason = '',
  });

  final String apparatus;
  final ApparatusQueuePolicy policy;
  final bool locked;
  final String reason;

  factory AdminApparatusQueuePolicy.fromJson(Map<String, dynamic> json) {
    return AdminApparatusQueuePolicy(
      apparatus: json['apparatus']?.toString() ?? '',
      policy: ApparatusQueuePolicy.fromRaw(json['policy']),
      locked: json['locked'] == true,
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'apparatus': apparatus,
        'policy': policy.apiValue,
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

  factory AdminRawMaterialRequirementGroup.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawGroups = json['item_groups'];
    return AdminRawMaterialRequirementGroup(
      name: json['name']?.toString().trim() ?? '',
      itemGroups: [
        if (rawGroups is List)
          for (final item in rawGroups)
            if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ],
      minRequiredCount:
          int.tryParse(json['min_required_count']?.toString() ?? '') ?? 1,
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
    required this.apparatus,
    required this.requiresMaterial,
    required this.itemGroups,
    this.startPolicy = AdminRawMaterialStartPolicy.stateAll,
    this.requirementGroups = const [],
  });

  final String apparatus;
  final bool requiresMaterial;
  final List<String> itemGroups;
  final AdminRawMaterialStartPolicy startPolicy;
  final List<AdminRawMaterialRequirementGroup> requirementGroups;

  factory AdminRawMaterialRule.fromJson(Map<String, dynamic> json) {
    final rawGroups = json['item_groups'];
    final rawRequirementGroups = json['requirement_groups'];
    return AdminRawMaterialRule(
      apparatus: json['apparatus']?.toString() ?? '',
      requiresMaterial: json['requires_material'] == true,
      startPolicy: AdminRawMaterialStartPolicy.fromJson(json['start_policy']),
      itemGroups: [
        if (rawGroups is List)
          for (final item in rawGroups)
            if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ],
      requirementGroups: [
        if (rawRequirementGroups is List)
          for (final item in rawRequirementGroups)
            if (item is Map<String, dynamic>)
              AdminRawMaterialRequirementGroup.fromJson(item),
      ],
    );
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
      assignedBarcodes: _normalizedRawMaterialBarcodeList(
        rawAssignedBarcodes,
      ),
      stagedBarcodes: _normalizedRawMaterialBarcodeList(rawStagedBarcodes),
      assignments: [
        if (rawAssignments is List)
          for (final item in rawAssignments)
            if (item is Map)
              AdminRawMaterialAssignment.fromJson(
                item.cast<String, dynamic>(),
              ),
      ],
      startAssignments: [
        if (rawStartAssignments is List)
          for (final item in rawStartAssignments)
            if (item is Map)
              AdminRawMaterialAssignment.fromJson(
                item.cast<String, dynamic>(),
              ),
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
        (linked) => productionMapWarehouseTitlesMatch(linked.name, apparatus),
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
      apparatus: json['apparatus']?.toString() ?? '',
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
      apparatusOptions: (json['apparatus_options'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
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
      apparatusOptions: (json['apparatus_options'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
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
      apparatus: json['apparatus']?.toString() ?? '',
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
      queueStates: _stringMapOfStringMaps(json['queue_states']),
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

  factory AdminProductionMapLiveSnapshot.fromJson(Map<String, dynamic> json) {
    final mapsRaw = json['maps'];
    final completedRaw = json['completed_orders'];
    final completionRequestsRaw = json['completion_requests'];
    final completionRequestDecisionsRaw = json['completion_request_decisions'];
    return AdminProductionMapLiveSnapshot(
      maps: [
        if (mapsRaw is List)
          for (final item in mapsRaw)
            ProductionMapSaved.fromJson(item as Map<String, dynamic>),
      ],
      sequences: MobileApi.instance.parseApparatusSequenceMap(
        json['sequences'],
      ),
      visibleOrderIds: _parseRequiredProductionMapVisibleOrderIds(json),
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
            AdminCompletedQueueOrder.fromJson(item as Map<String, dynamic>),
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
      orderControls: _parseAdminOrderControls(json['order_controls']),
      orderCustomers: _stringMapOfStrings(json['order_customers']),
      orderStatuses: _parseAdminOrderStatuses(json['order_statuses']),
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
      'progress_batch_not_found' => 'Progress QR topilmadi',
      'progress_batch_not_accepted' =>
        'Bu QR oldingi bosqich mahsulotiga mos emas',
      'progress_batch_not_resumable' =>
        'Bu progress QR davom ettirishga yaramaydi',
      'scale_driver_not_configured' => 'Printer ulanmagan',
      'unauthorized' => 'Sessiya tugagan. Qayta login qiling',
      'forbidden' => 'Bu amal sizning rolingiz uchun ruxsat etilmagan',
      'method not allowed' => 'Bu amal bu usulda qo‘llanmaydi',
      'invalid json' => 'Yuborilgan ma’lumot noto‘g‘ri',
      'production maps fetch failed' => 'Production maplar yuklanmadi',
      'map_id_required' => 'Production map ID sini kiriting',
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
      'store_failed' ||
      'production_map_store_failed' =>
        'Production map ma’lumotlarini saqlashda server xatosi',
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
      apparatusId: json['apparatus_id']?.toString().trim() ?? '',
      apparatus: json['apparatus']?.toString().trim() ?? '',
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
        'capacity_slots': capacitySlots,
        'setup_minutes': setupMinutes,
        'cleanup_minutes': cleanupMinutes,
        'efficiency_percent': efficiencyPercent,
        'finite_capacity': finiteCapacity,
        'working_windows': [
          for (final window in workingWindows) window.toJson(),
        ],
        'capabilities': capabilities,
        'capability_levels': capabilityLevels,
        'notes': notes,
        'updated_at_unix': updatedAtUnix,
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
      apparatusId: json['apparatus_id']?.toString() ?? '',
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

  Map<String, dynamic> toJson() => {
        'code': code.trim(),
        'min_level': minLevel,
      };
}

class AdminApparatusScheduleCandidate {
  const AdminApparatusScheduleCandidate({
    required this.apparatusId,
    required this.apparatus,
  });

  final String apparatusId;
  final String apparatus;

  factory AdminApparatusScheduleCandidate.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdminApparatusScheduleCandidate(
      apparatusId: json['apparatus_id']?.toString().trim() ?? '',
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
      apparatusId: json['apparatus_id']?.toString() ?? '',
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

  Future<List<AdminApparatusGroup>> adminApparatusGroups() async {
    if (await TestModeController.instance.isEnabled()) {
      return _normalizeDefaultAdminApparatusGroups(
        List<AdminApparatusGroup>.from(_testModeApparatusGroups),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/apparatus-groups'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin apparatus groups failed');
    }
    final json = await decodeJsonListPayload(response.body);
    return _normalizeDefaultAdminApparatusGroups(
      json
          .map(
            (item) =>
                AdminApparatusGroup.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  Future<AdminApparatusGroup> adminSaveApparatusGroup(
    AdminApparatusGroup group,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = AdminApparatusGroup.fromJson(group.toJson());
      final key = normalized.name.toLowerCase();
      final index = _testModeApparatusGroups.indexWhere(
        (item) => item.name.toLowerCase() == key,
      );
      if (index >= 0) {
        _testModeApparatusGroups[index] = normalized;
      } else {
        _testModeApparatusGroups.add(normalized);
      }
      return normalized;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/apparatus-groups'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(group.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Admin apparatus group save failed');
    }
    return AdminApparatusGroup.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
    if (await TestModeController.instance.isEnabled()) {
      final duplicate = _testModeProductionMaps.any(
        (item) =>
            item.map.orderNumber.trim().isNotEmpty &&
            item.map.orderNumber.trim() == map.orderNumber.trim() &&
            !_isSameProductionMapOrder(item.map, map),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'duplicate_order_number',
          message: 'Bu raqam boshqa zakazga berilgan',
        );
      }
      final saved = ProductionMapSaved(
        map: map,
        program: ProductionMapProgram(
          mapId: map.id,
          productCode: map.productCode,
          operations: [
            for (var i = 0; i < map.nodes.length; i++)
              ProductionMapOperation(
                order: i + 1,
                nodeId: map.nodes[i].id,
                opCode: map.nodes[i].kind,
                args: {'title': map.nodes[i].title},
              ),
          ],
        ),
      );
      _testModeProductionMaps.removeWhere((item) => item.map.id == map.id);
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
      try {
        final templateMap = _templateMapCopyForSave(map, template);
        final savedMap = await adminSaveProductionMap(map);
        final savedTemplateMap = templateMap == null
            ? null
            : await adminSaveProductionMap(templateMap);
        final opensQuickTemplateAsOrder =
            template.sourceMapId.trim().isNotEmpty &&
                template.sourceMapId.trim() != savedMap.map.id.trim() &&
                _isSheetOrderMap(savedMap.map);
        final savedTemplate = opensQuickTemplateAsOrder
            ? null
            : _testModeUpsertCalculateOrderTemplate(
                template.copyWith(
                  sourceMapId: savedTemplateMap?.map.id ??
                      _templateSourceMapIdForSave(
                        savedMap.map,
                        template,
                      ),
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
          _testModeProductionMaps.removeWhere(
            (item) => item.map.id.trim() == map.id.trim(),
          );
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
    if (await TestModeController.instance.isEnabled()) {
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
          fromApparatus: fromApparatus,
        );
        if (!productionMapCanMoveOrderToApparatus(
          nodes: current.map.nodes,
          fromApparatus: fromApparatus,
          toApparatus: toApparatus,
          rollCount: current.map.rollCount,
          widthMm: current.map.widthMm,
          isFlexoOrder: productionMapIsFlexoOrder(current.map),
        )) {
          throw const MobileApiException(
            code: 'move_not_allowed',
            message: 'Zakaz bu aparatga tushmaydi',
          );
        }
        final nodes = productionMapReassignAlternativeApparatusAssignment(
              nodes: current.map.nodes,
              fromApparatus: fromApparatus,
              toApparatus: toApparatus,
            ) ??
            productionMapReassignApparatusNodes(
              nodes: current.map.nodes,
              fromApparatus: fromApparatus,
              toApparatus: toApparatus,
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
          'from_apparatus': fromApparatus,
          'to_apparatus': toApparatus,
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
    final normalizedFrom = fromApparatus.trim();
    final normalizedTo = toApparatus.trim();
    final normalizedReason = reason.trim();
    final normalizedKey = idempotencyKey.trim();
    if (normalizedOrderId.isEmpty ||
        normalizedFrom.isEmpty ||
        normalizedTo.isEmpty) {
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
      final existing = _testModeApparatusTransfers[normalizedKey];
      if (existing != null) {
        if (existing.orderId != normalizedOrderId ||
            !productionMapWarehouseTitlesMatch(
              existing.fromApparatus,
              normalizedFrom,
            ) ||
            !productionMapWarehouseTitlesMatch(
              existing.toApparatus,
              normalizedTo,
            )) {
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
      final knownKeys = {
        ..._testModeApparatusSequences.keys,
        ..._testModeApparatusQueueStates.keys,
      };
      final sourceKey = resolveApparatusStorageKey(
        normalizedFrom,
        knownKeys,
      );
      final targetKey = resolveApparatusStorageKey(
        normalizedTo,
        knownKeys,
      );
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
        fromApparatus: normalizedFrom,
        toApparatus: normalizedTo,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
        isFlexoOrder: productionMapIsFlexoOrder(current.map),
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: normalizedFrom,
            toApparatus: normalizedTo,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: normalizedFrom,
            toApparatus: normalizedTo,
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
      final targetSequence = List<String>.from(
        _testModeApparatusSequences[targetKey] ?? const [],
      )
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
        fromApparatus: sourceKey,
        toApparatus: targetKey,
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
    if (await TestModeController.instance.isEnabled()) {
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
        fromApparatus: fromApparatus,
      );
      if (!productionMapCanMoveOrderToApparatus(
        nodes: current.map.nodes,
        fromApparatus: fromApparatus,
        toApparatus: toApparatus,
        rollCount: current.map.rollCount,
        widthMm: current.map.widthMm,
        isFlexoOrder: productionMapIsFlexoOrder(current.map),
      )) {
        throw const MobileApiException(
          code: 'move_not_allowed',
          message: 'Zakaz bu aparatga tushmaydi',
        );
      }
      final nodes = productionMapReassignAlternativeApparatusAssignment(
            nodes: current.map.nodes,
            fromApparatus: fromApparatus,
            toApparatus: toApparatus,
          ) ??
          productionMapReassignApparatusNodes(
            nodes: current.map.nodes,
            fromApparatus: fromApparatus,
            toApparatus: toApparatus,
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
          'from_apparatus': fromApparatus,
          'to_apparatus': toApparatus,
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
      return AdminApparatusQueueSnapshot(
        sequences: {
          for (final entry in _testModeApparatusSequences.entries)
            entry.key: List<String>.unmodifiable(entry.value),
        },
        visibleOrderIds: _testModeVisibleOrderIdsByApparatus(),
        queueStates: {
          for (final entry in _testModeApparatusQueueStates.entries)
            entry.key: Map<String, String>.unmodifiable(entry.value),
        },
        queuePolicies: Map<String, AdminApparatusQueuePolicy>.unmodifiable(
          _testModeApparatusQueuePolicies,
        ),
        queueActionControls: _testModeQueueActionControls(),
        orderControls: Map<String, AdminOrderControlState>.unmodifiable(
          _testModeOrderControls,
        ),
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
      );
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
    return AdminApparatusQueueSnapshot(
      sequences: parseApparatusSequenceMap(payload['sequences']),
      visibleOrderIds: _parseRequiredProductionMapVisibleOrderIds(payload),
      queueStates: parseApparatusQueueStateMap(payload['queue_states']),
      queuePolicies: parseApparatusQueuePolicyMap(payload['queue_policies']),
      queueActionControls: _parseAdminQueueActionControls(
        payload['queue_action_controls'],
      ),
      orderControls: _parseAdminOrderControls(payload['order_controls']),
      orderCustomers: _stringMapOfStrings(payload['order_customers']),
      orderStatuses: _parseAdminOrderStatuses(payload['order_statuses']),
      qolipOrderNotes: _parseAdminQolipOrderNotes(
        payload['qolip_order_notes'],
      ),
    );
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/order-control',
        ),
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
    final normalizedApparatus = apparatus.trim();
    final normalizedNextApparatus = nextApparatus.trim();
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
                !productionMapWarehouseTitlesMatch(
                  batch.currentApparatus,
                  normalizedApparatus,
                ) &&
                !productionMapWarehouseTitlesMatch(
                  batch.apparatus,
                  normalizedApparatus,
                )) {
              return false;
            }
            if (normalizedNextApparatus.isNotEmpty &&
                batch.nextApparatus.trim().isNotEmpty &&
                !productionMapNextStageTitleMatchesApparatus(
                  batch.nextApparatus,
                  normalizedNextApparatus,
                )) {
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
        body: jsonEncode({
          'event_id': eventId,
          'decision': decision,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'completion_request_decision');
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
    required String apparatus,
    required ApparatusQueuePolicy policy,
  }) async {
    final normalized = apparatus.trim();
    if (await TestModeController.instance.isEnabled()) {
      final locked = productionMapIsPechatApparatus(normalized);
      if (locked && policy != ApparatusQueuePolicy.strictSequence) {
        throw const MobileApiException(
          code: 'queue_policy_locked',
          message: 'Bosma aparati doim ketma-ketlik bo‘yicha ishlaydi',
        );
      }
      final record = AdminApparatusQueuePolicy(
        apparatus: normalized,
        policy: locked ? ApparatusQueuePolicy.strictSequence : policy,
        locked: locked,
        reason: locked ? 'pechat_always_strict' : '',
      );
      _testModeApparatusQueuePolicies[normalized] = record;
      return record;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/queue-policies'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalized,
          'policy': policy.apiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_policies');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['policy'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'queue_policies_invalid_response',
        message: 'Aparat navbat qoidasi javobi noto‘g‘ri',
      );
    }
    return AdminApparatusQueuePolicy.fromJson(raw.cast<String, dynamic>());
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
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'apparatus_capacity_invalid_response',
        message: 'Aparat quvvati olinmadi',
      );
    }
    return AdminApparatusCapacitySnapshot.fromJson(
      raw.cast<String, dynamic>(),
    );
  }

  Future<AdminApparatusCapacityProfile> adminSaveApparatusCapacityProfile(
    AdminApparatusCapacityProfile profile,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = _normalizeTestModeCapacityProfile(profile);
      _testModeApparatusCapacityProfiles[normalized.apparatusId] = normalized;
      return normalized;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/capacity'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(profile.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'apparatus_capacity');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['profile'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'apparatus_capacity_invalid_response',
        message: 'Aparat profili saqlanmadi',
      );
    }
    return AdminApparatusCapacityProfile.fromJson(raw.cast<String, dynamic>());
  }

  Future<AdminApparatusDowntime> adminSaveApparatusDowntime(
    AdminApparatusDowntime downtime,
  ) async {
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/capacity/downtime',
        ),
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
    final key = idempotencyKey.trim().isEmpty
        ? 'mobile-schedule:${orderId.trim()}:${DateTime.now().microsecondsSinceEpoch}'
        : idempotencyKey.trim();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeScheduleApparatusOrder(
        orderId: orderId,
        apparatusId: apparatusId,
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
          'apparatus_id': apparatusId.trim(),
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/schedule/cancel',
        ),
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
    await for (final event
        in connectWarehouseLive(adminProductionMapLiveUri())) {
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
    required String apparatus,
    bool requiresMaterial = false,
    AdminRawMaterialStartPolicy startPolicy =
        AdminRawMaterialStartPolicy.stateAll,
    required List<String> itemGroups,
    List<AdminRawMaterialRequirementGroup> requirementGroups = const [],
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedGroups = itemGroups
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final normalizedRequirementGroups = requirementGroups
        .map((item) => item.toJson())
        .where((item) => (item['item_groups'] as List).isNotEmpty)
        .toList(growable: false);
    if (await TestModeController.instance.isEnabled()) {
      final rule = AdminRawMaterialRule(
        apparatus: normalizedApparatus,
        requiresMaterial: requiresMaterial,
        startPolicy: startPolicy,
        itemGroups: normalizedGroups,
        requirementGroups: requirementGroups,
      );
      _testModeRawMaterialRules[normalizedApparatus] = rule;
      return rule;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-rules'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'requires_material': requiresMaterial,
          'start_policy': startPolicy.apiValue,
          'item_groups': normalizedGroups,
          'requirement_groups': normalizedRequirementGroups,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'raw_material_rules');
    }
    return AdminRawMaterialRule.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminRawMaterialStartRequirements> adminRawMaterialStartRequirements({
    required String orderId,
    required String apparatus,
    List<String> materialBarcodes = const [],
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = apparatus.trim();
    if (await TestModeController.instance.isEnabled()) {
      AdminRawMaterialRule? rule;
      for (final candidate in _testModeRawMaterialRules.values) {
        if (productionMapWarehouseTitlesMatch(
          candidate.apparatus,
          normalizedApparatus,
        )) {
          rule = candidate;
          break;
        }
      }
      final orderAssignments = _testModeRawMaterialAssignments
          .where(
            (assignment) => assignment.orderId.trim() == normalizedOrderId,
          )
          .toList(growable: false);
      final assignments = orderAssignments
          .where(
            (assignment) => productionMapWarehouseTitlesMatch(
              assignment.apparatus,
              normalizedApparatus,
            ),
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
            (linked) => productionMapWarehouseTitlesMatch(
              linked.name,
              normalizedApparatus,
            ),
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
      final requiredScanCount = policy == AdminRawMaterialStartPolicy.stateAll
          ? stagedBarcodes.length
          : requirementGroups.fold<int>(
              0,
              (total, group) =>
                  total +
                  (group.minRequiredCount < 1 ? 1 : group.minRequiredCount),
            );
      final matchedScanCount = policy == AdminRawMaterialStartPolicy.stateAll
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
              assignedMatchedCount == requiredScanCount;
      final scanSatisfied = assignments.isEmpty
          ? !requiresMaterial
          : scannedBarcodes.isNotEmpty &&
              assignedBarcodes.containsAll(scannedBarcodes) &&
              (policy == AdminRawMaterialStartPolicy.stateAll
                  ? setEquals(scannedBarcodes, stagedBarcodes)
                  : requiredScanCount > 0 &&
                      matchedScanCount == requiredScanCount);
      return AdminRawMaterialStartRequirements(
        policy: policy,
        requiresMaterial: requiresMaterial,
        requirementGroups: requirementGroups,
        assignedBarcodes: assignedBarcodes.toList(growable: false),
        stagedBarcodes: stagedBarcodes.toList(growable: false),
        assignments: orderAssignments,
        startAssignments: eligibleAssignments,
        requiredScanCount: requiredScanCount,
        matchedScanCount: matchedScanCount,
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
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminRawMaterialAssignment>.unmodifiable(
        _testModeRawMaterialAssignments.where(
          (assignment) =>
              (orderId.trim().isEmpty ||
                  assignment.orderId.trim() == orderId.trim()) &&
              (apparatus.trim().isEmpty ||
                  productionMapWarehouseTitlesMatch(
                    assignment.apparatus,
                    apparatus,
                  )),
        ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/raw-material-assignments').replace(
          queryParameters: {
            if (orderId.trim().isNotEmpty) 'order_id': orderId.trim(),
            if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
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
          (item) => AdminRawMaterialAssignment.fromJson(
            item as Map<String, dynamic>,
          ),
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/raw-material-assignments/orders',
        ),
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
          (item) => ProductionMapSaved.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<AdminRawMaterialAssignmentCandidate>>
      adminRawMaterialAssignmentCandidates({
    required String orderId,
    String apparatus = '',
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = apparatus.trim();
    if (await TestModeController.instance.isEnabled()) {
      final profile = AppSession.instance.profile;
      final assignedApparatus = profile?.role == UserRole.materialTaminotchi
          ? profile?.assignedApparatus ?? const <String>[]
          : null;
      if (assignedApparatus != null &&
          normalizedApparatus.isNotEmpty &&
          !assignedApparatus.any(
            (assigned) => productionMapWarehouseTitlesMatch(
              assigned,
              normalizedApparatus,
            ),
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
            .map((rule) => rule.apparatus.trim())
            .where((apparatus) => apparatus.isNotEmpty)
            .where(
              (apparatus) =>
                  assignedApparatus == null ||
                  assignedApparatus.any(
                    (assigned) => productionMapWarehouseTitlesMatch(
                      apparatus,
                      assigned,
                    ),
                  ),
            )
            .where(
              (apparatus) =>
                  normalizedApparatus.isEmpty ||
                  productionMapWarehouseTitlesMatch(
                    apparatus,
                    normalizedApparatus,
                  ),
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
      return List<AdminRawMaterialAssignmentCandidate>.unmodifiable(
        candidates,
      );
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
      adminRawMaterialAssignmentCandidateOrders({
    required String barcode,
  }) async {
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
    final normalizedApparatus = apparatus.trim();
    if (await TestModeController.instance.isEnabled()) {
      final isActive = _testModeApparatusQueueStates.entries.any(
        (entry) =>
            productionMapWarehouseTitlesMatch(
              entry.key,
              normalizedApparatus,
            ) &&
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
        if (productionMapWarehouseTitlesMatch(
          candidate.apparatus,
          normalizedApparatus,
        )) {
          rule = candidate;
          break;
        }
      }
      return List<AdminRawMaterialAssignment>.unmodifiable(
        _testModeRawMaterialAssignments.where((assignment) {
          if (assignment.orderId.trim() != normalizedOrderId ||
              !productionMapWarehouseTitlesMatch(
                assignment.apparatus,
                normalizedApparatus,
              ) ||
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
          (item) => AdminRawMaterialAssignment.fromJson(
            item as Map<String, dynamic>,
          ),
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
    final body = {
      'order_id': orderId.trim(),
      'barcode': barcode.trim(),
      if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
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
    final body = {
      'order_id': orderId.trim(),
      'apparatus': apparatus.trim(),
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
            !productionMapWarehouseTitlesMatch(
              existing.apparatus,
              body['apparatus']!,
            )) {
          throw const MobileApiException(
            code: 'raw_material_already_assigned',
            message: 'Bu homashyo boshqa zakaz uchun band qilingan',
          );
        }
        final active = _testModeApparatusQueueStates.entries.any(
          (entry) =>
              productionMapWarehouseTitlesMatch(
                entry.key,
                body['apparatus']!,
              ) &&
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
    final body = {
      'order_id': orderId.trim(),
      'barcode': barcode.trim(),
    };
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
        warehouse: '',
        itemCode: '',
        itemName: '',
        itemGroup: '',
        qty: 0,
        uom: '',
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
    return {
      for (final entry in raw.entries)
        entry.key.toString(): [
          if (entry.value is List)
            for (final id in entry.value as List) id.toString(),
        ],
    };
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
    return {
      for (final entry in raw.entries)
        entry.key.toString(): {
          if (entry.value is Map)
            for (final stateEntry in (entry.value as Map).entries)
              stateEntry.key.toString(): stateEntry.value.toString(),
        },
    };
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
        continue;
      }
      final policy = AdminApparatusQueuePolicy.fromJson(
        item.cast<String, dynamic>(),
      );
      if (policy.apparatus.trim().isNotEmpty) {
        policies[policy.apparatus.trim()] = policy;
      }
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
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
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
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      finishedGoodsMeter: finishedGoodsMeter,
      uom: uom,
      qrPayload: qrPayload,
      progressBatchId: progressBatchId,
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/qolip-validate',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus.trim(),
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
    return AdminProductionMapQolipValidation(
      qolipCode: qolipCode.trim(),
    );
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/qolip-order-notes',
        ),
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
        Uri.parse(
          '$baseUrl/v1/mobile/admin/production-maps/qolip-order-notes',
        ),
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
    String description = '',
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedOrderId = orderId.trim();
    bool isNonNegative(double? value) =>
        value != null && value.isFinite && value >= 0;
    if (!productionMapIsLaminatsiyaApparatus(normalizedApparatus) ||
        normalizedOrderId.isEmpty ||
        !isNonNegative(laminationPrintLeftoverRolls) ||
        !isNonNegative(laminationFilmLeftoverRolls) ||
        !isNonNegative(totalWaste)) {
      throw const MobileApiException(
        code: 'laminatsiya_astatka_metrics_required',
        message: 'Bosmadan, plyonkadan ortgan rulon va chiqindini kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
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
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
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
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final knownKeys = {
        ..._testModeApparatusSequences.keys,
        ..._testModeApparatusQueueStates.keys,
      };
      final storageKey = resolveApparatusStorageKey(apparatus, knownKeys);
      final sequence = _testModeApparatusSequences[storageKey] ?? const [];
      final states = Map<String, String>.from(
        _testModeApparatusQueueStates[storageKey] ?? const {},
      );
      final control = _testModeOrderControls[orderId.trim()] ??
          AdminOrderControlState.active;
      if (control == AdminOrderControlState.frozen) {
        throw const MobileApiException(
          code: 'order_frozen',
          message: 'Buyurtma muzlatilgan',
        );
      }
      if (control == AdminOrderControlState.freezeRequested &&
          action != 'pause') {
        throw const MobileApiException(
          code: 'order_freeze_requested',
          message: 'Buyurtmani muzlatish uchun worker pauzasi kutilmoqda',
        );
      }
      final actionableStates = Map<String, String>.from(states)
        ..removeWhere(
          (id, _) =>
              _testModeOrderControls[id] == AdminOrderControlState.frozen,
        );
      final policy =
          _effectiveTestModeQueuePolicy(apparatus, storageKey).policy;
      final progressKey =
          qrPayload.trim().isEmpty ? progressBatchId.trim() : qrPayload.trim();
      final startUsesProgressQr = action == 'start' && progressKey.isNotEmpty;
      final startInputBatch = startUsesProgressQr
          ? _testModeProgressBatchForKey(progressKey)
          : null;
      final queueInputKey =
          _testModeProgressQueueKey(storageKey, orderId.trim());
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
      final isLaminatsiya = productionMapIsLaminatsiyaApparatus(apparatus);
      final laminatsiyaWipCanReuseMaterial = isLaminatsiya &&
          startInputBatch != null &&
          startInputBatch.wipStatus.trim().toLowerCase() == 'waiting' &&
          (startInputBatch.nextApparatus.trim().isEmpty ||
              productionMapNextStageTitleMatchesApparatus(
                startInputBatch.nextApparatus,
                apparatus,
              ));
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
      final isRezka = apparatus.trim().toLowerCase().contains('rezka');
      bool isPositive(double? value) =>
          value != null && value.isFinite && value > 0;
      final hasRezkaQuantityMetrics = isPositive(
            producedQty ?? finishedGoodsMeter,
          ) &&
          isPositive(grossQty ?? finishedGoodsKg);
      final hasRezkaWaste = [
        totalWaste,
        rezkaBosmaWaste,
        rezkaLaminationWaste,
        rezkaEdgeWaste,
      ].any(isPositive);
      final hasRezkaProgressMetrics =
          hasRezkaQuantityMetrics && (action != 'complete' || hasRezkaWaste);
      if (isRezka &&
          (action == 'pause' ||
              action == 'roll_complete' ||
              action == 'complete') &&
          !hasRezkaProgressMetrics) {
        throw const MobileApiException(
          code: 'rezka_progress_metrics_required',
          message:
              'Rezka uchun metraj va og‘irlikni kiriting; yakuniy rulonda chiqindi ham shart',
        );
      }
      if (isRezka &&
          (action == 'pause' ||
              action == 'roll_complete' ||
              action == 'complete') &&
          _testModeRezkaKadrCount(
                orderId: orderId,
                apparatus: apparatus,
              ) ==
              null) {
        throw const MobileApiException(
          code: 'rezka_kadr_count_required',
          message: 'Rezka uchun kadr soni sozlanmagan',
        );
      }
      final testModeOrderMap = _testModeOrderById(orderId)?.map;
      final previousStage = testModeOrderMap == null
          ? null
          : productionMapPreviousWorkStageStation(
              map: testModeOrderMap!,
              station: apparatus,
            );
      final hasPreviousStage = previousStage != null;
      final previousStageCompleted = hasPreviousStage &&
          _testModeApparatusQueueStates.entries.any(
            (entry) {
              final state = apparatusQueueOrderStateFromRaw(
                entry.value[orderId.trim()],
              );
              return productionMapWarehouseTitlesMatch(
                    entry.key,
                    previousStage!,
                  ) &&
                  state == ApparatusQueueOrderState.completed;
            },
          );
      bool isPreviousStageBatch(AdminProgressBatch batch) {
        if (!hasPreviousStage ||
            batch.orderId.trim() != orderId.trim() ||
            !productionMapWarehouseTitlesMatch(
              batch.apparatus,
              previousStage!,
            ) ||
            (batch.nextApparatus.trim().isNotEmpty &&
                !productionMapNextStageTitleMatchesApparatus(
                  batch.nextApparatus,
                  apparatus,
                ))) {
          return false;
        }
        final actionName = batch.action.trim().toLowerCase();
        if (actionName != 'pause' &&
            actionName != 'roll_complete' &&
            actionName != 'complete') {
          return false;
        }
        final wipStatus = batch.wipStatus.trim().toLowerCase();
        return wipStatus == 'waiting' ||
            (wipStatus == 'in_use' &&
                productionMapWarehouseTitlesMatch(
                  batch.usedByApparatus.trim().isEmpty
                      ? batch.currentApparatus
                      : batch.usedByApparatus,
                  apparatus,
                ));
      }

      final hasUnprocessedPreviousLaminatsiyaWip = isLaminatsiya &&
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
      final allowPartialLaminatsiyaCompletion = isLaminatsiya &&
          action == 'complete' &&
          !fullCompletionReportRequired &&
          hasUnprocessedPreviousLaminatsiyaWip;
      if (isRezka &&
          (action == 'pause' ||
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
          (action == 'pause' || action == 'complete') &&
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
            (inputWipStatus == 'in_use' &&
                productionMapWarehouseTitlesMatch(
                  inputUsedByApparatus,
                  apparatus,
                ));
        if (!inputWipIsUsable ||
            !productionMapWarehouseTitlesMatch(
                input.apparatus, previousStage!) ||
            (inputNextApparatus.isNotEmpty &&
                !productionMapNextStageTitleMatchesApparatus(
                  inputNextApparatus,
                  apparatus,
                ))) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: 'Bu QR oldingi bosqich mahsulotiga mos emas',
          );
        }
      }
      if (action == 'start') {
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
                  batchAction != 'roll_complete' &&
                  batchAction != 'complete') ||
              (batchStatus != 'paused' &&
                  batchStatus != 'completed' &&
                  batchStatus != 'resumed') ||
              (hasPreviousStage &&
                  ((batchWipStatus.isNotEmpty && batchWipStatus != 'waiting') ||
                      !productionMapWarehouseTitlesMatch(
                        batch.apparatus,
                        previousStage!,
                      ) ||
                      (batchNextApparatus.isNotEmpty &&
                          !productionMapNextStageTitleMatchesApparatus(
                            batchNextApparatus,
                            apparatus,
                          ))))) {
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
                  productionMapWarehouseTitlesMatch(
                    assignment.apparatus,
                    apparatus,
                  ),
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
        }
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: '',
          apparatus: storageKey,
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
              productionMapWarehouseTitlesMatch(
                assignment.apparatus,
                apparatus,
              ) &&
              scannedBarcodes
                  .contains(assignment.barcode.trim().toUpperCase())) {
            _testModeRawMaterialAssignments[index] = assignment.copyWith(
              stockStatus: 'in_use',
              reservedOrderId: orderId.trim(),
            );
          }
        }
      } else if (action == 'pause' &&
          (workerHandoff || removeRollFromApparatus)) {
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
                },
              );
        _testModeProgressBatchesByQr[updatedInput.qrPayload] = updatedInput;
        _testModeActiveProgressInputByQueue[queueInputKey] =
            updatedInput.qrPayload;
        states[orderId.trim()] = 'paused';
        _testModeRecordCompletedQueueOrder(
          actorRef: AppSession.instance.profile?.ref.trim() ?? '',
          apparatus: storageKey,
          orderId: orderId.trim(),
          status: 'in_progress',
        );
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatus: storageKey,
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
      } else if (action == 'pause') {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final qty = producedQty ?? 1;
        final outputBatches = isRezka
            ? _testModeRezkaProgressBatches(
                apparatus: storageKey,
                orderId: orderId.trim(),
                action: 'pause',
                status: 'paused',
                producedQty: qty,
                uom: uom.trim().isEmpty ? 'm' : uom.trim(),
                frameCount: _testModeRezkaKadrCount(
                  orderId: orderId,
                  apparatus: apparatus,
                )!,
                inputBatch: activeInputBatch,
                laminationPrintLeftoverRolls: null,
                laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                rezkaBosmaWaste: rezkaBosmaWaste,
                rezkaLaminationWaste: rezkaLaminationWaste,
                rezkaEdgeWaste: rezkaEdgeWaste,
                totalWaste: totalWaste,
                finishedGoodsKg: finishedGoodsKg ?? grossQty,
                finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
              )
            : [
                _testModeProgressBatch(
                  apparatus: storageKey,
                  orderId: orderId.trim(),
                  action: 'pause',
                  status: 'paused',
                  producedQty: qty,
                  uom: uom.trim().isEmpty ? 'kg' : uom.trim(),
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
          );
          _testModeProgressBatchesByQr[processedInput.qrPayload] =
              processedInput;
        }
        _testModeActiveProgressInputByQueue.remove(queueInputKey);
        states[orderId.trim()] = 'paused';
        _testModeRecordCompletedQueueOrder(
          actorRef: AppSession.instance.profile?.ref.trim() ?? '',
          apparatus: storageKey,
          orderId: orderId.trim(),
          status: 'in_progress',
        );
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatus: storageKey,
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
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
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
        final outputBatches = _testModeRezkaProgressBatches(
          apparatus: storageKey,
          orderId: orderId.trim(),
          action: 'roll_complete',
          status: 'completed',
          producedQty: producedQty ?? 1,
          uom: uom.trim().isEmpty ? 'm' : uom.trim(),
          frameCount: _testModeRezkaKadrCount(
            orderId: orderId,
            apparatus: apparatus,
          )!,
          inputBatch: activeInputBatch,
          rezkaBosmaWaste: rezkaBosmaWaste,
          rezkaLaminationWaste: rezkaLaminationWaste,
          rezkaEdgeWaste: rezkaEdgeWaste,
          totalWaste: totalWaste,
          finishedGoodsKg: finishedGoodsKg ?? grossQty,
          finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
        );
        for (final batch in outputBatches) {
          _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        }
        if (activeInputBatch != null) {
          final processedInput = _testModeMarkProgressInputProcessed(
            batch: activeInputBatch,
            apparatus: storageKey,
            orderId: orderId,
          );
          _testModeProgressBatchesByQr[processedInput.qrPayload] =
              processedInput;
        }
        _testModeActiveProgressInputByQueue.remove(queueInputKey);
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: '',
          apparatus: storageKey,
          orderId: orderId,
        );
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatus: storageKey,
          status: 'active',
        );
        _testModeApparatusQueueStates[storageKey] = states;
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
        );
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: outputBatches.first,
          progressBatches: List<AdminProgressBatch>.unmodifiable(outputBatches),
          printJob: printJobs.isEmpty ? null : printJobs.first,
          printJobs: List<UsbRpsPrintRequest>.unmodifiable(printJobs),
        );
      } else if (action == 'resume') {
        if (current != ApparatusQueueOrderState.paused) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        AdminProgressBatch? resumed;
        if (progressKey.isNotEmpty) {
          final batch = _testModeProgressBatchForKey(progressKey);
          if (batch == null ||
              batch.status != 'paused' ||
              batch.orderId != orderId.trim() ||
              !productionMapWarehouseTitlesMatch(batch.apparatus, storageKey)) {
            throw const MobileApiException(
              code: 'progress_batch_not_resumable',
              message: 'Bu progress QR davom ettirishga yaramaydi',
            );
          }
          resumed = batch.copyWith(status: 'resumed');
          _testModeProgressBatchesByQr[batch.qrPayload] = resumed;
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
        }
        _testModeEnsureApparatusExecutionCapacity(
          apparatusId: '',
          apparatus: storageKey,
          orderId: orderId,
        );
        states[orderId.trim()] = 'in_progress';
        _testModeSyncScheduleReservationStatus(
          orderId: orderId,
          apparatus: storageKey,
          status: 'active',
        );
        _testModeApparatusQueueStates[storageKey] = states;
        return AdminApparatusQueueActionResult(
          states: Map<String, String>.unmodifiable(states),
          progressBatch: resumed,
        );
      } else if (action == 'complete') {
        if (current != ApparatusQueueOrderState.inProgress) {
          throw const MobileApiException(
            code: 'queue_action_not_allowed',
            message: 'Faqat navbatdagi zakazni boshlash yoki tugatish mumkin',
          );
        }
        final hasPendingRezkaSourceRoll = isRezka &&
            hasPreviousStage &&
            (!previousStageCompleted ||
                _testModeProgressBatchesByQr.values.any((batch) {
                  if (batch.orderId.trim() != orderId.trim() ||
                      !productionMapWarehouseTitlesMatch(
                        batch.apparatus,
                        previousStage!,
                      ) ||
                      (batch.nextApparatus.trim().isNotEmpty &&
                          !productionMapNextStageTitleMatchesApparatus(
                            batch.nextApparatus,
                            apparatus,
                          )) ||
                      (activeInputBatch != null &&
                          (batch.batchId.trim() ==
                                  activeInputBatch.batchId.trim() ||
                              batch.qrPayload.trim().toLowerCase() ==
                                  activeInputBatch.qrPayload
                                      .trim()
                                      .toLowerCase()))) {
                    return false;
                  }
                  final actionName = batch.action.trim().toLowerCase();
                  if (actionName != 'pause' &&
                      actionName != 'roll_complete' &&
                      actionName != 'complete') {
                    return false;
                  }
                  final wipStatus = batch.wipStatus.trim().toLowerCase();
                  return wipStatus == 'waiting' ||
                      (wipStatus == 'in_use' &&
                          productionMapWarehouseTitlesMatch(
                            batch.usedByApparatus.trim().isEmpty
                                ? batch.currentApparatus
                                : batch.usedByApparatus,
                            apparatus,
                          ));
                }));
        if (hasPendingRezkaSourceRoll) {
          throw const MobileApiException(
            code: 'rezka_final_roll_required',
            message:
                'Avval qolgan laminatsiya rulonlarini tugating; to‘liq tugatish faqat oxirgi rulonda mumkin',
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
        final hasLaminatsiyaCompleteMetrics = allowPartialLaminatsiyaCompletion
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
            !hasRezkaProgressMetrics &&
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
                frameCount: _testModeRezkaKadrCount(
                  orderId: orderId,
                  apparatus: apparatus,
                )!,
                inputBatch: activeInputBatch,
                returnInkKg: returnInkKg,
                laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
                laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
                rezkaBosmaWaste: rezkaBosmaWaste,
                rezkaLaminationWaste: rezkaLaminationWaste,
                rezkaEdgeWaste: rezkaEdgeWaste,
                totalWaste: totalWaste,
                finishedGoodsKg: finishedGoodsKg ?? grossQty,
                finishedGoodsMeter: finishedGoodsMeter ?? producedQty,
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
          );
          _testModeProgressBatchesByQr[processedInput.qrPayload] =
              processedInput;
        }
        _testModeActiveProgressInputByQueue.remove(queueInputKey);
        final batch = outputBatches.first;
        states[orderId.trim()] =
            hasUnprocessedPreviousLaminatsiyaWip ? 'pending' : 'completed';
        _testModeApparatusQueueStates[storageKey] = states;
        final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
        final completedOrderId = orderId.trim();
        if (actorRef.isNotEmpty && completedOrderId.isNotEmpty) {
          _testModeRecordCompletedQueueOrder(
            actorRef: actorRef,
            apparatus: storageKey,
            orderId: completedOrderId,
            status: _testModeQueueHistoryStatus(
              orderId: completedOrderId,
              fallbackStatus: 'completed',
            ),
          );
        }
        if (returnedPaintItems.isNotEmpty ||
            returnedPaintImageId.trim().isNotEmpty) {
          final reportId =
              'returned-paint-complete:$completedOrderId:$storageKey';
          if (!_testModeReturnedPaintRequests
              .any((request) => request.id == reportId)) {
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
          apparatus: storageKey,
          status: 'completed',
        );
        final printJobs = _testModeProgressPrintJobs(
          batches: outputBatches,
          printer: printer,
          printMode: printMode,
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
          apparatus: storageKey,
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
          if (uom.trim().isNotEmpty) 'uom': uom.trim(),
          if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          if (progressBatchId.trim().isNotEmpty)
            'progress_batch_id': progressBatchId.trim(),
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
    if (raw is! Map) {
      return const AdminApparatusQueueActionResult(states: {});
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
    final printJobs = <UsbRpsPrintRequest>[
      if (payload['prints'] is List)
        for (final item in payload['prints'] as List)
          if (item is Map && item['ok'] == true)
            UsbRpsPrintRequest.fromPrintJson(item.cast<String, dynamic>()),
    ];
    final legacyProgressBatch = progressRaw is Map
        ? AdminProgressBatch.fromJson(progressRaw.cast<String, dynamic>())
        : (progressBatches.isEmpty ? null : progressBatches.first);
    final legacyPrintJob = printRaw is Map && printRaw['ok'] == true
        ? UsbRpsPrintRequest.fromPrintJson(printRaw.cast<String, dynamic>())
        : (printJobs.isEmpty ? null : printJobs.first);
    return AdminApparatusQueueActionResult(
      states: {
        for (final entry in raw.entries)
          entry.key.toString(): entry.value.toString(),
      },
      orderStatus: AdminProductionOrderStatusDetail.fromJson(
        payload['order_status'],
      ),
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
      final batch = _testModeProgressBatchesByQr[normalized];
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
            '$baseUrl/v1/mobile/admin/production-maps/progress-qr/lookup'),
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
        ).replace(
          queryParameters: {'limit': boundedLimit.toString()},
        ),
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
    final normalizedDriverUrl =
        driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final normalizedPrinter = printer.trim();
    final normalizedPrintMode = printMode.trim();

    if (await TestModeController.instance.isEnabled()) {
      AdminProgressBatch? batch;
      if (normalizedQrPayload.isNotEmpty) {
        batch = _testModeProgressBatchesByQr[normalizedQrPayload];
      } else {
        for (final candidate in _testModeProgressBatchesByQr.values) {
          if (candidate.batchId.trim() == normalizedBatchId) {
            batch = candidate;
            break;
          }
        }
      }
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
        warehouse: 'Ijrochi: ${batch.executorName}',
        printer: normalizedPrinter.isEmpty ? 'godex' : normalizedPrinter,
        printMode: normalizedPrintMode.isEmpty ? 'label' : normalizedPrintMode,
        grossQty: batch.finishedGoodsKg ?? batch.producedQty,
        unit: 'kg',
        printCount: boundedPrintCount,
        labelKind: 'progress',
        executorName: batch.executorName,
        progressQty: batch.producedQty,
        progressUnit: batch.uom.isEmpty ? 'm' : batch.uom,
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
      final batch = _testModeProgressBatchesByQr[normalized];
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      return AdminProgressQrReport(
        scannedBatch: batch,
        currentBatch: batch,
        isStale: false,
        staleReason: '',
        queueStates: const {},
        logs: const [],
        progressBatches: [batch],
        runSessions: const [],
        activeSessions: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
            '$baseUrl/v1/mobile/admin/production-maps/progress-qr/report'),
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
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceSequenceSaveFailure) {
        throw const MobileApiException(
          code: 'production_map_sequence',
          message: 'Ketma-ketlik saqlanmadi (test)',
        );
      }
      _testModeApparatusSequences[apparatus.trim()] = List<String>.from(
        orderIds,
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/admin/production-maps/sequence'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'apparatus': apparatus, 'order_ids': orderIds}),
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
      return TestModeDemoData.roleAssignments;
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
        Uri.parse('$baseUrl/v1/mobile/admin/system-users/detail')
            .replace(queryParameters: {'id': id}),
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
        Uri.parse('$baseUrl/v1/mobile/admin/system-users/code/regenerate')
            .replace(queryParameters: {'id': id}),
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
        Uri.parse('$baseUrl/v1/mobile/admin/workers/delete-check')
            .replace(queryParameters: {'id': id}),
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
    String apparatus = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final key = apparatus.trim().toLowerCase();
      return _testModeWorkerGroups
          .where(
            (group) =>
                key.isEmpty || group.apparatus.trim().toLowerCase() == key,
          )
          .map(_hydrateTestModeWorkerGroup)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/admin/worker-groups').replace(
          queryParameters: {
            if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
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
    String? previousApparatus,
    String? previousGroupCode,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = _normalizeTestModeWorkerGroup(group);
      final key = normalized.apparatus.trim().toLowerCase();
      final code = normalized.groupCode.trim().toUpperCase();
      final previousKey = previousApparatus?.trim().toLowerCase();
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
                item.apparatus.trim().toLowerCase() == previousKey &&
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
          return item.apparatus.trim().toLowerCase() == previousKey &&
              item.groupCode.trim().toUpperCase() == previousCode;
        }
        return item.groupCode.trim().toUpperCase() == code;
      };
      final duplicateName = _testModeWorkerGroups.any(
        (item) =>
            item.apparatus.trim().toLowerCase() == key &&
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
            item.apparatus.trim().toLowerCase() == key &&
            !isPreviousGroup(item) &&
            item.workerIds.any(normalized.workerIds.toSet().contains),
      );
      if (duplicate) {
        throw const MobileApiException(
          code: 'worker_duplicated_in_group',
          message: 'Ishchi boshqa guruhga ulangan',
        );
      }
      _testModeWorkerGroups.removeWhere(
        isPreviousGroup,
      );
      _testModeWorkerGroups.add(normalized);
      return _hydrateTestModeWorkerGroup(normalized);
    }
    final payload = group.toJson();
    final normalizedPreviousApparatus = previousApparatus?.trim() ?? '';
    final normalizedPreviousGroupCode = previousGroupCode?.trim() ?? '';
    if (normalizedPreviousApparatus.isNotEmpty) {
      payload['previous_apparatus'] = normalizedPreviousApparatus;
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
    final workerIds = group.workerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final groupCode =
        group.groupCode.trim().split(RegExp(r'\s+')).join(' ').toUpperCase();
    return AdminWorkerGroup(
      apparatus: group.apparatus.trim(),
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
      final systemRole = switch (role.trim().toLowerCase()) {
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
          items: items.skip(offset).take(limit).toList(growable: false),
          hasMore: items.length > offset + limit,
        );
      }
      return TestModeDemoData.userListPage(
        query: query,
        limit: limit,
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
      return (await adminMaterialTaminotchiDetail(ref)).copyWith(
        assignedItemGroups: normalizedGroups,
      );
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
  String apparatus,
  String storageKey,
) {
  final title =
      storageKey.trim().isEmpty ? apparatus.trim() : storageKey.trim();
  final locked = productionMapIsPechatApparatus(title) ||
      productionMapIsPechatApparatus(apparatus);
  if (locked) {
    return AdminApparatusQueuePolicy(
      apparatus: title,
      policy: ApparatusQueuePolicy.strictSequence,
      locked: true,
      reason: 'pechat_always_strict',
    );
  }
  return _testModeApparatusQueuePolicies[title] ??
      _testModeApparatusQueuePolicies[apparatus.trim()] ??
      AdminApparatusQueuePolicy(
        apparatus: title,
        policy: ApparatusQueuePolicy.strictSequence,
      );
}

String _testModeQueueHistoryStatus({
  required String orderId,
  required String fallbackStatus,
}) {
  final normalizedOrderId = orderId.trim();
  final normalizedFallback = fallbackStatus.trim().toLowerCase();
  if (normalizedFallback != 'completed') {
    return 'in_progress';
  }
  ProductionMapSaved? saved;
  for (final candidate in _testModeProductionMaps) {
    if (candidate.map.id.trim() == normalizedOrderId) {
      saved = candidate;
      break;
    }
  }
  if (saved == null) {
    return normalizedFallback;
  }
  final apparatusTitles = <String>[];
  final seenTitles = <String>{};
  for (final node in saved.map.nodes) {
    if (node.kind != 'apparatus') continue;
    final title = (node.alternativeAssignedTitle.trim().isEmpty
            ? node.title
            : node.alternativeAssignedTitle)
        .trim();
    if (title.isNotEmpty && seenTitles.add(title.toLowerCase())) {
      apparatusTitles.add(title);
    }
  }
  if (apparatusTitles.isEmpty) {
    return normalizedFallback;
  }
  final fullyCompleted = apparatusTitles.every(
    (title) => _testModeApparatusQueueStates.entries.any(
      (entry) =>
          productionMapWarehouseTitlesMatch(entry.key, title) &&
          entry.value[normalizedOrderId]?.trim().toLowerCase() == 'completed',
    ),
  );
  return fullyCompleted ? 'completed' : 'in_progress';
}

void _testModeRecordCompletedQueueOrder({
  required String actorRef,
  required String apparatus,
  required String orderId,
  required String status,
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
  double? returnInkKg,
  double? laminationPrintLeftoverRolls,
  double? laminationFilmLeftoverRolls,
  double? rezkaBosmaWaste,
  double? rezkaLaminationWaste,
  double? rezkaEdgeWaste,
  double? totalWaste,
  double? finishedGoodsKg,
  double? finishedGoodsMeter,
}) {
  final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final batchId = batchIdOverride?.trim().isNotEmpty == true
      ? batchIdOverride!.trim()
      : 'test-progress-$stamp-$orderId-$action';
  final qrPayload = qrPayloadOverride?.trim().isNotEmpty == true
      ? qrPayloadOverride!.trim()
      : 'GSP:$batchId'.toUpperCase();
  final executor = AppSession.instance.profile?.displayName.trim() ?? '';
  final statusDetail = AdminProgressBatchStatusDetail.fromJsonOrBatchJson({
    'action': action,
    'status': status,
    'wip_status': 'waiting',
    'next_apparatus': '',
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
    labelItemName: '$orderId yarim tayyor, $apparatus holatda, $status',
    executorName: executor,
    returnInkKg: returnInkKg,
    laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
    laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
    rezkaBosmaWaste: rezkaBosmaWaste,
    rezkaLaminationWaste: rezkaLaminationWaste,
    rezkaEdgeWaste: rezkaEdgeWaste,
    totalWaste: totalWaste,
    finishedGoodsKg: finishedGoodsKg,
    finishedGoodsMeter: finishedGoodsMeter,
    wipStatus: 'waiting',
    statusDetail: statusDetail,
    currentApparatus: apparatus,
    currentLocation: apparatus,
    parentBatchId: parentBatchId,
    startedAtUnix: nowUnix,
    completedAtUnix: nowUnix,
    payloadJson: payloadJson,
  );
}

String _testModeProgressQueueKey(String apparatus, String orderId) =>
    '${apparatus.trim().toLowerCase()}|${orderId.trim().toLowerCase()}';

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
        (productionMapIsRezkaApparatus(node.title) ||
            productionMapIsRezkaApparatus(node.alternativeAssignedTitle)) &&
        _testModeProductionMapNodeMatchesStation(node, apparatus) &&
        node.rezkaKadrCount != null &&
        node.rezkaKadrCount! > 0) {
      return node.rezkaKadrCount;
    }
  }
  return null;
}

bool _testModeProductionMapNodeMatchesStation(
  ProductionMapNode node,
  String station,
) {
  return productionMapWarehouseTitlesMatch(node.title, station) ||
      (node.alternativeAssignedTitle.trim().isNotEmpty &&
          productionMapWarehouseTitlesMatch(
            node.alternativeAssignedTitle,
            station,
          ));
}

AdminProgressBatch _testModeMarkProgressInputProcessed({
  required AdminProgressBatch batch,
  required String apparatus,
  required String orderId,
}) {
  return batch.copyWith(
    wipStatus: 'processed',
    currentApparatus: apparatus,
    currentLocation: apparatus,
    processedBySessionId: 'test-session-${orderId.trim()}',
    processedByApparatus: apparatus,
  );
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
  double? returnInkKg,
  double? laminationPrintLeftoverRolls,
  double? laminationFilmLeftoverRolls,
  double? rezkaBosmaWaste,
  double? rezkaLaminationWaste,
  double? rezkaEdgeWaste,
  double? totalWaste,
  double? finishedGoodsKg,
  double? finishedGoodsMeter,
}) {
  final baseStamp = DateTime.now().microsecondsSinceEpoch;
  final parentBatchId = inputBatch?.batchId.trim() ?? '';
  final map = _testModeOrderById(orderId)?.map;
  double? labelLength;
  if (map != null) {
    for (final node in map.nodes) {
      final value = node.rezkaLabelLength;
      if (node.kind == 'apparatus' &&
          (productionMapIsRezkaApparatus(node.title) ||
              productionMapIsRezkaApparatus(node.alternativeAssignedTitle)) &&
          _testModeProductionMapNodeMatchesStation(node, apparatus) &&
          value != null &&
          value > 0) {
        labelLength = value;
        break;
      }
    }
  }
  return [
    for (var index = 0; index < frameCount; index += 1)
      _testModeProgressBatch(
        apparatus: apparatus,
        orderId: orderId,
        action: action,
        status: status,
        producedQty: producedQty,
        uom: uom,
        batchIdOverride:
            'test-progress-$baseStamp-$orderId-$action:frame:${index + 1}',
        parentBatchId: parentBatchId,
        returnInkKg: index == 0 ? returnInkKg : null,
        laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
        laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
        rezkaBosmaWaste: index == 0 ? rezkaBosmaWaste : null,
        rezkaLaminationWaste: index == 0 ? rezkaLaminationWaste : null,
        rezkaEdgeWaste: index == 0 ? rezkaEdgeWaste : null,
        totalWaste: index == 0 ? totalWaste : null,
        finishedGoodsKg: finishedGoodsKg,
        finishedGoodsMeter: finishedGoodsMeter,
        payloadJson: {
          'rezka_frame_index': index + 1,
          'rezka_frame_count': frameCount,
          'rezka_output_kind': 'frame',
          'rezka_metrics_owner': index == 0,
          if (labelLength != null) 'rezka_label_length': labelLength,
        },
      ),
  ];
}

List<UsbRpsPrintRequest> _testModeProgressPrintJobs({
  required List<AdminProgressBatch> batches,
  required String printer,
  required String printMode,
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
        grossQty: batch.finishedGoodsKg ?? batch.producedQty,
        unit: 'kg',
        labelKind: 'progress',
        executorName: batch.executorName,
        progressQty: batch.producedQty,
        progressUnit: batch.uom.isEmpty ? 'm' : batch.uom,
      ),
  ];
}
