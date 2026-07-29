import 'package:flutter/material.dart';

import '../../../../app/app_router.dart';
import '../../models/chat_models.dart';
import '../../state/chat_failure.dart';
import '../../state/chat_store.dart';

class ChatProfileActionButton extends StatefulWidget {
  const ChatProfileActionButton({super.key, required this.target});

  final ChatDirectoryEntry target;

  @override
  State<ChatProfileActionButton> createState() =>
      _ChatProfileActionButtonState();
}

class _ChatProfileActionButtonState extends State<ChatProfileActionButton> {
  bool _opening = false;

  Future<void> _openChat() async {
    if (_opening) {
      return;
    }
    setState(() => _opening = true);
    try {
      final conversation =
          await ChatStore.instance.openConversation(widget.target);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushNamed(
        AppRoutes.chatDetail,
        arguments: conversation,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(chatFailureMessage(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: _opening ? null : _openChat,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: _opening
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chat_bubble_rounded, size: 17),
      label: Text(_opening ? 'Ochilmoqda...' : 'Xabar yozish'),
    );
  }
}
