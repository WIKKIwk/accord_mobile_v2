part of '../mobile_api.dart';

final List<ProductionMapSaved> _testModeProductionMaps = [];

final List<AdminOpeningWipRecord> _testModeOpeningWipRecords = [];

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

final Map<String, Map<String, String>> _testModeProductionMapStageStates = {};

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

void setMobileApiTestModeForceSequenceSaveFailure(bool value) {
  _testModeForceSequenceSaveFailure = value;
}

void setMobileApiTestModeForceCalculateTemplateSaveFailure(bool value) {
  _testModeForceCalculateTemplateSaveFailure = value;
}

void resetMobileApiTestModeData() {
  _testModeProductionMaps.clear();
  _testModeOpeningWipRecords.clear();
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
  _testModeProductionMapStageStates.clear();
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

bool _testModeNodeHasOperation(ProductionMapNode node, String operation) {
  final apparatusId = _testModeEffectiveNodeApparatusId(node);
  if (apparatusId.isEmpty) return false;
  return _testModeRequiredApparatus(apparatusId)
          .operation
          .trim()
          .toLowerCase() ==
      operation.trim().toLowerCase();
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

const _knownApparatusQueueStates = {
  'pending',
  'in_progress',
  'paused',
  'frozen',
  'completed',
};

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

ProductionMapSaved? _testModeOrderById(String orderId) {
  final normalized = orderId.trim();
  for (final saved in _testModeProductionMaps) {
    if (saved.map.id.trim() == normalized) return saved;
  }
  return null;
}
