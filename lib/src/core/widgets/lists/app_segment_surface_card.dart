import 'package:flutter/material.dart';

import 'm3_segmented_list.dart';

class AppSegmentSurfaceCard extends StatelessWidget {
  const AppSegmentSurfaceCard({
    super.key,
    required this.child,
    this.slot,
    this.padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
    this.onTap,
  });

  final Widget child;
  final M3SegmentVerticalSlot? slot;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedSlot = slot ?? M3SegmentVerticalSlot.top;
    final radius = M3SegmentedListGeometry.borderRadius(
      resolvedSlot,
      slot == null
          ? M3SegmentedListGeometry.cornerLarge
          : M3SegmentedListGeometry.cornerRadiusForSlot(resolvedSlot),
    );

    final paddedChild = Padding(padding: padding, child: child);

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? paddedChild
          : InkWell(onTap: onTap, borderRadius: radius, child: paddedChild),
    );
  }
}
