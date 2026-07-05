import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'admin_item_group_bulk_move_screen.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_top_notice.dart';
import 'dart:async';
import 'package:flutter/material.dart';

const double _itemCreateCardRadius = 18;
const double _itemCreateFieldRadius = 18;

class AdminItemCreateScreen extends StatefulWidget {
  const AdminItemCreateScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<AdminItemCreateScreen> createState() => _AdminItemCreateScreenState();
}

class _AdminItemCreateScreenState extends State<AdminItemCreateScreen>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 2;

  final TextEditingController code = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController itemGroup = TextEditingController();
  final TextEditingController uom = TextEditingController(text: 'Kg');
  final TextEditingController _itemsSearchController = TextEditingController();
  final FocusNode _itemsSearchFocusNode = FocusNode();
  final GlobalKey<_AdminItemsListTabState> _itemsListTabKey =
      GlobalKey<_AdminItemsListTabState>();
  late final Future<List<String>> itemGroupsFuture;
  late final TabController _tabController;
  CustomerDirectoryEntry? selectedCustomer;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final initialIndex = _resolveInitialTabIndex(widget.initialTabIndex);
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _itemsSearchFocusNode.addListener(_handleItemsSearchFocus);
    itemGroupsFuture = _loadItemGroups();
    _hydrateDefaultUom();
  }

  int _resolveInitialTabIndex(int requestedIndex) {
    if (requestedIndex >= 2) {
      return 1;
    }
    return 0;
  }

  @override
  void dispose() {
    _itemsSearchFocusNode.removeListener(_handleItemsSearchFocus);
    _itemsSearchFocusNode.dispose();
    _itemsSearchController.dispose();
    _tabController.dispose();
    code.dispose();
    name.dispose();
    itemGroup.dispose();
    uom.dispose();
    super.dispose();
  }

  void _handleItemsSearchFocus() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _hydrateDefaultUom() async {
    try {
      final settings = await MobileApi.instance.adminSettings();
      if (!mounted) {
        return;
      }
      final currentValue = uom.text.trim();
      if (currentValue.isEmpty || currentValue == 'Kg') {
        final defaultUom = settings.defaultUom.trim();
        uom.text = defaultUom.isEmpty ? 'Kg' : defaultUom;
      }
    } catch (_) {}
  }

  Future<List<String>> _loadItemGroups() async {
    try {
      final tree = await MobileApi.instance.adminItemGroupTree();
      final ordered = orderAdminItemGroupsByParent(tree);
      if (ordered.isNotEmpty) {
        return ordered;
      }
    } catch (_) {}
    return MobileApi.instance.adminItemGroups();
  }

  void _syncItemGroupSelection(List<String> groups) {
    final current = itemGroup.text.trim();
    if (current.isNotEmpty && groups.contains(current)) {
      return;
    }
    final fallback = groups.contains('All Item Groups')
        ? 'All Item Groups'
        : (groups.isNotEmpty ? groups.first : '');
    if (fallback.isNotEmpty) {
      itemGroup.text = fallback;
    }
  }

  Future<bool> _save() async {
    final group = itemGroup.text.trim();
    if (_isFinishedGoodsGroup(group) && selectedCustomer == null) {
      showAdminTopNotice(context, 'Tayyor mahsulot uchun customer tanlang');
      return false;
    }
    setState(() => saving = true);
    try {
      if (await _itemAlreadyExists()) {
        if (mounted) {
          showAdminTopNotice(context, 'Item allaqachon yaratilgan');
        }
        return false;
      }
      final item = await MobileApi.instance.adminCreateItem(
        code: code.text.trim(),
        name: name.text.trim(),
        uom: uom.text.trim(),
        itemGroup: group,
        customerRef: _isFinishedGoodsGroup(group)
            ? selectedCustomer?.ref.trim() ?? ''
            : '',
      );
      if (!mounted) {
        return false;
      }
      code.clear();
      name.clear();
      selectedCustomer = null;
      AdminItemsListTab.clearMemoryCache();
      await _itemsListTabKey.currentState?._loadFirstPage(forceRefresh: true);
      if (!mounted) {
        return true;
      }
      showAdminTopNotice(context, 'Item yaratildi: ${item.code}');
      return true;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(context, 'Item yaratilmadi');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<bool> _itemAlreadyExists() async {
    final itemCode = code.text.trim();
    final itemName = name.text.trim();
    final query = itemCode.isNotEmpty ? itemCode : itemName;
    if (query.isEmpty) {
      return false;
    }
    final items = await MobileApi.instance.adminItemsPage(
      query: query,
      limit: 5,
    );
    final normalizedCode = itemCode.toLowerCase();
    final normalizedName = itemName.toLowerCase();
    return items.any((item) {
      final codeMatches = normalizedCode.isNotEmpty &&
          item.code.trim().toLowerCase() == normalizedCode;
      final nameMatches = normalizedName.isNotEmpty &&
          item.name.trim().toLowerCase() == normalizedName;
      return codeMatches || nameMatches;
    });
  }

  Future<void> _openItemGroupPicker(List<String> groups) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<String>(
          title: 'Item group tanlang',
          hintText: 'Item group qidiring',
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? groups
                : groups.where((group) {
                    return group.toLowerCase().contains(normalizedQuery);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (group) => group,
          itemSubtitle: (_) => '',
          onSelected: (group) => Navigator.of(context).pop(group),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      itemGroup.text = picked;
      if (!_isFinishedGoodsGroup(picked)) {
        selectedCustomer = null;
      }
    });
  }

  Future<void> _openCustomerPicker() async {
    final picked = await showModalBottomSheet<CustomerDirectoryEntry>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<CustomerDirectoryEntry>(
          title: 'Customer tanlang',
          hintText: 'Customer qidiring',
          pageSize: 50,
          cacheKey: 'admin:item-create-customers',
          loadPage: (query, offset, limit) {
            return MobileApi.instance.adminCustomers(
              query: query,
              limit: limit,
              offset: offset,
            );
          },
          itemTitle: (customer) => customer.name,
          itemSubtitle: (customer) => '${customer.ref} • ${customer.phone}',
          onSelected: (customer) => Navigator.of(context).pop(customer),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => selectedCustomer = picked);
  }

  Future<void> _openItemCreateDialog() async {
    code.clear();
    name.clear();
    selectedCustomer = null;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ItemCreateDialogCard(
                code: code,
                name: name,
                itemGroup: itemGroup,
                uom: uom,
                selectedCustomer: selectedCustomer,
                itemGroupsFuture: itemGroupsFuture,
                saving: saving,
                onSyncItemGroup: _syncItemGroupSelection,
                onOpenItemGroupPicker: (groups) async {
                  await _openItemGroupPicker(groups);
                  if (context.mounted) {
                    setDialogState(() {});
                  }
                },
                onOpenCustomerPicker: () async {
                  await _openCustomerPicker();
                  if (context.mounted) {
                    setDialogState(() {});
                  }
                },
                onClearCustomer: () {
                  setState(() => selectedCustomer = null);
                  setDialogState(() {});
                },
                onSave: saving
                    ? null
                    : () async {
                        final saved = await _save();
                        if (saved && dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        } else if (context.mounted) {
                          setDialogState(() {});
                        }
                      },
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchActive = _itemsSearchFocusNode.hasFocus;
    return AppShell(
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _itemsSearchFocusNode,
      showProfileActionResolver: () => !_itemsSearchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _itemsSearchController,
        focusNode: _itemsSearchFocusNode,
        hintText: 'Mahsulot qidirish',
        onChanged: (value) =>
            _itemsListTabKey.currentState?.notifySearchChanged(value),
        onClear: () {
          _itemsSearchController.clear();
          _itemsListTabKey.currentState?.notifySearchChanged('');
        },
        searchCloseKey: const ValueKey('admin-item-search-close'),
      ),
      bottom: AdminDock(
        activeTab: AdminDockTab.settings,
        primaryFabActions: [
          AdminFabMenuAction(
            title: 'Item qo‘shish',
            icon: Icons.inventory_2_outlined,
            onTap: _openItemCreateDialog,
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: searchActive
                  ? const SizedBox.shrink()
                  : AdminSurfaceTabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(height: 38, text: 'Itemlar'),
                        Tab(height: 38, text: "Group ko'chirish"),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: AppTheme.shellStart(context),
              child: TabBarView(
                controller: _tabController,
                children: [
                  AdminItemsListTab(
                    key: _itemsListTabKey,
                    searchController: _itemsSearchController,
                    embeddedSearchInAppBar: true,
                    loadItemsPage: ({
                      required query,
                      required limit,
                      required offset,
                    }) =>
                        MobileApi.instance.adminItemsPage(
                      query: query,
                      limit: limit,
                      offset: offset,
                    ),
                  ),
                  AdminItemGroupBulkMoveTab(
                    embedded: true,
                    searchController: _itemsSearchController,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCreateDialogCard extends StatelessWidget {
  const _ItemCreateDialogCard({
    required this.code,
    required this.name,
    required this.itemGroup,
    required this.uom,
    required this.selectedCustomer,
    required this.itemGroupsFuture,
    required this.saving,
    required this.onSyncItemGroup,
    required this.onOpenItemGroupPicker,
    required this.onOpenCustomerPicker,
    required this.onClearCustomer,
    required this.onSave,
    required this.onClose,
  });

  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController itemGroup;
  final TextEditingController uom;
  final CustomerDirectoryEntry? selectedCustomer;
  final Future<List<String>> itemGroupsFuture;
  final bool saving;
  final ValueChanged<List<String>> onSyncItemGroup;
  final ValueChanged<List<String>> onOpenItemGroupPicker;
  final VoidCallback onOpenCustomerPicker;
  final VoidCallback onClearCustomer;
  final VoidCallback? onSave;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldSurface = theme.brightness == Brightness.light
        ? scheme.surfaceBright
        : scheme.surface;
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(_itemCreateCardRadius),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 48, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('admin-item-create-code'),
                    controller: code,
                    decoration: appSoftInputDecoration(
                      context,
                      labelText: 'Mahsulot kodi',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('admin-item-create-name'),
                    controller: name,
                    decoration: appSoftInputDecoration(
                      context,
                      labelText: 'Mahsulot nomi',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<String>>(
                    future: itemGroupsFuture,
                    builder: (context, snapshot) {
                      final groups = snapshot.data ?? const <String>[];
                      if (snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError) {
                        onSyncItemGroup(groups);
                      }
                      final selectedGroup = itemGroup.text.trim().isEmpty
                          ? null
                          : itemGroup.text.trim();
                      final requiresCustomer = _isFinishedGoodsGroup(
                        selectedGroup ?? '',
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Mahsulot guruhi',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _TapBox(
                            key: const ValueKey(
                              'admin-item-create-group-picker',
                            ),
                            onTap: snapshot.connectionState ==
                                        ConnectionState.done &&
                                    !snapshot.hasError &&
                                    !saving
                                ? () => onOpenItemGroupPicker(groups)
                                : null,
                            borderRadius: _itemCreateFieldRadius,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 58),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: fieldSurface,
                                borderRadius: BorderRadius.circular(
                                  _itemCreateFieldRadius,
                                ),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedGroup ?? 'Guruh tanlang',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: selectedGroup == null
                                            ? scheme.onSurfaceVariant
                                            : scheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (requiresCustomer) ...[
                            Text(
                              'Haridor',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _TapBox(
                              key: const ValueKey(
                                'admin-item-create-customer-picker',
                              ),
                              onTap: saving ? null : onOpenCustomerPicker,
                              borderRadius: _itemCreateFieldRadius,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 58),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: fieldSurface,
                                  borderRadius: BorderRadius.circular(
                                    _itemCreateFieldRadius,
                                  ),
                                  border: Border.all(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selectedCustomer == null
                                            ? 'Haridor tanlang'
                                            : selectedCustomer!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          color: selectedCustomer == null
                                              ? scheme.onSurfaceVariant
                                              : scheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (selectedCustomer != null) ...[
                                      const SizedBox(width: 10),
                                      IconButton(
                                        tooltip: 'Tozalash',
                                        onPressed:
                                            saving ? null : onClearCustomer,
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.expand_more_rounded,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                  ),
                  TextField(
                    controller: uom,
                    decoration: appSoftInputDecoration(
                      context,
                      labelText: 'O‘lchov birligi',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('admin-item-create-submit'),
                      onPressed: onSave,
                      child: Text(
                        saving ? 'Yaratilmoqda...' : 'Item qo‘shish',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: IconButton(
                onPressed: saving ? null : onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Yopish',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isFinishedGoodsGroup(String group) {
  return group.trim().toLowerCase() == 'tayyor mahsulot';
}

typedef AdminItemsPageLoader = Future<List<SupplierItem>> Function({
  required String query,
  required int limit,
  required int offset,
});

class AdminItemsListTab extends StatefulWidget {
  const AdminItemsListTab({
    super.key,
    required this.loadItemsPage,
    this.searchController,
    this.embeddedSearchInAppBar = false,
  });

  final AdminItemsPageLoader loadItemsPage;
  final TextEditingController? searchController;
  final bool embeddedSearchInAppBar;

  static void clearMemoryCache() {
    _AdminItemsListTabState._memoryCache = null;
  }

  @override
  State<AdminItemsListTab> createState() => _AdminItemsListTabState();
}

class _AdminItemsListTabState extends State<AdminItemsListTab>
    with AutomaticKeepAliveClientMixin<AdminItemsListTab> {
  static const int _pageSize = 80;
  static const double _loadMoreExtent = 420;
  static _AdminItemsMemoryCache? _memoryCache;

  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _searchController;
  late final bool _ownsSearchController;
  Timer? _debounce;
  String _query = '';
  List<SupplierItem> _items = const <SupplierItem>[];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ownsSearchController = widget.searchController == null;
    _searchController = widget.searchController ?? TextEditingController();
    _scrollController.addListener(_handleScroll);
    if (!_restoreMemoryCache()) {
      _loadFirstPage(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    if (_ownsSearchController) {
      _searchController.dispose();
    }
    super.dispose();
  }

  void notifySearchChanged(String value) {
    _handleSearchChanged(value);
  }

  void _handleSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _query = value.trim();
      _loadFirstPage(forceRefresh: true);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients ||
        _initialLoading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    if (_scrollController.position.extentAfter <= _loadMoreExtent) {
      _loadNextPage();
    }
  }

  bool _restoreMemoryCache() {
    final cache = _memoryCache;
    if (cache == null) {
      return false;
    }
    _query = cache.query;
    _searchController.text = cache.query;
    _items = cache.items;
    _initialLoading = false;
    _loadingMore = false;
    _hasMore = cache.hasMore;
    _error = null;
    return true;
  }

  void _saveMemoryCache() {
    _memoryCache = _AdminItemsMemoryCache(
      query: _query,
      items: List<SupplierItem>.unmodifiable(_items),
      hasMore: _hasMore,
    );
  }

  Future<void> _loadFirstPage({bool forceRefresh = false}) async {
    if (!forceRefresh && _restoreMemoryCache()) {
      setState(() {});
      return;
    }
    setState(() {
      _items = const <SupplierItem>[];
      _initialLoading = true;
      _loadingMore = false;
      _hasMore = false;
      _error = null;
    });
    await _fetchPage(offset: 0, replace: true);
  }

  Future<void> _loadNextPage() async {
    if (_initialLoading || _loadingMore || !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    await _fetchPage(offset: _items.length, replace: false);
  }

  Future<void> _fetchPage({required int offset, required bool replace}) async {
    final query = _query;
    try {
      final page = await widget.loadItemsPage(
        query: query,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted || query != _query) {
        return;
      }
      setState(() {
        _items = replace ? page : <SupplierItem>[..._items, ...page];
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = page.length == _pageSize;
        _error = null;
      });
      _saveMemoryCache();
    } catch (error) {
      if (!mounted || query != _query) {
        return;
      }
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: AppTheme.shellStart(context),
      child: RefreshIndicator.noSpinner(
        onRefresh: () => _loadFirstPage(forceRefresh: true),
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(4, 12, 4, bottomPadding),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (!widget.embeddedSearchInAppBar) ...[
              SearchBar(
                controller: _searchController,
                hintText: 'Mahsulot qidirish',
                constraints: const BoxConstraints(minHeight: 58),
                padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                  EdgeInsets.symmetric(horizontal: 18),
                ),
                leading: Icon(
                  Icons.search_rounded,
                  size: 26,
                  color: scheme.onSurfaceVariant,
                ),
                elevation: const WidgetStatePropertyAll<double>(0),
                onChanged: _handleSearchChanged,
              ),
              const SizedBox(height: 12),
            ],
            _AdminItemsListBody(
              items: _items,
              initialLoading: _initialLoading,
              loadingMore: _loadingMore,
              hasMore: _hasMore,
              error: _error,
              onRetry: () => _loadFirstPage(forceRefresh: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminItemsMemoryCache {
  const _AdminItemsMemoryCache({
    required this.query,
    required this.items,
    required this.hasMore,
  });

  final String query;
  final List<SupplierItem> items;
  final bool hasMore;
}

class _AdminItemsListBody extends StatelessWidget {
  const _AdminItemsListBody({
    required this.items,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  final List<SupplierItem> items;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (initialLoading) {
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.48,
        child: const Center(child: AppLoadingIndicator()),
      );
    }
    if (error != null && items.isEmpty) {
      return _ItemListNotice(
        text: 'Itemlar yuklanmadi',
        actionText: 'Qayta urinish',
        onAction: onRetry,
      );
    }
    return _AdminItemsList(
      items: items,
      loadingMore: loadingMore,
      hasMore: hasMore,
      pageError: error,
      onRetry: onRetry,
    );
  }
}

class _AdminItemsList extends StatelessWidget {
  const _AdminItemsList({
    required this.items,
    required this.loadingMore,
    required this.hasMore,
    required this.pageError,
    required this.onRetry,
  });

  final List<SupplierItem> items;
  final bool loadingMore;
  final bool hasMore;
  final Object? pageError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _ItemListNotice(text: 'Item topilmadi');
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        M3SegmentSpacedColumn(
          padding: EdgeInsets.zero,
          children: [
            for (var index = 0; index < items.length; index++)
              _AdminItemRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  items.length,
                ),
                item: items[index],
              ),
          ],
        ),
        if (loadingMore)
          const Padding(
            padding: EdgeInsets.all(14),
            child: AppLoadingIndicator(size: 48, glyphSize: 28),
          )
        else if (pageError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Yana yuklash'),
            ),
          )
        else if (hasMore)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Pastga scroll qiling, qolganlari yuklanadi',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _AdminItemRow extends StatelessWidget {
  const _AdminItemRow({required this.slot, required this.item});

  final M3SegmentVerticalSlot slot;
  final SupplierItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = item.name.trim().isEmpty ? item.code : item.name;
    final subtitle = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      if (item.uom.trim().isNotEmpty) item.uom.trim(),
      if (item.itemGroup.trim().isNotEmpty) item.itemGroup.trim(),
    ].join(' • ');

    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      value: '',
      showChevron: false,
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
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
    );
  }
}

class _ItemListNotice extends StatelessWidget {
  const _ItemListNotice({required this.text, this.actionText, this.onAction});

  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}

List<String> orderAdminItemGroupsByParent(
  List<AdminItemGroupTreeEntry> entries,
) {
  final names = <String>{};
  final parentByName = <String, String>{};
  final indexByName = <String, int>{};
  final childrenByParent = <String, List<String>>{};

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final name = (entry.itemGroupName.trim().isNotEmpty
            ? entry.itemGroupName
            : entry.name)
        .trim();
    if (name.isEmpty || !names.add(name)) {
      continue;
    }
    indexByName[name] = index;
    final parent = entry.parentItemGroup.trim();
    parentByName[name] = parent;
    if (parent.isNotEmpty && parent != name) {
      childrenByParent.putIfAbsent(parent, () => <String>[]).add(name);
    }
  }

  for (final children in childrenByParent.values) {
    children.sort((left, right) {
      return (indexByName[left] ?? 1 << 20).compareTo(
        indexByName[right] ?? 1 << 20,
      );
    });
  }

  final ordered = <String>[];
  final visited = <String>{};
  final queue = <String>[];

  void enqueue(String name) {
    if (!names.contains(name) || !visited.add(name)) {
      return;
    }
    queue.add(name);
  }

  if (names.contains('All Item Groups')) {
    enqueue('All Item Groups');
  }

  final roots = names.where((name) {
    final parent = parentByName[name] ?? '';
    return parent.isEmpty || parent == name || !names.contains(parent);
  }).toList()
    ..sort((left, right) {
      return (indexByName[left] ?? 1 << 20).compareTo(
        indexByName[right] ?? 1 << 20,
      );
    });

  for (final root in roots) {
    enqueue(root);
  }

  for (var index = 0; index < queue.length; index++) {
    final name = queue[index];
    ordered.add(name);
    for (final child in childrenByParent[name] ?? const <String>[]) {
      enqueue(child);
    }
  }

  for (final name in names) {
    enqueue(name);
  }
  for (var index = ordered.length; index < queue.length; index++) {
    ordered.add(queue[index]);
  }
  return ordered;
}

class _TapBox extends StatelessWidget {
  const _TapBox({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
