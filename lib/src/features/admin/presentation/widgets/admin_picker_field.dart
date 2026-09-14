import 'package:flutter/material.dart';

import '../../../../core/widgets/forms/forms.dart';

class AdminPickerField extends StatelessWidget {
  const AdminPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String placeholder;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 6),
        Material(
          color: scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: value == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet ochadigan order tanlash field'i.
/// Material biriktirishdagi order field bilan bir xil ko'rinish
/// (InputDecorator + dropdown icon); yangi style yozilmasdan reuse qilinadi.
class AdminOrderPickerField extends StatelessWidget {
  const AdminOrderPickerField({
    super.key,
    required this.labelText,
    required this.valueText,
    required this.emptyText,
    required this.selectText,
    required this.hasOptions,
    required this.onPick,
    this.disabled = false,
  });

  final String labelText;
  final String valueText;
  final String emptyText;
  final String selectText;
  final bool hasOptions;
  final bool disabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final empty = valueText.trim().isEmpty;
    return InkWell(
      onTap: disabled || !hasOptions ? null : onPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appSurfaceInputDecoration(
          context,
          labelText: labelText,
        ).copyWith(
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        isEmpty: empty,
        child: Text(
          empty ? (hasOptions ? selectText : emptyText) : valueText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
