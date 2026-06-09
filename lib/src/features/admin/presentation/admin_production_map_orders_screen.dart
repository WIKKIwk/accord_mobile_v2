import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../models/production_map_models.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'package:flutter/material.dart';

enum _OpenedOrderModule {
  orders,
  apparatus,
  sequence,
}

class AdminProductionMapOrdersScreen extends StatefulWidget {
  const AdminProductionMapOrdersScreen({super.key});

  @override
  State<AdminProductionMapOrdersScreen> createState() =>
      _AdminProductionMapOrdersScreenState();
}

class _AdminProductionMapOrdersScreenState
    extends State<AdminProductionMapOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final TabController _tabController;
  bool _openingRoute = false;
  bool _loading = true;
  String _searchQuery = '';
  _OpenedOrderModule _module = _OpenedOrderModule.orders;
  AdminWarehouse? _selectedApparatus;
  List<ProductionMapSaved> _orders = const [];
  List<AdminWarehouse> _apparatus = const [];
  final Map<String, List<String>> _sequenceByApparatus = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _OpenedOrderModule.values.length,
      vsync: this,
    );
    _tabController.addListener(_syncModuleFromTab);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_syncModuleFromTab);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final maps = await MobileApi.instance.adminProductionMaps();
    final apparatus = await MobileApi.instance.adminWarehouses(
      parent: 'aparat - A',
      limit: 200,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _orders = maps
          .where((item) => item.map.id.trim().startsWith('zakaz-'))
          .toList(growable: false);
      _apparatus = apparatus;
      _selectedApparatus ??= apparatus.isEmpty ? null : apparatus.first;
      _loading = false;
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
    Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
    );
  }

  void _openOrder(ProductionMapSaved order) {
    Navigator.of(context).pushNamed(
      AppRoutes.adminProductionMapTest,
      arguments: order,
    );
  }

  void _setModule(_OpenedOrderModule module) {
    if (_module != module) {
      setState(() => _module = module);
    }
    if (_tabController.index != module.index) {
      _tabController.animateTo(
        module.index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectApparatus(AdminWarehouse apparatus) {
    setState(() => _selectedApparatus = apparatus);
    _setModule(_OpenedOrderModule.sequence);
  }

  void _syncModuleFromTab() {
    final module = _OpenedOrderModule.values[_tabController.index];
    if (_module != module) {
      setState(() => _module = module);
    }
  }

  List<ProductionMapSaved> _visibleOrders() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _orders;
    }
    return _orders.where((order) {
      final map = order.map;
      final haystack = [
        map.title,
        map.productCode,
        for (final node in map.nodes) node.title,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final filtered = _orders.where((order) {
      return order.map.nodes.any(
        (node) => node.kind == 'apparatus' && node.title.trim() == title,
      );
    }).toList();
    final sequence = _sequenceByApparatus[title] ?? const <String>[];
    if (sequence.isEmpty) {
      return filtered;
    }
    final byId = {for (final order in filtered) order.map.id: order};
    return [
      for (final id in sequence)
        if (byId.containsKey(id)) byId.remove(id)!,
      ...byId.values,
    ];
  }

  void _reorderSelectedApparatusOrders(int oldIndex, int newIndex) {
    final apparatus = _selectedApparatus;
    if (apparatus == null) {
      return;
    }
    final orders = _ordersForApparatus(apparatus);
    if (oldIndex == newIndex) {
      return;
    }
    final moved = orders.removeAt(oldIndex);
    orders.insert(newIndex, moved);
    setState(() {
      _sequenceByApparatus[apparatus.warehouse.trim()] =
          orders.map((order) => order.map.id).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminProductionMapOrders,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Ochilgan zakazlar',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  onTap: (index) =>
                      _setModule(_OpenedOrderModule.values[index]),
                  tabs: const [
                    Tab(text: 'Zakazlar'),
                    Tab(text: 'Aparatlar'),
                    Tab(text: 'Ketma-ketlik'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _OrdersModulePage(
                        bottomPadding: bottomPadding,
                        searchController: _searchController,
                        orders: _orders,
                        visibleOrders: _visibleOrders(),
                        onSearchChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        onSearchClear: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        onTapOrder: _openOrder,
                      ),
                      _ApparatusModulePage(
                        bottomPadding: bottomPadding,
                        apparatus: _apparatus,
                        selected: _selectedApparatus,
                        orderCountFor: (apparatus) =>
                            _ordersForApparatus(apparatus).length,
                        onTapApparatus: _selectApparatus,
                      ),
                      _SequenceModulePage(
                        bottomPadding: bottomPadding,
                        apparatus: _selectedApparatus,
                        orders: _selectedApparatus == null
                            ? const []
                            : _ordersForApparatus(_selectedApparatus!),
                        onReorder: _reorderSelectedApparatusOrders,
                        onTapOrder: _openOrder,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _OrdersModulePage extends StatelessWidget {
  const _OrdersModulePage({
    required this.bottomPadding,
    required this.searchController,
    required this.orders,
    required this.visibleOrders,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onTapOrder,
  });

  final double bottomPadding;
  final TextEditingController searchController;
  final List<ProductionMapSaved> orders;
  final List<ProductionMapSaved> visibleOrders;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final ValueChanged<ProductionMapSaved> onTapOrder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding),
      children: [
        _OpenedOrderSearchField(
          controller: searchController,
          onChanged: onSearchChanged,
          onClear: onSearchClear,
        ),
        if (orders.isEmpty)
          const _EmptyOpenedOrders(message: 'Ochilgan zakaz yo‘q')
        else if (visibleOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Zakaz topilmadi')
        else
          _OpenedOrderList(
            orders: visibleOrders,
            onTapOrder: onTapOrder,
          ),
      ],
    );
  }
}

class _ApparatusModulePage extends StatelessWidget {
  const _ApparatusModulePage({
    required this.bottomPadding,
    required this.apparatus,
    required this.selected,
    required this.orderCountFor,
    required this.onTapApparatus,
  });

  final double bottomPadding;
  final List<AdminWarehouse> apparatus;
  final AdminWarehouse? selected;
  final int Function(AdminWarehouse apparatus) orderCountFor;
  final ValueChanged<AdminWarehouse> onTapApparatus;

  @override
  Widget build(BuildContext context) {
    if (apparatus.isEmpty) {
      return const _EmptyOpenedOrders(message: 'Aparat topilmadi');
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      children: [
        M3SegmentSpacedColumn(
          children: [
            for (var index = 0; index < apparatus.length; index++)
              _ApparatusRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  apparatus.length,
                ),
                apparatus: apparatus[index],
                selected: selected?.warehouse == apparatus[index].warehouse,
                orderCount: orderCountFor(apparatus[index]),
                onTap: () => onTapApparatus(apparatus[index]),
              ),
          ],
        ),
      ],
    );
  }
}

class _SequenceModulePage extends StatelessWidget {
  const _SequenceModulePage({
    required this.bottomPadding,
    required this.apparatus,
    required this.orders,
    required this.onReorder,
    required this.onTapOrder,
  });

  final double bottomPadding;
  final AdminWarehouse? apparatus;
  final List<ProductionMapSaved> orders;
  final ReorderCallback onReorder;
  final ValueChanged<ProductionMapSaved> onTapOrder;

  @override
  Widget build(BuildContext context) {
    final selected = apparatus;
    if (selected == null) {
      return const _EmptyOpenedOrders(message: 'Avval aparat tanlang');
    }
    if (orders.isEmpty) {
      return _EmptyOpenedOrders(
        message: '${selected.warehouse} uchun zakaz yo‘q',
      );
    }
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      buildDefaultDragHandles: false,
      itemCount: orders.length,
      onReorderItem: onReorder,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _SequenceOrderRow(
          key: ValueKey('sequence-${selected.warehouse}-${order.map.id}'),
          order: order,
          index: index,
          onTap: () => onTapOrder(order),
        );
      },
    );
  }
}

class _OpenedOrderSearchField extends StatelessWidget {
  const _OpenedOrderSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final hasText = controller.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Ochilgan zakaz qidirish',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Tozalash',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OpenedOrderList extends StatelessWidget {
  const _OpenedOrderList({
    required this.orders,
    required this.onTapOrder,
  });

  final List<ProductionMapSaved> orders;
  final ValueChanged<ProductionMapSaved> onTapOrder;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (var index = 0; index < orders.length; index++)
          _OpenedOrderRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              orders.length,
            ),
            order: orders[index],
            onTap: () => onTapOrder(orders[index]),
          ),
      ],
    );
  }
}

