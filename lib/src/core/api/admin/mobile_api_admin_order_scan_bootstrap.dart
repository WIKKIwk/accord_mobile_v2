part of '../mobile_api.dart';

/// Short-lived detail data. This is never a full live/delta baseline.
class AdminOrderScanBootstrap {
  const AdminOrderScanBootstrap({
    required this.controlState,
    required this.scope,
    this.materials,
    this.qolips,
    this.queueContext,
    this.validatedProgress,
    this.materialAssignments,
    this.inputProgressBatches,
  });

  final AdminPrintPreflightControlState controlState;
  final String scope;
  final AdminRawMaterialStartRequirements? materials;
  final AdminProductionMapQolipValidation? qolips;
  final AdminApparatusQueueSnapshot? queueContext;
  final AdminProgressBatch? validatedProgress;
  final List<AdminRawMaterialAssignment>? materialAssignments;
  final List<AdminProgressBatch>? inputProgressBatches;

  factory AdminOrderScanBootstrap.fromJson(
    Map<String, dynamic> json, {
    required String apparatus,
    required String orderId,
    String qrPayload = '',
  }) {
    final rawControl = json['control_state'];
    final control = AdminPrintPreflightControlState.tryFromJson(rawControl);
    if (json['ok'] != true ||
        control == null ||
        control.apparatus != apparatus ||
        control.orderId != orderId ||
        rawControl is! Map ||
        rawControl['scope'] is! String ||
        (rawControl['scope'] as String).isEmpty) {
      throw _productionMapQueueContractException(
        'invalid scan bootstrap control',
      );
    }
    final sections = json['sections'];
    Object? ready(String name) {
      final section = sections is Map ? sections[name] : null;
      return section is Map && section['status'] == 'ready'
          ? section['data']
          : null;
    }

    return AdminOrderScanBootstrap(
      controlState: control,
      scope: rawControl['scope'] as String,
      materials: _completeBootstrapMaterials(ready('materials'), orderId),
      qolips: _completeBootstrapQolips(ready('qolips')),
      materialAssignments: _bootstrapMaterialAssignments(
          sections is Map ? sections['material_assignments'] : null, control),
      inputProgressBatches: _bootstrapInputProgress(
          sections is Map ? sections['input_progress'] : null, control),
      queueContext: json.containsKey('queue_context')
          ? _completeBootstrapQueueContext(
              json['queue_context'], control, rawControl['scope'] as String)
          : null,
      validatedProgress: json.containsKey('validated_progress')
          ? _completeBootstrapProgress(
              json['validated_progress'], control, qrPayload)
          : null,
    );
  }
}

Object? _bootstrapComparableJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _bootstrapComparableJson(value[key])};
  }
  if (value is List) return value.map(_bootstrapComparableJson).toList();
  return value;
}

AdminApparatusQueueSnapshot _completeBootstrapQueueContext(
  Object? raw,
  AdminPrintPreflightControlState control,
  String scope,
) {
  if (raw is! Map ||
      raw['ok'] != true ||
      raw['maps'] is! List ||
      raw['stage_states'] is! Map) {
    throw _productionMapQueueContractException('invalid scan queue context');
  }
  final snapshot = _productionMapQueueSnapshotFromJson(
      raw.cast<String, dynamic>());
  final targetControl =
      snapshot.queueActionControls[control.apparatus]?[control.orderId];
  final ids = snapshot.maps.map((order) => order.map.id.trim()).toList();
  if (snapshot.epoch != control.epoch ||
      snapshot.revision != control.revision ||
      snapshot.scope != scope ||
      snapshot.queueStates[control.apparatus]?[control.orderId] !=
          control.queueState ||
      snapshot.orderControlFor(control.orderId) != control.orderControl ||
      !mapEquals(snapshot.stageStates[control.orderId] ?? const {},
          control.stageStates) ||
      targetControl == null ||
      jsonEncode(_bootstrapComparableJson(
              jsonDecode(targetControl.serverContractSignature))) !=
          jsonEncode(_bootstrapComparableJson(
              jsonDecode(control.control.serverContractSignature))) ||
      ids.length != (raw['maps'] as List).length ||
      ids.any((id) => id.isEmpty) ||
      ids.toSet().length != ids.length ||
      !ids.contains(control.orderId)) {
    throw _productionMapQueueContractException(
        'scan queue context disagrees with control');
  }
  return snapshot;
}

