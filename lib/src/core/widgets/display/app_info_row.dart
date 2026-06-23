import 'package:flutter/material.dart';

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.selectable = false,
    this.trailing,
    this.onTap,
    this.labelWidth = 104,
    this.alignValueToTrailing = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool selectable;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double labelWidth;
  final bool alignValueToTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayValue = value.trim().isEmpty ? '—' : value.trim();
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final valueTextAlign = alignValueToTrailing && trailing != null
        ? TextAlign.end
        : TextAlign.start;
    final child = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: onTap == null ? 0 : 10,
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: selectable
                ? SelectableText(
                    displayValue,
                    textAlign: valueTextAlign,
                    style: valueStyle,
                  )
                : Text(
                    displayValue,
                    textAlign: valueTextAlign,
                    style: valueStyle,
                  ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            IconTheme.merge(
              data: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return child;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      ),
    );
  }
}
