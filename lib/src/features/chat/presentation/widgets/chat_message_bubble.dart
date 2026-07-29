import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/widgets/display/image_fade.dart';
import '../../models/chat_media_models.dart';
import '../../models/chat_models.dart';
import '../../state/chat_audio_playback_controller.dart';
import '../chat_media_viewer.dart';
import 'chat_order_freeze_request_card.dart';
import 'chat_inventory_transfer_request_card.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.playback,
    this.compactTop = false,
    this.isLastInGroup = true,
  });

  final ChatMessage message;
  final bool mine;
  final ChatAudioPlaybackController playback;
  final bool compactTop;
  final bool isLastInGroup;

  @override
  Widget build(BuildContext context) {
    final freezeRequest = message.orderFreezeRequest;
    if (freezeRequest != null && freezeRequest.isValid) {
      return ChatOrderFreezeRequestCard(data: freezeRequest);
    }
    final transferRequest = message.inventoryTransferRequest;
    if (transferRequest != null && transferRequest.isValid) {
      return ChatInventoryTransferRequestCard(data: transferRequest);
    }
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
                    message: message,
                    attachment: attachment,
                    caption: message.body,
                    timeText: timeText,
                    mine: mine,
                    playback: playback,
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
    required this.message,
    required this.attachment,
    required this.caption,
    required this.timeText,
    required this.mine,
    required this.playback,
    required this.heroTag,
  });

  final ChatMessage message;
  final ChatMessageAttachment attachment;
  final String caption;
  final String timeText;
  final bool mine;
  final ChatAudioPlaybackController playback;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (attachment.kind == ChatMediaKind.audio) {
      return _AudioMessageContent(
        message: message,
        attachment: attachment,
        caption: caption,
        timeText: timeText,
        mine: mine,
        playback: playback,
      );
    }
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
        mediaId: attachment.mediaId,
        contentUri: contentUri,
        previewUri: previewUri,
        headers: headers,
        heroTag: heroTag,
      ),
    );
  }
}

class _AudioMessageContent extends StatelessWidget {
  const _AudioMessageContent({
    required this.message,
    required this.attachment,
    required this.caption,
    required this.timeText,
    required this.mine,
    required this.playback,
  });

  final ChatMessage message;
  final ChatMessageAttachment attachment;
  final String caption;
  final String timeText;
  final bool mine;
  final ChatAudioPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final current = playback.isCurrent(message);
        final playing = current && playback.isPlaying;
        final loading = current && playback.isLoading;
        final duration = current
            ? playback.currentDuration
            : Duration(milliseconds: attachment.durationMs ?? 0);
        final position = current ? playback.position : Duration.zero;
        final maximum = math.max(duration.inMilliseconds, 1).toDouble();
        final value =
            position.inMilliseconds.clamp(0, maximum.round()).toDouble();
        return SizedBox(
          width: math.min(MediaQuery.sizeOf(context).width * 0.7, 320),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
            child: Column(
              crossAxisAlignment:
                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: playing ? 'Pauza' : 'Eshitish',
                      onPressed: loading
                          ? null
                          : () => unawaited(playback.toggle(message)),
                      icon: loading
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
 mainAxisSize: MainAxisSize.min,
 children: [
   _AudioProgressBar(
     value: value,
     max: maximum,
     onChanged: current && !loading
         ? (next) => unawaited(playback.seek(next))
         : null,
     activeColor: scheme.primary,
     inactiveColor: scheme.onSurfaceVariant.withValues(alpha: 0.2),
   ),
   const SizedBox(height: 6),
   Row(
     mainAxisAlignment: MainAxisAlignment.spaceBetween,
     children: [
       Text(
         _mediaDuration(position.inMilliseconds),
         style: Theme.of(context).textTheme.labelSmall,
       ),
       Text(
         _mediaDuration(duration.inMilliseconds),
         style: Theme.of(context).textTheme.labelSmall,
       ),
     ],
   ),
 ],
 ),
                    ),
                  ],
                ),
                if (current && playback.error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      playback.error,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 3, 4, 2),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (caption.trim().isNotEmpty)
                          TextSpan(
                            text: caption.trim(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(height: 1.25),
                          ),
                        TextSpan(
                          text:
                              caption.trim().isEmpty ? timeText : '  $timeText',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
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
          ),
        );
      },
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

/// Custom audio progress bar with smooth thumb animation.
/// Silky 60fps interpolation when audio position changes.
class _AudioProgressBar extends StatefulWidget {
  const _AudioProgressBar({
    required this.value,
    required this.max,
    this.onChanged,
    required this.activeColor,
    required this.inactiveColor,
  });

  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<_AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<_AudioProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _thumbController;
  late Animation<double> _thumbAnimation;
  double _dragValue = 0;
  bool _isDragging = false;
  double _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _thumbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _thumbAnimation = Tween<double>(
      begin: widget.value,
      end: widget.value,
    ).animate(
      CurvedAnimation(parent: _thumbController, curve: Curves.linear),
    );
    _displayValue = widget.value;
  }

  @override
  void didUpdateWidget(_AudioProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != _displayValue) {
      _displayValue = widget.value;
      // Animate from current position to new position smoothly
      final currentPos = _thumbAnimation.value;
      final distance = (_displayValue - currentPos).abs();

      // Shorter animation for small jumps (playing audio), longer for seeks
      final duration = distance < widget.max * 0.05
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 250);

      _thumbController.stop();
      _thumbAnimation = Tween<double>(
        begin: currentPos,
        end: _displayValue,
      ).animate(
        CurvedAnimation(
          parent: _thumbController,
          curve: Curves.linearToEaseOut,
        ),
      );
      _thumbController.duration = duration;
      _thumbController.reset();
      _thumbController.forward();
    }
  }

  @override
  void dispose() {
    _thumbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxSafe = widget.max > 0 ? widget.max : 1;
    final currentValue = _isDragging ? _dragValue : _thumbAnimation.value;
    final progress = (currentValue / maxSafe).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragStart: widget.onChanged != null
          ? (details) {
              setState(() {
                _isDragging = true;
                _dragValue = widget.value;
              });
            }
          : null,
      onHorizontalDragUpdate: widget.onChanged != null
          ? (details) {
              final box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final width = box.size.width;
              final newProgress = (localPosition.dx / width).clamp(0.0, 1.0);
              setState(() {
                _dragValue = newProgress * maxSafe;
              });
            }
          : null,
      onHorizontalDragEnd: widget.onChanged != null
          ? (details) {
              widget.onChanged!(_dragValue);
              setState(() {
                _isDragging = false;
              });
            }
          : null,
      onTapDown: widget.onChanged != null
          ? (details) {
              final box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final width = box.size.width;
              final newProgress = (localPosition.dx / width).clamp(0.0, 1.0);
              widget.onChanged!(newProgress * maxSafe);
            }
          : null,
      child: AnimatedBuilder(
        animation: _thumbController,
        builder: (context, child) {
          return Container(
            height: 32,
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Active progress
                Container(
                  height: 4,
                  width: progress * 220,
                  decoration: BoxDecoration(
                    color: widget.activeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Animated thumb
                Positioned(
                  left: (progress * 220).clamp(0.0, 220) - 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOutCubic,
                    width: _isDragging ? 14 : 10,
                    height: _isDragging ? 14 : 10,
                    decoration: BoxDecoration(
                      color: widget.activeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.3),
                          blurRadius: _isDragging ? 8 : 4,
                          spreadRadius: _isDragging ? 2 : 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
