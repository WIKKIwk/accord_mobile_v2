import '../../../../app/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shell/app_shell.dart';
import 'admin_dock.dart';
import 'admin_drawer_navigation.dart';
import 'admin_navigation_drawer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.title,
    required this.child,
    required this.activeTab,
    this.selectedRouteName,
    this.subtitle = '',
    this.leading,
    this.actions,
    this.bottomDockFadeStrength,
    this.contentPadding = EdgeInsets.zero,
    this.includeDrawer = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final AdminDockTab? activeTab;
  final String? selectedRouteName;
  final Widget? leading;
  final List<Widget>? actions;
  final ValueListenable<double>? bottomDockFadeStrength;
  final EdgeInsets contentPadding;
  final bool includeDrawer;

  void _openDrawerRoute(BuildContext context, String routeName) {
    if (ModalRoute.of(context)?.settings.name == routeName) {
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      drawer: includeDrawer
          ? AdminNavigationDrawer(
              selectedIndex: 0,
              selectedRouteName: selectedRouteName ?? AppRoutes.adminHome,
              onNavigate: (routeName) => _openDrawerRoute(context, routeName),
            )
          : null,
      leading: leading,
      actions: actions,
      title: title,
      subtitle: subtitle,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(activeTab: activeTab),
      bottomDockFadeStrength: bottomDockFadeStrength,
      contentPadding: contentPadding,
      child: child,
    );
  }
}
