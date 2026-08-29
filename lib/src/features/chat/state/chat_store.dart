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
part 'chat_store_ChatStore_methods_01.dart';
part 'chat_store_ChatStore_methods_02.dart';
part 'chat_store_media_ChatStoreMedia_methods_01.dart';
part 'chat_store_media_ChatStoreMedia_methods_02.dart';
part 'chat_store_media_ChatStoreMedia_methods_03.dart';
part 'chat_store_media_declarations_part_01.dart';

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
