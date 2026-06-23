part of 'admin_production_map_test_screen.dart';

class _BranchAddButton extends StatelessWidget {
  const _BranchAddButton({
    required this.branch,
    required this.onConnectionDragStart,
    required this.onConnectionDragUpdate,
    required this.onConnectionDragEnd,
    required this.onConnectionDragCancel,
  });

  static const width = 34.0;
  static const height = 34.0;

  final String branch;
  final ValueChanged<Offset> onConnectionDragStart;
  final ValueChanged<Offset> onConnectionDragUpdate;
  final VoidCallback onConnectionDragEnd;
  final VoidCallback onConnectionDragCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branchKey = branch.trim().toLowerCase();
    final color = switch (branchKey) {
      'true' => scheme.primaryContainer,
      'false' => scheme.errorContainer,
      _ => scheme.secondaryContainer,
    };
    final foreground = switch (branchKey) {
      'true' => scheme.onPrimaryContainer,
      'false' => scheme.onErrorContainer,
      _ => scheme.onSecondaryContainer,
    };
    return Tooltip(
      message:
          '${productionMapBranchDisplayLabel(branch)} yo‘liga qo‘l tortish',
      child: SizedBox(
        key: ValueKey('production-map-branch-add-$branch'),
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) =>
              onConnectionDragStart(details.globalPosition),
          onPanUpdate: (details) =>
              onConnectionDragUpdate(details.globalPosition),
          onPanEnd: (_) => onConnectionDragEnd(),
          onPanCancel: onConnectionDragCancel,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(99),
            elevation: 2,
            shadowColor: scheme.shadow.withValues(alpha: 0.18),
            clipBehavior: Clip.antiAlias,
            child: Icon(Icons.add_link_rounded, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _EdgeDeleteButton extends StatelessWidget {
  const _EdgeDeleteButton({required this.edge, required this.onTap});

  final ProductionMapEdge edge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branchKey = edge.branch.trim().toLowerCase();
    final color = switch (branchKey) {
      'true' => scheme.primary,
      'false' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Tooltip(
      message: 'Yo‘lni uzish',
      child: Material(
        key: ValueKey(
          'production-map-edge-delete-${edge.from}-${edge.to}-${edge.branch}',
        ),
        color: scheme.surface,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.16),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 26,
            child: Icon(Icons.close_rounded, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}
