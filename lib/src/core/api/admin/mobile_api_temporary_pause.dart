part of '../mobile_api.dart';

class AdminTemporaryPauseControl {
  const AdminTemporaryPauseControl(
      {required this.sessionId, required this.token});

  final String sessionId;
  final String token;

  static AdminTemporaryPauseControl? tryFromJson(Object? raw) {
    if (raw is! Map ||
        raw['session_id'] is! String ||
        raw['token'] is! String) {
      return null;
    }
    final sessionId = raw['session_id'] as String;
    final token = raw['token'] as String;
    if (sessionId.trim().isEmpty ||
        sessionId != sessionId.trim() ||
        sessionId.length > 512 ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
      return null;
    }
    return AdminTemporaryPauseControl(sessionId: sessionId, token: token);
  }
}

extension MobileApiTemporaryPause on MobileApi {
  Future<void> adminTemporarilyPauseWork({
    required String apparatus,
    required String orderId,
    required AdminTemporaryPauseControl control,
  }) async {
    final scope = currentSessionReadScope();
    final apparatusId = _requireCanonicalApparatusId(apparatus);
    final normalizedOrder = orderId.trim();
    if (normalizedOrder.isEmpty ||
        normalizedOrder.startsWith('training-') ||
        AdminTemporaryPauseControl.tryFromJson({
              'session_id': control.sessionId,
              'token': control.token,
            }) ==
            null ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'queue_action_not_allowed', message: '');
    }
    final uri = Uri.parse(
        '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/temporary-pause');
    final body = jsonEncode({
      'apparatus': apparatusId,
      'order_id': normalizedOrder,
      'session_id': control.sessionId,
      'token': control.token,
    });
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: '');
      }
      return _post(uri,
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
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['ok'] != true) {
      throw const MobileApiException(
          code: 'queue_action_not_allowed', message: '');
    }
  }
}
