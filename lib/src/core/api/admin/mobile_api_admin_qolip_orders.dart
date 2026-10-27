part of '../mobile_api.dart';

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

class AdminProductionMapRequiredQolip {
  const AdminProductionMapRequiredQolip({
    required this.qolipCode,
    required this.color,
    this.isInUse = false,
    this.qolipSetId = '',
    this.isExtension = false,
    this.ready = false,
    this.blockingReasonCode = '',
  });

  final String qolipCode;
  final String color;
  final bool isInUse;
  final String qolipSetId;
  final bool isExtension;
  final bool ready;
  final String blockingReasonCode;
  String get setId => qolipSetId.trim().isEmpty ? 'legacy' : qolipSetId.trim();

  factory AdminProductionMapRequiredQolip.fromJson(Map<String, dynamic> json) {
    return AdminProductionMapRequiredQolip(
      qolipCode: json['qolip_code']?.toString().trim() ?? '',
      color: json['color']?.toString().trim() ?? '',
      isInUse: json['in_use'] == true,
      qolipSetId: json['qolip_set_id']?.toString().trim() ?? '',
      isExtension: json['is_extension'] == true,
      ready: json['ready'] == true,
      blockingReasonCode: json['blocking_reason_code']?.toString().trim() ?? '',
    );
  }
}

class AdminProductionMapQolipValidation {
  const AdminProductionMapQolipValidation({
    required this.qolipCode,
    this.requiredQolips = const [],
    this.automaticConfirmationEnabled = false,
    this.policyRevision = 0,
    this.blockingReasonCode = '',
    this.sets = const [],
  });

  final String qolipCode;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final bool automaticConfirmationEnabled;
  final int policyRevision;
  final String blockingReasonCode;
  final List<AdminQolipAutomaticSet> sets;

  List<String> get requiredQolipCodes => [
        for (final qolip in requiredQolips) qolip.qolipCode,
      ];

  factory AdminProductionMapQolipValidation.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawAutomatic = json['automatic_confirmation_enabled'];
    if (rawAutomatic != null && rawAutomatic is! bool) {
      throw _invalidQolipAutomaticConfirmation();
    }
    final automatic = rawAutomatic == true;
    final rawRevision = json['policy_revision'];
    if ((rawRevision != null && (rawRevision is! int || rawRevision < 0)) ||
        (automatic &&
            (rawRevision is! int ||
                json['blocking_reason_code'] is! String ||
                json['sets'] is! List ||
                json['required_qolips'] is! List ||
                json['required_qolip_count'] is! int ||
                json['required_qolip_codes'] is! List ||
                json['qolip_code'] != ''))) {
      throw _invalidQolipAutomaticConfirmation();
    }
    final requiredQolips = <AdminProductionMapRequiredQolip>[];
    for (final rawQolip in json['required_qolips'] as List? ?? const []) {
      if (rawQolip is! Map) {
        if (automatic) throw _invalidQolipAutomaticConfirmation();
        continue;
      }
      if (automatic &&
          (rawQolip['qolip_code'] is! String ||
              (rawQolip['qolip_code'] as String).trim().isEmpty ||
              rawQolip['qolip_set_id'] is! String ||
              (rawQolip['qolip_set_id'] as String).trim().isEmpty ||
              rawQolip['color'] is! String ||
              rawQolip['is_extension'] is! bool ||
              rawQolip['ready'] is! bool ||
              rawQolip['blocking_reason_code'] is! String ||
              (rawQolip['ready'] == true &&
                  (rawQolip['blocking_reason_code'] as String).isNotEmpty))) {
        throw _invalidQolipAutomaticConfirmation();
      }
      final qolip = AdminProductionMapRequiredQolip.fromJson(
        rawQolip.cast<String, dynamic>(),
      );
      if (qolip.qolipCode.isNotEmpty) {
        requiredQolips.add(qolip);
      }
    }
    final sets = <AdminQolipAutomaticSet>[];
    if (automatic) {
      final codes = json['required_qolip_codes'] as List;
      if (json['required_qolip_count'] != requiredQolips.length ||
          codes.length != requiredQolips.length) {
        throw _invalidQolipAutomaticConfirmation();
      }
      for (var index = 0; index < codes.length; index++) {
        if (codes[index] is! String ||
            codes[index] != requiredQolips[index].qolipCode) {
          throw _invalidQolipAutomaticConfirmation();
        }
      }
      final ids = <String>{};
      final moldCodes = <String>{};
      for (final mold in requiredQolips) {
        if (!moldCodes.add(mold.qolipCode.toLowerCase())) {
          throw _invalidQolipAutomaticConfirmation();
        }
      }
      for (final raw in json['sets'] as List) {
        if (raw is! Map) throw _invalidQolipAutomaticConfirmation();
        final set =
            AdminQolipAutomaticSet.fromJson(raw.cast<String, dynamic>());
        if (!ids.add(set.setId)) throw _invalidQolipAutomaticConfirmation();
        if (set.ready &&
            (!requiredQolips.any(
                    (mold) => !mold.isExtension && mold.setId == set.setId) ||
                requiredQolips.any((mold) =>
                    (mold.isExtension || mold.setId == set.setId) &&
                    !mold.ready))) {
          throw _invalidQolipAutomaticConfirmation();
        }
        sets.add(set);
      }
      if ((requiredQolips.isEmpty || sets.isEmpty) &&
          (json['blocking_reason_code'] as String).isEmpty) {
        throw _invalidQolipAutomaticConfirmation();
      }
      if ((json['blocking_reason_code'] as String).isNotEmpty &&
          sets.any((set) => set.ready)) {
        throw _invalidQolipAutomaticConfirmation();
      }
    }
    return AdminProductionMapQolipValidation(
      qolipCode: json['qolip_code']?.toString().trim() ?? '',
      requiredQolips: requiredQolips,
      automaticConfirmationEnabled: automatic,
      policyRevision: rawRevision is int ? rawRevision : 0,
      blockingReasonCode: json['blocking_reason_code']?.toString().trim() ?? '',
      sets: sets,
    );
  }
}

