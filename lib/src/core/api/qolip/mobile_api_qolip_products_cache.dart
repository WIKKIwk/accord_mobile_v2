part of '../mobile_api.dart';

// Only the complete Qoliplar catalog is retained. Search/QR lookups cannot
// replace it with a partial result. Only in-flight requests are zone scoped;
// Flutter frames can run in a different zone from the initial navigation call.
class _QolipProductsCache {
  _QolipProductsCache(this.scope);

  final Object scope;
  List<QolipProduct>? products;
  String? etag;
  DateTime? storedAt;
  final inFlight = Expando<Future<List<QolipProduct>>>();
  int requestGeneration = 0;

  List<QolipProduct>? get recentProducts {
    final age = storedAt == null ? null : DateTime.now().difference(storedAt!);
    return age != null &&
            age >= Duration.zero &&
            age < const Duration(minutes: 2)
        ? products
        : null;
  }
}

extension MobileApiQolipProductsCache on MobileApi {
  Object get _qolipProductsAccount => (
        MobileApi.baseUrl,
        AppSession.instance.profile?.ref,
        AppSession.instance.profile?.role,
      );

  Object get _qolipProductsScope => (
        MobileApi.baseUrl,
        AppSession.instance.token,
        AppSession.instance.profile,
        AppSession.instance.revision.value,
        // Every server mutation advances this epoch before AND after sending.
        // In-flight reads from before a write must never repopulate the cache.
        _queueSnapshotReadEpoch,
      );

  _QolipProductsCache get _qolipProductsCache {
    final scope = _qolipProductsScope;
    var cache = _qolipProductsSnapshot;
    if (cache == null || cache.scope != scope) {
      cache = _QolipProductsCache(scope);
      _qolipProductsSnapshot = cache;
    }
    return cache;
  }

  /// A short-lived snapshot for the first frame only. Always revalidate on entry.
  List<QolipProduct>? get cachedQolipProducts {
    if (AppSession.instance.isTestModeSession ||
        !AppSession.instance.isLoggedIn) {
      return null;
    }
    return _qolipProductsCache.recentProducts;
  }

  Future<List<QolipProduct>> _readQolipProducts({
    required String query,
    required int limit,
    required bool withQolipOnly,
  }) {
    final cache = query.trim().isEmpty && limit == 20000 && withQolipOnly
        ? _qolipProductsCache
        : null;
    final existing = cache?.inFlight[Zone.current];
    if (existing != null) return existing;
    late final Future<List<QolipProduct>> pending;
    pending = _fetchQolipProducts(
      query: query,
      limit: limit,
      withQolipOnly: withQolipOnly,
      cache: cache,
    ).whenComplete(() {
      if (cache != null && identical(cache.inFlight[Zone.current], pending)) {
        cache.inFlight[Zone.current] = null;
      }
    });
    cache?.inFlight[Zone.current] = pending;
    return pending;
  }

  Future<List<QolipProduct>> _fetchQolipProducts({
    required String query,
    required int limit,
    required bool withQolipOnly,
    required _QolipProductsCache? cache,
  }) async {
    final previous = cache?.products;
    final previousEtag = cache?.etag;
    final generation = cache == null ? null : ++cache.requestGeneration;
    final scope = _qolipProductsScope;
    final account = _qolipProductsAccount;
    final uri =
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/products').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (limit > 0) 'limit': '$limit',
        if (withQolipOnly) 'with_qolip': 'true',
      },
    );
    try {
      final response = await _sendAuthorized(() {
        if (account != _qolipProductsAccount) {
          throw StateError('Qolip catalog account changed');
        }
        final headers = _headers(requireToken());
        if (previous != null && previousEtag != null) {
          headers['If-None-Match'] = previousEtag;
        }
        return _get(uri, headers: headers);
      });
      final List<QolipProduct> products;
      if (response.statusCode == 304 && previous != null) {
        products = previous;
      } else if (response.statusCode == 200) {
        final data = await decodeJsonMapPayload(response.body);
        final raw = data['products'];
        final parsed = <QolipProduct>[];
        final slice = Stopwatch()..start();
        if (raw is List) {
          for (final item in raw) {
            parsed.add(
                QolipProduct.fromJson((item as Map).cast<String, dynamic>()));
            if (slice.elapsedMicroseconds >= 2000) {
              await Future<void>.delayed(Duration.zero);
              slice.reset();
            }
          }
        }
        products = List<QolipProduct>.unmodifiable(parsed);
      } else {
        throw MobileApiException(
          code: 'qolip_products_failed',
          message: 'Qolip products failed',
          statusCode: response.statusCode,
        );
      }
      if (account != _qolipProductsAccount) {
        throw StateError('Qolip catalog account changed');
      }
      if (scope != _qolipProductsScope) {
        // Reauthentication or a concurrent write needs a fresh scoped request.
        // A disposed screen still cannot publish this result (load generation).
        return await _readQolipProducts(
          query: query,
          limit: limit,
          withQolipOnly: withQolipOnly,
        );
      }
      if (cache != null && cache.requestGeneration == generation) {
        cache.products = products;
        cache.etag = response.headers['etag'] ??
            (response.statusCode == 304 ? previousEtag : null);
        cache.storedAt = DateTime.now();
      }
      return products;
    } catch (_) {
      // A denied or failed refresh must not leave a reusable stale snapshot.
      if (cache != null && cache.requestGeneration == generation) {
        cache.products = null;
        cache.etag = null;
        cache.storedAt = null;
      }
      rethrow;
    }
  }
}