class _OpenedOrderRow extends StatelessWidget {
  const _OpenedOrderRow({
    required this.slot,
    required this.order,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final apparatusCount =
        map.nodes.where((node) => node.kind == 'apparatus').length;
    final productTitle = _productTitle(map);
    final subtitle = [
      if (productTitle.isNotEmpty) productTitle,
      if (map.productCode.trim().isNotEmpty) map.productCode.trim(),
      if (apparatusCount > 0) '$apparatusCount ta aparat',
    ].join(' • ');
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
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
                    Icons.account_tree_outlined,
                    color: scheme.onPrimaryContainer,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      map.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _productTitle(ProductionMapDefinition map) {
    for (final node in map.nodes) {
      final title = node.title.trim();
      if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
        return title;
      }
    }
    return '';
  }
}

class _ApparatusRow extends StatelessWidget {
  const _ApparatusRow({
    required this.slot,
    required this.apparatus,
    required this.selected,
    required this.orderCount,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminWarehouse apparatus;
  final bool selected;
  final int orderCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color:
          selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.surface.withValues(alpha: 0.72)
                        : scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.precision_manufacturing_rounded,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onPrimaryContainer,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apparatus.warehouse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$orderCount ta zakaz',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SequenceOrderRow extends StatelessWidget {
  const _SequenceOrderRow({
    super.key,
    required this.order,
    required this.index,
    required this.onTap,
  });

  final ProductionMapSaved order;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final productTitle = _productTitle(order.map);
    final subtitle = [
      if (productTitle.isNotEmpty) productTitle,
      if (order.map.productCode.trim().isNotEmpty) order.map.productCode.trim(),
    ].join(' • ');
    return Padding(
      padding: const EdgeInsets.only(bottom: M3SegmentedListGeometry.gap),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(M3SegmentedListGeometry.cornerLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(M3SegmentedListGeometry.cornerLarge),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.map.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _productTitle(ProductionMapDefinition map) {
    for (final node in map.nodes) {
      final title = node.title.trim();
      if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
        return title;
      }
    }
    return '';
  }
}

class _EmptyOpenedOrders extends StatelessWidget {
  const _EmptyOpenedOrders({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
