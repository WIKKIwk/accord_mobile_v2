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
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Item group tree yuklanmadi',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final bottomPadding = MediaQuery.paddingOf(context).bottom + 116;
        final scheme = Theme.of(context).colorScheme;
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Material(
                  color: scheme.surface,
                  elevation: 2,
                  shadowColor: scheme.shadow.withValues(alpha: 0.16),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Item Group tree',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton.filledTonal(
                              onPressed: onRefresh,
                              icon: const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Parent va child guruhlarni ERPNext tree tartibida ko‘rsatadi.',
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
