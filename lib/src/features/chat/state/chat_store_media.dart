part of 'chat_store.dart';

const Duration _mediaStatusPollInterval = Duration(seconds: 1);
const int _mediaStatusPollLimit = 3600;

extension ChatStoreMedia on ChatStore {
  List<ChatPendingMedia> pendingMediaFor(String conversationId) {
    return _pendingMedia[conversationId] ?? const <ChatPendingMedia>[];
  }

  Future<void> queueMedia({
    required String conversationId,
    required XFile source,
    required ChatMediaKind kind,
    String caption = '',
    int durationMs = 0,
    bool deleteSourceAfterPersist = false,
  }) async {
    await startForCurrentSession();
    final key = profileKey;
    if (key.isEmpty || conversationId.trim().isEmpty) {
      throw const MobileApiException(
        code: 'authentication_required',
        message: 'Chat sessiyasi tayyor emas',
        statusCode: 401,
      );
    }
    final sizeBytes = await source.length();
    if (profileKey != key) throw StateError('chat_profile_changed');
    final maximum = switch (kind) {
      ChatMediaKind.image => chatMediaImageMaxBytes,
      ChatMediaKind.video => chatMediaVideoMaxBytes,
      ChatMediaKind.audio => chatMediaAudioMaxBytes,
    };
    if (sizeBytes <= 0 || sizeBytes > maximum) {
      throw MobileApiException(
        code: 'chat_media_too_large',
        message: switch (kind) {
          ChatMediaKind.image => 'Rasm 15 MiB dan oshmasligi kerak.',
          ChatMediaKind.video =>
            'Video 2 GiB va 10 daqiqadan oshmasligi kerak.',
          ChatMediaKind.audio =>
            'Ovozli xabar 64 MiB va 10 daqiqadan oshmasligi kerak.',
        },
        statusCode: 413,
      );
    }
    if (kind == ChatMediaKind.video &&
        durationMs > chatMediaVideoMaxDuration.inMilliseconds) {
      throw const MobileApiException(
        code: 'video_duration_too_long',
        message: 'Video 10 daqiqa (600 soniya)dan oshmasligi kerak.',
        statusCode: 422,
      );
    }
    if (kind == ChatMediaKind.audio && durationMs <= 0) {
      throw const MobileApiException(
        code: 'chat_media_input_invalid',
        message: 'Ovozli xabar davomiyligi aniqlanmadi.',
        statusCode: 400,
      );
    }
    if (kind == ChatMediaKind.audio &&
        durationMs > chatMediaAudioMaxDuration.inMilliseconds) {
      throw const MobileApiException(
        code: 'audio_duration_too_long',
        message: 'Ovozli xabar 10 daqiqadan oshmasligi kerak.',
        statusCode: 422,
      );
    }
    final localId = _newMediaId('local_media');
    final filename = _safeMediaFilename(source.name, localId, kind);
    final contentType = _mediaContentType(
      filename: filename,
      declared: source.mimeType,
      kind: kind,
    );
    if (contentType.isEmpty) {
      throw MobileApiException(
        code: 'chat_media_input_invalid',
        message: switch (kind) {
          ChatMediaKind.image =>
            'Faqat JPEG, PNG yoki WebP rasm yuborish mumkin.',
          ChatMediaKind.video =>
            'Faqat MP4, MOV yoki WebM video yuborish mumkin.',
          ChatMediaKind.audio => 'Ovozli xabar formati qo‘llab-quvvatlanmaydi.',
        },
        statusCode: 400,
      );
    }
    final pending = ChatPendingMedia(
      localId: localId,
      conversationId: conversationId.trim(),
      clientMessageId: ChatStore._newClientMessageId(),
      clientUploadId: _newMediaId('client_upload'),
      kind: kind,
      localPath: '',
      filename: filename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      caption: caption.trim(),
      status: ChatPendingMediaStatus.preparing,
      progress: 0,
      createdAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      durationMs: kind == ChatMediaKind.image ? 0 : durationMs,
    );
    _insertPendingMedia(pending);
    await _preparePendingMedia(
      key,
      pending,
      source,
      deleteSourceAfterPersist: deleteSourceAfterPersist,
    );
  }

