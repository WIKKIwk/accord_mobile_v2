part of '../mobile_api.dart';

extension MobileApiAdminTelegram on MobileApi {
  Future<TelegramAdminOverview> adminTelegramOverview() async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.telegramAdminOverview;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/telegram/settings'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Telegram settings failed');
    }
    return TelegramAdminOverview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TelegramAdminOverview> updateTelegramBotSettings({
    required String botUsername,
    String botToken = '',
  }) async {
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/telegram/settings'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'bot_username': botUsername.trim(),
          'bot_token': botToken.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Telegram settings update failed');
    }
    return TelegramAdminOverview.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TelegramInvite> createTelegramInvite(TelegramInviteRole role) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/telegram/invites'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'role': role.jsonName}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Telegram invite creation failed');
    }
    return TelegramInvite.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<TelegramQrLogin> startTelegramQrLogin(TelegramInviteRole role) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/telegram/qr-logins'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'role': role.jsonName}),
        ));
    return _telegramQrResponse(response);
  }

  Future<TelegramQrLogin> pollTelegramQrLogin(String id) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/telegram/qr-logins/${Uri.encodeComponent(id)}'),
          headers: _headers(requireToken()),
        ));
    return _telegramQrResponse(response);
  }

  Future<TelegramQrLogin> submitTelegramQrPassword(
      String id, String password) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/telegram/qr-logins/${Uri.encodeComponent(id)}'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'password': password}),
        ));
    return _telegramQrResponse(response);
  }

  Future<void> cancelTelegramQrLogin(String id) async {
    await _sendAuthorized(() => _delete(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/telegram/qr-logins/${Uri.encodeComponent(id)}'),
          headers: _headers(requireToken()),
        ));
  }

  Future<void> deleteTelegramUser(String telegramUserId) async {
    final response = await _sendAuthorized(() => _delete(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/telegram/users/${Uri.encodeComponent(telegramUserId)}'),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw Exception('Telegram user deletion failed');
    }
  }

  TelegramQrLogin _telegramQrResponse(http.Response response) {
    if (response.statusCode != 200) {
      String code = 'transport_failed';
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        code = (json['error'] ?? json['message']) as String? ?? code;
      } catch (_) {
        /* Non-JSON proxy errors use the generic connection message. */
      }
      throw TelegramQrException(code);
    }
    return TelegramQrLogin.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
}
