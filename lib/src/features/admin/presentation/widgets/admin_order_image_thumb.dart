import 'package:flutter/material.dart';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/display/order_image_provider.dart';
import '../../../../core/widgets/display/image_fade.dart';
import '../../../shared/presentation/widgets/profile_avatar_preview.dart';

/// Tezkor buyurtmalar ro'yxatidagi chap taraftagi 30x30 rasm ko'rinishi.
///
/// [imageUrl] bo'sh bo'lsa, hisob-kitob ikonkasi (fallback) chiqadi.
/// Ish xaritasi (Buyurtmalar / Ketma-ketlik) da ham aynan shu widget
/// reuse qilinadi — ko'rinish bitta joydan boshqariladi.
class AdminOrderImageThumb extends StatefulWidget {
  const AdminOrderImageThumb({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.heroTag,
    this.dimension = 30,
    this.previewOnLongPress = true,
  });

  final String imageUrl;
  final String displayName;
  final String heroTag;
  final double dimension;
  final bool previewOnLongPress;

  @override
  State<AdminOrderImageThumb> createState() => _AdminOrderImageThumbState();
}

class _AdminOrderImageThumbState extends State<AdminOrderImageThumb> {
  final _providers = _OrderThumbProviders();

  @override
  Widget build(BuildContext context) {
    _providers.update(widget.imageUrl);
    final dimension = widget.dimension;
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
    final image = _providers.thumbnail;
    if (image == null) {
      return SizedBox.square(dimension: dimension, child: fallback);
    }
    return SizedBox.square(
      dimension: dimension,
      child: ProfileAvatarPreview(
        displayName: widget.displayName,
        avatarImage: _providers.full,
        semanticLabel: context.l10n.productionText(
          'worker.action.view_order_image',
        ),
        heroTag: widget.heroTag,
        previewOnLongPress: widget.previewOnLongPress,
        previewFit: BoxFit.contain,
        previewMaxScale: 64,
        previewFullScreen: true,
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
class AdminOrderCoverThumb extends StatefulWidget {
  const AdminOrderCoverThumb({
    super.key,
    required this.imageUrl,
    required this.displayName,
    required this.heroTag,
    this.width = kAdminOrderCoverWidth,
    this.providerCache,
  });

  final String imageUrl;
  final String displayName;
  final String heroTag;
  final double width;
  final OrderImageThumbCache? providerCache;
  @override
  State<AdminOrderCoverThumb> createState() => _AdminOrderCoverThumbState();
}

class _AdminOrderCoverThumbState extends State<AdminOrderCoverThumb> {
  final _providers = _OrderThumbProviders();

  @override
  Widget build(BuildContext context) {
    final providers = widget.providerCache?._forUrl(widget.imageUrl) ??
        (_providers..update(widget.imageUrl));
    return AdminOrderCoverImage(
      image: providers.thumbnail,
      previewImage: providers.full,
      displayName: widget.displayName,
      heroTag: widget.heroTag,
      width: widget.width,
    );
  }
}

/// Page-owned, bounded provider metadata for rows recycled by a lazy list.
/// Image bytes and decoded pixels retain their existing shared cache budgets.
class OrderImageThumbCache {
  OrderImageThumbCache({this.maxEntries = 128}) : assert(maxEntries > 0);

  final int maxEntries;
  String? _scope;
  final _entries = <String, _OrderThumbProviders>{};

  void clear() {
    _entries.clear();
    _scope = null;
  }

  _OrderThumbProviders _forUrl(String imageUrl) {
    final api = MobileApi.instance;
    final scope = api.orderImageCacheScope;
    if (_scope != scope) {
      clear();
      _scope = scope;
    }
    final trimmed = imageUrl.trim();
    final url =
        trimmed.isEmpty ? '' : api.orderImageRequestUri(trimmed).toString();
    final providers = _entries.remove(url) ?? _OrderThumbProviders();
    providers.update(url);
    if (url.isNotEmpty) {
      _entries[url] = providers;
      while (_entries.length > maxEntries) {
        _entries.remove(_entries.keys.first);
      }
    }
    return providers;
  }
}

/// A mounted thumbnail keeps its image stream when its card changes size.
/// Re-entry, source changes and account changes still create fresh providers;
/// the provider's normal freshness epoch and shared cache TTL remain intact.
class _OrderThumbProviders {
  String? _url;
  String? _scope;
  OrderImageProvider? thumbnail;
  OrderImageProvider? full;

  void update(String imageUrl) {
    final trimmed = imageUrl.trim();
    final api = MobileApi.instance;
    final url =
        trimmed.isEmpty ? '' : api.orderImageRequestUri(trimmed).toString();
    final scope = api.orderImageCacheScope;
    if (_url == url && _scope == scope) return;
    _url = url;
    _scope = scope;
    thumbnail = url.isEmpty ? null : OrderImageProvider(url, thumbnail: true);
    full = url.isEmpty ? null : OrderImageProvider(url);
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
        previewMaxScale: 64,
        previewFullScreen: true,
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
