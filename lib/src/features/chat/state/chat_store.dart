import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../shared/models/app_models.dart';
import '../data/chat_local_store.dart';
import '../models/chat_models.dart';
import '../realtime/chat_realtime_service.dart';

class ChatStore extends ChangeNotifier {
  ChatStore._();

  static final ChatStore instance = ChatStore._();
  static const _deviceIdKey = 'chat_device_id_v1';

  final ChatRealtimeService _realtime = ChatRealtimeService();
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, bool> _hasMoreMessages = {};

  List<ChatConversation> conversations = const [];
  List<ChatDirectoryEntry> directory = const [];
  String profileKey = '';
  String activeConversationId = '';
  bool loadingConversations = false;
  bool loadingDirectory = false;
  bool connected = false;
  bool sending = false;
  String error = '';

  int get totalUnread => conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.unreadCount,
      );

  List<ChatMessage> messagesFor(String conversationId) =>
      List<ChatMessage>.unmodifiable(
        _messages[conversationId] ?? const <ChatMessage>[],
      );

  bool hasMoreMessages(String conversationId) =>
      _hasMoreMessages[conversationId] ?? false;

  Future<void> startForCurrentSession() async {
    final profile = AppSession.instance.profile;
    if (profile == null || !AppSession.instance.isLoggedIn) {
      clearMemory();
      return;
    }
    final nextKey = _keyFor(profile);
    if (nextKey == profileKey) {
      if (conversations.isEmpty) await refreshConversations();
      return;
    }
    _realtime.stop();
    profileKey = nextKey;
    conversations = const [];
    directory = const [];
    _messages.clear();
    _hasMoreMessages.clear();
    activeConversationId = '';
    error = '';
    notifyListeners();

    try {
      conversations = await ChatLocalStore.instance.loadConversations(nextKey);
      notifyListeners();
    } catch (_) {}
    await refreshConversations();
    if (profileKey != nextKey) return;
    _realtime.start(
      liveUri: MobileApi.instance.chatLiveUri,
      onEvent: _handleRealtimeEvent,
      onConnectionChanged: (value) {
        if (connected == value) return;
        connected = value;
        notifyListeners();
      },
    );
  }

  void clearMemory() {
    _realtime.stop();
    profileKey = '';
    conversations = const [];
    directory = const [];
    _messages.clear();
    _hasMoreMessages.clear();
    activeConversationId = '';
    connected = false;
    loadingConversations = false;
    loadingDirectory = false;
    sending = false;
    error = '';
    notifyListeners();
  }

  void pauseRealtime() {
    _realtime.stop();
    if (!connected) return;
    connected = false;
    notifyListeners();
  }

  Future<void> refreshConversations() async {
    final key = profileKey;
    if (key.isEmpty || loadingConversations) return;
    loadingConversations = true;
    error = '';
    notifyListeners();
    try {
      final page = await MobileApi.instance.chatConversations();
      if (profileKey != key) return;
      conversations = page.items;
      try {
        await ChatLocalStore.instance.saveConversations(key, conversations);
      } catch (_) {}
    } catch (exception) {
      if (profileKey == key) error = exception.toString();
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
      if (profileKey == key) directory = page.items;
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
    await startForCurrentSession();
    final conversation = await MobileApi.instance.chatCreateDm(target);
    _upsertConversation(conversation);
    if (profileKey.isNotEmpty) {
      try {
        await ChatLocalStore.instance
            .saveConversations(profileKey, [conversation]);
      } catch (_) {}
    }
    notifyListeners();
    return conversation;
  }

  Future<void> loadMessages(String conversationId) async {
    await startForCurrentSession();
    final key = profileKey;
    if (key.isEmpty || conversationId.trim().isEmpty) return;
    if (!_messages.containsKey(conversationId)) {
      try {
        final cached = await ChatLocalStore.instance.loadMessages(
          key,
          conversationId,
        );
        if (profileKey == key) {
          _messages[conversationId] = cached;
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
      await markRead(conversationId);
      unawaited(_flushPendingMessages(conversationId));
    } catch (exception) {
      if (profileKey == key) error = exception.toString();
    }
    notifyListeners();
  }

  Future<void> loadOlderMessages(String conversationId) async {
    if (!hasMoreMessages(conversationId)) return;
    final existing = _messages[conversationId] ?? const <ChatMessage>[];
    if (existing.isEmpty) return;
    final page = await MobileApi.instance.chatMessages(
      conversationId,
      beforeSequence: existing.first.sequence,
    );
    _messages[conversationId] = _mergeMessages(page.items, existing);
    _hasMoreMessages[conversationId] = page.hasMore;
    if (profileKey.isNotEmpty) {
      try {
        await ChatLocalStore.instance.saveMessages(profileKey, page.items);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> sendMessage(String conversationId, String rawBody) async {
    final body = rawBody.trim();
    if (body.isEmpty || sending) return;
    sending = true;
    error = '';
    notifyListeners();
    final key = profileKey;
    try {
      var clientMessageId = _newClientMessageId();
      try {
        final pending = await ChatLocalStore.instance.loadPendingMessages(
          key,
          conversationId: conversationId,
        );
        final matching = pending.where((message) => message.body == body);
        if (matching.isNotEmpty) {
          clientMessageId = matching.first.clientMessageId;
        }
        await ChatLocalStore.instance.savePendingMessage(
          key,
          ChatPendingMessage(
            conversationId: conversationId,
            clientMessageId: clientMessageId,
            body: body,
          ),
        );
      } catch (_) {}
      final message = await MobileApi.instance.chatSendMessage(
        conversationId: conversationId,
        clientMessageId: clientMessageId,
        body: body,
      );
      await _acceptMessage(message);
      try {
        await ChatLocalStore.instance.removePendingMessage(
          key,
          clientMessageId,
        );
      } catch (_) {}
      await refreshConversations();
    } catch (exception) {
      error = exception.toString();
      rethrow;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String conversationId) async {
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
      if (profileKey.isNotEmpty) {
        unawaited(
          ChatLocalStore.instance.saveConversations(profileKey, [updated]),
        );
      }
    }
    if (sequence <= 0) return;
    try {
      await MobileApi.instance.chatMarkRead(
        conversationId: conversationId,
        sequence: sequence,
        deviceId: await _deviceId(),
      );
    } catch (_) {}
  }

  void setActiveConversation(String conversationId) {
    activeConversationId = conversationId;
    if (conversationId.isNotEmpty) unawaited(markRead(conversationId));
  }

  Future<void> handlePush(Map<String, dynamic> data) async {
    if (data['event_type'] != 'chat.message.created') return;
    await startForCurrentSession();
    await refreshConversations();
    final conversationId = data['conversation_id']?.toString() ?? '';
    if (conversationId == activeConversationId && conversationId.isNotEmpty) {
      await loadMessages(conversationId);
    }
  }

  void _handleRealtimeEvent(Map<String, dynamic> payload) {
    if (payload['event'] != 'chat.message.created') return;
    final rawMessage = payload['message'];
    if (rawMessage is! Map) return;
    final message = ChatMessage.fromJson(rawMessage.cast<String, dynamic>());
    unawaited(_acceptMessage(message));
    unawaited(refreshConversations());
    if (message.conversationId == activeConversationId) {
      unawaited(markRead(message.conversationId));
    }
  }

  Future<void> _acceptMessage(ChatMessage message) async {
    final current = _messages[message.conversationId] ?? const <ChatMessage>[];
    _messages[message.conversationId] = _mergeMessages(current, [message]);
    if (profileKey.isNotEmpty) {
      try {
        await ChatLocalStore.instance.saveMessages(profileKey, [message]);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _flushPendingMessages(String conversationId) async {
    final key = profileKey;
    if (key.isEmpty || sending) return;
    List<ChatPendingMessage> pending;
    try {
      pending = await ChatLocalStore.instance.loadPendingMessages(
        key,
        conversationId: conversationId,
      );
    } catch (_) {
      return;
    }
    for (final item in pending) {
      if (profileKey != key) return;
      try {
        final message = await MobileApi.instance.chatSendMessage(
          conversationId: item.conversationId,
          clientMessageId: item.clientMessageId,
          body: item.body,
        );
        await _acceptMessage(message);
        await ChatLocalStore.instance.removePendingMessage(
          key,
          item.clientMessageId,
        );
      } catch (_) {
        return;
      }
    }
    if (pending.isNotEmpty) await refreshConversations();
  }

  void _upsertConversation(ChatConversation conversation) {
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
    return result;
  }

  static String _keyFor(SessionProfile profile) {
    return '${userRoleToJson(profile.role)}:${profile.ref}';
  }

  static String _newClientMessageId() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'client_${DateTime.now().microsecondsSinceEpoch}_$random';
  }

  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey)?.trim() ?? '';
    if (existing.isNotEmpty) return existing;
    final random =
        List<int>.generate(4, (_) => Random.secure().nextInt(1 << 32))
            .map((value) => value.toRadixString(16).padLeft(8, '0'))
            .join();
    final id = 'device_$random';
    await prefs.setString(_deviceIdKey, id);
    return id;
  }
}
