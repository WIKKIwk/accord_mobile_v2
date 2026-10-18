part of 'chat_message_bubble.dart';

enum _ChatMessageAction { copy, selectText }

Future<void> _showChatMessageActions(
  BuildContext context,
  ChatMessage message,
  bool mine,
) async {
  final hasText = message.body.trim().isNotEmpty;
  final action = await showModalBottomSheet<_ChatMessageAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _ChatMessageDetails(message: message, mine: mine),
            ),
            if (hasText) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Nusxa olish'),
                onTap: () =>
                    Navigator.pop(sheetContext, _ChatMessageAction.copy),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields_rounded),
                title: const Text('Matnni tanlash'),
                onTap: () =>
                    Navigator.pop(sheetContext, _ChatMessageAction.selectText),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _ChatMessageAction.copy:
      await _copyChatMessageText(context, message.body);
    case _ChatMessageAction.selectText:
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Xabar matni',
                            style:
                                Theme.of(dialogContext).textTheme.titleLarge),
                      ),
                      IconButton(
                        tooltip: 'Yopish',
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(right: 8, bottom: 16),
                      child: SelectableText(
                        message.body,
                        style: Theme.of(dialogContext)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(height: 1.4),
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () =>
                          _copyChatMessageText(context, message.body),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Nusxa olish'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

Future<void> _copyChatMessageText(BuildContext context, String text) async {
  String feedback;
  try {
    await Clipboard.setData(ClipboardData(text: text));
    feedback = 'Matn nusxalandi';
  } catch (_) {
    feedback = 'Matndan nusxa olib bo‘lmadi';
  }
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(feedback)));
}

class _ChatMessageDetails extends StatelessWidget {
  const _ChatMessageDetails({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sender = message.senderDisplayName.trim();
    final editedAt = message.editedAtUnix;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mine
              ? 'Siz'
              : sender.isEmpty
                  ? 'Xabar'
                  : sender,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Yuborilgan: ${_chatMessageDateTime(message.createdAtUnix)}',
          style: theme.textTheme.bodyMedium,
        ),
        if (editedAt != null && editedAt > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Tahrirlangan: ${_chatMessageDateTime(editedAt)}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

String _chatMessageDateTime(int unixSeconds) {
  final date =
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000).toLocal();
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${twoDigits(date.day)}.${twoDigits(date.month)}.${date.year} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}
