import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
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
  AdminUserKind.materialTaminotchi,
  AdminUserKind.worker,
  AdminUserKind.qolipchi,
  AdminUserKind.boyoqchi,
];

String _adminUserKindLabel(AdminUserKind kind) {
  return switch (kind) {
    AdminUserKind.werka => 'Omborchi',
    AdminUserKind.customer => 'Haridor',
    AdminUserKind.supplier => 'Ta’minotchi',
    AdminUserKind.materialTaminotchi => 'Material taminotchisi',
    AdminUserKind.worker => 'Ishchi',
    AdminUserKind.qolipchi => 'Qolipchi',
    AdminUserKind.boyoqchi => 'Bo‘yoqchi',
  };
}

String _adminUserKindRoleQuery(AdminUserKind kind) {
  return switch (kind) {
    AdminUserKind.werka => 'werka',
    AdminUserKind.customer => 'customer',
    AdminUserKind.supplier => 'supplier',
    AdminUserKind.materialTaminotchi => 'material_taminotchi',
    AdminUserKind.worker => 'worker',
    AdminUserKind.qolipchi => 'qolipchi',
    AdminUserKind.boyoqchi => 'boyoqchi',
  };
}

bool _adminUserKindUsesWorkers(AdminUserKind? kind) {
  return false;
}

