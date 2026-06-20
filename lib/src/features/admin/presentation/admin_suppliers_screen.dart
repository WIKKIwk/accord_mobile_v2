import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_supplier_list_module.dart';

class AdminSuppliersScreen extends StatefulWidget {
  const AdminSuppliersScreen({super.key});

  static void invalidateCache() {
    _AdminSuppliersScreenState.invalidateCache();
  }

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
}

const List<AdminUserKind> _adminUserTabKinds = [
  AdminUserKind.werka,
  AdminUserKind.customer,
  AdminUserKind.supplier,
  AdminUserKind.worker,
  AdminUserKind.qolipchi,
];

bool _workerIsQolipchi(
  AdminWorker worker,
  List<AdminRoleAssignment> assignments,
) {
  final workerId = worker.id.trim().toLowerCase();
  for (final assignment in assignments) {
    if (assignment.principalRef.trim().toLowerCase() != workerId) {
      continue;
    }
    if (assignment.principalRole == UserRole.qolipchi ||
        assignment.roleId.trim() == 'qolipchi') {
      return true;
    }
  }
  return false;
}

int _adminUserKindIndex(AdminUserKind kind) {
  final index = _adminUserTabKinds.indexOf(kind);
  return index < 0 ? 2 : index;
}

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen>
    with SingleTickerProviderStateMixin {
  static const int _pageSize = 50;
  static const double _prefetchExtentAfterFactor = 2.5;
  static _AdminSuppliersCache? _cache;
  static final ValueNotifier<int> _usersChanged = ValueNotifier<int>(0);

  static void invalidateCache() {
    _cache = null;
    _usersChanged.value++;
  }

  final TextEditingController _searchController = TextEditingController();
  final List<AdminUserListEntry> _items = [];
  final List<AdminWorker> _workers = [];
  final List<AdminRoleAssignment> _assignments = [];
  Timer? _searchDebounce;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  AdminUserKind _selectedKind = AdminUserKind.supplier;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _adminUserTabKinds.length,
      initialIndex: _adminUserKindIndex(_selectedKind),
      vsync: this,
    )..addListener(_handleKindTabChanged);
    _usersChanged.addListener(_handleUsersChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _usersChanged.removeListener(_handleUsersChanged);
    _tabController.removeListener(_handleKindTabChanged);
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleKindTabChanged() {
    final next = _adminUserTabKinds[_tabController.index];
    if (_selectedKind == next) {
      return;
    }
    setState(() => _selectedKind = next);
    _saveCache();
  }

  void _handleUsersChanged() {
    unawaited(_bootstrap(forceRefresh: true));
  }

  Future<void> _reload() async {
    await _bootstrap(forceRefresh: true);
  }

  void _handleScrollMetrics(ScrollMetrics metrics) {
    if (_initialLoading ||
        _loadingMore ||
        _selectedKind == AdminUserKind.worker ||
        _selectedKind == AdminUserKind.qolipchi ||
        !_hasMore) {
      return;
    }
    final viewport = metrics.viewportDimension;
    final prefetchExtentAfter = viewport * _prefetchExtentAfterFactor;
    if (metrics.extentAfter < prefetchExtentAfter) {
      unawaited(_loadMore());
    }
  }

  Future<void> _bootstrap({bool forceRefresh = false}) async {
    if (!forceRefresh && _restoreCache()) {
      return;
    }

    if (mounted) {
      setState(() {
        _initialLoading = true;
        _loadingMore = false;
        _hasMore = true;
        _offset = 0;
        _items.clear();
        _workers.clear();
        _assignments.clear();
      });
    }

    final results = await Future.wait([
      _safeLoadAdminUserList(limit: _pageSize, offset: 0),
      _safeLoadWorkers(),
      _safeLoadRoleAssignments(),
    ]);
    final page = results[0] as AdminUserListPage;
    final workers = results[1] as List<AdminWorker>;
    final assignments = results[2] as List<AdminRoleAssignment>;

    if (!mounted) {
      return;
    }
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _workers
        ..clear()
        ..addAll(workers);
      _assignments
        ..clear()
        ..addAll(assignments);
      _hasMore = page.hasMore;
      _offset = page.items.length;
      _initialLoading = false;
      _loadingMore = false;
    });
    _saveCache();
  }

  Future<void> _loadMore() async {
    if (_selectedKind == AdminUserKind.worker ||
        _selectedKind == AdminUserKind.qolipchi) {
      return;
    }
    if (_loadingMore || _initialLoading) {
      return;
    }
    if (!_hasMore) {
      return;
    }

    if (mounted) {
      setState(() => _loadingMore = true);
    }

    try {
      await _loadNextPages();
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _loadNextPages() async {
    final page =
        await _safeLoadAdminUserList(limit: _pageSize, offset: _offset);
    if (!mounted) {
      return;
    }

    setState(() {
      _items.addAll(page.items);
      _offset += page.items.length;
      _hasMore = page.hasMore;
    });
    _saveCache();
  }

  Future<AdminUserListPage> _safeLoadAdminUserList({
    required int limit,
    required int offset,
  }) async {
    try {
      return await MobileApi.instance.adminUserList(
        query: _searchQuery,
        limit: limit,
        offset: offset,
      );
    } catch (error) {
      debugPrint('admin user list failed: $error');
      return const AdminUserListPage(items: [], hasMore: false);
    }
  }

  Future<List<AdminWorker>> _safeLoadWorkers() async {
    try {
      return await MobileApi.instance.adminWorkers(query: _searchQuery);
    } catch (error) {
      debugPrint('admin workers failed: $error');
      return const <AdminWorker>[];
    }
  }

  Future<List<AdminRoleAssignment>> _safeLoadRoleAssignments() async {
    try {
      return await MobileApi.instance.adminRoleAssignments();
    } catch (error) {
      debugPrint('admin role assignments failed: $error');
      return const <AdminRoleAssignment>[];
    }
  }

  Future<void> _openUser(AdminUserListEntry item) async {
    bool changed = false;
    if (item.kind == AdminUserKind.worker ||
        (item.kind == AdminUserKind.qolipchi && _isWorkerBackedUser(item))) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminWorkerDetail, arguments: item);
      changed = result == true;
    } else if (item.kind == AdminUserKind.qolipchi) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminCustomerDetail, arguments: item);
      changed = result == true;
    } else if (item.kind == AdminUserKind.werka) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminWerka);
      changed = result == true;
    } else if (item.kind == AdminUserKind.customer) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminCustomerDetail, arguments: item.id);
      changed = result == true;
    } else {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminSupplierDetail, arguments: item.id);
      changed = result == true;
    }
    if (changed && mounted) {
      await _bootstrap(forceRefresh: true);
    }
  }

  bool _isWorkerBackedUser(AdminUserListEntry item) {
    final id = item.id.trim().toLowerCase();
    return _workers.any((worker) => worker.id.trim().toLowerCase() == id);
  }

  bool _restoreCache() {
    final cache = _cache;
    if (cache == null) {
      return false;
    }
    if (mounted) {
      setState(() {
        _items
          ..clear()
          ..addAll(cache.items);
        _workers
          ..clear()
          ..addAll(cache.workers);
        _assignments
          ..clear()
          ..addAll(cache.assignments);
        _hasMore = cache.hasMore;
        _offset = cache.offset;
        _searchQuery = cache.query;
        _selectedKind = cache.selectedKind;
        _searchController.text = cache.query;
        _initialLoading = false;
        _loadingMore = false;
      });
    }
    _tabController.index = _adminUserKindIndex(cache.selectedKind);
    return true;
  }

  void _saveCache() {
    _cache = _AdminSuppliersCache(
      items: List<AdminUserListEntry>.unmodifiable(_items),
      workers: List<AdminWorker>.unmodifiable(_workers),
      assignments: List<AdminRoleAssignment>.unmodifiable(_assignments),
      hasMore: _hasMore,
      offset: _offset,
      query: _searchQuery,
      selectedKind: _selectedKind,
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      _searchQuery = value.trim();
      unawaited(_bootstrap(forceRefresh: true));
    });
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _selectKind(AdminUserKind kind) {
    if (_selectedKind == kind) {
      return;
    }
    final index = _adminUserKindIndex(kind);
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
    setState(() => _selectedKind = kind);
    _saveCache();
  }

  List<AdminUserListEntry> _workerEntries(AdminUserKind kind) {
    final isQolipTab = kind == AdminUserKind.qolipchi;
    return [
      for (final worker in _workers)
        if (_workerIsQolipchi(worker, _assignments) == isQolipTab)
          AdminUserListEntry(
            id: worker.id,
            name: worker.name,
            phone: worker.phone,
            kind: kind,
            principalRole: isQolipTab ? UserRole.qolipchi : UserRole.aparatchi,
            roleLabelOverride: isQolipTab ? 'Qolipchi' : worker.level.trim(),
          ),
    ];
  }

  List<AdminUserListEntry> _visibleItems(AdminUserKind kind) {
    if (kind == AdminUserKind.worker || kind == AdminUserKind.qolipchi) {
      return [
        ..._workerEntries(kind),
        ..._items.where((item) => item.kind == kind),
      ];
    }
    return _items.where((item) => item.kind == kind).toList(growable: false);
  }

  Widget _buildUserList(AdminUserKind kind) {
    final visibleItems = _visibleItems(kind);
    final showFooter = kind != AdminUserKind.worker &&
        kind != AdminUserKind.qolipchi &&
        visibleItems.isNotEmpty &&
        (_loadingMore || _hasMore);
    if (_initialLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    return AppRefreshIndicator(
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (kind == _selectedKind) {
            _handleScrollMetrics(notification.metrics);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 116),
          itemCount: visibleItems.isEmpty
              ? 1
              : visibleItems.length + (showFooter ? 1 : 0),
          itemBuilder: (context, index) {
            if (visibleItems.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Text(
                  'Userlar topilmadi',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }
            if (index >= visibleItems.length) {
              if (_loadingMore) {
                return const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Center(child: AppLoadingIndicator()),
                );
              }
              return const SizedBox(height: 14);
            }
            final item = visibleItems[index];
            return Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
              ),
              child: AdminSupplierListRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  visibleItems.length,
                ),
                item: item,
                onTap: () => _openUser(item),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppShell(
      animateOnEnter: false,
      drawer: AdminNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.adminSuppliers,
        onNavigate: _openDrawerRoute,
      ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      titleWidget: _AdminUserSearchField(
        controller: _searchController,
        inAppBar: true,
        onChanged: _onSearchChanged,
        onClear: () {
          _searchController.clear();
          _onSearchChanged('');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: const AdminDock(activeTab: AdminDockTab.suppliers),
      child: Column(
        children: [
          Material(
            color: theme.appBarTheme.backgroundColor ??
                theme.colorScheme.surfaceContainer,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              onTap: (index) => _selectKind(_adminUserTabKinds[index]),
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
              unselectedLabelStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(height: 38, text: 'Omborchi'),
                Tab(height: 38, text: 'Haridor'),
                Tab(height: 38, text: 'Ta’minotchi'),
                Tab(height: 38, text: 'Ishchi'),
                Tab(height: 38, text: 'Qolipchi'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final kind in _adminUserTabKinds) _buildUserList(kind),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserSearchField extends StatelessWidget {
  const _AdminUserSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.inAppBar = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool inAppBar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final field = ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        return TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Foydalanuvchi qidirish',
            isDense: inAppBar,
            prefixIcon: inAppBar
                ? IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).openAppDrawerTooltip,
                    onPressed: () =>
                        AppShellDrawerScope.maybeOf(context)?.openDrawer(),
                  )
                : const Icon(Icons.search_rounded),
            prefixIconConstraints: inAppBar
                ? const BoxConstraints(minWidth: 58, minHeight: 58)
                : null,
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'Tozalash',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            contentPadding: inAppBar
                ? const EdgeInsets.symmetric(vertical: 12)
                : const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(inAppBar ? 999 : 22),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(inAppBar ? 999 : 22),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(inAppBar ? 999 : 22),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
    );
    if (inAppBar) {
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: SizedBox(
          height: AppTheme.appBarHeight,
          child: Align(
            alignment: Alignment.center,
            child: SizedBox(height: 58, width: double.infinity, child: field),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: field,
    );
  }
}

class _AdminSuppliersCache {
  const _AdminSuppliersCache({
    required this.items,
    required this.workers,
    required this.assignments,
    required this.hasMore,
    required this.offset,
    required this.query,
    required this.selectedKind,
  });

  final List<AdminUserListEntry> items;
  final List<AdminWorker> workers;
  final List<AdminRoleAssignment> assignments;
  final bool hasMore;
  final int offset;
  final String query;
  final AdminUserKind selectedKind;
}
