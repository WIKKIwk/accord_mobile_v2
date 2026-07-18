import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/session/session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'dart:async';
import 'package:flutter/material.dart';

const Duration _warehouseLiveReconnectInterval = Duration(seconds: 5);

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
  Future<_WarehouseInventorySection?>? _detailFuture;
  String? _selectedWarehouse;
  bool _warehouseFilterExpanded = false;
  bool _refreshing = false;
  bool _disposed = false;

  bool get _materialScoped =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;

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
    _warehouseLiveSub?.cancel();
    _pageTabController.dispose();
    super.dispose();
  }

  Future<_WarehouseSummaryData> _load() async {
    final summaries = await MobileApi.instance.adminWarehouseSummaries(
      limit: 500,
    );
    final allowedWarehouses =
        _materialScoped ? await _loadMaterialAssignedWarehouses() : null;
    return _WarehouseSummaryData(
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
    ]);
    final allReservations = results[0] as List<AdminRawMaterialAssignment>;
    final rawStock = results[1] as List<AdminRawMaterialStockEntry>;
    final stockBarcodes = rawStock
        .map((item) => item.barcode.trim().toLowerCase())
        .where((barcode) => barcode.isNotEmpty)
        .toSet();
    return _WarehouseInventorySection(
      rawStock: List<AdminRawMaterialStockEntry>.unmodifiable(rawStock),
      reservations: List<AdminRawMaterialAssignment>.unmodifiable(
        allReservations.where(
          (item) => stockBarcodes.contains(item.barcode.trim().toLowerCase()),
        ),
      ),
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
      final selected = _selectedWarehouse?.trim() ?? '';
      if (selected.isNotEmpty) {
        _detailFuture = _loadDetail(selected);
      }
    });
    await _future;
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
    final nextFuture = _load();
    setState(() {
      _future = nextFuture;
    });
    try {
      await nextFuture;
    } catch (_) {
      // FutureBuilder ko‘rsatadi; background refresh exceptioni UI threadni yiqitmasin.
    } finally {
      _refreshing = false;
    }
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
          _refreshInPlace();
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
      title: materialScoped ? 'Omborlarim' : 'Ombor',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: materialScoped
          ? const MaterialTaminotchiDock()
          : AdminDock(
              activeTab: AdminDockTab.settings,
              primaryFabActions: [
                AdminFabMenuAction(
                  title: 'Ombor yaratish',
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
            summaries: data.sections,
            warehouse: _selectedWarehouse,
            detailFuture: _detailFuture,
            bottomPadding: bottomPadding,
            filterExpanded: _warehouseFilterExpanded,
            onFilterToggle: () {
              setState(() {
                _warehouseFilterExpanded = !_warehouseFilterExpanded;
              });
            },
            onWarehouseChanged: _openWarehouseDetailByName,
          );
          if (materialScoped) {
            return productsTab;
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
  const _WarehouseSummaryData({required this.sections});

  static const empty = _WarehouseSummaryData(sections: []);

  final List<_WarehouseSummarySection> sections;
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

Future<List<AdminUserListEntry>> _loadWarehouseAssigneeUsers() async {
  final results = await Future.wait([
    MobileApi.instance.adminUserList(limit: 500),
    MobileApi.instance.adminUserList(role: 'qolipchi', limit: 500),
    MobileApi.instance.adminUserList(
      role: 'material_taminotchi',
      limit: 500,
    ),
    MobileApi.instance.adminWorkers(),
    MobileApi.instance.adminRoleAssignments(),
  ]);
  final page = results[0] as AdminUserListPage;
  final qolipchiPage = results[1] as AdminUserListPage;
  final materialPage = results[2] as AdminUserListPage;
  final workers = results[3] as List<AdminWorker>;
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
    final isBrigader = worker.level.trim().toLowerCase() == 'brigader';
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
      principalRole: role,
      roleLabelOverride: isQolipchi ? userRoleLabel(role) : 'Brigader',
    ));
  }
  final byKey = <String, AdminUserListEntry>{};
  for (final item in [
    ...page.items,
    ...qolipchiPage.items,
    ...materialPage.items,
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
          const SnackBar(content: Text('Foydalanuvchilar yuklanmadi')),
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
        const SnackBar(content: Text('Foydalanuvchilar topilmadi')),
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
          title: 'Kimga assign',
          hintText: 'Foydalanuvchi qidiring',
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
                      'Ombor yaratish',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Yopish',
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
                  labelText: 'Ombor nomi',
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
                  label: const Text('Assign qilish'),
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
          labelText: 'Kimga assign',
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
                loading ? 'Yuklanmoqda...' : 'Tanlash uchun bosing',
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
    required this.summaries,
    required this.warehouse,
    required this.detailFuture,
    required this.bottomPadding,
    required this.filterExpanded,
    required this.onFilterToggle,
    required this.onWarehouseChanged,
  });

  final List<_WarehouseSummarySection> summaries;
  final String? warehouse;
  final Future<_WarehouseInventorySection?>? detailFuture;
  final double bottomPadding;
  final bool filterExpanded;
  final VoidCallback onFilterToggle;
  final ValueChanged<String> onWarehouseChanged;

  @override
  State<_WarehouseDetailsTab> createState() => _WarehouseDetailsTabState();
}

