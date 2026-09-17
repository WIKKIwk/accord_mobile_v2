part of '../mobile_api.dart';

class AdminPrintPreflightResponse {
  const AdminPrintPreflightResponse({required this.hold});

  final AdminPrintPreflightHold hold;

  factory AdminPrintPreflightResponse.fromJson(Map<String, dynamic> json) {
    final rawHold = json['hold'];
    final hold = AdminPrintPreflightHold.tryFromJson(rawHold);
    if (hold == null) {
      throw const MobileApiException(
        code: 'print_preflight_invalid_response',
        message: 'Rang sinovi javobi noto‘g‘ri',
      );
    }
    return AdminPrintPreflightResponse(hold: hold);
  }
}

extension MobileApiAdminPrintPreflight on MobileApi {
  Future<AdminPrintPreflightResponse> adminPrintPreflight({
    required String apparatus,
    required String orderId,
    required String action,
    String holdId = '',
    String idempotencyKey = '',
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/print-preflight',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus,
          'order_id': orderId,
          'action': action,
          if (holdId.trim().isNotEmpty) 'hold_id': holdId.trim(),
          if (idempotencyKey.trim().isNotEmpty)
            'idempotency_key': idempotencyKey.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'print_preflight_not_ready');
    }
    return AdminPrintPreflightResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
