import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('voice message renders playback controls without opening viewer',
      (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: ChatMessageBubble(
            message: ChatMessage(
              messageId: 'message_audio_1',
              conversationId: 'conversation_1',
              senderPrincipalId: 'principal_1',
              senderRole: UserRole.customer,
              senderRef: 'customer_1',
              senderDisplayName: 'Customer',
              clientMessageId: 'client_audio_1',
              sequence: 1,
              type: 'audio',
              body: '',
              createdAtUnix: 100,
              attachment: ChatMessageAttachment(
                attachmentId: 'attachment_audio_1',
                mediaId: 'media_audio_1',
                kind: ChatMediaKind.audio,
                contentType: 'audio/mp4',
                sizeBytes: 4096,
                widthPixels: 480,
                heightPixels: 120,
                durationMs: 12345,
                contentUrl: '/v1/mobile/chat/media/media_audio_1/content',
                thumbnailUrl: '/v1/mobile/chat/media/media_audio_1/thumbnail',
              ),
            ),
            mine: false,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Eshitish'), findsOneWidget);
    expect(find.text('0:12'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
