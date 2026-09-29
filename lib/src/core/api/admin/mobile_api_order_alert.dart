part of '../mobile_api.dart';

enum OrderAlertKind { rawMaterial, qolip }

extension MobileApiOrderAlert on MobileApi {
  Future<void> sendOrderAlert({
    required String orderId,
    required String apparatus,
    required OrderAlertKind kind,
    required String requestId,
  }) async {
    if (AppSession.instance.isTestModeSession ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
        code: 'order_alert_test_mode',
        message: 'Sinov rejimida xabar yuborilmaydi',
      );
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-alert'),
          headers: {
            ..._headers(requireToken()),
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'order_id': orderId,
            'apparatus': apparatus,
            'kind':
                kind == OrderAlertKind.rawMaterial ? 'raw_material' : 'qolip',
            'request_id': requestId,
          }),
        ));
    Map<String, dynamic> payload = const {};
    try {
      payload = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (response.statusCode == 200 && payload['ok'] == true) return;
    final code = payload['error']?.toString() ?? 'order_alert_send_failed';
    throw MobileApiException(
      code: code,
      message: code == 'order_alert_no_recipients'
          ? 'Xabar yuboriladigan faol xodim topilmadi'
          : 'Xabar yuborilmadi. Qayta urinib ko‘ring',
      statusCode: response.statusCode,
    );
  }
}
