import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/display/image_fade.dart';

const String profileAvatarPreviewHeroTag = 'profile-avatar-preview';

class ProfileAvatarPreview extends StatelessWidget {
  const ProfileAvatarPreview({
    super.key,
    required this.displayName,
    required this.child,
    this.avatarImage,
    this.semanticLabel = 'Profil rasmini kattalashtirish',
    this.heroTag = profileAvatarPreviewHeroTag,
    this.previewOnLongPress = false,
    this.previewFit = BoxFit.cover,
    this.previewMaxScale = 3,
  });

  final String displayName;
  final Widget child;
  final ImageProvider? avatarImage;
  final String semanticLabel;
  final Object heroTag;
  final bool previewOnLongPress;
  final BoxFit previewFit;
  final double previewMaxScale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: previewOnLongPress
            ? null
            : () => showProfileAvatarPreview(
                  context,
                  displayName: displayName,
                  avatarImage: avatarImage,
                  heroTag: heroTag,
                  previewFit: previewFit,
                  previewMaxScale: previewMaxScale,
                ),
        onLongPress: previewOnLongPress
            ? () => showProfileAvatarPreview(
                  context,
                  displayName: displayName,
                  avatarImage: avatarImage,
                  heroTag: heroTag,
                  previewFit: previewFit,
                  previewMaxScale: previewMaxScale,
                )
            : null,
        child: Hero(
          tag: heroTag,
          createRectTween: (begin, end) =>
              MaterialRectCenterArcTween(begin: begin, end: end),
          flightShuttleBuilder: profileAvatarFlightShuttleBuilder,
          child: child,
        ),
      ),
    );
  }
}

Future<void> showProfileAvatarPreview(
  BuildContext context, {
  required String displayName,
  required ImageProvider? avatarImage,
  Object heroTag = profileAvatarPreviewHeroTag,
  BoxFit previewFit = BoxFit.cover,
  double previewMaxScale = 3,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ProfileAvatarPreviewOverlay(
          displayName: displayName,
          avatarImage: avatarImage,
          heroTag: heroTag,
          previewFit: previewFit,
          previewMaxScale: previewMaxScale,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: fade, child: child);
      },
    ),
  );
}

Widget profileAvatarFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final radiusTween = flightDirection == HeroFlightDirection.push
      ? Tween<double>(begin: 48, end: 28)
      : Tween<double>(begin: 28, end: 48);
  final child = flightDirection == HeroFlightDirection.push
      ? toHeroContext.widget
      : fromHeroContext.widget;
  return AnimatedBuilder(
    animation: curved,
    builder: (context, _) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radiusTween.evaluate(curved)),
        child: child,
      );
    },
  );
}

class _ProfileAvatarPreviewOverlay extends StatelessWidget {
  const _ProfileAvatarPreviewOverlay({
    required this.displayName,
    required this.avatarImage,
    required this.heroTag,
    required this.previewFit,
    required this.previewMaxScale,
  });

  final String displayName;
  final ImageProvider? avatarImage;
  final Object heroTag;
  final BoxFit previewFit;
  final double previewMaxScale;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final previewWidth = (size.width - 32).clamp(260.0, 420.0);
    final previewHeight =
        (previewWidth * 1.25).clamp(280.0, size.height * 0.72);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: previewMaxScale,
                boundaryMargin: const EdgeInsets.all(80),
                child: Hero(
                  tag: heroTag,
                  createRectTween: (begin, end) =>
                      MaterialRectCenterArcTween(begin: begin, end: end),
                  flightShuttleBuilder: profileAvatarFlightShuttleBuilder,
                  child: _LargeProfileAvatarPreview(
                    displayName: displayName,
                    avatarImage: avatarImage,
                    width: previewWidth,
                    height: previewHeight,
                    fit: previewFit,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LargeProfileAvatarPreview extends StatelessWidget {
  const _LargeProfileAvatarPreview({
    required this.displayName,
    required this.avatarImage,
    required this.width,
    required this.height,
    required this.fit,
  });

  final String displayName;
  final ImageProvider? avatarImage;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.actionSurface(context),
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: Alignment.center,
      child: Text(
        (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase(),
        style: Theme.of(context).textTheme.displayMedium,
      ),
    );
    final image = avatarImage;
    if (image == null) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: ImageFade(
        image: image,
        height: height,
        width: width,
        fit: fit,
        placeholder: fallback,
        errorBuilder: (context, error) => fallback,
      ),
    );
  }
}
