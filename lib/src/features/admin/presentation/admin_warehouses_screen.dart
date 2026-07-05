import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/admin_item_group_tree_entry.dart';
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

class _AdminWarehousesScreenState extends State<AdminWarehousesScreen> {
  late Future<_WarehouseSummaryData> _future;
  StreamSubscription<Map<String, dynamic>>? _warehouseLiveSub;
  Timer? _warehouseLiveReconnectTimer;
  Future<_WarehouseInventorySection?>? _detailFuture;
  String? _selectedWarehouse;
  bool _warehouseFilterExpanded = false;
  bool _refreshing = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _connectWarehouseLive();
  }

  @override
  void dispose() {
    _disposed = true;
    _warehouseLiveReconnectTimer?.cancel();
    _warehouseLiveSub?.cancel();
    super.dispose();
  }

  Future<_WarehouseSummaryData> _load() async {
    final summaries = await MobileApi.instance.adminWarehouseSummaries(
      limit: 500,
    );
    return _WarehouseSummaryData(
      sections: summaries
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
    final results = await Future.wait([
      MobileApi.instance.adminWarehouses(limit: 500),
      MobileApi.instance.adminItems(),
      MobileApi.instance.adminWarehouseAssignments(),
      MobileApi.instance.adminRawMaterialAssignments(),
      MobileApi.instance.adminRawMaterialStock(limit: 500),
      MobileApi.instance.adminItemGroupTree(),
    ]);
    final data = _WarehouseInventoryData.from(
      warehouses: results[0] as List<AdminWarehouse>,
      items: results[1] as List<SupplierItem>,
      assignments: results[2] as List<AdminWarehouseAssignment>,
      reservations: results[3] as List<AdminRawMaterialAssignment>,
      rawStock: results[4] as List<AdminRawMaterialStockEntry>,
      itemGroupTree: results[5] as List<AdminItemGroupTreeEntry>,
    );
    final selected = warehouse.trim().toLowerCase();
    for (final section in data.sections) {
      if (section.warehouse.trim().toLowerCase() == selected) {
        return section;
      }
    }
    return null;
  }

  Future<void> _reload() async {
    setState(() {
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
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminWarehouses,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Ombor',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: AdminDock(
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
          return _WarehouseDetailsTab(
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

class _WarehouseInventoryData {
  const _WarehouseInventoryData({
    required this.sections,
  });

  final List<_WarehouseInventorySection> sections;

  factory _WarehouseInventoryData.from({
    required List<AdminWarehouse> warehouses,
    required List<SupplierItem> items,
    required List<AdminWarehouseAssignment> assignments,
    required List<AdminRawMaterialAssignment> reservations,
    required List<AdminRawMaterialStockEntry> rawStock,
    required List<AdminItemGroupTreeEntry> itemGroupTree,
  }) {
    final groupWarehouseResolver = _ItemGroupWarehouseResolver(
      warehouses: warehouses,
      itemGroupTree: itemGroupTree,
    );
    final byWarehouse = <String, List<SupplierItem>>{};
    final itemWarehouseByCode = <String, String>{};
    for (final item in items) {
      final warehouse =
          groupWarehouseResolver.resolve(item) ?? item.warehouse.trim();
      if (warehouse.isEmpty) {
        continue;
      }
      byWarehouse.putIfAbsent(warehouse, () => []).add(item);
      final code = item.code.trim().toLowerCase();
      if (code.isNotEmpty) {
        itemWarehouseByCode[code] = warehouse;
      }
    }

    final assignmentByWarehouse = <String, List<AdminWarehouseAssignment>>{};
    for (final assignment in assignments) {
      final warehouse = assignment.warehouse.trim();
      if (warehouse.isEmpty) {
        continue;
      }
      assignmentByWarehouse.putIfAbsent(warehouse, () => []).add(assignment);
    }

    final rawStockByWarehouse = <String, List<AdminRawMaterialStockEntry>>{};
    final stockWarehouseByBarcode = <String, String>{};
    for (final stock in rawStock) {
      final warehouse = stock.warehouse.trim();
      if (warehouse.isEmpty) {
        continue;
      }
      rawStockByWarehouse.putIfAbsent(warehouse, () => []).add(stock);
      final barcode = stock.barcode.trim().toLowerCase();
      if (barcode.isNotEmpty) {
        stockWarehouseByBarcode[barcode] = warehouse;
      }
    }

    final reservationByWarehouse = <String, List<AdminRawMaterialAssignment>>{};
    for (final reservation in reservations) {
      final warehouse =
          stockWarehouseByBarcode[reservation.barcode.trim().toLowerCase()] ??
              itemWarehouseByCode[reservation.itemCode.trim().toLowerCase()] ??
              '';
      if (warehouse.isEmpty) {
        continue;
      }
      reservationByWarehouse.putIfAbsent(warehouse, () => []).add(reservation);
    }

    final warehouseNames = <String>[];
    void addWarehouse(String name) {
      final normalized = name.trim();
      if (normalized.isEmpty) {
        return;
      }
      if (!warehouseNames
          .any((item) => item.toLowerCase() == normalized.toLowerCase())) {
        warehouseNames.add(normalized);
      }
    }

    for (final warehouse in warehouses) {
      if (warehouse.parentWarehouse.trim().isEmpty) {
        addWarehouse(warehouse.warehouse);
      }
    }
    for (final warehouse in byWarehouse.keys) {
      addWarehouse(warehouse);
    }
    for (final warehouse in assignmentByWarehouse.keys) {
      addWarehouse(warehouse);
    }
    for (final warehouse in rawStockByWarehouse.keys) {
      addWarehouse(warehouse);
    }
    warehouseNames.sort(
        (left, right) => left.toLowerCase().compareTo(right.toLowerCase()));

    final sections = <_WarehouseInventorySection>[];
    for (final warehouse in warehouseNames) {
      final warehouseItems = List<SupplierItem>.from(
        byWarehouse[warehouse] ?? const [],
      )..sort((left, right) {
          final group = left.itemGroup.compareTo(right.itemGroup);
          if (group != 0) {
            return group;
          }
          return left.name.compareTo(right.name);
        });
      final warehouseAssignments = List<AdminWarehouseAssignment>.from(
        assignmentByWarehouse[warehouse] ?? const [],
      );
      final warehouseReservations = List<AdminRawMaterialAssignment>.from(
        reservationByWarehouse[warehouse] ?? const [],
      );
      final warehouseRawStock = List<AdminRawMaterialStockEntry>.from(
        rawStockByWarehouse[warehouse] ?? const [],
      )..sort((left, right) {
          final code = left.itemCode.compareTo(right.itemCode);
          if (code != 0) {
            return code;
          }
          return left.barcode.compareTo(right.barcode);
        });
      sections.add(
        _WarehouseInventorySection(
          warehouse: warehouse,
          items: List<SupplierItem>.unmodifiable(warehouseItems),
          rawStock: List<AdminRawMaterialStockEntry>.unmodifiable(
            warehouseRawStock,
          ),
          assignments: List<AdminWarehouseAssignment>.unmodifiable(
            warehouseAssignments,
          ),
          reservations: List<AdminRawMaterialAssignment>.unmodifiable(
            warehouseReservations,
          ),
        ),
      );
    }
    return _WarehouseInventoryData(
      sections: List<_WarehouseInventorySection>.unmodifiable(sections),
    );
  }
}

class _WarehouseInventorySection {
  const _WarehouseInventorySection({
    required this.warehouse,
    required this.items,
    required this.rawStock,
    required this.assignments,
    required this.reservations,
  });

  final String warehouse;
  final List<SupplierItem> items;
  final List<AdminRawMaterialStockEntry> rawStock;
  final List<AdminWarehouseAssignment> assignments;
  final List<AdminRawMaterialAssignment> reservations;

  int get productCount => items.length + rawStock.length;
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
    final next = Future.wait([
      MobileApi.instance.adminUserList(limit: 500),
      MobileApi.instance.adminWorkers(),
      MobileApi.instance.adminRoleAssignments(),
    ]).then((results) {
      final page = results[0] as AdminUserListPage;
      final workers = results[1] as List<AdminWorker>;
      final assignments = results[2] as List<AdminRoleAssignment>;
      final workerEntries = workers.map((worker) {
        final assignment = assignments
            .where((item) => item.principalRef.trim() == worker.id.trim())
            .where((item) =>
                item.principalRole == UserRole.qolipchi ||
                item.roleId.trim() == 'qolipchi')
            .cast<AdminRoleAssignment?>()
            .firstWhere((item) => item != null, orElse: () => null);
        final role = assignment?.principalRole == UserRole.qolipchi ||
                assignment?.roleId.trim() == 'qolipchi'
            ? UserRole.qolipchi
            : UserRole.aparatchi;
        return AdminUserListEntry(
          id: worker.id,
          name: worker.name,
          phone: worker.phone,
          kind: role == UserRole.qolipchi
              ? AdminUserKind.qolipchi
              : AdminUserKind.worker,
          principalRole: role,
          roleLabelOverride: userRoleLabel(role),
        );
      });
      final byKey = <String, AdminUserListEntry>{};
      for (final item in [...page.items, ...workerEntries]) {
        final key = '${item.kind.name}:${item.id.trim().toLowerCase()}';
        byKey[key] = item;
      }
      return byKey.values.toList(growable: false)
        ..sort((left, right) => left.name.toLowerCase().compareTo(
              right.name.toLowerCase(),
            ));
    });
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
      color: scheme.surface,
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
  late TabController _stockTabController;
  String? _expandedCardKey;

  @override
  void initState() {
    super.initState();
    _stockTabController = TabController(length: 1, vsync: this);
    _stockTabController.addListener(_handleStockTabChanged);
  }

  @override
  void didUpdateWidget(covariant _WarehouseDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warehouse != widget.warehouse) {
      _expandedCardKey = null;
    }
  }

  @override
  void dispose() {
    _stockTabController.removeListener(_handleStockTabChanged);
    _stockTabController.dispose();
    super.dispose();
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
    Widget buildScaffold(List<Widget> children) {
      return ColoredBox(
        color: AppTheme.shellStart(context),
        child: ListView(
          padding: EdgeInsets.fromLTRB(4, 4, 4, widget.bottomPadding),
          children: [
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
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return buildScaffold(const [
            SizedBox(height: 24),
            Center(child: AppLoadingIndicator()),
          ]);
        }
        if (snapshot.hasError) {
          return buildScaffold(const [
            SizedBox(height: 24),
            Center(child: Text('Ombor ma’lumoti yuklanmadi')),
          ]);
        }
        final current = snapshot.data;
        if (current == null) {
          return buildScaffold(const [
            SizedBox(height: 24),
            Center(child: Text('Ombor topilmadi')),
          ]);
        }
        if (current.items.isEmpty &&
            current.rawStock.isEmpty &&
            current.reservations.isEmpty) {
          return buildScaffold(const [
            SizedBox(height: 24),
            Center(child: Text('Mahsulot topilmadi')),
          ]);
        }
        final availableRawStock = _availableRawStock(current.rawStock);
        final reservedRawStock = _reservedRawStock(current.rawStock);
        final availableCount = current.items.length + availableRawStock.length;
        final reservedCount = _bandTabEntryCount(
          reservedRawStock,
          current.reservations,
        );
        final availableChildren = <Widget>[
          if (current.items.isNotEmpty)
            _WarehouseItemListModule(
              items: current.items,
              expandedKey: _expandedCardKey,
              onExpandedChanged: _onExpandedChanged,
            ),
          if (availableRawStock.isNotEmpty)
            _WarehouseRawStockListModule(
              stock: availableRawStock,
              expandedKey: _expandedCardKey,
              onExpandedChanged: _onExpandedChanged,
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
        final hasAvailable = availableChildren.isNotEmpty;
        final hasReserved = reservedChildren.isNotEmpty;
        final stockTabs = <Tab>[];
        final stockTabChildren = <List<Widget>>[];
        if (hasAvailable && hasReserved) {
          stockTabs.add(Tab(height: 38, text: 'Mavjud ($availableCount)'));
          stockTabChildren.add(availableChildren);
          stockTabs
              .add(Tab(height: 38, text: 'Band qilingan ($reservedCount)'));
          stockTabChildren.add(reservedChildren);
        } else if (hasAvailable) {
          stockTabs.add(Tab(height: 38, text: 'Mahsulotlar ($availableCount)'));
          stockTabChildren.add(availableChildren);
        } else if (hasReserved) {
          stockTabs
              .add(Tab(height: 38, text: 'Band qilingan ($reservedCount)'));
          stockTabChildren.add(reservedChildren);
        }
        final stockController = _stockControllerForLength(stockTabs.length);
        final visibleChildren = stockTabChildren[stockController.index];
        return buildScaffold([
          AdminSurfaceTabBar(
            controller: stockController,
            tabs: stockTabs,
          ),
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
        ]);
      },
    );
  }
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
    final subtitle = <String>[
      if (stock.itemCode.trim().isNotEmpty) stock.itemCode.trim(),
      if (stock.barcode.trim().isNotEmpty) stock.barcode.trim(),
      '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
      if (stock.status.trim().isNotEmpty) stock.status.trim(),
      if (stock.reservedOrderId.trim().isNotEmpty)
        'Band ${stock.reservedOrderId.trim()}',
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
            Icons.science_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title.isEmpty ? stock.barcode : title,
      subtitle: subtitle,
      details: [
        _WarehouseDetailEntry('Kod', stock.itemCode),
        _WarehouseDetailEntry('Barcode', stock.barcode),
        _WarehouseDetailEntry(
          'Miqdor',
          '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
        ),
        _WarehouseDetailEntry('Status', stock.status),
        if (stock.reservedOrderId.trim().isNotEmpty)
          _WarehouseDetailEntry('Band', stock.reservedOrderId),
        if (stock.sourceReceiptId.trim().isNotEmpty)
          _WarehouseDetailEntry('Kirim', stock.sourceReceiptId),
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
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onExpandedChanged(!expanded),
        borderRadius: radius,
        child: Ink(
          decoration:
              BoxDecoration(color: scheme.surface, borderRadius: radius),
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
    case AdminUserKind.worker:
      return UserRole.aparatchi;
  }
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

class _ItemGroupWarehouseResolver {
  _ItemGroupWarehouseResolver({
    required List<AdminWarehouse> warehouses,
    required List<AdminItemGroupTreeEntry> itemGroupTree,
  })  : _rawWarehouse = _findWarehouse(warehouses, _isRawName),
        _finishedWarehouse = _findWarehouse(warehouses, _isFinishedName),
        _parentByGroup = _parentsFrom(itemGroupTree);

  final String _rawWarehouse;
  final String _finishedWarehouse;
  final Map<String, String> _parentByGroup;

  String? resolve(SupplierItem item) {
    final group = item.itemGroup.trim();
    if (group.isEmpty) {
      return null;
    }
    if (_rawWarehouse.isNotEmpty && _groupMatches(group, _isRawName)) {
      return _rawWarehouse;
    }
    if (_finishedWarehouse.isNotEmpty &&
        _groupMatches(group, _isFinishedName)) {
      return _finishedWarehouse;
    }
    return null;
  }

  bool _groupMatches(String group, bool Function(String) matcher) {
    var current = group.trim();
    final visited = <String>{};
    while (current.isNotEmpty) {
      final normalized = _normalize(current);
      if (!visited.add(normalized)) {
        return false;
      }
      if (matcher(normalized)) {
        return true;
      }
      current = _parentByGroup[normalized] ?? '';
    }
    return false;
  }

  static Map<String, String> _parentsFrom(
    List<AdminItemGroupTreeEntry> entries,
  ) {
    final parents = <String, String>{};
    for (final entry in entries) {
      final name = (entry.itemGroupName.trim().isNotEmpty
              ? entry.itemGroupName
              : entry.name)
          .trim();
      if (name.isEmpty) {
        continue;
      }
      parents[_normalize(name)] = entry.parentItemGroup.trim();
    }
    return parents;
  }

  static String _findWarehouse(
    List<AdminWarehouse> warehouses,
    bool Function(String) matcher,
  ) {
    for (final warehouse in warehouses) {
      final name = warehouse.warehouse.trim();
      if (name.isEmpty || warehouse.parentWarehouse.trim().isNotEmpty) {
        continue;
      }
      if (matcher(_normalize(name))) {
        return name;
      }
    }
    return '';
  }

  static bool _isRawName(String value) {
    return value.contains('xomashyo') || value.contains('homashyo');
  }

  static bool _isFinishedName(String value) {
    return value.contains('tayyor') && value.contains('mahsulot');
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }
}