  Future<void> retryMedia(String localId) async {
    final key = profileKey;
    final pending = _pendingMediaById(localId);
    if (key.isEmpty || pending == null || _runningMedia.contains(localId)) {
      return;
    }
    final updated = await _replacePendingMedia(
      key,
      localId,
      (current) => current.copyWith(
        status: ChatPendingMediaStatus.preparing,
        progress: 0,
        error: '',
        retryAttempts: 0,
        nextRetryAtUnix: 0,
        autoRetry: false,
      ),
    );
    if (updated == null || profileKey != key) return;
    unawaited(_runPendingMedia(key, localId, allowRestart: true));
  }

  Future<void> cancelMedia(String localId) async {
    final key = profileKey;
    final pending = _pendingMediaById(localId);
    if (key.isEmpty || pending == null) return;
    if (pending.status == ChatPendingMediaStatus.sending ||
        pending.status == ChatPendingMediaStatus.sent) {
      return;
    }
    final updated = await _replacePendingMedia(
      key,
      localId,
      (current) => current.copyWith(
        status: ChatPendingMediaStatus.cancelled,
        error: '',
      ),
    );
    if (updated == null || profileKey != key) return;
    _mediaUploadClients.remove(localId)?.close();
    if (pending.uploadId.isNotEmpty) {
      try {
        await MobileApi.instance.chatCancelMedia(
          conversationId: pending.conversationId,
          uploadId: pending.uploadId,
        );
      } catch (_) {}
    }
  }

  Future<void> clearPendingMediaForProfile(SessionProfile profile) async {
    final key = ChatStore._keyFor(profile);
    _clearingMediaProfiles.add(key);
    if (profileKey == key) {
      for (final client in _mediaUploadClients.values) {
        client.close();
      }
      _mediaUploadClients.clear();
    }
    final byId = <String, ChatPendingMedia>{};
    for (final items in _pendingMedia.values) {
      for (final item in items) {
        byId[item.localId] = item;
      }
    }
    try {
      for (final item in await ChatLocalStore.instance.clearPendingMedia(key)) {
        byId[item.localId] = item;
      }
    } catch (_) {}
    for (final item in byId.values) {
      if (item.localPath.isEmpty) continue;
      try {
        await deleteChatMediaFile(item.localPath);
      } catch (_) {}
    }
    if (profileKey == key) {
      _pendingMedia.clear();
      notifyListeners();
    }
  }

  Future<void> _restorePendingMedia(String key) async {
    List<ChatPendingMedia> pending;
    try {
      pending = await ChatLocalStore.instance.loadPendingMedia(key);
    } catch (_) {
      return;
    }
    if (profileKey != key || _clearingMediaProfiles.contains(key)) return;
    _pendingMedia.clear();
    for (final item in pending) {
      if (item.status == ChatPendingMediaStatus.sent) {
        unawaited(_removePendingMedia(key, item));
        continue;
      }
      _insertPendingMedia(item, notify: false);
    }
    notifyListeners();
    for (final item in pending) {
      if (item.status != ChatPendingMediaStatus.failed &&
          item.status != ChatPendingMediaStatus.cancelled &&
          item.status != ChatPendingMediaStatus.sent) {
        unawaited(_runPendingMedia(key, item.localId));
      }
    }
    unawaited(_drainPendingMediaRetries());
  }

