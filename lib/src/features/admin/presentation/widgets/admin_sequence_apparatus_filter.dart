import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/lists/m3_sequence_list.dart';
import '../../../shared/models/app_models.dart';
import '../../state/admin_apparatus_filter_order_store.dart';
import 'admin_expandable_filter_chip.dart';
import 'admin_top_notice.dart';

enum _ApparatusFilterAction { edit, reset }

class AdminSequenceApparatusFilter extends StatefulWidget {
  const AdminSequenceApparatusFilter({
    super.key,
    required this.apparatus,
    required this.selectedId,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
    this.editableProfileRef,
  });

  final List<AdminApparatus> apparatus;
  final String? selectedId;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AdminApparatus> onSelect;
  final String? editableProfileRef;

  @override
  State<AdminSequenceApparatusFilter> createState() =>
      _AdminSequenceApparatusFilterState();
}

class _AdminSequenceApparatusFilterState
    extends State<AdminSequenceApparatusFilter> {
  List<String> _savedIds = const [];
  int _loadGeneration = 0;
  bool _loaded = false;
  bool _editing = false;

  String get _profileRef => widget.editableProfileRef?.trim() ?? '';

  List<AdminApparatus> get _orderedApparatus =>
      AdminApparatusFilterOrderStore.apply(widget.apparatus, _savedIds);

  @override
  void initState() {
    super.initState();
    unawaited(_loadOrder());
  }

  @override
  void didUpdateWidget(covariant AdminSequenceApparatusFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.editableProfileRef?.trim() ?? '') != _profileRef) {
      unawaited(_loadOrder());
    }
  }

  Future<void> _loadOrder() async {
    final generation = ++_loadGeneration;
    final profileRef = _profileRef;
    _savedIds = const [];
    _loaded = false;
    if (profileRef.isEmpty) return;
    var ids = const <String>[];
    try {
      ids = await AdminApparatusFilterOrderStore.load(profileRef);
    } catch (_) {
      // The catalog remains usable if local preferences cannot be read.
    }
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _savedIds = ids;
      _loaded = true;
    });
  }

  Future<void> _editOrder(AdminApparatus apparatus) async {
    final profileRef = _profileRef;
    if (!_loaded || _editing || profileRef.isEmpty) return;
    final generation = _loadGeneration;
    final ordered = _orderedApparatus;
    final index = ordered.indexWhere((item) => item.id == apparatus.id);
    if (index < 0) return;
    setState(() => _editing = true);
    try {
      final action = await showModalBottomSheet<_ApparatusFilterAction>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    apparatus.name.trim(),
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                for (final item in [
                  (
                    _ApparatusFilterAction.edit,
                    Icons.reorder_rounded,
                    'edit',
                    ordered.length > 1,
                  ),
                  (
                    _ApparatusFilterAction.reset,
                    Icons.restore_rounded,
                    'reset',
                    _savedIds.isNotEmpty,
                  ),
                ])
                  ListTile(
                    key: ValueKey('apparatus-filter-order-${item.$3}'),
                    leading: Icon(item.$2),
                    title: Text(sheetContext.l10n.productionText(
                      'admin.apparatus_filter_order.${item.$3}',
                    )),
                    enabled: item.$4,
                    onTap: item.$4
                        ? () => Navigator.of(sheetContext).pop(item.$1)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      );
      if (action == null ||
          !mounted ||
          generation != _loadGeneration ||
          profileRef != _profileRef) {
        return;
      }
      final ids = <String>[];
      if (action == _ApparatusFilterAction.edit) {
        final editedIds = await _showOrderEditor();
        if (editedIds == null ||
            !mounted ||
            generation != _loadGeneration ||
            profileRef != _profileRef) {
          return;
        }
        // Reconcile any catalog changes that arrived while the editor was open.
        ids.addAll(
          AdminApparatusFilterOrderStore.apply(widget.apparatus, editedIds)
              .map((item) => item.id.trim()),
        );
      }
      await AdminApparatusFilterOrderStore.save(profileRef, ids);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _savedIds = ids);
    } catch (_) {
      if (mounted && generation == _loadGeneration) {
        showAdminTopNotice(
          context,
          context.l10n
              .productionText('admin.apparatus_filter_order.save_failed'),
          tone: AdminTopNoticeTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<List<String>?> _showOrderEditor() {
    final draft = _orderedApparatus;
    return showModalBottomSheet<List<String>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: 0.85,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.productionText(
                          'admin.apparatus_filter_order.edit',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(context.l10n.productionText(
                        'admin.apparatus_filter_order.drag_hint',
                      )),
                    ],
                  ),
                ),
                Expanded(
                  child: M3SequenceList(
                    listKey: const ValueKey('apparatus-filter-order-editor'),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: draft.length,
                    itemKey: (index) => ValueKey(
                      'apparatus-filter-order-row-${draft[index].id}',
                    ),
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        draft.insert(newIndex, draft.removeAt(oldIndex));
                      });
                    },
                    itemBuilder: (context, index) =>
                        ReorderableDelayedDragStartListener(
                      index: index,
                      child: Material(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          leading: Text('${index + 1}'),
                          title: Text(draft[index].name.trim()),
                          trailing: M3SequenceDragHandle(index: index),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OverflowBar(
                    spacing: 12,
                    overflowSpacing: 8,
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const ValueKey('apparatus-filter-order-cancel'),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(context.l10n.adminText('action.cancel')),
                      ),
                      FilledButton(
                        key: const ValueKey('apparatus-filter-order-save'),
                        onPressed: () => Navigator.of(sheetContext).pop(
                          [for (final apparatus in draft) apparatus.id.trim()],
                        ),
                        child: Text(context.l10n.save),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedApparatus;
    final selectedId = widget.selectedId?.trim();
    return AdminExpandableFilterChip<String>(
      label: context.l10n.productionText('worker.queue.filter.apparatus'),
      emptyLabel: context.l10n.productionText('worker.queue.filter.unselected'),
      icon: Icons.precision_manufacturing_rounded,
      selectedValue: selectedId?.isEmpty == true ? null : selectedId,
      options: [
        for (final apparatus in ordered)
          AdminFilterChipOption(
            value: apparatus.id.trim(),
            label: apparatus.name.trim(),
            onLongPress: _loaded && !_editing && _profileRef.isNotEmpty
                ? () => unawaited(_editOrder(apparatus))
                : null,
          ),
      ],
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      onSelect: (id) {
        for (final apparatus in ordered) {
          if (apparatus.id.trim() == id) {
            widget.onSelect(apparatus);
            return;
          }
        }
      },
      padding: EdgeInsets.zero,
    );
  }
}
