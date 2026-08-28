part of '../mobile_api.dart';

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

  AdminRawMaterialStartRequirements withLocalScannedBarcodes(
    Iterable<String> barcodes,
  ) {
    final scannedBarcodes = barcodes
        .map(_normalizeRawMaterialBarcode)
        .where((barcode) => barcode.isNotEmpty)
        .toSet();
    final assigned = normalizedAssignedBarcodes;
    final staged = normalizedStagedBarcodes;
    final matchedCount = policy == AdminRawMaterialStartPolicy.stateAll
        ? scannedBarcodes.intersection(staged).length
        : _matchedRawMaterialRequirementCount(
            requirementGroups: requirementGroups,
            assignments: startAssignments,
            barcodes: scannedBarcodes,
          );
    final locallySatisfied = assignments.isEmpty && !requiresMaterial ||
        assignments.isNotEmpty &&
            scannedBarcodes.isNotEmpty &&
            assigned.containsAll(scannedBarcodes) &&
            (policy == AdminRawMaterialStartPolicy.stateAll
                ? setEquals(scannedBarcodes, staged)
                : requiredScanCount > 0 && matchedCount == requiredScanCount);
    return AdminRawMaterialStartRequirements(
      policy: policy,
      requiresMaterial: requiresMaterial,
      requirementGroups: requirementGroups,
      assignedBarcodes: assignedBarcodes,
      stagedBarcodes: stagedBarcodes,
      assignments: assignments,
      startAssignments: startAssignments,
      requiredScanCount: requiredScanCount,
      matchedScanCount: matchedCount,
      assignmentsSatisfied: assignmentsSatisfied,
      scanSatisfied: locallySatisfied,
    );
  }
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

int _matchedRawMaterialRequirementCount({
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

extension MobileApiAdminRawMaterials on MobileApi {
Future<List<AdminRawMaterialRule>> adminRawMaterialRules() async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeRawMaterialRules.values.toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-rules'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-rules'),
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
              : _matchedRawMaterialRequirementCount(
                  requirementGroups: requirementGroups,
                  assignments: assignments,
                  barcodes: scannedBarcodes,
                );
      final assignedMatchedCount = _matchedRawMaterialRequirementCount(
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
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-start-requirements',
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments').replace(
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments/orders'),
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
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments/candidates',
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
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments/candidate-orders',
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
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-intake-candidates',
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-history').replace(
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-intake'),
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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments'),
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
          '${MobileApi.baseUrl}/v1/mobile/admin/raw-material-assignments/lookup',
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
}
