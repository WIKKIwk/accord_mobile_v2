import '../../shared/models/app_models.dart';
import 'chat_media_models.dart';

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
    this.metadata = const <String, dynamic>{},
    required this.createdAtUnix,
    this.editedAtUnix,
    this.deletedAtUnix,
    this.attachment,
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
  final Map<String, dynamic> metadata;
  final int createdAtUnix;
  final int? editedAtUnix;
  final int? deletedAtUnix;
  final ChatMessageAttachment? attachment;

  String get previewText {
    if (orderFreezeRequest != null) return 'Buyurtmani muzlatish so‘rovi';
    if (inventoryTransferRequest != null) return 'Ombor transferi';
    final caption = body.trim();
    if (caption.isNotEmpty) return caption;
    return switch (attachment?.kind) {
      ChatMediaKind.image => 'Rasm',
      ChatMediaKind.video => 'Video',
      ChatMediaKind.audio => 'Ovozli xabar',
      null => 'Xabar',
    };
  }

  OrderFreezeRequestCardData? get orderFreezeRequest {
    if (type != 'order_freeze_request') return null;
    return OrderFreezeRequestCardData.fromJson(metadata);
  }

  InventoryTransferRequestCardData? get inventoryTransferRequest {
    if (type != 'inventory_transfer_request') return null;
    return InventoryTransferRequestCardData.fromJson(metadata);
  }

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
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.unmodifiable(
              (json['metadata'] as Map).cast<String, dynamic>(),
            )
          : const <String, dynamic>{},
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      editedAtUnix: (json['edited_at_unix'] as num?)?.toInt(),
      deletedAtUnix: (json['deleted_at_unix'] as num?)?.toInt(),
      attachment: json['attachment'] is Map
          ? ChatMessageAttachment.fromJson(
              (json['attachment'] as Map).cast<String, dynamic>(),
            )
          : null,
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
        if (metadata.isNotEmpty) 'metadata': metadata,
        'created_at_unix': createdAtUnix,
        if (editedAtUnix != null) 'edited_at_unix': editedAtUnix,
        if (deletedAtUnix != null) 'deleted_at_unix': deletedAtUnix,
        if (attachment != null) 'attachment': attachment!.toJson(),
      };
}

enum OrderFreezeRequestCardStatus {
  pending,
  frozen,
  cancelled,
  unfrozen;

  static OrderFreezeRequestCardStatus fromRaw(Object? raw) {
    return switch (raw?.toString().trim()) {
      'frozen' => OrderFreezeRequestCardStatus.frozen,
      'cancelled' => OrderFreezeRequestCardStatus.cancelled,
      'unfrozen' => OrderFreezeRequestCardStatus.unfrozen,
      _ => OrderFreezeRequestCardStatus.pending,
    };
  }
}

class OrderFreezeRequestCardData {
  const OrderFreezeRequestCardData({
    required this.eventSequence,
    required this.requestId,
    required this.status,
    required this.orderId,
    required this.orderNumber,
    required this.orderTitle,
    required this.requesterRole,
    required this.requesterRef,
    required this.requesterDisplayName,
    required this.targetSessionId,
    required this.targetApparatus,
    required this.targetWorkerRole,
    required this.targetWorkerRef,
    required this.targetWorkerDisplayName,
    required this.requestedAtUnix,
    required this.transitionedAtUnix,
  });

  final int eventSequence;
  final String requestId;
  final OrderFreezeRequestCardStatus status;
  final String orderId;
  final String orderNumber;
  final String orderTitle;
  final String requesterRole;
  final String requesterRef;
  final String requesterDisplayName;
  final String targetSessionId;
  final String targetApparatus;
  final String targetWorkerRole;
  final String targetWorkerRef;
  final String targetWorkerDisplayName;
  final int requestedAtUnix;
  final int transitionedAtUnix;

  bool get isValid =>
      requestId.trim().isNotEmpty &&
      orderId.trim().isNotEmpty &&
      canonicalApparatusIdIsValid(targetApparatus) &&
      targetWorkerRef.trim().isNotEmpty;

