import 'package:flutter/material.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/lists/m3_segmented_list.dart';
import 'admin_summary_card.dart';

class AdminCatalogListRow extends StatelessWidget {
  const AdminCatalogListRow({
    super.key,
    required this.slot,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.onLongPress,
    this.value = '',
    this.subtitleMaxLines = 1,
  });

  final M3SegmentVerticalSlot slot;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String value;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      onLongPress: onLongPress,
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: subtitleMaxLines == 1 ? 61 : null,
      minHeight: 61,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
      value: value,
      valueStyle: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      showChevron: false,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: scheme.onSecondaryContainer),
        ),
      ),
      title: title,
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: subtitleMaxLines,
      titleStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      subtitleStyle: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
        height: 1.05,
      ),
      elevation:
          ThemeController.instance.variant == AppThemeVariant.white ? 1 : 0,
    );
  }
}
