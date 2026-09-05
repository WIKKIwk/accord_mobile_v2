import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/native_back_button.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../shared/models/app_models.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaArchiveScreen extends StatelessWidget {
  const WerkaArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    useNativeNavigationTitle(context, context.l10n.archiveTitle);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: context.l10n.archiveTitle,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const WerkaDock(activeTab: WerkaDockTab.archive),
      contentPadding: EdgeInsets.zero,
      child: ListView(
        padding: EdgeInsets.fromLTRB(0, 4, 0, bottomPadding),
        children: [
          M3SegmentSpacedColumn(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              _WerkaArchiveSegmentTile(
                slot: M3SegmentVerticalSlot.top,
                cornerRadius: M3SegmentedListGeometry.cornerLarge,
                title: context.l10n.archiveReceivedTitle,
                icon: Icons.inventory_2_outlined,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.werkaArchivePeriods,
                  arguments: WerkaArchiveKind.received,
                ),
              ),
              _WerkaArchiveSegmentTile(
                slot: M3SegmentVerticalSlot.middle,
                cornerRadius: M3SegmentedListGeometry.cornerMiddle,
                title: context.l10n.archiveSentTitle,
                icon: Icons.outbox_outlined,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(AppRoutes.werkaArchiveSentHub),
              ),
              _WerkaArchiveSegmentTile(
                slot: M3SegmentVerticalSlot.bottom,
                cornerRadius: M3SegmentedListGeometry.cornerLarge,
                title: context.l10n.archiveReturnedTitle,
                icon: Icons.assignment_return_outlined,
                onTap: () => Navigator.of(context).pushNamed(
                  AppRoutes.werkaArchivePeriods,
                  arguments: WerkaArchiveKind.returned,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WerkaArchiveSegmentTile extends StatelessWidget {
  const _WerkaArchiveSegmentTile({
    required this.slot,
    required this.cornerRadius,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final double cornerRadius;
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: cornerRadius,
      backgroundColor: scheme.surfaceContainerLowest,
      title: title,
      value: '',
      leading: Icon(icon, size: 23, color: scheme.onSurfaceVariant),
      onTap: onTap,
      elevation: 4,
    );
  }
}
