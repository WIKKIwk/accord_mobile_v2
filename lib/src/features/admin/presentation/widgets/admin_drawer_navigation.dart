import '../../../../app/app_router.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import 'package:flutter/material.dart';

abstract final class AdminDrawerNavigation {
  AdminDrawerNavigation._();

  /// Drawer orqali admin sahifalar ochiladi.
  /// [AppRoutes.adminHome] stack da bo'lsa u saqlanadi — ortga/swipe ishlashi uchun.
  static void openRoute(BuildContext context, String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    final navigator = Navigator.of(context);
    if (AppRootNavigation.containsRoute(routeName)) {
      navigator.popUntil((route) => route.settings.name == routeName);
      return;
    }

    if (current != AppRoutes.adminHome &&
        AppRootNavigation.containsRoute(AppRoutes.adminHome)) {
      navigator.pushReplacementNamed(routeName);
      return;
    }

    navigator.pushNamed(routeName);
  }
}
