part of '../mobile_api.dart';

class QolipCatalogItem {
  const QolipCatalogItem({required this.id, required this.name});
  final String id;
  final String name;
}

class QolipCatalogPage {
  const QolipCatalogPage({required this.items, this.nextCursor});
  final List<QolipCatalogItem> items;
  final String? nextCursor;
  bool get hasMore => nextCursor != null;
}

extension MobileApiQolipCatalog on MobileApi {
  Future<QolipCatalogPage> qolipCatalogPage({
    String query = '',
    String? cursor,
    int limit = 200,
  }) async {
    final count = limit.clamp(1, 200);
    if (await TestModeController.instance.isEnabled()) {
      final products =
          await qolipProducts(query: query, limit: 20000, withQolipOnly: true);
      final unique = <String, QolipProduct>{};
      for (final product in products) {
        if (product.qolipCode.isNotEmpty) {
          unique.putIfAbsent(product.code.toLowerCase(), () => product);
        }
      }
      final items = unique.values.toList()
        ..sort((a, b) {
          final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return name == 0
              ? a.code.toLowerCase().compareTo(b.code.toLowerCase())
              : name;
        });
      if (cursor != null) {
        final last = (jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(cursor)))))
            as List;
        items.removeWhere((item) {
          final name = item.name.toLowerCase().compareTo(last[0] as String);
          return name < 0 ||
              (name == 0 &&
                  item.code.toLowerCase().compareTo(last[1] as String) <= 0);
        });
      }
      final page = items.take(count).toList();
      return QolipCatalogPage(
        items: [
          for (final item in page)
            QolipCatalogItem(
                id: 'qp1.${base64Url.encode(utf8.encode(item.code)).replaceAll('=', '')}',
                name: item.name)
        ],
        nextCursor: items.length > count
            ? base64Url
                .encode(utf8.encode(jsonEncode([
                  page.last.name.toLowerCase(),
                  page.last.code.toLowerCase()
                ])))
                .replaceAll('=', '')
            : null,
      );
    }
    final account = _qolipProductsAccount;
    final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/products/page')
        .replace(queryParameters: {
      'limit': '$count',
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (cursor != null) 'cursor': cursor,
    });
    final response = await _sendAuthorized(() {
      if (account != _qolipProductsAccount) {
        throw StateError('Qolip catalog account changed');
      }
      return _get(uri, headers: _headers(requireToken()));
    });
    if (account != _qolipProductsAccount) {
      throw StateError('Qolip catalog account changed');
    }
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_products_failed',
          fallbackMessage: 'Qoliplar yuklanmadi');
    }
    final data = await decodeJsonMapPayload(response.body);
    final raw = data['items'];
    final next = data['next_cursor'];
    if (raw is! List ||
        raw.length > count ||
        data['has_more'] is! bool ||
        (data['has_more'] == true &&
            (raw.isEmpty ||
                next is! String ||
                next.isEmpty ||
                next == cursor))) {
      throw const FormatException('Invalid Qolip catalog page');
    }
    final ids = <String>{};
    final items = <QolipCatalogItem>[];
    for (final item in raw) {
      if (item is! Map ||
          item['id'] is! String ||
          item['name'] is! String ||
          (item['id'] as String).isEmpty ||
          !ids.add(item['id'] as String)) {
        throw const FormatException('Invalid Qolip catalog item');
      }
      items.add(QolipCatalogItem(
          id: item['id'] as String, name: item['name'] as String));
    }
    return QolipCatalogPage(
        items: List.unmodifiable(items),
        nextCursor: data['has_more'] == true ? next as String : null);
  }

  Future<List<QolipProduct>> qolipCatalogDetails(String id) async {
    if (await TestModeController.instance.isEnabled()) {
      final code =
          utf8.decode(base64Url.decode(base64Url.normalize(id.substring(4))));
      return (await qolipProducts(limit: 20000, withQolipOnly: true))
          .where((product) => product.code.toLowerCase() == code.toLowerCase())
          .toList();
    }
    final account = _qolipProductsAccount;
    final uri =
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/products/detail')
            .replace(queryParameters: {'id': id});
    final response = await _sendAuthorized(() {
      if (account != _qolipProductsAccount) {
        throw StateError('Qolip catalog account changed');
      }
      return _get(uri, headers: _headers(requireToken()));
    });
    if (account != _qolipProductsAccount) {
      throw StateError('Qolip catalog account changed');
    }
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_products_failed',
          fallbackMessage: 'Qoliplar yuklanmadi');
    }
    final data = await decodeJsonMapPayload(response.body);
    if (data['products'] is! List || (data['products'] as List).isEmpty) {
      throw const FormatException('Missing Qolip product details');
    }
    return List.unmodifiable((data['products'] as List).map(
        (raw) => QolipProduct.fromJson((raw as Map).cast<String, dynamic>())));
  }
}
