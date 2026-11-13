part of '../mobile_api.dart';

class MetalayzerMaterial {
  const MetalayzerMaterial({
    required this.barcode,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.qty,
    required this.uom,
    required this.isMetalayzer,
  });

  final String barcode, itemCode, itemName, warehouse, uom;
  final double qty;
  final bool isMetalayzer;

  factory MetalayzerMaterial.fromJson(Map<String, dynamic> json) {
    final barcode = json['barcode'];
    final flag = json['is_metalayzer'];
    final qty = json['qty'];
    if (barcode is! String ||
        barcode.trim().isEmpty ||
        flag is! bool ||
        qty is! num ||
        !qty.isFinite ||
        qty <= 0) {
      throw const FormatException('Xomashyo ma’lumotlari olinmadi');
    }
    return MetalayzerMaterial(
      barcode: barcode,
      itemCode: json['item_code'] as String? ?? '',
      itemName: json['item_name'] as String? ?? '',
      warehouse: json['warehouse'] as String? ?? '',
      qty: qty.toDouble(),
      uom: json['uom'] as String? ?? '',
      isMetalayzer: flag,
    );
  }
}

extension MobileApiMetalayzer on MobileApi {
  String metalayzerScope() {
    final session = AppSession.instance;
    if (!session.isLoggedIn ||
        session.isTestModeSession ||
        session.profile?.role != UserRole.metalayzer ||
        !session.can('metalayzer.access')) {
      throw StateError('Metalayzer huquqi kerak');
    }
    return currentSessionReadScope();
  }

  Future<MetalayzerMaterial> metalayzerMaterial(String barcode) =>
      _metalayzerRequest(barcode, complete: false);

  Future<MetalayzerMaterial> metalayzerComplete(String barcode) =>
      _metalayzerRequest(barcode, complete: true);

  Future<MetalayzerMaterial> _metalayzerRequest(String barcode,
      {required bool complete}) async {
    final scope = metalayzerScope();
    final code = barcode.trim();
    if (code.isEmpty) {
      throw const FormatException('Xomashyo QR kodini kiriting');
    }
    final response = await _sendAuthorized(() {
      if (metalayzerScope() != scope) throw StateError('Akkaunt o‘zgargan');
      final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/metalayzer/'
          '${complete ? 'complete' : 'material'}');
      return complete
          ? _post(uri,
              headers: _headers(requireToken())
                ..['Content-Type'] = 'application/json',
              body: jsonEncode({'barcode': code}))
          : _get(uri.replace(queryParameters: {'barcode': code}),
              headers: _headers(requireToken()));
    });
    if (metalayzerScope() != scope) throw StateError('Akkaunt o‘zgargan');
    Map<String, dynamic>? data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    if (response.statusCode != 200 || data == null) {
      throw MobileApiException(
        code: data?['code'] as String? ?? 'metalayzer_request_failed',
        statusCode: response.statusCode,
        message: data?['error'] as String? ??
            'Xomashyoni tekshiring yoki qayta urinib ko‘ring',
      );
    }
    final material = MetalayzerMaterial.fromJson(data);
    if (material.barcode.trim().toLowerCase() != code.toLowerCase() ||
        (complete && !material.isMetalayzer)) {
      throw const FormatException('Metalayzer natijasi tasdiqlanmadi');
    }
    return material;
  }
}
