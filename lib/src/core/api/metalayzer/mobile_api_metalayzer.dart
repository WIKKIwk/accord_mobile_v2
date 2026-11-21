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

  factory MetalayzerMaterial.fromJson(Map<String, dynamic> json,
      {bool allowZero = false}) {
    final barcode = json['barcode'];
    final flag = json['is_metalayzer'];
    final qty = json['qty'];
    if (barcode is! String ||
        barcode.trim().isEmpty ||
        flag is! bool ||
        qty is! num ||
        !qty.isFinite ||
        (allowZero ? qty < 0 : qty <= 0)) {
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

class MetalayzerMaterialsPage {
  const MetalayzerMaterialsPage(
      {required this.items, required this.nextCursor});

  final List<MetalayzerMaterial> items;
  final String? nextCursor;
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

  Future<MetalayzerMaterialsPage> metalayzerMaterials({String? cursor}) async {
    final scope = metalayzerScope();
    final data = await _metalayzerJsonRequest(scope, () {
      final uri =
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/metalayzer/materials')
              .replace(queryParameters: {
        'limit': '50',
        if (cursor != null) 'cursor': cursor,
      });
      return _get(uri, headers: _headers(requireToken()));
    },
        failureCode: 'metalayzer_list_failed',
        failureMessage: 'Ro‘yxatni yuklab bo‘lmadi');

    final rawItems = data['items'];
    final nextCursor = data['next_cursor'];
    const invalidPage = FormatException('Xomashyo ro‘yxati tasdiqlanmadi');
    if (rawItems is! List ||
        !data.containsKey('next_cursor') ||
        (nextCursor != null &&
            (nextCursor is! String ||
                nextCursor.trim().isEmpty ||
                nextCursor == cursor ||
                rawItems.isEmpty))) {
      throw invalidPage;
    }
    final items = <MetalayzerMaterial>[];
    for (final row in rawItems) {
      if (row is! Map<String, dynamic>) throw invalidPage;
      final material = MetalayzerMaterial.fromJson(row, allowZero: true);
      if (!material.isMetalayzer) throw invalidPage;
      items.add(material);
    }
    return MetalayzerMaterialsPage(
        items: items, nextCursor: nextCursor as String?);
  }

  Future<MetalayzerMaterial> _metalayzerRequest(String barcode,
      {required bool complete}) async {
    final scope = metalayzerScope();
    final code = barcode.trim();
    if (code.isEmpty) {
      throw const FormatException('Xomashyo QR kodini kiriting');
    }
    final data = await _metalayzerJsonRequest(scope, () {
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
    final material = MetalayzerMaterial.fromJson(data);
    if (material.barcode.trim().toLowerCase() != code.toLowerCase() ||
        (complete && !material.isMetalayzer)) {
      throw const FormatException('Metalayzer natijasi tasdiqlanmadi');
    }
    return material;
  }

  Future<Map<String, dynamic>> _metalayzerJsonRequest(
    String scope,
    Future<http.Response> Function() send, {
    String failureCode = 'metalayzer_request_failed',
    String failureMessage = 'Xomashyoni tekshiring yoki qayta urinib ko‘ring',
  }) async {
    final response = await _sendAuthorized(() {
      if (metalayzerScope() != scope) throw StateError('Akkaunt o‘zgargan');
      return send();
    });
    if (metalayzerScope() != scope) throw StateError('Akkaunt o‘zgargan');
    Object? data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      data = null;
    }
    if (response.statusCode != 200 || data is! Map<String, dynamic>) {
      final code = data is Map ? data['code'] : null;
      final message = data is Map ? data['error'] : null;
      throw MobileApiException(
        code: code is String ? code : failureCode,
        statusCode: response.statusCode,
        message: message is String ? message : failureMessage,
      );
    }
    return data;
  }
}
