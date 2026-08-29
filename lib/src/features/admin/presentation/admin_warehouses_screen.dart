import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/session/session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../material_taminotchi/presentation/widgets/material_state_locations_tab.dart';
import '../../shared/models/app_models.dart';
import '../../shared/models/inventory_movement_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'dart:async';
import 'package:flutter/material.dart';

part 'admin_warehouses_screen__AdminWarehousesScreenState_methods_01.dart';
part 'admin_warehouses_screen__WarehouseDetailsTabState_methods_02.dart';
part 'admin_warehouses_screen__WarehouseSettingsTabState_methods_03.dart';
part 'admin_warehouses_screen_widgets_part_01.dart';
part 'admin_warehouses_screen_declarations_part_02.dart';
part 'admin_warehouses_screen_declarations_part_03.dart';
part 'admin_warehouses_screen_models_part_04.dart';
part 'admin_warehouses_screen_helpers_part_05.dart';

const Duration _warehouseLiveReconnectInterval = Duration(seconds: 5);
const Duration _warehouseLiveRefreshDebounce = Duration(milliseconds: 250);

class _AdminWarehousesScreenState extends State<AdminWarehousesScreen>
    with SingleTickerProviderStateMixin {
  late Future<_WarehouseSummaryData> _future;
  late final TabController _pageTabController;
  StreamSubscription<Map<String, dynamic>>? _warehouseLiveSub;
  Timer? _warehouseLiveReconnectTimer;
  Timer? _warehouseLiveRefreshTimer;
  Future<_WarehouseInventorySection?>? _detailFuture;
  String? _selectedWarehouse;
  bool _warehouseFilterExpanded = false;
  bool _refreshing = false;
  bool _warehouseRefreshPending = false;
  bool _disposed = false;
  final TextEditingController _materialItemsSearchController =
      TextEditingController();
  final FocusNode _materialItemsSearchFocusNode = FocusNode();
  final GlobalKey<_WarehouseDetailsTabState> _warehouseDetailsKey =
      GlobalKey<_WarehouseDetailsTabState>();
  final GlobalKey<MaterialStateLocationsTabState> _materialStateLocationsKey =
      GlobalKey<MaterialStateLocationsTabState>();

  bool get _materialScoped =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;

  bool get _adminScoped => AppSession.instance.profile?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    _pageTabController = TabController(length: 2, vsync: this);
    _future = _load();
    _connectWarehouseLive();
  }

  @override
  void dispose() {
    _disposed = true;
    _warehouseLiveReconnectTimer?.cancel();
    _warehouseLiveRefreshTimer?.cancel();
    _warehouseLiveSub?.cancel();
    _materialItemsSearchController.dispose();
    _materialItemsSearchFocusNode.dispose();
    _pageTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialScoped = _materialScoped;
    return AppShell(
      drawer: materialScoped
          ? MaterialTaminotchiNavigationDrawer(
              selectedRouteName: AppRoutes.adminWarehouses,
              onNavigate: _openDrawerRoute,
            )
          : AdminNavigationDrawer(
              selectedIndex: 0,
              selectedRouteName: AppRoutes.adminWarehouses,
              onNavigate: _openDrawerRoute,
            ),
      title: materialScoped
          ? context.l10n.adminText('warehouse.my_locations')
          : context.l10n.adminText('label.warehouse'),
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _materialItemsSearchFocusNode,
      showProfileActionResolver: () => !_materialItemsSearchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _materialItemsSearchController,
        focusNode: _materialItemsSearchFocusNode,
        hintText: materialScoped
            ? context.l10n.adminText('warehouse.location_products_search')
            : context.l10n.adminText('warehouse.products_search'),
        onChanged: (value) {
          _warehouseDetailsKey.currentState?.handleItemsSearchChanged(value);
          _materialStateLocationsKey.currentState
              ?.handleItemsSearchChanged(value);
        },
        onClear: () {
          _materialItemsSearchController.clear();
          _warehouseDetailsKey.currentState?.handleItemsSearchChanged('');
          _materialStateLocationsKey.currentState?.handleItemsSearchChanged('');
        },
        onBack: _goBackFromSearch,
      ),
      bottom: materialScoped
          ? const MaterialTaminotchiDock()
          : AdminDock(
              activeTab: AdminDockTab.settings,
              primaryFabActions: [
                AdminFabMenuAction(
                  title: context.l10n.adminText('warehouse.create'),
                  icon: Icons.warehouse_outlined,
                  onTap: _openWarehouseCreateDialog,
                ),
              ],
            ),
      contentPadding: EdgeInsets.zero,
      child: FutureBuilder<_WarehouseSummaryData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: _reload);
          }
          final data = snapshot.data ?? _WarehouseSummaryData.empty;
          final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
          final productsTab = _WarehouseDetailsTab(
            key: _warehouseDetailsKey,
            summaries: data.sections,
            warehouse: _selectedWarehouse,
            detailFuture: _detailFuture,
            bottomPadding: bottomPadding,
            filterExpanded: _warehouseFilterExpanded,
            showQolipWarehouseProducts: _adminScoped,
            qolipWarehouseNames: data.qolipWarehouseNames,
            searchController: _materialItemsSearchController,
            onFilterToggle: () {
              setState(() {
                _warehouseFilterExpanded = !_warehouseFilterExpanded;
              });
            },
            onWarehouseChanged: _openWarehouseDetailByName,
            allowRawStockEdit: materialScoped,
            onRawStockChanged: _reload,
          );
          if (materialScoped) {
            return Column(
              children: [
                AdminSurfaceTabBar(
                  controller: _pageTabController,
                  tabs: [
                    Tab(
                      height: 38,
                      text: context.l10n.adminText(
                        'warehouse.tabs_warehouses',
                      ),
                    ),
                    Tab(
                      height: 38,
                      text: context.l10n.adminText('warehouse.tabs_states'),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _pageTabController,
                    children: [
                      productsTab,
                      MaterialStateLocationsTab(
                        key: _materialStateLocationsKey,
                        bottomPadding: bottomPadding,
                        onAssetReturned: _reload,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              AdminSurfaceTabBar(
                controller: _pageTabController,
                tabs: const [
                  Tab(height: 38, text: 'Mahsulotlar'),
                  Tab(height: 38, text: 'Sozlamalar'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _pageTabController,
                  children: [
                    productsTab,
                    _WarehouseSettingsTab(
                      summaries: data.sections,
                      warehouse: _selectedWarehouse,
                      bottomPadding: bottomPadding,
                      filterExpanded: _warehouseFilterExpanded,
                      onFilterToggle: () {
                        setState(() {
                          _warehouseFilterExpanded = !_warehouseFilterExpanded;
                        });
                      },
                      onWarehouseChanged: _openWarehouseDetailByName,
                      onChanged: _reload,
                      onDeleted: _handleWarehouseDeleted,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

const int _warehouseAssigneePageSize = 50;

class _WarehouseDetailsTabState extends State<_WarehouseDetailsTab> {
  static const int _pageSize = 80;
  static const double _loadMoreExtent = 420;

  final ScrollController _itemsScrollController = ScrollController();
  late final TextEditingController _itemsSearchController;
  late final bool _ownsItemsSearchController;
  Timer? _itemsSearchDebounce;
  List<AdminWarehouseStockItem> _items = const <AdminWarehouseStockItem>[];
  List<QolipProduct> _qolipProducts = const <QolipProduct>[];
  String _itemsQuery = '';
  bool _initialItemsLoading = false;
  bool _loadingMoreItems = false;
  bool _hasMoreItems = false;
  Object? _itemsError;
  int _itemsRequestGeneration = 0;
  String? _editingStockBarcode;

  bool get _isQolipWarehouse =>
      widget.showQolipWarehouseProducts &&
      (_isQolipWarehouseName(widget.warehouse) ||
          _warehouseNameMatches(widget.qolipWarehouseNames, widget.warehouse));

  @override
  void initState() {
    super.initState();
    _ownsItemsSearchController = widget.searchController == null;
    _itemsSearchController = widget.searchController ?? TextEditingController();
    _itemsScrollController.addListener(_handleItemsScroll);
    unawaited(_loadFirstItemsPage());
  }

  @override
  void didUpdateWidget(covariant _WarehouseDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIsQolipWarehouse = oldWidget.showQolipWarehouseProducts &&
        (_isQolipWarehouseName(oldWidget.warehouse) ||
            _warehouseNameMatches(
              oldWidget.qolipWarehouseNames,
              oldWidget.warehouse,
            ));
    final isQolipWarehouse = _isQolipWarehouse;
    if (oldWidget.warehouse != widget.warehouse ||
        oldIsQolipWarehouse != isQolipWarehouse) {
      _itemsSearchDebounce?.cancel();
      final queryToClear = _itemsSearchController.text;
      if (queryToClear.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _itemsSearchController.text == queryToClear) {
            _itemsSearchController.clear();
          }
        });
      }
      _itemsQuery = '';
      unawaited(_loadFirstItemsPage());
    }
  }

  @override
  void dispose() {
    _itemsSearchDebounce?.cancel();
    _itemsScrollController.removeListener(_handleItemsScroll);
    _itemsScrollController.dispose();
    if (_ownsItemsSearchController) {
      _itemsSearchController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.detailFuture;
    final selectedWarehouse = widget.warehouse?.trim() ?? '';
    final filter = _WarehouseFilterBar(
      selectedWarehouse: selectedWarehouse,
      warehouses: widget.summaries,
      expanded: widget.filterExpanded,
      onToggle: widget.onFilterToggle,
      onChanged: widget.onWarehouseChanged,
    );
    Widget buildScaffold(
      List<Widget> children, {
      List<Widget> leading = const [],
      ScrollController? controller,
    }) {
      return ColoredBox(
        color: AppTheme.shellStart(context),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(4, 4, 4, widget.bottomPadding),
          children: [
            ...leading,
            filter,
            ...children,
          ],
        ),
      );
    }

    if (widget.summaries.isEmpty) {
      return buildScaffold([
        SizedBox(height: 24),
        Center(child: Text(context.l10n.adminText('warehouse.empty'))),
      ]);
    }
    if (widget.warehouse == null ||
        widget.warehouse!.trim().isEmpty ||
        future == null) {
      return buildScaffold([
        SizedBox(height: 24),
        Center(child: Text(context.l10n.adminText('warehouse.no_selection'))),
      ]);
    }
    return FutureBuilder<_WarehouseInventorySection?>(
      future: future,
      builder: (context, snapshot) {
        final current = snapshot.data ??
            const _WarehouseInventorySection(
              rawStock: <AdminRawMaterialStockEntry>[],
              reservations: <AdminRawMaterialAssignment>[],
              apparatus: <AdminApparatus>[],
            );
        final availableRawStock = _availableRawStock(current.rawStock);
        final reservedRawStock = _reservedRawStock(current.rawStock);
        _WarehouseSummarySection? selectedSummary;
        for (final summary in widget.summaries) {
          if (summary.warehouse.trim().toLowerCase() ==
              selectedWarehouse.toLowerCase()) {
            selectedSummary = summary;
            break;
          }
        }
        final isQolipWarehouse = _isQolipWarehouse;
        final qolipProductGroups = isQolipWarehouse
            ? _groupAdminQolipProducts(_qolipProducts)
            : const <_AdminQolipProductGroup>[];
        final availableCount = isQolipWarehouse
            ? qolipProductGroups.length
            : selectedSummary?.productCount ??
                (_items.length + availableRawStock.length);
        final reservedCount = _bandTabEntryCount(
          reservedRawStock,
          current.reservations,
        );
        final availableChildren = <Widget>[
          if (widget.searchController == null)
            SearchBar(
              controller: _itemsSearchController,
              hintText: context.l10n.adminText('warehouse.products_search'),
              constraints: const BoxConstraints(minHeight: 54),
              padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                EdgeInsets.symmetric(horizontal: 16),
              ),
              leading: Icon(
                Icons.search_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              elevation: const WidgetStatePropertyAll<double>(0),
              onChanged: _handleItemsSearchChanged,
            ),
          if (_initialItemsLoading)
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Center(child: AppLoadingIndicator()),
            )
          else if (_itemsError != null && _items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadFirstItemsPage,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.adminText('action.retry')),
                ),
              ),
            )
          else if (isQolipWarehouse && qolipProductGroups.isNotEmpty)
            _AdminQolipProductListModule(groups: qolipProductGroups)
          else if (!isQolipWarehouse && _items.isNotEmpty)
            _WarehouseItemListModule(
              items: _items,
            )
          else if (isQolipWarehouse)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: Text(
                  context.l10n.adminText('warehouse.no_mold_products'),
                ),
              ),
            )
          else if (availableRawStock.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: Text(context.l10n.adminText('warehouse.no_products')),
              ),
            ),
          if (availableRawStock.isNotEmpty)
            _WarehouseRawStockListModule(
              stock: availableRawStock,
              canEdit: widget.allowRawStockEdit
                  ? (stock) => _canEditRawMaterialStock(
                        stock,
                        current.reservations,
                      )
                  : null,
              onEdit: widget.allowRawStockEdit
                  ? (stock) => unawaited(_editRawStock(stock))
                  : null,
              onQr: widget.allowRawStockEdit
                  ? (stock) => unawaited(_showRawStockQr(stock))
                  : null,
            ),
          if (_loadingMoreItems)
            const Padding(
              padding: EdgeInsets.all(14),
              child: AppLoadingIndicator(size: 48, glyphSize: 28),
            )
          else if (_itemsError != null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: _loadNextItemsPage,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.adminText('action.load_more')),
              ),
            )
          else if (_hasMoreItems)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.l10n.adminText('warehouse.load_more_hint'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ];
        final reservedChildren = <Widget>[
          if (current.reservations.isNotEmpty)
            _WarehouseReservationListModule(
              reservations: current.reservations,
              apparatus: current.apparatus,
            )
          else if (reservedRawStock.isNotEmpty)
            _WarehouseRawStockListModule(
              stock: reservedRawStock,
              onQr: widget.allowRawStockEdit
                  ? (stock) => unawaited(_showRawStockQr(stock))
                  : null,
            ),
        ];
        final hasReserved = reservedChildren.isNotEmpty;
        final stockTabs = <Tab>[
          Tab(
            height: 38,
            text: context.l10n.adminText(
              'warehouse.available',
              values: {'count': availableCount},
            ),
          ),
        ];
        final stockTabChildren = <List<Widget>>[availableChildren];
        if (hasReserved) {
          stockTabs.add(
            Tab(
              height: 38,
              text: context.l10n.adminText(
                'warehouse.reserved',
                values: {'count': reservedCount},
              ),
            ),
          );
          stockTabChildren.add(reservedChildren);
        }
        return DefaultTabController(
          key: ValueKey<String>(
            '${selectedWarehouse.toLowerCase()}:${stockTabs.length}',
          ),
          length: stockTabs.length,
          child: Builder(
            builder: (context) {
              final stockController = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: stockController,
                builder: (context, _) {
                  final selectedIndex =
                      stockController.index < stockTabChildren.length
                          ? stockController.index
                          : stockTabChildren.length - 1;
                  final visibleChildren = stockTabChildren[selectedIndex];
                  return buildScaffold([
                    const SizedBox(height: 8),
                    if (visibleChildren.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(
                          child: Text(
                            context.l10n.adminText('warehouse.no_products'),
                          ),
                        ),
                      )
                    else ...[
                      for (var index = 0;
                          index < visibleChildren.length;
                          index++) ...[
                        if (index > 0) const SizedBox(height: 16),
                        visibleChildren[index],
                      ],
                    ],
                  ],
                      leading: [
                        AdminSurfaceTabBar(
                          controller: stockController,
                          tabs: stockTabs,
                        ),
                      ],
                      controller:
                          selectedIndex == 0 ? _itemsScrollController : null);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _WarehouseSettingsTabState extends State<_WarehouseSettingsTab> {
  Future<List<AdminWarehouseAssignment>>? _assignmentsFuture;
  bool _assigning = false;
  String? _removingAssignmentKey;
  bool _deleting = false;

  String get _warehouse => widget.warehouse?.trim() ?? '';

  _WarehouseSummarySection? get _summary {
    final selected = _warehouse.toLowerCase();
    if (selected.isEmpty) {
      return null;
    }
    for (final summary in widget.summaries) {
      if (summary.warehouse.trim().toLowerCase() == selected) {
        return summary;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void didUpdateWidget(covariant _WarehouseSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warehouse != widget.warehouse) {
      _loadAssignments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final summary = _summary;
    final filter = _WarehouseFilterBar(
      selectedWarehouse: _warehouse,
      warehouses: widget.summaries,
      expanded: widget.filterExpanded,
      onToggle: widget.onFilterToggle,
      onChanged: widget.onWarehouseChanged,
    );
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(4, 4, 4, widget.bottomPadding),
        children: [
          filter,
          if (summary == null) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(context.l10n.adminText('warehouse.no_selection')),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.adminText('warehouse.summary'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _WarehouseSettingCount(
                      label: context.l10n.adminText('warehouse.items'),
                      value: summary.productCount,
                    ),
                    _WarehouseSettingCount(
                      label: context.l10n.adminText(
                        'warehouse.reserved_count',
                      ),
                      value: summary.reservedCount,
                    ),
                    _WarehouseSettingCount(
                      label: context.l10n.adminText('warehouse.assignments'),
                      value: summary.assignmentCount,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.adminText('warehouse.assigned_users'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<AdminWarehouseAssignment>>(
                      future: _assignmentsFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(child: AppLoadingIndicator()),
                          );
                        }
                        final assignments = snapshot.data ?? const [];
                        if (assignments.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              context.l10n.adminText(
                                'warehouse.no_assignments',
                              ),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final assignment in assignments)
                              Builder(
                                builder: (context) {
                                  final assignmentKey =
                                      _warehouseAssignmentKey(assignment);
                                  final removing =
                                      _removingAssignmentKey == assignmentKey;
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.person_outline),
                                    title: Text(
                                      assignment.displayName.trim().isEmpty
                                          ? assignment.principalRef
                                          : assignment.displayName,
                                    ),
                                    subtitle: Text(
                                      userRoleLabel(assignment.principalRole),
                                    ),
                                    trailing: removing
                                        ? const SizedBox.square(
                                            dimension: 24,
                                            child: AppLoadingIndicator(),
                                          )
                                        : IconButton(
                                            key: ValueKey(
                                              'warehouse-unassign-$assignmentKey',
                                            ),
                                            tooltip: context.l10n.adminText(
                                              'warehouse.unassign',
                                            ),
                                            onPressed: _removingAssignmentKey ==
                                                    null
                                                ? () =>
                                                    _unassignUser(assignment)
                                                : null,
                                            icon: const Icon(
                                              Icons.person_remove_outlined,
                                            ),
                                          ),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('warehouse-assign-user'),
                        onPressed: _assigning ? null : _assignUser,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(
                          context.l10n.adminText('warehouse.assign_user'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.adminText('warehouse.dangerous_action'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.adminText(
                        'warehouse.delete_cascade_warning',
                      ),
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('warehouse-delete-button'),
                        onPressed: _deleting ? null : _deleteWarehouse,
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          context.l10n.adminText('warehouse.delete_title'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
