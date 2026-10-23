import '../../../../app/app_router.dart';
import '../../../../core/api/mobile_api.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/session/session_read_scope.dart';
import '../../../../core/session/state/app_session.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import '../../../admin/logic/canonical_apparatus_groups.dart';
import '../../../shared/models/app_models.dart';
import '../aparatchi_paddon_scope.dart';
import 'package:flutter/material.dart';

class AparatchiNavigationDrawer extends StatefulWidget {
  const AparatchiNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    this.selectedRouteName,
    this.apparatusLoader,
  });

  final int selectedIndex;
  final ValueChanged<String> onNavigate;
  final String? selectedRouteName;
  final Future<List<AdminApparatus>> Function()? apparatusLoader;

  @override
  State<AparatchiNavigationDrawer> createState() =>
      _AparatchiNavigationDrawerState();
}

class _AparatchiNavigationDrawerState extends State<AparatchiNavigationDrawer> {
  late Future<List<AdminApparatus>> _apparatus;
  late Object _scope;

  Object get _currentScope => (
        currentSessionReadScope(),
        AppSession.instance.profile?.assignedApparatus.join('|'),
      );

  Future<List<AdminApparatus>> _loadApparatus() {
    final profile = AppSession.instance.profile;
    if (profile?.role != UserRole.aparatchi ||
        profile!.assignedApparatus.isEmpty) {
      return Future.value(const []);
    }
    return widget.apparatusLoader?.call() ??
        MobileApi.instance.adminApparatus(limit: 10000);
  }

  @override
  void initState() {
    super.initState();
    _scope = _currentScope;
    _apparatus = _loadApparatus();
    AppSession.instance.revision.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (_scope == _currentScope) return;
    setState(() {
      _scope = _currentScope;
      _apparatus = _loadApparatus();
    });
  }

  @override
  void didUpdateWidget(covariant AparatchiNavigationDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apparatusLoader != widget.apparatusLoader) {
      _apparatus = _loadApparatus();
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = AppSession.instance.profile;
    final showDailyWork = profile != null &&
        profile.role == UserRole.aparatchi &&
        profile.assignedApparatus.any(
          isCanonicalApparatusId,
        );
    return FutureBuilder<List<AdminApparatus>>(
      future: _apparatus,
      builder: (context, snapshot) => RoleNavigationDrawer(
        selectedIndex: widget.selectedIndex,
        selectedRouteName: widget.selectedRouteName,
        onNavigate: widget.onNavigate,
        destinations: [
          RoleNavigationDrawerDestination(
            icon: Icons.view_list_outlined,
            selectedIcon: Icons.view_list_rounded,
            label: l10n.monitoringNavTitle,
            routeName: AppRoutes.apparatusQueue,
          ),
          if (showDailyWork)
            RoleNavigationDrawerDestination(
              icon: Icons.today_outlined,
              selectedIcon: Icons.today_rounded,
              label: l10n.productionText('worker.daily'),
              routeName: AppRoutes.apparatusDailyWork,
            ),
          for (final apparatus in assignedPaddonApparatus(
            snapshot.data ?? const [],
            profile?.assignedApparatus ?? const [],
          ))
            RoleNavigationDrawerDestination(
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              label: apparatusPaddonsTitle(l10n, apparatus.name),
              routeName: apparatusPaddonsRoute(apparatus.id,
                  apparatusName: apparatus.name),
            ),
          RoleNavigationDrawerDestination(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            label: l10n.productionText('worker.instructions'),
            routeName: AppRoutes.apparatusWorkInstructions,
          ),
          if (AppRouter.canOpenRoute(AppRoutes.inventoryMovements))
            RoleNavigationDrawerDestination(
              icon: Icons.swap_horiz_outlined,
              selectedIcon: Icons.swap_horiz_rounded,
              label: l10n.productionText('worker.transfer'),
              routeName: AppRoutes.inventoryMovements,
              push: true,
            ),
          RoleNavigationDrawerDestination(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.profileTitle,
            routeName: AppRoutes.profile,
          ),
        ],
      ),
    );
  }
}
