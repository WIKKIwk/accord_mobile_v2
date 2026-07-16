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
    final end = height / MediaQuery.sizeOf(context).height;
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00FFFFFF),
            Color(0x26FFFFFF),
            Color(0x66FFFFFF),
            Color(0xB3FFFFFF),
            Color(0xFFFFFFFF),
          ],
          stops: [
            0,
            end * 0.25,
            end * 0.5,
            end * 0.75,
            end,
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
