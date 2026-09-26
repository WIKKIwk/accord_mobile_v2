part of '../mobile_api.dart';

extension MobileApiQolipOrderProducts on MobileApi {
  Future<Map<String, QolipProduct?>> qolipOrderProducts(
      List<String> orderIds) async {
    if (orderIds.isEmpty) return {};
    final ids = orderIds.map((id) => id.trim()).toList(growable: false);
    if (ids.length > 50 || ids.any((id) => id.isEmpty)) {
      throw ArgumentError('Expected at most 50 non-empty order IDs');
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/order-products'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'order_ids': ids}),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'qolip_order_products_failed');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final result = <String, QolipProduct?>{};
    for (final raw in payload['orders'] as List? ?? const []) {
      if (raw is! Map) continue;
      final product = raw['product'];
      result[raw['order_id'].toString()] = product is Map
          ? QolipProduct.fromJson(product.cast<String, dynamic>())
          : null;
    }
    // A truncated response must never make missing tasks look completed.
    if (ids.any((id) => !result.containsKey(id))) {
      throw const FormatException('Incomplete Qolip readiness response');
    }
    return result;
  }
}
