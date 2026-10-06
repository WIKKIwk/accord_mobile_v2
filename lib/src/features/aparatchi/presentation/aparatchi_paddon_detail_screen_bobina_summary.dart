part of 'aparatchi_paddon_detail_screen.dart';

int _paddonBobinaWeightUnits(double? kg) {
  // Match the six decimal places used to store kilograms in PostgreSQL.
  final units =
      kg != null && kg.isFinite && kg > 0 ? (kg * 1000000).round() : 0;
  return units > 0 ? units : 0;
}

class _PaddonBobinaSummary extends StatelessWidget {
  const _PaddonBobinaSummary({
    required this.items,
    required this.selectedWeightUnits,
    required this.onWeightSelected,
  });

  final List<AdminProgressBatch> items;
  final int? selectedWeightUnits;
  final ValueChanged<int> onWeightSelected;

  @override
  Widget build(BuildContext context) {
    // Count physical WIPs, independent of metrage or contained kadr count.
    final counts = <int, int>{};
    var unknownCount = 0;
    for (final item in items) {
      final units = _paddonBobinaWeightUnits(item.bobinaKg);
      if (units <= 0) {
        unknownCount++;
      } else {
        counts.update(units, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final weights = counts.keys.toList()..sort();
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('paddon-bobina-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.view_carousel_outlined,
                size: 18, color: scheme.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.productionText('worker.paddon.bobina_summary'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final minWidth = MediaQuery.textScalerOf(context).scale(140);
            final width = constraints.maxWidth >= minWidth * 2 + 8
                ? (constraints.maxWidth - 8) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final weight in weights)
                  SizedBox(
                    width: width,
                    child: _PaddonBobinaGroup(
                      key: ValueKey('paddon-bobina-group-$weight'),
                      label: formatQuantityWithUnit(
                        weight / 1000000,
                        'kg',
                        decimalPlaces: 6,
                        trimTrailingZeros: true,
                      ),
                      count: counts[weight]!,
                      selected: selectedWeightUnits == weight,
                      onTap: () => onWeightSelected(weight),
                    ),
                  ),
                if (unknownCount > 0)
                  SizedBox(
                    width: width,
                    child: _PaddonBobinaGroup(
                      key: const ValueKey('paddon-bobina-group-unknown'),
                      label: context.l10n
                          .productionText('worker.paddon.bobina_unknown'),
                      count: unknownCount,
                      selected: selectedWeightUnits == 0,
                      onTap: () => onWeightSelected(0),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PaddonBobinaGroup extends StatelessWidget {
  const _PaddonBobinaGroup({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final countText = context.l10n.productionCount(count);
    final foreground = selected ? scheme.onPrimary : scheme.onPrimaryContainer;
    return Semantics(
      label: '$label, $countText',
      button: true,
      selected: selected,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? scheme.primary
            : scheme.onPrimaryContainer.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? scheme.primary
                : scheme.onPrimaryContainer.withValues(alpha: 0.08),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: selected ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    countText,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