bool _assignmentIsMaterialTaminotchi(AdminRoleAssignment assignment) {
  return assignment.principalRole == UserRole.materialTaminotchi ||
      assignment.roleId.trim() == 'material_taminotchi';
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
  Object? _loadError;
  int _requestGeneration = 0;

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
    if (_initialLoading || _loadingMore || _selectedKind == null || !_hasMore) {
      return;
    }
    final viewport = metrics.viewportDimension;
    final prefetchExtentAfter = viewport * _prefetchExtentAfterFactor;
    if (metrics.extentAfter < prefetchExtentAfter) {
      unawaited(_loadMore());
    }
  }

  Future<void> _bootstrap({bool forceRefresh = false}) async {
    final generation = ++_requestGeneration;
    final sessionRevision = AppSession.instance.revision.value;
    if (!forceRefresh && _restoreCache(sessionRevision)) {
      return;
    }

    final query = _searchQuery;
    final selectedKind = _selectedKind;

    if (mounted) {
      setState(() {
        _initialLoading = true;
        _loadingMore = false;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait<Object>([
        _loadAdminUserList(
          query: query,
          selectedKind: selectedKind,
          limit: _pageSize,
          offset: 0,
        ),
        _loadWorkers(query: query, selectedKind: selectedKind),
        _loadRoleAssignments(),
      ]);
      if (!_isCurrentRequest(
        generation,
        query,
        selectedKind,
        sessionRevision,
      )) {
        return;
      }
      final page = results[0] as AdminUserListPage;
      final workers = results[1] as List<AdminWorker>;
      final assignments = results[2] as List<AdminRoleAssignment>;

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
        _loadError = null;
      });
      _saveCache(sessionRevision);
    } catch (error) {
      debugPrint('admin users bootstrap failed: $error');
      if (!_isCurrentRequest(
        generation,
        query,
        selectedKind,
        sessionRevision,
      )) {
        return;
      }
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _loadError = error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_selectedKind == null) {
      return;
    }
    if (_loadingMore || _initialLoading) {
      return;
    }
    if (!_hasMore) {
      return;
    }

    final generation = _requestGeneration;
    final query = _searchQuery;
    final selectedKind = _selectedKind;
    final offset = _offset;
    final sessionRevision = AppSession.instance.revision.value;
    setState(() => _loadingMore = true);

    try {
      final page = await _loadAdminUserList(
        query: query,
        selectedKind: selectedKind,
        limit: _pageSize,
        offset: offset,
      );
      if (!_isCurrentRequest(
            generation,
            query,
            selectedKind,
            sessionRevision,
          ) ||
          _offset != offset) {
        return;
      }
      setState(() {
        _items.addAll(page.items);
        _offset += page.items.length;
        _hasMore = page.hasMore;
      });
      _saveCache(sessionRevision);
    } catch (error) {
      debugPrint('admin user list next page failed: $error');
      if (!mounted ||
          !_isCurrentRequest(
            generation,
            query,
            selectedKind,
            sessionRevision,
          )) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Userlarning keyingi qismi yuklanmadi. Qayta urinib ko‘ring.',
          ),
        ),
      );
    } finally {
      if (_isCurrentRequest(
        generation,
        query,
        selectedKind,
        sessionRevision,
      )) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<AdminUserListPage> _loadAdminUserList({
    required String query,
    required AdminUserKind? selectedKind,
    required int limit,
    required int offset,
  }) async {
    if (selectedKind == null || _adminUserKindUsesWorkers(selectedKind)) {
      return const AdminUserListPage(items: [], hasMore: false);
    }
    return MobileApi.instance.adminUserList(
      query: query,
      limit: limit,
      offset: offset,
      role: _adminUserKindRoleQuery(selectedKind),
    );
  }

  Future<List<AdminWorker>> _loadWorkers({
    required String query,
    required AdminUserKind? selectedKind,
  }) async {
    if (!_adminUserKindUsesWorkers(selectedKind)) {
      return const <AdminWorker>[];
    }
    return MobileApi.instance.adminWorkers(
      query: query,
      role: _adminUserKindRoleQuery(selectedKind!),
    );
  }

  Future<List<AdminRoleAssignment>> _loadRoleAssignments() {
    return MobileApi.instance.adminRoleAssignments();
  }

  bool _isCurrentRequest(
    int generation,
    String query,
    AdminUserKind? selectedKind,
    int sessionRevision,
  ) {
    return mounted &&
        generation == _requestGeneration &&
        query == _searchQuery &&
        selectedKind == _selectedKind &&
        sessionRevision == AppSession.instance.revision.value;
  }

  Future<void> _openUser(AdminUserListEntry item) async {
    bool changed = false;
    if (item.kind == AdminUserKind.worker ||
        item.kind == AdminUserKind.qolipchi ||
        item.kind == AdminUserKind.boyoqchi) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminWorkerDetail, arguments: item);
      changed = result == true;
    } else if (item.kind == AdminUserKind.werka) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminWerka, arguments: item);
      changed = result == true;
    } else if (item.kind == AdminUserKind.customer ||
        item.kind == AdminUserKind.materialTaminotchi) {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminCustomerDetail, arguments: item);
      changed = result == true;
    } else {
      final result = await Navigator.of(
        context,
      ).pushNamed(AppRoutes.adminSupplierDetail, arguments: item);
      changed = result == true;
    }
    if (changed && mounted) {
      await _bootstrap(forceRefresh: true);
    }
  }

  bool _restoreCache(int sessionRevision) {
    final cache = _cache;
    if (cache == null) {
      return false;
    }
    if (cache.sessionRevision != sessionRevision) {
      _cache = null;
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
        _loadError = null;
      });
    }
    return true;
  }

  void _saveCache(int sessionRevision) {
    _cache = _AdminSuppliersCache(
      sessionRevision: sessionRevision,
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
    final query = value.trim();
    if (query == _searchQuery) {
      return;
    }
    _requestGeneration++;
    setState(() {
      _searchQuery = query;
      _initialLoading = true;
      _loadingMore = false;
      _loadError = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
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
    _requestGeneration++;
    setState(() {
      _selectedKind = kind;
      _roleMenuOpen = false;
      _initialLoading = true;
      _loadingMore = false;
      _loadError = null;
    });
    unawaited(_bootstrap(forceRefresh: true));
  }

  List<AdminUserListEntry> _workerEntries(AdminUserKind kind) {
    return [
      for (final worker in _workers)
        AdminUserListEntry(
          id: worker.id,
          name: worker.name,
          phone: worker.phone,
          kind: AdminUserKind.worker,
          principalRole: UserRole.aparatchi,
          roleLabelOverride: worker.level.trim(),
        ),
    ];
  }

  bool _itemIsMaterialTaminotchi(AdminUserListEntry item) {
    if (item.kind == AdminUserKind.materialTaminotchi ||
        item.principalRole == UserRole.materialTaminotchi) {
      return true;
    }
    final itemRef = item.id.trim().toLowerCase();
    return _assignments.any((assignment) {
      return assignment.principalRef.trim().toLowerCase() == itemRef &&
          _assignmentIsMaterialTaminotchi(assignment);
    });
  }

  AdminUserListEntry _materialTaminotchiEntry(AdminUserListEntry item) {
    if (item.kind == AdminUserKind.materialTaminotchi &&
        item.principalRole == UserRole.materialTaminotchi) {
      return item;
    }
    return AdminUserListEntry(
      id: item.id,
      name: item.name,
      phone: item.phone,
      kind: AdminUserKind.materialTaminotchi,
      avatarUrl: item.avatarUrl,
      principalRole: UserRole.materialTaminotchi,
      blocked: item.blocked,
      roleLabelOverride: 'Material taminotchisi',
    );
  }

  List<AdminUserListEntry> _visibleItems(AdminUserKind? kind) {
    if (kind == null) {
      return const <AdminUserListEntry>[];
    }
    if (kind == AdminUserKind.materialTaminotchi) {
      return _items
          .where(_itemIsMaterialTaminotchi)
          .map(_materialTaminotchiEntry)
          .toList(growable: false);
    }
    if (kind == AdminUserKind.worker) {
      return [
        ..._workerEntries(kind),
        ..._items.where((item) => item.kind == kind),
      ];
    }
    if (kind == AdminUserKind.customer) {
      return _items
          .where(
            (item) =>
                item.kind == AdminUserKind.customer &&
                !_itemIsMaterialTaminotchi(item),
          )
          .toList(growable: false);
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
    final showFooter = kind != AdminUserKind.qolipchi &&
        kind != AdminUserKind.boyoqchi &&
        visibleItems.isNotEmpty &&
        (_loadingMore || _hasMore);
    if (_initialLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_loadError != null) {
      return AppRetryState(
        onRetry: _reload,
        message: 'Userlar yuklanmadi. Qayta urinib ko‘ring.',
      );
    }
    return AppRefreshIndicator(
      onRefresh: _reload,
      allowRefreshOnShortContent: true,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (kind == _selectedKind) {
            _handleScrollMetrics(notification.metrics);
          }
          return false;
        },
        child: ListView.builder(
          physics: const TopRefreshScrollPhysics(),
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
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
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
      bottom: const AdminDock(activeTab: AdminDockTab.user),
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
    final selectedLabel =
        selectedKind == null ? null : _adminUserKindLabel(selectedKind!);
    return AdminExpandableFilterChip<AdminUserKind>(
      chipKey: const ValueKey('admin-users-role-filter-chip'),
      label: 'Rol',
      emptyLabel: selectedLabel ?? 'Tanlanmagan',
      icon: Icons.person_outline_rounded,
      selectedValue: selectedKind,
      expanded: expanded,
      onToggle: onToggle,
      onSelect: onSelect,
      optionKeyPrefix: 'admin-users-role-option-chip',
      options: [
        for (final kind in _adminUserTabKinds)
          AdminFilterChipOption(
            value: kind,
            label: _adminUserKindLabel(kind),
            key: ValueKey('admin-users-role-option-chip-${kind.name}'),
          ),
      ],
    );
  }
}

class _AdminSuppliersCache {
  const _AdminSuppliersCache({
    required this.sessionRevision,
    required this.items,
    required this.workers,
    required this.assignments,
    required this.hasMore,
    required this.offset,
    required this.query,
    required this.selectedKind,
  });

  final int sessionRevision;
  final List<AdminUserListEntry> items;
  final List<AdminWorker> workers;
  final List<AdminRoleAssignment> assignments;
  final bool hasMore;
  final int offset;
  final String query;
  final AdminUserKind? selectedKind;
}
