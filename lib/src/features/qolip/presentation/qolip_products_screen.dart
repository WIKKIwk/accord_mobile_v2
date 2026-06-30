import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
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

  void _reload() {
    setState(() {
      _expandedContainerKey = null;
      _future = _load();
    });
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
    _searchDebounce = Timer(const Duration(milliseconds: 260), _reload);
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _printQolipCodeQr(QolipProduct product) async {
    final code = product.qolipCode.trim();
    if (code.isEmpty) {
      return;
    }
    final option = await showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      return;
    }
    try {
      final printer = qolipPrinterChoiceForDriver(
        kind: option.printerKind,
        label: option.printerLabel,
      );
      final qr = await MobileApi.instance.qolipPrintCodeQr(
        qolipCode: code,
        driverUrl: option.driverUrl,
        printer: printer,
        printMode: printer == 'godex' ? 'label' : 'rfid',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${qr.qolipCode} QR chop etildi')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qolip QR chop etilmadi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppShell(
      title: '',
      subtitle: '',
      nativeTopBar: true,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _search,
        focusNode: _searchFocusNode,
        hintText: 'Mahsulot yoki qolip code',
        onChanged: _searchChanged,
        onClear: () {
          _search.clear();
          _reload();
        },
        onBackWithContext: (context) =>
            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
        leadingIcon: Icons.menu_rounded,
        leadingTooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      drawer: QolipNavigationDrawer(
        selectedIndex: 1,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: QolipDockTab.products),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: FutureBuilder<List<QolipProductContainer>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: () async => _reload());
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
                    onToggle: () => _toggleContainerExpanded(containers[index]),
                    onPrintCodeQr: _printQolipCodeQr,
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
    required this.onToggle,
    required this.onPrintCodeQr,
  });

  final M3SegmentVerticalSlot slot;
  final QolipProductContainer container;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<QolipProduct> onPrintCodeQr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final container = this.container;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: scheme.surface,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                        color: scheme.onPrimaryContainer,
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
                          '${container.children.length} ta qolip',
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
                            onLongPress: () => onPrintCodeQr(child),
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
  const _QolipCodeRow({required this.product, required this.onLongPress});

  final QolipProduct product;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
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
                Icons.qr_code_2_rounded,
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
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (product.qolipSize > 0)
                  Text(
                    '${product.qolipSize} razmer',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
