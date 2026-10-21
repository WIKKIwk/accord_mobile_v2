import '../../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../shared/models/app_models.dart';
import 'admin_catalog_list_row.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/urdu_aware_text.dart';

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
        child: UrduAwareText(
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
    final phone = item.phone.trim();
    final subtitleLine = <String>[
      item.roleLabel,
      if (item.blocked) 'Blocked',
      if (phone.isNotEmpty) phone,
    ].join(' • ');

    return AdminCatalogListRow(
      slot: slot,
      onTap: onTap,
      icon: Icons.person_outline_rounded,
      title: item.name,
      subtitle: subtitleLine,
    );
  }
}
