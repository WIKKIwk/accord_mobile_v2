import 'package:flutter/material.dart';

import 'm3_segmented_list.dart';

class AppSummarySegmentCard extends StatelessWidget {
  const AppSummarySegmentCard({
    super.key,
    required this.slot,
    required this.cornerRadius,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final double cornerRadius;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(slot, cornerRadius);
    final bg = switch (theme.brightness) {
      Brightness.dark => scheme.surfaceContainerLow,
      Brightness.light => scheme.surfaceContainerHighest,
    };
    final foreground = scheme.onSurface;
    final accent = scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 22, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
