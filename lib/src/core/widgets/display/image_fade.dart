import 'package:flutter/material.dart';

class ImageFade extends StatelessWidget {
  const ImageFade({
    super.key,
    required this.image,
    required this.placeholder,
    required this.errorBuilder,
    this.fit,
    this.width,
    this.height,
    this.cacheWidth,
    this.cacheHeight,
    this.gaplessPlayback = true,
  });

  final ImageProvider<Object> image;
  final Widget placeholder;
  final Widget Function(BuildContext context, Object exception) errorBuilder;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> resolvedImage =
        cacheWidth == null && cacheHeight == null
            ? image
            : ResizeImage(
                image,
                width: cacheWidth,
                height: cacheHeight,
              );
    return Image(
      image: resolvedImage,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: gaplessPlayback,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        final loaded = wasSynchronouslyLoaded || frame != null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: loaded
              ? KeyedSubtree(key: const ValueKey('image'), child: child)
              : KeyedSubtree(
                  key: const ValueKey('placeholder'),
                  child: placeholder,
                ),
        );
      },
      errorBuilder: (context, exception, _) => errorBuilder(context, exception),
    );
  }
}
