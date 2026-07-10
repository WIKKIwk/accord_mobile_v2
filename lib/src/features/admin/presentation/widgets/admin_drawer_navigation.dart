import '../../../../app/app_router.dart';
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
    navigator.popUntil(
      (route) => route.settings.name == AppRoutes.adminHome || route.isFirst,
    );

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
  }
}