  factory OrderFreezeRequestCardData.fromJson(Map<String, dynamic> json) {
    final targetApparatus = json['target_apparatus']?.toString().trim() ?? '';
    if (!canonicalApparatusIdIsValid(targetApparatus)) {
      throw const FormatException('Canonical apparatus ID is required');
    }
    return OrderFreezeRequestCardData(
      eventSequence: (json['event_sequence'] as num?)?.toInt() ?? 0,
      requestId: json['request_id']?.toString() ?? '',
      status: OrderFreezeRequestCardStatus.fromRaw(json['status']),
      orderId: json['order_id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString() ?? '',
      orderTitle: json['order_title']?.toString() ?? '',
      requesterRole: json['requester_role']?.toString() ?? '',
      requesterRef: json['requester_ref']?.toString() ?? '',
      requesterDisplayName: json['requester_display_name']?.toString() ?? '',
      targetSessionId: json['target_session_id']?.toString() ?? '',
      targetApparatus: targetApparatus,
      targetWorkerRole: json['target_worker_role']?.toString() ?? '',
      targetWorkerRef: json['target_worker_ref']?.toString() ?? '',
      targetWorkerDisplayName:
          json['target_worker_display_name']?.toString() ?? '',
      requestedAtUnix: (json['requested_at_unix'] as num?)?.toInt() ?? 0,
      transitionedAtUnix: (json['transitioned_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class InventoryTransferRequestCardData {
  const InventoryTransferRequestCardData({
    required this.eventSequence,
    required this.transferId,
    required this.status,
    required this.sourceWarehouse,
    required this.destinationWarehouse,
    required this.note,
    required this.requesterRole,
    required this.requesterRef,
    required this.requesterDisplayName,
    required this.targetRole,
    required this.targetRef,
    required this.targetDisplayName,
    required this.approvedByName,
    required this.dispatchedByName,
    required this.receivedByName,
    required this.rejectedByName,
    required this.cancelledByName,
    required this.createdAtUnix,
    required this.lines,
  });

  final int eventSequence;
  final String transferId;
  final String status;
  final String sourceWarehouse;
  final String destinationWarehouse;
  final String note;
  final String requesterRole;
  final String requesterRef;
  final String requesterDisplayName;
  final String targetRole;
  final String targetRef;
  final String targetDisplayName;
  final String approvedByName;
  final String dispatchedByName;
  final String receivedByName;
  final String rejectedByName;
  final String cancelledByName;
  final int createdAtUnix;
  final List<InventoryTransferRequestLine> lines;

  bool get isValid =>
      transferId.trim().isNotEmpty &&
      sourceWarehouse.trim().isNotEmpty &&
      destinationWarehouse.trim().isNotEmpty &&
      targetRef.trim().isNotEmpty;

  factory InventoryTransferRequestCardData.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return InventoryTransferRequestCardData(
      eventSequence: (json['event_sequence'] as num?)?.toInt() ?? 0,
      transferId: json['transfer_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'requested',
      sourceWarehouse: json['source_warehouse']?.toString() ?? '',
      destinationWarehouse: json['destination_warehouse']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      requesterRole: json['requester_role']?.toString() ?? '',
      requesterRef: json['requester_ref']?.toString() ?? '',
      requesterDisplayName: json['requester_display_name']?.toString() ?? '',
      targetRole: json['target_role']?.toString() ?? '',
      targetRef: json['target_ref']?.toString() ?? '',
      targetDisplayName: json['target_display_name']?.toString() ?? '',
      approvedByName: json['approved_by_name']?.toString() ?? '',
      dispatchedByName: json['dispatched_by_name']?.toString() ?? '',
      receivedByName: json['received_by_name']?.toString() ?? '',
      rejectedByName: json['rejected_by_name']?.toString() ?? '',
      cancelledByName: json['cancelled_by_name']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map(
                (line) => InventoryTransferRequestLine.fromJson(
                  line.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

class InventoryTransferRequestLine {
  const InventoryTransferRequestLine({
    required this.itemName,
    required this.qty,
    required this.uom,
  });

  final String itemName;
  final double qty;
  final String uom;

  factory InventoryTransferRequestLine.fromJson(Map<String, dynamic> json) {
    return InventoryTransferRequestLine(
      itemName: json['item_name']?.toString() ?? '',
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
    );
  }
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

class ChatRealtimeEvent {
  const ChatRealtimeEvent({
    required this.eventId,
    required this.cursor,
    required this.event,
    required this.conversationId,
    required this.sequence,
    required this.message,
  });

  final String eventId;
  final int cursor;
  final String event;
  final String conversationId;
  final int sequence;
  final ChatMessage? message;

  factory ChatRealtimeEvent.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'];
    return ChatRealtimeEvent(
      eventId: json['event_id']?.toString() ?? '',
      cursor: (json['cursor'] as num?)?.toInt() ?? 0,
      event: json['event']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      message: rawMessage is Map
          ? ChatMessage.fromJson(rawMessage.cast<String, dynamic>())
          : null,
    );
  }
}

class ChatSyncPage {
  const ChatSyncPage({
    required this.events,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<ChatRealtimeEvent> events;
  final int nextCursor;
  final bool hasMore;

  factory ChatSyncPage.fromJson(Map<String, dynamic> json) {
    return ChatSyncPage(
      events: ((json['events'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ChatRealtimeEvent.fromJson(
                item.cast<String, dynamic>(),
              ))
          .toList(growable: false),
      nextCursor: (json['next_cursor'] as num?)?.toInt() ?? 0,
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