AdminProgressBatch _completeBootstrapProgress(
  Object? raw,
  AdminPrintPreflightControlState control,
  String qrPayload,
) {
  if (raw is! Map ||
      raw['ok'] != true ||
      raw['active_order_validated'] != true ||
      raw['validated_apparatus'] != control.apparatus ||
      raw['validated_order_id'] != control.orderId ||
      control.orderControl != AdminOrderControlState.active ||
      raw['batch'] is! Map) {
    throw _productionMapQueueContractException('invalid scan progress proof');
  }
  final batch = raw['batch'] as Map;
  if (qrPayload.trim().isEmpty ||
      batch['batch_id'] is! String ||
      (batch['batch_id'] as String).trim().isEmpty ||
      batch['order_id'] != control.orderId ||
      batch['qr_payload'] is! String ||
      (batch['qr_payload'] as String).trim().toUpperCase() !=
          qrPayload.trim().toUpperCase() ||
      batch['wip_status'] != 'waiting' ||
      raw['input_route'] is! Map ||
      (raw['input_route_error'] != null && raw['input_route_error'] != '')) {
    throw _productionMapQueueContractException(
        'invalid scan progress identity');
  }
  final route = AdminProgressInputRoute.fromJson(
      (raw['input_route'] as Map).cast<String, dynamic>());
  if (!route.consumerApparatusIds.contains(control.apparatus)) {
    throw _productionMapQueueContractException('invalid scan progress route');
  }
  return AdminProgressBatch.fromJson(batch.cast<String, dynamic>(),
      inputRoute: route, hasInputRouteMetadata: true);
}

bool _bootstrapStrings(Object? raw) =>
    raw is List && raw.every((value) => value is String && value.isNotEmpty);

bool _bootstrapScopedSection(
    Object? raw, AdminPrintPreflightControlState control) =>
    raw is Map &&
    raw['status'] == 'ready' &&
    raw['apparatus'] == control.apparatus &&
    raw['order_id'] == control.orderId &&
    raw['stage_node_id'] == control.control.stageNodeId;

List<AdminRawMaterialAssignment>? _bootstrapMaterialAssignments(
    Object? section, AdminPrintPreflightControlState control) {
  if (!_bootstrapScopedSection(section, control) || section is! Map ||
      section['data'] is! List) {
    return null;
  }
  final rows = section['data'] as List;
  final barcodes = <String>{};
  final result = <AdminRawMaterialAssignment>[];
  try {
    for (final raw in rows) {
      if (raw is! Map || raw['order_id'] != control.orderId ||
          raw['apparatus'] != control.apparatus ||
          raw['barcode'] is! String ||
          (raw['barcode'] as String).trim().isEmpty ||
          !barcodes.add((raw['barcode'] as String).trim().toUpperCase()) ||
          ['item_code', 'item_name', 'item_group']
              .any((key) => raw[key] is! String)) {
        return null;
      }
      result.add(AdminRawMaterialAssignment.fromJson(
          raw.cast<String, dynamic>()));
    }
  } catch (_) {
    return null;
  }
  return List.unmodifiable(result);
}

List<AdminProgressBatch>? _bootstrapInputProgress(
    Object? section, AdminPrintPreflightControlState control) {
  if (!_bootstrapScopedSection(section, control) || section is! Map ||
      section['limit'] is! int || section['limit'] != 500 ||
      section['status_filter'] != 'waiting' ||
      section['data'] is! Map) {
    return null;
  }
  final rows = (section['data'] as Map)['batches'];
  if (rows is! List || rows.length > 500) return null;
  final ids = <String>{};
  final qrs = <String>{};
  final result = <AdminProgressBatch>[];
  try {
    for (final raw in rows) {
      if (raw is! Map || raw['order_id'] != control.orderId ||
          raw['wip_status'] != 'waiting' ||
          raw['batch_id'] is! String ||
          (raw['batch_id'] as String).trim().isEmpty ||
          !ids.add((raw['batch_id'] as String).trim()) ||
          raw['qr_payload'] is! String ||
          (raw['qr_payload'] as String).trim().isEmpty ||
          !qrs.add((raw['qr_payload'] as String).trim().toUpperCase()) ||
          raw['apparatus'] is! String || raw['uom'] is! String ||
          raw['produced_qty'] is! num ||
          !(raw['produced_qty'] as num).isFinite ||
          (raw['payload_json'] != null && raw['payload_json'] is! Map)) {
        return null;
      }
      result.add(AdminProgressBatch.fromJson(raw.cast<String, dynamic>()));
    }
  } catch (_) {
    return null;
  }
  // This is the existing bounded candidate page, never a complete WIP history
  // or authority to accept a scanned roll without its independent QR proof.
  return List.unmodifiable(result);
}