  Future<void> _preparePendingMedia(
    String key,
    ChatPendingMedia pending,
    XFile source, {
    required bool deleteSourceAfterPersist,
  }) async {
    String persistedPath = '';
    try {
      persistedPath = await persistChatMediaFile(source, pending.localId);
      if (deleteSourceAfterPersist && source.path != persistedPath) {
        try {
          await deleteChatMediaFile(source.path);
        } catch (_) {}
      }
      if (profileKey != key || _clearingMediaProfiles.contains(key)) {
        await deleteChatMediaFile(persistedPath);
        return;
      }
      final updated = await _replacePendingMedia(
        key,
        pending.localId,
        (current) => current.copyWith(localPath: persistedPath),
      );
      if (updated == null) {
        await deleteChatMediaFile(persistedPath);
        return;
      }
      unawaited(_runPendingMedia(key, pending.localId));
    } catch (error) {
      if (deleteSourceAfterPersist && source.path != persistedPath) {
        try {
          await deleteChatMediaFile(source.path);
        } catch (_) {}
      }
      if (persistedPath.isNotEmpty && profileKey != key) {
        try {
          await deleteChatMediaFile(persistedPath);
        } catch (_) {}
      }
      await _markPendingMediaFailed(key, pending.localId, error);
    }
  }

