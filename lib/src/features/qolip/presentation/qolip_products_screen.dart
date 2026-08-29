import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../shared/models/app_models.dart';
import '../qolip_search_matcher.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_home_screen.dart'
    show
        QolipPrinterOption,
        qolipPrinterChoiceForDriver,
        showQolipPrinterPicker,
        showQolipProductSpecSheet;
import 'qolip_color_picker.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_products_screen__QolipProductsScreenState_methods_01.dart';
part 'qolip_products_screen__QolipProductsScreenState_methods_02.dart';
part 'qolip_products_screen_widgets_part_01.dart';

class _QolipProductsScreenState extends State<QolipProductsScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Future<List<QolipProduct>> _future;
  Timer? _searchDebounce;
  List<QolipProduct>? _cachedProducts;
  String _cachedQuery = '';
  List<QolipProductContainer> _cachedContainers = const [];
  String? _expandedContainerKey;
  _QolipSelectionMode? _selectionMode;
  final Set<String> _selectedContainerKeys = <String>{};
  final Set<String> _selectedQolipCodes = <String>{};
  bool _deleting = false;
  bool _printing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: _selectionMode == null
          ? AdminCatalogSearchField(
              controller: _search,
              focusNode: _searchFocusNode,
              hintText: l10n.qolipText('products.search'),
              onChanged: _searchChanged,
              onClear: () {
                _search.clear();
                _searchDebounce?.cancel();
                setState(() {});
              },
              onBackWithContext: (context) =>
                  AppShellDrawerScope.maybeOf(context)?.openDrawer(),
              leadingIcon: Icons.menu_rounded,
              leadingTooltip:
                  MaterialLocalizations.of(context).openAppDrawerTooltip,
            )
          : _selectionTitle(context),
      drawer: QolipNavigationDrawer(
        selectedIndex: 2,
        onNavigate: _openDrawerRoute,
      ),
      bottom: ValueListenableBuilder<bool>(
        valueListenable: adminCreateHubMenuOpen,
        builder: (context, menuOpen, _) => QolipDock(
          activeTab: QolipDockTab.products,
          showPrimaryFab: !menuOpen,
          onPrimaryFabTap: _openFabAction,
        ),
      ),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<List<QolipProduct>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: _reload);
            }
            final products = snapshot.data ?? const <QolipProduct>[];
            if (products.isEmpty) {
              return Center(child: Text(l10n.qolipText('products.empty')));
            }
            final containers = _visibleContainers(products);
            if (containers.isEmpty) {
              return Center(
                child: Text(l10n.qolipText('products.search_empty')),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  4,
                  4,
                  4,
                  MediaQuery.viewPaddingOf(context).bottom + 112,
                ),
                itemCount: containers.length,
                separatorBuilder: (_, __) => const SizedBox(
                  height: M3SegmentedListGeometry.gap,
                ),
                itemBuilder: (context, index) {
                  return _QolipProductContainerCard(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      containers.length,
                    ),
                    container: containers[index],
                    expanded: _expandedContainerKey == containers[index].key,
                    containerSelectionMode:
                        _selectionMode == _QolipSelectionMode.containers,
                    qolipSelectionMode:
                        _selectionMode == _QolipSelectionMode.qolips,
                    selectedContainer: _selectedContainerKeys.contains(
                      containers[index].key,
                    ),
                    selectedQolipCodes: _selectedQolipCodes,
                    onToggle: () {
                      if (_selectionMode == _QolipSelectionMode.containers) {
                        _toggleContainerSelection(containers[index]);
                      } else {
                        _toggleContainerExpanded(containers[index]);
                      }
                    },
                    onLongPress: () =>
                        _toggleContainerSelection(containers[index]),
                    onToggleQolip: _toggleQolipSelection,
                    onPrintCodeQr: _showQolipCodeQr,
                    onEditQolip: _editQolip,
                    onAdd: () => _addQolip(containers[index].catalogProduct),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
