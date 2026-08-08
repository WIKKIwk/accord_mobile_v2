import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../shared/models/app_models.dart';
import '../logic/apparatus_queue_state.dart';
import '../logic/factory_map_order_filter.dart';
import '../logic/production_map_chain.dart';
import '../models/production_map_models.dart';
import 'admin_factory_map_viewer.dart';
import 'admin_production_map_orders_screen.dart'
    show showAdminProductionMapOrderReadOnlyDetail;
import 'widgets/admin_dock.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_top_notice.dart';

class AdminFactoryMapScreen extends StatefulWidget {
  const AdminFactoryMapScreen({super.key});

  @override
  State<AdminFactoryMapScreen> createState() => _AdminFactoryMapScreenState();
}

class _AdminFactoryMapScreenState extends State<AdminFactoryMapScreen> {
  Animation<double>? _routeAnimation;
  bool _modelLoadScheduled = false;
  bool _showModel = false;
  bool _factoryMapInteractionEnabled = true;
  bool _loadingMappings = false;
  String _mappingError = '';
  List<AdminApparatus> _apparatus = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (!identical(animation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = animation;
      _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    }
    if (animation == null || animation.status == AnimationStatus.completed) {
      _scheduleModelLoad();
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    super.dispose();
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleModelLoad();
    }
  }

