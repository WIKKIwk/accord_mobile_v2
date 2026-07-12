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
    expect(page.hasMore, isFalse);
  });
}
