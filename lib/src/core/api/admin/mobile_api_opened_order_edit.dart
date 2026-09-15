part of '../mobile_api.dart';

/// Keep the server snapshot losslessly for optimistic concurrency. Rebuilding
/// it through UI models would discard fields unknown to older mobile clients.
class OpenedOrderEditSource {
  OpenedOrderEditSource.fromJson(Map<String, dynamic> json)
      : original = json,
        template = CalculateOrderTemplate.fromJson(
          (json['template'] as Map).cast<String, dynamic>(),
        );

  final Map<String, dynamic> original;
  final CalculateOrderTemplate template;
  String get orderId => (original['map'] as Map)['id'] as String;
}

extension MobileApiOpenedOrderEdit on MobileApi {
  Future<OpenedOrderEditSource> adminOpenedOrderEditSource(
      String orderId) async {
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_edit',
        message: 'Order tahriri uchun server tekshiruvi kerak',
      );
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-edit')
              .replace(queryParameters: {'id': orderId}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_edit');
    }
    return OpenedOrderEditSource.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<OpenedOrderEditSource> adminSaveOpenedOrderEdit({
    required OpenedOrderEditSource source,
    required CalculateOrderTemplate template,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_edit',
        message: 'Order tahriri uchun server tekshiruvi kerak',
      );
    }
    final response = await _sendAuthorized(() => _put(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-edit')
              .replace(queryParameters: {'id': source.orderId}),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(
              {'original': source.original, 'template': template.toJson()}),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_edit');
    }
    return OpenedOrderEditSource.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }
}
