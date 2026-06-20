import 'package:flutter/material.dart';

class AdminSurfaceTabBar extends StatelessWidget {
  const AdminSurfaceTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.isScrollable = false,
    this.tabAlignment,
    this.onTap,
  });

  final TabController controller;
  final List<Tab> tabs;
  final bool isScrollable;
  final TabAlignment? tabAlignment;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        tabAlignment: tabAlignment,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        unselectedLabelStyle: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
        ),
        onTap: onTap,
        tabs: tabs,
      ),
    );
  }
}
