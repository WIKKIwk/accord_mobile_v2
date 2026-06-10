import 'dart:ui' as ui;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../logic/production_map_pechat_rules.dart';
import '../models/production_map_models.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';

enum _OpenedOrderModule {
  orders,
  apparatus,
  sequence,
  move,
}

class AdminProductionMapOrdersScreen extends StatefulWidget {
  const AdminProductionMapOrdersScreen({
    super.key,
    this.readOnly = false,
    this.workerMode = false,
  });

  final bool readOnly;
  final bool workerMode;

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
  AdminWarehouse? _moveTopApparatus;
  AdminWarehouse? _moveBottomApparatus;
  ProductionMapSaved? _draggingMoveOrder;
  List<ProductionMapSaved> _orders = const [];
  List<AdminWarehouse> _apparatus = const [];
  final Map<String, List<String>> _sequenceByApparatus = {};

  @override
  void initState() {
    super.initState();
    if (widget.workerMode) {
      _module = _OpenedOrderModule.apparatus;
    }
    _tabController = TabController(
      length: _modules.length,
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

  List<_OpenedOrderModule> get _modules {
    return widget.workerMode
        ? const [_OpenedOrderModule.apparatus, _OpenedOrderModule.sequence]
        : _OpenedOrderModule.values;
  }

  Future<void> _load() async {
    final maps = await MobileApi.instance.adminProductionMaps();
    final apparatus = await MobileApi.instance.adminWarehouses(
      parent: 'aparat - A',
      limit: 200,
    );
    final filteredApparatus = _filterApparatusForWorker(apparatus);
    if (!mounted) {
      return;
    }
    setState(() {
      _orders = maps
          .where((item) => item.map.id.trim().startsWith('zakaz-'))
          .toList(growable: false);
      _apparatus = filteredApparatus;
      _selectedApparatus ??=
          filteredApparatus.isEmpty ? null : filteredApparatus.first;
      _syncMoveApparatusDefaults(filteredApparatus);
      _loading = false;
    });
  }

  void _syncMoveApparatusDefaults(List<AdminWarehouse> source) {
    final pechat = source
        .where((item) => productionMapPechatColorCount(item.warehouse) != null)
        .toList(growable: false);
    final candidates = pechat.isEmpty ? source : pechat;
    if (candidates.isEmpty) {
      _moveTopApparatus = null;
      _moveBottomApparatus = null;
      return;
    }
    _moveTopApparatus ??= candidates.first;
    if (_moveBottomApparatus == null) {
      if (candidates.length > 1) {
        _moveBottomApparatus = candidates[1];
      } else {
        for (final item in source) {
          if (item.warehouse != candidates.first.warehouse) {
            _moveBottomApparatus = item;
            break;
          }
        }
      }
    }
  }

  List<AdminWarehouse> _filterApparatusForWorker(List<AdminWarehouse> source) {
    if (!widget.workerMode) {
      return source;
    }
    final allowed = AppSession.instance.profile?.assignedApparatus
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet() ??
        const <String>{};
    if (allowed.isEmpty) {
      return const <AdminWarehouse>[];
    }
    return source
        .where((item) => allowed.contains(item.warehouse.trim()))
        .toList(growable: false);
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

  void _showOrderDetail(ProductionMapSaved order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReadOnlyOrderDetailSheet(order: order),
    );
  }

  void _setModule(_OpenedOrderModule module) {
    if (_module != module) {
      setState(() => _module = module);
    }
    final index = _modules.indexOf(module);
    if (index < 0) {
      return;
    }
    if (_tabController.index != index) {
      _tabController.animateTo(
        index,
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
    final module = _modules[_tabController.index];
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
    if (widget.readOnly) {
      return;
    }
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

  Future<void> _moveOrderBetweenApparatus({
    required ProductionMapSaved order,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) async {
    if (widget.readOnly || from.warehouse.trim() == to.warehouse.trim()) {
      return;
    }
    if (!_canMoveOrderToApparatus(order, to)) {
      showAdminTopNotice(context, 'Bu zakaz tanlangan aparatga tushmaydi');
      return;
    }
    final nextMap = _replaceOrderApparatus(
      order.map,
      from: from.warehouse,
      to: to.warehouse,
    );
    try {
      final saved = await MobileApi.instance.adminSaveProductionMap(nextMap);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = [
          for (final item in _orders)
            if (item.map.id == saved.map.id) saved else item,
        ];
        _draggingMoveOrder = null;
      });
      showAdminTopNotice(context, 'Zakaz ko‘chirildi');
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _draggingMoveOrder = null);
      showAdminTopNotice(context, 'Zakaz ko‘chirilmadi');
    }
  }

  ProductionMapDefinition _replaceOrderApparatus(
    ProductionMapDefinition map, {
    required String from,
    required String to,
  }) {
    var replaced = false;
    final nodes = [
      for (final node in map.nodes)
        if (!replaced &&
            node.kind == 'apparatus' &&
            node.title.trim() == from.trim())
          (() {
            replaced = true;
            return node.copyWith(title: to.trim());
          })()
        else
          node,
    ];
    return map.copyWith(nodes: nodes);
  }

  bool _canMoveOrderToApparatus(
    ProductionMapSaved order,
    AdminWarehouse target,
  ) {
    final colorCount = productionMapPechatColorCount(target.warehouse);
    if (colorCount == null) {
      return true;
    }
    return productionMapPechatCanMoveOrder(
      apparatusColorCount: colorCount,
      rollCount: order.map.rollCount,
      widthMm: order.map.widthMm,
    );
  }

  Future<void> _pickMoveApparatus({required bool top}) async {
    final picked = await showModalBottomSheet<AdminWarehouse>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _MoveApparatusPickerSheet(apparatus: _apparatus),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (top) {
        _moveTopApparatus = picked;
      } else {
        _moveBottomApparatus = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      drawer: widget.workerMode
          ? null
          : AdminNavigationDrawer(
              selectedIndex: 0,
              selectedRouteName: AppRoutes.adminProductionMapOrders,
              onNavigate: _openDrawerRoute,
            ),
      title: widget.workerMode ? 'Aparatlar' : 'Ochilgan zakazlar',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: widget.workerMode
          ? const _WorkerHomeDock()
          : AdminDock(
              activeTab: AdminDockTab.home,
              showPrimaryFab: _module != _OpenedOrderModule.sequence &&
                  _module != _OpenedOrderModule.move,
            ),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  onTap: (index) => _setModule(_modules[index]),
                  tabs: [
                    for (final module in _modules)
                      Tab(text: _moduleLabel(module)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final module in _modules)
                        switch (module) {
                          _OpenedOrderModule.orders => _OrdersModulePage(
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
                              onTapOrder: widget.readOnly ? null : _openOrder,
                            ),
                          _OpenedOrderModule.apparatus => _ApparatusModulePage(
                              bottomPadding: bottomPadding,
                              apparatus: _apparatus,
                              selected: _selectedApparatus,
                              orderCountFor: (apparatus) =>
                                  _ordersForApparatus(apparatus).length,
                              onTapApparatus: _selectApparatus,
                            ),
                          _OpenedOrderModule.sequence => _SequenceModulePage(
                              bottomPadding: bottomPadding,
                              apparatus: _selectedApparatus,
                              orders: _selectedApparatus == null
                                  ? const []
                                  : _ordersForApparatus(_selectedApparatus!),
                              readOnly: widget.readOnly,
                              onReorder: _reorderSelectedApparatusOrders,
                              onTapOrder: widget.readOnly
                                  ? _showOrderDetail
                                  : _openOrder,
                            ),
                          _OpenedOrderModule.move => _MoveModulePage(
                              topApparatus: _moveTopApparatus,
                              bottomApparatus: _moveBottomApparatus,
                              topOrders: _moveTopApparatus == null
                                  ? const []
                                  : _ordersForApparatus(_moveTopApparatus!),
                              bottomOrders: _moveBottomApparatus == null
                                  ? const []
                                  : _ordersForApparatus(_moveBottomApparatus!),
                              draggingOrder: _draggingMoveOrder,
                              canMoveTo: _canMoveOrderToApparatus,
                              onPickTop: () => _pickMoveApparatus(top: true),
                              onPickBottom: () =>
                                  _pickMoveApparatus(top: false),
                              onDragStarted: (order) {
                                setState(() => _draggingMoveOrder = order);
                              },
                              onDragEnded: () {
                                setState(() => _draggingMoveOrder = null);
                              },
                              onMove: _moveOrderBetweenApparatus,
                            ),
                        },
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _moduleLabel(_OpenedOrderModule module) {
    return switch (module) {
      _OpenedOrderModule.orders => 'Zakazlar',
      _OpenedOrderModule.apparatus => 'Aparatlar',
      _OpenedOrderModule.sequence => 'Ketma-ketlik',
      _OpenedOrderModule.move => 'Ko‘chirish',
    };
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
  final ValueChanged<ProductionMapSaved>? onTapOrder;

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
    required this.readOnly,
    required this.onReorder,
    required this.onTapOrder,
  });

  final double bottomPadding;
  final AdminWarehouse? apparatus;
  final List<ProductionMapSaved> orders;
  final bool readOnly;
  final ReorderCallback onReorder;
  final ValueChanged<ProductionMapSaved>? onTapOrder;

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
    if (readOnly) {
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _SequenceOrderRow(
            key: ValueKey('sequence-${selected.warehouse}-${order.map.id}'),
            order: order,
            index: index,
            readOnly: true,
            onTap: onTapOrder == null ? null : () => onTapOrder!(order),
          );
        },
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
          readOnly: false,
          onTap: onTapOrder == null ? null : () => onTapOrder!(order),
        );
      },
    );
  }
}

class _MoveModulePage extends StatelessWidget {
  const _MoveModulePage({
    required this.topApparatus,
    required this.bottomApparatus,
    required this.topOrders,
    required this.bottomOrders,
    required this.draggingOrder,
    required this.canMoveTo,
    required this.onPickTop,
    required this.onPickBottom,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });

