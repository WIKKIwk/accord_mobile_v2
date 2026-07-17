import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
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
        onChanged: (_) {},
        onClear: searchController.clear,
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
      child: AnimatedBuilder(
        animation: Listenable.merge([store, searchController]),
        builder: (context, _) {
          return Stack(
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
          );
        },
      ),
    );
  }

  List<ChatConversation> get _visibleConversations {
    final normalized = searchController.text.trim().toLowerCase();
    final started = store.conversations.where(
      (conversation) => conversation.hasMessages,
    );
    if (normalized.isEmpty) return started.toList(growable: false);
    return started.where((conversation) {
      final title = conversation.displayTitle.toLowerCase();
      final preview = conversation.lastMessage?.previewText.toLowerCase() ?? '';
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
            searchController.text.trim().isEmpty
                ? Icons.forum_outlined
                : Icons.search_off_rounded,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            searchController.text.trim().isEmpty
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
        return Padding(
          padding: EdgeInsets.only(
            top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
          ),
          child: _ConversationTile(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              conversations.length,
            ),
            conversation: conversation,
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.chatDetail,
              arguments: conversation,
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.slot,
    required this.conversation,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
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
          '${message?.previewText ?? 'Suhbat boshlandi'}',
      child: AdminSummaryCard(
        slot: slot,
        cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
        onTap: onTap,
        backgroundColor: scheme.surfaceContainerLowest,
        fixedHeight: 61,
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        value: '',
        showChevron: false,
        leading: SizedBox.square(
          dimension: 30,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ChatAvatar(
              name: conversation.displayTitle,
              avatarUrl: peer?.avatarUrl ?? '',
              radius: 15,
            ),
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
        title: conversation.displayTitle,
        subtitle: message?.previewText ?? 'Suhbat boshlandi',
        titleMaxLines: 1,
        subtitleMaxLines: 1,
        titleStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
        subtitleStyle: theme.textTheme.bodySmall?.copyWith(
          color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
          fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
          height: 1.05,
        ),
        elevation:
            ThemeController.instance.variant == AppThemeVariant.white ? 1 : 0,
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
