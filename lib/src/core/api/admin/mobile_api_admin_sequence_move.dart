part of '../mobile_api.dart';

class AdminSequenceMoveResult {
  const AdminSequenceMoveResult(
    this.orderIds,
    this.version,
    this.adjusted, {
    this.revision,
    this.ops = const [],
  });
  final List<String> orderIds;
  final String version;
  final bool adjusted;
  final int? revision;
  final List<AdminProductionMapDeltaOp> ops;
}

extension MobileApiAdminSequenceMove on MobileApi {
  Future<AdminSequenceMoveResult> adminMoveProductionMapSequence({
    required String apparatus,
    required String orderId,
    String? beforeOrderId,
    String? afterOrderId,
    required String expectedVersion,
    required String idempotencyKey,
  }) async {
    _requireCanonicalApparatusId(apparatus);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedVersion)) {
      throw const MobileApiException(
          code: 'queue_reorder_unavailable',
          message: 'Server navbatni xavfsiz surish uchun yangilanishi kerak.');
    }
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeForceSequenceSaveFailure) {
        throw const MobileApiException(
            code: 'queue_reorder_conflict',
            message: 'Ketma-ketlik saqlanmadi (test)');
      }
      final ids = List<String>.from(
          _testModeEffectiveQueueSequences()[apparatus] ?? const []);
      if (!ids.remove(orderId)) {
        throw const MobileApiException(
            code: 'queue_reorder_conflict', message: 'Navbat o‘zgargan');
      }
      final index = beforeOrderId != null
          ? ids.indexOf(beforeOrderId)
          : afterOrderId != null
              ? ids.indexOf(afterOrderId) + 1
              : ids.length;
      if (index < 0 || (afterOrderId != null && !ids.contains(afterOrderId))) {
        throw const MobileApiException(
            code: 'queue_reorder_conflict', message: 'Navbat o‘zgargan');
      }
      ids.insert(index, orderId);
      _testModeApparatusSequences[apparatus] = ids;
      return AdminSequenceMoveResult(ids, expectedVersion, false);
    }
    // Retries in the transport/auth layer reuse this exact body and key.
    final body = jsonEncode({
      'apparatus': apparatus,
      'order_id': orderId,
      if (beforeOrderId != null) 'before_order_id': beforeOrderId,
      if (afterOrderId != null) 'after_order_id': afterOrderId,
      'expected_version': expectedVersion,
      'idempotency_key': idempotencyKey,
    });
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/sequence'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: body,
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
    final data = jsonDecode(response.body);
    final ids = data is Map ? data['order_ids'] : null;
    final version = data is Map ? data['version'] : null;
    if (data is! Map ||
        data['ok'] != true ||
        ids is! List ||
        ids.any((id) => id is! String || id.trim().isEmpty) ||
        ids.toSet().length != ids.length ||
        !ids.contains(orderId) ||
        version is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(version) ||
        data['adjusted'] is! bool) {
      throw _productionMapQueueContractException(
          'invalid sequence move result');
    }
    final rawRev = data['revision'];
    final revision = rawRev is num ? rawRev.toInt() : null;
    final rawOps = data['ops'];
    final ops = <AdminProductionMapDeltaOp>[];
    if (rawOps is List) {
      for (final item in rawOps) {
        if (item is Map) {
          ops.add(AdminProductionMapDeltaOp.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return AdminSequenceMoveResult(
      List<String>.from(ids),
      version,
      data['adjusted'] as bool,
      revision: revision,
      ops: ops,
    );
  }
}
