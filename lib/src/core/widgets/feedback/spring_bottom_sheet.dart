import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../lists/m3_segmented_list.dart';

/// Pastdan chiqadigan spring-animatsiyali modal sheet.
///
/// [showModalBottomSheet] o'rniga ishlatiladi — API bir xil:
/// ```dart
/// showSpringBottomSheet<bool>(
///   context: context,
///   builder: (context) => ConfirmSheet(),
/// );
/// ```
///
/// Kontent kichik modallar uchun: [builder] dan qaytgan widget
/// `Column(mainAxisSize: MainAxisSize.min)` bo'lsin, ichida scrollable
/// bo'lmasin — scrollable drag'ni o'ziga tortib oladi va sheet yopilmay
/// qoladi. Ko'p account'li ro'yxatlarda faqat bo'sh joy/handle'dan
/// tortilganda yopiladi — bu kutilgan cheklov.
Future<T?> showSpringBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
}) {
  return Navigator.of(context, rootNavigator: useRootNavigator).push(
    SpringSheetRoute<T>(builder: builder),
  );
}

/// Pastki chekkaga yopishgan spring-animatsiyali route.
class SpringSheetRoute<T> extends PopupRoute<T> {
  SpringSheetRoute({required this.builder, super.settings});

  /// Sheet kontenti — fon/radius [SheetContainer]'dan keladi.
  final WidgetBuilder builder;

  // SwiftUI `.smooth` spring: 300ms kirish, 200ms chiqish.
  static const SpringDescription _enterSpring = SpringDescription(
    mass: 1,
    stiffness: 438.6,
    damping: 41.9,
  );
  static const SpringDescription _exitSpring = SpringDescription(
    mass: 1,
    stiffness: 987.0,
    damping: 62.8,
  );

  static const double _overdragResistance = 100;
  static const double _closeVelocity = 0.9;
  static const double _closePosition = 0.5;

  double? _releaseVelocity;
  bool _popped = false;

  @override
  Color? get barrierColor => const Color(0x8A000000);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Animation<double>? get animation {
    final Animation<double>? raw = super.animation;
    if (raw == null) return null;
    return _ClampedAnimation(raw);
  }

  @override
  AnimationController createAnimationController() {
    return AnimationController.unbounded(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      vsync: navigator!,
    );
  }

  @override
  Simulation? createSimulation({required bool forward}) {
    final double velocity = _releaseVelocity ?? 0;
    _releaseVelocity = null;
    return SpringSimulation(
      forward ? _enterSpring : _exitSpring,
      controller?.value ?? 0,
      forward ? 1 : 0,
      -velocity,
      snapToEnd: true,
    );
  }

  @override
  bool didPop(T? result) {
    FocusManager.instance.primaryFocus?.unfocus();
    _popped = true;
    return super.didPop(result);
  }

  void _dragBy(double relativeDelta) {
    if (_popped) return;
    final AnimationController controller = this.controller!;
    double delta = relativeDelta;
    if (controller.value > 1) {
      final double overshoot = controller.value - 1;
      delta *= 1 / (1 + overshoot * _overdragResistance);
    }
    controller.value -= delta;
  }

  void _endDrag(double relativeVelocity) {
    if (_popped) return;
    final AnimationController controller = this.controller!;
    final double value = controller.value;

    if (value > 1) {
      final double overshoot = value - 1;
      final double damped =
          relativeVelocity / (1 + overshoot * _overdragResistance);
      controller.animateWith(
        SpringSimulation(_enterSpring, value, 1, -damped, snapToEnd: true),
      );
      return;
    }

    final bool close = switch (relativeVelocity) {
      > _closeVelocity => true,
      < -_closeVelocity => false,
      _ => value < _closePosition,
    };

    if (close) {
      _releaseVelocity = relativeVelocity;
      navigator?.pop();
    } else {
      controller.animateWith(
        SpringSimulation(
          _enterSpring,
          value,
          1,
          -relativeVelocity,
          snapToEnd: true,
        ),
      );
    }
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedPadding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedBuilder(
          animation: controller!,
          builder: (context, child) {
            return FractionalTranslation(
              translation: Offset(0, 1 - controller!.value),
              child: child,
            );
          },
          child: Builder(
            builder: (context) {
              double height() => context.size?.height ?? 1;
              return GestureDetector(
                excludeFromSemantics: true,
                onVerticalDragUpdate: (details) {
                  _dragBy(details.primaryDelta! / height());
                },
                onVerticalDragEnd: (details) {
                  _endDrag(details.velocity.pixelsPerSecond.dy / height());
                },
                onVerticalDragCancel: () {
                  _endDrag(0);
                },
                child: SizedBox(
                  width: double.infinity,
                  child: SheetContainer(child: builder(context)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [showSpringBottomSheet] uchun sirt: tema surface rangi + yuqori
/// burchaklar 28 (eski account sheet dizayniga mos).
class SheetContainer extends StatelessWidget {
  const SheetContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        child: ColoredBox(color: surface, child: child),
      ),
    );
  }
}

class AppSheetHandle extends StatelessWidget {
  const AppSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class AppActionSheetAction<T> {
  const AppActionSheetAction({
    required this.title,
    required this.icon,
    required this.value,
    this.subtitle,
    this.enabled = true,
    this.destructive = false,
  });

  final String title;
  final IconData icon;
  final T value;
  final String? subtitle;
  final bool enabled;
  final bool destructive;
}

class AppActionSheet<T> extends StatelessWidget {
  const AppActionSheet({
    super.key,
    required this.title,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<AppActionSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title, style: theme.textTheme.headlineSmall),
            ),
            if ((subtitle ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            M3SegmentSpacedColumn(
              children: [
                for (var i = 0; i < actions.length; i++)
                  Builder(builder: (sheetContext) {
                    final action = actions[i];
                    final slot = M3SegmentedListGeometry
                        .standaloneListSlotForIndex(i, actions.length);
                    final radius =
                        M3SegmentedListGeometry.cornerRadiusForSlot(slot);
                    final foreground = action.destructive
                        ? scheme.error
                        : action.enabled
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.38);
                    return M3SegmentFilledSurface(
                      slot: slot,
                      cornerRadius: radius,
                      backgroundColor: scheme.surfaceContainerLowest,
                      onTap: action.enabled
                          ? () => Navigator.of(sheetContext).pop(action.value)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 9, 12, 9),
                        child: Row(
                          children: [
                            Icon(action.icon, color: foreground, size: 20),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    action.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: foreground,
                                    ),
                                  ),
                                  if ((action.subtitle ?? '').trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        action.subtitle!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: foreground),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: action.enabled
                                  ? scheme.onSurfaceVariant
                                  : scheme.outline,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClampedAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _ClampedAnimation(this.parent);

  @override
  final Animation<double> parent;

  @override
  double get value => parent.value.clamp(0.0, 1.0);
}