class _WarehouseDetailsTabState extends State<_WarehouseDetailsTab>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 80;
  static const double _loadMoreExtent = 420;

  late TabController _stockTabController;
  final ScrollController _itemsScrollController = ScrollController();
  final TextEditingController _itemsSearchController = TextEditingController();
  Timer? _itemsSearchDebounce;
  List<SupplierItem> _items = const <SupplierItem>[];
  String _itemsQuery = '';
  bool _initialItemsLoading = false;
  bool _loadingMoreItems = false;
  bool _hasMoreItems = false;
  Object? _itemsError;
  int _itemsRequestGeneration = 0;
  String? _expandedCardKey;

  @override
  void initState() {
    super.initState();
    _stockTabController = TabController(length: 1, vsync: this);
    _stockTabController.addListener(_handleStockTabChanged);
    _itemsScrollController.addListener(_handleItemsScroll);
    unawaited(_loadFirstItemsPage());
  }

  @override
  void didUpdateWidget(covariant _WarehouseDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warehouse != widget.warehouse) {
      _expandedCardKey = null;
      _itemsSearchDebounce?.cancel();
      _itemsSearchController.clear();
      _itemsQuery = '';
      unawaited(_loadFirstItemsPage());
    }
  }

  @override
  void dispose() {
    _itemsSearchDebounce?.cancel();
    _itemsScrollController.removeListener(_handleItemsScroll);
    _itemsScrollController.dispose();
    _itemsSearchController.dispose();
    _stockTabController.removeListener(_handleStockTabChanged);
    _stockTabController.dispose();
    super.dispose();
  }

  void _handleItemsSearchChanged(String value) {
    _itemsSearchDebounce?.cancel();
    _itemsSearchDebounce = Timer(const Duration(milliseconds: 220), () {
      _itemsQuery = value.trim();
      unawaited(_loadFirstItemsPage());
    });
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
        _items = const <SupplierItem>[];
        _initialItemsLoading = warehouse.isNotEmpty;
        _loadingMoreItems = false;
        _hasMoreItems = false;
        _itemsError = null;
      });
    }
    if (warehouse.isEmpty) {
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
        _items = replace ? page : <SupplierItem>[..._items, ...page];
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

  void _handleStockTabChanged() {
    if (_stockTabController.indexIsChanging) {
      return;
    }
    setState(() {
      _expandedCardKey = null;
    });
  }

  TabController _stockControllerForLength(int length) {
    if (_stockTabController.length == length) {
      return _stockTabController;
    }
    final currentIndex = _stockTabController.index;
    _stockTabController.removeListener(_handleStockTabChanged);
    _stockTabController.dispose();
    _stockTabController = TabController(
      length: length,
      initialIndex: currentIndex < length ? currentIndex : length - 1,
      vsync: this,
    );
    _stockTabController.addListener(_handleStockTabChanged);
    _expandedCardKey = null;
    return _stockTabController;
  }

  void _onExpandedChanged(String key, bool expanded) {
    setState(() {
      _expandedCardKey = expanded ? key : null;
    });
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
      return buildScaffold(const [
        SizedBox(height: 24),
        Center(child: Text('Ombor topilmadi')),
      ]);
    }
    if (widget.warehouse == null ||
        widget.warehouse!.trim().isEmpty ||
        future == null) {
      return buildScaffold(const [
        SizedBox(height: 24),
        Center(child: Text('Ombor tanlanmagan')),
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
        final availableCount = selectedSummary?.productCount ??
            (_items.length + availableRawStock.length);
        final reservedCount = _bandTabEntryCount(
          reservedRawStock,
          current.reservations,
        );
        final availableChildren = <Widget>[
          SearchBar(
            controller: _itemsSearchController,
            hintText: 'Ombordagi mahsulotni qidirish',
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
                  label: const Text('Qayta urinish'),
                ),
              ),
            )
          else if (_items.isNotEmpty)
            _WarehouseItemListModule(
              items: _items,
              expandedKey: _expandedCardKey,
              onExpandedChanged: _onExpandedChanged,
            )
          else if (availableRawStock.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: Text('Mahsulot topilmadi')),
            ),
          if (availableRawStock.isNotEmpty)
            _WarehouseRawStockListModule(
              stock: availableRawStock,
              expandedKey: _expandedCardKey,
              onExpandedChanged: _onExpandedChanged,
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
                label: const Text('Yana yuklash'),
              ),
            )
          else if (_hasMoreItems)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Pastga scroll qiling, qolganlari yuklanadi',
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
              expandedKey: _expandedCardKey,
              onExpandedChanged: _onExpandedChanged,
            )
          else if (reservedRawStock.isNotEmpty)
            _WarehouseRawStockListModule(
              stock: reservedRawStock,
              expandedKey: _expandedCardKey,
              onExpandedChanged: _onExpandedChanged,
            ),
        ];
        final hasReserved = reservedChildren.isNotEmpty;
        final stockTabs = <Tab>[
          Tab(height: 38, text: 'Mavjud ($availableCount)'),
        ];
        final stockTabChildren = <List<Widget>>[availableChildren];
        if (hasReserved) {
          stockTabs
              .add(Tab(height: 38, text: 'Band qilingan ($reservedCount)'));
          stockTabChildren.add(reservedChildren);
        }
        final stockController = _stockControllerForLength(stockTabs.length);
        final visibleChildren = stockTabChildren[stockController.index];
        return buildScaffold([
          const SizedBox(height: 8),
          if (visibleChildren.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: Text('Mahsulot topilmadi')),
            )
          else ...[
            for (var index = 0; index < visibleChildren.length; index++) ...[
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
                stockController.index == 0 ? _itemsScrollController : null);
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
        _showWarehouseNotice(context, 'Foydalanuvchilar yuklanmadi');
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
          context, 'Barcha mos foydalanuvchilar assign qilingan');
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
          title: 'Kimga assign',
          hintText: 'Foydalanuvchi qidiring',
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
        _showWarehouseNotice(context, '${picked.name} omborga assign qilindi');
      }
    } catch (_) {
      if (mounted) {
        _showWarehouseNotice(context, 'Foydalanuvchi assign qilinmadi');
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
      title: 'Assigndan chiqarish',
      message:
          '$displayName foydalanuvchisini “$_warehouse” omboridan chiqarasizmi?',
      cancelLabel: 'Bekor qilish',
      confirmLabel: 'Olib tashlash',
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
        _showWarehouseNotice(context, '$displayName assigndan chiqarildi');
      }
    } catch (error) {
      if (mounted) {
        final message = error is MobileApiException
            ? error.message
            : 'Foydalanuvchi assigndan chiqarilmadi';
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
            title: const Text('Omborni o‘chirib bo‘lmaydi'),
            content: Text(
              '“${summary.warehouse}” omborida ${summary.reservedCount} ta faol band qilingan mahsulot bor. Avval ularni bo‘shating.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Yopish'),
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
        _showWarehouseNotice(context, 'Ombor o‘chirildi');
      }
    } catch (error) {
      if (mounted) {
        _showWarehouseNotice(context, _warehouseDeleteErrorMessage(error));
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
          title: const Text('Omborni o‘chirish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasProducts
                    ? '“${summary.warehouse}” omborida ${summary.productCount} ta mahsulot bor. Omborni o‘chirsangiz, bu mahsulotlar ham o‘chib ketadi.'
                    : '“${summary.warehouse}” omborini o‘chirishni tasdiqlaysizmi?',
              ),
              if (summary.assignmentCount > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '${summary.assignmentCount} ta foydalanuvchi assigni ham olib tashlanadi.',
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
                      child: const Text('Bekor qilish'),
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
                      child: const Text('O‘chirish'),
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
            const Center(child: Text('Ombor tanlanmagan')),
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
                      'Ombor ma’lumoti',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _WarehouseSettingCount(
                      label: 'Mahsulotlar',
                      value: summary.productCount,
                    ),
                    _WarehouseSettingCount(
                      label: 'Band qilingan',
                      value: summary.reservedCount,
                    ),
                    _WarehouseSettingCount(
                      label: 'Assignlar',
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
                      'Assign qilinganlar',
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
                              'Hech kim assign qilinmagan',
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
                                            tooltip: 'Assigndan chiqarish',
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
                        label: const Text('Kimga assign qilish'),
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
                      'Xavfli amal',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ombor o‘chirilganda uning mahsulotlari va assignlari ham olib tashlanadi.',
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
                        label: const Text('Omborni o‘chirish'),
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

String _warehouseDeleteErrorMessage(Object error) {
  if (error is MobileApiException) {
    return switch (error.code) {
      'warehouse_has_active_reservations' =>
        'Omborda faol band qilingan mahsulotlar bor',
      'warehouse_has_children' => 'Omborda ichki omborlar bor',
      'warehouse_not_empty' =>
        'Omborda mahsulotlar bor. Ma’lumotni yangilab qayta urinib ko‘ring',
      'warehouse_not_found' => 'Ombor topilmadi',
      _ => 'Ombor o‘chirilmadi',
    };
  }
  return 'Ombor o‘chirilmadi';
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
      label: 'Ombor',
      emptyLabel: 'Tanlanmagan',
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

class _WarehouseItemListModule extends StatelessWidget {
  const _WarehouseItemListModule({
    required this.items,
    required this.expandedKey,
    required this.onExpandedChanged,
  });

  final List<SupplierItem> items;
  final String? expandedKey;
  final void Function(String key, bool expanded) onExpandedChanged;

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
            expanded: expandedKey == _warehouseItemCardKey(items[index]),
            onExpandedChanged: (expanded) => onExpandedChanged(
              _warehouseItemCardKey(items[index]),
              expanded,
            ),
          ),
      ],
    );
  }
}

String _warehouseItemCardKey(SupplierItem item) => 'item:${item.code}';

class _WarehouseItemRow extends StatelessWidget {
  const _WarehouseItemRow({
    required this.slot,
    required this.item,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final M3SegmentVerticalSlot slot;
  final SupplierItem item;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = item.name.trim().isEmpty ? item.code : item.name;
    final subtitle = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      if (item.uom.trim().isNotEmpty) item.uom.trim(),
      if (item.itemGroup.trim().isNotEmpty) item.itemGroup.trim(),
    ].join(' • ');

    return _WarehouseExpandableSummaryCard(
      slot: slot,
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
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
        _WarehouseDetailEntry('Kod', item.code),
        _WarehouseDetailEntry('Birlik', item.uom),
        if (item.itemGroup.trim().isNotEmpty)
          _WarehouseDetailEntry('Guruh', item.itemGroup),
        _WarehouseDetailEntry('Ombor', item.warehouse),
      ],
    );
  }
}

