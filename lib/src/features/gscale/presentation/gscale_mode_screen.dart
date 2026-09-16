import 'dart:async';

import '../gscale_mobile_app.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/printing/session_bluetooth_printer.dart';
import '../../../core/print_transport.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/logout_prompt.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../preparation/presentation/preparation_navigation.dart';
import '../../preparation/presentation/widgets/preparation_kirim_order_section.dart';
import '../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class GScaleModeScreen extends StatelessWidget {
  const GScaleModeScreen({super.key, this.initialWarehouse});

  final String? initialWarehouse;

  @override
  Widget build(BuildContext context) {
    final role = AppSession.instance.profile?.role;
    if (role == UserRole.materialTaminotchi) {
      return _MaterialGScaleControlScreen(
        drawer: MaterialTaminotchiNavigationDrawer(
          selectedRouteName: AppRoutes.gscaleMode,
          onNavigate: _replaceDrawerRoute(context),
        ),
        bottom: const MaterialTaminotchiDock(
          activeTab: MaterialTaminotchiDockTab.scale,
        ),
      );
    }
    if (role == UserRole.tayyorlovMasteri) {
      return _MaterialGScaleControlScreen(
        drawer: PreparationDrawer(
          selectedRouteName: AppRoutes.gscaleMode,
          onNavigate: _replaceDrawerRoute(context),
        ),
        bottom: const PreparationDock(),
        linkPrintsToOrder: true,
        initialWarehouse: initialWarehouse,
      );
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

ValueChanged<String> _replaceDrawerRoute(BuildContext context) {
  return (route) {
    if (ModalRoute.of(context)?.settings.name == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  };
}

class _MaterialGScaleControlScreen extends StatefulWidget {
  const _MaterialGScaleControlScreen({
    required this.drawer,
    required this.bottom,
    this.linkPrintsToOrder = false,
    this.initialWarehouse,
  });

  final Widget drawer;
  final Widget bottom;

  /// true bo'lsa chop etilgan har bir homashyo tanlangan orderga
  /// avtomatik ulanadi (tayyorlov kirimi). Material oqimida false.
  final bool linkPrintsToOrder;
  final String? initialWarehouse;

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
  String? _linkedOrderId;
  double? _linkedOrderWidthMm;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreLastPrintDevice());
    // Backend yangilangandan keyin eski sessiyada capability/omborlar
    // eskirgan bo'lishi mumkin — kirim ochilganda yangilab olamiz.
    unawaited(_refreshProfileScope());
  }

  Future<void> _refreshProfileScope() async {
    try {
      await MobileApi.instance.profile();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Sessiya yaroqli bo'lsa ham eski profil bilan davom etiladi.
    }
  }

  Future<void> _restoreLastPrintDevice() async {
    // Boshqa ekranda (Qolip, Progress, ...) tanlangan BT printer sessiya
    // davomida eslab qolinadi — kirim sahifasiga har kirganda qayta so'ramaslik
    // uchun avval shuni tekshiramiz.
    final sessionBluetooth = await SessionBluetoothPrinter.resolveCached();
    if (sessionBluetooth != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _printTransport = PrintTransport.bluetooth;
        _offlinePrinter = null;
        _bluetoothPrinter = sessionBluetooth;
        _selectedServer = null;
        _deviceNeedsAttention = false;
      });
      await saveLastPrintDevice(
        PrintDeviceSelection.bluetooth(sessionBluetooth),
      );
      return;
    }
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
    if (selection.transport.isBluetooth && selection.bluetoothPrinter != null) {
      SessionBluetoothPrinter.remember(selection.bluetoothPrinter!);
    }
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

  bool get _isPrintDeviceConnected {
    if (_printTransport.isBluetooth) {
      return _bluetoothPrinter != null;
    }
    if (_printTransport.isOffline) {
      return _offlinePrinter != null;
    }
    return _selectedServer != null;
  }

  Future<void> _openServerPicker() async {
    final selection = await showPrintDevicePicker(context);
    if (selection == null) {
      return;
    }
    await _applyDeviceSelection(selection);
  }

  @override
  Widget build(BuildContext context) {
    final orderSection = widget.linkPrintsToOrder
        ? PreparationKirimOrderSection(
            onOrderChanged: (order) => setState(() {
              _linkedOrderId = order?.id;
              final width = order?.widthMm;
              _linkedOrderWidthMm =
                  width != null && width.isFinite && width > 0 ? width : null;
            }),
          )
        : null;
    return AppShell(
      title: 'Homashyo kirimi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: widget.drawer,
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      actions: [
        IconButton(
          onPressed: () => _openServerPicker(),
          icon: DevicePickerIcon(
            attention: _deviceNeedsAttention,
            connected: _isPrintDeviceConnected,
          ),
          tooltip: 'Printer yoki tarozi tanlash',
        ),
      ],
      bottom: widget.bottom,
      child: Column(
        children: [
          Expanded(
            child: OperatorDashboardPage(
              initialWarehouse: widget.initialWarehouse,
              orderSection: orderSection,
              server: _selectedServer,
              printTransport: _printTransport,
              offlinePrinter: _offlinePrinter,
              bluetoothPrinter: _bluetoothPrinter,
              deviceNeedsAttention: _deviceNeedsAttention,
              linkedOrderId:
                  widget.linkPrintsToOrder ? (_linkedOrderId ?? '') : '',
              linkedOrderWidthMm:
                  widget.linkPrintsToOrder ? _linkedOrderWidthMm : null,
              onExitMode: () async {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              onChangeServer: _openServerPicker,
              onServerUnavailable: _clearSelectedServer,
              controlOnly: true,
            ),
          ),
        ],
      ),
    );
  }
}
