part of '../mobile_api.dart';

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

extension MobileApiAdminCapacitySchedule on MobileApi {
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/capacity'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/capacity'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/capacity/downtime'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/schedule'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/schedule/cancel'),
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
}
