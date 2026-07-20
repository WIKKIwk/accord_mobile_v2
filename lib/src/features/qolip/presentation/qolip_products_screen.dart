import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_home_screen.dart'
    show qolipPrinterChoiceForDriver, showQolipPrinterPicker;
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
  late Future<List<QolipProductContainer>> _future;
  Timer? _searchDebounce;
  String? _expandedContainerKey;
  _QolipSelectionMode? _selectionMode;
  final Set<String> _selectedContainerKeys = <String>{};
  final Set<String> _selectedQolipCodes = <String>{};
  bool _deleting = false;

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

  Future<List<QolipProductContainer>> _load() async {
    final products = await MobileApi.instance.qolipProducts(
      query: _search.text,
      limit: 20000,
      withQolipOnly: true,
    );
    return groupQolipProductsByContainer(products);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _expandedContainerKey = null;
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

  void _searchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 260),
      () => unawaited(_reload()),
    );
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Qoliplarni o‘chirasizmi?'),
        content: Text(
          _selectionMode == _QolipSelectionMode.containers
              ? '$productCount ta mahsulotga biriktirilgan ${codes.length} ta qolip o‘chiriladi.'
              : '${codes.length} ta tanlangan qolip o‘chiriladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('O‘chirish'),
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
        SnackBar(content: Text('$deleted ta qolip o‘chirildi')),
      );
      await _reload();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(error, fallback: 'Qoliplar o‘chirilmadi'),
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

  Widget _selectionTitle(BuildContext context) {
    final count = _selectionMode == _QolipSelectionMode.containers
        ? _selectedContainerKeys.length
        : _selectedQolipCodes.length;
    return Row(
      children: [
        IconButton(
          onPressed: _deleting ? null : _cancelSelection,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Tanlashni bekor qilish',
        ),
        Expanded(
          child: Text(
            '$count ta tanlandi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        IconButton.filled(
          onPressed: _deleting ? null : _deleteSelection,
          icon: _deleting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline_rounded),
          tooltip: 'Tanlanganlarni o‘chirish',
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
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => RpsQrReprintSheet(
        title: 'Qolip QR',
        payload: code,
        itemName: itemName,
        previewKey: ValueKey('qolip-code-qr-preview-$code'),
        reprintButtonKey: ValueKey('qolip-code-qr-reprint-$code'),
        details: [
          if (product.code.trim().isNotEmpty)
            RpsQrDetail('Mahsulot kodi', product.code),
          if (product.qolipSize > 0)
            RpsQrDetail('Razmer', '${product.qolipSize}'),
          if (product.customerNames.isNotEmpty)
            RpsQrDetail('Customer', product.customerNames.join(', ')),
        ],
        onReprint: () => _reprintQolipCodeQr(product),
        errorMessage: (error) => qolipErrorMessage(
          error,
          fallback: 'Qolip QR chop etilmadi',
        ),
      ),
    );
  }

  Future<String?> _reprintQolipCodeQr(QolipProduct product) async {
    final code = product.qolipCode.trim();
    final option = await showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      throw StateError('Printer tanlanmadi');
    }
    final printer = option.transport.isOffline
        ? option.offlinePrinter!.printer
        : qolipPrinterChoiceForDriver(
            kind: option.printerKind,
            label: option.printerLabel,
          );
    final result = await MobileApi.instance.qolipPrintCodeQr(
      qolipCode: code,
      driverUrl: option.driverUrl,
      printer: printer,
      printMode: option.transport.isOffline
          ? option.offlinePrinter!.printMode
          : printer == 'godex'
              ? 'label'
              : 'rfid',
      printTransport: option.transport,
    );
    if (option.transport.isOffline) {
      await PrintService.printRps(
        result.printJob,
        printerProfile: option.offlinePrinter,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
              hintText: 'Mahsulot yoki qolip code',
              onChanged: _searchChanged,
              onClear: () {
                _search.clear();
                unawaited(_reload());
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
      bottom: const QolipDock(activeTab: QolipDockTab.products),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<List<QolipProductContainer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: _reload);
            }
            final containers = snapshot.data ?? const <QolipProductContainer>[];
            if (containers.isEmpty) {
              return const Center(child: Text('Qolip topilmadi'));
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                              ? '${container.children.length} ta qolip • bittasi ishlatilmoqda'
                              : '${container.children.length} ta qolip',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.05,
                                  ),
                        ),
                      ],
                    ),
                  ),
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
  });

  final QolipProduct product;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                          ? 'Ishchiga berilgan'
                          : product.qolipSize > 0
                              ? '${product.qolipSize} razmer'
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
                ),
            ],
          ),
        ),
      ),
    );
  }
}
