import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/display/order_image_provider.dart';
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
    final image = OrderImageProvider(trimmedUrl, thumbnail: true);
    return SizedBox.square(
      dimension: dimension,
      child: ProfileAvatarPreview(
        displayName: displayName,
        avatarImage: OrderImageProvider(trimmedUrl),
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

/// Chap yon cover-rasm eni (px). Qatorlar shu konstantaga tayanib
/// matn uchun chap padding ajratadi.
const double kAdminOrderCoverWidth = 68.0;

/// Kartochka chap yonini to'liq egallaydigan cover-rasm
/// (chekka-chekka, to'liq balandlik).
///
/// Ota [Stack] da [Positioned(left: 0, top: 0, bottom: 0)] bilan
/// ishlatiladi — shuning uchun qator balandligiga ta'sir qilmaydi,
/// balandlikni faqat matn belgilaydi. Burchak yumaloqligini ota karta
/// o'zi kesadi ([Clip.antiAlias]).
class AdminOrderCoverThumb extends StatelessWidget {
  const AdminOrderCoverThumb({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.heroTag,
    this.width = kAdminOrderCoverWidth,
  });

  final String imageUrl;
  final String displayName;
  final String heroTag;
  final double width;
  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty) {
      return AdminOrderCoverImage(
        displayName: displayName,
        heroTag: heroTag,
        width: width,
      );
    }
    final image = OrderImageProvider(trimmedUrl, thumbnail: true);
    return AdminOrderCoverImage(
      image: image,
      previewImage: OrderImageProvider(trimmedUrl),
      displayName: displayName,
      heroTag: heroTag,
      width: width,
    );
  }
}

/// Cover qutining o'zi: [ImageProvider] dan chizadi.
///
/// [image] `null` bo'lsa fallback polosa chiqadi. Bytes orqali kelgan
/// rasmlar ([MemoryImage]) ham shu widget orqali bir xil ko'rinishda
/// chiziladi.
class AdminOrderCoverImage extends StatelessWidget {
  const AdminOrderCoverImage({
    super.key,
    this.image,
    this.previewImage,
    required this.displayName,
    required this.heroTag,
    this.width = kAdminOrderCoverWidth,
  });

  final ImageProvider? image;
  final ImageProvider? previewImage;
  final String displayName;
  final String heroTag;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      color: scheme.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.calculate_outlined,
        size: 22,
        color: scheme.onSecondaryContainer,
      ),
    );
    final provider = image;
    if (provider == null) {
      return SizedBox(width: width, child: fallback);
    }
    return SizedBox(
      width: width,
      child: ProfileAvatarPreview(
        displayName: displayName,
        avatarImage: previewImage ?? provider,
        semanticLabel: context.l10n.productionText(
          'worker.action.view_order_image',
        ),
        heroTag: heroTag,
        previewOnLongPress: true,
        previewFit: BoxFit.contain,
        previewMaxScale: 8,
        // Aniq o'lcham beriladi: rasm ajratilgan joyni to'liq to'ldirib
        // (cover/zoom-crop) chiqadi, chetda bo'shliq qolmaydi.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boxWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : width;
            final boxHeight =
                constraints.maxHeight.isFinite ? constraints.maxHeight : width;
            return ImageFade(
              image: provider,
              width: boxWidth,
              height: boxHeight,
              fit: BoxFit.cover,
              placeholder: fallback,
              errorBuilder: (_, __) => fallback,
            );
          },
        ),
      ),
    );
  }
}