  final AdminWarehouse? topApparatus;
  final AdminWarehouse? bottomApparatus;
  final List<ProductionMapSaved> topOrders;
  final List<ProductionMapSaved> bottomOrders;
  final ProductionMapSaved? draggingOrder;
  final bool Function(ProductionMapSaved order, AdminWarehouse target)
      canMoveTo;
  final VoidCallback onPickTop;
  final VoidCallback onPickBottom;
  final ValueChanged<ProductionMapSaved> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required ProductionMapSaved order,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) onMove;

  @override
  Widget build(BuildContext context) {
    final top = topApparatus;
    final bottom = bottomApparatus;
    if (top == null || bottom == null) {
      return const _EmptyOpenedOrders(message: 'Ko‘chirish uchun aparat yo‘q');
    }
    final viewMetrics = MediaQueryData.fromView(View.of(context));
    final dockInset = dockLayoutBottomInset(
      viewMetrics,
      thinGestureBottom: DockGestureOverlayScope.thinGestureBottomOf(context),
    );
    final bottomInset = 60 + dockInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomInset),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                _MoveApparatusHeader(
                  apparatus: top,
                  alignment: Alignment.centerLeft,
                  onTap: onPickTop,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _MoveDropZone(
                    apparatus: top,
                    fromApparatus: bottom,
                    orders: topOrders,
                    draggingOrder: draggingOrder,
                    canMoveTo: canMoveTo,
                    onDragStarted: onDragStarted,
                    onDragEnded: onDragEnded,
                    onMove: onMove,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _MoveBoundary(
              apparatus: bottom,
              onTap: onPickBottom,
            ),
          ),
          Expanded(
            child: _MoveDropZone(
              apparatus: bottom,
              fromApparatus: top,
              orders: bottomOrders,
              draggingOrder: draggingOrder,
              canMoveTo: canMoveTo,
              onDragStarted: onDragStarted,
              onDragEnded: onDragEnded,
              onMove: onMove,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveDropZone extends StatelessWidget {
  const _MoveDropZone({
    required this.apparatus,
    required this.fromApparatus,
    required this.orders,
    required this.draggingOrder,
    required this.canMoveTo,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });

  final AdminWarehouse apparatus;
  final AdminWarehouse fromApparatus;
  final List<ProductionMapSaved> orders;
  final ProductionMapSaved? draggingOrder;
  final bool Function(ProductionMapSaved order, AdminWarehouse target)
      canMoveTo;
  final ValueChanged<ProductionMapSaved> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required ProductionMapSaved order,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) onMove;

  @override
  Widget build(BuildContext context) {
    final dragged = draggingOrder;
    final blocked = dragged != null && !canMoveTo(dragged, apparatus);
    return DragTarget<_MoveDragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data.source.warehouse.trim() != apparatus.warehouse.trim() &&
          canMoveTo(details.data.order, apparatus),
      onAcceptWithDetails: (details) {
        onMove(
          order: details.data.order,
          from: details.data.source,
          to: apparatus,
        );
      },
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: blocked
                ? Theme.of(context)
                    .colorScheme
                    .errorContainer
                    .withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: blocked ? 1.8 : 0,
              sigmaY: blocked ? 1.8 : 0,
            ),
            child: orders.isEmpty
                ? _MoveEmptyZone(apparatus: apparatus)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _MoveOrderTile(
                        order: order,
                        source: apparatus,
                        index: index,
                        onDragStarted: () => onDragStarted(order),
                        onDragEnded: onDragEnded,
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _MoveApparatusHeader extends StatelessWidget {
  const _MoveApparatusHeader({
    required this.apparatus,
    required this.alignment,
    required this.onTap,
  });

  final AdminWarehouse apparatus;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: alignment,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.precision_manufacturing_rounded,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    apparatus.warehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveBoundary extends StatelessWidget {
  const _MoveBoundary({
    required this.apparatus,
    required this.onTap,
  });

  final AdminWarehouse apparatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          _MoveApparatusHeader(
            apparatus: apparatus,
            alignment: Alignment.center,
            onTap: onTap,
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _MoveOrderTile extends StatelessWidget {
  const _MoveOrderTile({
    required this.order,
    required this.source,
    required this.index,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final ProductionMapSaved order;
  final AdminWarehouse source;
  final int index;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final feedbackWidth = constraints.maxWidth;
        return _MoveOrderCard(
          order: order,
          index: index,
          trailing: LongPressDraggable<_MoveDragPayload>(
            data: _MoveDragPayload(order: order, source: source),
            axis: Axis.vertical,
            dragAnchorStrategy: (_, handleContext, position) {
              final box = handleContext.findRenderObject()! as RenderBox;
              final local = box.globalToLocal(position);
              return Offset(feedbackWidth - 28, local.dy);
            },
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: feedbackWidth,
                child: _MoveOrderCard(
                  order: order,
                  index: index,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: _MoveDragHandle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            onDragStarted: onDragStarted,
            onDragEnd: (_) => onDragEnded(),
            onDraggableCanceled: (_, __) => onDragEnded(),
            child: _MoveDragHandle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

class _MoveDragPayload {
  const _MoveDragPayload({
    required this.order,
    required this.source,
  });

  final ProductionMapSaved order;
  final AdminWarehouse source;
}

class _MoveOrderCard extends StatelessWidget {
  const _MoveOrderCard({
    required this.order,
    required this.index,
    this.trailing,
  });

  final ProductionMapSaved order;
  final int index;
  final Widget? trailing;

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
              trailing ?? _MoveDragHandle(color: scheme.onSurfaceVariant),
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

class _MoveDragHandle extends StatelessWidget {
  const _MoveDragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        Icons.drag_handle_rounded,
        color: color,
      ),
    );
  }
}

class _MoveEmptyZone extends StatelessWidget {
  const _MoveEmptyZone({required this.apparatus});

  final AdminWarehouse apparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        '${apparatus.warehouse} uchun zakaz yo‘q',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _MoveApparatusPickerSheet extends StatelessWidget {
  const _MoveApparatusPickerSheet({required this.apparatus});

  final List<AdminWarehouse> apparatus;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        shrinkWrap: true,
        children: [
          Text(
            'Aparat tanlang',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          M3SegmentSpacedColumn(
            children: [
              for (var index = 0; index < apparatus.length; index++)
                _ApparatusRow(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    apparatus.length,
                  ),
                  apparatus: apparatus[index],
                  selected: false,
                  orderCount: 0,
                  onTap: () => Navigator.of(context).pop(apparatus[index]),
                ),
            ],
          ),
        ],
      ),
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
  final ValueChanged<ProductionMapSaved>? onTapOrder;

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
            onTap: onTapOrder == null ? null : () => onTapOrder!(orders[index]),
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
  final VoidCallback? onTap;

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
    required this.readOnly,
    required this.onTap,
  });

  final ProductionMapSaved order;
  final int index;
  final bool readOnly;
  final VoidCallback? onTap;

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
                if (!readOnly)
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

class _WorkerHomeDock extends StatelessWidget {
  const _WorkerHomeDock();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64 + bottom,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Uy',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyOrderDetailSheet extends StatelessWidget {
  const _ReadOnlyOrderDetailSheet({required this.order});

  final ProductionMapSaved order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final steps = _linearNodes(map);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              map.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            _DetailCard(
              children: [
                if (map.orderNumber.trim().isNotEmpty)
                  _DetailRow(label: 'Zakaz raqami', value: map.orderNumber),
                _DetailRow(label: 'Mahsulot', value: _productTitle(map)),
                if (map.productCode.trim().isNotEmpty)
                  _DetailRow(label: 'Kod', value: map.productCode),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Ketma-ketlik',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (var index = 0; index < steps.length; index++)
                      _SequenceStepTile(
                        node: steps[index],
                        index: index,
                        isLast: index == steps.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _productTitle(ProductionMapDefinition map) {
    for (final node in map.nodes) {
      final title = node.title.trim();
      if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
        return title;
      }
    }
    return map.title;
  }

  List<ProductionMapNode> _linearNodes(ProductionMapDefinition map) {
    final byId = {for (final node in map.nodes) node.id: node};
    final byFrom = <String, List<ProductionMapEdge>>{};
    for (final edge in map.edges) {
      byFrom.putIfAbsent(edge.from, () => <ProductionMapEdge>[]).add(edge);
    }
    final start = map.nodes
        .where((node) => node.kind == 'start')
        .map((node) => node.id)
        .cast<String?>()
        .firstWhere((id) => id != null, orElse: () => null);
    if (start == null || !byId.containsKey(start)) {
      return map.nodes;
    }
    final result = <ProductionMapNode>[];
    final seen = <String>{};
    var current = start;
    while (seen.add(current)) {
      final node = byId[current];
      if (node != null) {
        result.add(node);
      }
      final next = byFrom[current]
          ?.map((edge) => edge.to)
          .where((id) => byId.containsKey(id))
          .cast<String?>()
          .firstWhere((id) => id != null, orElse: () => null);
      if (next == null) {
        break;
      }
      current = next;
    }
    return result.isEmpty ? map.nodes : result;
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(children: children),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SequenceStepTile extends StatelessWidget {
  const _SequenceStepTile({
    required this.node,
    required this.index,
    required this.isLast,
  });

  final ProductionMapNode node;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (node.kind) {
      'start' => Icons.play_arrow_rounded,
      'apparatus' => Icons.precision_manufacturing_rounded,
      'kk_product' => Icons.inventory_2_outlined,
      'end' => Icons.flag_rounded,
      _ => Icons.account_tree_outlined,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              SizedBox.square(
                dimension: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: scheme.outlineVariant,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.title.trim().isEmpty
                        ? 'Qadam ${index + 1}'
                        : node.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _kindLabel(node.kind),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(String kind) {
    return switch (kind) {
      'start' => 'Boshlanish',
      'apparatus' => 'Aparat',
      'kk_product' => 'KK li mahsulot',
      'end' => 'Yakun',
      _ => kind,
    };
  }
}
