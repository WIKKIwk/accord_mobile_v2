import 'dart:async';
import 'dart:convert';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/mobile_api.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/localization/locale_controller.dart';
import '../../core/native_bluetooth_printer.dart';
import '../../core/native_usb_printer.dart';
import '../../core/print_service.dart';
import '../../core/print_transport.dart';
import '../../core/session/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../core/widgets/lists/m3_segmented_list.dart';
import '../../core/widgets/navigation/app_navigation_bar.dart';
import '../../core/widgets/printing/bluetooth_printer_list.dart';
import '../shared/models/app_models.dart';
import '../admin/presentation/widgets/admin_summary_card.dart';
import '../werka/presentation/widgets/m3_picker_sheet.dart';
import 'gscale_catalog.dart';
import 'network_candidates_stub.dart'
    if (dart.library.io) 'network_candidates_io.dart' as network_candidates;

// Keep in sync with gscale-zebra mobileapi approved ports.

part 'gscale_mobile_app__OperatorDashboardPageState_methods_01.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_02.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_03.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_04.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_05.dart';
part 'gscale_mobile_app__OperatorDashboardPageState_methods_06.dart';
part 'gscale_mobile_app_declarations_part_01.dart';
part 'gscale_mobile_app_widgets_part_02.dart';
part 'gscale_mobile_app_declarations_part_03.dart';
part 'gscale_mobile_app_declarations_part_04.dart';
part 'gscale_mobile_app_models_part_05.dart';
part 'gscale_mobile_app_declarations_part_06.dart';
part 'gscale_mobile_app_helpers_part_07.dart';
part 'gscale_mobile_app_models_part_08.dart';
part 'gscale_mobile_app_declarations_part_09.dart';
part 'gscale_mobile_app_helpers_part_10.dart';
part 'gscale_mobile_app_helpers_part_11.dart';

const _defaultApiPort = 39117;
const _discoveryPort = 18081;
const _fastProbeTimeout = Duration(milliseconds: 350);
const _manualProbeTimeout = Duration(seconds: 2);
const _udpDiscoveryTimeout = Duration(milliseconds: 900);
const _fallbackProbeTimeout = Duration(milliseconds: 240);
const _fallbackProbeConcurrency = 24;
const _directProbePorts = <int>[39117, 41257, 43391, 45533, 47681];
const _enableAutomaticSubnetSweep = false;
const _lastServerKey = 'last_server_base_url';
const _cachedServersKey = 'cached_servers_v1';
const _controlDraftKey = 'operator_control_draft_v1';
const _lastPrintDeviceKey = 'gscale_last_print_device_v1';
const _defaultWifiServerAddress = 'http://gscale.local:39117';
const _platformDiscoveryTimeout = Duration(milliseconds: 900);
const _bonjourDiscoveryChannel = MethodChannel('gscale/bonjour');
const _nsdDiscoveryChannel = MethodChannel('gscale/nsd');
const _udpDiscoveryChannel = MethodChannel('gscale/udp_discovery');
const _platformDiscoveryServiceTypes = <String>[
  '_gscale-mobileapi._tcp.',
  '_rp-scale._tcp.',
];
const _minManualPrintKg = 0.100;
const _catalogPickerPageSize = 50;
const _configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultWifiServerAddress,
);

