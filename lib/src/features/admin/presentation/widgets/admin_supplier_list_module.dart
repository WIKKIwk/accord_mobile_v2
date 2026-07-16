import '../../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../shared/models/app_models.dart';
import 'admin_summary_card.dart';
import 'package:flutter/material.dart';

class AdminSupplierListModule extends StatelessWidget {
  const AdminSupplierListModule({
    super.key,
    required this.items,
    required this.onTapUser,
  });

  final List<AdminUserListEntry> items;
  final ValueChanged<AdminUserListEntry> onTapUser;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          'Userlar topilmadi',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return M3SegmentSpacedColumn(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        for (int index = 0; index < items.length; index++)
          AdminSupplierListRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              items.length,
            ),
            item: items[index],
            onTap: () => onTapUser(items[index]),
          ),
      ],
    );
  }
}

class AdminSupplierListRow extends StatelessWidget {
  const AdminSupplierListRow({
    super.key,
    required this.slot,
    required this.item,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminUserListEntry item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final phone = item.phone.trim();
    final subtitleLine = <String>[
      item.roleLabel,
      if (item.blocked) 'Blocked',
      if (phone.isNotEmpty) phone,
    ].join(' • ');

    return AdminSummaryCard(
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
          child: Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: item.name,
      subtitle: subtitleLine,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
      elevation:
          ThemeController.instance.variant == AppThemeVariant.white ? 1 : 0,
    );
  }
}
