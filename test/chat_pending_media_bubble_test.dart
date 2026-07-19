import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_pending_media_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uploading media exposes progress and cancellation', (
    tester,
  ) async {
    var cancellations = 0;
    await tester.pumpWidget(
      _host(
        pending: _pending(
          status: ChatPendingMediaStatus.uploading,
          progress: 0.35,
        ),
        onCancel: () => cancellations++,
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, 0.35);
    await tester.tap(find.byTooltip('Bekor qilish'));
    expect(cancellations, 1);
  });

  testWidgets('failed media exposes its error and retry action', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        pending: _pending(
          status: ChatPendingMediaStatus.failed,
          error: 'Internet uzildi',
        ),
        onRetry: () => retries++,
      ),
    );

    expect(find.text('Internet uzildi'), findsOneWidget);
    expect(find.byTooltip('Bekor qilish'), findsNothing);
    await tester.tap(find.byTooltip('Qayta yuborish'));
    expect(retries, 1);
  });

  testWidgets('sent placeholder leaves the list after server acceptance', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(pending: _pending(status: ChatPendingMediaStatus.sent)),
    );

    expect(find.byType(ChatPendingMediaBubble), findsOneWidget);
    expect(find.text('Yuborildi'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('voice upload uses an audio-specific pending indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        pending: _pending(
          status: ChatPendingMediaStatus.processing,
          kind: ChatMediaKind.audio,
        ),
      ),
    );

    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.text('Qayta ishlanmoqda…'), findsOneWidget);
  });
}

Widget _host({
  required ChatPendingMedia pending,
  VoidCallback? onRetry,
  VoidCallback? onCancel,
}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: ChatPendingMediaBubble(
        pending: pending,
        onRetry: onRetry ?? () {},
        onCancel: onCancel ?? () {},
      ),
    ),
  );
}

ChatPendingMedia _pending({
  required ChatPendingMediaStatus status,
  double progress = 0,
  String error = '',
  ChatMediaKind kind = ChatMediaKind.video,
}) {
  return ChatPendingMedia(
    localId: 'local_1',
    conversationId: 'conversation_1',
    clientMessageId: 'client_message_1',
    clientUploadId: 'client_upload_1',
    kind: kind,
    localPath: '',
    filename: kind == ChatMediaKind.audio ? 'voice.m4a' : 'clip.mp4',
    contentType: kind == ChatMediaKind.audio ? 'audio/mp4' : 'video/mp4',
    sizeBytes: 100,
    caption: 'Sinov',
    status: status,
    progress: progress,
    createdAtUnix: 100,
    error: error,
  );
}
