part of '../mobile_api.dart';

/// Short-lived detail data. This is never a full live/delta baseline.
class AdminOrderScanBootstrap {
  const AdminOrderScanBootstrap({
    required this.controlState,
    required this.scope,
    this.materials,
    this.qolips,
  });

  final AdminPrintPreflightControlState controlState;
  final String scope;
  final AdminRawMaterialStartRequirements? materials;
  final AdminProductionMapQolipValidation? qolips;

  factory AdminOrderScanBootstrap.fromJson(
    Map<String, dynamic> json, {
    required String apparatus,
    required String orderId,
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
    );
  }
}

bool _bootstrapStrings(Object? raw) =>
    raw is List && raw.every((value) => value is String && value.isNotEmpty);

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
    );
  }
}
