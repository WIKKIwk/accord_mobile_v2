import 'package:flutter/material.dart';

/// Root tab/dock navigatsiyasi — bir frame ichidagi qo'sh navigatsiyani oldini oladi.
abstract final class AppRootNavigation {
  AppRootNavigation._();

  static String? _scheduledRootRoute;
  static bool _rootCallbackScheduled = false;

  static void replaceRootRoute(BuildContext context, String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    _scheduledRootRoute = routeName;
    if (_rootCallbackScheduled) {
      return;
    }
    _rootCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootCallbackScheduled = false;
      final target = _scheduledRootRoute;
      _scheduledRootRoute = null;
      if (target == null || !context.mounted) {
        return;
      }
      final now = ModalRoute.of(context)?.settings.name;
      if (now == target) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(target, (route) => false);
    });
  }
}
