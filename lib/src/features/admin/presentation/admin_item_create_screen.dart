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

part 'admin_item_create_screen__AdminItemCreateScreenState_methods_01.dart';
part 'admin_item_create_screen_widgets_part_01.dart';
part 'admin_item_create_screen_models_part_02.dart';
part 'admin_item_create_screen_declarations_part_03.dart';

const double _itemCreateCardRadius = 18;
const double _itemCreateFieldRadius = 18;

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
}
