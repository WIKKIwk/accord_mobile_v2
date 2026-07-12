import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/chat_models.dart';
import '../state/chat_store.dart';
import 'widgets/chat_avatar.dart';

class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  final store = ChatStore.instance;

  @override
  void initState() {
    super.initState();
    unawaited(store.startForCurrentSession());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return AppShell(
          title: 'Chatlar',
          subtitle: store.connected ? 'Onlayn' : 'Ulanmoqda…',
          nativeTopBar: true,
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: store.refreshConversations,
                child: _conversationList(context),
              ),
              Positioned(
                right: 18,
                bottom: 22,
                child: FloatingActionButton(
                  heroTag: 'chat-new-conversation',
                  tooltip: 'Yangi suhbat',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.chatDirectory,
                  ),
                  child: const Icon(Icons.edit_rounded),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _conversationList(BuildContext context) {
    if (store.loadingConversations && store.conversations.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (store.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 120, 28, 100),
        children: const [
          Icon(Icons.forum_outlined, size: 56),
          SizedBox(height: 16),
          Text(
            'Hali suhbat yo‘q. Pastdagi tugma orqali foydalanuvchini tanlang.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: store.conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final conversation = store.conversations[index];
        return _ConversationTile(
          conversation: conversation,
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.chatDetail,
            arguments: conversation,
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final peer = conversation.peer;
    final message = conversation.lastMessage;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      leading: ChatAvatar(
        name: conversation.displayTitle,
        avatarUrl: peer?.avatarUrl ?? '',
      ),
      title: Text(
        conversation.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        message?.body ?? 'Suhbat boshlandi',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: conversation.unreadCount > 0
          ? Badge(label: Text('${conversation.unreadCount}'))
          : const Icon(Icons.chevron_right_rounded),
    );
  }
}
