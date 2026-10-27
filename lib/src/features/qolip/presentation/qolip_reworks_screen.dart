import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_mileage_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipReworksScreen extends StatefulWidget {
  const QolipReworksScreen({super.key});
  @override
  State<QolipReworksScreen> createState() => _QolipReworksScreenState();
}

class _QolipReworksScreenState extends State<QolipReworksScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _selected = <String>{};
  late Future<void> _future;
  List<QolipReworkEntry> _entries = const [];
  bool _returned = false;
  bool _saving = false;
  int _generation = 0;
  String? _requestSignature;
  String? _requestId;
  late String _readScope;

  @override
  void initState() {
    super.initState();
    _readScope = currentSessionReadScope();
    _future = _load();
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scope = currentSessionReadScope();
    final generation = ++_generation;
    final entries = await MobileApi.instance.qolipReworks(status: 'all');
    if (!mounted ||
        generation != _generation ||
        scope != currentSessionReadScope()) {
      return;
    }
    _readScope = scope;
    _entries = entries;
    _selected.retainAll(
        entries.where((row) => row.isOpen).map((row) => row.id).toSet());
  }

  Future<void> _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
    return future;
  }

  void _toggle(String id) {
    if (_saving) return;
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  Future<void> _returnSelected() async {
    if (_saving || _selected.isEmpty) return;
    final l10n = context.l10n;
    final scope = currentSessionReadScope();
    if (_readScope != scope) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.qolipReworkText('session_changed'))));
      return;
    }
    final ids = _selected.toList()..sort();
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(l10n.qolipReworkText('return')),
              content: Text(l10n.qolipReworkText('return_confirm',
                  values: {'count': ids.length})),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.qolipText('action.cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(l10n.qolipReworkText('return'))),
              ],
            ));
    if (!mounted || accepted != true) return;
    if (scope != currentSessionReadScope()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.qolipReworkText('session_changed'))));
      return;
    }
    final signature = ids.join('\u0000');
    setState(() => _saving = true);
    try {
      if (_requestSignature != signature || _requestId == null) {
        final requestId = newQolipReworkRequestId();
        _requestId = requestId;
        _requestSignature = signature;
      }
      final returned = await MobileApi.instance
          .qolipReturnFromRework(requestId: _requestId!, reworkIds: ids);
      if (!mounted) return;
      final updates = {for (final entry in returned) entry.id: entry};
      setState(() {
        // A refresh started before the return must not overwrite this result.
        _generation++;
        _entries = [
          for (final entry in _entries) updates[entry.id] ?? entry,
        ];
        _requestSignature = null;
        _requestId = null;
        _selected.clear();
      });
      QolipDataRevision.notifyLocationsChanged();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n
              .qolipReworkText('returned', values: {'count': ids.length}))));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(qolipErrorMessage(error,
                l10n: l10n, fallback: l10n.qolipReworkText('failed')))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
      titleWidget: AdminCatalogSearchField(
          controller: _search,
          focusNode: _focus,
          hintText: l10n.qolipReworkText('search'),
          onChanged: (_) => setState(() {}),
          onClear: () => setState(_search.clear),
          onBackWithContext: (context) =>
              AppShellDrawerScope.maybeOf(context)?.openDrawer(),
          leadingIcon: Icons.menu_rounded,
          leadingTooltip:
              MaterialLocalizations.of(context).openAppDrawerTooltip),
      drawer: QolipNavigationDrawer(
          selectedIndex: 10,
          selectedRouteName: AppRoutes.qolipReworks,
          onNavigate: (route) {
            if (route != AppRoutes.qolipReworks) {
              Navigator.of(context).pushReplacementNamed(route);
            }
          }),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!_returned && _selected.isNotEmpty)
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('qolip-rework-return-selected'),
                    onPressed: _saving ? null : _returnSelected,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.assignment_return_outlined),
                    label: Text(l10n.qolipReworkText('return_selected',
                        values: {'count': _selected.length})),
                  ))),
        const QolipDock(activeTab: null),
      ]),
      contentPadding: EdgeInsets.zero,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.qolipReworkText('title'),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                            value: false,
                            label: Text(l10n.qolipReworkText('open'))),
                        ButtonSegment(
                            value: true,
                            label: Text(l10n.qolipReworkText('history'))),
                      ],
                      selected: {
                        _returned
                      },
                      onSelectionChanged: _saving
                          ? null
                          : (values) => setState(() {
                                _returned = values.single;
                                _selected.clear();
                              })),
                ])),
        Expanded(
            child: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) return AppRetryState(onRetry: _reload);
            final needle = _search.text.trim().toLowerCase();
            final entries = _entries
                .where((entry) =>
                    entry.isOpen != _returned &&
                    [
                      entry.qolipCode,
                      entry.setId,
                      entry.itemCode,
                      entry.itemName
                    ].any((text) => text.toLowerCase().contains(needle)))
                .toList();
            final groups = <String, List<QolipReworkEntry>>{};
            for (final entry in entries) {
              final key = entry.setId.isEmpty ? entry.qolipCode : entry.setId;
              groups.putIfAbsent(key, () => []).add(entry);
            }
            return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  key: const PageStorageKey('qolip-reworks-list'),
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      8, 0, 8, MediaQuery.viewPaddingOf(context).bottom + 24),
                  children: groups.isEmpty
                      ? [
                          Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                  child: Text(l10n.qolipReworkText(
                                      _returned ? 'history_empty' : 'empty'))))
                        ]
                      : [
                          for (final group in groups.entries)
                            _group(group.key, group.value)
                        ],
                ));
          },
        )),
      ]),
    );
  }

  Widget _group(String setId, List<QolipReworkEntry> entries) {
    final l10n = context.l10n;
    final names = entries
        .map((row) => row.itemName.isEmpty ? row.itemCode : row.itemName)
        .where((name) => name.isNotEmpty)
        .toSet();
    return Card(
        key: ValueKey('qolip-rework-group-$setId'),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: _returned
                  ? const Icon(Icons.layers_outlined)
                  : Checkbox(
                      value: entries.every((row) => _selected.contains(row.id)),
                      onChanged: _saving
                          ? null
                          : (selected) => setState(() {
                                if (selected == true) {
                                  _selected
                                      .addAll(entries.map((row) => row.id));
                                } else {
                                  _selected
                                      .removeAll(entries.map((row) => row.id));
                                }
                              })),
              title: Text(names.isEmpty ? setId : names.join(', ')),
              subtitle: Text('${l10n.qolipSharedSetText('id')}: $setId'),
            ),
            const Divider(height: 1),
            for (final entry in entries)
              ListTile(
                key: ValueKey('qolip-rework-${entry.id}'),
                selected: _selected.contains(entry.id),
                leading: _returned
                    ? const Icon(Icons.check_circle_outline)
                    : Checkbox(
                        key: ValueKey('qolip-rework-select-${entry.qolipCode}'),
                        value: _selected.contains(entry.id),
                        onChanged: _saving ? null : (_) => _toggle(entry.id)),
                title: Text(entry.qolipCode),
                subtitle: Text([
                  if (entry.color.isNotEmpty) l10n.qolipColorName(entry.color),
                  '${l10n.qolipReworkText('sent_at')}: ${qolipReworkDate(entry.sentAt)}',
                  if (entry.returnedAt != null)
                    '${l10n.qolipReworkText('returned_at')}: ${qolipReworkDate(entry.returnedAt!)}',
                ].join('\n')),
                onTap: _saving
                    ? null
                    : _returned
                        ? () => unawaited(
                            showQolipMileageSheet(context, entry.qolipCode))
                        : () => _toggle(entry.id),
                trailing: IconButton(
                    key: ValueKey('qolip-mileage-${entry.qolipCode}'),
                    tooltip: l10n.qolipReworkText('mileage'),
                    onPressed: () => unawaited(
                        showQolipMileageSheet(context, entry.qolipCode)),
                    icon: const Icon(Icons.speed_rounded)),
              ),
          ],
        ));
  }
}
