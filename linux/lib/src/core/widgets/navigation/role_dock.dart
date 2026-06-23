import '../../native_dock_bridge.dart';
import 'app_navigation_bar.dart';
import 'package:flutter/material.dart';

class RoleDockDestination {
  const RoleDockDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.active,
    required this.onTap,
    this.nativeIcon,
    this.nativeSelectedIcon,
    this.primary = false,
    this.showBadge = false,
    this.routeName,
    this.replaceStack = true,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool active;
  final VoidCallback onTap;
  final IconData? nativeIcon;
  final IconData? nativeSelectedIcon;
  final bool primary;
  final bool showBadge;
  final String? routeName;
  final bool replaceStack;
}

class RoleDock extends StatelessWidget {
  const RoleDock({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.selectionVisible,
    this.primaryVisible = false,
    this.compact = true,
    this.tightToEdges = true,
  });

  final List<RoleDockDestination> destinations;
  final int selectedIndex;
  final bool selectionVisible;
  final bool primaryVisible;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    final useNativeDock = NativeDockBridge.isSupportedPlatform &&
        NativeDockBridge.instance.supportsSystemDock;
    if (useNativeDock) {
      NativeDockBridge.instance.register(
        NativeDockState(
          visible: true,
          compact: compact,
          tightToEdges: tightToEdges,
          items: [
            for (final destination in destinations)
              if (!destination.primary || primaryVisible)
                NativeDockItem(
                  id: destination.id,
                  label: destination.label,
                  iconCodePoint:
                      (destination.nativeIcon ?? destination.icon).codePoint,
                  selectedIconCodePoint: (destination.nativeSelectedIcon ??
                          destination.selectedIcon)
                      .codePoint,
                  active: destination.active,
                  primary: destination.primary,
                  showBadge: destination.showBadge,
                  routeName: destination.primary ? null : destination.routeName,
                  replaceStack: destination.replaceStack,
                  onTap: destination.onTap,
                ),
          ],
        ),
      );
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tightToEdges ? 0 : 8),
      child: AppNavigationBar(
        height: compact ? 60 : 64,
        selectionVisible: selectionVisible,
        selectedIndex: selectedIndex,
        primaryVisible: primaryVisible,
        destinations: [
          for (final destination in destinations)
            AppNavigationDestination(
              label: destination.label,
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              isPrimary: destination.primary,
              showBadge: destination.showBadge,
            ),
        ],
        onDestinationSelected: (index) {
          if (index < 0 || index >= destinations.length) {
            return;
          }
          destinations[index].onTap();
        },
      ),
    );
  }
}
