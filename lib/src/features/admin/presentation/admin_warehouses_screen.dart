import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_summary_card.dart';
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
  late final TabController _tabController;
  StreamSubscription<Map<String, dynamic>>? _warehouseLiveSub;
  Timer? _warehouseLiveReconnectTimer;
  Future<_WarehouseInventorySection?>? _detailFuture;
  String? _selectedWarehouse;
  bool _refreshing = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _future = _load();
    _connectWarehouseLive();
  }

  @override
  void dispose() {
    _disposed = true;
    _warehouseLiveReconnectTimer?.cancel();
    _warehouseLiveSub?.cancel();
    _tabController.dispose();
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

  void _openWarehouseSummaryDetail(_WarehouseSummarySection section) {
    _openWarehouseDetailByName(section.warehouse);
  }

  void _openWarehouseDetailByName(String warehouse) {
    final normalized = warehouse.trim();
    setState(() {
      _selectedWarehouse = normalized;
      _detailFuture = _loadDetail(normalized);
    });
    _tabController.animateTo(1);
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
      bottom: const AdminDock(activeTab: AdminDockTab.settings),
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
          return Column(
            children: [
              AdminSurfaceTabBar(
                controller: _tabController,
                tabs: const [
                  Tab(height: 38, text: 'Omborlar'),
                  Tab(height: 38, text: 'Ombor ma’lumoti'),
                  Tab(height: 38, text: 'Ombor yaratish'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _WarehouseListTab(
                      data: data,
                      bottomPadding: bottomPadding,
                      onRefresh: _reload,
                      onOpenDetail: _openWarehouseSummaryDetail,
                    ),
                    _WarehouseDetailsTab(
                      warehouse: _selectedWarehouse,
                      detailFuture: _detailFuture,
                      bottomPadding: bottomPadding,
                    ),
                    _WarehouseCreateTab(
                      bottomPadding: bottomPadding,
                      onSaved: _reload,
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

class _WarehouseListTab extends StatelessWidget {
  const _WarehouseListTab({
    required this.data,
    required this.bottomPadding,
    required this.onRefresh,
    required this.onOpenDetail,
  });

  final _WarehouseSummaryData data;
  final double bottomPadding;
  final Future<void> Function() onRefresh;
  final ValueChanged<_WarehouseSummarySection> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (data.sections.isEmpty) {
      return const Center(child: Text('Ombor topilmadi'));
    }
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: AppRefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(4, 12, 4, bottomPadding),
          itemCount: data.sections.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: M3SegmentedListGeometry.gap),
          itemBuilder: (context, index) {
            return _WarehouseSectionCard(
              slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                index,
                data.sections.length,
              ),
              section: data.sections[index],
              onOpenDetail: onOpenDetail,
            );
          },
        ),
      ),
    );
  }
}

class _WarehouseCreateTab extends StatefulWidget {
  const _WarehouseCreateTab({
    required this.bottomPadding,
    required this.onSaved,
  });

  final double bottomPadding;
  final Future<void> Function() onSaved;

  @override
  State<_WarehouseCreateTab> createState() => _WarehouseCreateTabState();
}

class _WarehouseCreateTabState extends State<_WarehouseCreateTab> {
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
    final next =
        MobileApi.instance.adminUserList(limit: 500).then((page) => page.items);
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
        setState(() => _loadingUsers = false);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _loadingUsers = false);
    final picked = await showModalBottomSheet<AdminUserListEntry>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
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
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(4, 12, 4, widget.bottomPadding),
        children: [
          TextField(
            controller: _warehouseController,
            textInputAction: TextInputAction.done,
            decoration: _warehouseFieldDecoration(
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
          const SizedBox(height: 12),
          FilledButton.icon(
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
        ],
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
        decoration: _warehouseFieldDecoration(
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

class _WarehouseSectionCard extends StatelessWidget {
  const _WarehouseSectionCard({
    required this.slot,
    required this.section,
    required this.onOpenDetail,
  });

  final M3SegmentVerticalSlot slot;
  final _WarehouseSummarySection section;
  final ValueChanged<_WarehouseSummarySection> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assignValue = section.assignmentCount == 0
        ? 'yo‘q'
        : '${section.assignmentCount}';
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surface,
      elevation: 2,
      title: section.warehouse,
      value: '${section.productCount}',
      subtitle:
          'Mahsulot ${section.productCount} • Band ${section.reservedCount} • Assign $assignValue',
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.warehouse_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      onTap: () => onOpenDetail(section),
    );
  }
}

class _WarehouseDetailsTab extends StatefulWidget {
  const _WarehouseDetailsTab({
    required this.warehouse,
    required this.detailFuture,
    required this.bottomPadding,
  });

  final String? warehouse;
  final Future<_WarehouseInventorySection?>? detailFuture;
  final double bottomPadding;

  @override
  State<_WarehouseDetailsTab> createState() => _WarehouseDetailsTabState();
}

class _WarehouseDetailsTabState extends State<_WarehouseDetailsTab> {
  String? _expandedCardKey;

  @override
  void didUpdateWidget(covariant _WarehouseDetailsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.warehouse != widget.warehouse) {
      _expandedCardKey = null;
    }
  }

  void _onExpandedChanged(String key, bool expanded) {
    setState(() {
      _expandedCardKey = expanded ? key : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final future = widget.detailFuture;
    if (widget.warehouse == null ||
        widget.warehouse!.trim().isEmpty ||
        future == null) {
      return const Center(child: Text('Ombor tanlanmagan'));
    }
    return FutureBuilder<_WarehouseInventorySection?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Ombor ma’lumoti yuklanmadi'));
        }
        final current = snapshot.data;
        if (current == null) {
          return const Center(child: Text('Ombor topilmadi'));
        }
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListView(
            padding: EdgeInsets.fromLTRB(4, 12, 4, widget.bottomPadding),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(
                  current.warehouse,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _WarehouseDetailSummaryCards(section: current),
              if (current.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _WarehouseItemListModule(
                    items: current.items,
                    expandedKey: _expandedCardKey,
                    onExpandedChanged: _onExpandedChanged,
                  ),
                ),
              if (current.rawStock.isNotEmpty ||
                  current.reservations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _WarehouseRawMaterialInventorySection(
                    rawStock: current.rawStock,
                    reservations: current.reservations,
                    expandedKey: _expandedCardKey,
                    onExpandedChanged: _onExpandedChanged,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WarehouseSectionHeader extends StatelessWidget {
  const _WarehouseSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _WarehouseRawMaterialInventorySection extends StatefulWidget {
  const _WarehouseRawMaterialInventorySection({
    required this.rawStock,
    required this.reservations,
    required this.expandedKey,
    required this.onExpandedChanged,
  });

  final List<AdminRawMaterialStockEntry> rawStock;
  final List<AdminRawMaterialAssignment> reservations;
  final String? expandedKey;
  final void Function(String key, bool expanded) onExpandedChanged;

  @override
  State<_WarehouseRawMaterialInventorySection> createState() =>
      _WarehouseRawMaterialInventorySectionState();
}

class _WarehouseRawMaterialInventorySectionState
    extends State<_WarehouseRawMaterialInventorySection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    widget.onExpandedChanged('', false);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final available = _availableRawStock(widget.rawStock);
    final reserved = _reservedRawStock(widget.rawStock);
    final reservedCount = _bandTabEntryCount(reserved, widget.reservations);
    final radius = BorderRadius.circular(M3SegmentedListGeometry.cornerLarge);

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Text(
              'Xomashyo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          AdminSurfaceTabBar(
            controller: _tabController,
            tabs: [
              Tab(height: 38, text: 'Mavjud (${available.length})'),
              Tab(height: 38, text: 'Band qilingan ($reservedCount)'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: _tabController.index == 0
                ? _buildAvailableTab(available)
                : _buildReservedTab(reserved, widget.reservations),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTab(List<AdminRawMaterialStockEntry> available) {
    if (available.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Center(child: Text('Mavjud homashyo topilmadi')),
      );
    }
    return _WarehouseRawStockListModule(
      stock: available,
      expandedKey: widget.expandedKey,
      onExpandedChanged: widget.onExpandedChanged,
    );
  }

  Widget _buildReservedTab(
    List<AdminRawMaterialStockEntry> reserved,
    List<AdminRawMaterialAssignment> reservations,
  ) {
    if (reservations.isNotEmpty) {
      return _WarehouseReservationListModule(
        reservations: reservations,
        expandedKey: widget.expandedKey,
        onExpandedChanged: widget.onExpandedChanged,
      );
    }
    if (reserved.isNotEmpty) {
      return _WarehouseRawStockListModule(
        stock: reserved,
        expandedKey: widget.expandedKey,
        onExpandedChanged: widget.onExpandedChanged,
      );
    }
    return const Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Center(child: Text('Band qilingan homashyo topilmadi')),
    );
  }
}

class _WarehouseDetailSummaryCards extends StatelessWidget {
  const _WarehouseDetailSummaryCards({required this.section});

  final _WarehouseInventorySection section;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final assignValue = section.assignments.isEmpty
        ? 'yo‘q'
        : section.assignments
            .map(
              (item) => item.displayName.trim().isEmpty
                  ? item.principalRef
                  : item.displayName,
            )
            .join(', ');
    return M3SegmentSpacedColumn(
      padding: EdgeInsets.zero,
      children: [
        AdminSummaryCard(
          slot: M3SegmentVerticalSlot.top,
          cornerRadius: M3SegmentedListGeometry.cornerLarge,
          backgroundColor: scheme.surface,
          elevation: 2,
          title: 'Mahsulotlar',
          value: '${section.productCount}',
          showChevron: false,
        ),
        AdminSummaryCard(
          slot: M3SegmentVerticalSlot.middle,
          cornerRadius: M3SegmentedListGeometry.cornerMiddle,
          backgroundColor: scheme.surface,
          elevation: 2,
          title: 'Band qilingan',
          value: '${section.reservations.length}',
          showChevron: false,
        ),
        AdminSummaryCard(
          slot: M3SegmentVerticalSlot.bottom,
          cornerRadius: M3SegmentedListGeometry.cornerLarge,
          backgroundColor: scheme.surface,
          elevation: 2,
          title: 'Assign',
          value: assignValue,
          showChevron: false,
          valueMaxLines: 2,
        ),
      ],
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
            expanded: expandedKey == _warehouseReservationCardKey(
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
          decoration: BoxDecoration(color: scheme.surface, borderRadius: radius),
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
  switch (user.kind) {
    case AdminUserKind.supplier:
      return UserRole.supplier;
    case AdminUserKind.werka:
      return UserRole.werka;
    case AdminUserKind.customer:
      return UserRole.customer;
    case AdminUserKind.worker:
      return UserRole.aparatchi;
  }
}

InputDecoration _warehouseFieldDecoration(
  BuildContext context, {
  required String labelText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder outline({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color ?? scheme.outlineVariant, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: scheme.surface,
    border: outline(),
    enabledBorder: outline(),
    focusedBorder: outline(color: scheme.primary, width: 1.2),
    errorBorder: outline(color: scheme.error),
    focusedErrorBorder: outline(color: scheme.error, width: 1.2),
  );
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
  return stock.where((item) => !_isReservedRawStock(item)).toList(growable: false);
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

String _formatQty(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

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
