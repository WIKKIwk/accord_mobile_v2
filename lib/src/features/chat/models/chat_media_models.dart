enum ChatMediaKind { image, video }

const int chatMediaImageMaxBytes = 15 * 1024 * 1024;
const int chatMediaVideoMaxBytes = 2 * 1024 * 1024 * 1024;
const int chatMediaProcessedVideoMaxBytes = 1024 * 1024 * 1024;
const Duration chatMediaVideoMaxDuration = Duration(seconds: 600);
const int chatMediaVideoMaxLongEdge = 1920;
const int chatMediaVideoMaxShortEdge = 1080;
const int chatMediaVideoMaxFramesPerSecond = 60;

ChatMediaKind chatMediaKindFromJson(Object? value) {
  return value?.toString() == 'video'
      ? ChatMediaKind.video
      : ChatMediaKind.image;
}

String chatMediaKindToJson(ChatMediaKind kind) => kind.name;

class ChatMessageAttachment {
  const ChatMessageAttachment({
    required this.attachmentId,
    required this.mediaId,
    required this.kind,
    required this.contentType,
    required this.sizeBytes,
    required this.widthPixels,
    required this.heightPixels,
    required this.contentUrl,
    required this.thumbnailUrl,
    this.durationMs,
  });

  final String attachmentId;
  final String mediaId;
  final ChatMediaKind kind;
  final String contentType;
  final int sizeBytes;
  final int widthPixels;
  final int heightPixels;
  final int? durationMs;
  final String contentUrl;
  final String thumbnailUrl;

