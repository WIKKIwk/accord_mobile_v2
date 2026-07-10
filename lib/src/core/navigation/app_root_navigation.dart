import 'package:flutter/material.dart';

/// Root tab/dock navigatsiyasi — bir frame ichidagi qo'sh navigatsiyani oldini oladi.
abstract final class AppRootNavigation {
  AppRootNavigation._();

  static final _AppRouteStackObserver _routeObserver = _AppRouteStackObserver();
  static String? _scheduledRootRoute;
  static bool _rootCallbackScheduled = false;

  static NavigatorObserver get navigatorObserver => _routeObserver;

  static bool containsRoute(String routeName) {
    return _routeObserver.containsRoute(routeName);
  }

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
      final navigator = Navigator.of(context);
      if (_routeObserver.containsRoute(target)) {
        navigator.popUntil((route) => route.settings.name == target);
        return;
      }
      navigator.pushNamed(target);
    });
  }
}

class _AppRouteStackObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  bool containsRoute(String routeName) {
    return _routes.any((route) => route.settings.name == routeName);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _routes.remove(route);
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final oldIndex = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (oldRoute != null) {
      _routes.remove(oldRoute);
    }
    if (newRoute == null) {
      return;
    }
    _routes.remove(newRoute);
    if (oldIndex >= 0 && oldIndex <= _routes.length) {
      _routes.insert(oldIndex, newRoute);
    } else {
      _routes.add(newRoute);
    }
  }
}
