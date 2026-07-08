import '../gscale_mobile_app.dart';
import '../../../app/app_router.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/logout_prompt.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class GScaleModeScreen extends StatelessWidget {
  const GScaleModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppSession.instance.profile?.role == UserRole.materialTaminotchi) {
      return const _MaterialGScaleControlScreen();
    }
    return GScaleMobileApp(
      embedded: true,
      onExitMode: () async {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }
        await showLogoutPrompt(context);
      },
    );
  }
}

class _MaterialGScaleControlScreen extends StatefulWidget {
  const _MaterialGScaleControlScreen();

  @override
  State<_MaterialGScaleControlScreen> createState() =>
      _MaterialGScaleControlScreenState();
}

class _MaterialGScaleControlScreenState
    extends State<_MaterialGScaleControlScreen> {
  DiscoveredServer? _selectedServer;

  Future<void> _openServer(DiscoveredServer server) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedServer = server;
    });
  }

  void _clearSelectedServer() {
    if (!mounted || _selectedServer == null) {
      return;
    }
    setState(() {
      _selectedServer = null;
    });
  }

  Future<void> _openServerPicker() async {
    final server = await showModalBottomSheet<DiscoveredServer>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return ServerPickerPage(
          onOpenServer: (server) {
            Navigator.of(sheetContext).pop(server);
          },
          onExitMode: () async {
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
    if (server == null) {
      return;
    }
    await _openServer(server);
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Tarozilar rejimi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: MaterialTaminotchiNavigationDrawer(
        selectedRouteName: AppRoutes.gscaleMode,
        onNavigate: _openDrawerRoute,
      ),
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      actions: [
        IconButton(
          onPressed: () => _openServerPicker(),
          icon: const Icon(Icons.add_link_rounded),
          tooltip: 'Printer yoki tarozi tanlash',
        ),
      ],
      bottom: const MaterialTaminotchiDock(
        activeTab: MaterialTaminotchiDockTab.scale,
      ),
      child: OperatorDashboardPage(
        server: _selectedServer,
        onExitMode: () async {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        },
        onChangeServer: _openServerPicker,
        onServerUnavailable: _clearSelectedServer,
        controlOnly: true,
      ),
    );
  }
}