  factory ChatMessageAttachment.fromJson(Map<String, dynamic> json) {
    return ChatMessageAttachment(
      attachmentId: json['attachment_id']?.toString() ?? '',
      mediaId: json['media_id']?.toString() ?? '',
      kind: chatMediaKindFromJson(json['kind']),
      contentType: json['content_type']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      widthPixels: (json['width_pixels'] as num?)?.toInt() ?? 0,
      heightPixels: (json['height_pixels'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      contentUrl: json['content_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'attachment_id': attachmentId,
        'media_id': mediaId,
        'kind': chatMediaKindToJson(kind),
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'width_pixels': widthPixels,
        'height_pixels': heightPixels,
        if (durationMs != null) 'duration_ms': durationMs,
        'content_url': contentUrl,
        'thumbnail_url': thumbnailUrl,
      };
}

class ChatMediaUploadInstruction {
  const ChatMediaUploadInstruction({
    required this.strategy,
    required this.method,
    required this.url,
    required this.headers,
    required this.expiresAtUnix,
    this.chunkSizeBytes = 0,
    this.totalChunks = 0,
  });

  final String strategy;
  final String method;
  final String url;
  final Map<String, String> headers;
  final int expiresAtUnix;
  final int chunkSizeBytes;
  final int totalChunks;

  bool get resumable => strategy == 'resumable_chunks';

  String urlForChunk(int chunkIndex) {
    return url.replaceAll('{chunk_index}', chunkIndex.toString());
  }

  factory ChatMediaUploadInstruction.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    return ChatMediaUploadInstruction(
      strategy: json['strategy']?.toString() ?? '',
      method: json['method']?.toString() ?? 'PUT',
      url: json['url']?.toString() ?? '',
      headers: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      expiresAtUnix: (json['expires_at_unix'] as num?)?.toInt() ?? 0,
      chunkSizeBytes: (json['chunk_size_bytes'] as num?)?.toInt() ?? 0,
      totalChunks: (json['total_chunks'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMediaUploadedChunk {
  const ChatMediaUploadedChunk({
    required this.chunkIndex,
    required this.offsetBytes,
    required this.sizeBytes,
  });

  final int chunkIndex;
  final int offsetBytes;
  final int sizeBytes;

  factory ChatMediaUploadedChunk.fromJson(Map<String, dynamic> json) {
    return ChatMediaUploadedChunk(
      chunkIndex: (json['chunk_index'] as num?)?.toInt() ?? -1,
      offsetBytes: (json['offset_bytes'] as num?)?.toInt() ?? -1,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMediaUpload {
  const ChatMediaUpload({
    required this.mediaId,
    required this.uploadId,
    required this.conversationId,
    required this.clientUploadId,
    required this.kind,
    required this.status,
    required this.contentType,
    required this.sizeBytes,
    required this.errorCode,
    this.uploadMode = 'single',
    this.chunkSizeBytes = 0,
    this.totalChunks = 0,
    this.uploadedChunks = const <ChatMediaUploadedChunk>[],
  });

  final String mediaId;
  final String uploadId;
  final String conversationId;
  final String clientUploadId;
  final ChatMediaKind kind;
  final String status;
  final String contentType;
  final int sizeBytes;
  final String errorCode;
  final String uploadMode;
  final int chunkSizeBytes;
  final int totalChunks;
  final List<ChatMediaUploadedChunk> uploadedChunks;

  bool get ready => status == 'ready';
  bool get terminalFailure => status == 'failed' || status == 'cancelled';
  bool get chunked => uploadMode == 'chunked';
  int get uploadedBytes {
    final seen = <int>{};
    return uploadedChunks.fold<int>(
      0,
      (total, chunk) =>
          seen.add(chunk.chunkIndex) ? total + chunk.sizeBytes : total,
    );
  }

  Set<int> get uploadedChunkIndexes => uploadedChunks
      .where((chunk) => chunk.chunkIndex >= 0)
      .map((chunk) => chunk.chunkIndex)
      .toSet();

  List<int> get missingChunkIndexes {
    if (!chunked || totalChunks <= 0) return const <int>[];
    final uploaded = uploadedChunkIndexes;
    return List<int>.generate(totalChunks, (index) => index)
        .where((index) => !uploaded.contains(index))
        .toList(growable: false);
  }

  factory ChatMediaUpload.fromJson(Map<String, dynamic> json) {
    return ChatMediaUpload(
      mediaId: json['media_id']?.toString() ?? '',
      uploadId: json['upload_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      clientUploadId: json['client_upload_id']?.toString() ?? '',
      kind: chatMediaKindFromJson(json['kind']),
      status: json['status']?.toString() ?? 'pending',
      contentType: json['content_type']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      errorCode: json['error_code']?.toString() ?? '',
      uploadMode: json['upload_mode']?.toString() ?? 'single',
      chunkSizeBytes: (json['chunk_size_bytes'] as num?)?.toInt() ?? 0,
      totalChunks: (json['total_chunks'] as num?)?.toInt() ?? 0,
      uploadedChunks: (json['uploaded_chunks'] as List?)
              ?.whereType<Map>()
              .map(
                (chunk) => ChatMediaUploadedChunk.fromJson(
                  chunk.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false) ??
          const <ChatMediaUploadedChunk>[],
    );
  }
}

class ChatMediaChunkBounds {
  const ChatMediaChunkBounds({
    required this.index,
    required this.startByte,
    required this.endByteExclusive,
    required this.totalSizeBytes,
  });

  final int index;
  final int startByte;
  final int endByteExclusive;
  final int totalSizeBytes;

  int get sizeBytes => endByteExclusive - startByte;
  int get endByteInclusive => endByteExclusive - 1;
  String get contentRange =>
      'bytes $startByte-$endByteInclusive/$totalSizeBytes';
}

ChatMediaChunkBounds chatMediaChunkBounds({
  required int index,
  required int chunkSizeBytes,
  required int totalSizeBytes,
}) {
  if (index < 0 || chunkSizeBytes <= 0 || totalSizeBytes <= 0) {
    throw ArgumentError('Invalid chat media chunk configuration.');
  }
  final startByte = index * chunkSizeBytes;
  if (startByte >= totalSizeBytes) {
    throw RangeError.index(index, const <int>[], 'index');
  }
  return ChatMediaChunkBounds(
    index: index,
    startByte: startByte,
    endByteExclusive: (startByte + chunkSizeBytes).clamp(0, totalSizeBytes),
    totalSizeBytes: totalSizeBytes,
  );
}

class ChatMediaInitialization {
  const ChatMediaInitialization({
    required this.media,
    required this.upload,
    required this.created,
  });

  final ChatMediaUpload media;
  final ChatMediaUploadInstruction upload;
  final bool created;

  factory ChatMediaInitialization.fromJson(Map<String, dynamic> json) {
    return ChatMediaInitialization(
      media: ChatMediaUpload.fromJson(
        (json['media'] as Map).cast<String, dynamic>(),
      ),
      upload: ChatMediaUploadInstruction.fromJson(
        (json['upload'] as Map).cast<String, dynamic>(),
      ),
      created: json['created'] == true,
    );
  }
}

enum ChatPendingMediaStatus {
  preparing,
  uploading,
  processing,
  sending,
  sent,
  failed,
  cancelled,
}

class ChatPendingMedia {
  const ChatPendingMedia({
    required this.localId,
    required this.conversationId,
    required this.clientMessageId,
    required this.clientUploadId,
    required this.kind,
    required this.localPath,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.caption,
    required this.status,
    required this.progress,
    required this.createdAtUnix,
    this.mediaId = '',
    this.uploadId = '',
    this.error = '',
    this.durationMs = 0,
  });

  final String localId;
  final String conversationId;
  final String clientMessageId;
  final String clientUploadId;
  final ChatMediaKind kind;
  final String localPath;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String caption;
  final ChatPendingMediaStatus status;
  final double progress;
  final int createdAtUnix;
  final String mediaId;
  final String uploadId;
  final String error;
  final int durationMs;

  ChatPendingMedia copyWith({
    String? clientUploadId,
    String? localPath,
    ChatPendingMediaStatus? status,
    double? progress,
    String? mediaId,
    String? uploadId,
    String? error,
  }) {
    return ChatPendingMedia(
      localId: localId,
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      clientUploadId: clientUploadId ?? this.clientUploadId,
      kind: kind,
      localPath: localPath ?? this.localPath,
      filename: filename,
      contentType: contentType,
      sizeBytes: sizeBytes,
      caption: caption,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAtUnix: createdAtUnix,
      mediaId: mediaId ?? this.mediaId,
      uploadId: uploadId ?? this.uploadId,
      error: error ?? this.error,
      durationMs: durationMs,
    );
  }

  factory ChatPendingMedia.fromJson(Map<String, dynamic> json) {
    return ChatPendingMedia(
      localId: json['local_id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      clientMessageId: json['client_message_id']?.toString() ?? '',
      clientUploadId: json['client_upload_id']?.toString() ?? '',
      kind: chatMediaKindFromJson(json['kind']),
      localPath: json['local_path']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      caption: json['caption']?.toString() ?? '',
      status: ChatPendingMediaStatus.values.firstWhere(
        (status) => status.name == json['status']?.toString(),
        orElse: () => ChatPendingMediaStatus.failed,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      mediaId: json['media_id']?.toString() ?? '',
      uploadId: json['upload_id']?.toString() ?? '',
      error: json['error']?.toString() ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'conversation_id': conversationId,
        'client_message_id': clientMessageId,
        'client_upload_id': clientUploadId,
        'kind': chatMediaKindToJson(kind),
        'local_path': localPath,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
        'caption': caption,
        'status': status.name,
        'progress': progress,
        'created_at_unix': createdAtUnix,
        'media_id': mediaId,
        'upload_id': uploadId,
        'error': error,
        if (durationMs > 0) 'duration_ms': durationMs,
      };
}
