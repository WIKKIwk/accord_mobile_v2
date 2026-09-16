import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_order_freeze_request_card.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_audio_playback_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final entry in [
    (name: 'assigned replacement', role: UserRole.aparatchi, assigned: true, manage: true, allowed: true),
    (name: 'unassigned worker', role: UserRole.aparatchi, assigned: false, manage: true, allowed: false),
    (name: 'read only worker', role: UserRole.aparatchi, assigned: true, manage: false, allowed: false),
    (name: 'non worker', role: UserRole.materialTaminotchi, assigned: true, manage: true, allowed: false),
  ]) {
    testWidgets('freeze card permissions: ${entry.name}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = SessionProfile(
        role: entry.role, ref: 'worker-2', displayName: 'Replacement worker',
        legalName: '', phone: '', avatarUrl: '',
        capabilities: entry.manage ? ['apparatus.queue.manage'] : ['apparatus.queue.read'],
        assignedApparatus: entry.assigned ? ['apparatus:default:bosma_7'] : [],
      );
      addTearDown(() async {
        AppSession.instance.profile = null;
        await TestModeController.instance.setEnabled(false);
      });
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: ChatOrderFreezeRequestCard(data: OrderFreezeRequestCardData(
          eventSequence: 1, requestId: 'freeze-1', status: OrderFreezeRequestCardStatus.pending,
          orderId: 'zakaz-1', orderNumber: '0001', orderTitle: 'Order',
          requesterRole: 'admin', requesterRef: 'admin-1', requesterDisplayName: 'Admin',
          targetSessionId: 'session-worker-1', targetApparatus: 'apparatus:default:bosma_7',
          targetWorkerRole: 'aparatchi', targetWorkerRef: 'worker-1', targetWorkerDisplayName: 'Worker 1',
          requestedAtUnix: 100, transitionedAtUnix: 100,
        )),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Pauza qilish'), entry.allowed ? findsOneWidget : findsNothing);
      expect(find.text('So‘rovni bekor qilish'), findsNothing);
    });
  }

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
                'target_apparatus': 'apparatus:default:bosma_7',
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
    expect(find.text('apparatus:default:bosma_7'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });
}