extension MobileApiAdminQolipOrders on MobileApi {
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
    bool automaticConfirmation = false,
  }) {
    return adminValidateProductionMapQolipDetails(
      apparatus: apparatus,
      orderId: orderId,
      qolipCode: '',
      automaticConfirmation: automaticConfirmation,
    );
  }

  Future<AdminProductionMapQolipValidation>
      adminValidateProductionMapQolipDetails({
    required String apparatus,
    required String orderId,
    required String qolipCode,
    bool automaticConfirmation = false,
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
                  qolipSetId: product.setId,
                  isExtension: product.isExtension,
                ),
          ],
        );
      }
      final requirements = await adminProductionMapQolipRequirements(
          apparatus: normalizedApparatus, orderId: orderId);
      final matches = requirements.requiredQolips.where((mold) =>
          mold.qolipCode.toLowerCase() == qolipCode.trim().toLowerCase());
      if (matches.isEmpty)
        throw const MobileApiException(
            code: 'qolip_code_mismatch', message: 'qolip_code_mismatch');
      final selected = matches.first;
      return AdminProductionMapQolipValidation(
          qolipCode: selected.qolipCode,
          requiredQolips: requirements.requiredQolips
              .where((mold) =>
                  selected.isExtension ||
                  mold.isExtension ||
                  mold.setId == selected.setId)
              .toList(growable: false));
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-validate'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': orderId.trim(),
          'qolip_code': qolipCode.trim(),
          if (automaticConfirmation && qolipCode.trim().isEmpty)
            'automatic_confirmation': true,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'qolip_code_not_found');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawQolip = payload['qolip'];
    if (rawQolip is Map) {
      if (rawQolip['automatic_confirmation_enabled'] == true &&
          (!automaticConfirmation || payload['ok'] != true)) {
        throw _invalidQolipAutomaticConfirmation();
      }
      return AdminProductionMapQolipValidation.fromJson(
        rawQolip.cast<String, dynamic>(),
      );
    }
    if (automaticConfirmation) throw _invalidQolipAutomaticConfirmation();
    return AdminProductionMapQolipValidation(qolipCode: qolipCode.trim());
  }
}