  Future<void> _runPendingMedia(
    String key,
    String localId, {
    bool allowRestart = false,
  }) async {
    if (_runningMedia.contains(localId) ||
        profileKey != key ||
        _clearingMediaProfiles.contains(key)) {
      return;
    }
    _runningMedia.add(localId);
    try {
      var mayRestart = allowRestart;
      while (profileKey == key && !_clearingMediaProfiles.contains(key)) {
        var pending = _pendingMediaById(localId);
        if (pending == null) return;
        _throwIfMediaCancelled(pending);

        ChatMediaUpload serverMedia;
        ChatMediaUploadInstruction? instruction;
        if (pending.uploadId.isEmpty) {
          final initialized = await _initializePendingMedia(pending);
          _throwIfMediaProfileChanged(key);
          serverMedia = initialized.media;
          instruction = initialized.upload;
          pending = (await _replacePendingMedia(
            key,
            localId,
            (current) => current.copyWith(
              mediaId: initialized.media.mediaId,
              uploadId: initialized.media.uploadId,
              error: '',
            ),
          ))!;
        } else {
          try {
            serverMedia = await MobileApi.instance.chatMediaStatus(
              conversationId: pending.conversationId,
              uploadId: pending.uploadId,
            );
            _throwIfMediaProfileChanged(key);
          } catch (error) {
            if (mayRestart &&
                error is MobileApiException &&
                error.statusCode == 404) {
              await _resetPendingUpload(key, localId);
              mayRestart = false;
              continue;
            }
            rethrow;
          }
        }

        if (serverMedia.terminalFailure) {
          if (mayRestart) {
            await _resetPendingUpload(key, localId);
            mayRestart = false;
            continue;
          }
          throw MobileApiException(
            code: serverMedia.errorCode.isEmpty
                ? 'chat_media_processing_failed'
                : serverMedia.errorCode,
            message: 'Media fayl qayta ishlanmadi',
            statusCode: 422,
          );
        }

        if (serverMedia.status == 'pending') {
          if (instruction == null) {
            final initialized = await _initializePendingMedia(pending);
            _throwIfMediaProfileChanged(key);
            serverMedia = initialized.media;
            instruction = initialized.upload;
          }
          if (serverMedia.status == 'pending') {
            if (pending.localPath.isEmpty ||
                !await chatMediaFileExists(pending.localPath)) {
              throw StateError('chat_media_local_file_missing');
            }
            await _replacePendingMedia(
              key,
              localId,
              (current) => current.copyWith(
                status: ChatPendingMediaStatus.uploading,
                progress: serverMedia.sizeBytes <= 0
                    ? 0
                    : (serverMedia.uploadedBytes / serverMedia.sizeBytes)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                error: '',
              ),
            );
            final client = http.Client();
            _mediaUploadClients[localId] = client;
            try {
              if (serverMedia.chunked) {
                serverMedia = await _uploadPendingVideoChunks(
                  key: key,
                  localId: localId,
                  pending: pending,
                  serverMedia: serverMedia,
                  instruction: instruction,
                  client: client,
                );
                _throwIfMediaProfileChanged(key);
              } else {
                await MobileApi.instance.chatUploadMedia(
                  instruction: instruction,
                  content: XFile(pending.localPath).openRead(),
                  sizeBytes: pending.sizeBytes,
                  client: client,
                  onProgress: (progress) =>
                      _updatePendingMediaProgress(key, localId, progress),
                );
                _throwIfMediaProfileChanged(key);
              }
            } finally {
              if (identical(_mediaUploadClients[localId], client)) {
                _mediaUploadClients.remove(localId);
              }
              client.close();
            }
            pending = _pendingMediaById(localId)!;
            _throwIfMediaCancelled(pending);
            serverMedia = await MobileApi.instance.chatCompleteMedia(
              conversationId: pending.conversationId,
              uploadId: pending.uploadId,
            );
            _throwIfMediaProfileChanged(key);
          }
        } else if (serverMedia.status == 'uploaded') {
          serverMedia = await MobileApi.instance.chatCompleteMedia(
            conversationId: pending.conversationId,
            uploadId: pending.uploadId,
          );
          _throwIfMediaProfileChanged(key);
        }

        if (serverMedia.status == 'processing') {
          await _replacePendingMedia(
            key,
            localId,
            (current) => current.copyWith(
              status: ChatPendingMediaStatus.processing,
              progress: 1,
              error: '',
            ),
          );
          serverMedia = await _waitForReadyMedia(key, localId, serverMedia);
          _throwIfMediaProfileChanged(key);
        }
        if (!serverMedia.ready) {
          throw StateError(
              'chat_media_unexpected_status_${serverMedia.status}');
        }

        pending = (await _replacePendingMedia(
          key,
          localId,
          (current) => current.copyWith(
            status: ChatPendingMediaStatus.sending,
            progress: 1,
            mediaId: serverMedia.mediaId,
            uploadId: serverMedia.uploadId,
            error: '',
          ),
        ))!;
        final message = await MobileApi.instance.chatSendMessage(
          conversationId: pending.conversationId,
          clientMessageId: pending.clientMessageId,
          body: pending.caption,
          mediaId: serverMedia.mediaId,
        );
        _throwIfMediaProfileChanged(key);
        await _acceptMessage(message, expectedProfileKey: key);
        if (pending.kind != ChatMediaKind.image &&
            pending.localPath.isNotEmpty) {
          try {
            await promoteChatMediaFile(pending.localPath, serverMedia.mediaId);
          } catch (_) {
            // Network playback remains available when local cache promotion fails.
          }
        }
        final sent = await _replacePendingMedia(
          key,
          localId,
          (current) => current.copyWith(
            status: ChatPendingMediaStatus.sent,
            progress: 1,
            error: '',
            retryAttempts: 0,
            nextRetryAtUnix: 0,
            autoRetry: false,
          ),
        );
        if (sent != null) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await _removePendingMedia(key, sent);
        }
        unawaited(refreshConversations());
        return;
      }
    } on _ChatMediaCancelled {
      return;
    } catch (error) {
      await _markPendingMediaFailed(key, localId, error);
    } finally {
      _runningMedia.remove(localId);
    }
  }

  Future<ChatMediaInitialization> _initializePendingMedia(
    ChatPendingMedia pending,
  ) {
    return MobileApi.instance.chatInitializeMedia(
      conversationId: pending.conversationId,
      clientUploadId: pending.clientUploadId,
      kind: pending.kind,
      filename: pending.filename,
      contentType: pending.contentType,
      sizeBytes: pending.sizeBytes,
      durationMs: pending.durationMs > 0 ? pending.durationMs : null,
    );
  }

  Future<ChatMediaUpload> _uploadPendingVideoChunks({
    required String key,
    required String localId,
    required ChatPendingMedia pending,
    required ChatMediaUpload serverMedia,
    required ChatMediaUploadInstruction instruction,
    required http.Client client,
  }) async {
    final chunkSize = instruction.chunkSizeBytes > 0
        ? instruction.chunkSizeBytes
        : serverMedia.chunkSizeBytes;
    final totalChunks = instruction.totalChunks > 0
        ? instruction.totalChunks
        : serverMedia.totalChunks;
    if (!instruction.resumable ||
        chunkSize <= 0 ||
        totalChunks <= 0 ||
        totalChunks != serverMedia.totalChunks ||
        chunkSize != serverMedia.chunkSizeBytes) {
      throw StateError('chat_media_chunk_configuration_invalid');
    }

    final uploaded = serverMedia.uploadedChunkIndexes;
    var uploadedBytes = 0;
    for (final index in uploaded) {
      if (index < 0 || index >= totalChunks) {
        throw StateError('chat_media_chunk_configuration_invalid');
      }
      uploadedBytes += chatMediaChunkBounds(
        index: index,
        chunkSizeBytes: chunkSize,
        totalSizeBytes: pending.sizeBytes,
      ).sizeBytes;
    }
    _updatePendingMediaProgress(
      key,
      localId,
      uploadedBytes / pending.sizeBytes,
    );

    var current = serverMedia;
    for (var index = 0; index < totalChunks; index++) {
      if (uploaded.contains(index)) continue;
      final active = _pendingMediaById(localId);
      if (active == null) throw const _ChatMediaCancelled();
      _throwIfMediaCancelled(active);
      final bounds = chatMediaChunkBounds(
        index: index,
        chunkSizeBytes: chunkSize,
        totalSizeBytes: pending.sizeBytes,
      );
      final completedBeforeChunk = uploadedBytes;
      current = await MobileApi.instance.chatUploadMediaChunk(
        instruction: instruction,
        bounds: bounds,
        content: XFile(pending.localPath).openRead(
          bounds.startByte,
          bounds.endByteExclusive,
        ),
        client: client,
        onProgress: (chunkProgress) {
          final bytes =
              completedBeforeChunk + (bounds.sizeBytes * chunkProgress).round();
          _updatePendingMediaProgress(
            key,
            localId,
            bytes / pending.sizeBytes,
          );
        },
      );
      _throwIfMediaProfileChanged(key);
      uploadedBytes += bounds.sizeBytes;
      uploaded.add(index);
    }
    return current;
  }

  Future<ChatMediaUpload> _waitForReadyMedia(
    String key,
    String localId,
    ChatMediaUpload current,
  ) async {
    var media = current;
    for (var attempt = 0; attempt < _mediaStatusPollLimit; attempt++) {
      final pending = _pendingMediaById(localId);
      if (pending == null || profileKey != key) {
        throw const _ChatMediaCancelled();
      }
      _throwIfMediaCancelled(pending);
      if (media.ready || media.terminalFailure) break;
      await Future<void>.delayed(_mediaStatusPollInterval);
      media = await MobileApi.instance.chatMediaStatus(
        conversationId: pending.conversationId,
        uploadId: pending.uploadId,
      );
      _throwIfMediaProfileChanged(key);
    }
    if (media.terminalFailure) {
      throw MobileApiException(
        code: media.errorCode.isEmpty
            ? 'chat_media_processing_failed'
            : media.errorCode,
        message: 'Media fayl qayta ishlanmadi',
        statusCode: 422,
      );
    }
    if (!media.ready) {
      throw TimeoutException('chat_media_processing_timeout');
    }
    _throwIfMediaProfileChanged(key);
    return media;
  }

  Future<void> _resetPendingUpload(String key, String localId) async {
    await _replacePendingMedia(
      key,
      localId,
      (current) => current.copyWith(
        clientUploadId: _newMediaId('client_upload'),
        mediaId: '',
        uploadId: '',
        status: ChatPendingMediaStatus.preparing,
        progress: 0,
        error: '',
      ),
    );
  }

  Future<void> _markPendingMediaFailed(
    String key,
    String localId,
    Object error,
  ) async {
    final current = _pendingMediaById(localId);
    if (current == null ||
        current.status == ChatPendingMediaStatus.cancelled ||
        profileKey != key ||
        _clearingMediaProfiles.contains(key)) {
      return;
    }
    final transient = isTransientChatFailure(error);
    final attempts = current.retryAttempts + 1;
    final delaySeconds =
        (1 << attempts.clamp(1, 8).toInt()).clamp(2, 300).toInt();
    await _replacePendingMedia(
      key,
      localId,
      (pending) => pending.copyWith(
        status: ChatPendingMediaStatus.failed,
        error: chatMediaFailureMessage(error),
        retryAttempts: attempts,
        nextRetryAtUnix: transient
            ? DateTime.now().millisecondsSinceEpoch ~/ 1000 + delaySeconds
            : 0,
        autoRetry: transient,
      ),
    );
    if (transient) {
      _scheduleMediaRetry(Duration(seconds: delaySeconds));
    }
  }

  Future<void> _drainPendingMediaRetries() async {
    final key = profileKey;
    if (key.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final retryable = _pendingMedia.values
        .expand((items) => items)
        .where(
          (item) =>
              item.status == ChatPendingMediaStatus.failed && item.autoRetry,
        )
        .toList(growable: false);
    for (final item in retryable) {
      if (profileKey != key) return;
      if (item.nextRetryAtUnix > now) continue;
      final updated = await _replacePendingMedia(
        key,
        item.localId,
        (current) => current.copyWith(
          status: ChatPendingMediaStatus.preparing,
          error: '',
          nextRetryAtUnix: 0,
          autoRetry: false,
        ),
      );
      if (updated != null) {
        await _runPendingMedia(key, item.localId, allowRestart: true);
      }
    }
    if (profileKey != key) return;
    final nextRetry = _pendingMedia.values
        .expand((items) => items)
        .where(
          (item) =>
              item.status == ChatPendingMediaStatus.failed &&
              item.autoRetry &&
              item.nextRetryAtUnix > 0,
        )
        .map((item) => item.nextRetryAtUnix)
        .fold<int?>(null, (current, value) {
      if (current == null || value < current) return value;
      return current;
    });
    if (nextRetry != null) {
      final currentUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _scheduleMediaRetry(
        Duration(seconds: (nextRetry - currentUnix).clamp(0, 300).toInt()),
      );
    }
  }

  void _scheduleMediaRetry(Duration delay) {
    if (profileKey.isEmpty) return;
    final target = DateTime.now().add(delay);
    final current = _mediaRetryAt;
    if (_mediaRetryTimer?.isActive == true &&
        current != null &&
        !target.isBefore(current)) {
      return;
    }
    _mediaRetryTimer?.cancel();
    _mediaRetryAt = target;
    _mediaRetryTimer = Timer(delay, () {
      _mediaRetryTimer = null;
      _mediaRetryAt = null;
      unawaited(_drainPendingMediaRetries());
    });
  }

  void _insertPendingMedia(ChatPendingMedia pending, {bool notify = true}) {
    final current = _pendingMedia[pending.conversationId] ?? const [];
    final next = [
      ...current.where((item) => item.localId != pending.localId),
      pending
    ]..sort((left, right) => left.createdAtUnix.compareTo(right.createdAtUnix));
    _pendingMedia[pending.conversationId] =
        List<ChatPendingMedia>.unmodifiable(next);
    if (notify) notifyListeners();
  }

  ChatPendingMedia? _pendingMediaById(String localId) {
    for (final items in _pendingMedia.values) {
      for (final item in items) {
        if (item.localId == localId) return item;
      }
    }
    return null;
  }

  Future<ChatPendingMedia?> _replacePendingMedia(
    String key,
    String localId,
    ChatPendingMedia Function(ChatPendingMedia current) update,
  ) async {
    if (profileKey != key || _clearingMediaProfiles.contains(key)) return null;
    final current = _pendingMediaById(localId);
    if (current == null) return null;
    final next = update(current);
    final items = <ChatPendingMedia>[
      ...(_pendingMedia[current.conversationId] ?? const <ChatPendingMedia>[]),
    ];
    final index = items.indexWhere((item) => item.localId == localId);
    if (index < 0) return null;
    items[index] = next;
    _pendingMedia[current.conversationId] =
        List<ChatPendingMedia>.unmodifiable(items);
    notifyListeners();
    await _persistPendingMedia(key, next);
    if (profileKey != key || _clearingMediaProfiles.contains(key)) return null;
    return next;
  }

  void _updatePendingMediaProgress(
      String key, String localId, double progress) {
    if (profileKey != key || _clearingMediaProfiles.contains(key)) return;
    final current = _pendingMediaById(localId);
    if (current == null || current.status != ChatPendingMediaStatus.uploading) {
      return;
    }
    final value = progress.clamp(0.0, 1.0).toDouble();
    if ((current.progress - value).abs() < 0.015 && value < 1) return;
    final next = current.copyWith(progress: value);
    final items = <ChatPendingMedia>[
      ...(_pendingMedia[current.conversationId] ?? const <ChatPendingMedia>[]),
    ];
    final index = items.indexWhere((item) => item.localId == localId);
    if (index < 0) return;
    items[index] = next;
    _pendingMedia[current.conversationId] =
        List<ChatPendingMedia>.unmodifiable(items);
    notifyListeners();
  }

  Future<void> _persistPendingMedia(
      String key, ChatPendingMedia pending) async {
    try {
      await ChatLocalStore.instance.savePendingMedia(key, pending);
    } catch (_) {
      if (!kIsWeb) rethrow;
    }
  }

  Future<void> _removePendingMedia(String key, ChatPendingMedia pending) async {
    if (profileKey == key) {
      final items = <ChatPendingMedia>[
        ...(_pendingMedia[pending.conversationId] ??
            const <ChatPendingMedia>[]),
      ]..removeWhere((item) => item.localId == pending.localId);
      if (items.isEmpty) {
        _pendingMedia.remove(pending.conversationId);
      } else {
        _pendingMedia[pending.conversationId] =
            List<ChatPendingMedia>.unmodifiable(items);
      }
      notifyListeners();
    }
    try {
      await ChatLocalStore.instance.removePendingMedia(key, pending.localId);
    } catch (_) {}
    if (pending.localPath.isNotEmpty) {
      try {
        await deleteChatMediaFile(pending.localPath);
      } catch (_) {}
    }
  }

  void _throwIfMediaCancelled(ChatPendingMedia pending) {
    if (pending.status == ChatPendingMediaStatus.cancelled) {
      throw const _ChatMediaCancelled();
    }
  }

  void _throwIfMediaProfileChanged(String key) {
    if (profileKey != key || _clearingMediaProfiles.contains(key)) {
      throw const _ChatMediaCancelled();
    }
  }
}

