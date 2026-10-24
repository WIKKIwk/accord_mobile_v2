import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

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
import '../../../core/widgets/transfer/transfer_list.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_order_image_thumb.dart';
import '../../shared/models/app_models.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_home_screen.dart'
    show
        QolipPrinterOption,
        qolipPrinterChoiceForDriver,
        showQolipPrinterPicker,
        showQolipProductSpecSheet;
import 'qolip_color_picker.dart';
import 'qolip_product_pdf.dart';
import 'qolip_management_dialogs.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_products_screen__QolipProductsScreenState_methods_01.dart';
part 'qolip_products_screen__QolipProductsScreenState_methods_02.dart';
part 'qolip_products_screen_widgets_part_01.dart';
part 'qolip_products_management.dart';
part 'qolip_products_catalog.dart';

String _productMoldKey(QolipProduct product) =>
    '${product.code.trim().toLowerCase()}\u0000${product.qolipCode.trim().toLowerCase()}';

class _QolipProductsScreenState extends State<QolipProductsScreen> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late Future<void> _future;
  final ScrollController _scroll = ScrollController();
  final List<QolipCatalogItem> _catalogItems = [];
  final Map<String, QolipProductContainer> _details = {};
  final Map<String, Future<QolipProductContainer?>> _detailRequests = {};
  final Map<String, Object> _detailErrors = {};
  String? _nextCursor;
  String _query = '';
  bool _loadingMore = false;
  Object? _pageError;
  int _selectionGeneration = 0;
  Timer? _searchDebounce;
  List<QolipProduct>? _cachedProducts;
  List<QolipProductContainer> _allContainers = const [];
  int _loadGeneration = 0;
  List<QolipProductContainer> _cachedContainers = const [];
  String? _expandedContainerKey;
  _QolipSelectionMode? _selectionMode;
  final Set<String> _selectedContainerKeys = <String>{};
  final Set<String> _selectedQolipCodes = <String>{};
  bool _deleting = false;
  bool _printing = false;
  String? _sharingContainerKey;

  void _update(VoidCallback action) {
    if (mounted) {
      setState(() {
        action();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
    _future = _load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _searchDebounce?.cancel();
    _scroll.dispose();
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
                _searchChanged('');
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
        child: FutureBuilder<void>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                _cachedProducts == null) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: _reload);
            }
            final containers = _cachedContainers;
            if (containers.isEmpty) {
              return Center(
                child: Text(l10n.qolipText(_query.isEmpty
                    ? 'products.empty'
                    : 'products.search_empty')),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                key: const ValueKey('qolip-catalog-list'),
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  4,
                  8,
                  4,
                  MediaQuery.viewPaddingOf(context).bottom + 112,
                ),
                itemCount: containers.length + (_nextCursor == null ? 0 : 1),
                separatorBuilder: (_, __) => const SizedBox(
                  height: M3SegmentedListGeometry.gap,
                ),
                itemBuilder: (context, index) {
                  if (index == containers.length) {
                    return _pageError != null
                        ? AppRetryState(onRetry: _loadMore)
                        : const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: AppLoadingIndicator()));
                  }
                  final container = containers[index];
                  final orderImageOrderId = container.orderImageOrderId;
                  return _QolipProductContainerCard(
                    key: ValueKey('qolip-catalog-${container.key}'),
                    loading: _detailRequests.containsKey(container.key),
                    errorMessage: _detailErrors[container.key] == null
                        ? null
                        : qolipErrorMessage(_detailErrors[container.key]!,
                            l10n: l10n),
                    onRetry: () async {
                      await _ensureDetails(container);
                    },
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      containers.length,
                    ),
                    container: container,
                    imageUrl: orderImageOrderId.isEmpty
                        ? ''
                        : MobileApi.instance.adminProductionMapOrderImageUrl(
                            orderImageOrderId,
                          ),
                    expanded: _expandedContainerKey == container.key,
                    containerSelectionMode:
                        _selectionMode == _QolipSelectionMode.containers,
                    qolipSelectionMode:
                        _selectionMode == _QolipSelectionMode.qolips,
                    selectedContainer: _selectedContainerKeys.contains(
                      container.key,
                    ),
                    selectedQolipCodes: _selectedQolipCodes,
                    sharing: _sharingContainerKey == container.key,
                    onShare: _sharingContainerKey == null
                        ? (originContext) =>
                            _shareProductPdf(container, originContext)
                        : null,
                    onToggle: () {
                      if (_selectionMode == _QolipSelectionMode.containers) {
                        _toggleContainerSelection(container);
                      } else {
                        _toggleContainerExpanded(container);
                      }
                    },
                    onLongPress: () => _toggleContainerSelection(container),
                    onToggleQolip: _toggleQolipSelection,
                    onPrintCodeQr: _showQolipCodeQr,
                    onCopyCode: _copyQolipCode,
                    onEditQolip: _editQolip,
                    onAdd: () => _addQolip(container.catalogProduct),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _shareProductPdf(
    QolipProductContainer container,
    BuildContext originContext,
  ) async {
    if (_sharingContainerKey != null) return;
    final l10n = context.l10n;
    final box = originContext.findRenderObject() as RenderBox?;
    final origin = box != null && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    setState(() => _sharingContainerKey = container.key);
    try {
      // Exact product lookup includes every set and extension, independent of
      // the search filter and the catalog page's result limit.
      final molds = await MobileApi.instance.qolipProductMolds(container.code);
      if (!mounted) return;
      final product = molds.first;
      final bytes = await QolipProductPdf.build(
        productCode: container.code,
        productName: product.name,
        molds: molds,
        l10n: l10n,
      );
      if (!mounted) return;
      final filename = QolipProductPdf.filename(product.name, product.code);
      await SharePlus.instance.share(
        ShareParams(
          title: product.name,
          subject: l10n.qolipProductPdfText('title'),
          files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
          fileNameOverrides: [filename],
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.qolipProductPdfText('error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sharingContainerKey = null);
    }
  }

  Future<void> _copyQolipCode(QolipProduct product) async {
    final code = product.qolipCode.trim();
    if (code.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.adminText('detail.code_copied'))),
      );
  }
}
