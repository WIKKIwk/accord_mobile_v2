part of '../mobile_api.dart';

extension MobileApiPreparationProduction on MobileApi {
  Future<Map<String, dynamic>> _productionRead(
      String path, Map<String, String> query) async {
    final key = _preparationStorageKey();
    final scope = currentSessionReadScope();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key ||
          currentSessionReadScope() != scope) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/preparation/production/$path')
              .replace(queryParameters: query),
          headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key || currentSessionReadScope() != scope) {
      throw StateError('Akkaunt o‘zgargan');
    }
    return _preparationResponse(response);
  }

  Future<PreparationProductionOrdersPage> preparationProductionOrders({
    String query = '',
    String status = 'all',
    int offset = 0,
  }) async {
    if (!const {'all', 'active', 'completed'}.contains(status) || offset < 0) {
      throw ArgumentError('Ishlab chiqarish filtri noto‘g‘ri');
    }
    return PreparationProductionOrdersPage.fromJson(
        await _productionRead('orders', {
      'q': query.trim(),
      'status': status,
      'offset': '$offset',
      'limit': '50',
    }));
  }

  Future<PreparationProductionOrderPage> preparationProductionOrder(
      String orderId,
      {int offset = 0}) async {
    if (orderId.trim().isEmpty || offset < 0) {
      throw ArgumentError('Buyurtma tanlanmagan');
    }
    final page =
        PreparationProductionOrderPage.fromJson(await _productionRead('order', {
      'order_id': orderId.trim(),
      'offset': '$offset',
      'limit': '30',
    }));
    if (page.order.id != orderId.trim()) {
      throw const FormatException('Buyurtma mos kelmadi');
    }
    return page;
  }

  Future<PreparationProductionBatchPage> preparationProductionBatch(
      String batchId,
      {int offset = 0}) async {
    if (batchId.trim().isEmpty || offset < 0) {
      throw ArgumentError('Ishlab chiqarish tanlanmagan');
    }
    final page =
        PreparationProductionBatchPage.fromJson(await _productionRead('batch', {
      'batch_id': batchId.trim(),
      'offset': '$offset',
      'limit': '50',
    }));
    if (page.batch.id != batchId.trim()) {
      throw const FormatException('Ishlab chiqarish mos kelmadi');
    }
    return page;
  }
}
