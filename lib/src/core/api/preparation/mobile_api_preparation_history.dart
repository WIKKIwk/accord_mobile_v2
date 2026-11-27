part of '../mobile_api.dart';

extension MobileApiPreparationHistory on MobileApi {
  Future<PreparationHistoryPage> preparationHistory({
    required String warehouseId,
    PreparationHistoryCursor? cursor,
  }) async {
    final scope = currentSessionReadScope();
    _preparationStorageKey();
    void requireCurrentScope() {
      if (scope != currentSessionReadScope()) {
        throw const MobileApiException(
          code: 'account_changed',
          message: 'Akkaunt o‘zgargan. Sahifani qayta oching',
        );
      }
    }

    final uri =
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/history').replace(
      queryParameters: {
        'kind': 'all',
        if (warehouseId.isNotEmpty) 'warehouse_id': warehouseId,
        if (cursor != null) ...{
          'before_time': cursor.time,
          'before_key': cursor.key,
        },
      },
    );
    final response = await _sendAuthorized(() {
      requireCurrentScope();
      return _get(uri, headers: _headers(requireToken()));
    });
    requireCurrentScope();
    return PreparationHistoryPage.fromJson(_preparationResponse(response));
  }
}
