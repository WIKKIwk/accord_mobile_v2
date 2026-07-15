part of '../mobile_api.dart';

final List<ReturnedPaintRequest> _testModeReturnedPaintRequests = [];
final Map<String, ReturnedPaintImage> _testModeReturnedPaintImages = {};
int _testModeReturnedPaintImageSequence = 0;

extension MobileApiBoyoqchi on MobileApi {
  Future<ReturnedPaintRequest> submitReturnedPaint(
    ReturnedPaintSubmission input,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final profile = AppSession.instance.profile;
      final image = _testModeReturnedPaintImages[input.imageId.trim()];
      final waiting = input.items.isEmpty && image != null;
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
        status: waiting
            ? ReturnedPaintStatus.waitingForBoyoqchiInput
            : ReturnedPaintStatus.completed,
        image: image,
        calculation: waiting
            ? null
            : const ReturnedPaintCalculation(
                rasxotMixTotal: '0',
                astatkaMixTotal: '0',
                rasxotAlcohol: '0',
                astatkaAlcohol: '0',
                finalUsedAlcohol: '0',
                rasxotPurePaint: '0',
                astatkaPurePaint: '0',
                finalUsedPaint: '0',
              ),
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

  Future<ReturnedPaintImage> uploadReturnedPaintImage({
    required String orderId,
    required String apparatus,
    required List<int> bytes,
    required String filename,
    required String mime,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final id =
          'returned-paint-image-${++_testModeReturnedPaintImageSequence}';
      final image = ReturnedPaintImage(
        imageId: id,
        imageName: filename,
        imageMime: mime,
        imageSizeBytes: bytes.length,
        imageUrl: '',
      );
      _testModeReturnedPaintImages[id] = image;
      return image;
    }
    final uri = Uri.parse(
      '${MobileApi.baseUrl}/v1/mobile/returned-paint/images',
    ).replace(
      queryParameters: {
        'order_id': orderId.trim(),
        'apparatus': apparatus.trim(),
      },
    );
    final response = await _sendAuthorized(
      () => _post(
        uri,
        headers: _headers(requireToken())
          ..['Content-Type'] = mime
          ..['x-file-name'] = _returnedPaintHeaderFileName(filename),
        body: bytes,
      ),
    );
    if (response.statusCode != 200) {
      throw _returnedPaintException(
        response,
        code: 'returned_paint_image_upload_failed',
        message: 'Qaytarilgan bo‘yoq rasmi yuklanmadi',
      );
    }
    final payload = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    final raw = payload['image'];
    return ReturnedPaintImage.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{},
    );
  }

  Future<void> deleteReturnedPaintImage(String imageId) async {
    if (await TestModeController.instance.isEnabled()) {
      _testModeReturnedPaintImages.remove(imageId.trim());
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/returned-paint/images')
            .replace(queryParameters: {'id': imageId.trim()}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _returnedPaintException(
        response,
        code: 'returned_paint_image_delete_failed',
        message: 'Qaytarilgan bo‘yoq rasmi olib tashlanmadi',
      );
    }
  }

  Future<ReturnedPaintRequest> completeReturnedPaint(
    ReturnedPaintCompleteSubmission input,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeReturnedPaintRequests.indexWhere(
        (request) => request.id == input.requestId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'returned_paint_not_found',
          message: 'Qaytarilgan bo‘yoq hisoboti topilmadi',
        );
      }
      final existing = _testModeReturnedPaintRequests[index];
      if (!existing.waitingForBoyoqchiInput) return existing;
      const calculation = ReturnedPaintCalculation(
        rasxotMixTotal: '0',
        astatkaMixTotal: '0',
        rasxotAlcohol: '0',
        astatkaAlcohol: '0',
        finalUsedAlcohol: '0',
        rasxotPurePaint: '0',
        astatkaPurePaint: '0',
        finalUsedPaint: '0',
      );
      final completed = existing.copyWith(
        items: input.items,
        status: ReturnedPaintStatus.completed,
        calculation: calculation,
      );
      _testModeReturnedPaintRequests[index] = completed;
      return completed;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/returned-paint/requests/complete',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _returnedPaintException(
        response,
        code: 'returned_paint_complete_failed',
        message: 'Qaytarilgan bo‘yoq hisoboti saqlanmadi',
      );
    }
    return ReturnedPaintRequest.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  String returnedPaintImageUrl(String imageUrl) {
    final value = imageUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${MobileApi.baseUrl}$value';
    return value;
  }

  Map<String, String> returnedPaintImageHeaders() => _headers(requireToken());

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

String _returnedPaintHeaderFileName(String value) {
  final cleaned = value
      .trim()
      .split('')
      .where(
        (character) => RegExp(r'[A-Za-z0-9._ -]').hasMatch(character),
      )
      .join();
  return cleaned.isEmpty ? 'qaytarilgan-boyoq.jpg' : cleaned;
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
