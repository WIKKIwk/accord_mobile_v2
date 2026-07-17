import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('upload initialization parses local and direct storage instructions',
      () {
    final initialization = ChatMediaInitialization.fromJson({
      'media': {
        'media_id': 'media_1',
        'upload_id': 'upload_1',
        'conversation_id': 'conversation_1',
        'client_upload_id': 'client_upload_1',
        'kind': 'image',
        'status': 'pending',
        'content_type': 'image/jpeg',
        'size_bytes': 321,
      },
      'upload': {
        'strategy': 'local_proxy',
        'method': 'PUT',
        'url':
            '/v1/mobile/chat/conversations/conversation_1/media/uploads/upload_1/content',
        'headers': {'Content-Type': 'image/jpeg'},
        'expires_at_unix': 200,
      },
      'created': true,
    });

    expect(initialization.created, isTrue);
    expect(initialization.media.kind, ChatMediaKind.image);
    expect(initialization.media.status, 'pending');
    expect(initialization.upload.strategy, 'local_proxy');
    expect(initialization.upload.headers['Content-Type'], 'image/jpeg');
  });

  test('resumable initialization restores uploaded chunks without duplicates',
      () {
    final initialization = ChatMediaInitialization.fromJson({
      'media': {
        'media_id': 'media_1',
        'upload_id': 'upload_1',
        'conversation_id': 'conversation_1',
        'client_upload_id': 'client_upload_1',
        'kind': 'video',
        'status': 'pending',
        'content_type': 'video/mp4',
        'size_bytes': 25,
        'upload_mode': 'chunked',
        'chunk_size_bytes': 10,
        'total_chunks': 3,
        'uploaded_chunks': [
          {'chunk_index': 0, 'offset_bytes': 0, 'size_bytes': 10},
          {'chunk_index': 0, 'offset_bytes': 0, 'size_bytes': 10},
          {'chunk_index': 2, 'offset_bytes': 20, 'size_bytes': 5},
        ],
      },
      'upload': {
        'strategy': 'resumable_chunks',
        'method': 'PUT',
        'url': '/uploads/upload_1/chunks/{chunk_index}',
        'headers': {'content-type': 'application/octet-stream'},
        'expires_at_unix': 200,
        'chunk_size_bytes': 10,
        'total_chunks': 3,
      },
      'created': false,
    });

    expect(initialization.created, isFalse);
    expect(initialization.media.chunked, isTrue);
    expect(initialization.media.uploadedBytes, 15);
    expect(initialization.media.missingChunkIndexes, [1]);
    expect(initialization.upload.resumable, isTrue);
    expect(initialization.upload.urlForChunk(1), '/uploads/upload_1/chunks/1');
  });

  test('large video chunk bounds preserve the final partial chunk', () {
    const chunkSize = 8 * 1024 * 1024;
    final totalSize = chatMediaVideoMaxBytes - 1;
    final finalChunk = chatMediaChunkBounds(
      index: 255,
      chunkSizeBytes: chunkSize,
      totalSizeBytes: totalSize,
    );

    expect(finalChunk.startByte, 255 * chunkSize);
    expect(finalChunk.sizeBytes, chunkSize - 1);
    expect(
      finalChunk.contentRange,
      'bytes ${255 * chunkSize}-${totalSize - 1}/$totalSize',
    );
  });

  test('pending media survives JSON storage with retry identity intact', () {
    const pending = ChatPendingMedia(
      localId: 'local_1',
      conversationId: 'conversation_1',
      clientMessageId: 'client_message_1',
      clientUploadId: 'client_upload_1',
      kind: ChatMediaKind.video,
      localPath: '/private/chat_media_pending/local_1.mp4',
      filename: 'clip.mp4',
      contentType: 'video/mp4',
      sizeBytes: 2048,
      caption: 'Sinov',
      status: ChatPendingMediaStatus.processing,
      progress: 1,
      createdAtUnix: 100,
      mediaId: 'media_1',
      uploadId: 'upload_1',
      durationMs: 600000,
    );

    final restored = ChatPendingMedia.fromJson(pending.toJson());

    expect(restored.localPath, pending.localPath);
    expect(restored.clientMessageId, pending.clientMessageId);
    expect(restored.clientUploadId, pending.clientUploadId);
    expect(restored.status, ChatPendingMediaStatus.processing);
    expect(restored.mediaId, 'media_1');
    expect(restored.uploadId, 'upload_1');
    expect(restored.durationMs, 600000);
  });

  test('pending media state can restart without changing message identity', () {
    const pending = ChatPendingMedia(
      localId: 'local_1',
      conversationId: 'conversation_1',
      clientMessageId: 'client_message_1',
      clientUploadId: 'client_upload_1',
      kind: ChatMediaKind.image,
      localPath: '/private/local_1.jpg',
      filename: 'photo.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 100,
      caption: '',
      status: ChatPendingMediaStatus.failed,
      progress: 0.4,
      createdAtUnix: 100,
      error: 'offline',
    );

    final retry = pending.copyWith(
      status: ChatPendingMediaStatus.preparing,
      progress: 0,
      error: '',
    );

    expect(retry.localId, pending.localId);
    expect(retry.clientMessageId, pending.clientMessageId);
    expect(retry.clientUploadId, pending.clientUploadId);
    expect(retry.status, ChatPendingMediaStatus.preparing);
    expect(retry.error, isEmpty);
  });

  test('V1 media limits match the approved contract', () {
    expect(chatMediaImageMaxBytes, 15 * 1024 * 1024);
    expect(chatMediaVideoMaxBytes, 2 * 1024 * 1024 * 1024);
    expect(chatMediaProcessedVideoMaxBytes, 1024 * 1024 * 1024);
    expect(chatMediaVideoMaxDuration, const Duration(seconds: 600));
    expect(chatMediaVideoMaxLongEdge, 1920);
    expect(chatMediaVideoMaxShortEdge, 1080);
    expect(chatMediaVideoMaxFramesPerSecond, 60);
  });
}
