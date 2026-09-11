import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Bosilganda spring bilan kichrayib-qaytadigan wrapper.
///
/// `motor` paketidagi `SingleMotionBuilder(CupertinoMotion.smooth())`
/// bilan bir xil hissiyot — lekin tashqi dependency'siz, faqat
/// `flutter/physics` spring'da:
///
/// ```dart
/// SpringPressable(
///   enabled: onPressed != null,
///   child: FilledButton(...),
/// )
/// ```
///
/// Ichki button o'z `onPressed`'ini boshqaradi — bu widget faqat scale
/// beradi. Shuning uchun `GestureDetector` emas, `Listener` (pointer
/// event) ishlatilgan: button tap arenasi bilan konfliktda bo'lmaydi.
class SpringPressable extends StatefulWidget {
  const SpringPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.96,
  });

  final Widget child;
  final bool enabled;
  final double pressedScale;

  @override
  State<SpringPressable> createState() => _SpringPressableState();
}

class _SpringPressableState extends State<SpringPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static SpringDescription get _pressSpring {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      // Cupertino .smooth() ga yaqin: biroz yumshoq, tabiiy.
      return const SpringDescription(mass: 1, stiffness: 420, damping: 26);
    }
    // Material taraf: M3 expressive fast-spatial ruhida.
    return const SpringDescription(mass: 1, stiffness: 520, damping: 24);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(value: 1, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.animateWith(
      SpringSimulation(_pressSpring, _controller.value, target, 0,
          snapToEnd: false),
    );
  }

  void _press() {
    if (!widget.enabled) return;
    _animateTo(widget.pressedScale);
  }

  void _release() {
    if (!widget.enabled) return;
    _animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _press(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: Transform.scale(scale: _controller.value, child: widget.child),
    );
  }
}
