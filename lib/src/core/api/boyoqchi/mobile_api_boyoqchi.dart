part of '../mobile_api.dart';

final List<ReturnedPaintRequest> _testModeReturnedPaintRequests = [];

extension MobileApiBoyoqchi on MobileApi {
  Future<ReturnedPaintRequest> submitReturnedPaint(
    ReturnedPaintSubmission input,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final profile = AppSession.instance.profile;
      final request = ReturnedPaintRequest(
        id: 'returned-paint-${DateTime.now().microsecondsSinceEpoch}',
        orderId: input.orderId,
        orderCode: input.orderCode,
        orderName: input.orderName,
        apparatus: input.apparatus,
        senderRole: profile?.role ?? UserRole.aparatchi,
        senderRef: profile?.ref ?? 'test-user',
        senderDisplayName: profile?.displayName ?? 'Test foydalanuvchi',
        items: input.items,
        createdAt: DateTime.now(),
      );
      _testModeReturnedPaintRequests.insert(0, request);
      return request;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/returned-paint/requests'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _returnedPaintException(
        response,
        code: 'returned_paint_submit_failed',
        message: 'Qaytarilgan bo‘yoq ma’lumoti yuborilmadi',
      );
    }
    return ReturnedPaintRequest.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<ReturnedPaintRequestPage> boyoqchiReturnedPaintRequests({
    int limit = 20,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final items = _testModeReturnedPaintRequests
          .skip(offset)
          .take(limit)
          .toList(growable: false);
      return ReturnedPaintRequestPage(
        items: items,
        hasMore: _testModeReturnedPaintRequests.length > offset + limit,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/returned-paint/requests')
            .replace(
          queryParameters: {
            'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _returnedPaintException(
        response,
        code: 'returned_paint_load_failed',
        message: 'Qaytarilgan bo‘yoq ma’lumotlari yuklanmadi',
      );
    }
    return ReturnedPaintRequestPage.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }
}

MobileApiException _returnedPaintException(
  http.Response response, {
  required String code,
  required String message,
}) {
  return MobileApiException(
    code: code,
    message: message,
    statusCode: response.statusCode,
  );
}
