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

    var foundHome = false;
    navigator.popUntil((route) {
      if (route.settings.name == AppRoutes.adminHome) {
        foundHome = true;
        return true;
      }
      if (route.isFirst) {
        return true;
      }
      return false;
    });

    if (foundHome &&
        ModalRoute.of(context)?.settings.name == AppRoutes.adminHome) {
      if (routeName == AppRoutes.adminHome) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) {
          return;
        }
        if (ModalRoute.of(context)?.settings.name == routeName) {
          return;
        }
        Navigator.of(context).pushNamed(routeName);
      });
      return;
    }

    AppRootNavigation.replaceRootRoute(context, routeName);
  }
}
