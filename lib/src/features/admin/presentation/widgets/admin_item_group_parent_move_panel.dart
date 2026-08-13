import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../shared/models/app_models.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'admin_picker_field.dart';
import 'admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminItemGroupParentMovePanel extends StatefulWidget {
  const AdminItemGroupParentMovePanel({
    super.key,
    required this.groups,
    required this.onMoved,
    this.showHeader = true,
    this.elevation = 2,
    this.backgroundColor,
  });

  final List<String> groups;
  final ValueChanged<AdminItemGroup> onMoved;
  final bool showHeader;
  final double elevation;
  final Color? backgroundColor;

  @override
  State<AdminItemGroupParentMovePanel> createState() =>
      _AdminItemGroupParentMovePanelState();
}

class _AdminItemGroupParentMovePanelState
    extends State<AdminItemGroupParentMovePanel> {
  String? groupName;
  String? parentName;
  bool submitting = false;

  List<String> get movableGroups => widget.groups
      .map((group) => group.trim())
      .where((group) => group.isNotEmpty && group != 'All Item Groups')
      .toSet()
      .toList()
    ..sort();

  List<String> get parentGroups {
    final current = groupName?.trim() ?? '';
    return widget.groups
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty && group != current)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void didUpdateWidget(AdminItemGroupParentMovePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final movable = movableGroups;
    final parents = parentGroups;
    if (groupName != null && !movable.contains(groupName)) {
      groupName = null;
    }
    if (parentName != null && !parents.contains(parentName)) {
      parentName =
          parents.contains('All Item Groups') ? 'All Item Groups' : null;
    }
  }

  Future<void> _openGroupPicker(List<String> groups) async {
    if (submitting || groups.isEmpty) {
      return;
    }
    final picked = await _showGroupPicker(
      title: context.l10n.adminText('item_group.movable_group'),
      hintText: context.l10n.adminText('item_group.group_search'),
      groups: groups,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      groupName = picked;
      if (parentName == picked) {
        parentName =
            parentGroups.contains('All Item Groups') ? 'All Item Groups' : null;
      }
    });
  }

  Future<void> _openParentPicker(List<String> groups) async {
    if (submitting || groups.isEmpty) {
      return;
    }
    final picked = await _showGroupPicker(
      title: context.l10n.adminText('item_group.new_parent'),
      hintText: context.l10n.adminText('item_group.parent_search_short'),
      groups: groups,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => parentName = picked);
  }

  Future<String?> _showGroupPicker({
    required String title,
    required String hintText,
    required List<String> groups,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<String>(
          title: title,
          hintText: hintText,
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? groups
                : groups.where((group) {
                    return group.toLowerCase().contains(normalizedQuery);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (group) => group,
          itemSubtitle: (_) => '',
          onSelected: (group) => Navigator.of(context).pop(group),
        );
      },
    );
  }

  Future<void> _move() async {
    final group = groupName?.trim() ?? '';
    final parent = parentName?.trim() ?? '';
    if (group.isEmpty || parent.isEmpty || submitting) {
      return;
    }
    setState(() => submitting = true);
    try {
      final moved = await MobileApi.instance.adminMoveItemGroupParent(
        name: group,
        parent: parent,
      );
      if (!mounted) {
        return;
      }
      widget.onMoved(moved);
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          'item_group.parent_updated',
          values: {'name': moved.itemGroupName},
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.adminText(
              'item_group.parent_update_failed',
              values: {'error': error},
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final movable = movableGroups;
    final parents = parentGroups;
    final canSubmit = !submitting &&
        (groupName?.isNotEmpty ?? false) &&
        (parentName?.isNotEmpty ?? false);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: widget.backgroundColor ?? scheme.surface,
      elevation: widget.elevation,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeader) ...[
              Text(
                l10n.adminText('item_group.parent_move_title'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.adminText('item_group.parent_move_description'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
            ],
            AdminPickerField(
              label: l10n.adminText('item_group.movable_group'),
              value: groupName,
              placeholder: l10n.adminText('item_group.group_select'),
              enabled: !submitting && movable.isNotEmpty,
              onTap: () => _openGroupPicker(movable),
            ),
            const SizedBox(height: 12),
            AdminPickerField(
              label: l10n.adminText('item_group.new_parent'),
              value: parentName,
              placeholder: l10n.adminText('item_group.parent_placeholder'),
              enabled: !submitting && parents.isNotEmpty,
              onTap: () => _openParentPicker(parents),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: canSubmit ? _move : null,
              child: Text(
                submitting
                    ? l10n.adminText('item_group.moving')
                    : l10n.adminText('item_group.move_action'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
