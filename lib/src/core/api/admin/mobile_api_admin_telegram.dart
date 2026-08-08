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
}
