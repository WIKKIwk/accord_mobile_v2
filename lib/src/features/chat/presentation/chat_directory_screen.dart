import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/progressive_fade.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../shared/models/app_models.dart';
import '../models/chat_models.dart';
import '../state/chat_failure.dart';
import '../state/chat_store.dart';
import '../../../core/localization/urdu_aware_text.dart';

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
  UserRole? selectedRole;
  bool roleFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(store.startForCurrentSession().then((_) {
      if (mounted) return _loadDirectory();
    }));
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
      () => store.searchDirectory(value, role: selectedRole),
    );
  }

  Future<void> _loadDirectory() =>
      store.searchDirectory(searchController.text, role: selectedRole);

  void _selectRole(UserRole? role) {
    debounce?.cancel();
    setState(() {
      selectedRole = role;
      roleFilterExpanded = false;
    });
    unawaited(_loadDirectory());
  }

  String _roleLabel(UserRole role) {
    final l10n = context.l10n;
    return switch (role) {
      UserRole.supplier => l10n.adminText('users.kind.supplier'),
      UserRole.werka => l10n.adminText('users.kind.werka'),
      UserRole.customer => l10n.adminText('users.kind.customer'),
      UserRole.aparatchi => l10n.adminText('users.kind.worker'),
      UserRole.qolipchi => l10n.adminText('users.kind.mold_maker'),
      UserRole.boyoqchi => l10n.adminText('users.kind.painter'),
      UserRole.materialTaminotchi =>
        l10n.adminText('users.kind.material_supplier'),
      UserRole.admin => l10n.adminRoleName,
      UserRole.tayyorlovMasteri ||
      UserRole.homashyoRezkachi =>
        userRoleLabel(role),
    };
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
      child: Column(
        children: [
          AdminExpandableFilterChip<UserRole?>(
            chipKey: const ValueKey('chat-directory-role-filter'),
            label: context.l10n.adminText('users.role'),
            emptyLabel: context.l10n.adminText('users.all_roles'),
            icon: Icons.person_outline_rounded,
            selectedValue: selectedRole,
            expanded: roleFilterExpanded,
            onToggle: () =>
                setState(() => roleFilterExpanded = !roleFilterExpanded),
            onSelect: _selectRole,
            options: [
              AdminFilterChipOption(
                value: null,
                label: context.l10n.adminText('users.all_roles'),
                key: const ValueKey('chat-directory-role-option-all'),
              ),
              for (final role in UserRole.values)
                AdminFilterChipOption(
                  value: role,
                  label: _roleLabel(role),
                  key: ValueKey(
                    'chat-directory-role-option-${userRoleToJson(role)}',
                  ),
                ),
            ],
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: store,
              builder: (context, _) => _directoryList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _directoryList() {
    final entries = store.directory
        .where((entry) => selectedRole == null || entry.role == selectedRole)
        .toList(growable: false);
    if (store.loadingDirectory && entries.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }
    if (store.error.isNotEmpty && entries.isEmpty) {
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: _loadDirectory,
          icon: const Icon(Icons.refresh_rounded),
          label: const UrduAwareText('Qayta qidirish'),
        ),
      );
    }
    if (entries.isEmpty) {
      return const Center(child: UrduAwareText('Foydalanuvchi topilmadi'));
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
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
      value: '',
      showChevron: false,
      trailing: opening
          ? const Padding(
              padding: EdgeInsetsDirectional.only(start: 12),
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
