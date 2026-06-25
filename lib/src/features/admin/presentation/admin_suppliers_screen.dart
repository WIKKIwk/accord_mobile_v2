import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_catalog_search_field.dart';
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

String _adminUserKindLabel(AdminUserKind kind) {
  return switch (kind) {
    AdminUserKind.werka => 'Omborchi',
    AdminUserKind.customer => 'Haridor',
    AdminUserKind.supplier => 'Ta’minotchi',
    AdminUserKind.worker => 'Ishchi',
    AdminUserKind.qolipchi => 'Qolipchi',
  };
}

String _adminUserKindSelectionLabel(AdminUserKind? kind) {
  return kind == null ? 'Tanlanmagan' : _adminUserKindLabel(kind);
}

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

class _AdminSuppliersScreenState extends State<AdminSuppliersScreen> {
  static const int _pageSize = 50;
  static const double _prefetchExtentAfterFactor = 2.5;
  static _AdminSuppliersCache? _cache;
  static final ValueNotifier<int> _usersChanged = ValueNotifier<int>(0);

  static void invalidateCache() {
    _cache = null;
    _usersChanged.value++;
  }

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<AdminUserListEntry> _items = [];
  final List<AdminWorker> _workers = [];
  final List<AdminRoleAssignment> _assignments = [];
  Timer? _searchDebounce;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  AdminUserKind? _selectedKind;
  bool _roleMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _usersChanged.addListener(_handleUsersChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    _usersChanged.removeListener(_handleUsersChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
        _selectedKind == null ||
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
    if (_selectedKind == null ||
        _selectedKind == AdminUserKind.worker ||
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
        item.kind == AdminUserKind.qolipchi) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminWorkerDetail, arguments: item);
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
      setState(() => _roleMenuOpen = false);
      return;
    }
    setState(() {
      _selectedKind = kind;
      _roleMenuOpen = false;
    });
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

  List<AdminUserListEntry> _visibleItems(AdminUserKind? kind) {
    if (kind == null) {
      return const <AdminUserListEntry>[];
    }
    if (kind == AdminUserKind.worker || kind == AdminUserKind.qolipchi) {
      return [
        ..._workerEntries(kind),
        ..._items.where((item) => item.kind == kind),
      ];
    }
    return _items.where((item) => item.kind == kind).toList(growable: false);
  }

  Widget _buildUserList(AdminUserKind? kind) {
    final visibleItems = _visibleItems(kind);
    if (kind == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Rollar tanlanmagan',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
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
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Foydalanuvchi qidirish',
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
          _AdminUserRolePicker(
            selectedKind: _selectedKind,
            expanded: _roleMenuOpen,
            onToggle: () => setState(() => _roleMenuOpen = !_roleMenuOpen),
            onSelect: _selectKind,
          ),
          Expanded(child: _buildUserList(_selectedKind)),
        ],
      ),
    );
  }
}

class _AdminUserRolePicker extends StatelessWidget {
  const _AdminUserRolePicker({
    required this.selectedKind,
    required this.expanded,
    required this.onToggle,
    required this.onSelect,
  });

  final AdminUserKind? selectedKind;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<AdminUserKind> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: scheme.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: const ValueKey('admin-users-role-picker'),
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Rollar',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _adminUserKindSelectionLabel(selectedKind),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              Icons.expand_more_rounded,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: scheme.outlineVariant.withValues(
                                alpha: 0.75,
                              ),
                            ),
                            for (int index = 0;
                                index < _adminUserTabKinds.length;
                                index++) ...[
                              if (index > 0)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              _AdminUserRoleOption(
                                kind: _adminUserTabKinds[index],
                                selected:
                                    _adminUserTabKinds[index] == selectedKind,
                                onTap: () =>
                                    onSelect(_adminUserTabKinds[index]),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserRoleOption extends StatelessWidget {
  const _AdminUserRoleOption({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final AdminUserKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _adminUserKindLabel(kind),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: scheme.onSurface),
            ],
          ),
        ),
      ),
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
  final AdminUserKind? selectedKind;
}
