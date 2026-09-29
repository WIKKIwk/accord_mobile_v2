part of '../mobile_api.dart';

class AdminPushConfig {
  const AdminPushConfig(
      {required this.configured,
      this.projectId = '',
      this.clientEmail = '',
      this.source = '',
      this.lastVerifiedAt,
      this.error = ''});
  final bool configured;
  final String projectId;
  final String clientEmail;
  final String source;
  final int? lastVerifiedAt;
  final String error;

  factory AdminPushConfig.fromJson(Map<String, dynamic> json) =>
      AdminPushConfig(
        configured: json['configured'] == true,
        projectId: json['project_id']?.toString() ?? '',
        clientEmail: json['client_email']?.toString() ?? '',
        source: json['source']?.toString() ?? '',
        lastVerifiedAt: (json['last_verified_at'] as num?)?.toInt(),
        error: json['error']?.toString() ?? '',
      );
}

extension MobileApiPushConfig on MobileApi {
  Future<AdminPushConfig> adminPushConfig() async =>
      AdminPushConfig.fromJson(await _pushConfigRequest('GET', ''));

  Future<AdminPushConfig> saveAdminPushConfig(
          Map<String, dynamic> account) async =>
      AdminPushConfig.fromJson(await _pushConfigRequest('PUT', '', {
        'service_account': account,
        'client_project_id': PushMessagingService.instance.firebaseProjectId
      }));

  Future<AdminPushConfig> checkAdminPushConfig() async =>
      AdminPushConfig.fromJson(await _pushConfigRequest('POST', '/check'));

  Future<void> testAdminPushConfig(String deviceToken) async {
    final result =
        await _pushConfigRequest('POST', '/test', {'token': deviceToken});
    if (result['accepted_by_fcm'] != true) {
      throw const MobileApiException(
          code: 'push_config_test_failed',
          message: 'FCM did not accept the test');
    }
  }

  Future<Map<String, dynamic>> _pushConfigRequest(String method, String suffix,
      [Map<String, dynamic>? body]) async {
    if (AppSession.instance.isTestModeSession ||
        await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'push_config_test_mode', message: 'Unavailable in test mode');
    }
    final uri =
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/push-config$suffix');
    final response = await _sendAuthorized(() {
      final headers = {
        ..._headers(requireToken()),
        'Content-Type': 'application/json'
      };
      if (method == 'GET') return _get(uri, headers: headers);
      if (method == 'PUT') {
        return _put(uri,
            headers: headers,
            body: jsonEncode(body),
            timeout: const Duration(seconds: 40));
      }
      return _post(uri,
          headers: headers,
          body: jsonEncode(body ?? {}),
          timeout: const Duration(seconds: 40));
    });
    Map<String, dynamic> json = {};
    try {
      json = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (response.statusCode != 200 || json.isEmpty) {
      throw MobileApiException(
          code: json['error']?.toString() ?? 'push_config_request_failed',
          message: 'Push configuration request failed',
          statusCode: response.statusCode);
    }
    return json;
  }
}
