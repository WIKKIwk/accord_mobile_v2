import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/session.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/chat_models.dart';
import '../state/chat_store.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_message_composer.dart';
import 'widgets/chat_role_dock.dart';

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
      store.clearSendError();
      _scrollToBottom();
    } catch (_) {}
  }

  void _draftChanged() {
    store.clearSendError();
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
          subtitle: '',
          titleWidget: _ConversationTitle(
            conversation: widget.conversation,
            connected: store.connected,
          ),
          nativeTopBar: true,
          contentPadding: EdgeInsets.zero,
          bottom: ChatRoleDock(
            messageComposer: ChatMessageComposer(
              controller: controller,
              sending: store.sending,
              errorText: store.sendError,
              onSend: _send,
              onDraftChanged: _draftChanged,
              embeddedInDock: true,
            ),
          ),
          child: _messages(messages),
        );
      },
    );
  }

  Widget _messages(List<ChatMessage> messages) {
    if (messages.isEmpty &&
        store.loadingMessagesFor(widget.conversation.conversationId)) {
      return const Center(child: AppLoadingIndicator());
    }
    if (messages.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.waving_hand_outlined,
                size: 42,
                color: scheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                'Suhbatni boshlang',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Birinchi xabaringizni yozing.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }
    final profile = AppSession.instance.profile;
    final children = <Widget>[];
    if (store.hasMoreMessages(widget.conversation.conversationId)) {
      children.add(
        Center(
          child: TextButton.icon(
            onPressed: () => store.loadOlderMessages(
              widget.conversation.conversationId,
            ),
            icon: const Icon(Icons.expand_less_rounded),
            label: const Text('Oldingi xabarlar'),
          ),
        ),
      );
    }
    DateTime? previousDay;
    ChatMessage? previousMessage;
    for (final message in messages) {
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        message.createdAtUnix * 1000,
      ).toLocal();
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final newDay = previousDay == null || day != previousDay;
      if (newDay) {
        children.add(ChatDateDivider(date: createdAt));
      }
      final compactTop = !newDay &&
          previousMessage?.senderPrincipalId == message.senderPrincipalId &&
          message.createdAtUnix - (previousMessage?.createdAtUnix ?? 0) <= 300;
      children.add(
        ChatMessageBubble(
          message: message,
          mine: profile != null && message.isMine(profile),
          compactTop: compactTop,
        ),
      );
      previousDay = day;
      previousMessage = message;
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      ),
    );
  }
}

class _ConversationTitle extends StatelessWidget {
  const _ConversationTitle({
    required this.conversation,
    required this.connected,
  });

  final ChatConversation conversation;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        ChatAvatar(
          name: conversation.displayTitle,
          avatarUrl: conversation.peer?.avatarUrl ?? '',
          radius: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                connected ? 'Onlayn' : 'Ulanmoqda…',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
