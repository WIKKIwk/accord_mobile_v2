import '../../../../app/app_router.dart';
import 'package:flutter/material.dart';

class WerkaNavigationDrawer extends StatelessWidget {
  const WerkaNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final int selectedIndex;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onSurfaceVariant = scheme.onSurfaceVariant;
    return SizedBox(
      width: 272,
      child: NavigationDrawer(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        selectedIndex: selectedIndex,
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        onDestinationSelected: (index) {
          if (index == selectedIndex) {
            Navigator.of(context).pop();
            return;
          }
          Navigator.of(context).pop();
          switch (index) {
            case 0:
              onNavigate(AppRoutes.werkaHome);
            case 1:
              onNavigate(AppRoutes.werkaNotifications);
            case 2:
              onNavigate(AppRoutes.werkaArchive);
            case 3:
              onNavigate(AppRoutes.profile);
          }
        },
        header: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bo‘limlar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        children: const [
          NavigationDrawerDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: Text('Uy'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: Text('Bildirish'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive_rounded),
            label: Text('Data'),
          ),
          NavigationDrawerDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: Text('Profil'),
          ),
        ],
      ),
    );
  }
}
