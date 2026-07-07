import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/material_taminotchi_dock.dart';
import 'widgets/material_taminotchi_navigation_drawer.dart';
import 'package:flutter/material.dart';

class MaterialTaminotchiHomeScreen extends StatefulWidget {
  const MaterialTaminotchiHomeScreen({super.key});

  @override
  State<MaterialTaminotchiHomeScreen> createState() =>
      _MaterialTaminotchiHomeScreenState();
}

class _MaterialTaminotchiHomeScreenState
    extends State<MaterialTaminotchiHomeScreen> {
  Future<void> _refreshProfile() async {
    try {
      await MobileApi.instance.profile();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openRoute(String route) {
    if (route == AppRoutes.profile || route == AppRoutes.gscaleMode) {
      Navigator.of(context).pushNamed(route);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final groups = profile?.assignedItemGroups ?? const <String>[];
    final hasMaterialGroupScope = groups.isNotEmpty;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Material ta’minotchisi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: MaterialTaminotchiNavigationDrawer(
        selectedRouteName: AppRoutes.materialHome,
        onNavigate: _openDrawerRoute,
      ),
      preferNativeTitle: true,
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
      bottom: const MaterialTaminotchiDock(
        activeTab: MaterialTaminotchiDockTab.home,
      ),
      child: AppRefreshIndicator(
        onRefresh: _refreshProfile,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
          children: [
            SmoothAppear(
              delay: const Duration(milliseconds: 20),
              child: _MaterialProfilePanel(profile: profile, groups: groups),
            ),
            if (!hasMaterialGroupScope) ...[
              const SizedBox(height: 14),
              const SmoothAppear(
                delay: Duration(milliseconds: 40),
                child: _MaterialScopeNotice(),
              ),
            ],
            const SizedBox(height: 14),
            SmoothAppear(
              delay: const Duration(milliseconds: 60),
              child: _MaterialActionPanel(
                hasMaterialGroupScope: hasMaterialGroupScope,
                onOpenRoute: _openRoute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialProfilePanel extends StatelessWidget {
  const _MaterialProfilePanel({required this.profile, required this.groups});

  final SessionProfile? profile;
  final List<String> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = (profile?.displayName.trim().isNotEmpty ?? false)
        ? profile!.displayName.trim()
        : 'Material ta’minotchisi';
    final phone = profile?.phone.trim() ?? '';

    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Text(
                    _initials(name),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Material ta’minotchisi profili',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.phone_rounded,
                  label: phone.isEmpty ? 'Kiritilmagan' : phone,
                ),
                _InfoChip(
                  icon: Icons.inventory_2_rounded,
                  label: '${groups.length} ta guruh',
                ),
              ],
            ),
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Biriktirilgan mahsulot guruhlari',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in groups)
                    Chip(
                      label: Text(group),
                      avatar: const Icon(Icons.category_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialActionPanel extends StatelessWidget {
  const _MaterialActionPanel({
    required this.hasMaterialGroupScope,
    required this.onOpenRoute,
  });

  final bool hasMaterialGroupScope;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            _ActionRow(
              icon: Icons.scale_outlined,
              title: 'Tarozilar rejimi',
              subtitle: 'Printer, tarozi va homashyo qabul qilish',
              onTap: () => onOpenRoute(AppRoutes.gscaleMode),
              isFirst: true,
            ),
            if (AppRouter.canOpenRoute(AppRoutes.adminRawMaterialAssignments))
              _ActionRow(
                icon: Icons.inventory_2_outlined,
                title: 'Homashyo biriktirish',
                subtitle: 'Zakazga kerakli rulon va materiallarni bog‘lash',
                onTap: () {
                  if (!hasMaterialGroupScope) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Avval material guruhlari biriktirilishi kerak',
                        ),
                      ),
                    );
                    return;
                  }
                  onOpenRoute(AppRoutes.adminRawMaterialAssignments);
                },
              ),
            _ActionRow(
              icon: Icons.person_outline_rounded,
              title: 'Profil',
              subtitle: 'Avatar, ism, xavfsizlik va chiqish sozlamalari',
              onTap: () => onOpenRoute(AppRoutes.profile),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialScopeNotice extends StatelessWidget {
  const _MaterialScopeNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mahsulot guruhi biriktirilmagan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Homashyo qabul qilish va zakazga ulash uchun admin avval material guruhini biriktirishi kerak.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(isFirst ? 22 : 10),
          bottom: Radius.circular(isLast ? 22 : 10),
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: scheme.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return 'M';
  }
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
