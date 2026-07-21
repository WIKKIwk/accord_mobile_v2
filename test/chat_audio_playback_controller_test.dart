import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_models.dart';
import 'package:accord_mobile_v2/src/features/chat/state/chat_audio_playback_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice queue contains only later voice messages from the same chat', () {
    final selected = _voiceMessage(
      id: 'audio_2',
      conversationId: 'conversation_1',
      sequence: 2,
    );
    final queue = ChatAudioPlaybackController.voiceQueueFor(selected, [
      _voiceMessage(
        id: 'audio_1',
        conversationId: 'conversation_1',
        sequence: 1,
      ),
      selected,
      _textMessage(
        id: 'text_3',
        conversationId: 'conversation_1',
        sequence: 3,
      ),
      _voiceMessage(
        id: 'audio_4',
        conversationId: 'conversation_1',
        sequence: 4,
      ),
      _voiceMessage(
        id: 'audio_other_chat',
        conversationId: 'conversation_2',
        sequence: 5,
      ),
    ]);

    expect(queue.map((message) => message.messageId), ['audio_2', 'audio_4']);
  });
}

ChatMessage _voiceMessage({
  required String id,
  required String conversationId,
  required int sequence,
}) {
  return ChatMessage(
    messageId: id,
    conversationId: conversationId,
    senderPrincipalId: 'principal_1',
    senderRole: UserRole.admin,
    senderRef: 'admin',
    senderDisplayName: 'Admin',
    clientMessageId: id,
    sequence: sequence,
    type: 'audio',
    body: '',
    createdAtUnix: sequence,
    attachment: ChatMessageAttachment(
      attachmentId: 'attachment_$id',
      mediaId: 'media_$id',
      kind: ChatMediaKind.audio,
      contentType: 'audio/mp4',
      sizeBytes: 1,
      widthPixels: 0,
      heightPixels: 0,
      durationMs: 1000,
      contentUrl: '',
      thumbnailUrl: '',
    ),
  );
}

ChatMessage _textMessage({
  required String id,
  required String conversationId,
  required int sequence,
}) {
  return ChatMessage(
    messageId: id,
    conversationId: conversationId,
    senderPrincipalId: 'principal_1',
    senderRole: UserRole.admin,
    senderRef: 'admin',
    senderDisplayName: 'Admin',
    clientMessageId: id,
    sequence: sequence,
    type: 'text',
    body: 'Text',
    createdAtUnix: sequence,
  );
}