class _WarehouseRawStockListModule extends StatelessWidget {
  const _WarehouseRawStockListModule({
    required this.stock,
    required this.expandedKey,
    required this.onExpandedChanged,
  });

  final List<AdminRawMaterialStockEntry> stock;
  final String? expandedKey;
  final void Function(String key, bool expanded) onExpandedChanged;

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
            expanded: expandedKey == _warehouseStockCardKey(stock[index]),
            onExpandedChanged: (expanded) => onExpandedChanged(
              _warehouseStockCardKey(stock[index]),
              expanded,
            ),
          ),
      ],
    );
  }
}

String _warehouseStockCardKey(AdminRawMaterialStockEntry stock) {
  if (stock.id.trim().isNotEmpty) {
    return 'stock:${stock.id}';
  }
  return 'stock:${stock.itemCode}-${stock.barcode}';
}

class _WarehouseRawStockRow extends StatelessWidget {
  const _WarehouseRawStockRow({
    required this.slot,
    required this.stock,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialStockEntry stock;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = stock.itemName.trim().isEmpty
        ? stock.itemCode.trim()
        : stock.itemName.trim();

    return _WarehouseExpandableSummaryCard(
      slot: slot,
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.science_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title.isEmpty ? stock.barcode : title,
      subtitle: '',
      details: [
        _WarehouseDetailEntry('Mahsulot kodi', stock.itemCode),
        _WarehouseDetailEntry('Shtrix-kod', stock.barcode),
        _WarehouseDetailEntry(
          'Miqdor',
          '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
        ),
        _WarehouseDetailEntry(
            'Holati', _warehouseStockStatusLabel(stock.status)),
        if (stock.reservedOrderId.trim().isNotEmpty)
          _WarehouseDetailEntry('Band', stock.reservedOrderId),
        if (stock.sourceReceiptId.trim().isNotEmpty)
          _WarehouseDetailEntry('Kirim raqami', stock.sourceReceiptId),
      ],
    );
  }
}

class _WarehouseReservationListModule extends StatelessWidget {
  const _WarehouseReservationListModule({
    required this.reservations,
    required this.expandedKey,
    required this.onExpandedChanged,
  });

