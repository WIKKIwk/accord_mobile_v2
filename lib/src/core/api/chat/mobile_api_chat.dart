part of '../mobile_api.dart';

extension MobileApiChat on MobileApi {
  Future<void> chatRegisterDeviceToken({
    required String tokenValue,
    required String platform,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/chat/device-token'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'token': tokenValue.trim(), 'platform': platform}),
      ),
    );
    _requireChatSuccess(response, 'chat_device_register_failed');
  }

  Future<void> chatUnregisterDeviceToken(String tokenValue) async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) return;
    final response = await _delete(
      Uri.parse('${MobileApi.baseUrl}/v1/mobile/chat/device-token').replace(
        queryParameters: {'token': tokenValue.trim()},
      ),
      headers: _headers(token),
    );
    _requireChatSuccess(response, 'chat_device_unregister_failed');
  }

  Future<ChatDirectoryPage> chatDirectory({String query = ''}) async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/chat/directory').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            'limit': '100',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_directory_failed');
    return ChatDirectoryPage.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<ChatConversationPage> chatConversations() async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/chat/conversations').replace(
          queryParameters: {'limit': '100'},
        ),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_conversations_failed');
    return ChatConversationPage.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<ChatConversation> chatCreateDm(ChatDirectoryEntry target) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/chat/conversations/dm'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'role': userRoleToJson(target.role),
          'ref': target.ref,
        }),
      ),
    );
    _requireChatSuccess(response, 'chat_create_failed');
    return ChatConversation.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<ChatMessagePage> chatMessages(
    String conversationId, {
    int? beforeSequence,
  }) async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
        ).replace(
          queryParameters: {
            'limit': '100',
            if (beforeSequence != null)
              'before_sequence': beforeSequence.toString(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_messages_failed');
    return ChatMessagePage.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<ChatMessage> chatSendMessage({
    required String conversationId,
    required String clientMessageId,
    required String body,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/chat/conversations/${Uri.encodeComponent(conversationId)}/messages',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'client_message_id': clientMessageId,
          'body': body,
        }),
      ),
    );
    _requireChatSuccess(response, 'chat_send_failed');
    final payload = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    return ChatMessage.fromJson(
      (payload['message'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> chatMarkRead({
    required String conversationId,
    required int sequence,
    required String deviceId,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/chat/conversations/${Uri.encodeComponent(conversationId)}/read',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'sequence': sequence, 'device_id': deviceId}),
      ),
    );
    _requireChatSuccess(response, 'chat_read_failed');
  }

  Future<Uri> chatLiveUri() async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/chat/socket-ticket'),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_socket_ticket_failed');
    final payload = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    final base = Uri.parse(MobileApi.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/mobile/chat/live',
      queryParameters: {'ticket': payload['ticket']?.toString() ?? ''},
    );
  }

  Never _chatFailure(http.Response response, String fallbackCode) {
    var code = fallbackCode;
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['error'] != null) {
        code = payload['error'].toString();
      }
    } catch (_) {}
    throw MobileApiException(
      code: code,
      message: 'Chat so‘rovi bajarilmadi',
      statusCode: response.statusCode,
    );
  }

  void _requireChatSuccess(http.Response response, String fallbackCode) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _chatFailure(response, fallbackCode);
    }
  }
}
