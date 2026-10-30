part of '../mobile_api.dart';

class AdminScannedWip {
  const AdminScannedWip({
    required this.sessionId,
    required this.batchId,
    required this.qrPayload,
    required this.sourceApparatus,
    required this.linkedAtUnix,
    required this.workerDisplayName,
    required this.state,
    required this.consumeState,
    required this.returnToken,
    required this.blockedReason,
  });
  final String sessionId,
      batchId,
      qrPayload,
      sourceApparatus,
      workerDisplayName;
  final String state, consumeState, blockedReason;
  final String? returnToken;
  final int linkedAtUnix;
  bool get canReturn =>
      consumeState == 'unused' &&
      returnToken != null &&
      const {'active', 'unprocessed'}.contains(state);

  factory AdminScannedWip.fromJson(Map<String, dynamic> json) {
    for (final key in [
      'session_id',
      'batch_id',
      'qr_payload',
      'source_apparatus',
      'worker_display_name',
      'blocked_reason'
    ]) {
      if (json[key] is! String) {
        throw const FormatException('Invalid scanned WIP');
      }
    }
    final token = json['return_token'];
    if (json['session_id'].isEmpty ||
        json['batch_id'].isEmpty ||
        json['linked_at_unix'] is! int ||
        !const {'active', 'unprocessed', 'consumed', 'returned'}
            .contains(json['state']) ||
        !const {'unused', 'consumed', 'unknown'}
            .contains(json['consume_state']) ||
        (token != null &&
            (token is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(token)))) {
      throw const FormatException('Invalid scanned WIP');
    }
    return AdminScannedWip(
      sessionId: json['session_id'],
      batchId: json['batch_id'],
      qrPayload: json['qr_payload'],
      sourceApparatus: json['source_apparatus'],
      linkedAtUnix: json['linked_at_unix'],
      workerDisplayName: json['worker_display_name'],
      state: json['state'],
      consumeState: json['consume_state'],
      returnToken: token,
      blockedReason: json['blocked_reason'],
    );
  }
}

extension MobileApiScannedWip on MobileApi {
  Future<List<AdminScannedWip>> adminScannedWips({
    required String apparatus,
    required String orderId,
    required String stageNodeId,
  }) async {
    final scope = currentSessionReadScope();
    final machine = _requireCanonicalApparatusId(apparatus);
    if (orderId.trim().isEmpty || stageNodeId.trim().isEmpty) {
      throw const FormatException('Invalid scanned WIP scope');
    }
    if (await TestModeController.instance.isEnabled()) return const [];
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/scanned-wips')
              .replace(queryParameters: {
            'apparatus': machine,
            'order_id': orderId.trim(),
            'stage_node_id': stageNodeId.trim()
          }),
          headers: _headers(requireToken()),
        ));
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'scanned_wips');
    }
    final body = jsonDecode(response.body);
    if (body is! Map || body['items'] is! List) {
      throw const FormatException('Invalid scanned WIP response');
    }
    return List.unmodifiable((body['items'] as List).map((row) {
      if (row is! Map) throw const FormatException('Invalid scanned WIP');
      return AdminScannedWip.fromJson(row.cast<String, dynamic>());
    }));
  }

  Future<void> adminReturnScannedWip({
    required String apparatus,
    required String orderId,
    required String stageNodeId,
    required AdminScannedWip input,
  }) async {
    final scope = currentSessionReadScope();
    final machine = _requireCanonicalApparatusId(apparatus);
    if (!input.canReturn ||
        orderId.trim().isEmpty ||
        stageNodeId.trim().isEmpty ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'queue_action_not_allowed', message: '');
    }
    final body = jsonEncode({
      'apparatus': machine,
      'order_id': orderId.trim(),
      'stage_node_id': stageNodeId.trim(),
      'session_id': input.sessionId,
      'batch_id': input.batchId,
      'token': input.returnToken
    });
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: '');
      }
      return _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/scanned-wips/return'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: body);
    });
    if (scope != currentSessionReadScope()) {
      throw const MobileApiException(
          code: 'session_scope_changed', message: '');
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_action_not_allowed');
    }
    final reply = jsonDecode(response.body);
    if (reply is! Map || reply['ok'] != true) {
      throw const FormatException('Invalid WIP return response');
    }
  }
}
