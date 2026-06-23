import '../../localization/app_localizations.dart';
import '../feedback/logout_prompt.dart';
import 'package:flutter/material.dart';

class RoleNavigationDrawerDestination {
  const RoleNavigationDrawerDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.routeName,
    this.push = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String routeName;
  final bool push;
}

class RoleNavigationDrawer extends StatelessWidget {
  const RoleNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onNavigate,
    this.selectedRouteName,
    this.headerLabel,
  });

  final int selectedIndex;
  final List<RoleNavigationDrawerDestination> destinations;
  final ValueChanged<String> onNavigate;
  final String? selectedRouteName;
  final String? headerLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedRoute = selectedRouteName;
    final effectiveSelectedIndex = selectedRoute == null
        ? selectedIndex
        : destinations.indexWhere(
            (destination) => destination.routeName == selectedRoute,
          );

    return SizedBox(
      width: 272,
      child: Stack(
        children: [
          NavigationDrawer(
            backgroundColor: scheme.surfaceContainerLow,
            indicatorColor: scheme.secondaryContainer,
            surfaceTintColor: Colors.transparent,
            selectedIndex:
                effectiveSelectedIndex >= 0 ? effectiveSelectedIndex : null,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            onDestinationSelected: (index) async {
              if (index < 0 || index >= destinations.length) {
                Navigator.of(context).pop();
                return;
              }
              final destination = destinations[index];
              if (index == effectiveSelectedIndex) {
                Navigator.of(context).pop();
                return;
              }
              Navigator.of(context).pop();
              await Future<void>.delayed(const Duration(milliseconds: 220));
              if (!context.mounted) {
                return;
              }
              if (destination.push) {
                Navigator.of(context).pushNamed(destination.routeName);
                return;
              }
              onNavigate(destination.routeName);
            },
            header: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  headerLabel ?? 'Bo‘limlar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            children: [
              for (final destination in destinations)
                NavigationDrawerDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 168),
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                Navigator.of(context).pop();
                await Future<void>.delayed(const Duration(milliseconds: 120));
                if (!context.mounted) {
                  return;
                }
                await showLogoutPrompt(context);
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(context.l10n.logoutTitle),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
