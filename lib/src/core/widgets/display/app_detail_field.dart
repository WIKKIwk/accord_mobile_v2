import 'package:flutter/material.dart';

class AppDetailField extends StatelessWidget {
  const AppDetailField({
    super.key,
    this.value,
    this.child,
    this.borderRadius = 14,
    this.emptyText = 'Kiritilmagan',
  });

  final String? value;
  final Widget? child;
  final double borderRadius;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final resolved = (value ?? '').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: child ??
          Text(
            resolved.isEmpty ? emptyText : resolved,
            style: Theme.of(context).textTheme.titleMedium,
          ),
    );
  }
}
