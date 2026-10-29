import 'package:flutter/material.dart';

import '../localization/urdu_aware_text.dart';
import 'lists/m3_segmented_list.dart';

/// Shared presentation for production and mold pallets. Lifecycle actions stay
/// with the caller because the two pallet types have different storage rules.
class PaddonPanel extends StatelessWidget {
  const PaddonPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card.filled(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}

class PaddonMetric extends StatelessWidget {
  const PaddonMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: UrduAwareText(
          '$label: $value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class PaddonListCard extends StatelessWidget {
  const PaddonListCard({
    super.key,
    required this.slot,
    required this.code,
    required this.countLabel,
    required this.onTap,
    this.subtitle = '',
    this.icon = Icons.inventory_2_rounded,
    this.onLongPress,
    this.trailing,
  });

  final M3SegmentVerticalSlot slot;
  final String code;
  final String countLabel;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 10, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 45),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 25),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      if (countLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(countLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ]),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class PaddonSectionHeader extends StatelessWidget {
  const PaddonSectionHeader({super.key, required this.title, this.count});

  final String title;
  final String? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (count != null)
            Text(count!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800)),
        ]),
      );
}

class PaddonEmptyState extends StatelessWidget {
  const PaddonEmptyState({
    super.key,
    required this.title,
    this.message = '',
    this.icon = Icons.inventory_2_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => M3SegmentFilledSurface(
        slot: M3SegmentVerticalSlot.top,
        cornerRadius: M3SegmentedListGeometry.cornerLarge,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(icon,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ]),
        ),
      );
}
