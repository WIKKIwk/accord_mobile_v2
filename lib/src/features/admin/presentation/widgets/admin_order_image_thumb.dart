import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/session/state/app_session.dart';
import '../../../../core/widgets/display/image_fade.dart';
import '../../../shared/presentation/widgets/profile_avatar_preview.dart';

/// Tezkor buyurtmalar ro'yxatidagi chap taraftagi 30x30 rasm ko'rinishi.
///
/// [imageUrl] bo'sh bo'lsa, hisob-kitob ikonkasi (fallback) chiqadi.
/// Ish xaritasi (Buyurtmalar / Ketma-ketlik) da ham aynan shu widget
/// reuse qilinadi — ko'rinish bitta joydan boshqariladi.
class AdminOrderImageThumb extends StatelessWidget {
  const AdminOrderImageThumb({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.heroTag,
    this.dimension = 30,
  });

  final String imageUrl;
  final String displayName;
  final String heroTag;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.calculate_outlined,
        size: 16,
        color: scheme.onSecondaryContainer,
      ),
    );
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return SizedBox.square(dimension: dimension, child: fallback);
    }
    final token = AppSession.instance.token?.trim() ?? '';
    final image = NetworkImage(
      MobileApi.instance.calculateOrderImageUrl(trimmedUrl),
      headers: token.isEmpty ? null : {'Authorization': 'Bearer $token'},
    );
    return SizedBox.square(
      dimension: dimension,
      child: ProfileAvatarPreview(
        displayName: displayName,
        avatarImage: image,
        semanticLabel: context.l10n.productionText(
          'worker.action.view_order_image',
        ),
        heroTag: heroTag,
        previewOnLongPress: true,
        previewFit: BoxFit.contain,
        previewMaxScale: 8,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ImageFade(
            image: image,
            width: dimension,
            height: dimension,
            fit: BoxFit.cover,
            placeholder: fallback,
            errorBuilder: (_, __) => fallback,
          ),
        ),
      ),
    );
  }
}
