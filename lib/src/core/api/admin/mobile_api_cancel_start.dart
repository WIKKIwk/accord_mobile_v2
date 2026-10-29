part of '../mobile_api.dart';

class AdminCancelStartControl {
  const AdminCancelStartControl(
      {required this.sessionId,
      required this.token,
      required this.workerRef,
      required this.previousState});
  final String sessionId, token, workerRef, previousState;

  static AdminCancelStartControl? tryFromJson(Object? raw) {
    if (raw is! Map ||
        raw['session_id'] is! String ||
        raw['token'] is! String ||
        raw['worker_ref'] is! String ||
        raw['previous_state'] is! String) {
      return null;
    }
    final session = raw['session_id'] as String;
    final token = raw['token'] as String;
    final worker = raw['worker_ref'] as String;
    final previous = raw['previous_state'] as String;
    if (session.isEmpty ||
        session != session.trim() ||
        session.length > 512 ||
        worker.isEmpty ||
        worker != worker.trim() ||
        worker.length > 512 ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token) ||
        !const {'pending', 'completed'}.contains(previous)) {
      return null;
    }
    return AdminCancelStartControl(
        sessionId: session,
        token: token,
        workerRef: worker,
        previousState: previous);
  }
}

extension MobileApiCancelStart on MobileApi {
  Future<void> adminCancelStartedWork(
      {required String apparatus,
      required String orderId,
      required AdminCancelStartControl control}) async {
    final scope = currentSessionReadScope();
    final machine = _requireCanonicalApparatusId(apparatus);
    final order = orderId.trim();
    final profile = AppSession.instance.profile;
    if (order.isEmpty ||
        order.startsWith('training-') ||
        profile?.role != UserRole.aparatchi ||
        profile?.ref != control.workerRef ||
        AdminCancelStartControl.tryFromJson({
              'session_id': control.sessionId,
              'token': control.token,
              'worker_ref': control.workerRef,
              'previous_state': control.previousState
            }) ==
            null ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'queue_action_not_allowed', message: '');
    }
    final uri = Uri.parse(
        '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/cancel-start');
    final body = jsonEncode({
      'apparatus': machine,
      'order_id': order,
      'session_id': control.sessionId,
      'token': control.token
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
