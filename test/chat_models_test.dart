import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat message parses backend contract and identifies its sender', () {
    final message = ChatMessage.fromJson({
      'message_id': 'message_1',
      'conversation_id': 'conversation_1',
      'sender_principal_id': 'principal_1',
      'sender_role': 'material_taminotchi',
      'sender_ref': 'material_1',
      'sender_display_name': 'Materialchi',
      'client_message_id': 'client_1',
      'sequence': 7,
      'type': 'text',
      'body': 'Salom',
      'created_at_unix': 100,
    });
    const profile = SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: 'Materialchi',
      ref: 'material_1',
      phone: '',
      avatarUrl: '',
    );

    expect(message.sequence, 7);
    expect(message.senderRole, UserRole.materialTaminotchi);
    expect(message.isMine(profile), isTrue);
    expect(ChatMessage.fromJson(message.toJson()).body, 'Salom');
  });

  test('media message preserves attachment metadata and preview fallback', () {
    final message = ChatMessage.fromJson({
      'message_id': 'message_media_1',
      'conversation_id': 'conversation_1',
      'sender_principal_id': 'principal_1',
      'sender_role': 'material_taminotchi',
      'sender_ref': 'material_1',
      'sender_display_name': 'Materialchi',
      'client_message_id': 'client_media_1',
      'sequence': 8,
      'type': 'video',
      'body': '',
      'created_at_unix': 101,
      'attachment': {
        'attachment_id': 'attachment_1',
        'media_id': 'media_1',
        'kind': 'video',
        'content_type': 'video/mp4',
        'size_bytes': 1024,
        'width_pixels': 1280,
        'height_pixels': 720,
        'duration_ms': 42000,
        'content_url': '/v1/mobile/chat/media/media_1/content',
        'thumbnail_url': '/v1/mobile/chat/media/media_1/thumbnail',
      },
    });

    expect(message.previewText, 'Video');
    expect(message.attachment?.durationMs, 42000);
    expect(message.attachment?.widthPixels, 1280);

    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.type, 'video');
    expect(restored.attachment?.mediaId, 'media_1');
    expect(restored.previewText, 'Video');
  });

  test('media caption is preferred over the generic conversation label', () {
    final message = ChatMessage.fromJson({
      'message_id': 'message_image_1',
      'conversation_id': 'conversation_1',
      'sender_principal_id': 'principal_1',
      'sender_role': 'material_taminotchi',
      'sender_ref': 'material_1',
      'sender_display_name': 'Materialchi',
      'client_message_id': 'client_image_1',
      'sequence': 9,
      'type': 'image',
      'body': 'Bugungi natija',
      'created_at_unix': 102,
      'attachment': {
        'attachment_id': 'attachment_2',
        'media_id': 'media_2',
        'kind': 'image',
        'content_type': 'image/jpeg',
        'size_bytes': 512,
        'width_pixels': 800,
        'height_pixels': 600,
        'content_url': '/v1/mobile/chat/media/media_2/content',
        'thumbnail_url': '/v1/mobile/chat/media/media_2/thumbnail',
      },
    });

    expect(message.previewText, 'Bugungi natija');
  });

  test('voice message parses audio metadata and uses its preview label', () {
    final message = ChatMessage.fromJson({
      'message_id': 'message_audio_1',
      'conversation_id': 'conversation_1',
      'sender_principal_id': 'principal_1',
      'sender_role': 'customer',
      'sender_ref': 'customer_1',
      'sender_display_name': 'Customer',
      'client_message_id': 'client_audio_1',
      'sequence': 10,
      'type': 'audio',
      'body': '',
      'created_at_unix': 103,
      'attachment': {
        'attachment_id': 'attachment_audio_1',
        'media_id': 'media_audio_1',
        'kind': 'audio',
        'content_type': 'audio/mp4',
        'size_bytes': 4096,
        'width_pixels': 480,
        'height_pixels': 120,
        'duration_ms': 12345,
        'content_url': '/v1/mobile/chat/media/media_audio_1/content',
        'thumbnail_url': '/v1/mobile/chat/media/media_audio_1/thumbnail',
      },
    });

    expect(message.type, 'audio');
    expect(message.attachment?.kind, ChatMediaKind.audio);
    expect(message.attachment?.durationMs, 12345);
    expect(message.previewText, 'Ovozli xabar');
    expect(ChatMessage.fromJson(message.toJson()).previewText, 'Ovozli xabar');
  });

  test('conversation page keeps peer, last message and unread count', () {
    final page = ChatConversationPage.fromJson({
      'items': [
        {
          'conversation_id': 'conversation_1',
          'kind': 'dm',
          'title': '',
          'peer': {
            'principal_id': 'principal_2',
            'role': 'qolipchi',
            'ref': 'qolipchi_1',
            'display_name': 'Qolipchi',
            'avatar_url': 'https://example.test/avatar',
          },
          'last_message': null,
          'last_message_sequence': 0,
          'unread_count': 3,
          'updated_at_unix': 200,
        },
      ],
      'has_more': false,
    });

    expect(page.items.single.displayTitle, 'Qolipchi');
    expect(page.items.single.unreadCount, 3);
    expect(page.items.single.peer?.role, UserRole.qolipchi);
    expect(page.items.single.hasMessages, isFalse);
    expect(page.hasMore, isFalse);
  });

  test('chat directory and conversations include customers', () {
    final directory = ChatDirectoryPage.fromJson({
      'items': [
        {
          'role': 'customer',
          'ref': 'customer_1',
          'display_name': 'Customer',
          'avatar_url': '',
        },
        {
          'role': 'admin',
          'ref': 'admin',
          'display_name': 'Admin',
          'avatar_url': '',
        },
      ],
      'has_more': false,
    });
    final conversations = ChatConversationPage.fromJson({
      'items': [
        {
          'conversation_id': 'customer_conversation',
          'kind': 'dm',
          'title': '',
          'peer': {
            'principal_id': 'customer_principal',
            'role': 'customer',
            'ref': 'customer_1',
            'display_name': 'Customer',
            'avatar_url': '',
          },
          'last_message': null,
          'last_message_sequence': 0,
          'unread_count': 0,
          'updated_at_unix': 0,
        },
      ],
      'has_more': false,
    });

    expect(directory.items.map((item) => item.role), [
      UserRole.customer,
      UserRole.admin,
    ]);
    expect(conversations.items.single.peer?.role, UserRole.customer);
  });

  test('sync page preserves durable event cursor and message payload', () {
    final page = ChatSyncPage.fromJson({
      'events': [
        {
          'event_id': 'event_1',
          'cursor': 42,
          'event': 'chat.message.created',
          'conversation_id': 'conversation_1',
          'sequence': 7,
          'message': {
            'message_id': 'message_1',
            'conversation_id': 'conversation_1',
            'sender_principal_id': 'principal_1',
            'sender_role': 'customer',
            'sender_ref': 'customer_1',
            'sender_display_name': 'Customer',
            'client_message_id': 'client_1',
            'sequence': 7,
            'type': 'text',
            'body': 'Offline xabar',
            'created_at_unix': 100,
          },
        },
      ],
      'next_cursor': 42,
      'has_more': false,
    });

    expect(page.nextCursor, 42);
    expect(page.hasMore, isFalse);
    expect(page.events.single.cursor, 42);
    expect(page.events.single.message?.body, 'Offline xabar');
  });

  test('freeze request card preserves exact request and target binding', () {
    final message = ChatMessage.fromJson({
      'message_id': 'message_freeze_1',
      'conversation_id': 'conversation_1',
      'sender_principal_id': 'principal_admin',
      'sender_role': 'admin',
      'sender_ref': 'admin_1',
      'sender_display_name': 'Admin',
      'client_message_id': 'order-freeze-request:order-freeze-request_abc',
      'sequence': 11,
      'type': 'order_freeze_request',
      'body': 'Buyurtmani muzlatish so‘rovi',
      'metadata': {
        'kind': 'order_freeze_request',
        'event_sequence': 17,
        'request_id': 'order-freeze-request_abc',
        'status': 'pending',
        'order_id': 'zakaz-1',
        'order_number': 'Z-001',
        'order_title': 'Sinov order',
        'requester_role': 'admin',
        'requester_ref': 'admin_1',
        'requester_display_name': 'Admin',
        'target_session_id': 'session_1',
        'target_apparatus': '7 ta rangli pechat',
        'target_worker_role': 'aparatchi',
        'target_worker_ref': 'worker_1',
        'target_worker_display_name': 'Worker',
        'requested_at_unix': 100,
        'transitioned_at_unix': 100,
      },
      'created_at_unix': 100,
    });

    final request = message.orderFreezeRequest;
    expect(request, isNotNull);
    expect(request?.isValid, isTrue);
    expect(request?.requestId, 'order-freeze-request_abc');
    expect(request?.targetWorkerRef, 'worker_1');
    expect(request?.status, OrderFreezeRequestCardStatus.pending);
    expect(message.previewText, 'Buyurtmani muzlatish so‘rovi');

    final restored = ChatMessage.fromJson(message.toJson());
    expect(restored.orderFreezeRequest?.eventSequence, 17);
    expect(restored.orderFreezeRequest?.targetApparatus, '7 ta rangli pechat');
  });

  test('freeze card sync update parses terminal state on the same message', () {
    final page = ChatSyncPage.fromJson({
      'events': [
        {
          'event_id': 'freeze_event_2',
          'cursor': 43,
          'event': 'chat.message.updated',
          'conversation_id': 'conversation_1',
          'sequence': 11,
          'message': {
            'message_id': 'message_freeze_1',
            'conversation_id': 'conversation_1',
            'sender_principal_id': 'principal_admin',
            'sender_role': 'admin',
            'sender_ref': 'admin_1',
            'sender_display_name': 'Admin',
            'client_message_id':
                'order-freeze-request:order-freeze-request_abc',
            'sequence': 11,
            'type': 'order_freeze_request',
            'body': 'Buyurtmani muzlatish so‘rovi',
            'metadata': {
              'event_sequence': 18,
              'request_id': 'order-freeze-request_abc',
              'status': 'cancelled',
              'order_id': 'zakaz-1',
              'target_apparatus': '7 ta rangli pechat',
              'target_worker_ref': 'worker_1',
            },
            'created_at_unix': 100,
            'edited_at_unix': 101,
          },
        },
      ],
      'next_cursor': 43,
      'has_more': false,
    });

    expect(page.events.single.event, 'chat.message.updated');
    expect(
      page.events.single.message?.orderFreezeRequest?.status,
      OrderFreezeRequestCardStatus.cancelled,
    );
    expect(
      page.events.single.message?.orderFreezeRequest?.eventSequence,
      18,
    );
  });

  test('inventory transfer card keeps the destination recipient binding', () {
    final message = ChatMessage.fromJson({
      'message_id': 'message_transfer_1',
      'conversation_id': 'conversation_1',
      'sender_principal_id': 'principal_material',
      'sender_role': 'material_taminotchi',
      'sender_ref': 'material_1',
      'sender_display_name': 'Materialchi',
      'client_message_id': 'inventory-transfer-request:transfer_1',
      'sequence': 12,
      'type': 'inventory_transfer_request',
      'body': 'Ombor transferi',
      'metadata': {
        'event_sequence': 21,
        'transfer_id': 'transfer_1',
        'status': 'requested',
        'source_warehouse': 'Asosiy ombor',
        'destination_warehouse': 'Sex ombori',
        'requester_role': 'material_taminotchi',
        'requester_ref': 'material_1',
        'requester_display_name': 'Materialchi',
        'target_role': 'werka',
        'target_ref': 'werka_1',
        'target_display_name': 'Werka',
        'lines': [
          {'item_name': 'Kraska', 'qty': 58, 'uom': 'kg'},
        ],
      },
      'created_at_unix': 100,
    });

    final request = message.inventoryTransferRequest;
    expect(request, isNotNull);
    expect(request?.isValid, isTrue);
    expect(request?.targetRef, 'werka_1');
    expect(request?.destinationWarehouse, 'Sex ombori');
    expect(request?.lines.single.itemName, 'Kraska');
    expect(message.previewText, 'Ombor transferi');
  });
}
