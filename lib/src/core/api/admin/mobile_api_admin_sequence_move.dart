part of '../mobile_api.dart';

class AdminSequenceMoveResult {
  const AdminSequenceMoveResult(
    this.orderIds,
    this.version,
    this.adjusted, {
    this.revision,
    this.epoch = '',
    this.ops = const [],
  });
  final List<String> orderIds;
  final String version;
  final bool adjusted;
  final int? revision;
  final String epoch;
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
    // Complete canonical IDs captured with this exact expectedVersion. A
    // filtered/paged or locally projected list must never be passed here.
    List<String>? canonicalOrderIds,
  }) async {
    _requireCanonicalApparatusId(apparatus);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedVersion)) {
      throw const MobileApiException(
          code: 'queue_reorder_unavailable',
          message: 'Server navbatni xavfsiz surish uchun yangilanishi kerak.');
    }
    final baseline = canonicalOrderIds == null
        ? null
        : List<String>.unmodifiable(canonicalOrderIds);
    if (baseline != null &&
        (baseline.isEmpty ||
            baseline.any((id) => id.isEmpty || id != id.trim()) ||
            baseline.toSet().length != baseline.length ||
            !baseline.contains(orderId))) {
      throw _productionMapQueueContractException(
          'invalid sequence move baseline');
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
          headers: {
            ..._headers(requireToken()),
            'Content-Type': 'application/json',
            if (baseline != null) 'Prefer': 'return=minimal',
          },
          body: body,
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'production_map_sequence');
    }
    final data = jsonDecode(response.body);
    final version = data is Map ? data['version'] : null;
    if (data is! Map ||
        data['ok'] != true ||
        version is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(version) ||
        data['adjusted'] is! bool) {
      throw _productionMapQueueContractException(
          'invalid sequence move result');
    }
    final rawIds = data['order_ids'];
    final List<String> ids;
    if (rawIds is List) {
      if (rawIds.any((id) => id is! String || id.trim().isEmpty) ||
          rawIds.toSet().length != rawIds.length ||
          !rawIds.contains(orderId)) {
        throw _productionMapQueueContractException('invalid sequence move IDs');
      }
      // Older servers ignore Prefer and return their original complete list.
      ids = List<String>.from(rawIds);
    } else if (baseline != null && !data.containsKey('order_ids')) {
      ids = _decodeMinimalSequenceMove(
          data, baseline, orderId, expectedVersion, version);
    } else {
      throw _productionMapQueueContractException('missing sequence move IDs');
    }
    final rawRev = data['revision'];
    final revision = rawRev is num ? rawRev.toInt() : null;
    final rawOps = data['ops'];
    final ops = <AdminProductionMapDeltaOp>[];
    if (rawOps is List) {
      for (final item in rawOps) {
        if (item is Map) {
          ops.add(
              AdminProductionMapDeltaOp.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return AdminSequenceMoveResult(
      ids,
      version,
      data['adjusted'] as bool,
      revision: revision,
      epoch: data['epoch'] is String ? data['epoch'] as String : '',
      ops: ops,
    );
  }
}

List<String> _decodeMinimalSequenceMove(Map data, List<String> baseline,
    String orderId, String expectedVersion, String version) {
  final rawOps = data['ops'];
  if (data['base_version'] != expectedVersion ||
      rawOps is! List ||
      rawOps.length > 1 ||
      data['order_count'] is! int ||
      data['order_count'] != baseline.length ||
      data['order_hash'] is! String ||
      !RegExp(r'^[0-9a-f]{16}$').hasMatch(data['order_hash'] as String) ||
      (data['revision'] != null &&
          (data['revision'] is! int || (data['revision'] as int) < 0)) ||
      (rawOps.isNotEmpty && data['revision'] == null) ||
      data['epoch'] is! String ||
      (data['epoch'] as String).isEmpty) {
    throw _productionMapQueueContractException(
        'invalid minimal sequence move result');
  }
  final result = List<String>.from(baseline);
  if (rawOps.isEmpty) {
    if (version != expectedVersion) {
      throw _productionMapQueueContractException(
          'invalid no-op sequence version');
    }
  } else {
    final op = rawOps.single;
    if (op is! Map ||
        op['type'] != 'move' ||
        op['id'] != orderId ||
        op['base_version'] != expectedVersion ||
        op['version'] != version ||
        (op['before_id'] != null && op['before_id'] is! String) ||
        (op['after_id'] != null && op['after_id'] is! String) ||
        !result.remove(orderId)) {
      throw _productionMapQueueContractException(
          'invalid canonical sequence move');
    }
    final before = op['before_id'] as String?;
    final after = op['after_id'] as String?;
    final index = before != null
        ? result.indexOf(before)
        : after != null
            ? result.indexOf(after) + 1
            : result.isEmpty
                ? 0
                : -1;
    if (index < 0 || (after != null && !result.contains(after))) {
      throw _productionMapQueueContractException(
          'missing canonical sequence anchor');
    }
    result.insert(index, orderId);
    if ((before != null &&
            (index + 1 >= result.length || result[index + 1] != before)) ||
        (after != null && (index == 0 || result[index - 1] != after))) {
      throw _productionMapQueueContractException(
          'inconsistent canonical sequence anchors');
    }
  }
  if (data['order_count'] != result.length ||
      data['order_hash'] != _productionMapSequenceFingerprint(result)) {
    throw _productionMapQueueContractException(
        'minimal sequence result fingerprint mismatch');
  }
  return result;
}
