import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_audio_playback_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('freeze request is rendered as a structured chat card', (
    tester,
  ) async {
    final playback = ChatAudioPlaybackController();
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: ChatMessageBubble(
            message: const ChatMessage(
              messageId: 'message_freeze_1',
              conversationId: 'conversation_1',
              senderPrincipalId: 'principal_admin',
              senderRole: UserRole.admin,
              senderRef: 'admin_1',
              senderDisplayName: 'Admin',
              clientMessageId: 'order-freeze-request:order-freeze-request_abc',
              sequence: 1,
              type: 'order_freeze_request',
              body: 'Buyurtmani muzlatish so‘rovi',
              metadata: {
                'event_sequence': 1,
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
              createdAtUnix: 100,
            ),
            mine: false,
            playback: playback,
          ),
        ),
      ),
    );

    expect(find.text('Buyurtmani muzlatish so‘rovi'), findsOneWidget);
    expect(find.text('Kutilmoqda'), findsOneWidget);
    expect(find.text('Z-001'), findsOneWidget);
    expect(find.text('7 ta rangli pechat'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
