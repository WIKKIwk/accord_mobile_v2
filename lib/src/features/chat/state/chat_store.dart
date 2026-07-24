import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../shared/models/app_models.dart';
import '../data/chat_local_store.dart';
import '../data/chat_media_file_store.dart';
import '../models/chat_media_models.dart';
import '../models/chat_models.dart';
import '../realtime/chat_realtime_service.dart';
import 'chat_failure.dart';

part 'chat_store_media.dart';
part 'chat_store_sync.dart';

class ChatStore extends ChangeNotifier {
  ChatStore._();

  static final ChatStore instance = ChatStore._();
  static const _deviceIdKey = 'chat_device_id_v1';
  static const _sendTimeout = Duration(seconds: 15);

  final ChatRealtimeService _realtime = ChatRealtimeService();
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, bool> _hasMoreMessages = {};
  final Set<String> _loadingMessages = {};
  final Map<String, List<ChatPendingMedia>> _pendingMedia = {};
  final Map<String, http.Client> _mediaUploadClients = {};
  final Set<String> _runningMedia = {};
  final Set<String> _clearingMediaProfiles = {};
  final Map<String, Future<ChatMessage>> _pendingSends = {};
  Timer? _pendingRetryTimer;
  DateTime? _pendingRetryAt;
  Timer? _periodicSyncTimer;
  Timer? _mediaRetryTimer;
  DateTime? _mediaRetryAt;
  Future<void>? _syncOperation;
  Future<void>? _conversationRefreshOperation;
  bool _conversationRefreshRequested = false;
  bool _pendingDrainRunning = false;
  bool _pendingDrainRequested = false;
  bool _receiptFlushRunning = false;
  bool _receiptFlushRequested = false;
  int _syncCursor = 0;
  String _retryClientMessageId = '';
  String _retryConversationId = '';
  String _retryBody = '';

  List<ChatConversation> conversations = const [];
  List<ChatDirectoryEntry> directory = const [];
  String profileKey = '';
  String activeConversationId = '';
  bool loadingConversations = false;
  bool loadingDirectory = false;
  bool connected = false;
  bool sending = false;
  String error = '';
  String sendError = '';
  final ValueNotifier<int> unreadCountListenable = ValueNotifier<int>(0);

