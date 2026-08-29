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
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-validate'),
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

}