class _ChatMediaCancelled implements Exception {
  const _ChatMediaCancelled();
}

String _newMediaId(String prefix) {
  final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$random';
}

String _safeMediaFilename(String raw, String localId, ChatMediaKind kind) {
  var value = raw.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '_');
  if (value.isEmpty) {
    value = switch (kind) {
      ChatMediaKind.image => '$localId.jpg',
      ChatMediaKind.video => '$localId.mp4',
      ChatMediaKind.audio => '$localId.m4a',
    };
  }
  if (value.length > 240) value = value.substring(value.length - 240);
  return value;
}

String _mediaContentType({
  required String filename,
  required String? declared,
  required ChatMediaKind kind,
}) {
  final normalized = declared?.trim().toLowerCase() ?? '';
  final allowed = switch (kind) {
    ChatMediaKind.image => const {'image/jpeg', 'image/png', 'image/webp'},
    ChatMediaKind.video => const {
        'video/mp4',
        'video/quicktime',
        'video/webm',
      },
    ChatMediaKind.audio => const {
        'audio/mp4',
        'audio/x-m4a',
        'audio/aac',
        'audio/mpeg',
        'audio/ogg',
        'audio/webm',
        'audio/wav',
        'audio/x-wav',
      },
  };
  if (allowed.contains(normalized)) return normalized;
  final lower = filename.toLowerCase();
  if (kind == ChatMediaKind.image) {
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
  } else if (kind == ChatMediaKind.video) {
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
  } else {
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.wav')) return 'audio/wav';
  }
  return '';
}
