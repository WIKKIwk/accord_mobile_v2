import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standard routes keep Material transitions with app durations', () {
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.chat),
    ) as MaterialPageRoute<dynamic>;

    expect(route.transitionDuration, AppMotion.pageEnter);
    expect(route.reverseTransitionDuration, AppMotion.pageExit);
  });

  test('profile route keeps Material transition with reduced duration', () {
    final route = AppRouter.onGenerateRoute(
      const RouteSettings(name: AppRoutes.profile),
    ) as MaterialPageRoute<dynamic>;

    expect(route.transitionDuration, AppMotion.profilePageTransition);
    expect(route.reverseTransitionDuration, AppMotion.profilePageTransition);
  });
}
