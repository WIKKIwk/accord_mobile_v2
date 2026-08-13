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

const Duration _warehouseLiveReconnectInterval = Duration(seconds: 5);
const Duration _warehouseLiveRefreshDebounce = Duration(milliseconds: 250);

class AdminWarehousesScreen extends StatefulWidget {
  const AdminWarehousesScreen({super.key});

  @override
  State<AdminWarehousesScreen> createState() => _AdminWarehousesScreenState();
}

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

  Future<List<String>> _loadMaterialAssignedWarehouses() async {
    final profile = AppSession.instance.profile;
    final profileWarehouses = profile?.assignedWarehouses ?? const <String>[];
    if (profileWarehouses.isNotEmpty) {
      return _uniqueWarehouseNames(profileWarehouses);
    }
    final assignments = await MobileApi.instance.adminWarehouseAssignments();
    final profileRef = profile?.ref.trim().toLowerCase() ?? '';
    final displayName = profile?.displayName.trim().toLowerCase() ?? '';
    return _uniqueWarehouseNames(
      assignments
          .where((assignment) =>
              assignment.principalRole == UserRole.materialTaminotchi)
          .where((assignment) {
        final ref = assignment.principalRef.trim().toLowerCase();
        final name = assignment.displayName.trim().toLowerCase();
        return (profileRef.isNotEmpty && ref == profileRef) ||
            (displayName.isNotEmpty && name == displayName);
      }).map((assignment) => assignment.warehouse),
    );
  }

  bool _warehouseAllowed(String warehouse, List<String>? allowedWarehouses) {
    if (allowedWarehouses == null) {
      return true;
    }
    final normalized = warehouse.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    return allowedWarehouses.any(
      (item) => item.trim().toLowerCase() == normalized,
    );
  }

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

  Future<_WarehouseSummaryData> _load() async {
    final summariesFuture = MobileApi.instance.adminWarehouseSummaries(
      limit: 500,
    );
    final allowedWarehousesFuture = _materialScoped
        ? _loadMaterialAssignedWarehouses()
        : Future<List<String>?>.value(null);
    final qolipAssignmentsFuture = _adminScoped
        ? MobileApi.instance.adminWarehouseAssignments()
        : Future<List<AdminWarehouseAssignment>>.value(
            const <AdminWarehouseAssignment>[],
          );
    final summaries = await summariesFuture;
    final allowedWarehouses = await allowedWarehousesFuture;
    final qolipAssignments = await qolipAssignmentsFuture;
    return _WarehouseSummaryData(
      qolipWarehouseNames: _uniqueWarehouseNames(
        qolipAssignments
            .where(
              (assignment) => assignment.principalRole == UserRole.qolipchi,
            )
            .map((assignment) => assignment.warehouse),
      ),
      sections: summaries
          .where((item) => _warehouseAllowed(item.warehouse, allowedWarehouses))
          .map(
            (item) => _WarehouseSummarySection(
              warehouse: item.warehouse,
              productCount: item.productCount,
              reservedCount: item.reservedCount,
              assignmentCount: item.assignmentCount,
              assignedDisplayNames: item.assignedDisplayNames,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<_WarehouseInventorySection?> _loadDetail(String warehouse) async {
    final allowedWarehouses =
        _materialScoped ? await _loadMaterialAssignedWarehouses() : null;
    if (!_warehouseAllowed(warehouse, allowedWarehouses)) {
      return null;
    }
    final results = await Future.wait([
      MobileApi.instance.adminRawMaterialAssignments(),
      MobileApi.instance.adminRawMaterialStock(
        warehouse: warehouse,
        limit: 500,
      ),
      MobileApi.instance.inventoryLocations(),
    ]);
    final allReservations = results[0] as List<AdminRawMaterialAssignment>;
    final rawStock = results[1] as List<AdminRawMaterialStockEntry>;
    if (rawStock.isEmpty) {
      return const _WarehouseInventorySection(
        rawStock: <AdminRawMaterialStockEntry>[],
        reservations: <AdminRawMaterialAssignment>[],
      );
    }
    final locations = results[2] as List<InventoryLocation>;
    final warehouseLocations = locations.where(
      (location) =>
          location.isWarehouse &&
          location.name.trim().toLowerCase() == warehouse.trim().toLowerCase(),
    );
    if (warehouseLocations.isEmpty) {
      throw StateError('Inventory warehouse location not found: $warehouse');
    }
    final warehouseLocation = warehouseLocations.first;
    final inventoryAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: warehouseLocation.warehouseId,
      assetKind: InventoryAssetKind.rawMaterial,
      limit: 500,
    );
    final physicalRawMaterialRefs = inventoryAssets
        .where(
          (asset) =>
              asset.physicalLocation.kind == InventoryLocationKind.warehouse &&
              asset.physicalLocation.id == warehouseLocation.id,
        )
        .map((asset) => asset.assetRef.trim().toLowerCase())
        .where((assetRef) => assetRef.isNotEmpty)
        .toSet();
    final warehouseRawStock = rawStock
        .where(
          (stock) =>
              physicalRawMaterialRefs.contains(stock.id.trim().toLowerCase()),
        )
        .toList(growable: false);
    final stockBarcodes = warehouseRawStock
        .map((item) => item.barcode.trim().toLowerCase())
        .where((barcode) => barcode.isNotEmpty)
        .toSet();
    return _WarehouseInventorySection(
      rawStock: List<AdminRawMaterialStockEntry>.unmodifiable(
        warehouseRawStock,
      ),
      reservations: List<AdminRawMaterialAssignment>.unmodifiable(
        allReservations.where(
          (item) => stockBarcodes.contains(item.barcode.trim().toLowerCase()),
        ),
      ),
    );
  }

  Future<void> _reload() async {
    final stateReload = _materialStateLocationsKey.currentState?.reload();
    setState(() {
      _future = _load();
      final selected = _selectedWarehouse?.trim() ?? '';
      if (selected.isNotEmpty) {
        _detailFuture = _loadDetail(selected);
      }
    });
    await _future;
    await stateReload;
  }

  Future<void> _handleWarehouseDeleted() async {
    setState(() {
      _selectedWarehouse = null;
      _detailFuture = null;
      _warehouseFilterExpanded = false;
      _future = _load();
    });
    await _future;
  }

  Future<void> _refreshInPlace() async {
    if (_refreshing || !mounted) {
      return;
    }
    _refreshing = true;
    try {
      while (_warehouseRefreshPending && mounted) {
        _warehouseRefreshPending = false;
        _warehouseLiveRefreshTimer?.cancel();
        _warehouseLiveRefreshTimer = null;
        final nextFuture = _load();
        setState(() {
          _future = nextFuture;
        });
        try {
          await nextFuture;
        } catch (_) {
          // FutureBuilder ko‘rsatadi; background refresh exceptioni UI threadni yiqitmasin.
        }
      }
    } finally {
      _refreshing = false;
    }
  }

  void _scheduleWarehouseRefresh() {
    if (_disposed || !mounted) {
      return;
    }
    _warehouseRefreshPending = true;
    _warehouseLiveRefreshTimer?.cancel();
    _warehouseLiveRefreshTimer = Timer(_warehouseLiveRefreshDebounce, () {
      _warehouseLiveRefreshTimer = null;
      unawaited(_refreshInPlace());
    });
  }

  Future<void> _connectWarehouseLive() async {
    if (_disposed ||
        _materialScoped ||
        await TestModeController.instance.isEnabled() ||
        !mounted) {
      return;
    }
    await _warehouseLiveSub?.cancel();
    _warehouseLiveSub = MobileApi.instance.adminWarehouseLiveEvents().listen(
      (event) {
        if (event['event'] == 'warehouse.updated') {
          _scheduleWarehouseRefresh();
        }
      },
      onError: (_) => _scheduleWarehouseLiveReconnect(),
      onDone: _scheduleWarehouseLiveReconnect,
    );
  }

  void _scheduleWarehouseLiveReconnect() {
    if (_disposed || !mounted || _warehouseLiveReconnectTimer != null) {
      return;
    }
    _warehouseLiveReconnectTimer = Timer(_warehouseLiveReconnectInterval, () {
      _warehouseLiveReconnectTimer = null;
      _connectWarehouseLive();
    });
  }

  void _openDrawerRoute(String routeName) {
    if (routeName == AppRoutes.adminWarehouses) {
      Navigator.of(context).pop();
      return;
    }
    if (_materialScoped) {
      Navigator.of(context).pushReplacementNamed(routeName);
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _openWarehouseDetailByName(String warehouse) {
    final normalized = warehouse.trim();
    setState(() {
      _selectedWarehouse = normalized;
      _warehouseFilterExpanded = false;
      _detailFuture = _loadDetail(normalized);
    });
  }

  void _goBackFromSearch() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed(
      _materialScoped ? AppRoutes.materialHome : AppRoutes.adminHome,
    );
  }

  Future<void> _openWarehouseCreateDialog() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: _WarehouseCreateCard(
            onSaved: _reload,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        );
      },
    );
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

class _WarehouseSummaryData {
  const _WarehouseSummaryData({
    required this.sections,
    this.qolipWarehouseNames = const <String>[],
  });

  static const empty = _WarehouseSummaryData(sections: []);

  final List<_WarehouseSummarySection> sections;
  final List<String> qolipWarehouseNames;
}

class _WarehouseSummarySection {
  const _WarehouseSummarySection({
    required this.warehouse,
    required this.productCount,
    required this.reservedCount,
    required this.assignmentCount,
    required this.assignedDisplayNames,
  });

  final String warehouse;
  final int productCount;
  final int reservedCount;
  final int assignmentCount;
  final List<String> assignedDisplayNames;
}

class _WarehouseInventorySection {
  const _WarehouseInventorySection({
    required this.rawStock,
    required this.reservations,
  });

  final List<AdminRawMaterialStockEntry> rawStock;
  final List<AdminRawMaterialAssignment> reservations;
}

const int _warehouseAssigneePageSize = 50;

Future<List<AdminUserListEntry>> _loadWarehouseUserPages({
  required String role,
}) async {
  final items = <AdminUserListEntry>[];
  var offset = 0;
  while (true) {
    final page = await MobileApi.instance.adminUserList(
      role: role,
      limit: _warehouseAssigneePageSize,
      offset: offset,
    );
    items.addAll(page.items);
    if (!page.hasMore) {
      return items;
    }
    if (page.items.isEmpty) {
      throw StateError('Warehouse assignee pagination did not advance');
    }
    offset += page.items.length;
  }
}

Future<List<AdminUserListEntry>> _loadWarehouseAssigneeUsers() async {
  final results = await Future.wait<Object>([
    _loadWarehouseUserPages(role: 'werka'),
    _loadWarehouseUserPages(role: 'qolipchi'),
    _loadWarehouseUserPages(role: 'material_taminotchi'),
    _loadWarehouseUserPages(role: 'worker'),
    MobileApi.instance.adminRoleAssignments(),
  ]);
  final generalUsers = results[0] as List<AdminUserListEntry>;
  final qolipchiUsers = results[1] as List<AdminUserListEntry>;
  final materialUsers = results[2] as List<AdminUserListEntry>;
  final workers = results[3] as List<AdminUserListEntry>;
  final assignments = results[4] as List<AdminRoleAssignment>;
  final workerEntries = <AdminUserListEntry>[];
  for (final worker in workers) {
    final assignment = assignments
        .where((item) => item.principalRef.trim() == worker.id.trim())
        .where((item) =>
            item.principalRole == UserRole.qolipchi ||
            item.roleId.trim() == 'qolipchi')
        .cast<AdminRoleAssignment?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final isQolipchi = assignment?.principalRole == UserRole.qolipchi ||
        assignment?.roleId.trim() == 'qolipchi';
    final isBrigader = worker.roleLabel.trim().toLowerCase() == 'brigader';
    if (!isQolipchi && !isBrigader) {
      continue;
    }
    final role = isQolipchi ? UserRole.qolipchi : UserRole.aparatchi;
    workerEntries.add(AdminUserListEntry(
      id: worker.id,
      name: worker.name,
      phone: worker.phone,
      kind: role == UserRole.qolipchi
          ? AdminUserKind.qolipchi
          : AdminUserKind.worker,
      avatarUrl: worker.avatarUrl,
      principalRole: role,
      blocked: worker.blocked,
      roleLabelOverride: isQolipchi ? userRoleLabel(role) : 'Brigader',
    ));
  }
  final byKey = <String, AdminUserListEntry>{};
  for (final item in [
    ...generalUsers,
    ...qolipchiUsers,
    ...materialUsers,
    ...workerEntries,
  ].where((item) => !item.blocked).where(_isWarehouseAssigneeCandidate)) {
    final key = '${item.kind.name}:${item.id.trim().toLowerCase()}';
    byKey[key] = item;
  }
  return byKey.values.toList(growable: false)
    ..sort(
      (left, right) => left.name.toLowerCase().compareTo(
            right.name.toLowerCase(),
          ),
    );
}

bool _isWarehouseAssigneeCandidate(AdminUserListEntry user) {
  return user.kind == AdminUserKind.werka ||
      user.kind == AdminUserKind.materialTaminotchi ||
      user.kind == AdminUserKind.qolipchi ||
      user.principalRole == UserRole.werka ||
      user.principalRole == UserRole.materialTaminotchi ||
      user.principalRole == UserRole.qolipchi ||
      (user.kind == AdminUserKind.worker &&
          user.roleLabel.trim().toLowerCase() == 'brigader');
}

class _WarehouseCreateCard extends StatefulWidget {
  const _WarehouseCreateCard({
    required this.onSaved,
    required this.onClose,
  });

  final Future<void> Function() onSaved;
  final VoidCallback onClose;

  @override
  State<_WarehouseCreateCard> createState() => _WarehouseCreateCardState();
}

class _WarehouseCreateCardState extends State<_WarehouseCreateCard> {
  final TextEditingController _warehouseController = TextEditingController();
  Future<List<AdminUserListEntry>>? _usersFuture;
  AdminUserListEntry? _selectedUser;
  bool _loadingUsers = false;
  bool _saving = false;

  @override
  void dispose() {
    _warehouseController.dispose();
    super.dispose();
  }

  Future<List<AdminUserListEntry>> _loadUsers() {
    final current = _usersFuture;
    if (current != null) {
      return current;
    }
    final next = _loadWarehouseAssigneeUsers();
    _usersFuture = next;
    return next;
  }

  Future<void> _save() async {
    final warehouse = _warehouseController.text.trim();
    if (warehouse.isEmpty || _selectedUser == null || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminCreateWarehouse(warehouse);
      await MobileApi.instance.adminAssignWarehouse(
        warehouse: warehouse,
        principalRole: _roleForUser(_selectedUser!),
        principalRef: _selectedUser!.id,
        displayName: _selectedUser!.name,
      );
      _warehouseController.clear();
      if (mounted) {
        setState(() => _selectedUser = null);
      }
      await widget.onSaved();
      if (mounted) {
        widget.onClose();
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openUserPicker() async {
    if (_loadingUsers) {
      return;
    }
    setState(() => _loadingUsers = true);
    late final List<AdminUserListEntry> users;
    try {
      users = await _loadUsers();
    } catch (_) {
      if (mounted) {
        _usersFuture = null;
        setState(() => _loadingUsers = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.adminText('warehouse.users_load_failed'),
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _loadingUsers = false);
    if (users.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l10n.adminText('warehouse.no_users')),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<AdminUserListEntry>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3PickerSheet<AdminUserListEntry>(
          title: context.l10n.adminText('warehouse.assign_to'),
          hintText: context.l10n.adminText('warehouse.user_search'),
          items: users,
          itemTitle: (item) => item.name,
          itemSubtitle: (item) => item.roleLabel,
          matchesQuery: (item, query) => searchMatches(query, [
            item.name,
            item.phone,
            item.id,
            item.roleLabel,
          ]),
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedUser = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.adminText('warehouse.create'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: context.l10n.adminText('action.close'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _warehouseController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: context.l10n.adminText('warehouse.name'),
                ),
              ),
              const SizedBox(height: 12),
              _AssignUserPickerField(
                user: _selectedUser,
                loading: _loadingUsers,
                onTap: _openUserPicker,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: Text(context.l10n.adminText('warehouse.assign')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignUserPickerField extends StatelessWidget {
  const _AssignUserPickerField({
    required this.user,
    required this.loading,
    required this.onTap,
  });

  final AdminUserListEntry? user;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: appSurfaceInputDecoration(
          context,
          labelText: context.l10n.adminText('warehouse.assign_to'),
          prefixIcon: const Icon(Icons.person_search_rounded),
          suffixIcon: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(Icons.expand_more_rounded),
        ),
        child: user == null
            ? Text(
                loading
                    ? context.l10n.adminText('action.loading')
                    : context.l10n.adminText('warehouse.pick_user'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user!.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    user!.roleLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _WarehouseDetailsTab extends StatefulWidget {
  const _WarehouseDetailsTab({
    super.key,
    required this.summaries,
    required this.warehouse,
    required this.detailFuture,
    required this.bottomPadding,
    required this.filterExpanded,
    required this.showQolipWarehouseProducts,
    required this.qolipWarehouseNames,
    this.searchController,
    required this.onFilterToggle,
    required this.onWarehouseChanged,
    this.allowRawStockEdit = false,
    this.onRawStockChanged,
  });

  final List<_WarehouseSummarySection> summaries;
  final String? warehouse;
  final Future<_WarehouseInventorySection?>? detailFuture;
  final double bottomPadding;
  final bool filterExpanded;
  final bool showQolipWarehouseProducts;
  final List<String> qolipWarehouseNames;
  final TextEditingController? searchController;
  final VoidCallback onFilterToggle;
  final ValueChanged<String> onWarehouseChanged;
  final bool allowRawStockEdit;
  final Future<void> Function()? onRawStockChanged;

  @override
  State<_WarehouseDetailsTab> createState() => _WarehouseDetailsTabState();
}

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

  void _handleItemsSearchChanged(String value) {
    _itemsSearchDebounce?.cancel();
    _itemsSearchDebounce = Timer(const Duration(milliseconds: 220), () {
      _itemsQuery = value.trim();
      unawaited(_loadFirstItemsPage());
    });
  }

  void handleItemsSearchChanged(String value) {
    _handleItemsSearchChanged(value);
  }

  Future<void> _editRawStock(AdminRawMaterialStockEntry stock) async {
    final barcode = stock.barcode.trim();
    if (!widget.allowRawStockEdit ||
        barcode.isEmpty ||
        _editingStockBarcode != null) {
      return;
    }
    setState(() => _editingStockBarcode = barcode);
    try {
      final result = await showModalBottomSheet<_RawMaterialStockEditResult>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) => _RawMaterialStockEditSheet(stock: stock),
      );
      if (result == null || !mounted) {
        return;
      }
      await MobileApi.instance.adminUpdateRawMaterialStock(
        barcode: stock.barcode,
        itemCode: result.item.code,
        qty: result.qty,
      );
      await widget.onRawStockChanged?.call();
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText('warehouse.raw_material_updated'),
        );
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showWarehouseNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText('warehouse.raw_material_edit_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _editingStockBarcode = null);
      }
    }
  }

  Future<void> _showRawStockQr(AdminRawMaterialStockEntry stock) async {
    if (!widget.allowRawStockEdit || stock.barcode.trim().isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) => _RawMaterialStockQrSheet(stock: stock),
    );
  }

  void _handleItemsScroll() {
    if (!_itemsScrollController.hasClients ||
        _initialItemsLoading ||
        _loadingMoreItems ||
        !_hasMoreItems) {
      return;
    }
    if (_itemsScrollController.position.extentAfter <= _loadMoreExtent) {
      unawaited(_loadNextItemsPage());
    }
  }

  Future<void> _loadFirstItemsPage() async {
    final warehouse = widget.warehouse?.trim() ?? '';
    final generation = ++_itemsRequestGeneration;
    if (_itemsScrollController.hasClients) {
      _itemsScrollController.jumpTo(0);
    }
    if (mounted) {
      setState(() {
        _items = const <AdminWarehouseStockItem>[];
        _qolipProducts = const <QolipProduct>[];
        _initialItemsLoading = warehouse.isNotEmpty;
        _loadingMoreItems = false;
        _hasMoreItems = false;
        _itemsError = null;
      });
    }
    if (warehouse.isEmpty) {
      return;
    }
    if (_isQolipWarehouse) {
      await _fetchQolipProducts(generation: generation);
      return;
    }
    await _fetchItemsPage(
      warehouse: warehouse,
      offset: 0,
      replace: true,
      generation: generation,
    );
  }

  Future<void> _loadNextItemsPage() async {
    if (_initialItemsLoading || _loadingMoreItems || !_hasMoreItems) {
      return;
    }
    final warehouse = widget.warehouse?.trim() ?? '';
    if (warehouse.isEmpty) {
      return;
    }
    final generation = _itemsRequestGeneration;
    setState(() {
      _loadingMoreItems = true;
      _itemsError = null;
    });
    await _fetchItemsPage(
      warehouse: warehouse,
      offset: _items.length,
      replace: false,
      generation: generation,
    );
  }

  Future<void> _fetchItemsPage({
    required String warehouse,
    required int offset,
    required bool replace,
    required int generation,
  }) async {
    final query = _itemsQuery;
    try {
      final page = await MobileApi.instance.adminWarehouseItemsPage(
        warehouse: warehouse,
        query: query,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted ||
          generation != _itemsRequestGeneration ||
          query != _itemsQuery ||
          warehouse != (widget.warehouse?.trim() ?? '')) {
        return;
      }
      setState(() {
        _items = replace ? page : <AdminWarehouseStockItem>[..._items, ...page];
        _initialItemsLoading = false;
        _loadingMoreItems = false;
        _hasMoreItems = page.length == _pageSize;
        _itemsError = null;
      });
    } catch (error) {
      if (!mounted || generation != _itemsRequestGeneration) {
        return;
      }
      setState(() {
        _initialItemsLoading = false;
        _loadingMoreItems = false;
        _itemsError = error;
      });
    }
  }

  Future<void> _fetchQolipProducts({required int generation}) async {
    final query = _itemsQuery;
    try {
      final products = await MobileApi.instance.qolipProducts(
        query: query,
        limit: 20000,
        withQolipOnly: true,
      );
      if (!mounted ||
          generation != _itemsRequestGeneration ||
          query != _itemsQuery ||
          !_isQolipWarehouse) {
        return;
      }
      setState(() {
        _qolipProducts = products;
        _initialItemsLoading = false;
        _loadingMoreItems = false;
        _hasMoreItems = false;
        _itemsError = null;
      });
    } catch (error) {
      if (!mounted || generation != _itemsRequestGeneration) {
        return;
      }
      setState(() {
        _qolipProducts = const <QolipProduct>[];
        _initialItemsLoading = false;
        _loadingMoreItems = false;
        _hasMoreItems = false;
        _itemsError = error;
      });
    }
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

class _WarehouseSettingsTab extends StatefulWidget {
  const _WarehouseSettingsTab({
    required this.summaries,
    required this.warehouse,
    required this.bottomPadding,
    required this.filterExpanded,
    required this.onFilterToggle,
    required this.onWarehouseChanged,
    required this.onChanged,
    required this.onDeleted,
  });

  final List<_WarehouseSummarySection> summaries;
  final String? warehouse;
  final double bottomPadding;
  final bool filterExpanded;
  final VoidCallback onFilterToggle;
  final ValueChanged<String> onWarehouseChanged;
  final Future<void> Function() onChanged;
  final Future<void> Function() onDeleted;

  @override
  State<_WarehouseSettingsTab> createState() => _WarehouseSettingsTabState();
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

  void _loadAssignments() {
    final warehouse = _warehouse;
    _assignmentsFuture = warehouse.isEmpty
        ? null
        : MobileApi.instance.adminWarehouseAssignments(
            warehouse: warehouse,
          );
  }

  Future<void> _refreshAssignments() async {
    setState(_loadAssignments);
    await _assignmentsFuture;
  }

  Future<void> _assignUser() async {
    if (_warehouse.isEmpty || _assigning) {
      return;
    }
    setState(() => _assigning = true);
    late final List<AdminUserListEntry> users;
    try {
      final results = await Future.wait<Object>([
        _loadWarehouseAssigneeUsers(),
        MobileApi.instance.adminWarehouseAssignments(warehouse: _warehouse),
      ]);
      final candidates = results[0] as List<AdminUserListEntry>;
      final assignments = results[1] as List<AdminWarehouseAssignment>;
      final assignedPrincipalKeys = assignments
          .map(
            (assignment) => _warehousePrincipalKey(
              assignment.principalRole,
              assignment.principalRef,
            ),
          )
          .toSet();
      users = candidates
          .where(
            (user) => !assignedPrincipalKeys.contains(
              _warehousePrincipalKey(_roleForUser(user), user.id),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText('warehouse.users_load_failed'),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _assigning = false);
      }
    }
    if (!mounted) {
      return;
    }
    if (users.isEmpty) {
      _showWarehouseNotice(
        context,
        context.l10n.adminText('warehouse.all_assigned'),
      );
      return;
    }
    final picked = await showModalBottomSheet<AdminUserListEntry>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3PickerSheet<AdminUserListEntry>(
          title: context.l10n.adminText('warehouse.assign_to'),
          hintText: context.l10n.adminText('warehouse.user_search'),
          items: users,
          itemTitle: (item) => item.name,
          itemSubtitle: (item) => item.roleLabel,
          matchesQuery: (item, query) => searchMatches(query, [
            item.name,
            item.phone,
            item.id,
            item.roleLabel,
          ]),
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _assigning = true);
    try {
      await MobileApi.instance.adminAssignWarehouse(
        warehouse: _warehouse,
        principalRole: _roleForUser(picked),
        principalRef: picked.id,
        displayName: picked.name,
      );
      await _refreshAssignments();
      await widget.onChanged();
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText(
            'warehouse.assigned_user_success',
            values: {'name': picked.name},
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText('warehouse.assign_user_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _assigning = false);
      }
    }
  }

  Future<void> _unassignUser(AdminWarehouseAssignment assignment) async {
    final assignmentKey = _warehouseAssignmentKey(assignment);
    if (_removingAssignmentKey != null) {
      return;
    }
    final displayName = assignment.displayName.trim().isEmpty
        ? assignment.principalRef.trim()
        : assignment.displayName.trim();
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: context.l10n.adminText('warehouse.unassign'),
      message: context.l10n.adminText(
        'warehouse.unassign_confirm',
        values: {'warehouse': _warehouse, 'displayName': displayName},
      ),
      cancelLabel: context.l10n.adminText('action.cancel'),
      confirmLabel: context.l10n.adminText('action.delete'),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _removingAssignmentKey = assignmentKey);
    try {
      await MobileApi.instance.adminUnassignWarehouse(
        warehouse: assignment.warehouse,
        principalRole: assignment.principalRole,
        principalRef: assignment.principalRef,
      );
      await _refreshAssignments();
      await widget.onChanged();
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText(
            'warehouse.unassigned_user_success',
            values: {'name': displayName},
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is MobileApiException
            ? error.message
            : context.l10n.adminText('warehouse.unassign_user_failed');
        _showWarehouseNotice(context, message);
      }
    } finally {
      if (mounted) {
        setState(() => _removingAssignmentKey = null);
      }
    }
  }

  Future<void> _deleteWarehouse() async {
    final summary = _summary;
    if (summary == null || _deleting) {
      return;
    }
    if (summary.reservedCount > 0) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        builder: (dialogContext) {
          final scheme = Theme.of(dialogContext).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.block_rounded, color: scheme.error),
            title: Text(
              dialogContext.l10n.adminText('warehouse.delete_blocked'),
            ),
            content: Text(
              dialogContext.l10n.adminText(
                'warehouse.delete_blocked_message',
                values: {
                  'warehouse': summary.warehouse,
                  'count': summary.reservedCount,
                },
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(dialogContext.l10n.adminText('action.close')),
              ),
            ],
          );
        },
      );
      return;
    }
    final confirmed = await _confirmWarehouseDeletion(summary);
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await MobileApi.instance.adminDeleteWarehouse(
        warehouse: summary.warehouse,
        deleteProducts: summary.productCount > 0,
      );
      await widget.onDeleted();
      if (mounted) {
        _showWarehouseNotice(
          context,
          context.l10n.adminText('warehouse.deleted'),
        );
      }
    } catch (error) {
      if (mounted) {
        _showWarehouseNotice(
          context,
          _warehouseDeleteErrorMessage(error, context.l10n),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<bool> _confirmWarehouseDeletion(
    _WarehouseSummarySection summary,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final hasProducts = summary.productCount > 0;
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          title: Text(dialogContext.l10n.adminText('warehouse.delete_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasProducts
                    ? dialogContext.l10n.adminText(
                        'warehouse.delete_products_warning',
                        values: {
                          'warehouse': summary.warehouse,
                          'count': summary.productCount,
                        },
                      )
                    : dialogContext.l10n.adminText(
                        'warehouse.delete_confirmation',
                        values: {'warehouse': summary.warehouse},
                      ),
              ),
              if (summary.assignmentCount > 0) ...[
                const SizedBox(height: 12),
                Text(
                  dialogContext.l10n.adminText(
                    'warehouse.delete_assignments_warning',
                    values: {'count': summary.assignmentCount},
                  ),
                ),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(
                        dialogContext.l10n.adminText('action.cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('warehouse-delete-confirm'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                      ),
                      child: Text(
                        dialogContext.l10n.adminText('action.delete'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
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

String _warehouseAssignmentKey(AdminWarehouseAssignment assignment) {
  return '${assignment.warehouse.trim().toLowerCase()}-'
      '${userRoleToJson(assignment.principalRole)}-'
      '${assignment.principalRef.trim().toLowerCase()}';
}

String _warehousePrincipalKey(UserRole role, String principalRef) {
  return '${userRoleToJson(role)}:${principalRef.trim().toLowerCase()}';
}

class _WarehouseSettingCount extends StatelessWidget {
  const _WarehouseSettingCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$value',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

void _showWarehouseNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _warehouseDeleteErrorMessage(
  Object error,
  AppLocalizations l10n,
) {
  if (error is MobileApiException) {
    return switch (error.code) {
      'warehouse_has_active_reservations' =>
        l10n.adminText('warehouse.delete_error_active'),
      'warehouse_has_children' =>
        l10n.adminText('warehouse.delete_error_children'),
      'warehouse_not_empty' =>
        l10n.adminText('warehouse.delete_error_not_empty'),
      'warehouse_not_found' => l10n.adminText(
          'warehouse.delete_error_not_found',
        ),
      _ => l10n.adminText('warehouse.delete_error'),
    };
  }
  return l10n.adminText('warehouse.delete_error');
}

class _WarehouseFilterBar extends StatelessWidget {
  const _WarehouseFilterBar({
    required this.selectedWarehouse,
    required this.warehouses,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final String selectedWarehouse;
  final List<_WarehouseSummarySection> warehouses;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedWarehouse.trim();
    return AdminExpandableFilterChip<String>(
      chipKey: const ValueKey('admin-warehouse-filter-chip'),
      label: context.l10n.adminText('label.warehouse'),
      emptyLabel: context.l10n.adminText('warehouse.unselected'),
      icon: Icons.warehouse_outlined,
      selectedValue: selected.isEmpty ? null : selected,
      expanded: expanded,
      onToggle: onToggle,
      onSelect: onChanged,
      optionKeyPrefix: 'admin-warehouse-option-chip',
      options: [
        for (final warehouse in warehouses)
          AdminFilterChipOption(
            value: warehouse.warehouse,
            label: warehouse.warehouse,
            key: ValueKey(
              'admin-warehouse-option-chip-${warehouse.warehouse}',
            ),
          ),
      ],
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
    );
  }
}

class _AdminQolipProductGroup {
  const _AdminQolipProductGroup({
    required this.code,
    required this.name,
    required this.itemGroup,
    required this.qolips,
  });

  final String code;
  final String name;
  final String itemGroup;
  final List<QolipProduct> qolips;
}

class _AdminQolipProductGroupBuilder {
  _AdminQolipProductGroupBuilder({
    required this.code,
    required this.name,
    required this.itemGroup,
  });

  final String code;
  final String name;
  final String itemGroup;
  final List<QolipProduct> qolips = [];
}

List<_AdminQolipProductGroup> _groupAdminQolipProducts(
  Iterable<QolipProduct> products,
) {
  final grouped = <String, _AdminQolipProductGroupBuilder>{};
  for (final product in products) {
    final code = product.code.trim();
    final name = product.name.trim();
    final key = code.isEmpty ? name.toLowerCase() : code.toLowerCase();
    if (key.isEmpty || product.qolipCode.trim().isEmpty) {
      continue;
    }
    final group = grouped.putIfAbsent(
      key,
      () => _AdminQolipProductGroupBuilder(
        code: code,
        name: name,
        itemGroup: product.itemGroup.trim(),
      ),
    );
    final qolipKey = product.qolipCode.trim().toLowerCase();
    if (!group.qolips.any(
      (item) => item.qolipCode.trim().toLowerCase() == qolipKey,
    )) {
      group.qolips.add(product);
    }
  }
  final groups = grouped.values
      .map(
        (group) => _AdminQolipProductGroup(
          code: group.code,
          name: group.name,
          itemGroup: group.itemGroup,
          qolips: List<QolipProduct>.unmodifiable(group.qolips),
        ),
      )
      .toList(growable: false)
    ..sort(
      (left, right) =>
          (left.name.isEmpty ? left.code : left.name).toLowerCase().compareTo(
                (right.name.isEmpty ? right.code : right.name).toLowerCase(),
              ),
    );
  return groups;
}

class _AdminQolipProductListModule extends StatelessWidget {
  const _AdminQolipProductListModule({required this.groups});

  final List<_AdminQolipProductGroup> groups;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      padding: EdgeInsets.zero,
      children: [
        for (var index = 0; index < groups.length; index++)
          _AdminQolipProductRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              groups.length,
            ),
            group: groups[index],
          ),
      ],
    );
  }
}

class _AdminQolipProductRow extends StatelessWidget {
  const _AdminQolipProductRow({required this.slot, required this.group});

  final M3SegmentVerticalSlot slot;
  final _AdminQolipProductGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = group.name.isEmpty ? group.code : group.name;
    final subtitle = <String>[
      if (group.code.isNotEmpty && group.code != title) group.code,
      '${group.qolips.length} ${context.l10n.adminText('label.item').toLowerCase()}',
      if (group.itemGroup.isNotEmpty) group.itemGroup,
    ].join(' • ');
    final details = <_WarehouseDetailEntry>[
      if (group.code.isNotEmpty)
        _WarehouseDetailEntry(
          context.l10n.adminText('label.item_code'),
          group.code,
        ),
      if (group.itemGroup.isNotEmpty)
        _WarehouseDetailEntry(
          context.l10n.adminText('label.group'),
          group.itemGroup,
        ),
      for (var index = 0; index < group.qolips.length; index++)
        _WarehouseDetailEntry(
          '${context.l10n.adminText('label.item')} ${index + 1}',
          _adminQolipDetail(group.qolips[index]),
        ),
    ];
    return _WarehouseExpandableSummaryCard(
      slot: slot,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.grid_view_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title,
      subtitle: subtitle,
      details: details,
    );
  }
}

String _adminQolipDetail(QolipProduct product) {
  final code = product.qolipCode.trim().isEmpty
      ? product.firstQolipCode.trim()
      : product.qolipCode.trim();
  return [
    if (code.isNotEmpty) code,
    if (product.qolipSize > 0) 'Razmer: ${product.qolipSize}',
    if (product.qolipColor.trim().isNotEmpty)
      'Rang: ${product.qolipColor.trim()}',
    product.isInUse ? 'Holati: Ishlatilmoqda' : 'Holati: Mavjud',
  ].join(' • ');
}

class _WarehouseItemListModule extends StatelessWidget {
  const _WarehouseItemListModule({required this.items});

  final List<AdminWarehouseStockItem> items;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      padding: EdgeInsets.zero,
      children: [
        for (var index = 0; index < items.length; index++)
          _WarehouseItemRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              items.length,
            ),
            item: items[index],
          ),
      ],
    );
  }
}

class _WarehouseItemRow extends StatelessWidget {
  const _WarehouseItemRow({required this.slot, required this.item});

  final M3SegmentVerticalSlot slot;
  final AdminWarehouseStockItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = item.name.trim().isEmpty ? item.code : item.name;
    final subtitle = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      '${_formatQty(item.onHandQty)} ${item.uom}'.trim(),
      if (item.itemGroup.trim().isNotEmpty) item.itemGroup.trim(),
    ].join(' • ');

    return _WarehouseExpandableSummaryCard(
      slot: slot,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title,
      subtitle: subtitle,
      details: [
        _WarehouseDetailEntry(
          context.l10n.adminText('label.code'),
          item.code,
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('warehouse.available_quantity'),
          '${_formatQty(item.onHandQty)} ${item.uom}'.trim(),
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('warehouse.packages'),
          '${item.packageCount}',
        ),
        if (item.itemGroup.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('label.group'),
            item.itemGroup,
          ),
        _WarehouseDetailEntry(
          context.l10n.adminText('label.warehouse'),
          item.warehouse,
        ),
      ],
    );
  }
}

class _WarehouseRawStockListModule extends StatelessWidget {
  const _WarehouseRawStockListModule({
    required this.stock,
    this.canEdit,
    this.onEdit,
    this.onQr,
  });

  final List<AdminRawMaterialStockEntry> stock;
  final bool Function(AdminRawMaterialStockEntry stock)? canEdit;
  final ValueChanged<AdminRawMaterialStockEntry>? onEdit;
  final ValueChanged<AdminRawMaterialStockEntry>? onQr;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      padding: EdgeInsets.zero,
      children: [
        for (var index = 0; index < stock.length; index++)
          _WarehouseRawStockRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              stock.length,
            ),
            stock: stock[index],
            onEdit: canEdit?.call(stock[index]) == true && onEdit != null
                ? () => onEdit!(stock[index])
                : null,
            onQr: onQr == null ? null : () => onQr!(stock[index]),
          ),
      ],
    );
  }
}

class _WarehouseRawStockRow extends StatelessWidget {
  const _WarehouseRawStockRow({
    required this.slot,
    required this.stock,
    this.onEdit,
    this.onQr,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialStockEntry stock;
  final VoidCallback? onEdit;
  final VoidCallback? onQr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = stock.itemName.trim().isEmpty
        ? stock.itemCode.trim()
        : stock.itemName.trim();
    final subtitle = <String>[
      if (stock.barcode.trim().isNotEmpty) stock.barcode.trim(),
      '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
    ].join(' • ');

    return _WarehouseExpandableSummaryCard(
      slot: slot,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.category_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title.isEmpty ? stock.barcode : title,
      subtitle: subtitle,
      details: [
        _WarehouseDetailEntry(
          context.l10n.adminText('label.item_code'),
          stock.itemCode,
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('label.barcode'),
          stock.barcode,
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('label.quantity'),
          '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('label.status'),
          _warehouseStockStatusLabel(stock.status, context.l10n),
        ),
        if (stock.reservedOrderId.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('label.reserved'),
            stock.reservedOrderId,
          ),
        if (stock.sourceReceiptId.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('label.receipt'),
            stock.sourceReceiptId,
          ),
      ],
      expandedFooter: onEdit == null && onQr == null
          ? null
          : Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onQr != null)
                    IconButton.filledTonal(
                      key: ValueKey('raw-stock-qr-${stock.barcode}'),
                      onPressed: onQr,
                      tooltip: context.l10n.adminText('warehouse.qr_view'),
                      icon: const Icon(Icons.qr_code_2_rounded),
                    ),
                  if (onQr != null && onEdit != null) const SizedBox(width: 8),
                  if (onEdit != null)
                    IconButton.filledTonal(
                      key: ValueKey('raw-stock-edit-${stock.barcode}'),
                      onPressed: onEdit,
                      tooltip: context.l10n.adminText('action.edit'),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
            ),
    );
  }
}

class _RawMaterialStockQrSheet extends StatefulWidget {
  const _RawMaterialStockQrSheet({required this.stock});

  final AdminRawMaterialStockEntry stock;

  @override
  State<_RawMaterialStockQrSheet> createState() =>
      _RawMaterialStockQrSheetState();
}

class _RawMaterialStockQrSheetState extends State<_RawMaterialStockQrSheet> {
  Future<String?> _reprint() async {
    final prepared = await MobileApi.instance
        .adminPrepareRawMaterialStockReprint(barcode: widget.stock.barcode);
    final expectedBarcode = widget.stock.barcode.trim().toUpperCase();
    if (prepared.reprintId.trim().isEmpty ||
        prepared.stock.barcode.trim().toUpperCase() != expectedBarcode ||
        prepared.stock.sourceReceiptId.trim() !=
            widget.stock.sourceReceiptId.trim() ||
        prepared.printRequest.epc.trim().toUpperCase() != expectedBarcode) {
      throw MobileApiException(
        code: 'raw_material_stock_reprint_identity_mismatch',
        message: context.l10n.adminText('warehouse.qr_identity_mismatch'),
      );
    }
    final result = await PrintService.printRps(prepared.printRequest);
    if (!result.ok) {
      throw StateError(context.l10n.adminText('warehouse.qr_printer_failed'));
    }
    try {
      await MobileApi.instance.adminConfirmRawMaterialStockReprint(
        barcode: prepared.stock.barcode,
        reprintId: prepared.reprintId,
      );
      return null;
    } catch (_) {
      return context.l10n.adminText('warehouse.qr_confirmation_failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final itemName = stock.itemName.trim().isEmpty
        ? stock.itemCode.trim()
        : stock.itemName.trim();
    return RpsQrReprintSheet(
      payload: stock.barcode,
      itemName: itemName,
      previewKey: ValueKey('raw-stock-qr-preview-${stock.barcode}'),
      reprintButtonKey: const ValueKey('raw-stock-qr-reprint'),
      details: [
        RpsQrDetail(
          context.l10n.adminText('label.receipt'),
          stock.sourceReceiptId,
        ),
        RpsQrDetail(
          'Miqdor',
          '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
        ),
      ],
      onReprint: _reprint,
      errorMessage: (error) => error is MobileApiException
          ? error.message
          : context.l10n.adminText('warehouse.qr_print_failed'),
    );
  }
}

class _RawMaterialStockEditResult {
  const _RawMaterialStockEditResult({
    required this.item,
    required this.qty,
  });

  final SupplierItem item;
  final double qty;
}

class _RawMaterialStockEditSheet extends StatefulWidget {
  const _RawMaterialStockEditSheet({required this.stock});

  final AdminRawMaterialStockEntry stock;

  @override
  State<_RawMaterialStockEditSheet> createState() =>
      _RawMaterialStockEditSheetState();
}

class _RawMaterialStockEditSheetState
    extends State<_RawMaterialStockEditSheet> {
  late final TextEditingController _qtyController;
  late SupplierItem _selectedItem;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: _formatQty(widget.stock.qty));
    _selectedItem = SupplierItem(
      code: widget.stock.itemCode,
      name: widget.stock.itemName.trim().isEmpty
          ? widget.stock.itemCode
          : widget.stock.itemName,
      uom: widget.stock.uom,
      warehouse: widget.stock.warehouse,
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showModalBottomSheet<SupplierItem>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) => M3AsyncPickerSheet<SupplierItem>(
        title: context.l10n.adminText('warehouse.product_select'),
        hintText: context.l10n.adminText('warehouse.product_search'),
        supportingText: context.l10n.adminText(
          'warehouse.raw_material_groups_only',
        ),
        pageSize: 80,
        loadPage: (query, offset, limit) => MobileApi.instance.adminItemsPage(
          query: query,
          offset: offset,
          limit: limit,
        ),
        itemTitle: (item) => item.name.trim().isEmpty ? item.code : item.name,
        itemSubtitle: (item) => [
          item.code,
          if (item.uom.trim().isNotEmpty) item.uom.trim(),
        ].join(' • '),
        onSelected: (item) => Navigator.of(context).pop(item),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedItem = picked;
        _errorText = null;
      });
    }
  }

  void _save() {
    final qty =
        double.tryParse(_qtyController.text.trim().replaceAll(',', '.'));
    if (_selectedItem.code.trim().isEmpty ||
        qty == null ||
        !qty.isFinite ||
        qty <= 0) {
      setState(
        () => _errorText = context.l10n.adminText(
          'warehouse.raw_material_quantity_required',
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      _RawMaterialStockEditResult(item: _selectedItem, qty: qty),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final itemName = _selectedItem.name.trim().isEmpty
        ? _selectedItem.code
        : _selectedItem.name;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: scheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.adminText(
                            'warehouse.raw_material_edit_title',
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: context.l10n.adminText('action.close'),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickItem,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: appSurfaceInputDecoration(
                        context,
                        labelText: context.l10n.adminText('material.name'),
                        prefixIcon: const Icon(Icons.science_outlined),
                        suffixIcon: const Icon(Icons.expand_more_rounded),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_selectedItem.code.trim().isNotEmpty)
                            Text(
                              _selectedItem.code.trim(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const ValueKey('raw-stock-edit-qty'),
                    controller: _qtyController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    decoration: appSurfaceInputDecoration(
                      context,
                      labelText: context.l10n.adminText(
                        'warehouse.incoming_quantity',
                      ),
                      prefixIcon: const Icon(Icons.scale_outlined),
                    ).copyWith(
                      suffixText: widget.stock.uom.trim(),
                      errorText: _errorText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 20,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.l10n.adminText(
                                'warehouse.stock_identity_note',
                                values: {
                                  'barcode': widget.stock.barcode,
                                  'receipt': widget.stock.sourceReceiptId,
                                },
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const ValueKey('raw-stock-edit-save'),
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(context.l10n.adminText('action.save')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarehouseReservationListModule extends StatelessWidget {
  const _WarehouseReservationListModule({required this.reservations});

  final List<AdminRawMaterialAssignment> reservations;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      padding: EdgeInsets.zero,
      children: [
        for (var index = 0; index < reservations.length; index++)
          _WarehouseReservationRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              reservations.length,
            ),
            reservation: reservations[index],
          ),
      ],
    );
  }
}

class _WarehouseReservationRow extends StatelessWidget {
  const _WarehouseReservationRow({
    required this.slot,
    required this.reservation,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialAssignment reservation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = reservation.itemName.trim().isEmpty
        ? reservation.itemCode
        : reservation.itemName;
    final subtitle = <String>[
      if (reservation.itemCode.trim().isNotEmpty &&
          reservation.itemCode.trim() != title.trim())
        reservation.itemCode.trim(),
      if (reservation.barcode.trim().isNotEmpty) reservation.barcode.trim(),
      if (reservation.itemGroup.trim().isNotEmpty) reservation.itemGroup.trim(),
    ].join(' • ');

    return _WarehouseExpandableSummaryCard(
      slot: slot,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title,
      subtitle: subtitle,
      details: [
        _WarehouseDetailEntry(
          context.l10n.adminText('calculate.order'),
          reservation.orderId,
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('label.code'),
          reservation.itemCode,
        ),
        _WarehouseDetailEntry(
          context.l10n.adminText('label.barcode'),
          reservation.barcode,
        ),
        if (reservation.itemGroup.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('label.group'),
            reservation.itemGroup,
          ),
        if (reservation.apparatus.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('label.apparatus'),
            reservation.apparatus,
          ),
        if (reservation.assignedByName.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('action.assign'),
            reservation.assignedByName,
          ),
        if (reservation.assignedAt.trim().isNotEmpty)
          _WarehouseDetailEntry(
            context.l10n.adminText('label.date'),
            reservation.assignedAt,
          ),
      ],
    );
  }
}

class _WarehouseDetailEntry {
  const _WarehouseDetailEntry(this.label, this.value);

  final String label;
  final String value;
}

class _WarehouseExpandableSummaryCard extends StatelessWidget {
  const _WarehouseExpandableSummaryCard({
    required this.slot,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.details,
    this.expandedFooter,
  });

  final M3SegmentVerticalSlot slot;
  final Widget leading;
  final String title;
  final String subtitle;
  final List<_WarehouseDetailEntry> details;
  final Widget? expandedFooter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      title: title,
      subtitle: subtitle,
      value: '',
      showChevron: true,
      onTap: () => _showWarehouseSummaryDetails(
        context,
        title: title,
        details: details,
        expandedFooter: expandedFooter,
      ),
      leading: leading,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
    );
  }
}

Future<void> _showWarehouseSummaryDetails(
  BuildContext context, {
  required String title,
  required List<_WarehouseDetailEntry> details,
  Widget? expandedFooter,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _WarehouseSummaryDetailsSheet(
      title: title,
      details: details,
      footer: expandedFooter,
    ),
  );
}

class _WarehouseSummaryDetailsSheet extends StatelessWidget {
  const _WarehouseSummaryDetailsSheet({
    required this.title,
    required this.details,
    this.footer,
  });

  final String title;
  final List<_WarehouseDetailEntry> details;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              for (final detail in details)
                _WarehouseDetailLine(
                  label: detail.label,
                  value: detail.value,
                ),
              if (footer != null) ...[
                const SizedBox(height: 8),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WarehouseDetailLine extends StatelessWidget {
  const _WarehouseDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

UserRole _roleForUser(AdminUserListEntry user) {
  if (user.principalRole == UserRole.qolipchi) {
    return UserRole.qolipchi;
  }
  if (user.principalRole == UserRole.boyoqchi) {
    return UserRole.boyoqchi;
  }
  switch (user.kind) {
    case AdminUserKind.supplier:
      return UserRole.supplier;
    case AdminUserKind.werka:
      return UserRole.werka;
    case AdminUserKind.customer:
      return UserRole.customer;
    case AdminUserKind.materialTaminotchi:
      return UserRole.materialTaminotchi;
    case AdminUserKind.qolipchi:
      return UserRole.qolipchi;
    case AdminUserKind.boyoqchi:
      return UserRole.boyoqchi;
    case AdminUserKind.worker:
      return UserRole.aparatchi;
  }
}

List<String> _uniqueWarehouseNames(Iterable<String> warehouses) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in warehouses) {
    final warehouse = raw.trim();
    if (warehouse.isEmpty || !seen.add(warehouse.toLowerCase())) {
      continue;
    }
    out.add(warehouse);
  }
  return out;
}

bool _warehouseNameMatches(Iterable<String> warehouses, String? warehouse) {
  final normalized = warehouse?.trim().toLowerCase() ?? '';
  return normalized.isNotEmpty &&
      warehouses.any((item) => item.trim().toLowerCase() == normalized);
}

bool _isQolipWarehouseName(String? warehouse) {
  final normalized = warehouse?.trim().toLowerCase() ?? '';
  return normalized == 'qolip ombor' || normalized == 'qolip ombori';
}

bool _isReservedRawStock(AdminRawMaterialStockEntry stock) {
  if (stock.reservedOrderId.trim().isNotEmpty) {
    return true;
  }
  return switch (stock.status.trim().toLowerCase()) {
    'reserved' || 'band' => true,
    _ => false,
  };
}

bool _canEditRawMaterialStock(
  AdminRawMaterialStockEntry stock,
  List<AdminRawMaterialAssignment> reservations,
) {
  final barcode = stock.barcode.trim();
  if (barcode.isEmpty ||
      stock.status.trim().toLowerCase() != 'available' ||
      stock.reservedOrderId.trim().isNotEmpty) {
    return false;
  }
  return !reservations.any(
    (reservation) =>
        reservation.barcode.trim().toLowerCase() == barcode.toLowerCase(),
  );
}

String _warehouseStockStatusLabel(
  String rawStatus,
  AppLocalizations l10n,
) {
  return switch (rawStatus.trim().toLowerCase()) {
    'available' => l10n.adminText('stock.status.available'),
    'reserved' || 'band' => l10n.adminText('stock.status.reserved'),
    'in_use' => l10n.adminText('stock.status.in_use'),
    'consumed' => l10n.adminText('stock.status.consumed'),
    'returned' => l10n.adminText('stock.status.returned'),
    'processed' => l10n.adminText('stock.status.processed'),
    final value when value.isEmpty => '',
    final value => value,
  };
}

List<AdminRawMaterialStockEntry> _availableRawStock(
  List<AdminRawMaterialStockEntry> stock,
) {
  return stock
      .where(
        (item) =>
            item.status.trim().toLowerCase() == 'available' &&
            !_isReservedRawStock(item),
      )
      .toList(growable: false);
}

List<AdminRawMaterialStockEntry> _reservedRawStock(
  List<AdminRawMaterialStockEntry> stock,
) {
  return stock.where(_isReservedRawStock).toList(growable: false);
}

int _bandTabEntryCount(
  List<AdminRawMaterialStockEntry> reserved,
  List<AdminRawMaterialAssignment> reservations,
) {
  if (reservations.isNotEmpty) {
    return reservations.length;
  }
  return reserved.length;
}

String _formatQty(double value) => formatRawQuantity(value);
