part of '../mobile_api.dart';

extension MobileApiOrderImages on MobileApi {
  String get orderImageAccountScope => jsonEncode([
        MobileApi.baseUrl,
        AppSession.instance.profile?.role.name,
        AppSession.instance.profile?.ref,
      ]);

  String get orderImageCacheScope => jsonEncode([
        orderImageAccountScope,
        AppSession.instance.token,
      ]);

  String adminProductionMapOrderImageUrl(String orderId,
          {String imageId = ''}) =>
      Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-image/view')
          .replace(queryParameters: {
        'order_id': orderId.trim(),
        if (imageId.trim().isNotEmpty) 'image_id': imageId.trim(),
      }).toString();

  Uri orderImageRequestUri(String imageUrl, {bool thumbnail = false}) {
    final uri = Uri.parse(calculateOrderImageUrl(imageUrl));
    if (uri.origin != Uri.parse(MobileApi.baseUrl).origin ||
        !(uri.path.endsWith('/calculate/orders/image/view') ||
            uri.path.endsWith('/production-maps/order-image/view'))) {
      return uri;
    }
    final query = Map<String, String>.from(uri.queryParameters)
      ..remove('variant');
    if (thumbnail) query['variant'] = 'thumb-v1';
    return uri.replace(queryParameters: query);
  }

  String _orderImageCacheKey(Uri uri) =>
      jsonEncode([orderImageCacheScope, uri.toString()]);

  bool _orderImageIsImmutable(Uri uri) =>
      uri.origin == Uri.parse(MobileApi.baseUrl).origin &&
      (uri.queryParameters['id']?.isNotEmpty == true ||
          uri.queryParameters['image_id']?.isNotEmpty == true);

  /// Reads an already-authorized, fresh in-memory image for immediate display.
  /// Uses exactly the same account/session/version/variant key as normal load.
  Uint8List? peekCachedOrderImageBytes(String imageUrl,
      {bool thumbnail = false}) {
    if (imageUrl.trim().isEmpty || AppSession.instance.isTestModeSession) {
      return null;
    }
    final uri = orderImageRequestUri(imageUrl, thumbnail: thumbnail);
    if (uri.origin == Uri.parse(MobileApi.baseUrl).origin &&
        (AppSession.instance.token?.isNotEmpty != true)) {
      return null;
    }
    final scope = orderImageAccountScope;
    return OrderImageCache.instance.peek(
      key: _orderImageCacheKey(uri),
      immutable: _orderImageIsImmutable(uri),
      isCurrent: () => scope == orderImageAccountScope,
    );
  }

  Future<Uint8List?> cachedOrderImageBytes(String imageUrl,
      {bool thumbnail = false}) async {
    if (imageUrl.trim().isEmpty ||
        await TestModeController.instance.isEnabled()) {
      return null;
    }
    final uri = orderImageRequestUri(imageUrl, thumbnail: thumbnail);
    final internal = uri.origin == Uri.parse(MobileApi.baseUrl).origin;
    if (internal) requireToken();
    final scope = orderImageAccountScope;
    return OrderImageCache.instance.load(
      key: _orderImageCacheKey(uri),
      thumbnail: thumbnail,
      immutable: _orderImageIsImmutable(uri),
      isCurrent: () => scope == orderImageAccountScope,
      fetch: (etag) async {
        final conditional = {if (etag != null) 'If-None-Match': etag};
        final response = internal
            ? await _sendAuthorized(() => _get(uri,
                headers: {..._headers(requireToken()), ...conditional}))
            : await _httpClient
                .get(uri, headers: conditional)
                .timeout(MobileApi._requestTimeout);
        if (response.statusCode == 404 &&
            response.bodyBytes.isEmpty &&
            internal) {
          throw const MobileApiException(
              code: 'production_map_order_image_route_missing',
              message: 'Rasm xizmati topilmadi — server yangilanmagan');
        }
        return response;
      },
    );
  }
}
