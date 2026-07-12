import '../../shared/models/app_models.dart';

class ChatPrincipal {
  const ChatPrincipal({
    required this.principalId,
    required this.role,
    required this.ref,
    required this.displayName,
    required this.avatarUrl,
  });

  final String principalId;
  final UserRole role;
  final String ref;
  final String displayName;
  final String avatarUrl;

  factory ChatPrincipal.fromJson(Map<String, dynamic> json) {
    return ChatPrincipal(
      principalId: json['principal_id']?.toString() ?? '',
      role: userRoleFromJson(json['role']?.toString()),
      ref: json['ref']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'principal_id': principalId,
        'role': userRoleToJson(role),
        'ref': ref,
        'display_name': displayName,
        'avatar_url': avatarUrl,
      };
}

class ChatDirectoryEntry {
  const ChatDirectoryEntry({
    required this.role,
    required this.ref,
    required this.displayName,
    required this.avatarUrl,
  });

  final UserRole role;
  final String ref;
  final String displayName;
  final String avatarUrl;

  factory ChatDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return ChatDirectoryEntry(
      role: userRoleFromJson(json['role']?.toString()),
      ref: json['ref']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.messageId,
    required this.conversationId,
    required this.senderPrincipalId,
    required this.senderRole,
    required this.senderRef,
    required this.senderDisplayName,
    required this.clientMessageId,
    required this.sequence,
    required this.type,
    required this.body,
    required this.createdAtUnix,
    this.editedAtUnix,
    this.deletedAtUnix,
  });

  final String messageId;
  final String conversationId;
  final String senderPrincipalId;
  final UserRole senderRole;
  final String senderRef;
  final String senderDisplayName;
  final String clientMessageId;
  final int sequence;
  final String type;
  final String body;
  final int createdAtUnix;
  final int? editedAtUnix;
  final int? deletedAtUnix;

  bool isMine(SessionProfile profile) {
    return senderRole == profile.role && senderRef == profile.ref;
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderPrincipalId: json['sender_principal_id']?.toString() ?? '',
      senderRole: userRoleFromJson(json['sender_role']?.toString()),
      senderRef: json['sender_ref']?.toString() ?? '',
      senderDisplayName: json['sender_display_name']?.toString() ?? '',
      clientMessageId: json['client_message_id']?.toString() ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      editedAtUnix: (json['edited_at_unix'] as num?)?.toInt(),
      deletedAtUnix: (json['deleted_at_unix'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'message_id': messageId,
        'conversation_id': conversationId,
        'sender_principal_id': senderPrincipalId,
        'sender_role': userRoleToJson(senderRole),
        'sender_ref': senderRef,
        'sender_display_name': senderDisplayName,
        'client_message_id': clientMessageId,
        'sequence': sequence,
        'type': type,
        'body': body,
        'created_at_unix': createdAtUnix,
        if (editedAtUnix != null) 'edited_at_unix': editedAtUnix,
        if (deletedAtUnix != null) 'deleted_at_unix': deletedAtUnix,
      };
}

class ChatConversation {
  const ChatConversation({
    required this.conversationId,
    required this.kind,
    required this.title,
    required this.peer,
    required this.lastMessage,
    required this.lastMessageSequence,
    required this.unreadCount,
    required this.updatedAtUnix,
  });

  final String conversationId;
  final String kind;
  final String title;
  final ChatPrincipal? peer;
  final ChatMessage? lastMessage;
  final int lastMessageSequence;
  final int unreadCount;
  final int updatedAtUnix;

  bool get hasMessages => lastMessageSequence > 0 && lastMessage != null;

  String get displayTitle {
    final peerName = peer?.displayName.trim() ?? '';
    if (peerName.isNotEmpty) return peerName;
    if (title.trim().isNotEmpty) return title.trim();
    return 'Suhbat';
  }

  ChatConversation copyWith({
    ChatMessage? lastMessage,
    int? lastMessageSequence,
    int? unreadCount,
    int? updatedAtUnix,
  }) {
    return ChatConversation(
      conversationId: conversationId,
      kind: kind,
      title: title,
      peer: peer,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSequence: lastMessageSequence ?? this.lastMessageSequence,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAtUnix: updatedAtUnix ?? this.updatedAtUnix,
    );
  }

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final peer = json['peer'];
    final lastMessage = json['last_message'];
    return ChatConversation(
      conversationId: json['conversation_id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'dm',
      title: json['title']?.toString() ?? '',
      peer: peer is Map
          ? ChatPrincipal.fromJson(peer.cast<String, dynamic>())
          : null,
      lastMessage: lastMessage is Map
          ? ChatMessage.fromJson(lastMessage.cast<String, dynamic>())
          : null,
      lastMessageSequence:
          (json['last_message_sequence'] as num?)?.toInt() ?? 0,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'conversation_id': conversationId,
        'kind': kind,
        'title': title,
        'peer': peer?.toJson(),
        'last_message': lastMessage?.toJson(),
        'last_message_sequence': lastMessageSequence,
        'unread_count': unreadCount,
        'updated_at_unix': updatedAtUnix,
      };
}

class ChatConversationPage {
  const ChatConversationPage({required this.items, required this.hasMore});

  final List<ChatConversation> items;
  final bool hasMore;

  factory ChatConversationPage.fromJson(Map<String, dynamic> json) {
    return ChatConversationPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
              (item) => ChatConversation.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      hasMore: json['has_more'] == true,
    );
  }
}

class ChatMessagePage {
  const ChatMessagePage({required this.items, required this.hasMore});

  final List<ChatMessage> items;
  final bool hasMore;

  factory ChatMessagePage.fromJson(Map<String, dynamic> json) {
    return ChatMessagePage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => ChatMessage.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      hasMore: json['has_more'] == true,
    );
  }
}

class ChatDirectoryPage {
  const ChatDirectoryPage({required this.items, required this.hasMore});

  final List<ChatDirectoryEntry> items;
  final bool hasMore;

  factory ChatDirectoryPage.fromJson(Map<String, dynamic> json) {
    return ChatDirectoryPage(
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) =>
              ChatDirectoryEntry.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
      hasMore: json['has_more'] == true,
    );
  }
}
