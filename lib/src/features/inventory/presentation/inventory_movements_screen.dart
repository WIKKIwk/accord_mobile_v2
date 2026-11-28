import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/inventory/inventory_view_store.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/printing/session_bluetooth_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_animated_list_entry.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../shared/presentation/scanned_preparation_roll_notes.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../gscale/gscale_mobile_app.dart'
    show PrintDeviceSelection, showPrintDevicePicker;
import '../../material_taminotchi/presentation/widgets/material_state_locations_tab.dart';
import '../../material_taminotchi/presentation/widgets/material_sheet_action_style.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../material_taminotchi/presentation/widgets/raw_material_list_assignment.dart';
import '../../material_taminotchi/presentation/widgets/raw_material_order_assignment_section.dart';
import '../../preparation/models/preparation_history.dart';
import '../../preparation/models/preparation_models.dart' show preparationDisplay;
import '../../preparation/presentation/preparation_navigation.dart';
import '../../preparation/presentation/widgets/preparation_history_operation_card.dart';
import '../../preparation/presentation/preparation_production_paddon_picker.dart';
import '../../preparation/presentation/preparation_production_screen.dart';
import '../../shared/models/app_models.dart';
import '../../shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/localization/urdu_aware_text.dart';

part 'inventory_movements_screen__InventoryMovementsScreenState_methods_01.dart';
part 'inventory_movements_screen__InventoryMovementsScreenState_methods_02.dart';
part 'inventory_movements_screen__InventoryMovementsScreenState_methods_03.dart';
part 'inventory_movements_screen_widgets_part_01.dart';
part 'inventory_movements_screen_declarations_part_02.dart';
part 'inventory_movements_screen_models_part_03.dart';
part 'preparation_history_tab.dart';

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen>
    with SingleTickerProviderStateMixin {
  static const _preparationHistoryTabIndex = 2;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _paddonsSearchController =
      TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  late final TabController _tabs;
  late int _shownTabIndex;
  late final bool _hasMovementTabs;
  late final bool _hasPaddonTab;
  late bool _paddonTabVisited;
  final _materialPaddonsKey = GlobalKey<PreparationProductionScreenState>();
  bool _inventoryReadsStarted = false;
  int _paddonsRevision = 0;
  late final String _inventoryReadScope;
  InventoryViewLease<InventoryLocation>? _locationView;
  InventoryViewLease<InventoryAsset>? _assetView;
  final Map<String, InventoryViewLease<InventoryTransfer>> _transferViews = {};
  final Map<String, VoidCallback> _transferViewListeners = {};
  String _assetViewKey = '';
  int _assetsRequest = 0;
  int _assetMutationDepth = 0;
  final Set<String> _knownOrderAssignmentBarcodes = {};
  final Set<String> _loadingTransferDirections = {};
  final Map<String, String> _transferErrors = {};
  List<InventoryLocation> _locations = const [];
  List<InventoryAsset> _assets = const [];
  List<InventoryTransfer> _allIncoming = const [];
  List<InventoryTransfer> _allOutgoing = const [];
  List<InventoryTransfer> _incoming = const [];
  List<InventoryTransfer> _outgoing = const [];
  Map<String, RawMaterialListAssignment> _rawMaterialOrderAssignments =
      const {};
  String _selectedWarehouseId = '';
  InventoryStockUse? _stockUse;
  bool _hasStockUses = false;
  bool _loading = true;
  bool _assetsLoading = false;
  bool _warehouseFilterExpanded = false;
  String _error = '';
  final Set<String> _busyKeys = {};
  final Set<String> _selectedAssetKeys = {};
  final Set<String> _exitingAssetKeys = {};
  final Set<String> _enteringAssetKeys = {};
  final Set<String> _enteringTransferIds = {};
  int _selectedStateAssetCount = 0;
  bool _inventoryFabOpen = false;
  bool _pendingPaddonAttachment = false;
  bool _qrLookupOpen = false;
  int _qrLookupGeneration = 0;
  String _qrLookupStatus = 'QR kodni ramkaga keltiring';
  List<InventoryAsset> _qrScannedAssets = const [];
  final Set<String> _qrLookupBusyCodes = {};
  final GlobalKey<MaterialStateLocationsTabState> _materialStateLocationsKey =
      GlobalKey<MaterialStateLocationsTabState>();
  final _preparationHistoryTabKey =
      GlobalKey<_PreparationHistoryTabState>();

  void _updateInventory(VoidCallback update) => setState(update);

  @override
  void initState() {
    super.initState();
    _inventoryReadScope = currentSessionReadScope();
    final preparationTransfers = widget.preparationTransfers;
    _hasPaddonTab =
        _materialScoped && AppSession.instance.can('gscale.catalog.read');
    _hasMovementTabs = !_materialScoped ||
        AppSession.instance.can('inventory.movement.manage');
    final movementTabCount = _hasMovementTabs ? (_materialScoped ? 4 : 3) : 0;
    final openPaddons =
        _hasPaddonTab && (widget.openMaterialPaddons || !_hasMovementTabs);
    _tabs = TabController(
      length: movementTabCount + (_hasPaddonTab ? 1 : 0),
      vsync: this,
      initialIndex: openPaddons
          ? _paddonTabIndex
          : _preparationScoped && preparationTransfers != null
              ? preparationTransfers.openHistory
                  ? _preparationHistoryTabIndex
                  : _transferTabIndex
              : _assetsTabIndex,
    );
    _paddonTabVisited = openPaddons;
    _shownTabIndex = _tabs.index;
    _tabs.addListener(_handleInventoryTabChanged);
    if (!openPaddons) _startInventoryReads();
  }

  void _startInventoryReads() {
    if (!_hasMovementTabs || _inventoryReadsStarted) return;
    _inventoryReadsStarted = true;
    unawaited(_restoreWarehouseFilterAndLoad());
    unawaited(_loadPendingPaddonAttachment());
  }

  @override
  void dispose() {
    _locationView?.removeListener(_handleLocationViewChanged);
    _locationView?.dispose();
    _assetView?.removeListener(_handleAssetViewChanged);
    _assetView?.dispose();
    for (final entry in _transferViews.entries) {
      final listener = _transferViewListeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
      entry.value.dispose();
    }
    _tabs.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _paddonsSearchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<InventoryLocation> get _warehouseLocations => _locations
      .where((location) => location.isWarehouse && location.active)
      .toList(growable: false);

  List<InventoryLocation> get _stateLocations => _locations
      .where((location) => location.isState && location.active)
      .toList(growable: false);

  Set<String> get _assignedWarehouseNames =>
      (AppSession.instance.profile?.assignedWarehouses ?? const <String>[])
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet();

  bool get _isAdmin =>
      !_preparationScoped && AppSession.instance.canUseAdminComponents;

  bool get _materialScoped =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;
  bool get _preparationScoped =>
      AppSession.instance.profile?.role == UserRole.tayyorlovMasteri;

  int get _assetsTabIndex => 0;
  int get _paddonTabIndex => _hasMovementTabs ? 2 : 0;
  int get _transferTabIndex =>
      _materialScoped ? (_hasPaddonTab ? 3 : 2) : 1;
  bool get _showMaterialPaddons => _hasPaddonTab && _tabs.index == _paddonTabIndex;

  bool get _showPreparationHistory =>
      _preparationScoped && _tabs.index == _preparationHistoryTabIndex;

  bool get _stateSelectionMode => _selectedStateAssetCount > 0;

  bool get _selectionMode =>
      _selectedAssetKeys.isNotEmpty || _stateSelectionMode;

  int get _selectionCount => _stateSelectionMode
      ? _selectedStateAssetCount
      : _selectedAssetKeys.length;

  List<InventoryAsset> get _selectionAssets =>
      _qrLookupOpen ? _qrScannedAssets : _assets;

  List<InventoryAsset> get _selectedAssets => _selectionAssets
      .where((asset) => _selectedAssetKeys.contains(_selectionKey(asset)))
      .toList(growable: false);

  List<InventoryAsset> get _selectedLinkedRawMaterialAssets => _selectedAssets
      .where(
        (asset) =>
            asset.kind == InventoryAssetKind.rawMaterial &&
            _rawMaterialOrderAssignments.containsKey(
              rawMaterialAssetBarcode(asset),
            ),
      )
      .toList(growable: false);

  bool get _selectionActionBusy =>
      _busyKeys.contains('relocate-batch') ||
      _busyKeys.contains('unlink-raw-material-batch');

  @override
  Widget build(BuildContext context) {
    final showHistory = _showPreparationHistory;
    final showPaddons = _showMaterialPaddons;
    final selectionMode = !showHistory && !showPaddons && _selectionMode;
    if (_tabs.length == 0) return const SizedBox.shrink();
    final selectedLinkedRawMaterials = _selectedLinkedRawMaterialAssets;
    final selectionActionBusy = _selectionActionBusy;
    final selectedAssets = _selectedAssets;
    final showPaddonAttachment = MobileApi.instance.canPackInventoryPaddon &&
        !_stateSelectionMode &&
        (_pendingPaddonAttachment ||
            ((_tabs.index == _assetsTabIndex || _qrLookupOpen) &&
                selectedAssets.isNotEmpty &&
                selectedAssets.every((asset) => asset.canSelectForPaddon)));
    final tabs = <Tab>[
      if (_hasMovementTabs)
        Tab(text: _preparationScoped ? 'Qoldiqlar' : 'Mahsulotlar'),
      if (_hasMovementTabs && _materialScoped) const Tab(text: 'State’lar'),
      if (_hasPaddonTab) const Tab(text: 'Paddonlar'),
      if (_preparationScoped)
        Tab(text: localizeUrduUiText('Kutilayotgan'))
      else if (_hasMovementTabs) ...[
        const Tab(text: 'Kiruvchi'),
        const Tab(text: 'Chiquvchi'),
      ],
      if (_preparationScoped) Tab(text: localizeUrduUiText('Tarix')),
    ];
    final tabViews = <Widget>[
      if (_hasMovementTabs) _movementTab(_buildAssetsTab),
      if (_hasMovementTabs && _materialScoped)
        _movementTab(
          () => MaterialStateLocationsTab(
            key: _materialStateLocationsKey,
            bottomPadding: MediaQuery.viewPaddingOf(context).bottom + 128,
            locations: _locations,
            onAssignmentsLoaded: (assets) {
              if (mounted) setState(() => _rememberAssetAssignments(assets));
            },
            onAssetsChanged: _applyAssetMutations,
            onAssetQrRequested: _showAssetQr,
            orderAssignments: _rawMaterialOrderAssignments,
            onOrderAssignmentChanged: _reloadOrderAssignments,
            onSelectionChanged: _handleStateSelectionChanged,
          ),
        ),
      if (_hasPaddonTab)
        if (_paddonTabVisited)
          PreparationProductionScreen.materialPaddonsTab(
            key: _materialPaddonsKey,
            paddonsTabActive: showPaddons,
            paddonsRevision: _paddonsRevision,
            paddonsSearchController: _paddonsSearchController,
            onPaddonsChanged: _refreshInventoryAfterPaddonChange,
          )
        else
          const SizedBox.shrink(),
      if (_preparationScoped)
        _movementTab(_buildPendingPreparationTransfersTab)
      else if (_hasMovementTabs) ...[
        _movementTab(() => _buildTransferTab('incoming')),
        _movementTab(() => _buildTransferTab('outgoing')),
      ],
      if (_preparationScoped)
        _movementTab(
          () => _PreparationHistoryTab(
            key: _preparationHistoryTabKey,
            scope: _inventoryReadScope,
            locations: _warehouseLocations,
            warehouseId: _selectedWarehouseId,
            query: _searchController.text,
            onWarehouseSelected: _selectWarehouse,
            onRefreshLocations: () async {
              await _locationView?.refresh();
            },
          ),
        ),
    ];
    return AppShell(
      animateOnEnter: false,
      title: _preparationScoped ? localizeUrduUiText('Transfer va tarix') : '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      showProfileAction: !selectionMode,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      actions: selectionMode
          ? [
              if (selectedLinkedRawMaterials.isNotEmpty)
                IconButton(
                  key: const ValueKey('inventory-selection-unlink'),
                  tooltip: 'Ulangan homashyolarni uzish '
                      '(${selectedLinkedRawMaterials.length} ta)',
                  onPressed:
                      selectionActionBusy ? null : _unlinkSelectedRawMaterials,
                  icon: _busyKeys.contains('unlink-raw-material-batch')
                      ? const AppLoadingIndicator(size: 24, glyphSize: 16)
                      : const Icon(Icons.link_off_rounded),
                ),
              IconButton(
                key: ValueKey(
                  _stateSelectionMode
                      ? 'material-state-selection-return'
                      : 'inventory-selection-relocate',
                ),
                tooltip: _stateSelectionMode
                    ? 'Omborga qaytarish'
                    : 'State’ga ko‘chirish',
                onPressed: selectionActionBusy ? null : _runSelectionAction,
                icon: _busyKeys.contains('relocate-batch')
                    ? const AppLoadingIndicator(size: 24, glyphSize: 16)
                    : Icon(
                        _stateSelectionMode
                            ? Icons.keyboard_return_rounded
                            : Icons.swap_horiz_rounded,
                      ),
              ),
            ]
          : null,
      titleWidget: selectionMode
              ? Row(
                  children: [
                    IconButton(
                      key: const ValueKey('inventory-selection-close'),
                      tooltip: 'Tanlashni bekor qilish',
                      onPressed: _clearSelection,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 4),
                    UrduAwareText(
                      '$_selectionCount ta tanlandi',
                      key: const ValueKey('inventory-selection-count'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                )
              : _buildInventorySearch(showPaddons),
      drawer: _preparationScoped
          ? const PreparationDrawer(
              selectedRouteName: AppRoutes.preparationTransfers)
          : _materialScoped
              ? MaterialTaminotchiNavigationDrawer(
                  selectedRouteName: AppRoutes.inventoryMovements,
                  onNavigate: _openDrawerRoute,
                )
              : null,
      bottom: _preparationScoped
          ? const PreparationDock(showPrimaryFab: false)
          : _materialScoped
              ? const MaterialTaminotchiDock(
                  activeTab: MaterialTaminotchiDockTab.home,
                )
              : null,
      contentPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              TabBar(
                controller: _tabs,
                isScrollable: _hasPaddonTab && _hasMovementTabs,
                tabAlignment: _hasPaddonTab && _hasMovementTabs
                    ? TabAlignment.start
                    : null,
                labelPadding: _preparationScoped || _hasPaddonTab
                    ? const EdgeInsets.symmetric(horizontal: 8)
                    : null,
                tabs: tabs,
              ),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Offstage(
                      offstage: _qrLookupOpen,
                      child: TabBarView(controller: _tabs, children: tabViews),
                    ),
                    if (_qrLookupOpen) _buildQrLookupPanel(),
                  ],
                ),
              ),
            ],
          ),
          if (!showHistory)
            PositionedDirectional(
              end: 16,
              bottom: 16,
              child: AdminFabActionMenu(
                key: const ValueKey('inventory-movements-fab'),
                open: _inventoryFabOpen,
                actions: showPaddons
                    ? _materialPaddonActions()
                    : [
                        if (showPaddonAttachment)
                          AdminFabMenuAction(
                            title: _pendingPaddonAttachment
                                ? 'Biriktirish natijasini tekshirish'
                                : 'Paddonga biriktirish',
                            icon: Icons.inventory_2_outlined,
                            onTap: _attachSelectedInventoryRolls,
                          ),
                        AdminFabMenuAction(
                          title: 'QR orqali izlash',
                          icon: Icons.qr_code_scanner_rounded,
                          onTap: _openQrLookup,
                        ),
                      ],
                onToggle: () {
                  setState(() => _inventoryFabOpen = !_inventoryFabOpen);
                },
                closedLabel: showPaddons ? 'Paddon amallari' : 'Amallar',
                openLabel: 'Yopish',
                closedIcon: Icons.add_rounded,
                openIcon: Icons.close_rounded,
              ),
            ),
        ],
      ),
    );
  }

  List<AdminFabMenuAction> _materialPaddonActions() => [
        if (AppSession.instance.can('gscale.print'))
          AdminFabMenuAction(
            title: 'Paddon qo‘shish',
            icon: Icons.inventory_2_outlined,
            onTap: () {
              setState(() => _inventoryFabOpen = false);
              _materialPaddonsKey.currentState?.addMaterialPaddon();
            },
          ),
        AdminFabMenuAction(
          title: 'Paddon QR skaneri',
          icon: Icons.qr_code_scanner_rounded,
          onTap: () {
            setState(() => _inventoryFabOpen = false);
            _materialPaddonsKey.currentState?.scanMaterialPaddon();
          },
        ),
      ];

  Widget _buildInventorySearch(bool showPaddons) {
    final controller =
        showPaddons ? _paddonsSearchController : _searchController;
    return AdminCatalogSearchField(
      controller: controller,
      focusNode: _searchFocusNode,
      hintText: showPaddons
          ? 'Paddon, partiya yoki xomashyo'
          : 'Mahsulot, kod yoki QR qidirish',
      onChanged: _onInventorySearchChanged,
      onClear: () {
        controller.clear();
        _onInventorySearchChanged('');
      },
      onBack: _goBack,
    );
  }

  void _onInventorySearchChanged(String value) {
    if (_showMaterialPaddons) return;
    _onSearchChanged(value);
    _materialStateLocationsKey.currentState?.handleItemsSearchChanged(value);
  }

  Widget _movementTab(Widget Function() build) {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error.isNotEmpty) {
      return _InventoryErrorState(message: _error, onRetry: _loadAll);
    }
    return build();
  }
}
