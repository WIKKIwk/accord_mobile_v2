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
      throw _openedOrderEditException(response);
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
      throw _openedOrderEditException(response);
    }
    return OpenedOrderEditSource.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }
}

MobileApiException _openedOrderEditException(http.Response response) {
  // Only the endpoint's explicit, operator-facing diagnostic contract may
  // bypass the generic 5xx fallback. Never display raw database/proxy bodies.
  try {
    final payload = jsonDecode(response.body);
    if (payload is Map &&
        payload['error'] is String &&
        payload['message'] is String &&
        (payload['error'] as String).startsWith('order_edit_') &&
        !const {401, 403}.contains(response.statusCode)) {
      final message = (payload['message'] as String).trim();
      if (message.isNotEmpty && !message.contains(RegExp(r'[<>]'))) {
        return MobileApiException(
          code: payload['error'] as String,
          message: message,
          statusCode: response.statusCode,
        );
      }
    }
  } on FormatException {
    // Older servers and gateways need the existing fallback below.
  }
  final error = _adminProductionMapException(response, 'order_edit');
  // This endpoint returns user-facing business reasons in `error`, not just
  // machine codes. Preserve them without exposing auth or server failures.
  final reason = error.code.trim();
  if (const {400, 404, 409, 422}.contains(response.statusCode) &&
      error.message ==
          _adminProductionMapUnknownErrorMessage(
            code: error.code,
            fallbackCode: 'order_edit',
            statusCode: response.statusCode,
          ) &&
      reason.contains(RegExp(r'\s')) &&
      !reason.contains(RegExp(r'[<>]'))) {
    return MobileApiException(
      code: error.code,
      message: reason,
      statusCode: response.statusCode,
    );
  }
  return error;
}
