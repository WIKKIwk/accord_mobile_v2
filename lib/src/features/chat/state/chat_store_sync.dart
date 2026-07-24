part of 'chat_store.dart';

extension ChatStoreReliability on ChatStore {
  void _ensureRealtimeStarted() {
    if (profileKey.isEmpty || _realtime.isRunning) return;
    _realtime.start(
      liveUri: MobileApi.instance.chatLiveUri,
      onEvent: _handleRealtimeEvent,
      onConnectionChanged: (value) {
        final changed = connected != value;
        connected = value;
        if (changed) notifyListeners();
        if (value) unawaited(_recoverChatState());
      },
    );
  }

  void _startReliabilityTimers() {
    if (_periodicSyncTimer?.isActive == true) return;
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_recoverChatState());
    });
  }

  void _cancelReliabilityTimers() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = null;
    _pendingRetryAt = null;
    _mediaRetryTimer?.cancel();
    _mediaRetryTimer = null;
    _mediaRetryAt = null;
  }

  void _clearRetryIdentity() {
    _retryClientMessageId = '';
    _retryConversationId = '';
    _retryBody = '';
  }

  Future<void> _recoverChatState() async {
    if (profileKey.isEmpty) return;
    try {
      await _synchronizeChat();
    } catch (error) {
      debugPrint('chat sync failed: ${error.runtimeType}: $error');
    }
    try {
      await _drainPendingMessages();
    } catch (error) {
      debugPrint('chat pending drain failed: ${error.runtimeType}: $error');
    }
    try {
      await _drainPendingMediaRetries();
    } catch (error) {
      debugPrint('chat media retry failed: ${error.runtimeType}: $error');
    }
    try {
      await _flushPendingReceipts();
    } catch (error) {
      debugPrint('chat receipt flush failed: ${error.runtimeType}: $error');
    }
  }

  Future<void> _synchronizeChat() {
    final existing = _syncOperation;
    if (existing != null) return existing;
    late final Future<void> operation;
    operation = _runSynchronization().whenComplete(() {
      if (identical(_syncOperation, operation)) _syncOperation = null;
    });
    _syncOperation = operation;
    return operation;
  }

  Future<void> _runSynchronization() async {
    final key = profileKey;
    if (key.isEmpty) return;
    var cursor = _syncCursor;
    var changed = false;
    for (var pageIndex = 0; pageIndex < 100; pageIndex++) {
      if (profileKey != key) return;
      final page = await MobileApi.instance.chatSync(cursor: cursor);
      if (profileKey != key) return;
      for (final event in page.events) {
        if ((event.event != 'chat.message.created' &&
                event.event != 'chat.message.updated') ||
            event.message == null) {
          continue;
        }
        final message = event.message!;
        changed = await _fillMessageGap(
              message.conversationId,
              message.sequence,
              expectedProfileKey: key,
            ) ||
            changed;
        if (profileKey != key) return;
        changed = await _acceptMessage(
              message,
              expectedProfileKey: key,
              requirePersistence: true,
            ) ||
            changed;
        if (profileKey != key) return;
        await _queueReceipt(
          message.conversationId,
          deliveredSequence: message.sequence,
          expectedProfileKey: key,
        );
        if (profileKey != key) return;
      }
      final previous = cursor;
      final next = page.nextCursor < cursor ? cursor : page.nextCursor;
      if (next != previous) {
        cursor = next;
        _syncCursor = cursor;
        await ChatLocalStore.instance.saveSyncCursor(key, cursor);
        if (profileKey != key) return;
      }
      if (!page.hasMore) break;
      if (next == previous && page.events.isEmpty) break;
    }
    if (profileKey != key) return;
    if (changed) await refreshConversations();
    if (profileKey != key) return;
    if (activeConversationId.isNotEmpty) {
      await markRead(activeConversationId);
    }
    await _flushPendingReceipts();
  }

  Future<void> _acceptRealtimeMessage(ChatMessage message) async {
    final key = profileKey;
    if (key.isEmpty) return;
    await _fillMessageGap(
      message.conversationId,
      message.sequence,
      expectedProfileKey: key,
    );
    if (profileKey != key) return;
    await _acceptMessage(message, expectedProfileKey: key);
    if (profileKey != key) return;
    await _queueReceipt(
      message.conversationId,
      deliveredSequence: message.sequence,
      expectedProfileKey: key,
    );
    if (profileKey != key) return;
    if (message.conversationId == activeConversationId) {
      await markRead(message.conversationId);
    } else {
      unawaited(_flushPendingReceipts());
    }
    unawaited(refreshConversations());
    unawaited(_synchronizeChat());
  }

  Future<bool> _fillMessageGap(
    String conversationId,
    int incomingSequence, {
    String? expectedProfileKey,
  }) async {
    final key = expectedProfileKey ?? profileKey;
    if (key.isEmpty || profileKey != key) return false;
    final current = _messages[conversationId] ?? const <ChatMessage>[];
    final knownSequence = current.isEmpty ? 0 : current.last.sequence;
    if (incomingSequence <= knownSequence + 1) return false;
    return _syncConversationAfterKnown(
      conversationId,
      expectedProfileKey: key,
    );
  }

  Future<bool> _syncConversationAfterKnown(
    String conversationId, {
    String? expectedProfileKey,
  }) async {
    final key = expectedProfileKey ?? profileKey;
    if (key.isEmpty || profileKey != key || conversationId.isEmpty) {
      return false;
    }
    var existing = _messages[conversationId] ?? const <ChatMessage>[];
    var cursor = existing.isEmpty ? 0 : existing.last.sequence;
    if (cursor == 0) {
      cursor = await ChatLocalStore.instance.latestMessageSequence(
        key,
        conversationId,
      );
      if (profileKey != key) return false;
    }
    var changed = false;
    for (var pageIndex = 0; pageIndex < 100; pageIndex++) {
      final page = await MobileApi.instance.chatMessages(
        conversationId,
        afterSequence: cursor,
      );
      if (profileKey != key) return false;
      if (page.items.isEmpty) break;
      final knownIds = existing.map((message) => message.messageId).toSet();
      changed = page.items.any(
            (message) => !knownIds.contains(message.messageId),
          ) ||
          changed;
      existing = ChatStore._mergeMessages(existing, page.items);
      _messages[conversationId] = existing;
      await ChatLocalStore.instance.saveMessages(key, page.items);
      if (profileKey != key) return false;
      for (final message in page.items) {
        await _queueReceipt(
          conversationId,
          deliveredSequence: message.sequence,
          expectedProfileKey: key,
        );
        if (profileKey != key) return false;
      }
      final next = page.items.last.sequence;
      if (next <= cursor) break;
      cursor = next;
      if (!page.hasMore) break;
    }
    notifyListeners();
    return changed;
  }

  Future<ChatMessage> _sendPendingMessage(
    String key,
    ChatPendingMessage pending,
  ) {
    final existing = _pendingSends[pending.clientMessageId];
    if (existing != null) return existing;
    late final Future<ChatMessage> operation;
    operation = _performPendingSend(key, pending).whenComplete(() {
      if (identical(_pendingSends[pending.clientMessageId], operation)) {
        _pendingSends.remove(pending.clientMessageId);
      }
    });
    _pendingSends[pending.clientMessageId] = operation;
    return operation;
  }

  Future<ChatMessage> _performPendingSend(
    String key,
    ChatPendingMessage pending,
  ) async {
    if (profileKey != key) throw StateError('chat_profile_changed');
    late final ChatMessage message;
    try {
      message = await _sendWithRetry(
        conversationId: pending.conversationId,
        clientMessageId: pending.clientMessageId,
        body: pending.body,
        expectedProfileKey: key,
      );
    } catch (error) {
      final attempts = pending.attempts + 1;
      final transient = isTransientChatFailure(error);
      final delaySeconds = transient
          ? (1 << attempts.clamp(1, 8).toInt()).clamp(2, 300).toInt()
          : 60 * 60 * 24;
      final updated = pending.copyWith(
        attempts: attempts,
        nextAttemptAtUnix:
            DateTime.now().millisecondsSinceEpoch ~/ 1000 + delaySeconds,
        lastError: error.toString(),
        autoRetry: transient,
      );
      await ChatLocalStore.instance.savePendingMessage(key, updated);
      if (transient && profileKey == key) {
        _schedulePendingRetry(Duration(seconds: delaySeconds));
      }
      rethrow;
    }
    try {
      await ChatLocalStore.instance.removePendingMessage(
        key,
        pending.clientMessageId,
      );
    } catch (error) {
      debugPrint(
        'chat message accepted by server but local outbox cleanup failed: '
        '${error.runtimeType}: $error',
      );
    }
    if (profileKey != key) return message;
    try {
      await _acceptMessage(message, expectedProfileKey: key);
    } catch (stateError) {
      debugPrint(
        'chat message accepted by server but local state update failed: '
        '${stateError.runtimeType}: $stateError',
      );
    }
    if (profileKey != key) return message;
    if (_retryClientMessageId == pending.clientMessageId) {
      _clearRetryIdentity();
    }
    try {
      await _queueReceipt(
        pending.conversationId,
        deliveredSequence: message.sequence,
        expectedProfileKey: key,
      );
    } catch (error) {
      debugPrint(
        'chat message accepted by server but delivery receipt queue failed: '
        '${error.runtimeType}: $error',
      );
    }
    return message;
  }

  Future<void> _drainPendingMessages() async {
    if (_pendingDrainRunning) {
      _pendingDrainRequested = true;
      return;
    }
    final key = profileKey;
    if (key.isEmpty) return;
    _pendingDrainRunning = true;
    var sentAny = false;
    try {
      do {
        _pendingDrainRequested = false;
        final pending = await ChatLocalStore.instance.loadPendingMessages(key);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final item in pending) {
          if (profileKey != key) return;
          if (!item.autoRetry || item.nextAttemptAtUnix > now) continue;
          try {
            await _sendPendingMessage(key, item);
            sentAny = true;
          } catch (_) {
            // The item remains durable with its own retry deadline. Continue so
            // one broken conversation cannot block the rest of the outbox.
          }
        }
      } while (_pendingDrainRequested && profileKey == key);
    } finally {
      _pendingDrainRunning = false;
      await _scheduleNextPendingRetry(key);
    }
    if (sentAny) await refreshConversations();
  }

  Future<void> _scheduleNextPendingRetry(String key) async {
    if (profileKey != key) return;
    final pending = await ChatLocalStore.instance.loadPendingMessages(key);
    if (profileKey != key) return;
    final automatic = pending.where((item) => item.autoRetry).toList();
    if (automatic.isEmpty) {
      _pendingRetryTimer?.cancel();
      _pendingRetryTimer = null;
      _pendingRetryAt = null;
      return;
    }
    final nextUnix = automatic
        .map((item) => item.nextAttemptAtUnix)
        .reduce((left, right) => left < right ? left : right);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _schedulePendingRetry(
      Duration(seconds: (nextUnix - now).clamp(0, 86400).toInt()),
    );
  }

  void _schedulePendingRetry(Duration delay) {
    if (profileKey.isEmpty) return;
    final target = DateTime.now().add(delay);
    final current = _pendingRetryAt;
    if (_pendingRetryTimer?.isActive == true &&
        current != null &&
        !target.isBefore(current)) {
      return;
    }
    _pendingRetryTimer?.cancel();
    _pendingRetryAt = target;
    _pendingRetryTimer = Timer(delay, () {
      _pendingRetryTimer = null;
      _pendingRetryAt = null;
      unawaited(_drainPendingMessages());
    });
  }

  Future<void> _queueReceipt(
    String conversationId, {
    int deliveredSequence = 0,
    int readSequence = 0,
    String? expectedProfileKey,
  }) async {
    final key = expectedProfileKey ?? profileKey;
    if (key.isEmpty || profileKey != key || conversationId.isEmpty) return;
    await ChatLocalStore.instance.savePendingReceipt(
      key,
      ChatPendingReceipt(
        conversationId: conversationId,
        deliveredSequence: deliveredSequence,
        readSequence: readSequence,
      ),
    );
    if (profileKey == key && _receiptFlushRunning) {
      _receiptFlushRequested = true;
    }
  }

  Future<void> _flushPendingReceipts() async {
    if (_receiptFlushRunning) {
      _receiptFlushRequested = true;
      return;
    }
    if (profileKey.isEmpty) return;
    final key = profileKey;
    _receiptFlushRunning = true;
    try {
      do {
        _receiptFlushRequested = false;
        final deviceId = await ChatStore._deviceId();
        final receipts = await ChatLocalStore.instance.loadPendingReceipts(key);
        for (final receipt in receipts) {
          if (profileKey != key) return;
          var deliveredAcknowledged = 0;
          if (receipt.deliveredSequence > 0) {
            try {
              await MobileApi.instance.chatMarkDelivered(
                conversationId: receipt.conversationId,
                sequence: receipt.deliveredSequence,
                deviceId: deviceId,
              );
              if (profileKey != key) return;
              deliveredAcknowledged = receipt.deliveredSequence;
            } catch (_) {
              continue;
            }
          }
          var readAcknowledged = 0;
          if (receipt.readSequence > 0) {
            try {
              await MobileApi.instance.chatMarkRead(
                conversationId: receipt.conversationId,
                sequence: receipt.readSequence,
                deviceId: deviceId,
              );
              if (profileKey != key) return;
              readAcknowledged = receipt.readSequence;
            } catch (_) {
              await ChatLocalStore.instance.acknowledgePendingReceipt(
                key,
                receipt.conversationId,
                deliveredSequence: deliveredAcknowledged,
              );
              continue;
            }
          }
          await ChatLocalStore.instance.acknowledgePendingReceipt(
            key,
            receipt.conversationId,
            deliveredSequence: deliveredAcknowledged,
            readSequence: readAcknowledged,
          );
        }
      } while (_receiptFlushRequested && profileKey == key);
    } finally {
      _receiptFlushRunning = false;
    }
  }
}
