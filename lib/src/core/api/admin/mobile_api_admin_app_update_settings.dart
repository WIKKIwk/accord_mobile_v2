part of '../mobile_api.dart';

extension MobileApiAppUpdateSettings on MobileApi {
  Future<bool> mandatoryAppUpdatesEnabled() async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/app-update/settings'),
          headers: _headers(requireToken()),
        ));
    return _mandatoryAppUpdatesResponse(response);
  }

  Future<bool> setMandatoryAppUpdatesEnabled(bool enabled) async {
    final response = await _sendAuthorized(() => _put(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/app-update/settings'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'mandatory_updates_enabled': enabled}),
        ));
    final saved = _mandatoryAppUpdatesResponse(response);
    if (saved != enabled) {
      throw const MobileApiException(
          code: 'app_update_settings_failed',
          message: 'Yangilash sozlamasi saqlanmadi');
    }
    return saved;
  }

  bool _mandatoryAppUpdatesResponse(http.Response response) {
    if (response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      if (payload is Map &&
          payload['ok'] == true &&
          payload['settings'] is Map &&
          payload['settings']['mandatory_updates_enabled'] is bool) {
        return payload['settings']['mandatory_updates_enabled'] as bool;
      }
    }
    throw MobileApiException(
        code: 'app_update_settings_failed',
        message: 'Yangilash sozlamasi yuklanmadi',
        statusCode: response.statusCode);
  }
}