  void _scheduleModelLoad() {
    if (_modelLoadScheduled) {
      return;
    }
    _modelLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final animation = _routeAnimation;
      if (animation != null && animation.status != AnimationStatus.completed) {
        _modelLoadScheduled = false;
        return;
      }
      setState(() => _showModel = true);
      unawaited(_loadMappings());
    });
  }

  Future<void> _loadMappings() async {
    if (_loadingMappings) {
      return;
    }
    setState(() {
      _loadingMappings = true;
      _mappingError = '';
    });
    try {
      final apparatus = await MobileApi.instance.adminApparatus(limit: 500);
      if (!mounted) {
        return;
      }
      setState(() => _apparatus = apparatus);
    } catch (_) {
      if (mounted) {
        setState(() => _mappingError = 'Aparat bog‘lanishlari olinmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMappings = false);
      }
    }
  }

  void _handleObjectTap(FactoryMapObjectSelection selection) {
    AdminApparatus? mapped;
    for (final apparatus in _apparatus) {
      if (apparatus.factoryMapObjectId.trim() == selection.objectId) {
        mapped = apparatus;
        break;
      }
    }
    if (mapped == null) {
      showAdminTopNotice(
        context,
        'Bu 3D obyekt hali hech qaysi apparatga biriktirilmagan',
      );
      return;
    }
    setState(() => _factoryMapInteractionEnabled = false);
    unawaited(_showApparatusLiveSheet(mapped));
  }

  Future<void> _showApparatusLiveSheet(AdminApparatus apparatus) async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.58,
          minChildSize: 0.32,
          maxChildSize: 0.92,
          snap: true,
          snapSizes: const [0.58, 0.92],
          builder: (context, scrollController) => _FactoryApparatusLiveSheet(
            apparatus: apparatus,
            scrollController: scrollController,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _factoryMapInteractionEnabled = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 128;
    final mappedCount = _apparatus
        .where((item) => item.factoryMapObjectId.trim().isNotEmpty)
        .length;

    return AdminShell(
      title: 'Zavod kartasi',
      selectedRouteName: AppRoutes.adminFactoryMap,
      activeTab: AdminDockTab.home,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: ListView(
          padding: EdgeInsets.fromLTRB(4, 8, 4, bottomPadding),
          children: [
            Container(
              height: MediaQuery.sizeOf(context).height * 0.72,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: scheme.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: _showModel
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        IgnorePointer(
                          ignoring: !_factoryMapInteractionEnabled,
                          child: AdminFactoryMapViewer(
                            interactionEnabled: _factoryMapInteractionEnabled,
                            onObjectTap: _handleObjectTap,
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          right: 10,
                          child: IgnorePointer(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xD91B1F21),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  child: Text(
                                    _loadingMappings
                                        ? 'Aparatlar yuklanmoqda…'
                                        : _mappingError.isNotEmpty
                                            ? _mappingError
                                            : '$mappedCount ta apparat ulangan · apparat ustiga bosing',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: IconButton.filledTonal(
                            tooltip: 'Bog‘lanishlarni yangilash',
                            onPressed: _loadingMappings ? null : _loadMappings,
                            icon: _loadingMappings
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ],
                    )
                  : const _FactoryMapPlaceholder(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactoryApparatusLiveSheet extends StatefulWidget {
  const _FactoryApparatusLiveSheet({
    required this.apparatus,
    required this.scrollController,
  });

  final AdminApparatus apparatus;
  final ScrollController scrollController;

  @override
  State<_FactoryApparatusLiveSheet> createState() =>
      _FactoryApparatusLiveSheetState();
}

class _FactoryApparatusLiveSheetState
    extends State<_FactoryApparatusLiveSheet> {
  Timer? _refreshTimer;
  bool _loading = true;
  bool _refreshing = false;
  String _error = '';
  AdminApparatusQueueSnapshot? _snapshot;
  List<ProductionMapSaved> _orders = const [];
  List<AdminRawMaterialAssignment> _materials = const [];
  List<AdminProgressBatch> _wipBatches = const [];
  FactoryMapOrderFilter _orderFilter = FactoryMapOrderFilter.inProgress;
  bool _orderFilterExpanded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_load(silent: true)),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminProductionMaps(),
        MobileApi.instance.adminProductionMapQueueSnapshot(),
        MobileApi.instance.adminRawMaterialAssignments(
          apparatus: widget.apparatus.name,
        ),
        MobileApi.instance.adminWipBatches(
          status: 'all',
          apparatus: widget.apparatus.name,
          limit: 250,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = results[0] as List<ProductionMapSaved>;
        _snapshot = results[1] as AdminApparatusQueueSnapshot;
        _materials = results[2] as List<AdminRawMaterialAssignment>;
        _wipBatches = results[3] as List<AdminProgressBatch>;
        _error = '';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Live ishlab chiqarish ma’lumoti olinmadi');
      }
    } finally {
      _refreshing = false;
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  T? _forStation<T>(Map<String, T> values) {
    final direct = values[widget.apparatus.name.trim()];
    if (direct != null) {
      return direct;
    }
    for (final entry in values.entries) {
      if (productionMapStationTitlesMatch(
        entry.key,
        widget.apparatus.name,
      )) {
        return entry.value;
      }
    }
    return null;
  }

  List<String> get _orderIds {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const [];
    }
    final sequence = _forStation(snapshot.sequences) ?? const <String>[];
    final visible = _forStation(snapshot.visibleOrderIds) ?? const <String>[];
    final ids = <String>[];
    final seen = <String>{};
    void addAll(Iterable<String> values) {
      for (final value in values) {
        final id = value.trim();
        if (id.isNotEmpty && seen.add(id)) {
          ids.add(id);
        }
      }
    }

    addAll(
        effectiveQueueSequence(sequence: sequence, visibleOrderIds: visible));
    addAll(visible);
    addAll(_materials.map((item) => item.orderId));
    addAll(_wipBatches.map((item) => item.orderId));
    return ids;
  }

  Map<String, String> get _queueStates => _snapshot == null
      ? const <String, String>{}
      : _forStation(_snapshot!.queueStates) ?? const <String, String>{};

  ProductionMapSaved? _orderForId(String orderId) {
    for (final order in _orders) {
      if (order.map.id.trim() == orderId.trim()) {
        return order;
      }
    }
    return null;
  }

  List<AdminRawMaterialAssignment> _materialsForOrder(String orderId) =>
      _materials.where((item) {
        if (item.orderId.trim() != orderId.trim()) {
          return false;
        }
        if (_orderFilter != FactoryMapOrderFilter.inProgress) {
          return true;
        }
        final stockStatus = item.stockStatus.trim().toLowerCase();
        return stockStatus != 'consumed' &&
            (item.remainingQty > 0 ||
                stockStatus == 'available' ||
                stockStatus == 'in_use');
      }).toList(growable: false);

  List<AdminProgressBatch> _wipForOrder(String orderId) =>
      _wipBatches.where((item) {
        if (item.orderId.trim() != orderId.trim()) {
          return false;
        }
        if (_orderFilter != FactoryMapOrderFilter.inProgress) {
          return true;
        }
        final status = item.wipStatus.trim().toLowerCase();
        return status.isEmpty || status == 'waiting' || status == 'in_use';
      }).toList(growable: false);

  void _setOrderFilter(FactoryMapOrderFilter filter) {
    if (_orderFilter == filter) {
      setState(() => _orderFilterExpanded = false);
      return;
    }
    setState(() {
      _orderFilter = filter;
      _orderFilterExpanded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final states = _queueStates;
    final orderIds = filterFactoryMapOrderIds(
      orderIds: _orderIds,
      states: states,
      filter: _orderFilter,
    );
    final visibleMaterials = [
      for (final orderId in orderIds) ..._materialsForOrder(orderId),
    ];
    final visibleWipBatches = [
      for (final orderId in orderIds) ..._wipForOrder(orderId),
    ];
    final activeOrderId = firstActiveQueueOrderId(
      sequence: orderIds,
      states: states,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 10),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.apparatus.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      'Live holat · har 15 soniyada yangilanadi',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Yangilash',
                onPressed: _refreshing ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: 'Yopish',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        AdminExpandableFilterChip<FactoryMapOrderFilter>(
          chipKey: const ValueKey('factory-map-order-filter-chip'),
          label: 'Holat',
          emptyLabel: _orderFilter.label,
          icon: Icons.filter_list_rounded,
          selectedValue: _orderFilter,
          expanded: _orderFilterExpanded,
          onToggle: () => setState(
            () => _orderFilterExpanded = !_orderFilterExpanded,
          ),
          onSelect: _setOrderFilter,
          optionKeyPrefix: 'factory-map-order-filter-option',
          options: [
            for (final filter in FactoryMapOrderFilter.values)
              AdminFilterChipOption<FactoryMapOrderFilter>(
                value: filter,
                label: filter.label,
                key: ValueKey(
                  'factory-map-order-filter-option-${filter.name}',
                ),
              ),
          ],
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: widget.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      if (_error.isNotEmpty)
                        _FactoryMapNoticeCard(
                          icon: Icons.cloud_off_outlined,
                          message: _error,
                          actionLabel: 'Qayta urinish',
                          onAction: _load,
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FactoryMapMetric(
                            icon: Icons.receipt_long_outlined,
                            label: '${orderIds.length} order',
                          ),
                          _FactoryMapMetric(
                            icon: Icons.inventory_2_outlined,
                            label: '${visibleMaterials.length} homashyo',
                          ),
                          _FactoryMapMetric(
                            icon: Icons.precision_manufacturing_outlined,
                            label: '${visibleWipBatches.length} WIP',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (orderIds.isEmpty)
                        _FactoryMapNoticeCard(
                          icon: Icons.check_circle_outline_rounded,
                          message: _orderFilter.emptyMessage,
                        )
                      else
                        M3SegmentSpacedColumn(
                          children: [
                            for (var index = 0;
                                index < orderIds.length;
                                index++)
                              _FactoryOrderCard(
                                key: ValueKey(
                                  'factory-map-order-${orderIds[index]}',
                                ),
                                slot: M3SegmentedListGeometry
                                    .standaloneListSlotForIndex(
                                  index,
                                  orderIds.length,
                                ),
                                orderId: orderIds[index],
                                order: _orderForId(orderIds[index]),
                                state: apparatusQueueOrderStateFromRaw(
                                  states[orderIds[index]],
                                ),
                                isActive: activeOrderId == orderIds[index],
                                materials: _materialsForOrder(orderIds[index]),
                                wipBatches: _wipForOrder(orderIds[index]),
                                onOpenDetail: _orderForId(orderIds[index]) ==
                                        null
                                    ? null
                                    : () =>
                                        showAdminProductionMapOrderReadOnlyDetail(
                                          context,
                                          order: _orderForId(
                                            orderIds[index],
                                          )!,
                                          apparatus: widget.apparatus,
                                          queueSnapshot: _snapshot,
                                        ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _FactoryOrderCard extends StatefulWidget {
  const _FactoryOrderCard({
    super.key,
    required this.slot,
    required this.orderId,
    required this.order,
    required this.state,
    required this.isActive,
    required this.materials,
    required this.wipBatches,
    required this.onOpenDetail,
  });

  final M3SegmentVerticalSlot slot;
  final String orderId;
  final ProductionMapSaved? order;
  final ApparatusQueueOrderState state;
  final bool isActive;
  final List<AdminRawMaterialAssignment> materials;
  final List<AdminProgressBatch> wipBatches;
  final VoidCallback? onOpenDetail;

  @override
  State<_FactoryOrderCard> createState() => _FactoryOrderCardState();
}

class _FactoryOrderCardState extends State<_FactoryOrderCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isActive;
  }

  @override
  void didUpdateWidget(covariant _FactoryOrderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _expanded = true;
    }
  }

  String get _statusLabel => switch (widget.state) {
        ApparatusQueueOrderState.inProgress => 'Jarayonda',
        ApparatusQueueOrderState.paused => 'Pauzada',
        ApparatusQueueOrderState.completed => 'Tugagan',
        ApparatusQueueOrderState.pending => 'Navbatda',
      };

  Color _statusColor(ColorScheme scheme) => switch (widget.state) {
        ApparatusQueueOrderState.inProgress => const Color(0xFF2E7D32),
        ApparatusQueueOrderState.paused => const Color(0xFFC62828),
        ApparatusQueueOrderState.completed => scheme.outline,
        ApparatusQueueOrderState.pending => scheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final map = widget.order?.map;
    final orderNumber = map?.orderNumber.trim() ?? '';
    final title = orderNumber.isEmpty ? widget.orderId : 'Order №$orderNumber';
    final statusColor = _statusColor(scheme);
    final subtitle = [
      _statusLabel,
      if ((map?.customerName.trim() ?? '').isNotEmpty) map!.customerName.trim(),
      if ((map?.productCode.trim() ?? '').isNotEmpty) map!.productCode.trim(),
    ].join(' · ');
    return M3ExpandableFilledSurface(
      slot: widget.slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(widget.slot),
      expanded: _expanded,
      onExpandedChanged: (value) => setState(() => _expanded = value),
      headerPadding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      header: Row(
        children: [
          SizedBox.square(
            dimension: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.isActive
                    ? Icons.play_arrow_rounded
                    : Icons.schedule_rounded,
                size: 18,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.05,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      expandedChild: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (widget.materials.isEmpty)
              const _FactoryMapEmptyRow(
                icon: Icons.inventory_2_outlined,
                text: 'Biriktirilgan homashyo yo‘q',
              )
            else ...[
              const _FactoryMapSectionTitle(title: 'Homashyolar'),
              for (final material in widget.materials)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.inventory_2_outlined, size: 20),
                  title: Text(
                    material.itemName.trim().isEmpty
                        ? material.itemCode
                        : material.itemName,
                  ),
                  subtitle: Text(
                    [
                      if (material.itemCode.trim().isNotEmpty)
                        material.itemCode,
                      if (material.stockWarehouse.trim().isNotEmpty)
                        material.stockWarehouse,
                    ].join(' · '),
                  ),
                  trailing: Text(
                    formatQuantityWithUnit(
                      material.remainingQty,
                      material.stockUom,
                      trimTrailingZeros: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
            if (widget.wipBatches.isNotEmpty) ...[
              const _FactoryMapSectionTitle(title: 'WIP / yarim tayyor'),
              for (final batch in widget.wipBatches)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 20,
                  ),
                  title: Text(
                    batch.labelItemName.trim().isEmpty
                        ? batch.batchId
                        : batch.labelItemName,
                  ),
                  subtitle: Text(
                    [
                      if (batch.currentLocation.trim().isNotEmpty)
                        batch.currentLocation,
                      if (batch.nextApparatus.trim().isNotEmpty)
                        'Keyingi: ${batch.nextApparatus}',
                    ].join(' · '),
                  ),
                  trailing: Text(
                    formatQuantityWithUnit(
                      batch.producedQty,
                      batch.uom,
                      trimTrailingZeros: true,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
            ],
            if (widget.onOpenDetail != null) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: widget.onOpenDetail,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Orderni to‘liq ko‘rish'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactoryMapMetric extends StatelessWidget {
  const _FactoryMapMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FactoryMapNoticeCard extends StatelessWidget {
  const _FactoryMapNoticeCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _FactoryMapSectionTitle extends StatelessWidget {
  const _FactoryMapSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _FactoryMapEmptyRow extends StatelessWidget {
  const _FactoryMapEmptyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _FactoryMapPlaceholder extends StatelessWidget {
  const _FactoryMapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF202426),
      child: Semantics(
        label: 'Zavod 3D kartasi tayyorlanmoqda',
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.factory_outlined, color: Colors.white70, size: 34),
              SizedBox(height: 12),
              Text(
                'Zavod kartasi tayyorlanmoqda…',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
