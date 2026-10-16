part of '../mobile_api.dart';

class AdminResumePauseControl {
  const AdminResumePauseControl(
      {required this.resumeId,
      required this.workerRole,
      required this.workerRef});

  final String resumeId;
  final String workerRole;
  final String workerRef;

  static AdminResumePauseControl? tryFromJson(Object? raw) {
    if (raw is! Map ||
        raw['resume_id'] is! String ||
        raw['worker_role'] != 'aparatchi' ||
        raw['worker_ref'] is! String) {
      return null;
    }
    final id = (raw['resume_id'] as String).trim();
    final ref = (raw['worker_ref'] as String).trim();
    if (id.isEmpty || id.length > 512 || ref.isEmpty) return null;
    return AdminResumePauseControl(
        resumeId: id, workerRole: 'aparatchi', workerRef: ref);
  }

  bool belongsTo(SessionProfile? profile) =>
      profile?.role == UserRole.aparatchi &&
      profile?.ref == workerRef &&
      workerRole == 'aparatchi';
}

extension MobileApiResumePause on MobileApi {
  Future<void> adminRePauseResumedWork(
      {required String apparatus,
      required String orderId,
      required String resumeId}) async {
    final scope = currentSessionReadScope();
    _requireCanonicalApparatusId(apparatus);
    if (resumeId.trim().isEmpty ||
        resumeId.length > 512 ||
        orderId.trim().isEmpty ||
        orderId.startsWith('training-') ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'queue_action_not_allowed', message: '');
    }
    final uri = Uri.parse(
        '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/re-pause');
    final body = jsonEncode(
        {'apparatus': apparatus, 'order_id': orderId, 'resume_id': resumeId});
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
