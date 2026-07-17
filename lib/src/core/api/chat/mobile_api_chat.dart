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
    String? mediaId,
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
          if (mediaId != null && mediaId.trim().isNotEmpty)
            'media_id': mediaId.trim(),
        }),
      ),
    );
    _requireChatSuccess(response, 'chat_send_failed');
    final payload = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    return ChatMessage.fromJson(
      (payload['message'] as Map).cast<String, dynamic>(),
    );
  }

  Future<ChatMediaInitialization> chatInitializeMedia({
    required String conversationId,
    required String clientUploadId,
    required ChatMediaKind kind,
    required String filename,
    required String contentType,
    required int sizeBytes,
    int? durationMs,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/chat/conversations/${Uri.encodeComponent(conversationId)}/media/uploads',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'client_upload_id': clientUploadId,
          'kind': chatMediaKindToJson(kind),
          'filename': filename,
          'content_type': contentType,
          'size_bytes': sizeBytes,
          if (durationMs != null) 'duration_ms': durationMs,
        }),
      ),
    );
    _requireChatSuccess(response, 'chat_media_initialize_failed');
    return ChatMediaInitialization.fromJson(
      (jsonDecode(response.body) as Map).cast<String, dynamic>(),
    );
  }

  Future<void> chatUploadMedia({
    required ChatMediaUploadInstruction instruction,
    required Stream<List<int>> content,
    required int sizeBytes,
    required void Function(double progress) onProgress,
    http.Client? client,
  }) async {
    final uri = Uri.parse(MobileApi.baseUrl).resolve(instruction.url);
    final request = http.StreamedRequest(instruction.method, uri);
    request.contentLength = sizeBytes;
    request.headers.addAll(instruction.headers);
    if (instruction.strategy == 'local_proxy') {
      request.headers.addAll(_headers(requireToken()));
    }
    var sent = 0;
    final tracked = content.map((chunk) {
      sent += chunk.length;
      onProgress(
        sizeBytes <= 0 ? 0 : (sent / sizeBytes).clamp(0.0, 1.0).toDouble(),
      );
      return chunk;
    });
    final activeClient = client ?? http.Client();
    try {
      final responseFuture = activeClient.send(request);
      await request.sink.addStream(tracked);
      await request.sink.close();
      final streamed = await responseFuture;
      final response = await http.Response.fromStream(streamed);
      _requireChatSuccess(response, 'chat_media_upload_failed');
      onProgress(1);
    } finally {
      if (client == null) activeClient.close();
    }
  }

  Future<ChatMediaUpload> chatMediaStatus({
    required String conversationId,
    required String uploadId,
  }) async {
    final response = await _sendAuthorized(
      () => _get(
        _chatMediaUploadUri(conversationId, uploadId),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_media_status_failed');
    return _chatMediaFromResponse(response);
  }

  Future<ChatMediaUpload> chatCompleteMedia({
    required String conversationId,
    required String uploadId,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        _chatMediaUploadUri(conversationId, uploadId).replace(
          path:
              '${_chatMediaUploadUri(conversationId, uploadId).path}/complete',
        ),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_media_complete_failed');
    return _chatMediaFromResponse(response);
  }

  Future<void> chatCancelMedia({
    required String conversationId,
    required String uploadId,
  }) async {
    final response = await _sendAuthorized(
      () => _delete(
        _chatMediaUploadUri(conversationId, uploadId),
        headers: _headers(requireToken()),
      ),
    );
    _requireChatSuccess(response, 'chat_media_cancel_failed');
  }

  Uri chatMediaUri(String path) => Uri.parse(MobileApi.baseUrl).resolve(path);

  Map<String, String> chatMediaHeaders() => _headers(requireToken());

  Uri _chatMediaUploadUri(String conversationId, String uploadId) {
    return Uri.parse(
      '${MobileApi.baseUrl}/v1/mobile/chat/conversations/${Uri.encodeComponent(conversationId)}/media/uploads/${Uri.encodeComponent(uploadId)}',
    );
  }

  ChatMediaUpload _chatMediaFromResponse(http.Response response) {
    final payload = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    return ChatMediaUpload.fromJson(
      (payload['media'] as Map).cast<String, dynamic>(),
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
