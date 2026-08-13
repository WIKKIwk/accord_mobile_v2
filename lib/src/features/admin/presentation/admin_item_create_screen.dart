import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
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
  final TextEditingController uom = TextEditingController();
  final TextEditingController _itemsSearchController = TextEditingController();
  final FocusNode _itemsSearchFocusNode = FocusNode();
  final GlobalKey<_AdminItemsListTabState> _itemsListTabKey =
      GlobalKey<_AdminItemsListTabState>();
  late final Future<List<String>> itemGroupsFuture;
  late final Future<List<String>> itemUomsFuture;
  late final TabController _tabController;
  List<AdminItemGroupTreeEntry> _itemGroupTree = const [];
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
    itemUomsFuture = _loadItemUoms();
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

  Future<List<String>> _loadItemUoms() async {
    final values = await MobileApi.instance.adminItemUoms();
    if (values.isEmpty) {
      throw StateError('UOM katalogi bo‘sh');
    }
    _syncUomSelection(values);
    return values;
  }

  Future<List<String>> _loadItemGroups() async {
    try {
      final tree = await MobileApi.instance.adminItemGroupTree();
      _itemGroupTree = tree;
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

  void _syncUomSelection(List<String> values) {
    final current = uom.text.trim().toLowerCase();
    for (final value in values) {
      if (value.trim().toLowerCase() == current) {
        uom.text = value.trim();
        return;
      }
    }
    uom.text = values.first.trim();
  }

  Future<bool> _save() async {
    List<String> availableUoms;
    try {
      availableUoms = await itemUomsFuture;
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('item.uom_load_failed'),
        );
      }
      return false;
    }
    if (!mounted) {
      return false;
    }
    String? selectedUom;
    for (final value in availableUoms) {
      if (value.trim().toLowerCase() == uom.text.trim().toLowerCase()) {
        selectedUom = value;
        break;
      }
    }
    if (selectedUom == null) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('item.uom_required'),
      );
      return false;
    }
    uom.text = selectedUom.trim();
    final group = itemGroup.text.trim();
    if (_requiresCustomer(group) && selectedCustomer == null) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('item.customer_required'),
      );
      return false;
    }
    setState(() => saving = true);
    try {
      if (await _itemCodeAlreadyExists()) {
        if (mounted) {
          showAdminTopNotice(
            context,
            context.l10n.adminText('item.already_exists'),
          );
        }
        return false;
      }
      final item = await MobileApi.instance.adminCreateItem(
        code: code.text.trim(),
        name: name.text.trim(),
        uom: uom.text.trim(),
        itemGroup: group,
        customerRef:
            _requiresCustomer(group) ? selectedCustomer?.ref.trim() ?? '' : '',
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
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          'item.created',
          values: {'code': item.code},
        ),
      );
      return true;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('item.create_failed'),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<bool> _itemCodeAlreadyExists() async {
    final itemCode = code.text.trim();
    if (itemCode.isEmpty) {
      return false;
    }
    final items = await MobileApi.instance.adminItemsPage(
      query: itemCode,
      limit: 5,
    );
    final normalizedCode = itemCode.toLowerCase();
    return items.any(
      (item) => item.code.trim().toLowerCase() == normalizedCode,
    );
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
          title: context.l10n.adminText('item.group_select'),
          hintText: context.l10n.adminText('item.group_search'),
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
      if (!_requiresCustomer(picked)) {
        selectedCustomer = null;
      }
    });
  }

  Future<void> _openUomPicker(List<String> values) async {
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
          title: context.l10n.adminText('item.uom_select'),
          hintText: context.l10n.adminText('item.uom_search'),
          pageSize: 50,
          loadPage: (query, offset, limit) async {
            final normalizedQuery = query.trim().toLowerCase();
            final filtered = normalizedQuery.isEmpty
                ? values
                : values.where((value) {
                    return value.toLowerCase().contains(normalizedQuery);
                  }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (value) => value,
          itemSubtitle: (_) => '',
          onSelected: (value) => Navigator.of(context).pop(value),
        );
      },
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => uom.text = picked);
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
          title: context.l10n.adminText('item.customer_select'),
          hintText: context.l10n.adminText('item.customer_search'),
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
                itemUomsFuture: itemUomsFuture,
                saving: saving,
                requiresCustomer: _requiresCustomer,
                onSyncItemGroup: _syncItemGroupSelection,
                onSyncUom: _syncUomSelection,
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
                onOpenUomPicker: (values) async {
                  await _openUomPicker(values);
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
        hintText: context.l10n.adminText('item.search'),
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
            title: context.l10n.adminText('item.add_title'),
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
                      tabs: [
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('item.items_tab'),
                        ),
                        Tab(
                          height: 38,
                          text: context.l10n.adminText('item.group_move_tab'),
                        ),
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

  bool _requiresCustomer(String group) {
    return adminItemGroupRequiresCustomer(group, _itemGroupTree);
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
    required this.itemUomsFuture,
    required this.saving,
    required this.requiresCustomer,
    required this.onSyncItemGroup,
    required this.onSyncUom,
    required this.onOpenItemGroupPicker,
    required this.onOpenCustomerPicker,
    required this.onOpenUomPicker,
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
  final Future<List<String>> itemUomsFuture;
  final bool saving;
  final bool Function(String group) requiresCustomer;
  final ValueChanged<List<String>> onSyncItemGroup;
  final ValueChanged<List<String>> onSyncUom;
  final ValueChanged<List<String>> onOpenItemGroupPicker;
  final VoidCallback onOpenCustomerPicker;
  final ValueChanged<List<String>> onOpenUomPicker;
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
                      labelText: context.l10n.adminText('item.code'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('admin-item-create-name'),
                    controller: name,
                    decoration: appSoftInputDecoration(
                      context,
                      labelText: context.l10n.adminText('item.name'),
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
                      final requiresCustomer = this.requiresCustomer(
                        selectedGroup ?? '',
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.adminText('item.group_label'),
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
                                      selectedGroup ??
                                          context.l10n.adminText(
                                            'item.group_required',
                                          ),
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
                              context.l10n.adminText('item.customer_label'),
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
                                            ? context.l10n.adminText(
                                                'item.customer_required_short',
                                              )
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
                                        tooltip: context.l10n.adminText(
                                          'action.clear',
                                        ),
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
                  FutureBuilder<List<String>>(
                    future: itemUomsFuture,
                    builder: (context, snapshot) {
                      final values = snapshot.data ?? const <String>[];
                      if (snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError &&
                          values.isNotEmpty) {
                        onSyncUom(values);
                      }
                      final selectedUom = uom.text.trim();
                      final enabled =
                          snapshot.connectionState == ConnectionState.done &&
                              !snapshot.hasError &&
                              values.isNotEmpty &&
                              !saving;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.adminText('item.uom_label'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _TapBox(
                            key: const ValueKey(
                              'admin-item-create-uom-picker',
                            ),
                            onTap:
                                enabled ? () => onOpenUomPicker(values) : null,
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
                                      snapshot.hasError
                                          ? context.l10n.adminText(
                                              'item.uom_load_failed',
                                            )
                                          : selectedUom.isEmpty
                                              ? context.l10n.adminText(
                                                  'item.uom_required',
                                                )
                                              : selectedUom,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: selectedUom.isEmpty
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
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey('admin-item-create-submit'),
                      onPressed: onSave,
                      child: Text(
                        saving
                            ? context.l10n.adminText('item.creating')
                            : context.l10n.adminText('item.add_title'),
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
                tooltip: context.l10n.adminText('item.close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef AdminItemsPageLoader = Future<List<SupplierItem>> Function({
  required String query,
  required int limit,
  required int offset,
});
typedef AdminItemTapHandler = Future<void> Function(SupplierItem item);

class AdminItemsListTab extends StatefulWidget {
  const AdminItemsListTab({
    super.key,
    required this.loadItemsPage,
    this.searchController,
    this.embeddedSearchInAppBar = false,
    this.onItemTap,
  });

  final AdminItemsPageLoader loadItemsPage;
  final TextEditingController? searchController;
  final bool embeddedSearchInAppBar;
  final AdminItemTapHandler? onItemTap;

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
    if (cache.sessionRevision != AppSession.instance.revision.value) {
      _memoryCache = null;
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

  void _saveMemoryCache(int sessionRevision) {
    _memoryCache = _AdminItemsMemoryCache(
      sessionRevision: sessionRevision,
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
    final sessionRevision = AppSession.instance.revision.value;
    try {
      final page = await widget.loadItemsPage(
        query: query,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted ||
          query != _query ||
          sessionRevision != AppSession.instance.revision.value) {
        return;
      }
      setState(() {
        _items = replace ? page : <SupplierItem>[..._items, ...page];
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = page.length == _pageSize;
        _error = null;
      });
      _saveMemoryCache(sessionRevision);
    } catch (error) {
      if (!mounted ||
          query != _query ||
          sessionRevision != AppSession.instance.revision.value) {
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

  Future<void> _openItem(SupplierItem item) async {
    final customHandler = widget.onItemTap;
    if (customHandler != null) {
      await customHandler(item);
    } else {
      await Navigator.of(context).pushNamed(
        AppRoutes.adminItemDetail,
        arguments: item.code,
      );
    }
    if (!mounted) {
      return;
    }
    AdminItemsListTab.clearMemoryCache();
    await _loadFirstPage(forceRefresh: true);
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
                hintText: context.l10n.adminText('item.search'),
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
              onItemTap: widget.onItemTap != null ||
                      AppSession.instance.can('admin.access')
                  ? _openItem
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminItemsMemoryCache {
  const _AdminItemsMemoryCache({
    required this.sessionRevision,
    required this.query,
    required this.items,
    required this.hasMore,
  });

  final int sessionRevision;
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
    required this.onItemTap,
  });

  final List<SupplierItem> items;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final VoidCallback onRetry;
  final AdminItemTapHandler? onItemTap;

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
        text: context.l10n.adminText('item.loading_failed'),
        actionText: context.l10n.adminText('item.retry'),
        onAction: onRetry,
      );
    }
    return _AdminItemsList(
      items: items,
      loadingMore: loadingMore,
      hasMore: hasMore,
      pageError: error,
      onRetry: onRetry,
      onItemTap: onItemTap,
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
    required this.onItemTap,
  });

  final List<SupplierItem> items;
  final bool loadingMore;
  final bool hasMore;
  final Object? pageError;
  final VoidCallback onRetry;
  final AdminItemTapHandler? onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ItemListNotice(
        text: context.l10n.adminText('item.empty'),
      );
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
                onTap:
                    onItemTap == null ? null : () => onItemTap!(items[index]),
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
              label: Text(context.l10n.adminText('item.load_more')),
            ),
          )
        else if (hasMore)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              context.l10n.adminText('item.scroll_load_more'),
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
  const _AdminItemRow({required this.slot, required this.item, this.onTap});

  final M3SegmentVerticalSlot slot;
  final SupplierItem item;
  final VoidCallback? onTap;

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
      onTap: onTap,
      showChevron: onTap != null,
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
