import 'package:flutter/material.dart';

class AdminFilterChipOption<T> {
  const AdminFilterChipOption({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

class AdminExpandableFilterChip<T> extends StatelessWidget {
  const AdminExpandableFilterChip({
    super.key,
    required this.label,
    required this.emptyLabel,
    required this.icon,
    required this.selectedValue,
    required this.options,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 8),
    this.chipKey,
    this.optionKeyPrefix = 'admin-filter-option',
  });

  final String label;
  final String emptyLabel;
  final IconData icon;
  final T? selectedValue;
  final List<AdminFilterChipOption<T>> options;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<T> onSelect;
  final EdgeInsetsGeometry padding;
  final Key? chipKey;
  final String optionKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedOption = _selectedOption();
    final hasSelection = selectedValue != null;
    final selectedLabel = selectedOption?.label ?? emptyLabel;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              key: chipKey,
              selected: hasSelection,
              showCheckmark: false,
              label: Text('$label: $selectedLabel'),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                color: hasSelection
                    ? scheme.onSecondaryContainer
                    : scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              avatar: Icon(
                icon,
                size: 18,
                color: hasSelection
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              onSelected: (_) => onToggle(),
              selectedColor: scheme.secondaryContainer,
              backgroundColor: scheme.surfaceContainerLowest,
              elevation: 4,
              pressElevation: 4,
              shadowColor: scheme.shadow.withValues(alpha: 0.24),
              side: BorderSide(
                color: hasSelection
                    ? Colors.transparent
                    : scheme.outline.withValues(alpha: 0.72),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              deleteIcon: AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: hasSelection
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              onDeleted: onToggle,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in options)
                          _AdminExpandableFilterOptionChip<T>(
                            key: option.key ??
                                ValueKey('$optionKeyPrefix-${option.label}'),
                            label: option.label,
                            selected: option.value == selectedValue,
                            onSelect: () => onSelect(option.value),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  AdminFilterChipOption<T>? _selectedOption() {
    for (final option in options) {
      if (option.value == selectedValue) {
        return option;
      }
    }
    return null;
  }
}

class _AdminExpandableFilterOptionChip<T> extends StatelessWidget {
  const _AdminExpandableFilterOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FilterChip(
      selected: selected,
      showCheckmark: selected,
      checkmarkColor: scheme.onSecondaryContainer,
      label: Text(label),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: selected ? scheme.onSecondaryContainer : scheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      onSelected: (_) => onSelect(),
      selectedColor: scheme.secondaryContainer,
      backgroundColor: scheme.surfaceContainerLowest,
      elevation: 4,
      pressElevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : scheme.outline.withValues(alpha: 0.72),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: 0, vertical: -1),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }
}
