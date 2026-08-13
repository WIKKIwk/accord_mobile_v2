import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import '../qolip_search_matcher.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipBlocksScreen extends StatefulWidget {
  const QolipBlocksScreen({super.key});

  @override
  State<QolipBlocksScreen> createState() => _QolipBlocksScreenState();
}

class _QolipBlocksScreenState extends State<QolipBlocksScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late Future<QolipBlocksResult> _blocksFuture;
  String _query = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _blocksFuture = MobileApi.instance.qolipBlocksData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final next = MobileApi.instance.qolipBlocksData();
    setState(() => _blocksFuture = next);
    await next;
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current != route) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  Future<void> _openBlockActions(QolipBlock block) async {
    if (_saving) {
      return;
    }
    final l10n = context.l10n;
    final action = await showModalBottomSheet<_QolipBlockAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.qolipText('action.edit')),
              onTap: () => Navigator.of(sheetContext).pop(
                _QolipBlockAction.edit,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.qolipText('action.delete')),
              onTap: () => Navigator.of(sheetContext).pop(
                _QolipBlockAction.delete,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _QolipBlockAction.edit:
        await _editBlock(block);
      case _QolipBlockAction.delete:
        await _deleteBlock(block);
    }
  }

  Future<void> _editBlock(QolipBlock block) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: block.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qolipText('blocks.edit_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: l10n.qolipText('blocks.name'),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          AppDialogActionRow(
            cancelLabel: l10n.qolipText('action.cancel'),
            confirmLabel: l10n.qolipText('action.save'),
            gap: 8,
            vertical: true,
            onCancel: () => Navigator.of(dialogContext).pop(),
            onConfirm: () => Navigator.of(dialogContext).pop(controller.text),
          ),
        ],
      ),
    );
    controller.dispose();
    final updatedName = name?.trim() ?? '';
    if (!mounted || updatedName.isEmpty || updatedName == block.name.trim()) {
      return;
    }
    await _runBlockAction(
      () => MobileApi.instance.qolipUpdateBlock(
        block: block,
        newName: updatedName,
      ),
      successMessage: l10n.qolipText('blocks.updated'),
      failureMessage: l10n.qolipText('blocks.update_failed'),
    );
  }

  Future<void> _deleteBlock(QolipBlock block) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qolipText('blocks.delete_title')),
        content: Text(
          l10n.qolipText(
            'blocks.delete_message',
            values: {'name': block.name},
          ),
        ),
        actions: [
          AppDialogActionRow(
            cancelLabel: l10n.qolipText('action.cancel'),
            confirmLabel: l10n.qolipText('action.delete'),
            gap: 8,
            vertical: true,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    await _runBlockAction(
      () => MobileApi.instance.qolipDeleteBlock(block),
      successMessage: l10n.qolipText('blocks.deleted'),
      failureMessage: l10n.qolipText('blocks.delete_failed'),
    );
  }

  Future<void> _runBlockAction(
    Future<Object?> Function() action, {
    required String successMessage,
    required String failureMessage,
  }) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(
              error,
              fallback: failureMessage,
              l10n: context.l10n,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: l10n.qolipText('blocks.search'),
        onChanged: (value) => setState(() => _query = value.trim()),
        onClear: () {
          _searchController.clear();
          setState(() => _query = '');
        },
        onBackWithContext: (context) =>
            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
        leadingIcon: Icons.menu_rounded,
        leadingTooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      drawer: QolipNavigationDrawer(
        selectedIndex: 1,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<QolipBlocksResult>(
          future: _blocksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(
                onRetry: _reload,
                message: l10n.qolipText('blocks.load_failed'),
              );
            }
            final blocks =
                (snapshot.data?.blocks ?? const <QolipBlock>[]).where((block) {
              final query = _query;
              return qolipBlockSearchMatches(query, block);
            }).toList(growable: false);
            if (blocks.isEmpty) {
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 180),
                    Center(child: Text(l10n.qolipText('blocks.empty'))),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  4,
                  4,
                  4,
                  MediaQuery.viewPaddingOf(context).bottom + 112,
                ),
                itemCount: blocks.length,
                separatorBuilder: (_, __) => const SizedBox(
                  height: M3SegmentedListGeometry.gap,
                ),
                itemBuilder: (context, index) {
                  final block = blocks[index];
                  return M3SegmentFilledSurface(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      blocks.length,
                    ),
                    cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(
                      M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index,
                        blocks.length,
                      ),
                    ),
                    onLongPress: () => _openBlockActions(block),
                    child: ListTile(
                      leading: const Icon(Icons.view_module_outlined),
                      title: Text(block.name),
                      subtitle: Text(block.warehouse),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _QolipBlockAction { edit, delete }