  final List<AdminRawMaterialAssignment> reservations;
  final String? expandedKey;
  final void Function(String key, bool expanded) onExpandedChanged;

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
            expanded: expandedKey ==
                _warehouseReservationCardKey(
                  reservations[index],
                ),
            onExpandedChanged: (expanded) => onExpandedChanged(
              _warehouseReservationCardKey(reservations[index]),
              expanded,
            ),
          ),
      ],
    );
  }
}

String _warehouseReservationCardKey(AdminRawMaterialAssignment reservation) {
  return 'reservation:${reservation.orderId}-${reservation.barcode}';
}

class _WarehouseReservationRow extends StatelessWidget {
  const _WarehouseReservationRow({
    required this.slot,
    required this.reservation,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialAssignment reservation;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

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
      expanded: expanded,
      onExpandedChanged: onExpandedChanged,
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
        _WarehouseDetailEntry('Buyurtma', reservation.orderId),
        _WarehouseDetailEntry('Kod', reservation.itemCode),
        _WarehouseDetailEntry('Barcode', reservation.barcode),
        if (reservation.itemGroup.trim().isNotEmpty)
          _WarehouseDetailEntry('Guruh', reservation.itemGroup),
        if (reservation.apparatus.trim().isNotEmpty)
          _WarehouseDetailEntry('Apparat', reservation.apparatus),
        if (reservation.assignedByName.trim().isNotEmpty)
          _WarehouseDetailEntry('Assign', reservation.assignedByName),
        if (reservation.assignedAt.trim().isNotEmpty)
          _WarehouseDetailEntry('Vaqt', reservation.assignedAt),
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
    required this.expanded,
    required this.onExpandedChanged,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.details,
  });

