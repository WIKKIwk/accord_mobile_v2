import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/chat_media_models.dart';

class ChatPendingMediaBubble extends StatefulWidget {
  const ChatPendingMediaBubble({
    super.key,
    required this.pending,
    required this.onRetry,
    required this.onCancel,
  });

  final ChatPendingMedia pending;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  State<ChatPendingMediaBubble> createState() => _ChatPendingMediaBubbleState();
}

class _ChatPendingMediaBubbleState extends State<ChatPendingMediaBubble> {
  Future<Uint8List>? imageBytes;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant ChatPendingMediaBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pending.localPath != widget.pending.localPath ||
        oldWidget.pending.kind != widget.pending.kind) {
      _loadPreview();
    }
  }

  void _loadPreview() {
    final pending = widget.pending;
    imageBytes =
        pending.kind == ChatMediaKind.image && pending.localPath.isNotEmpty
            ? XFile(pending.localPath).readAsBytes()
            : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pending.status == ChatPendingMediaStatus.sent) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = widget.pending;
    final canCancel = switch (pending.status) {
      ChatPendingMediaStatus.preparing ||
      ChatPendingMediaStatus.uploading ||
      ChatPendingMediaStatus.processing =>
        true,
      _ => false,
    };
    final canRetry = pending.status == ChatPendingMediaStatus.failed ||
        pending.status == ChatPendingMediaStatus.cancelled;
    return Semantics(
      label: 'Media ${_statusLabel(pending.status)}',
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 250,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14).copyWith(
              bottomRight: const Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _preview(scheme),
                        ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
                        Center(child: _statusIndicator(scheme)),
                      ],
                    ),
                  ),
                ),
              ),
              if (pending.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(7, 6, 7, 2),
                  child: Text(
                    pending.caption,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 4, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pending.error.isNotEmpty
                            ? pending.error
                            : _statusLabel(pending.status),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pending.status == ChatPendingMediaStatus.failed
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (canCancel)
                      IconButton(
                        tooltip: 'Bekor qilish',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onCancel,
                        icon: const Icon(Icons.close_rounded, size: 19),
                      ),
                    if (canRetry)
                      IconButton(
                        tooltip: 'Qayta yuborish',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                  ],
                ),
              ),
              if (pending.status == ChatPendingMediaStatus.uploading)
                LinearProgressIndicator(value: pending.progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(ColorScheme scheme) {
    if (widget.pending.kind == ChatMediaKind.audio) {
      return Icon(
        Icons.graphic_eq_rounded,
        size: 62,
        color: scheme.onSurfaceVariant,
      );
    }
    if (widget.pending.kind == ChatMediaKind.video) {
      return Icon(
        Icons.videocam_rounded,
        size: 62,
        color: scheme.onSurfaceVariant,
      );
    }
    final future = imageBytes;
    if (future == null) {
      return Icon(
        Icons.image_rounded,
        size: 58,
        color: scheme.onSurfaceVariant,
      );
    }
    return FutureBuilder<Uint8List>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return Icon(
            Icons.image_rounded,
            size: 58,
            color: scheme.onSurfaceVariant,
          );
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 700,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            color: scheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  Widget _statusIndicator(ColorScheme scheme) {
    final status = widget.pending.status;
    if (status == ChatPendingMediaStatus.failed ||
        status == ChatPendingMediaStatus.cancelled) {
      return Icon(
        status == ChatPendingMediaStatus.failed
            ? Icons.error_outline_rounded
            : Icons.cancel_outlined,
        color: Colors.white,
        size: 38,
      );
    }
    return SizedBox.square(
      dimension: 42,
      child: CircularProgressIndicator(
        value: status == ChatPendingMediaStatus.uploading
            ? widget.pending.progress
            : null,
        strokeWidth: 3,
        color: Colors.white,
      ),
    );
  }
}

String _statusLabel(ChatPendingMediaStatus status) {
  return switch (status) {
    ChatPendingMediaStatus.preparing => 'Tayyorlanmoqda…',
    ChatPendingMediaStatus.uploading => 'Yuklanmoqda…',
    ChatPendingMediaStatus.processing => 'Qayta ishlanmoqda…',
    ChatPendingMediaStatus.sending => 'Yuborilmoqda…',
    ChatPendingMediaStatus.sent => 'Yuborildi',
    ChatPendingMediaStatus.failed => 'Yuborilmadi',
    ChatPendingMediaStatus.cancelled => 'Bekor qilindi',
  };
}
