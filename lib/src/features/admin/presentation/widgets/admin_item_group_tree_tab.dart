import '../../../../core/theme/app_theme.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../../core/widgets/shell/app_shell.dart' show AppRefreshIndicator;
import '../../models/admin_item_group_tree_entry.dart';
import 'admin_item_group_tree_panel.dart';
import 'package:flutter/material.dart';

class AdminItemGroupTreeTab extends StatelessWidget {
  const AdminItemGroupTreeTab({
    super.key,
    required this.itemGroupTreeFuture,
    required this.onRefresh,
    required this.onShowItems,
    this.onNavigateToItemsTab,
  });

  final Future<List<AdminItemGroupTreeEntry>> itemGroupTreeFuture;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onShowItems;
  final VoidCallback? onNavigateToItemsTab;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminItemGroupTreeEntry>>(
      future: itemGroupTreeFuture,
      builder: (context, snapshot) {
        final l10n = context.l10n;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.adminText('item_group.tree_load_failed'),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 116;
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          color: AppTheme.shellStart(context),
          child: AppRefreshIndicator(
            onRefresh: onRefresh,
            allowRefreshOnShortContent: true,
            child: ListView(
              padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
              physics: const TopRefreshScrollPhysics(),
              children: [
                Material(
                  color: scheme.surfaceContainerLowest,
                  elevation: 4,
                  shadowColor: scheme.shadow.withValues(alpha: 0.24),
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.adminText('item_group.tree_title'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.adminText('item_group.tree_description'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        AdminItemGroupTreePanel(
                          entries: snapshot.data ?? const [],
                          onShowItems: (group) {
                            onShowItems(group);
                            onNavigateToItemsTab?.call();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
