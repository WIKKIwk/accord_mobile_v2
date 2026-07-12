import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/session.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/chat_models.dart';
import '../state/chat_store.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.conversation});

  final ChatConversation conversation;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final store = ChatStore.instance;
  final controller = TextEditingController();
  final scrollController = ScrollController();
  int previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    store.setActiveConversation(widget.conversation.conversationId);
    unawaited(store.loadMessages(widget.conversation.conversationId));
  }

  @override
  void dispose() {
    store.setActiveConversation('');
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = controller.text.trim();
    if (body.isEmpty) return;
    try {
      await store.sendMessage(widget.conversation.conversationId, body);
      controller.clear();
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xabar yuborilmadi')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final messages = store.messagesFor(widget.conversation.conversationId);
        if (messages.length > previousMessageCount) {
          previousMessageCount = messages.length;
          _scrollToBottom();
        }
        return AppShell(
          title: widget.conversation.displayTitle,
          subtitle: store.connected ? 'Onlayn' : 'Ulanmoqda…',
          nativeTopBar: true,
          child: Column(
            children: [
              Expanded(child: _messages(messages)),
              _Composer(
                controller: controller,
                sending: store.sending,
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _messages(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return const Center(child: Text('Birinchi xabarni yozing'));
    }
    final profile = AppSession.instance.profile;
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      itemCount: messages.length +
          (store.hasMoreMessages(widget.conversation.conversationId) ? 1 : 0),
      itemBuilder: (context, index) {
        if (store.hasMoreMessages(widget.conversation.conversationId) &&
            index == 0) {
          return Center(
            child: TextButton(
              onPressed: () => store.loadOlderMessages(
                widget.conversation.conversationId,
              ),
              child: const Text('Oldingi xabarlar'),
            ),
          );
        }
        final offset =
            store.hasMoreMessages(widget.conversation.conversationId) ? 1 : 0;
        final message = messages[index - offset];
        final mine = profile != null && message.isMine(profile);
        return _MessageBubble(message: message, mine: mine);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = DateTime.fromMillisecondsSinceEpoch(
      message.createdAtUnix * 1000,
    ).toLocal();
    final timeText = '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 10, 6),
        decoration: BoxDecoration(
          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: mine ? const Radius.circular(4) : null,
            bottomLeft: mine ? null : const Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.body),
            const SizedBox(height: 3),
            Text(
              timeText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                maxLength: 4000,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Xabar yozing',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(22)),
                  ),
                ),
                onSubmitted: (_) {
                  if (!sending) onSend();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Yuborish',
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
