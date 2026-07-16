import 'package:flutter/material.dart';

import '../../../../core/widgets/display/image_fade.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.radius = 22,
  });

  final String name;
  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: avatarUrl.trim().isEmpty
            ? _fallback(scheme, initial)
            : ImageFade(
                image: NetworkImage(avatarUrl),
                fit: BoxFit.cover,
                cacheWidth: (radius * 4).round(),
                cacheHeight: (radius * 4).round(),
                placeholder: _fallback(scheme, initial),
                errorBuilder: (context, _) => _fallback(scheme, initial),
              ),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme, String initial) {
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
            fontSize: radius * 0.8,
          ),
        ),
      ),
    );
  }
}
