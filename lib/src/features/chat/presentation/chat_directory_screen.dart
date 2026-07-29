import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/progressive_fade.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../shared/models/app_models.dart';
import '../models/chat_models.dart';
import '../state/chat_failure.dart';
import '../state/chat_store.dart';

class ChatDirectoryScreen extends StatefulWidget {
  const ChatDirectoryScreen({super.key});

  @override
  State<ChatDirectoryScreen> createState() => _ChatDirectoryScreenState();
}

class _ChatDirectoryScreenState extends State<ChatDirectoryScreen> {
  final store = ChatStore.instance;
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  Timer? debounce;
  String openingRef = '';

  @override
  void initState() {
    super.initState();
    unawaited(
        store.startForCurrentSession().then((_) => store.searchDirectory('')));
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  void _search(String value) {
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 300),
      () => store.searchDirectory(value),
    );
  }

  Future<void> _open(ChatDirectoryEntry target) async {
    if (openingRef.isNotEmpty) return;
    setState(() => openingRef = target.ref);
    try {
      final conversation = await store.openConversation(target);
      if (!mounted) return;
      await Navigator.of(context).pushReplacementNamed(
        AppRoutes.chatDetail,
        arguments: conversation,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(chatFailureMessage(error)),
        ),
      );
    } finally {
      if (mounted) setState(() => openingRef = '');
    }
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
        hintText: 'Foydalanuvchi qidirish',
        onChanged: _search,
        onClear: () {
          searchController.clear();
          _search('');
        },
      ),
      contentPadding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => _directoryList(),
      ),
    );
  }

  Widget _directoryList() {
    if (store.loadingDirectory && store.directory.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (store.error.isNotEmpty && store.directory.isEmpty) {
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: () => store.searchDirectory(searchController.text),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Qayta qidirish'),
        ),
      );
    }
    final entries = store.directory;
    if (entries.isEmpty) {
      return const Center(child: Text('Foydalanuvchi topilmadi'));
    }
    return ProgressiveFade(
      topFade: false,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 24),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Padding(
            padding: EdgeInsets.only(
              top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
            ),
            child: _ChatDirectoryRow(
              slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                index,
                entries.length,
              ),
              entry: entry,
              opening: openingRef == entry.ref,
              onTap: () => _open(entry),
            ),
          );
        },
      ),
    );
  }
}

class _ChatDirectoryRow extends StatelessWidget {
  const _ChatDirectoryRow({
    required this.slot,
    required this.entry,
    required this.opening,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final ChatDirectoryEntry entry;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      value: '',
      showChevron: false,
      trailing: opening
          ? const Padding(
              padding: EdgeInsets.only(left: 12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: entry.displayName,
      subtitle: userRoleLabel(entry.role),
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
    );
  }
}
