import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
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
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
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
      contentPadding: const EdgeInsets.fromLTRB(12, 0, 14, 0),
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
              Material(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(height: 38, text: 'Omborlar'),
                    Tab(height: 38, text: 'Ombor ma’lumoti'),
                    Tab(height: 38, text: 'Ombor yaratish'),
                  ],
                ),
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
    if (data.sections.isEmpty) {
      return const Center(child: Text('Ombor topilmadi'));
    }
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(0, 6, 0, bottomPadding),
        itemCount: data.sections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _WarehouseSectionCard(
            section: data.sections[index],
            onOpenDetail: onOpenDetail,
          );
        },
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
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 10, 0, widget.bottomPadding),
      children: [
        TextField(
          controller: _warehouseController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Ombor nomi',
            border: OutlineInputBorder(),
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
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
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
          labelText: 'Kimga assign',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
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
    required this.section,
    required this.onOpenDetail,
  });

  final _WarehouseSummarySection section;
  final ValueChanged<_WarehouseSummarySection> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOpenDetail(section),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warehouse_rounded, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.warehouse,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${section.productCount}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ItemMeta(
                      label: 'Mahsulot', value: '${section.productCount}'),
                  _ItemMeta(
                    label: 'Band',
                    value: '${section.reservedCount}',
                  ),
                  _ItemMeta(
                    label: 'Assign',
                    value: section.assignmentCount == 0
                        ? 'yo‘q'
                        : '${section.assignmentCount}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarehouseDetailsTab extends StatelessWidget {
  const _WarehouseDetailsTab({
    required this.warehouse,
    required this.detailFuture,
    required this.bottomPadding,
  });

  final String? warehouse;
  final Future<_WarehouseInventorySection?>? detailFuture;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final future = detailFuture;
    if (warehouse == null || warehouse!.trim().isEmpty || future == null) {
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
        return ListView(
          padding: EdgeInsets.fromLTRB(0, 10, 0, bottomPadding),
          children: [
            Text(
              current.warehouse,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text('Mahsulotlar: ${current.productCount}'),
            Text('Band qilingan: ${current.reservations.length}'),
            Text(
              'Assign: ${current.assignments.isEmpty ? 'yo‘q' : current.assignments.map((item) => item.displayName.trim().isEmpty ? item.principalRef : item.displayName).join(', ')}',
            ),
            const SizedBox(height: 12),
            for (final item in current.items) _WarehouseItemTile(item: item),
            if (current.rawStock.isNotEmpty) ...[
              Text(
                'Xomashyo',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              for (final stock in current.rawStock)
                _RawMaterialStockTile(stock: stock),
              const SizedBox(height: 12),
            ],
            if (current.reservations.isNotEmpty) ...[
              Text(
                'Band buyurtmalar',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              for (final reservation in current.reservations)
                _ItemMeta(
                  label: reservation.orderId,
                  value: reservation.itemName.trim().isEmpty
                      ? reservation.itemCode
                      : reservation.itemName,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _WarehouseItemTile extends StatelessWidget {
  const _WarehouseItemTile({required this.item});

  final SupplierItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ItemMeta(label: 'Kod', value: item.code),
                  _ItemMeta(label: 'Birlik', value: item.uom),
                  if (item.itemGroup.trim().isNotEmpty)
                    _ItemMeta(label: 'Guruh', value: item.itemGroup),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RawMaterialStockTile extends StatelessWidget {
  const _RawMaterialStockTile({required this.stock});

  final AdminRawMaterialStockEntry stock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = stock.itemName.trim().isEmpty
        ? stock.itemCode.trim()
        : stock.itemName.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? stock.barcode : title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ItemMeta(label: 'Kod', value: stock.itemCode),
                  _ItemMeta(label: 'Barcode', value: stock.barcode),
                  _ItemMeta(
                    label: 'Miqdor',
                    value: '${_formatQty(stock.qty)} ${stock.uom}'.trim(),
                  ),
                  _ItemMeta(label: 'Status', value: stock.status),
                  if (stock.reservedOrderId.trim().isNotEmpty)
                    _ItemMeta(
                      label: 'Band',
                      value: stock.reservedOrderId,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemMeta extends StatelessWidget {
  const _ItemMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
