import 'package:flutter/material.dart';

class AppNavigationDestination {
  const AppNavigationDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.onLongPress,
    this.showBadge = false,
    this.isPrimary = false,
  });

  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  final VoidCallback? onLongPress;
  final bool showBadge;
  final bool isPrimary;
}
