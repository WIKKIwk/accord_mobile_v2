part of '../mobile_api.dart';

extension MobileApiAdminOrderSummary on MobileApi {
  Future<CalculateOrderTemplate> adminProductionMapOrderSummary(
    String orderId,
  ) async {
    final id = orderId.trim();
    if (await TestModeController.instance.isEnabled()) {
      final matches = _testModeCalculateOrderTemplates
          .where((template) => template.sourceMapId.trim() == id)
          .toList(growable: false);
      if (matches.length == 1) return matches.single;
      throw const MobileApiException(
        code: 'order_summary_missing',
        message: 'Buyurtmaning saqlangan hisob-kitobi topilmadi',
        statusCode: 404,
      );
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-summary',
          ).replace(queryParameters: {'id': id}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_summary');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['template'] is! Map) {
      throw const FormatException('Invalid order summary');
    }
    final template = CalculateOrderTemplate.fromJson(
      (payload['template'] as Map).cast<String, dynamic>(),
    );
    if (template.sourceMapId.trim() != id) {
      throw const FormatException('Order summary identity mismatch');
    }
    return template;
  }
}
