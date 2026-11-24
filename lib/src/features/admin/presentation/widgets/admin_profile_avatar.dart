import 'package:flutter/material.dart';

import '../../../../core/widgets/display/image_fade.dart';
import '../../../shared/presentation/widgets/profile_avatar_preview.dart';
import '../../../shared/presentation/widgets/refreshing_avatar.dart';

class AdminProfileAvatar extends StatelessWidget {
  const AdminProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.fallbackText,
    this.size = 92,
    this.refreshUrl,
    this.previewDisplayName = '',
  });

  final String avatarUrl;
  final String fallbackText;
  final double size;
  final String previewDisplayName;

  final Future<String> Function()? refreshUrl;

  @override
  Widget build(BuildContext context) => RefreshingAvatar(
        url: avatarUrl,
        refreshUrl: refreshUrl,
        builder: (image, onError) => _avatar(context, image, onError),
      );

  Widget _avatar(BuildContext context, ImageProvider<Object>? image,
      VoidCallback onError) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = size >= 60 ? 5.0 : 2.0;
    final innerSize = size - padding * 2;
    final fallback = Center(
      child: Text(
        fallbackText,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.26,
        ),
      ),
    );

    final avatar = Container(
      height: size,
      width: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surface,
      ),
      child: ClipOval(
        child: DecoratedBox(
          decoration: BoxDecoration(color: scheme.primaryContainer),
          child: image != null
              ? ImageFade(
                  image: image,
                  height: innerSize,
                  width: innerSize,
                  fit: BoxFit.cover,
                  placeholder: fallback,
                  errorBuilder: (context, _) {
                    onError();
                    return fallback;
                  },
                )
              : fallback,
        ),
      ),
    );
    return ProfileAvatarPreview(
      displayName: previewDisplayName.trim().isEmpty
          ? fallbackText
          : previewDisplayName.trim(),
      avatarImage: image,
      child: avatar,
    );
  }
}
