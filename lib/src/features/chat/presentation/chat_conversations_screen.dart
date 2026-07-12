import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../models/chat_models.dart';
import '../state/chat_store.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_role_dock.dart';

class ChatConversationsScreen extends StatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  final store = ChatStore.instance;
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  String query = '';

  @override
  void initState() {
    super.initState();
    unawaited(store.startForCurrentSession());
  }

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return AppShell(
          title: '',
          subtitle: '',
          nativeTopBar: true,
          automaticallyImplyNativeLeading: false,
          nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
          profileActionListenable: searchFocusNode,
          showProfileActionResolver: () => !searchFocusNode.hasFocus,
          titleWidget: AdminCatalogSearchField(
            controller: searchController,
            focusNode: searchFocusNode,
            hintText: 'Chatlardan qidirish',
            onChanged: (value) => setState(() => query = value.trim()),
            onClear: () {
              searchController.clear();
              setState(() => query = '');
            },
            onBackWithContext: (context) {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
                return;
              }
              AppRootNavigation.replaceRootRoute(
                context,
                AppSession.instance.homeRoute,
              );
            },
          ),
          bottom: const ChatRoleDock(),
          contentPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: store.refreshConversations,
                child: _conversationList(context),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'chat-new-conversation',
                  tooltip: 'Yangi suhbat',
                  onPressed: () => Navigator.of(context).pushNamed(
                    AppRoutes.chatDirectory,
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Yangi chat'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<ChatConversation> get _visibleConversations {
    final normalized = query.toLowerCase();
    final started = store.conversations.where(
      (conversation) => conversation.hasMessages,
    );
    if (normalized.isEmpty) return started.toList(growable: false);
    return started.where((conversation) {
      final title = conversation.displayTitle.toLowerCase();
      final preview = conversation.lastMessage?.body.toLowerCase() ?? '';
      return title.contains(normalized) || preview.contains(normalized);
    }).toList(growable: false);
  }

  Widget _conversationList(BuildContext context) {
    if (store.loadingConversations && store.conversations.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (store.error.isNotEmpty && store.conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(32, 100, 32, 120),
        children: [
          const Icon(Icons.cloud_off_outlined, size: 52),
          const SizedBox(height: 14),
          const Text(
            'Chatlar yuklanmadi',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: store.refreshConversations,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Qayta yuklash'),
            ),
          ),
        ],
      );
    }
    final conversations = _visibleConversations;
    if (conversations.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 90, 28, 120),
        children: [
          Icon(
            query.isEmpty ? Icons.forum_outlined : Icons.search_off_rounded,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? 'Hali suhbat yo‘q. “Yangi chat” orqali foydalanuvchini tanlang.'
                : 'Bu qidiruv bo‘yicha chat topilmadi.',
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 104),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final peer = conversation.peer;
    final message = conversation.lastMessage;
    final unread = conversation.unreadCount > 0;
    final timestamp = message?.createdAtUnix ?? conversation.updatedAtUnix;
    return Semantics(
      button: true,
      label: '${conversation.displayTitle}, '
          '${message?.body ?? 'Suhbat boshlandi'}',
      child: ListTile(
        minTileHeight: 78,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ChatAvatar(
          name: conversation.displayTitle,
          avatarUrl: peer?.avatarUrl ?? '',
          radius: 27,
        ),
        title: Text(
          conversation.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          message?.body ?? 'Suhbat boshlandi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _conversationTime(context, timestamp),
              style: theme.textTheme.labelMedium?.copyWith(
                color: unread ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 7),
            if (unread)
              Badge(
                backgroundColor: scheme.primary,
                textColor: scheme.onPrimary,
                label: Text('${conversation.unreadCount}'),
              )
            else
              const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String _conversationTime(BuildContext context, int unixSeconds) {
  if (unixSeconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
  ).toLocal();
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
  return MaterialLocalizations.of(context).formatCompactDate(date);
}