  final M3SegmentVerticalSlot slot;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget leading;
  final String title;
  final String subtitle;
  final List<_WarehouseDetailEntry> details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cornerRadius = M3SegmentedListGeometry.cornerRadiusForSlot(slot);
    final radius = M3SegmentedListGeometry.borderRadius(slot, cornerRadius);

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onExpandedChanged(!expanded),
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: radius,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 12 : 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (subtitle.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.05,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: 44,
                            top: 8,
                            right: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final detail in details)
                                _WarehouseDetailLine(
                                  label: detail.label,
                                  value: detail.value,
                                ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
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

bool _isReservedRawStock(AdminRawMaterialStockEntry stock) {
  if (stock.reservedOrderId.trim().isNotEmpty) {
    return true;
  }
  return switch (stock.status.trim().toLowerCase()) {
    'reserved' || 'band' => true,
    _ => false,
  };
}

String _warehouseStockStatusLabel(String rawStatus) {
  return switch (rawStatus.trim().toLowerCase()) {
    'available' => 'Mavjud',
    'reserved' || 'band' => 'Band qilingan',
    'in_use' => 'Ishlatilmoqda',
    'consumed' => 'Sarflangan',
    'returned' => 'Qaytarilgan',
    'processed' => 'Qayta ishlangan',
    final value when value.isEmpty => '',
    final value => value,
  };
}

List<AdminRawMaterialStockEntry> _availableRawStock(
  List<AdminRawMaterialStockEntry> stock,
) {
  return stock
      .where((item) => !_isReservedRawStock(item))
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
