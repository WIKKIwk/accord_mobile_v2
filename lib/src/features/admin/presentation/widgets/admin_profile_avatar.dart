import 'package:flutter/material.dart';

class AdminProfileAvatar extends StatelessWidget {
  const AdminProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackText,
    this.size = 92,
  });

  final String avatarUrl;
  final String fallbackText;
  final double size;

  bool get _canLoadAvatar {
    final value = avatarUrl.trim().toLowerCase();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final innerSize = size - 10;
    final fallback = Center(
      child: Text(
        fallbackText,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(color: scheme.primaryContainer),
          child: _canLoadAvatar
              ? Image.network(
                  avatarUrl.trim(),
                  height: innerSize,
                  width: innerSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}
