import 'dart:async';

import '../gscale_mobile_app.dart';
import '../../../app/app_router.dart';
import '../../../core/session/session.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_transport.dart';
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
  UsbPrinterProfile? _offlinePrinter;
  BluetoothPrinterProfile? _bluetoothPrinter;
  PrintTransport _printTransport = PrintTransport.wifi;
  bool _deviceNeedsAttention = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLastPrintDevice());
  }

  Future<void> _restoreLastPrintDevice() async {
    final saved = await loadLastPrintDevice();
    if (saved == null) {
      return;
    }
    final selection = await restoreLastPrintDevice(saved);
    if (!mounted) {
      return;
    }
    if (selection == null) {
      setState(() {
        _deviceNeedsAttention = true;
      });
      return;
    }
    setState(() {
      _printTransport = selection.transport;
      _offlinePrinter = selection.offlinePrinter;
      _bluetoothPrinter = selection.bluetoothPrinter;
      _selectedServer = selection.server;
      _deviceNeedsAttention = false;
    });
  }

  Future<void> _applyDeviceSelection(PrintDeviceSelection selection) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _printTransport = selection.transport;
      _offlinePrinter = selection.offlinePrinter;
      _bluetoothPrinter = selection.bluetoothPrinter;
      _selectedServer = selection.server;
      _deviceNeedsAttention = false;
    });
    await saveLastPrintDevice(selection);
  }

  void _clearSelectedServer() {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedServer = null;
      _deviceNeedsAttention = true;
    });
  }

  Future<void> _openServerPicker() async {
    final selection = await showPrintDevicePicker(context);
    if (selection == null) {
      return;
    }
    await _applyDeviceSelection(selection);
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
      title: 'Homashyo kirimi',
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
          icon: DevicePickerIcon(attention: _deviceNeedsAttention),
          tooltip: 'Printer yoki tarozi tanlash',
        ),
      ],
      bottom: const MaterialTaminotchiDock(
        activeTab: MaterialTaminotchiDockTab.scale,
      ),
      child: OperatorDashboardPage(
        server: _selectedServer,
        printTransport: _printTransport,
        offlinePrinter: _offlinePrinter,
        bluetoothPrinter: _bluetoothPrinter,
        deviceNeedsAttention: _deviceNeedsAttention,
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
