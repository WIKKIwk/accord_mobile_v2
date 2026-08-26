import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/lists/m3_animated_list_entry.dart';
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

String _adminUserKindLabel(AppLocalizations l10n, AdminUserKind kind) {
  return switch (kind) {
    AdminUserKind.werka => l10n.adminText('users.kind.werka'),
    AdminUserKind.customer => l10n.adminText('users.kind.customer'),
    AdminUserKind.supplier => l10n.adminText('users.kind.supplier'),
    AdminUserKind.materialTaminotchi =>
      l10n.adminText('users.kind.material_supplier'),
    AdminUserKind.worker => l10n.adminText('users.kind.worker'),
    AdminUserKind.qolipchi => l10n.adminText('users.kind.mold_maker'),
    AdminUserKind.boyoqchi => l10n.adminText('users.kind.painter'),
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
  final ScrollController _usersScrollController = ScrollController();
  final List<AdminUserListEntry> _items = [];
  final Map<String, AdminUserListEntry> _exitingItems = {};
  final Set<String> _enteringItemKeys = {};
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
  int _listAnimationGeneration = 0;
  bool _animateNextListUpdate = false;

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
    _usersScrollController.dispose();
    super.dispose();
  }

  void _handleUsersChanged() {
    _animateNextListUpdate = false;
    unawaited(_bootstrap(forceRefresh: true));
  }

  Future<void> _reload() async {
    _animateNextListUpdate = false;
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

      _applyUserListResult(
        page: page,
        workers: workers,
        assignments: assignments,
      );
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
      _animateNextListUpdate = false;
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _loadError = error;
      });
    }
  }

  void _applyUserListResult({
    required AdminUserListPage page,
    required List<AdminWorker> workers,
    required List<AdminRoleAssignment> assignments,
  }) {
    final previousIds = _items.map((item) => item.id).toSet();
    final nextIds = page.items.map((item) => item.id).toSet();
    final exitingItems = _animateNextListUpdate
        ? _items.where((item) => !nextIds.contains(item.id)).toList()
        : const <AdminUserListEntry>[];
    final enteringKeys = _animateNextListUpdate
        ? page.items
            .where((item) => !previousIds.contains(item.id))
            .map((item) => item.id)
            .toSet()
        : <String>{};
    final animationGeneration = ++_listAnimationGeneration;
    _animateNextListUpdate = false;

    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _exitingItems
        ..clear()
        ..addEntries(
          exitingItems.map((item) => MapEntry(item.id, item)),
        );
      _enteringItemKeys
        ..clear()
        ..addAll(enteringKeys);
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

    if (exitingItems.isNotEmpty || enteringKeys.isNotEmpty) {
      unawaited(
        Future<void>.delayed(m3ListMutationAnimationDuration).then((_) {
          if (!mounted || animationGeneration != _listAnimationGeneration) {
            return;
          }
          setState(() {
            _exitingItems.clear();
            _enteringItemKeys.removeAll(enteringKeys);
          });
        }),
      );
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
        SnackBar(
          content: Text(
            context.l10n.adminText('users.next_page_failed'),
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

  void _resetUsersScroll() {
    if (_usersScrollController.hasClients) {
      _usersScrollController.jumpTo(0);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query == _searchQuery) {
      return;
    }
    _requestGeneration++;
    _animateNextListUpdate = true;
    _listAnimationGeneration++;
    _resetUsersScroll();
    setState(() {
      _searchQuery = query;
      _exitingItems.clear();
      _enteringItemKeys.clear();
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
    _animateNextListUpdate = false;
    _listAnimationGeneration++;
    _resetUsersScroll();
    setState(() {
      _selectedKind = kind;
      _exitingItems.clear();
      _enteringItemKeys.clear();
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

  AdminUserListEntry _materialTaminotchiEntry(
    AdminUserListEntry item,
    AppLocalizations l10n,
  ) {
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
      roleLabelOverride: l10n.adminText('users.kind.material_supplier'),
    );
  }

  List<AdminUserListEntry> _visibleItems(AdminUserKind? kind) {
    if (kind == null) {
      return const <AdminUserListEntry>[];
    }
    late final List<AdminUserListEntry> items;
    if (kind == AdminUserKind.materialTaminotchi) {
      items = _items
          .where(_itemIsMaterialTaminotchi)
          .map((item) => _materialTaminotchiEntry(item, context.l10n))
          .toList(growable: false);
    } else if (kind == AdminUserKind.worker) {
      items = [
        ..._workerEntries(kind),
        ..._items.where((item) => item.kind == kind),
      ];
    } else if (kind == AdminUserKind.customer) {
      items = _items
          .where(
            (item) =>
                item.kind == AdminUserKind.customer &&
                !_itemIsMaterialTaminotchi(item),
          )
          .toList(growable: false);
    } else {
      items = _items.where((item) => item.kind == kind).toList();
    }

    final exitingItems = _exitingItems.values.where((item) {
      if (kind == AdminUserKind.materialTaminotchi) {
        return _itemIsMaterialTaminotchi(item);
      }
      if (kind == AdminUserKind.worker) {
        return item.kind == kind;
      }
      if (kind == AdminUserKind.customer) {
        return item.kind == AdminUserKind.customer &&
            !_itemIsMaterialTaminotchi(item);
      }
      return item.kind == kind;
    }).map((item) {
      return kind == AdminUserKind.materialTaminotchi
          ? _materialTaminotchiEntry(item, context.l10n)
          : item;
    });
    return [...items, ...exitingItems];
  }

  Widget _buildUserList(AdminUserKind? kind) {
    final l10n = context.l10n;
    final visibleItems = _visibleItems(kind);
    if (kind == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.adminText('users.not_selected'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (_loadError != null) {
      return AppRetryState(
        onRetry: _reload,
        message: l10n.adminText('users.load_failed'),
      );
    }
    final list = _buildLoadedUserList(kind, visibleItems, l10n);
    if (_initialLoading) {
      if (_items.isEmpty && _exitingItems.isEmpty) {
        return const Center(child: AppLoadingIndicator());
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Opacity(opacity: 0, child: list),
          ),
          const Center(child: AppLoadingIndicator()),
        ],
      );
    }
    return list;
  }

  Widget _buildLoadedUserList(
    AdminUserKind kind,
    List<AdminUserListEntry> visibleItems,
    AppLocalizations l10n,
  ) {
    final showFooter = kind != AdminUserKind.qolipchi &&
        kind != AdminUserKind.boyoqchi &&
        visibleItems.isNotEmpty &&
        (_loadingMore || _hasMore);
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
          controller: _usersScrollController,
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
                  l10n.adminText('users.not_found'),
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
            final exiting = _exitingItems.containsKey(item.id);
            return Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
              ),
              child: M3AnimatedListEntry(
                key: ValueKey('admin-user-animation-${item.id}'),
                visible: !exiting,
                animateIn: _enteringItemKeys.contains(item.id),
                transitionKey: ValueKey(
                  exiting
                      ? 'admin-user-exiting-${item.id}'
                      : 'admin-user-transition-${item.id}',
                ),
                revision: '${item.name}:${item.phone}:${item.roleLabel}:'
                    '${item.blocked}',
                child: IgnorePointer(
                  ignoring: exiting,
                  child: AdminSupplierListRow(
                    key: ValueKey('admin-user-${item.id}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      visibleItems.length,
                    ),
                    item: item,
                    onTap: () => _openUser(item),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        hintText: l10n.adminText('users.search'),
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
    final l10n = context.l10n;
    final selectedLabel =
        selectedKind == null ? null : _adminUserKindLabel(l10n, selectedKind!);
    return AdminExpandableFilterChip<AdminUserKind>(
      chipKey: const ValueKey('admin-users-role-filter-chip'),
      label: l10n.adminText('users.role'),
      emptyLabel: selectedLabel ?? l10n.adminText('users.none_selected'),
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
            label: _adminUserKindLabel(l10n, kind),
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
