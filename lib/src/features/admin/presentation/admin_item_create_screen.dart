import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/navigation/app_navigation_bar.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/admin_item_group_tree_entry.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_summary_card.dart';
import 'widgets/admin_top_notice.dart';
import 'admin_user_create_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';

part 'admin_item_create_screen__AdminItemCreateScreenState_methods_01.dart';
part 'admin_item_create_screen_widgets_part_01.dart';
part 'admin_item_create_screen_models_part_02.dart';
part 'admin_item_create_screen_declarations_part_03.dart';

const double _itemCreateCardRadius = 18;
const double _itemCreateFieldRadius = 18;

class _AdminItemCreateScreenState extends State<AdminItemCreateScreen> {
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
  List<AdminItemGroupTreeEntry> _itemGroupTree = const [];
  CustomerDirectoryEntry? selectedCustomer;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _itemsSearchFocusNode.addListener(_handleItemsSearchFocus);
    itemGroupsFuture = _loadItemGroups();
    itemUomsFuture = _loadItemUoms();
  }

  @override
  void dispose() {
    _itemsSearchFocusNode.removeListener(_handleItemsSearchFocus);
    _itemsSearchFocusNode.dispose();
    _itemsSearchController.dispose();
    code.dispose();
    name.dispose();
    itemGroup.dispose();
    uom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = _itemsListTabKey.currentState;
    final selectedCount = itemsState?.selectedCount ?? 0;
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
        primaryAction: selectedCount == 0
            ? null
            : SizedBox(
                height: appNavigationBarPrimaryButtonSize,
                child: FloatingActionButton.extended(
                  key: const ValueKey('admin-items-move-fab'),
                  onPressed:
                      itemsState!.moving ? null : itemsState.moveSelected,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      appNavigationBarPrimaryButtonBorderRadius,
                    ),
                  ),
                  icon: itemsState.submittingMove
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.drive_file_move_outlined),
                  label: Text(
                    '${context.l10n.adminText('bulk_move.action')} ($selectedCount)',
                  ),
                ),
              ),
        primaryFabActions: [
          AdminFabMenuAction(
            title: context.l10n.adminText('item.add_title'),
            icon: Icons.inventory_2_outlined,
            onTap: _openItemCreateDialog,
          ),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      child: AdminItemsListTab(
        key: _itemsListTabKey,
        searchController: _itemsSearchController,
        embeddedSearchInAppBar: true,
        itemGroupsFuture: itemGroupsFuture,
        onSelectionChanged: () => setState(() {}),
        loadItemsPage: ({
          required query,
          required group,
          required limit,
          required offset,
        }) =>
            MobileApi.instance.adminItemsPage(
          query: query,
          group: group,
          limit: limit,
          offset: offset,
        ),
      ),
    );
  }
}