AdminRawMaterialStartRequirements? _completeBootstrapMaterials(
  Object? raw,
  String orderId,
) {
  // Existing decoders support older servers by defaulting absent fields. A
  // reusable aggregate section needs evidence of completeness before skipping
  // its independent reader; malformed sections deliberately return null.
  if (raw is! Map ||
      !const {'state_all', 'requirement_groups'}.contains(raw['policy']) ||
      [
        'requires_material',
        'material_scan_required',
        'assignments_satisfied',
        'scan_satisfied',
      ].any((key) => raw[key] is! bool) ||
      [
        'required_scan_count',
        'matched_scan_count',
      ].any((key) => raw[key] is! int || (raw[key] as int) < 0) ||
      [
        'assigned_barcodes',
        'staged_barcodes',
        'eligible_barcodes',
      ].any((key) => !_bootstrapStrings(raw[key])) ||
      raw['requirement_groups'] is! List ||
      (raw['requirement_groups'] as List).any(
        (group) =>
            group is! Map ||
            (group['requirement_id'] ?? group['name']) is! String ||
            !_bootstrapStrings(
              group['item_group_ids'] ?? group['item_groups'],
            ) ||
            (group['minimum_required_count'] ?? group['min_required_count'])
                is! int,
      ) ||
      ['assignments', 'start_assignments'].any(
        (key) =>
            raw[key] is! List ||
            (raw[key] as List).any(
              (row) =>
                  row is! Map ||
                  row['order_id'] != orderId ||
                  row['barcode'] is! String ||
                  (row['barcode'] as String).isEmpty ||
                  (row['apparatus_id'] ?? row['apparatus']) is! String,
            ),
      )) {
    return null;
  }
  try {
    return AdminRawMaterialStartRequirements.fromJson(
      raw.cast<String, dynamic>(),
    );
  } catch (_) {
    return null;
  }
}

AdminProductionMapQolipValidation? _completeBootstrapQolips(Object? raw) {
  if (raw is! Map || raw['ok'] != true || raw['qolip'] is! Map) return null;
  final qolip = raw['qolip'] as Map;
  final entries = qolip['required_qolips'];
  final codes = qolip['required_qolip_codes'];
  if (qolip['qolip_code'] != '' ||
      entries is! List ||
      !_bootstrapStrings(codes) ||
      qolip['required_qolip_count'] is! int ||
      qolip['required_qolip_count'] != entries.length ||
      (codes as List).length != entries.length ||
      entries.any(
        (row) =>
            row is! Map ||
            row['qolip_code'] is! String ||
            (row['qolip_code'] as String).isEmpty ||
            row['color'] is! String,
      )) {
    return null;
  }
  for (var index = 0; index < entries.length; index++) {
    if (entries[index]['qolip_code'] != codes[index]) return null;
  }
  return AdminProductionMapQolipValidation.fromJson(
    qolip.cast<String, dynamic>(),
  );
}

extension MobileApiAdminOrderScanBootstrap on MobileApi {
  /// null means the old server has no aggregate route. Domain errors never
  /// fall back through the older, more broadly scoped readers.
  Future<AdminOrderScanBootstrap?> adminOrderScanBootstrap({
    required String apparatus,
    required String orderId,
    List<String> materialBarcodes = const [],
    bool includeSections = true,
    bool includeContext = false,
    String qrPayload = '',
  }) async {
    final station = _requireCanonicalApparatusId(apparatus);
    final order = orderId.trim();
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-scan-bootstrap',
        ).replace(
          queryParameters: {
            'apparatus': station,
            'order_id': order,
            if (!includeSections) 'include_sections': 'false',
            if (includeContext) 'include_context': 'true',
            if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
            if (materialBarcodes.isNotEmpty)
              'material_barcodes': materialBarcodes.join(','),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if ((response.statusCode == 404 || response.statusCode == 405) &&
        response.body.trim().isEmpty) {
      return null;
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'order_scan_bootstrap_failed',
      );
    }
    return AdminOrderScanBootstrap.fromJson(
      await decodeJsonMapPayload(response.body),
      apparatus: station,
      orderId: order,
      qrPayload: qrPayload.trim(),
    );
  }
}
