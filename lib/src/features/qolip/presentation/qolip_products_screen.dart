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

class QolipProductsScreen extends StatefulWidget {
  const QolipProductsScreen({super.key});

  @override
  State<QolipProductsScreen> createState() => _QolipProductsScreenState();
}

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

  Future<List<QolipProduct>> _load() {
    return MobileApi.instance.qolipProducts(
      limit: 20000,
      withQolipOnly: true,
    );
  }

  Future<void> _reload({String? preserveExpandedContainerKey}) async {
    final next = _load();
    setState(() {
      _cachedProducts = null;
      _cachedQuery = '';
      _cachedContainers = const [];
      _expandedContainerKey = preserveExpandedContainerKey;
      _selectionMode = null;
      _selectedContainerKeys.clear();
      _selectedQolipCodes.clear();
      _future = next;
    });
    await next;
  }

  void _toggleContainerExpanded(QolipProductContainer container) {
    final key = container.key;
    setState(() {
      if (_expandedContainerKey == key) {
        _expandedContainerKey = null;
      } else {
        _expandedContainerKey = key;
      }
    });
  }

  Future<void> _openQolipSpecSheet({QolipProduct? initialProduct}) async {
    await showQolipProductSpecSheet(
      context,
      initialProduct: initialProduct,
    );
    if (!mounted) {
      return;
    }
    QolipDataRevision.notifyLocationsChanged();
    await _reload(preserveExpandedContainerKey: _expandedContainerKey);
  }

  Future<void> _addQolip(QolipProduct product) {
    return _openQolipSpecSheet(initialProduct: product);
  }

  void _openFabAction() {
    final l10n = context.l10n;
    showAdminCreateHubSheet(
      context,
      actions: [
        AdminFabMenuAction(
          title: l10n.qolipText('products.add'),
          icon: Icons.inventory_2_rounded,
          onTap: () => unawaited(_openQolipSpecSheet()),
        ),
        AdminFabMenuAction(
          title: l10n.qolipText('products.ledger'),
          icon: Icons.menu_book_rounded,
          onTap: () => _openDrawerRoute(AppRoutes.qolipCheckouts),
        ),
      ],
    );
  }

  void _searchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 160),
      () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  List<QolipProductContainer> _visibleContainers(
    List<QolipProduct> products,
  ) {
    final query = _search.text.trim();
    if (identical(_cachedProducts, products) && _cachedQuery == query) {
      return _cachedContainers;
    }
    final visibleProducts = products
        .where((product) => qolipProductSearchMatches(query, product))
        .toList(growable: false);
    final containers = groupQolipProductsByContainer(visibleProducts);
    _cachedProducts = products;
    _cachedQuery = query;
    _cachedContainers = containers;
    return containers;
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = null;
      _selectedContainerKeys.clear();
      _selectedQolipCodes.clear();
    });
  }

  void _toggleContainerSelection(QolipProductContainer container) {
    if (container.hasInUseQolip ||
        (_selectionMode != null &&
            _selectionMode != _QolipSelectionMode.containers)) {
      return;
    }
    setState(() {
      _selectionMode = _QolipSelectionMode.containers;
      if (_selectedContainerKeys.add(container.key)) {
        _selectedQolipCodes.addAll(
          container.children.map((child) => child.qolipCode.trim()),
        );
      } else {
        _selectedContainerKeys.remove(container.key);
        _selectedQolipCodes.removeAll(
          container.children.map((child) => child.qolipCode.trim()),
        );
      }
      if (_selectedContainerKeys.isEmpty) {
        _selectionMode = null;
      }
    });
  }

  void _toggleQolipSelection(QolipProduct product) {
    if (product.isInUse ||
        (_selectionMode != null &&
            _selectionMode != _QolipSelectionMode.qolips)) {
      return;
    }
    final code = product.qolipCode.trim();
    if (code.isEmpty) {
      return;
    }
    setState(() {
      _selectionMode = _QolipSelectionMode.qolips;
      if (!_selectedQolipCodes.add(code)) {
        _selectedQolipCodes.remove(code);
      }
      if (_selectedQolipCodes.isEmpty) {
        _selectionMode = null;
      }
    });
  }

  Future<void> _deleteSelection() async {
    if (_deleting || _selectedQolipCodes.isEmpty) {
      return;
    }
    final codes = _selectedQolipCodes.toList(growable: false);
    final productCount = _selectedContainerKeys.length;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.qolipText('products.delete_title')),
        content: Text(
          _selectionMode == _QolipSelectionMode.containers
              ? l10n.qolipText(
                  'products.delete_container_message',
                  values: {
                    'products': productCount,
                    'molds': codes.length,
                  },
                )
              : l10n.qolipText(
                  'products.delete_selected_message',
                  values: {'molds': codes.length},
                ),
        ),
        actions: [
          AppDialogActionRow(
            cancelLabel: l10n.qolipText('action.cancel'),
            confirmLabel: l10n.qolipText('action.delete'),
            gap: 8,
            vertical: true,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _deleting = true);
    try {
      final deleted = await MobileApi.instance.qolipDeleteProductSpecs(codes);
      if (!mounted) {
        return;
      }
      QolipDataRevision.notifyLocationsChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.qolipText(
              'products.deleted',
              values: {'count': deleted},
            ),
          ),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(
              error,
              fallback: l10n.qolipText('products.delete_failed'),
              l10n: l10n,
            ),
          ),
        ),
      );
      await _reload();
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  List<QolipProduct> _selectedProducts() {
    final selectedCodes = _selectedQolipCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    return [
      for (final product in _cachedProducts ?? const <QolipProduct>[])
        if (selectedCodes.contains(product.qolipCode.trim().toLowerCase()))
          product,
    ];
  }

  Future<void> _printSelection() async {
    if (_printing || _deleting || _selectedQolipCodes.isEmpty) {
      return;
    }
    final products = _selectedProducts();
    if (products.isEmpty) {
      return;
    }
    final option = await showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      return;
    }
    setState(() => _printing = true);
    final failedCodes = <String>[];
    try {
      for (final product in products) {
        try {
          await _printQolipCodeQrWithOption(product, option);
        } catch (_) {
          failedCodes.add(product.qolipCode.trim());
        }
      }
      if (!mounted) {
        return;
      }
      final l10n = context.l10n;
      final message = failedCodes.isEmpty
          ? l10n.qolipText(
              'products.printed',
              values: {'count': products.length},
            )
          : l10n.qolipText(
              'products.printed_partial',
              values: {
                'success': products.length - failedCodes.length,
                'failed': failedCodes.length,
              },
            );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  Widget _selectionTitle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final totalQolipCount = _cachedProducts?.length ?? 0;
    final selectedQolipCount = _selectedQolipCodes.length;
    return Row(
      children: [
        IconButton(
          onPressed: _deleting || _printing ? null : _cancelSelection,
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.qolipText('products.selection_cancel'),
        ),
        Expanded(
          child: Text(
            l10n.qolipText(
              'products.selection_summary',
              values: {
                'total': totalQolipCount,
                'selected': selectedQolipCount,
              },
            ),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        IconButton.filled(
          onPressed: _deleting || _printing ? null : _printSelection,
          style: IconButton.styleFrom(foregroundColor: scheme.onPrimary),
          icon: _printing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_outlined),
          tooltip: l10n.qolipText('products.selection_print'),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          onPressed: _deleting || _printing ? null : _deleteSelection,
          style: IconButton.styleFrom(foregroundColor: scheme.onPrimary),
          icon: _deleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline_rounded),
          tooltip: l10n.qolipText('products.selection_delete'),
        ),
      ],
    );
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _showQolipCodeQr(QolipProduct product) async {
    final code = product.qolipCode.trim();
    if (code.isEmpty) {
      return;
    }
    final itemName = product.name.trim().isEmpty ? code : product.name.trim();
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => RpsQrReprintSheet(
        title: l10n.qolipText('products.qr_title'),
        payload: code,
        itemName: itemName,
        previewKey: ValueKey('qolip-code-qr-preview-$code'),
        reprintButtonKey: ValueKey('qolip-code-qr-reprint-$code'),
        details: [
          if (product.code.trim().isNotEmpty)
            RpsQrDetail(l10n.qolipText('products.product_code'), product.code),
          if (product.qolipSize > 0)
            RpsQrDetail(
                l10n.qolipText('products.size'), '${product.qolipSize}'),
          if (product.customerNames.isNotEmpty)
            RpsQrDetail(l10n.qolipText('products.customer'),
                product.customerNames.join(', ')),
        ],
        onReprint: () => _reprintQolipCodeQr(product),
        errorMessage: (error) => qolipErrorMessage(
          error,
          fallback: l10n.qolipText('products.qr_failed'),
          l10n: l10n,
        ),
      ),
    );
  }

  int? _availablePantonNumber(QolipProduct product) {
    final currentCode = product.qolipCode.trim().toLowerCase();
    final used = <int>{};
    for (final item in _cachedProducts ?? const <QolipProduct>[]) {
      if (item.qolipCode.trim().toLowerCase() == currentCode) {
        continue;
      }
      final number = qolipPantonNumber(item.qolipColor);
      if (number != null) {
        used.add(number);
      }
    }
    for (var number = 1; number <= qolipPantonMaxNumber; number++) {
      if (!used.contains(number)) {
        return number;
      }
    }
    return null;
  }

  Future<void> _editQolip(QolipProduct product) async {
    if (product.isInUse) {
      return;
    }
    final code = TextEditingController(text: product.qolipCode);
    final size = TextEditingController(text: '${product.qolipSize}');
    String? selectedColor =
        product.qolipColor.trim().isEmpty ? null : product.qolipColor;
    final l10n = context.l10n;
    final draft = await showDialog<_QolipEditDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          title: Text(l10n.qolipText('products.edit_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.qolipText('products.code'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: size,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.qolipText('products.size'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.qolipText('products.color'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: 8),
                QolipColorPicker(
                  selectedColor: selectedColor,
                  availablePantonNumber: _availablePantonNumber(product),
                  onChanged: (color) =>
                      setDialogState(() => selectedColor = color),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () {
                      final nextCode = code.text.trim();
                      final nextSize = int.tryParse(size.text.trim()) ?? 0;
                      if (nextCode.isEmpty || nextSize <= 0) {
                        return;
                      }
                      Navigator.of(dialogContext).pop(
                        _QolipEditDraft(
                          code: nextCode,
                          size: nextSize,
                          color: selectedColor ?? '',
                        ),
                      );
                    },
                    child: Text(l10n.qolipText('action.save')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(l10n.qolipText('action.cancel')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    code.dispose();
    size.dispose();
    if (draft == null || !mounted) {
      return;
    }
    try {
      await MobileApi.instance.qolipSaveProductSpec(
        product: product,
        qolipCode: draft.code,
        size: draft.size,
        qolipColor: draft.color,
        previousQolipCode: product.qolipCode,
      );
      if (!mounted) {
        return;
      }
      QolipDataRevision.notifyLocationsChanged();
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(
              error,
              fallback: l10n.qolipText('products.edit_failed'),
              l10n: l10n,
            ),
          ),
        ),
      );
    }
  }

  Future<String?> _reprintQolipCodeQr(QolipProduct product) async {
    final option = await showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      throw StateError('Printer tanlanmadi');
    }
    await _printQolipCodeQrWithOption(product, option);
    return null;
  }

  Future<void> _printQolipCodeQrWithOption(
    QolipProduct product,
    QolipPrinterOption option,
  ) async {
    final code = product.qolipCode.trim();
    final printer = option.transport.isLocal
        ? option.transport.isBluetooth
            ? option.bluetoothPrinter!.printer
            : option.offlinePrinter!.printer
        : qolipPrinterChoiceForDriver(
            kind: option.printerKind,
            label: option.printerLabel,
          );
    final result = await MobileApi.instance.qolipPrintCodeQr(
      qolipCode: code,
      driverUrl: option.driverUrl,
      printer: printer,
      printMode: option.transport.isLocal
          ? option.transport.isBluetooth
              ? option.bluetoothPrinter!.printMode
              : option.offlinePrinter!.printMode
          : printer == 'godex'
              ? 'label'
              : 'rfid',
      customerName: product.customerNames.join(', '),
      qolipColor: product.qolipColor,
      printTransport: option.transport,
    );
    if (option.transport.isLocal) {
      await PrintService.printRps(
        result.printJob,
        printerProfile: option.offlinePrinter,
        bluetoothPrinter: option.bluetoothPrinter,
        transport: option.transport,
      );
    }
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

enum _QolipSelectionMode { containers, qolips }

class _QolipEditDraft {
  const _QolipEditDraft({
    required this.code,
    required this.size,
    required this.color,
  });

  final String code;
  final int size;
  final String color;
}

class QolipProductContainer {
  const QolipProductContainer({
    required this.code,
    required this.name,
    required this.itemGroup,
    required this.children,
  });

  final String code;
  final String name;
  final String itemGroup;
  final List<QolipProduct> children;

  bool get hasInUseQolip => children.any((child) => child.isInUse);

  QolipProduct get catalogProduct {
    final first = children.first;
    return QolipProduct(
      code: code,
      name: name,
      itemGroup: itemGroup,
      customerNames: first.customerNames,
      firstQolipCode: first.firstQolipCode.trim().isEmpty
          ? first.qolipCode
          : first.firstQolipCode,
    );
  }

  String get key {
    final codeKey = code.trim().toLowerCase();
    if (codeKey.isNotEmpty) {
      return codeKey;
    }
    return name.trim().toLowerCase();
  }
}

List<QolipProductContainer> groupQolipProductsByContainer(
  Iterable<QolipProduct> products,
) {
  final grouped = <String, _QolipProductContainerBuilder>{};
  for (final product in products) {
    final qolipCode = product.qolipCode.trim();
    if (qolipCode.isEmpty) {
      continue;
    }
    final itemCode = product.code.trim();
    final key = itemCode.isEmpty
        ? product.name.trim().toLowerCase()
        : itemCode.toLowerCase();
    grouped
        .putIfAbsent(
          key,
          () => _QolipProductContainerBuilder(
            code: itemCode,
            name: product.name.trim(),
            itemGroup: product.itemGroup.trim(),
          ),
        )
        .children
        .add(product);
  }
  final containers = grouped.values.map((builder) {
    final children = [...builder.children]..sort((left, right) => left.qolipCode
        .trim()
        .toLowerCase()
        .compareTo(right.qolipCode.trim().toLowerCase()));
    return QolipProductContainer(
      code: builder.code,
      name: builder.name,
      itemGroup: builder.itemGroup,
      children: children,
    );
  }).toList(growable: false);
  return containers
    ..sort((left, right) => left.name
        .trim()
        .toLowerCase()
        .compareTo(right.name.trim().toLowerCase()));
}

class _QolipProductContainerBuilder {
  _QolipProductContainerBuilder({
    required this.code,
    required this.name,
    required this.itemGroup,
  });

  final String code;
  final String name;
  final String itemGroup;
  final List<QolipProduct> children = [];
}

class _QolipProductContainerCard extends StatelessWidget {
  const _QolipProductContainerCard({
    required this.slot,
    required this.container,
    required this.expanded,
    required this.containerSelectionMode,
    required this.qolipSelectionMode,
    required this.selectedContainer,
    required this.selectedQolipCodes,
    required this.onToggle,
    required this.onLongPress,
    required this.onToggleQolip,
    required this.onPrintCodeQr,
    required this.onEditQolip,
    required this.onAdd,
  });

  final M3SegmentVerticalSlot slot;
  final QolipProductContainer container;
  final bool expanded;
  final bool containerSelectionMode;
  final bool qolipSelectionMode;
  final bool selectedContainer;
  final Set<String> selectedQolipCodes;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;
  final ValueChanged<QolipProduct> onToggleQolip;
  final ValueChanged<QolipProduct> onPrintCodeQr;
  final ValueChanged<QolipProduct> onEditQolip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final container = this.container;
    final selectionDisabled = container.hasInUseQolip;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: selectedContainer ? scheme.secondaryContainer : scheme.surface,
      elevation: expanded ? 0 : 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            onLongPress: selectionDisabled ? () {} : onLongPress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  if (containerSelectionMode)
                    Checkbox(
                      value: selectedContainer,
                      onChanged: selectionDisabled ? null : (_) => onToggle(),
                    )
                  else
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selectionDisabled
                              ? scheme.surfaceContainerHighest
                              : scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          selectionDisabled
                              ? Icons.lock_outline_rounded
                              : Icons.inventory_2_outlined,
                          size: 16,
                          color: selectionDisabled
                              ? scheme.onSurfaceVariant
                              : scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          container.name.isEmpty
                              ? container.code
                              : container.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectionDisabled
                              ? l10n.qolipText(
                                  'products.count_in_use',
                                  values: {'count': container.children.length},
                                )
                              : l10n.qolipText(
                                  'products.mold_count',
                                  values: {'count': container.children.length},
                                ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.05,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (expanded &&
                      !containerSelectionMode &&
                      !qolipSelectionMode) ...[
                    IconButton.filledTonal(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: l10n.qolipText('products.add'),
                    ),
                    const SizedBox(width: 2),
                  ],
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.65),
                      ),
                      for (final child in container.children)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
                          child: _QolipCodeRow(
                            product: child,
                            selectionMode: qolipSelectionMode,
                            selected: selectedQolipCodes.contains(
                              child.qolipCode.trim(),
                            ),
                            onTap: () => qolipSelectionMode
                                ? onToggleQolip(child)
                                : onPrintCodeQr(child),
                            onLongPress: child.isInUse
                                ? () {}
                                : () => onToggleQolip(child),
                            onEdit: () => onEditQolip(child),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _QolipCodeRow extends StatelessWidget {
  const _QolipCodeRow({
    required this.product,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onEdit,
  });

  final QolipProduct product;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? scheme.secondaryContainer
              : product.isInUse
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 28,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    product.isInUse
                        ? Icons.lock_outline_rounded
                        : Icons.qr_code_2_rounded,
                    size: 17,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (product.qolipColor.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.qolipText(
                    'products.color_label',
                    values: {
                      'color': l10n.qolipColorName(product.qolipColor),
                    },
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: qolipColorValue(product.qolipColor),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: scheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.qolipCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: product.isInUse
                                ? scheme.onSurfaceVariant
                                : null,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      product.isInUse
                          ? l10n.qolipText('products.issued')
                          : product.qolipSize > 0
                              ? l10n.qolipText(
                                  'products.size_value',
                                  values: {'size': product.qolipSize},
                                )
                              : '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (selectionMode)
                Checkbox(
                  value: selected,
                  onChanged: product.isInUse ? null : (_) => onTap(),
                )
              else if (!product.isInUse)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: l10n.qolipText('products.edit_title'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
