import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/chat_models.dart';

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

    return Semantics(
      label: mine ? 'Siz yubordingiz' : message.senderDisplayName,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            margin: EdgeInsets.only(top: compactTop ? 2 : 8),
            padding: const EdgeInsets.fromLTRB(10, 6, 8, 5),
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
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: message.body,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.28),
                  ),
                  TextSpan(
                    text: '  $timeText',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (mine)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              textAlign: mine ? TextAlign.right : TextAlign.left,
            ),
          ),
        ),
      ),
    );
  }
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
