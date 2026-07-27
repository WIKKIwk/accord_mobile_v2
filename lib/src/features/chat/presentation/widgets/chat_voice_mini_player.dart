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
        final total = playback.queueLength;
        final currentNumber = playback.queueIndex + 1;
        final queueLabel = total > 1 ? '  •  $currentNumber/$total' : '';
        final sender = message.senderDisplayName.trim().isEmpty
            ? 'Ovozli xabar'
            : message.senderDisplayName.trim();

        return Material(
          elevation: 2,
          shadowColor: Colors.black45,
          color: scheme.surfaceContainerHighest,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: playback.isPlaying ? 'Pauza' : 'Eshitish',
                      onPressed: playback.isLoading
                          ? null
                          : () => unawaited(playback.toggle(message)),
                      icon: playback.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              playback.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 22,
                            ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              Text(
                                '${_voiceDuration(position.inMilliseconds)} / ${_voiceDuration(durationMs)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Ovozli xabar$queueLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Yopish',
                      onPressed: () => unawaited(playback.stop()),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                child: _AudioProgressBar(
                  value: position.inMilliseconds.toDouble(),
                  max: durationMs.toDouble(),
                  onChanged: null,
                ),
              ),
              if (playback.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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

/// Reusable smooth audio progress bar with 60fps interpolation.
class _AudioProgressBar extends StatefulWidget {
  const _AudioProgressBar({
    required this.value,
    required this.max,
    this.onChanged,
  });

  final double value;
  final double max;
  final ValueChanged<double>? onChanged;

  @override
  State<_AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<_AudioProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _thumbController;
  late Animation<double> _thumbAnimation;
  double _dragValue = 0;
  bool _isDragging = false;
  double _targetValue = 0;

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
    _targetValue = widget.value;
  }

  @override
  void didUpdateWidget(_AudioProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.value != _targetValue) {
      _targetValue = widget.value;
      // Animate from current position to new position smoothly
      final currentPos = _thumbAnimation.value;
      final distance = (_targetValue - currentPos).abs();

      // Shorter animation for small jumps (playing audio), longer for seeks
      final duration = distance < widget.max * 0.05
          ? const Duration(milliseconds: 150)
          : const Duration(milliseconds: 250);

      _thumbController.stop();
      _thumbAnimation = Tween<double>(
        begin: currentPos,
        end: _targetValue,
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
    final scheme = Theme.of(context).colorScheme;
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
            height: 24,
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  height: 3,
                  width: progress * 400,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  left: (progress * 400).clamp(0.0, 400) - 5,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOutCubic,
                    width: _isDragging ? 12 : 8,
                    height: _isDragging ? 12 : 8,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.35),
                          blurRadius: _isDragging ? 6 : 3,
                          spreadRadius: _isDragging ? 1 : 0,
                          offset: const Offset(0, 1),
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
