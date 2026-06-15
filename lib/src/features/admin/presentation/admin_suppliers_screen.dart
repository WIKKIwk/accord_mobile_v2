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
import 'widgets/admin_supplier_list_module.dart';

class AdminSuppliersScreen extends StatefulWidget {
  const AdminSuppliersScreen({super.key});

  static void invalidateCache() {
    _AdminSuppliersScreenState.invalidateCache();
  }

  @override
  State<AdminSuppliersScreen> createState() => _AdminSuppliersScreenState();
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

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<AdminUserListEntry> _items = [];
  Timer? _searchDebounce;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String _searchQuery = '';
  bool _openingRoute = false;

  @override
  void initState() {
    super.initState();
    _usersChanged.addListener(_handleUsersChanged);
    _scrollController.addListener(_handleScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _usersChanged.removeListener(_handleUsersChanged);
    _scrollController.removeListener(_handleScroll);
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleUsersChanged() {
    unawaited(_bootstrap(forceRefresh: true));
  }

  Future<void> _reload() async {
    await _bootstrap(forceRefresh: true);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _initialLoading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    final viewport = _scrollController.position.viewportDimension;
    final prefetchExtentAfter = viewport * _prefetchExtentAfterFactor;
    if (_scrollController.position.extentAfter < prefetchExtentAfter) {
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
      });
    }

    final page = await _safeLoadAdminUserList(limit: _pageSize, offset: 0);

    if (!mounted) {
      return;
    }
    setState(() {
      _items
        ..clear()
        ..addAll(page.items);
      _hasMore = page.hasMore;
      _offset = page.items.length;
      _initialLoading = false;
      _loadingMore = false;
    });
    _saveCache();
  }

  Future<void> _loadMore() async {
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

  Future<void> _openUser(AdminUserListEntry item) async {
    bool changed = false;
    if (item.kind == AdminUserKind.werka) {
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
        _hasMore = cache.hasMore;
        _offset = cache.offset;
        _searchQuery = cache.query;
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
      hasMore: _hasMore,
      offset: _offset,
      query: _searchQuery,
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
    if (_openingRoute) {
      return;
    }
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    _openingRoute = true;
    Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _items;
    final showFooter = visibleItems.isNotEmpty && (_loadingMore || _hasMore);
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
      child: _initialLoading
          ? const Center(child: AppLoadingIndicator())
          : AppRefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                controller: _scrollController,
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
    required this.hasMore,
    required this.offset,
    required this.query,
  });

  final List<AdminUserListEntry> items;
  final bool hasMore;
  final int offset;
  final String query;
}
