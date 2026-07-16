import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/chat_models.dart';
import '../state/chat_store.dart';
import '../state/chat_failure.dart';
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
    if (body.isEmpty || store.sending) return;
    try {
      await store.sendMessage(widget.conversation.conversationId, body);
      controller.clear();
      store.clearSendError();
      _scrollToBottom();
    } catch (exception) {
      if (!mounted) return;
      final message = store.sendError.isNotEmpty
          ? store.sendError
          : chatFailureMessage(exception);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
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
          showProfileAction: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _ChatParticipantProfileAction(
                participant: widget.conversation.peer,
                onTap: _openParticipantProfile,
              ),
            ),
          ],
          contentPadding: EdgeInsets.zero,
          bottomDockHeight: ChatRoleDock.messageComposerHeight,
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
          child: Text(
            'Birinchi xabaringizni yozing.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      final createdAt = DateTime.fromMillisecondsSinceEpoch(
        message.createdAtUnix * 1000,
      ).toLocal();
      final previous = index == 0 ? null : messages[index - 1];
      final next = index + 1 < messages.length ? messages[index + 1] : null;
      final previousCreatedAt = previous == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              previous.createdAtUnix * 1000,
            ).toLocal();
      final nextCreatedAt = next == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              next.createdAtUnix * 1000,
            ).toLocal();
      final groupedWithPrevious = _sameMessageGroup(
        previous,
        previousCreatedAt,
        message,
        createdAt,
      );
      final groupedWithNext = _sameMessageGroup(
        message,
        createdAt,
        next,
        nextCreatedAt,
      );
      final newDay = previousCreatedAt == null ||
          createdAt.year != previousCreatedAt.year ||
          createdAt.month != previousCreatedAt.month ||
          createdAt.day != previousCreatedAt.day;
      if (newDay) {
        children.add(ChatDateDivider(date: createdAt));
      }
      children.add(
        ChatMessageBubble(
          message: message,
          mine: profile != null && message.isMine(profile),
          compactTop: groupedWithPrevious,
          isLastInGroup: !groupedWithNext,
        ),
      );
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

  bool _sameMessageGroup(
    ChatMessage? first,
    DateTime? firstCreatedAt,
    ChatMessage? second,
    DateTime? secondCreatedAt,
  ) {
    if (first == null ||
        firstCreatedAt == null ||
        second == null ||
        secondCreatedAt == null) {
      return false;
    }
    final sameDay = firstCreatedAt.year == secondCreatedAt.year &&
        firstCreatedAt.month == secondCreatedAt.month &&
        firstCreatedAt.day == secondCreatedAt.day;
    return sameDay &&
        first.senderPrincipalId == second.senderPrincipalId &&
        second.createdAtUnix - first.createdAtUnix <= 300;
  }

  void _openParticipantProfile() {
    final participant = widget.conversation.peer;
    if (participant == null) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.chatParticipantProfile,
      arguments: participant,
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
    return Column(
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
    );
  }
}

class _ChatParticipantProfileAction extends StatelessWidget {
  const _ChatParticipantProfileAction({
    required this.participant,
    required this.onTap,
  });

  final ChatPrincipal? participant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = participant?.displayName.trim().isNotEmpty == true
        ? participant!.displayName
        : 'Suhbat';
    return Semantics(
      button: true,
      label: '$name profili',
      child: AppShellIconAction(
        size: 44,
        iconWidget: ChatAvatar(
          name: name,
          avatarUrl: participant?.avatarUrl ?? '',
          radius: 17,
        ),
        onTap: participant == null ? () {} : onTap,
      ),
    );
  }
}
