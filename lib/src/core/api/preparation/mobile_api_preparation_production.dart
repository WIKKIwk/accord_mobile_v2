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
    return PreparationProductionOrdersPage.fromJson(
        await _productionList('orders', query, status, offset));
  }

  Future<PreparationProductionBatchesPage> preparationProductionBatches({
    String query = '',
    String status = 'all',
    int offset = 0,
  }) async {
    return PreparationProductionBatchesPage.fromJson(
        await _productionList('batches', query, status, offset));
  }

  Future<PreparationProductionRollsPage> preparationProductionRolls({
    String query = '',
    String status = 'all',
    int offset = 0,
  }) async {
    return PreparationProductionRollsPage.fromJson(
        await _productionList('rolls', query, status, offset));
  }

  Future<Map<String, dynamic>> _productionList(
      String mode, String query, String status, int offset) async {
    if (!const {'all', 'active', 'completed'}.contains(status) || offset < 0) {
      throw ArgumentError('Ishlab chiqarish filtri noto‘g‘ri');
    }
    try {
      return await _productionRead(mode, {
        'q': String.fromCharCodes(query.trim().runes.take(200)),
        'status': status,
        'offset': '$offset',
        'limit': '50',
      });
    } on MobileApiException catch (error) {
      if (mode != 'orders' && error.statusCode == 404) {
        throw const MobileApiException(
          code: 'preparation_output_api_unavailable',
          statusCode: 404,
          message:
              'Batch va rulon ro‘yxati uchun Mini RS ERP’ni yangilash kerak.',
        );
      }
      rethrow;
    }
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