class _OperatorDashboardPageState extends State<OperatorDashboardPage>
    with SingleTickerProviderStateMixin {
  final http.Client _client = http.Client();
  final ValueNotifier<int> _latencyListenable = ValueNotifier<int>(0);
  final TextEditingController _defaultWarehouseController =
      TextEditingController();
  final TextEditingController _babinaWeightController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _micronController = TextEditingController();
  final TextEditingController _manualQtyController = TextEditingController();
  final TextEditingController _manualDuplicateController =
      TextEditingController();
  late final TabController _controlTabController;
  StreamSubscription<String>? _streamSubscription;
  int _streamGeneration = 0;
  int _selectedSection = 0;
  int _controlTabIndex = 0;

  bool _manualLoading = false;
  bool _manualPrintLoading = false;
  bool _requestInFlight = false;
  bool _batchActionLoading = false;
  bool _warehouseSetupLoading = false;
  bool _archiveLoading = false;
  bool _rpsBatchStateResolved = false;
  bool _batchContextEditing = false;
  bool _draftContextSaved = false;
  String _archivePrintLoadingSessionId = '';
  String _errorText = '';
  String _warehousesError = '';
  String _warehouseSetupError = '';
  String _archiveError = '';
  String _warehouseMode = 'manual';
  String _defaultWarehouse = '';
  String _batchPrintMode = 'rfid';
  String _batchPrinter = 'zebra';
  String _quantitySource = 'scale';
  bool _babinaEnabled = false;
  MonitorSnapshot _snapshot = MonitorSnapshot.empty();
  List<GScaleRpsBatchPrintEntry> _batchPrints = const [];
  GScaleRpsBatchSession? _authoritativeRsBatch;
  List<MobileArchiveSession> _archiveSessions = const [];
  MobileItem? _selectedItem;
  MobileWarehouse? _selectedWarehouse;
  Timer? _pingTimer;
  Timer? _printerStatusTimer;
  Timer? _controlPrefsDebounce;
  int _latencyGeneration = 0;
  bool _latencyRequestInFlight = false;
  int? _scheduledLiveRebuildGeneration;
  String _lastLivePayload = '';
  int _latencyFailureCount = 0;
  String _printerStatusOverride = '';
  String _lastAutoBatchPrintKey = '';
  String _lastRsBatchErrorKey = '';
  bool _suspendControlPrefsSave = false;

  @override
  void initState() {
    super.initState();
    _controlTabController = TabController(length: 2, vsync: this)
      ..addListener(_handleControlTabChanged);
    _manualQtyController.addListener(_scheduleSaveControlPrefs);
    _manualDuplicateController.addListener(_scheduleSaveControlPrefs);
    _babinaWeightController.addListener(_scheduleSaveControlPrefs);
    _widthController.addListener(_scheduleSaveControlPrefs);
    _micronController.addListener(_scheduleSaveControlPrefs);
    final server = widget.server;
    if (server != null) {
      _snapshot = MonitorSnapshot.empty().copyWithLatency(server.latencyMs);
      _latencyListenable.value = server.latencyMs;
    }
    _loadControlDraftPreferences();
    if (server != null) {
      _startLiveStream();
      _startPingLoop();
      unawaited(_refresh());
    }
    if (widget.controlOnly || server != null || widget.printTransport.isLocal) {
      unawaited(_refreshRsBatchState());
    }
  }

  @override
  void didUpdateWidget(covariant OperatorDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.server?.endpoint.baseUrl;
    final next = widget.server?.endpoint.baseUrl;
    if (previous == next && oldWidget.printTransport == widget.printTransport) {
      return;
    }
    _stopLiveStream();
    _stopPingLoop();
    final server = widget.server;
    _latencyListenable.value = server?.latencyMs ?? 0;
    setState(() {
      _snapshot = server == null
          ? MonitorSnapshot.empty()
          : MonitorSnapshot.empty().copyWithLatency(server.latencyMs);
      _errorText = '';
      _manualLoading = false;
      _requestInFlight = false;
      _latencyFailureCount = 0;
      _rpsBatchStateResolved = false;
      _authoritativeRsBatch = null;
    });
    if (server != null) {
      _startLiveStream();
      _startPingLoop();
      unawaited(_refresh());
    }
    if (widget.controlOnly || server != null || widget.printTransport.isLocal) {
      unawaited(_refreshRsBatchState());
    }
  }

  @override
  void dispose() {
    _stopPingLoop();
    _printerStatusTimer?.cancel();
    _controlPrefsDebounce?.cancel();
    _defaultWarehouseController.dispose();
    _babinaWeightController.dispose();
    _widthController.dispose();
    _micronController.dispose();
    _manualQtyController.dispose();
    _manualDuplicateController.dispose();
    _controlTabController
      ..removeListener(_handleControlTabChanged)
      ..dispose();
    _stopLiveStream();
    _latencyListenable.dispose();
    _client.close();
    super.dispose();
  }

  String get _currentDefaultWarehouse {
    final controllerValue = _defaultWarehouseController.text.trim();
    if (controllerValue.isNotEmpty) {
      return controllerValue;
    }
    return _defaultWarehouse.trim();
  }

  bool get _warehouseIndependentOfItem {
    return AppSession.instance.profile?.role == UserRole.materialTaminotchi;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final server = widget.server;

    if (widget.controlOnly) {
      return Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Material(
              color: scheme.surfaceContainer,
              child: TabBar(
                controller: _controlTabController,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                tabs: const [
                  Tab(height: 38, text: 'Print'),
                  Tab(height: 38, text: 'Print tarixi'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _controlTabController,
                children: [
                  _DashboardScrollView(
                    key: const ValueKey('control-section'),
                    horizontalPadding: 8,
                    child: _buildControlSection(
                      context,
                      theme,
                      scheme,
                      server,
                    ),
                  ),
                  _DashboardScrollView(
                    key: const ValueKey('print-history-section'),
                    horizontalPadding: 8,
                    child: _buildArchiveSection(
                      context,
                      theme,
                      scheme,
                      server,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(widget.onExitMode());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: AppTheme.appBarHeight,
          leading: IconButton(
            onPressed: () => unawaited(widget.onExitMode()),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          title: Text(server?.handshake.serverName ?? 'Tarozilar rejimi'),
          actions: [
            IconButton(
              onPressed: () => unawaited(widget.onChangeServer()),
              icon: DevicePickerIcon(attention: widget.deviceNeedsAttention),
              tooltip: 'Printer yoki tarozi tanlash',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<int>(
                    valueListenable: _latencyListenable,
                    builder: (context, latencyMs, _) => Text(
                      latencyMs > 0 ? '$latencyMs ms' : '—',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_selectedSection) {
            0 => _DashboardScrollView(
                key: const ValueKey('control-section'),
                child: _buildControlSection(context, theme, scheme, server),
              ),
            1 => _DashboardScrollView(
                key: const ValueKey('archive-section'),
                child: _buildArchiveSection(context, theme, scheme, server),
              ),
            _ => _DashboardScrollView(
                key: const ValueKey('server-section'),
                child: _buildServerSection(context, theme, scheme, server),
              ),
          },
        ),
        bottomNavigationBar: AppNavigationBar(
          height: 64,
          selectedIndex: _selectedSection,
          onDestinationSelected: (index) {
            setState(() {
              _selectedSection = index;
            });
            if (index == 1) {
              unawaited(_refreshArchive());
            }
          },
          destinations: const [
            AppNavigationDestination(
              label: 'Boshqaruv',
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune),
            ),
            AppNavigationDestination(
              label: 'Arxiv',
              icon: Icon(Icons.archive_outlined),
              selectedIcon: Icon(Icons.archive),
            ),
            AppNavigationDestination(
              label: 'Server',
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    DiscoveredServer? server,
  ) {
    final hasScaleDevice = server != null;
    final hasPrintDevice = widget.printTransport.isLocal || hasScaleDevice;
    final activeBatch = _rpsBatchStateResolved &&
            _authoritativeRsBatch != null &&
            _authoritativeRsBatch!.active
        ? _authoritativeRsBatch
        : null;
    final editingBatchContext = activeBatch != null && _batchContextEditing;
    final draftContextSummaryVisible =
        activeBatch == null && _draftContextSaved && !_batchContextEditing;
    final showContextFields =
        activeBatch == null ? !draftContextSummaryVisible : editingBatchContext;
    final lockedBatchContext = activeBatch != null && !editingBatchContext;
    final batchContextReady = hasExactRpsBatchContext(activeBatch);
    final selectedProduct = activeBatch == null || editingBatchContext
        ? _selectedItem
        : MobileItem(
            itemCode: activeBatch.itemCode,
            itemName: activeBatch.itemName,
            requiresDimensions:
                activeBatch.widthMm != null || activeBatch.micron != null,
          );
    final selectedWarehouse = activeBatch == null || editingBatchContext
        ? _selectedWarehouse
        : MobileWarehouse(warehouse: activeBatch.warehouse);
    final defaultWarehouse = _currentDefaultWarehouse;
    final defaultMode = activeBatch == null && _warehouseMode == 'default';
    final contextFieldsLocked = (activeBatch != null && !editingBatchContext) ||
        _batchActionLoading ||
        _manualPrintLoading;
    final printerLocked =
        _snapshot.batchActive || _batchActionLoading || _manualPrintLoading;
    final selectedPrinter = normalizePrinterChoice(_batchPrinter);
    final selectedQuantitySource = normalizeQuantitySource(
      lockedBatchContext ? activeBatch.quantitySource : _quantitySource,
    );
    final selectedBabinaEnabled =
        lockedBatchContext ? activeBatch.tareEnabled : _babinaEnabled;
    final manualQtyKg = selectedQuantitySource == 'manual'
        ? parsePositiveKg(_manualQtyController.text)
        : null;
    final duplicateCount = selectedQuantitySource == 'manual'
        ? parseManualDuplicateCount(_manualDuplicateController.text)
        : 1;
    final manualPrintReady = canTriggerManualPrint(
      qtyText: _manualQtyController.text,
      babinaEnabled: selectedBabinaEnabled,
      babinaText: _babinaWeightController.text,
    );
    final manualQtyInvalid = selectedQuantitySource == 'manual' &&
        _manualQtyController.text.trim().isNotEmpty &&
        manualQtyKg == null;
    final duplicateInvalid = selectedQuantitySource == 'manual' &&
        _manualDuplicateController.text.trim().isNotEmpty &&
        duplicateCount == null;
    final babinaInvalid = selectedBabinaEnabled &&
        _babinaWeightController.text.trim().isNotEmpty &&
        parsePositiveKg(_babinaWeightController.text) == null;
    final scaleQtyKg = parseScaleDisplayKg(_snapshot.scaleValue);
    final widthMm = parsePositiveKg(_widthController.text);
    final micron = parsePositiveKg(_micronController.text);
    final dimensionsReady = selectedProduct?.requiresDimensions != true ||
        (widthMm != null && micron != null);
    final widthInvalid = selectedProduct?.requiresDimensions == true &&
        _widthController.text.trim().isNotEmpty &&
        widthMm == null;
    final micronInvalid = selectedProduct?.requiresDimensions == true &&
        _micronController.text.trim().isNotEmpty &&
        micron == null;
    final hasPrintSelection = selectedProduct != null &&
        (defaultMode
            ? defaultWarehouse.isNotEmpty
            : selectedWarehouse != null) &&
        dimensionsReady;
    final batchContextSaveEnabled = showContextFields &&
        (activeBatch == null || batchContextReady) &&
        hasPrintSelection &&
        !_batchActionLoading &&
        !_manualPrintLoading &&
        !_requestInFlight;
    final scalePrintReady = canTriggerGrossPrint(
      grossKg: scaleQtyKg,
      babinaEnabled: selectedBabinaEnabled,
      babinaText: _babinaWeightController.text,
    );
    final scaleBatchActionEnabled = canPressScaleBatchAction(
          hasPrintSelection: hasPrintSelection,
          batchActive: _snapshot.batchActive,
          manualPrintLoading: _manualPrintLoading,
          batchActionLoading: _batchActionLoading,
        ) &&
        hasScaleDevice &&
        _rpsBatchStateResolved &&
        (_snapshot.batchActive ? batchContextReady : true);
    final manualBatchStartEnabled = hasPrintSelection &&
        hasPrintDevice &&
        !_snapshot.batchActive &&
        !_manualPrintLoading &&
        !_batchActionLoading &&
        !_requestInFlight &&
        _rpsBatchStateResolved;
    final manualBatchStopEnabled = activeBatch != null &&
        batchContextReady &&
        selectedQuantitySource == 'manual' &&
        !_manualPrintLoading &&
        !_batchActionLoading &&
        !_requestInFlight;
    final bluetoothPrinterLabel =
        widget.bluetoothPrinter?.displayName.trim().isNotEmpty == true
            ? widget.bluetoothPrinter!.displayName.trim()
            : 'XP-P323B';
    final printerStatusText = widget.printTransport.isOffline
        ? 'USB printer • Offline'
        : widget.printTransport.isBluetooth
            ? '$bluetoothPrinterLabel • Bluetooth'
            : _printerStatusOverride.isNotEmpty
                ? _printerStatusOverride
                : !_snapshot.hasPrinterState
                    ? _errorText.isEmpty
                        ? 'Printer holati olinmoqda'
                        : 'Printer holati olinmadi'
                    : _snapshot.printerLabel;
    final batchActionStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      visualDensity: const VisualDensity(horizontal: -1, vertical: 0),
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
    final controlInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    final controlFocusedInputBorder = controlInputBorder.copyWith(
      borderSide: BorderSide(color: scheme.primary, width: 1.6),
    );
    final controlErrorInputBorder = controlInputBorder.copyWith(
      borderSide: BorderSide(color: scheme.error),
    );
    final controlFocusedErrorInputBorder = controlInputBorder.copyWith(
      borderSide: BorderSide(color: scheme.error, width: 1.6),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        if (hasPrintDevice) ...[
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  printerStatusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onChangeServer,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                ),
                child: const Text('Almashtirish'),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (!_rpsBatchStateResolved && hasPrintDevice) ...[
          Row(
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Batch holati tekshirilmoqda…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (widget.printTransport.isOffline && !hasScaleDevice) ...[
          _OfflinePrintStatus(
            onChangeMode: widget.onChangeServer,
            printer: widget.offlinePrinter,
          ),
          const SizedBox(height: 8),
        ],
        if (hasScaleDevice) ...[
          Row(
            children: [
              Icon(Icons.scale_outlined, size: 22, color: scheme.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Joriy kg',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _snapshot.scaleValue,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  _snapshot.scaleConnectionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_errorText.isNotEmpty) ...[
          Text(
            _errorText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.error,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (activeBatch != null && !editingBatchContext) ...[
          _BatchContextSummary(
            itemName: activeBatch.displayItemName,
            warehouse: activeBatch.warehouse,
            widthMm: activeBatch.widthMm,
            micron: activeBatch.micron,
            quantitySource: activeBatch.quantitySource,
            babinaEnabled: activeBatch.tareEnabled,
            tareKg: activeBatch.tareKg,
            onEdit: _batchActionLoading || _manualPrintLoading
                ? null
                : _beginBatchContextEdit,
          ),
          const SizedBox(height: 8),
        ],
        if (draftContextSummaryVisible) ...[
          _BatchContextSummary(
            itemName:
                selectedProduct?.itemName ?? selectedProduct?.itemCode ?? '',
            warehouse: _selectedPrintWarehouse() ?? '',
            widthMm: parsePositiveKg(_widthController.text),
            micron: parsePositiveKg(_micronController.text),
            quantitySource: _quantitySource,
            babinaEnabled: _babinaEnabled,
            tareKg: parsePositiveKg(_babinaWeightController.text) ?? 0,
            onEdit: _batchActionLoading || _manualPrintLoading
                ? null
                : _beginBatchContextEdit,
          ),
          const SizedBox(height: 8),
        ],
        if (showContextFields) ...[
          _PickerField(
            icon: Icons.search_rounded,
            label: 'Mahsulot tanlang',
            value: selectedProduct?.itemCode,
            subtitle: null,
            onTap: contextFieldsLocked ? null : _openItemPicker,
          ),
          const SizedBox(height: 8),
          if (selectedProduct?.requiresDimensions == true) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    enabled: !contextFieldsLocked,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Eni (mm)',
                      errorText: widthInvalid ? "To'g'ri eni kiriting" : null,
                      border: controlInputBorder,
                      enabledBorder: controlInputBorder,
                      focusedBorder: controlFocusedInputBorder,
                      errorBorder: controlErrorInputBorder,
                      focusedErrorBorder: controlFocusedErrorInputBorder,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _micronController,
                    enabled: !contextFieldsLocked,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Mikron',
                      errorText:
                          micronInvalid ? "To'g'ri mikron kiriting" : null,
                      border: controlInputBorder,
                      enabledBorder: controlInputBorder,
                      focusedBorder: controlFocusedInputBorder,
                      errorBorder: controlErrorInputBorder,
                      focusedErrorBorder: controlFocusedErrorInputBorder,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (defaultMode) ...[
            if (defaultWarehouse.isEmpty)
              Text(
                'Default ombor tanlanmagan.',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              )
            else
              _MiniIconRow(
                icon: Icons.flag_rounded,
                text: 'Standart ombor: $defaultWarehouse',
              ),
          ] else if (selectedProduct == null) ...[
            const SizedBox(height: 6),
            Text(
              'Avval mahsulot tanlang, keyin ombor chiqadi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ] else ...[
            _PickerField(
              icon: Icons.warehouse_outlined,
              label: 'Ombor tanlang',
              value: selectedWarehouse?.warehouse,
              subtitle: null,
              onTap: contextFieldsLocked ? null : _openWarehousePicker,
            ),
            if (_warehousesError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _warehousesError,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
          ],
          const SizedBox(height: 8),
          _ContextSwitchRow(
            label: 'Miqdor (kg)',
            valueText: selectedQuantitySource == 'manual'
                ? 'Qo‘lda kg'
                : 'Tarozidan kg',
            value: selectedQuantitySource == 'manual',
            onChanged: contextFieldsLocked
                ? null
                : (manual) {
                    setState(() {
                      _quantitySource = manual ? 'manual' : 'scale';
                    });
                    _scheduleSaveControlPrefs();
                  },
          ),
          const SizedBox(height: 4),
          _ContextSwitchRow(
            label: 'Babina',
            valueText: selectedBabinaEnabled ? 'Bor' : 'Yo‘q',
            value: selectedBabinaEnabled,
            onChanged: contextFieldsLocked
                ? null
                : (enabled) {
                    setState(() {
                      _babinaEnabled = enabled;
                      if (!enabled) {
                        _babinaWeightController.clear();
                      }
                    });
                    _scheduleSaveControlPrefs();
                  },
          ),
          if (showContextFields) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: batchContextSaveEnabled
                    ? () => unawaited(_saveBatchContextEdit())
                    : null,
                icon: _batchActionLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Saqlash'),
              ),
            ),
          ],
        ],
        if (selectedBabinaEnabled) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: babinaInvalid ? 72 : 50,
            child: TextField(
              controller: _babinaWeightController,
              enabled: !_batchActionLoading && !_manualPrintLoading,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              maxLines: 1,
              minLines: 1,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Babina og‘irligi',
                suffixText: 'kg',
                hintText: '0.78',
                errorText: babinaInvalid ? 'Masalan: 0.78' : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: controlInputBorder,
                enabledBorder: controlInputBorder,
                focusedBorder: controlFocusedInputBorder,
                errorBorder: controlErrorInputBorder,
                focusedErrorBorder: controlFocusedErrorInputBorder,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (selectedQuantitySource == 'manual') ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: manualQtyInvalid ? 72 : 50,
                  child: TextField(
                    controller: _manualQtyController,
                    enabled: !_batchActionLoading && !_manualPrintLoading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: 'Qo‘lda brutto kg',
                      suffixText: 'kg',
                      hintText: '5',
                      errorText:
                          manualQtyInvalid ? 'Masalan: 5 yoki 4.22' : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: controlInputBorder,
                      enabledBorder: controlInputBorder,
                      focusedBorder: controlFocusedInputBorder,
                      errorBorder: controlErrorInputBorder,
                      focusedErrorBorder: controlFocusedErrorInputBorder,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SizedBox(
                    height: duplicateInvalid ? 72 : 50,
                    child: TextField(
                      controller: _manualDuplicateController,
                      enabled: !_batchActionLoading && !_manualPrintLoading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Duplicate soni',
                        suffixText: 'ta',
                        hintText: '1',
                        errorText:
                            duplicateInvalid ? 'Masalan: 1 yoki 5' : null,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: controlInputBorder,
                        enabledBorder: controlInputBorder,
                        focusedBorder: controlFocusedInputBorder,
                        errorBorder: controlErrorInputBorder,
                        focusedErrorBorder: controlFocusedErrorInputBorder,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_snapshot.batchActive)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: batchActionStyle,
                    onPressed: hasPrintDevice &&
                            selectedQuantitySource == 'manual' &&
                            manualPrintReady &&
                            !_manualPrintLoading &&
                            !_batchActionLoading
                        ? _printManualBatch
                        : null,
                    icon: _manualPrintLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_rounded, size: 23),
                    label: const Text('Chop etish'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: batchActionStyle,
                    onPressed: manualBatchStopEnabled
                        ? () => unawaited(_stopRsBatch())
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined, size: 23),
                    label: const Text('Batch stop'),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                style: batchActionStyle,
                onPressed: manualBatchStartEnabled
                    ? () => unawaited(
                          _startBatch(autoPrintStable: false),
                        )
                    : null,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 23),
                label: const Text('Batch start'),
              ),
            ),
          if (!_snapshot.batchActive) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Avval Batch start, keyin Chop etish orqali print qiling.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_manualPrintLoading) ...[
            const SizedBox(height: 4),
            Text(
              'Chop etish yuborilmoqda...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
        if (selectedQuantitySource == 'scale') ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: scaleBatchActionEnabled
                ? (_snapshot.batchActive
                    ? () => unawaited(_stopRsBatch())
                    : () => unawaited(_startBatch(autoPrintStable: true)))
                : null,
            icon: _batchActionLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _snapshot.batchActive
                        ? Icons.stop_circle_outlined
                        : Icons.play_arrow_rounded,
                  ),
            label: Text(
              scaleBatchActionLabel(
                loading: _batchActionLoading,
                batchActive: _snapshot.batchActive,
              ),
            ),
          ),
          if (_snapshot.batchActive) ...[
            const SizedBox(height: 4),
            Text(
              scalePrintReady
                  ? 'Stable kg avtomatik chop etiladi.'
                  : 'Stable kg kutilmoqda.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ] else if (hasScaleDevice && scaleQtyKg == null) ...[
            const SizedBox(height: 4),
            Text(
              'Scale ulangan va kg kelganda tugma aktiv bo‘ladi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
        if (_batchPrints.isNotEmpty) ...[
          _buildCurrentBatchPrints(theme, scheme),
          const SizedBox(height: 8),
        ],
        ExpansionTile(
          key: const PageStorageKey<String>('batch_actions_tile'),
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: Text(
            'Printer sozlamalari',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            IgnorePointer(
              ignoring: printerLocked,
              child: Opacity(
                opacity: printerLocked ? 0.6 : 1,
                child: SegmentedButton<String>(
                  style: _segmentStyle(context),
                  segments: const [
                    ButtonSegment<String>(
                      value: 'zebra',
                      label: Text('Zebra'),
                      icon: Icon(Icons.memory_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'godex',
                      label: Text('GoDEX'),
                      icon: Icon(Icons.local_printshop_outlined),
                    ),
                  ],
                  selected: <String>{selectedPrinter},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    final nextPrinter = normalizePrinterChoice(selection.first);
                    if (nextPrinter == selectedPrinter) {
                      return;
                    }
                    setState(() {
                      _batchPrinter = nextPrinter;
                      if (nextPrinter == 'godex') {
                        _batchPrintMode = 'label';
                      }
                    });
                    _scheduleSaveControlPrefs();
                  },
                ),
              ),
            ),
            if (selectedPrinter == 'godex') ...[
              const SizedBox(height: 8),
              const _MiniIconRow(
                icon: Icons.info_outline_rounded,
                text: 'GoDEX faqat yorliq chop etadi, RFID kodlamaydi.',
              ),
            ],
            const SizedBox(height: 10),
            IgnorePointer(
              ignoring: printerLocked || selectedPrinter == 'godex',
              child: Opacity(
                opacity: printerLocked || selectedPrinter == 'godex' ? 0.6 : 1,
                child: SegmentedButton<String>(
                  style: _segmentStyle(context),
                  segments: const [
                    ButtonSegment<String>(
                      value: 'rfid',
                      label: Text('RFID'),
                      icon: Icon(Icons.memory_rounded),
                    ),
                    ButtonSegment<String>(
                      value: 'label',
                      label: Text('Faqat yorliq'),
                      icon: Icon(Icons.local_printshop_outlined),
                    ),
                  ],
                  selected: <String>{_batchPrintMode},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    final nextMode = selection.first;
                    if (nextMode == _batchPrintMode) {
                      return;
                    }
                    setState(() {
                      _batchPrintMode = nextMode;
                    });
                    _scheduleSaveControlPrefs();
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _MiniIconRow(
              icon: Icons.hub_outlined,
              text: 'ERP batch/submit RS serverda, RPS faqat chop etadi.',
            ),
          ],
        ),
      ],
    );
  }
}
