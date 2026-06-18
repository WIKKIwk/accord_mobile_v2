import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../shared/models/app_models.dart';
import 'admin_item_group_parent_move_panel.dart';
import 'package:flutter/material.dart';

class AdminItemGroupParentMoveTab extends StatelessWidget {
  const AdminItemGroupParentMoveTab({
    super.key,
    required this.itemGroupsFuture,
    required this.onMoved,
  });

  final Future<List<String>> itemGroupsFuture;
  final ValueChanged<AdminItemGroup> onMoved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 116;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: FutureBuilder<List<String>>(
        future: itemGroupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError || (snapshot.data ?? const []).isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Item grouplar yuklanmadi',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final groups = snapshot.data ?? const <String>[];
          return ListView(
            padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
            children: [
              AdminItemGroupParentMovePanel(groups: groups, onMoved: onMoved),
            ],
          );
        },
      ),
    );
  }
}
