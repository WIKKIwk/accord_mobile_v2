part of '../mobile_api.dart';

extension MobileApiMaterialLink on MobileApi {
  Future<MaterialLinkOverview> materialLinkRequests({
    required String orderId,
    required String apparatus,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return MaterialLinkOverview.fromJson(const {});
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/material-link-requests')
              .replace(queryParameters: {
            'order_id': orderId,
            'apparatus': apparatus
          }),
          headers: _headers(requireToken()),
        ));
    return MaterialLinkOverview.fromJson(await _materialLinkJson(response));
  }

  Future<MaterialLinkRequest> materialLinkRequest(String requestId) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/material-link-requests')
              .replace(queryParameters: {'request_id': requestId}),
          headers: _headers(requireToken()),
        ));
    final json = await _materialLinkJson(response);
    return MaterialLinkRequest.fromJson(
        Map<String, dynamic>.from(json['request'] as Map));
  }

  Future<void> createMaterialLinkRequests({
    required String orderId,
    required String apparatus,
  }) async {
    await _materialLinkCommand(
        {'action': 'create', 'order_id': orderId, 'apparatus': apparatus});
  }

  Future<MaterialLinkRequest> decideMaterialLinkRequest({
    required String requestId,
    required String action,
    List<String> barcodes = const [],
  }) async {
    if (action == 'approve' && barcodes.isEmpty) {
      throw const MobileApiException(
          code: 'material_link_selection_required',
          message: 'Ulash uchun rulon tanlang');
    }
    final json = await _materialLinkCommand({
      'request_id': requestId,
      'action': action,
      'barcodes': barcodes,
    });
    return MaterialLinkRequest.fromJson(
        Map<String, dynamic>.from(json['request'] as Map));
  }

  Future<Map<String, dynamic>> _materialLinkCommand(
      Map<String, dynamic> body) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/material-link-requests'),
          headers: {
            ..._headers(requireToken()),
            'Content-Type': 'application/json'
          },
          body: jsonEncode(body),
        ));
    return _materialLinkJson(response);
  }

  Future<Map<String, dynamic>> _materialLinkJson(http.Response response) async {
    if (response.statusCode != 200) {
      String code = '';
      try {
        code = (jsonDecode(response.body) as Map)['error']?.toString() ?? '';
      } catch (_) {}
      final message = switch (code) {
        'material_link_no_candidates' =>
          'Bu apparat state’ida orderga ulash mumkin bo‘lgan rulon qolmagan',
        'material_link_selection_required' => 'Ulash uchun rulonlarni tanlang',
        'material_link_not_found' => 'So‘rov topilmadi',
        'raw_material_order_not_active' => 'Order faol emas',
        _ when response.statusCode == 403 =>
          'Bu so‘rov bo‘yicha amal qilishga ruxsat yo‘q',
        _ => 'So‘rov holatini yangilab bo‘lmadi. Qayta urinib ko‘ring',
      };
      throw MobileApiException(
          code: code, message: message, statusCode: response.statusCode);
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
