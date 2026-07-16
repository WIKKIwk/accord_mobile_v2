import 'package:flutter/material.dart';

class ProgressiveFade extends StatelessWidget {
  const ProgressiveFade({
    super.key,
    required this.child,
    this.height = 120,
  });

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        final extent = (height / bounds.height).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00FFFFFF),
            Color(0x33FFFFFF),
            Color(0x80FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x80FFFFFF),
            Color(0x33FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [
            0,
            extent * 0.25,
            extent * 0.5,
            extent,
            1 - extent,
            1 - extent * 0.5,
            1 - extent * 0.25,
            1,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
