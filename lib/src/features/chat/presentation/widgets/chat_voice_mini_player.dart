import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/chat_audio_playback_controller.dart';

class ChatVoiceMiniPlayer extends StatelessWidget {
  const ChatVoiceMiniPlayer({
    super.key,
    required this.playback,
  });

  final ChatAudioPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final message = playback.currentMessage;
        if (message == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final duration = playback.currentDuration;
        final position = playback.position;
        final durationMs = duration.inMilliseconds;
        final progress = durationMs <= 0
            ? null
            : (position.inMilliseconds / durationMs).clamp(0.0, 1.0);
        final total = playback.queueLength;
        final currentNumber = playback.queueIndex + 1;
        final queueLabel = total > 1 ? '  •  $currentNumber/$total' : '';
        final sender = message.senderDisplayName.trim().isEmpty
            ? 'Ovozli xabar'
            : message.senderDisplayName.trim();

        return Material(
          color: scheme.surfaceContainerHigh,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 3, 4, 2),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: playback.isPlaying ? 'Pauza' : 'Eshitish',
                      visualDensity: VisualDensity.compact,
                      onPressed: playback.isLoading
                          ? null
                          : () => unawaited(playback.toggle(message)),
                      icon: playback.isLoading
                          ? const SizedBox.square(
                              dimension: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              playback.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Ovozli xabar$queueLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _voiceDuration(position.inMilliseconds),
                                style: theme.textTheme.labelSmall,
                              ),
                              Text(
                                _voiceDuration(durationMs),
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yopish',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => unawaited(playback.stop()),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: scheme.onSurfaceVariant.withValues(
                    alpha: 0.12,
                  ),
                  color: scheme.primary,
                ),
              ),
              if (playback.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      playback.error,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _voiceDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
