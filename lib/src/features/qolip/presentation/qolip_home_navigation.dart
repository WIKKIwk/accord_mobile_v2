import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';

abstract final class QolipHomeNavigation {
  static void open(BuildContext context) {
    final navigator = Navigator.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    if (AppRootNavigation.containsRouteIn(navigator, AppRoutes.qolipHome)) {
      navigator.popUntil((route) => route.settings.name == AppRoutes.qolipHome);
    } else {
      navigator.pushNamedAndRemoveUntil(AppRoutes.qolipHome, (route) => false);
    }
  }
}
