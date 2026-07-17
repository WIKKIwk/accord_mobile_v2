enum ChatMediaKind { image, video }

const int chatMediaImageMaxBytes = 15 * 1024 * 1024;
const int chatMediaVideoMaxBytes = 75 * 1024 * 1024;
const Duration chatMediaVideoMaxDuration = Duration(seconds: 120);

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
  });

  final String strategy;
  final String method;
  final String url;
  final Map<String, String> headers;
  final int expiresAtUnix;

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

  bool get ready => status == 'ready';
  bool get terminalFailure => status == 'failed' || status == 'cancelled';

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
    );
  }
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
      };
}
