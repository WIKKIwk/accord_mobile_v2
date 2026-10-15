part of '../mobile_api.dart';

extension MobileApiPaddonTransfer on MobileApi {
  Future<void> transferPaddonItems({
    required String sourceCode,
    required String targetCode,
    required List<String> progressBatchIds,
  }) async {
    final source = sourceCode.trim();
    final target = targetCode.trim();
    final ids = progressBatchIds.map((id) => id.trim()).toSet();
    if (source.isEmpty ||
        target.isEmpty ||
        source == target ||
        source.length > 128 ||
        target.length > 128 ||
        ids.isEmpty ||
        ids.length > 500 ||
        ids.contains('')) {
      throw const MobileApiException(
        code: 'paddon_invalid_input',
        message: 'Invalid paddon transfer',
      );
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/items/transfer'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'source_code': source,
            'target_code': target,
            'progress_batch_ids': ids.toList(),
          }),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_transfer');
    }
    final payload = jsonDecode(response.body);
    final returnedIds = payload is Map ? payload['progress_batch_ids'] : null;
    if (payload is! Map ||
        payload['ok'] != true ||
        payload['source_code'] != source ||
        payload['target_code'] != target ||
        returnedIds is! List ||
        returnedIds.length != ids.length ||
        !setEquals(returnedIds.toSet(), ids)) {
      throw const MobileApiException(
        code: 'paddon_transfer',
        message: 'Paddon transfer was not confirmed',
      );
    }
  }
}
