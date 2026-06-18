import '../../../../core/api/mobile_api.dart';
import '../../../shared/models/app_models.dart';
import '../../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'admin_top_notice.dart';
import 'package:flutter/material.dart';

class AdminItemGroupParentMovePanel extends StatefulWidget {
  const AdminItemGroupParentMovePanel({
    super.key,
    required this.groups,
    required this.onMoved,
  });

  final List<String> groups;
  final ValueChanged<AdminItemGroup> onMoved;

  @override
  State<AdminItemGroupParentMovePanel> createState() =>
      _AdminItemGroupParentMovePanelState();
}

class _AdminItemGroupParentMovePanelState
    extends State<AdminItemGroupParentMovePanel> {
  String? groupName;
  String? parentName;
  bool submitting = false;

  List<String> get movableGroups =>
      widget.groups
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
      parentName = parents.contains('All Item Groups')
          ? 'All Item Groups'
          : null;
    }
  }

  Future<void> _openGroupPicker(List<String> groups) async {
    if (submitting || groups.isEmpty) {
      return;
    }
    final picked = await _showGroupPicker(
      title: 'Ko‘chiriladigan group',
      hintText: 'Group qidiring',
      groups: groups,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      groupName = picked;
      if (parentName == picked) {
        parentName = parentGroups.contains('All Item Groups')
            ? 'All Item Groups'
            : null;
      }
    });
  }

  Future<void> _openParentPicker(List<String> groups) async {
    if (submitting || groups.isEmpty) {
      return;
    }
    final picked = await _showGroupPicker(
      title: 'Yangi parent',
      hintText: 'Parent qidiring',
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
      showAdminTopNotice(context, '${moved.itemGroupName} parenti yangilandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Parent yangilanmadi: $error')));
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movable = movableGroups;
    final parents = parentGroups;
    final canSubmit =
        !submitting &&
        (groupName?.isNotEmpty ?? false) &&
        (parentName?.isNotEmpty ?? false);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Parentni ko‘chirish',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Mavjud groupni boshqa parent ostiga o‘tkazish uchun ishlatiladi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            _MovePickerField(
              label: 'Ko‘chiriladigan group',
              value: groupName,
              placeholder: 'Group tanlang',
              enabled: !submitting && movable.isNotEmpty,
              onTap: () => _openGroupPicker(movable),
            ),
            const SizedBox(height: 12),
            _MovePickerField(
              label: 'Yangi parent',
              value: parentName,
              placeholder: 'Parent tanlang',
              enabled: !submitting && parents.isNotEmpty,
              onTap: () => _openParentPicker(parents),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: canSubmit ? _move : null,
              child: Text(
                submitting ? 'Ko‘chirilmoqda...' : 'Parentni yangilash',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovePickerField extends StatelessWidget {
  const _MovePickerField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: value == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
