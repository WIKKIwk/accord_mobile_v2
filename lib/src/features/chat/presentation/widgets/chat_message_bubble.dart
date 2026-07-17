import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/widgets/display/image_fade.dart';
import '../../models/chat_media_models.dart';
import '../../models/chat_models.dart';
import '../chat_media_viewer.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    this.compactTop = false,
    this.isLastInGroup = true,
  });

  final ChatMessage message;
  final bool mine;
  final bool compactTop;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = math.min(screenWidth * 0.78, 520.0);
    final time = DateTime.fromMillisecondsSinceEpoch(
      message.createdAtUnix * 1000,
    ).toLocal();
    final timeText = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    final attachment = message.attachment;

    return Semantics(
      label: mine ? 'Siz yubordingiz' : message.senderDisplayName,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: EdgeInsets.only(top: compactTop ? 2 : 8),
            padding: attachment == null
                ? const EdgeInsets.fromLTRB(10, 6, 8, 5)
                : const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: mine
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14).copyWith(
                bottomRight:
                    mine && isLastInGroup ? const Radius.circular(4) : null,
                bottomLeft:
                    !mine && isLastInGroup ? const Radius.circular(4) : null,
              ),
            ),
            child: attachment == null
                ? _MessageText(
                    body: message.body,
                    timeText: timeText,
                    mine: mine,
                  )
                : _MediaMessageContent(
                    attachment: attachment,
                    caption: message.body,
                    timeText: timeText,
                    mine: mine,
                    heroTag: _chatMediaHeroTag(message, attachment),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  const _MessageText({
    required this.body,
    required this.timeText,
    required this.mine,
  });

  final String body;
  final String timeText;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: body,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.28),
          ),
          TextSpan(
            text: '  $timeText',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (mine) _deliveryStatus(scheme),
        ],
      ),
      textAlign: mine ? TextAlign.right : TextAlign.left,
    );
  }
}

class _MediaMessageContent extends StatelessWidget {
  const _MediaMessageContent({
    required this.attachment,
    required this.caption,
    required this.timeText,
    required this.mine,
    required this.heroTag,
  });

  final ChatMessageAttachment attachment;
  final String caption;
  final String timeText;
  final bool mine;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = math.min(MediaQuery.sizeOf(context).width * 0.7, 320.0);
    final rawRatio = attachment.widthPixels > 0 && attachment.heightPixels > 0
        ? attachment.widthPixels / attachment.heightPixels
        : 4 / 3;
    final ratio = rawRatio.clamp(0.65, 1.8).toDouble();
    final api = MobileApi.instance;
    final thumbnailUri = api.chatMediaUri(attachment.thumbnailUrl);
    final contentUri = api.chatMediaUri(attachment.contentUrl);
    final headers = api.chatMediaHeaders();
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Material(
              color: scheme.surfaceContainerHighest,
              child: InkWell(
                onTap: () => _openViewer(
                  context,
                  contentUri: contentUri,
                  previewUri: thumbnailUri,
                  headers: headers,
                ),
                child: Hero(
                  tag: heroTag,
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ImageFade(
                          image: NetworkImage(
                            thumbnailUri.toString(),
                            headers: headers,
                          ),
                          fit: BoxFit.cover,
                          cacheWidth: 900,
                          placeholder: ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorBuilder: (_, __) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: Icon(
                              attachment.kind == ChatMediaKind.video
                                  ? Icons.video_file_outlined
                                  : Icons.broken_image_outlined,
                              color: scheme.onSurfaceVariant,
                              size: 38,
                            ),
                          ),
                        ),
                        if (attachment.kind == ChatMediaKind.video) ...[
                          ColoredBox(
                              color: Colors.black.withValues(alpha: 0.16)),
                          const Center(
                            child: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                          if (attachment.durationMs != null)
                            Positioned(
                              right: 7,
                              bottom: 6,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    _mediaDuration(attachment.durationMs!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 4, 2),
            child: Text.rich(
              TextSpan(
                children: [
                  if (caption.trim().isNotEmpty)
                    TextSpan(
                      text: caption.trim(),
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.25),
                    ),
                  TextSpan(
                    text: caption.trim().isEmpty ? timeText : '  $timeText',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (mine) _deliveryStatus(scheme),
                ],
              ),
              textAlign: mine ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(
    BuildContext context, {
    required Uri contentUri,
    required Uri previewUri,
    required Map<String, String> headers,
  }) {
    Navigator.of(context).push<void>(
      chatMediaViewerRoute(
        kind: attachment.kind,
        contentUri: contentUri,
        previewUri: previewUri,
        headers: headers,
        heroTag: heroTag,
      ),
    );
  }
}

String _chatMediaHeroTag(
  ChatMessage message,
  ChatMessageAttachment attachment,
) {
  final stableId = attachment.attachmentId.isNotEmpty
      ? attachment.attachmentId
      : message.messageId.isNotEmpty
          ? message.messageId
          : attachment.contentUrl;
  return 'chat-media-$stableId';
}

WidgetSpan _deliveryStatus(ColorScheme scheme) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Icon(
        Icons.check_rounded,
        size: 15,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

String _mediaDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;
    final label = switch (difference) {
      0 => 'Bugun',
      1 => 'Kecha',
      _ => '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}',
    };
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
