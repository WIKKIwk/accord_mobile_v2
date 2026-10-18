part of '../mobile_api.dart';

class AdminReactivationRecloseControl {
  AdminReactivationRecloseControl._(
      {required this.sessionId,
      required this.stageNodeId,
      required this.token,
      required this.workerRef})
      : _readScope = currentSessionReadScope();

  final String sessionId;
  final String stageNodeId;
  final String token;
  final String workerRef;
  final String _readScope;

  static AdminReactivationRecloseControl? tryFromJson(Object? raw) {
    if (raw is! Map || raw['worker_role'] != 'aparatchi') return null;
    for (final key in ['session_id', 'stage_node_id', 'token', 'worker_ref']) {
      if (raw[key] is! String || (raw[key] as String).trim().isEmpty)
        return null;
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(raw['token'] as String) ||
        (raw['session_id'] as String).length > 4096 ||
        (raw['stage_node_id'] as String).length > 512) return null;
    return AdminReactivationRecloseControl._(
        sessionId: raw['session_id'] as String,
        stageNodeId: raw['stage_node_id'] as String,
        token: raw['token'] as String,
        workerRef: raw['worker_ref'] as String);
  }

  bool belongsTo(SessionProfile? profile) =>
      _readScope == currentSessionReadScope() &&
      profile?.role == UserRole.aparatchi &&
      profile?.ref == workerRef;
}

extension MobileApiReactivationReclose on MobileApi {
  Future<void> adminRecloseReactivatedWork(
      {required String apparatus,
      required String orderId,
      required AdminReactivationRecloseControl control}) async {
    final scope = currentSessionReadScope();
    _requireCanonicalApparatusId(apparatus);
    if (!control.belongsTo(AppSession.instance.profile) ||
        orderId.trim().isEmpty ||
        orderId.startsWith('training-') ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'queue_action_not_allowed', message: '');
    }
    final uri = Uri.parse(
        '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/reactivation/reclose');
    final body = jsonEncode({
      'apparatus': apparatus,
      'order_id': orderId,
      'session_id': control.sessionId,
      'stage_node_id': control.stageNodeId,
      'token': control.token
    });
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope() ||
          !control.belongsTo(AppSession.instance.profile)) {
        throw const MobileApiException(
            code: 'session_scope_changed', message: '');
      }
      return _post(uri,
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: body);
    });
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
