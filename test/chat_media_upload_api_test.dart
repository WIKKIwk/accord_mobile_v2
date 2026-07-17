import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/chat/models/chat_media_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    AppSession.instance.token = 'test-token';
  });

  tearDown(() {
    AppSession.instance.token = null;
  });

  test('chunk upload sends exact range and reports aggregate-ready media',
      () async {
    final progress = <double>[];
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, endsWith('/chunks/2'));
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['content-range'], 'bytes 8-11/20');
      expect(request.contentLength, 4);
      expect(request.bodyBytes, [1, 2, 3, 4]);
      return http.Response(
        jsonEncode({
          'media': {
            'media_id': 'media_1',
            'upload_id': 'upload_1',
            'conversation_id': 'conversation_1',
            'client_upload_id': 'client_upload_1',
            'kind': 'video',
            'status': 'pending',
            'content_type': 'video/mp4',
            'size_bytes': 20,
            'upload_mode': 'chunked',
            'chunk_size_bytes': 4,
            'total_chunks': 5,
            'uploaded_chunks': [
              {'chunk_index': 2, 'offset_bytes': 8, 'size_bytes': 4},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final media = await MobileApi.instance.chatUploadMediaChunk(
      instruction: const ChatMediaUploadInstruction(
        strategy: 'resumable_chunks',
        method: 'PUT',
        url: '/chunks/{chunk_index}',
        headers: {'content-type': 'application/octet-stream'},
        expiresAtUnix: 100,
        chunkSizeBytes: 4,
        totalChunks: 5,
      ),
      bounds: const ChatMediaChunkBounds(
        index: 2,
        startByte: 8,
        endByteExclusive: 12,
        totalSizeBytes: 20,
      ),
      content: Stream<List<int>>.value(const [1, 2, 3, 4]),
      onProgress: progress.add,
      client: client,
    );

    expect(media.uploadedChunkIndexes, {2});
    expect(progress, isNotEmpty);
    expect(progress.last, 1);
  });
}
