import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_color_picker.dart';
import 'qolip_management_dialogs.dart';
import 'qolip_products_screen.dart' show QolipCodeRow;
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipSetsScreen extends StatefulWidget {
  const QolipSetsScreen({super.key});
  @override
  State<QolipSetsScreen> createState() => _QolipSetsScreenState();
}

class _QolipSetsScreenState extends State<QolipSetsScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  late Future<List<QolipManagedSet>> _future;
  String? _expanded;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.qolipManagedSets();
  }

  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = MobileApi.instance.qolipManagedSets();
    setState(() => _future = future);
    await future;
  }

  Future<void> _add(QolipManagedSet entry) async {
    final used =
        entry.set.members.map((m) => qolipPantonNumber(m.qolipColor)).toSet();
    final available = List.generate(qolipPantonMaxNumber, (i) => i + 1)
        .where((i) => !used.contains(i))
        .firstOrNull;
    final saved = await showQolipMoldAddDialog(
      context,
      scope:
          '${entry.set.code}\n${context.l10n.qolipManagementText('set_scope')}',
      initialSize: entry.set.members.firstOrNull?.qolipSize ?? 0,
      availablePantonNumber: available,
      onSave: (draft) async {
        await MobileApi.instance.qolipEditSet(current: entry, add: [draft]);
      },
    );
    if (!mounted) return;
    if (saved == true) QolipDataRevision.notifyLocationsChanged();
    // Also refresh after a rejected stale fingerprint.
    await _reload();
  }

  Future<void> _remove(QolipManagedSet entry, QolipProduct mold) async {
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qolipManagementText('delete_title')),
        content: Text([
          l10n.qolipManagementText('delete_body',
              values: {'code': mold.qolipCode}),
          if (entry.set.members.length == 1)
            l10n.qolipManagementText('delete_last'),
        ].join('\n\n')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.qolipText('action.cancel'))),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.qolipText('action.delete'))),
        ],
      ),
    );
    if (!mounted || accepted != true) return;
    setState(() => _saving = true);
    try {
      await MobileApi.instance
          .qolipEditSet(current: entry, remove: [mold.qolipCode]);
      QolipDataRevision.notifyLocationsChanged();
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(qolipErrorMessage(error, l10n: l10n))));
        await _reload();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _navigate(String route) {
    if (route != AppRoutes.qolipSets) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.adminText('detail.code_copied'))));
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
      profileActionListenable: _focus,
      showProfileActionResolver: () => !_focus.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _search,
        focusNode: _focus,
        hintText: l10n.qolipManagementText('search'),
        onChanged: (_) => setState(() {}),
        onClear: () => setState(_search.clear),
        onBackWithContext: (context) =>
            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
        leadingIcon: Icons.menu_rounded,
        leadingTooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      drawer: QolipNavigationDrawer(
          selectedIndex: 9,
          selectedRouteName: AppRoutes.qolipSets,
          onNavigate: _navigate),
      bottom: const QolipDock(activeTab: null, showPrimaryFab: false),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<List<QolipManagedSet>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) return AppRetryState(onRetry: _reload);
            final query = _search.text.trim().toLowerCase();
            final entries = (snapshot.data ?? const <QolipManagedSet>[])
                .where((entry) =>
                    entry.set.members.isNotEmpty &&
                    [
                      entry.set.code,
                      ...entry.set.members.map((m) => m.qolipCode)
                    ].any((value) => value.toLowerCase().contains(query)))
                .toList();
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    4, 4, 4, MediaQuery.viewPaddingOf(context).bottom + 112),
                itemCount: entries.isEmpty ? 1 : entries.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: M3SegmentedListGeometry.gap),
                itemBuilder: (context, index) {
                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                          child: Text(l10n.qolipManagementText('empty'))),
                    );
                  }
                  final entry = entries[index];
                  final expanded = _expanded == entry.set.id;
                  final slot =
                      M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index, entries.length);
                  final radius = M3SegmentedListGeometry.borderRadius(
                      slot, M3SegmentedListGeometry.cornerRadiusForSlot(slot));
                  return Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: radius,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.layers_outlined,
                                size: 22,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer),
                          ),
                          title: Text(entry.set.code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                          subtitle: Text(l10n.qolipText('products.mold_count',
                              values: {'count': entry.set.members.length})),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _copy(entry.set.code),
                                tooltip: l10n.qolipManagementText('copy_code'),
                                icon: const Icon(Icons.copy_outlined, size: 18),
                              ),
                              Icon(expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more),
                            ],
                          ),
                          onTap: _saving
                              ? null
                              : () => setState(() =>
                                  _expanded = expanded ? null : entry.set.id),
                        ),
                        if (expanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Text(l10n.qolipManagementText('linked',
                                    values: {
                                      'count': entry.set.productLabels.length
                                    }),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge),
                                if (entry.set.productLabels.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                        entry.set.productLabels.join(', '),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ),
                                const SizedBox(height: 12),
                                for (final mold in entry.set.members)
                                  QolipCodeRow(
                                    product: mold,
                                    selectionMode: false,
                                    selected: false,
                                    onTap: () => _copy(mold.qolipCode),
                                    onCodeTap: () => _copy(mold.qolipCode),
                                    onLongPress: null,
                                    onEdit: () {},
                                    trailing: IconButton(
                                      tooltip: l10n.qolipText('action.delete'),
                                      onPressed: _saving || mold.isInUse
                                          ? null
                                          : () => _remove(entry, mold),
                                      icon: const Icon(
                                          Icons.delete_outline_rounded),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                FilledButton.tonalIcon(
                                  onPressed: _saving ? null : () => _add(entry),
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.qolipManagementText('add')),
                                ),
                              ],
                            ),
                          ),
                      ],
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