  int get totalUnread => conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.unreadCount,
      );

  @override
  void notifyListeners() {
    final unreadCount = totalUnread;
    if (unreadCountListenable.value != unreadCount) {
      unreadCountListenable.value = unreadCount;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _realtime.stop();
    _cancelReliabilityTimers();
    unreadCountListenable.dispose();
    super.dispose();
  }

  List<ChatMessage> messagesFor(String conversationId) =>
      _messages[conversationId] ?? const <ChatMessage>[];

  bool hasMoreMessages(String conversationId) =>
      _hasMoreMessages[conversationId] ?? false;

  bool loadingMessagesFor(String conversationId) =>
      _loadingMessages.contains(conversationId);

  Future<void> startForCurrentSession() async {
    final profile = AppSession.instance.profile;
    if (profile == null || !AppSession.instance.isLoggedIn) {
      clearMemory();
      return;
    }
    if (profile.role == UserRole.customer) {
      clearMemory();
      return;
    }
    final nextKey = _keyFor(profile);
    if (nextKey == profileKey) {
      _ensureRealtimeStarted();
      _startReliabilityTimers();
      unawaited(_recoverChatState());
      if (conversations.isEmpty) await refreshConversations();
      return;
    }
    _realtime.stop();
    _syncOperation = null;
    _conversationRefreshOperation = null;
    _conversationRefreshRequested = false;
    loadingConversations = false;
    profileKey = nextKey;
    conversations = const [];
    directory = const [];
    _messages.clear();
    _hasMoreMessages.clear();
    _loadingMessages.clear();
    activeConversationId = '';
    error = '';
    notifyListeners();

    try {
      conversations = (await ChatLocalStore.instance.loadConversations(nextKey))
          .where(
            (conversation) =>
                conversation.hasMessages &&
                !conversation.isCustomerConversation,
          )
          .toList(growable: false);
      notifyListeners();
    } catch (_) {}
    try {
      _syncCursor = await ChatLocalStore.instance.loadSyncCursor(nextKey);
    } catch (_) {
      _syncCursor = 0;
    }
    await _restorePendingMedia(nextKey);
    if (profileKey != nextKey) return;
    _ensureRealtimeStarted();
    _startReliabilityTimers();
    unawaited(_recoverChatState());
    await refreshConversations();
  }

  void clearMemory() {
    _realtime.stop();
    _cancelReliabilityTimers();
    for (final client in _mediaUploadClients.values) {
      client.close();
    }
    _mediaUploadClients.clear();
    _runningMedia.clear();
    _clearingMediaProfiles.clear();
    _pendingMedia.clear();
    _pendingSends.clear();
    _syncOperation = null;
    _conversationRefreshOperation = null;
    _conversationRefreshRequested = false;
    _pendingDrainRunning = false;
    _pendingDrainRequested = false;
    _receiptFlushRunning = false;
    _receiptFlushRequested = false;
    _syncCursor = 0;
    _pendingRetryAt = null;
    _mediaRetryAt = null;
    _clearRetryIdentity();
    profileKey = '';
    conversations = const [];
    directory = const [];
    _messages.clear();
    _hasMoreMessages.clear();
    _loadingMessages.clear();
    activeConversationId = '';
    connected = false;
    loadingConversations = false;
    loadingDirectory = false;
    sending = false;
    error = '';
    sendError = '';
    notifyListeners();
  }

  void pauseRealtime() {
    _realtime.stop();
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    if (!connected) return;
    connected = false;
    notifyListeners();
  }

  Future<void> refreshConversations() {
    final key = profileKey;
    if (key.isEmpty) return Future<void>.value();
    final existing = _conversationRefreshOperation;
    if (existing != null) {
      _conversationRefreshRequested = true;
      return existing;
    }
    late final Future<void> operation;
    operation = _runConversationRefresh(key).whenComplete(() {
      if (identical(_conversationRefreshOperation, operation)) {
        _conversationRefreshOperation = null;
      }
    });
    _conversationRefreshOperation = operation;
    return operation;
  }

  Future<void> _runConversationRefresh(String key) async {
    loadingConversations = true;
    error = '';
    notifyListeners();
    try {
      do {
        _conversationRefreshRequested = false;
        try {
          final page = await MobileApi.instance.chatConversations();
          if (profileKey != key) return;
          conversations = page.items
              .where(
                (conversation) =>
                    conversation.hasMessages &&
                    !conversation.isCustomerConversation,
              )
              .toList(growable: false);
          try {
            await ChatLocalStore.instance.saveConversations(
              key,
              conversations,
            );
          } catch (_) {}
        } catch (exception) {
          if (profileKey == key) error = exception.toString();
        }
      } while (_conversationRefreshRequested && profileKey == key);
    } finally {
      if (profileKey == key) {
        loadingConversations = false;
        notifyListeners();
      }
    }
  }

  Future<void> searchDirectory(String query) async {
    final key = profileKey;
    if (key.isEmpty) return;
    loadingDirectory = true;
    error = '';
    notifyListeners();
    try {
      final page = await MobileApi.instance.chatDirectory(query: query);
      if (profileKey == key) {
        directory = page.items
            .where((entry) => entry.role != UserRole.customer)
            .toList(growable: false);
      }
    } catch (exception) {
      if (profileKey == key) error = exception.toString();
    } finally {
      if (profileKey == key) {
        loadingDirectory = false;
        notifyListeners();
      }
    }
  }

  Future<ChatConversation> openConversation(ChatDirectoryEntry target) async {
    if (target.role == UserRole.customer) {
      throw const MobileApiException(
        code: 'chat_forbidden',
        message: 'Customerlar bilan chatlashish mumkin emas',
        statusCode: 403,
      );
    }
    await startForCurrentSession();
    final key = profileKey;
    if (key.isEmpty) throw StateError('chat_profile_changed');
    final conversation = await MobileApi.instance.chatCreateDm(target);
    if (profileKey != key) throw StateError('chat_profile_changed');
    _upsertConversation(conversation);
    if (profileKey == key) {
      try {
        await ChatLocalStore.instance.saveConversations(key, [conversation]);
      } catch (_) {}
    }
    notifyListeners();
    return conversation;
  }

  Future<void> loadMessages(String conversationId) async {
    await startForCurrentSession();
    final key = profileKey;
    if (key.isEmpty ||
        conversationId.trim().isEmpty ||
        _loadingMessages.contains(conversationId)) {
      return;
    }
    _loadingMessages.add(conversationId);
    notifyListeners();
    if (!_messages.containsKey(conversationId)) {
      try {
        final cached = await ChatLocalStore.instance.loadMessages(
          key,
          conversationId,
        );
        if (profileKey == key) {
          _messages[conversationId] = List<ChatMessage>.unmodifiable(cached);
          notifyListeners();
        }
      } catch (_) {}
    }
    try {
      final page = await MobileApi.instance.chatMessages(conversationId);
      if (profileKey != key) return;
      _messages[conversationId] = _mergeMessages(
        _messages[conversationId] ?? const [],
        page.items,
      );
      _hasMoreMessages[conversationId] = page.hasMore;
      try {
        await ChatLocalStore.instance.saveMessages(
          key,
          _messages[conversationId]!,
        );
      } catch (_) {}
      if (profileKey != key) return;
      await markRead(conversationId);
      unawaited(_drainPendingMessages());
    } catch (exception) {
      if (profileKey == key) error = exception.toString();
    } finally {
      _loadingMessages.remove(conversationId);
    }
    notifyListeners();
  }

  Future<void> loadOlderMessages(String conversationId) async {
    final key = profileKey;
    if (key.isEmpty) return;
    if (!hasMoreMessages(conversationId)) return;
    final existing = _messages[conversationId] ?? const <ChatMessage>[];
    if (existing.isEmpty) return;
    final page = await MobileApi.instance.chatMessages(
      conversationId,
      beforeSequence: existing.first.sequence,
    );
    if (profileKey != key) return;
    _messages[conversationId] = _mergeMessages(page.items, existing);
    _hasMoreMessages[conversationId] = page.hasMore;
    if (profileKey == key) {
      try {
        await ChatLocalStore.instance.saveMessages(key, page.items);
      } catch (_) {}
    }
    if (profileKey != key) return;
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String rawBody) async {
    final body = rawBody.trim();
    if (body.isEmpty || sending) return;
    sending = true;
    error = '';
    sendError = '';
    notifyListeners();
    var attemptedClientMessageId = '';
    var attemptedProfileKey = '';
    try {
      if (profileKey.isEmpty) {
        await startForCurrentSession().timeout(_sendTimeout);
      }
      if (profileKey.isEmpty || conversationId.trim().isEmpty) {
        throw const MobileApiException(
          code: 'authentication_required',
          message: 'Chat sessiyasi tayyor emas',
          statusCode: 401,
        );
      }
      if (_isCustomerConversation(conversationId)) {
        throw const MobileApiException(
          code: 'chat_forbidden',
          message: 'Customerlar bilan chatlashish mumkin emas',
          statusCode: 403,
        );
      }
      final key = profileKey;
      attemptedProfileKey = key;
      final retrying = _retryClientMessageId.isNotEmpty &&
          _retryConversationId == conversationId &&
          _retryBody == body;
      final clientMessageId =
          retrying ? _retryClientMessageId : _newClientMessageId();
      attemptedClientMessageId = clientMessageId;
      var pending = retrying
          ? await ChatLocalStore.instance
              .loadPendingMessage(key, clientMessageId)
          : null;
      pending ??= ChatPendingMessage(
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        body: body,
        createdAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      await ChatLocalStore.instance.savePendingMessage(key, pending);
      await _sendPendingMessage(key, pending);
      _clearRetryIdentity();
      unawaited(refreshConversations());
    } catch (exception) {
      if (attemptedProfileKey.isNotEmpty && profileKey == attemptedProfileKey) {
        error = exception.toString();
        sendError = chatFailureMessage(exception);
      }
      if (attemptedClientMessageId.isNotEmpty &&
          profileKey == attemptedProfileKey) {
        _retryClientMessageId = attemptedClientMessageId;
        _retryConversationId = conversationId;
        _retryBody = body;
      }
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  void clearSendError() {
    _clearRetryIdentity();
    if (sendError.isEmpty) return;
    sendError = '';
    notifyListeners();
  }

  Future<ChatMessage> _sendWithRetry({
    required String conversationId,
    required String clientMessageId,
    required String body,
    required String expectedProfileKey,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (profileKey != expectedProfileKey) {
        throw StateError('chat_profile_changed');
      }
      try {
        return await MobileApi.instance
            .chatSendMessage(
              conversationId: conversationId,
              clientMessageId: clientMessageId,
              body: body,
            )
            .timeout(_sendTimeout);
      } catch (error) {
        lastError = error;
        if (attempt > 0 || !isTransientChatFailure(error)) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (profileKey != expectedProfileKey) {
          throw StateError('chat_profile_changed');
        }
      }
    }
    throw lastError ?? StateError('chat_send_failed');
  }

  Future<void> markRead(String conversationId) async {
    final key = profileKey;
    if (key.isEmpty) return;
    final messages = _messages[conversationId] ?? const <ChatMessage>[];
    final sequence = messages.isEmpty ? 0 : messages.last.sequence;
    final index = conversations.indexWhere(
      (item) => item.conversationId == conversationId,
    );
    if (index >= 0 && conversations[index].unreadCount != 0) {
      final updated = conversations[index].copyWith(unreadCount: 0);
      final next = [...conversations];
      next[index] = updated;
      conversations = next;
      notifyListeners();
      if (profileKey == key) {
        unawaited(
          ChatLocalStore.instance.saveConversations(key, [updated]),
        );
      }
    }
    if (sequence <= 0) return;
    await _queueReceipt(
      conversationId,
      deliveredSequence: sequence,
      readSequence: sequence,
      expectedProfileKey: key,
    );
    unawaited(_flushPendingReceipts());
  }

  void setActiveConversation(String conversationId) {
    activeConversationId = conversationId;
    if (conversationId.isNotEmpty) unawaited(markRead(conversationId));
  }

  Future<void> handlePush(Map<String, dynamic> data) async {
    if (data['event_type'] != 'chat.message.created') return;
    await startForCurrentSession();
    try {
      await _synchronizeChat();
    } catch (exception) {
      debugPrint(
        'chat push synchronization failed: '
        '${exception.runtimeType}: $exception',
      );
    }
    final conversationId = data['conversation_id']?.toString() ?? '';
    if (conversationId == activeConversationId && conversationId.isNotEmpty) {
      try {
        await _syncConversationAfterKnown(conversationId);
      } catch (exception) {
        debugPrint(
          'chat push conversation recovery failed: '
          '${exception.runtimeType}: $exception',
        );
      }
    }
  }

  bool shouldPresentChatNotification(String conversationId) {
    return conversationId.isEmpty || conversationId != activeConversationId;
  }

  void _handleRealtimeEvent(Map<String, dynamic> payload) {
    final eventType = payload['event']?.toString() ?? '';
    if (eventType == 'chat.ready' || eventType == 'chat.resync_required') {
      unawaited(_recoverChatState());
      return;
    }
    if (eventType != 'chat.message.created' &&
        eventType != 'chat.message.updated') {
      return;
    }
    final rawMessage = payload['message'];
    if (rawMessage is! Map) return;
    final message = ChatMessage.fromJson(rawMessage.cast<String, dynamic>());
    unawaited(_acceptRealtimeMessage(message));
  }

  Future<bool> _acceptMessage(
    ChatMessage message, {
    String? expectedProfileKey,
    bool requirePersistence = false,
  }) async {
    if (message.senderRole == UserRole.customer) return false;
    final key = expectedProfileKey ?? profileKey;
    if (key.isEmpty || profileKey != key) return false;
    final current = _messages[message.conversationId] ?? const <ChatMessage>[];
    final alreadyKnown =
        current.any((item) => item.messageId == message.messageId);
    _messages[message.conversationId] = _mergeMessages(current, [message]);
    final conversationIndex = conversations.indexWhere(
      (conversation) => conversation.conversationId == message.conversationId,
    );
    if (conversationIndex >= 0) {
      final profile = AppSession.instance.profile;
      final mine = profile != null &&
          message.senderRole == profile.role &&
          message.senderRef == profile.ref;
      final next = [...conversations];
      final currentConversation = next[conversationIndex];
      final isLatest =
          message.sequence >= currentConversation.lastMessageSequence;
      next[conversationIndex] = currentConversation.copyWith(
        lastMessage: isLatest ? message : null,
        lastMessageSequence: isLatest ? message.sequence : null,
        unreadCount: message.conversationId == activeConversationId
            ? 0
            : !alreadyKnown && !mine
                ? currentConversation.unreadCount + 1
                : currentConversation.unreadCount,
        updatedAtUnix: isLatest ? message.createdAtUnix : null,
      );
      next.sort(
        (left, right) => right.updatedAtUnix.compareTo(left.updatedAtUnix),
      );
      conversations = next;
    }
    if (key.isNotEmpty) {
      try {
        await ChatLocalStore.instance.saveMessages(key, [message]);
        if (conversationIndex >= 0) {
          final updated = conversations.firstWhere(
            (conversation) =>
                conversation.conversationId == message.conversationId,
          );
          await ChatLocalStore.instance.saveConversations(key, [updated]);
        }
      } catch (persistenceError, stackTrace) {
        if (requirePersistence) {
          Error.throwWithStackTrace(persistenceError, stackTrace);
        }
      }
    }
    if (profileKey == key) notifyListeners();
    return true;
  }

  void _upsertConversation(ChatConversation conversation) {
    if (conversation.isCustomerConversation) return;
    final next = [...conversations];
    final index = next.indexWhere(
      (item) => item.conversationId == conversation.conversationId,
    );
    if (index >= 0) {
      next[index] = conversation;
    } else {
      next.insert(0, conversation);
    }
    next.sort(
        (left, right) => right.updatedAtUnix.compareTo(left.updatedAtUnix));
    conversations = next;
  }

  static List<ChatMessage> _mergeMessages(
    Iterable<ChatMessage> first,
    Iterable<ChatMessage> second,
  ) {
    final byId = <String, ChatMessage>{};
    for (final message in [...first, ...second]) {
      byId[message.messageId] = message;
    }
    final result = byId.values.toList();
    result.sort((left, right) => left.sequence.compareTo(right.sequence));
    return List<ChatMessage>.unmodifiable(result);
  }

  static String _keyFor(SessionProfile profile) {
    return '${userRoleToJson(profile.role)}:${profile.ref}';
  }

  bool _isCustomerConversation(String conversationId) {
    return conversations.any(
      (conversation) =>
          conversation.conversationId == conversationId &&
          conversation.isCustomerConversation,
    );
  }

  static String _newClientMessageId() {
    final random = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return 'client_${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final random =
        List<int>.generate(4, (_) => Random.secure().nextInt(0x7fffffff))
            .map((value) => value.toRadixString(16).padLeft(8, '0'))
            .join();
    final id = 'device_$random';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}
