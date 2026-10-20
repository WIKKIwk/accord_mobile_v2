part of 'admin_production_map_orders_screen.dart';

class _ClosedOrdersModulePage extends StatelessWidget {
  const _ClosedOrdersModulePage({
    this.loadDetail,
    required this.bottomPadding,
    required this.closedOrders,
    required this.apparatusCatalog,
    required this.visibleClosedOrders,
  });
  final double bottomPadding;
  final Future<AdminClosedProductionOrder> Function(String)? loadDetail;
  final List<AdminClosedProductionOrder> closedOrders;
  final List<AdminApparatus> apparatusCatalog;
  final List<AdminClosedProductionOrder> visibleClosedOrders;

  @override
  Widget build(BuildContext context) {
    if (visibleClosedOrders.isEmpty) {
      return ListView(children: [_EmptyOpenedOrders(message: context.l10n.adminText(
          closedOrders.isEmpty ? 'production.closed_empty' : 'production.search_empty'))]);
    }
    return ListView.builder(
      key: const PageStorageKey('admin-closed-orders'),
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        bottomPadding,
      ),
      itemCount: visibleClosedOrders.length,
      findChildIndexCallback: (key) {
        final index = visibleClosedOrders.indexWhere(
            (order) => key == ValueKey('closed-order-${order.orderId}'));
        return index < 0 ? null : index;
      },
      itemBuilder: (context, index) => Padding(
        key: ValueKey('closed-order-${visibleClosedOrders[index].orderId}'),
        padding: const EdgeInsets.only(bottom: 4),
        child: _ClosedOrderTile(
                  key: PageStorageKey(visibleClosedOrders[index].orderId),
                  loadDetail: loadDetail,
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    visibleClosedOrders.length,
                  ),
                  order: visibleClosedOrders[index],
                  apparatusCatalog: apparatusCatalog,
                  index: index,
                )),
    );
  }
}

class _ClosedOrderTile extends StatefulWidget {
  const _ClosedOrderTile({
    super.key,
    this.loadDetail,
    required this.slot,
    required this.order,
    required this.apparatusCatalog,
    required this.index,
  });
  final M3SegmentVerticalSlot slot;
  final AdminClosedProductionOrder order;
  final List<AdminApparatus> apparatusCatalog;
  final int index;
  final Future<AdminClosedProductionOrder> Function(String)? loadDetail;

  @override
  State<_ClosedOrderTile> createState() => _ClosedOrderTileState();
}

class _ClosedOrderTileState extends State<_ClosedOrderTile>
    with AutomaticKeepAliveClientMixin {
  AdminClosedProductionOrder? _detail;
  bool _loading = false;
  String? _error;
  bool _expanded = false;
  bool _restored = false;
  @override
  bool get wantKeepAlive => _expanded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_restored) return;
    _restored = true;
    _expanded = PageStorage.maybeOf(context)?.readState(context) == true;
    if (_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadDetail());
      });
    }
  }

  @override
  void didUpdateWidget(covariant _ClosedOrderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.historyVersion != widget.order.historyVersion) {
      _detail = null;
      if (_expanded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_loadDetail());
        });
      }
    }
  }
  AdminClosedProductionOrder get order => _detail ?? widget.order;
  M3SegmentVerticalSlot get slot => widget.slot;
  List<AdminApparatus> get apparatusCatalog => widget.apparatusCatalog;
  int get index => widget.index;

  Future<void> _loadDetail() async {
    if (_loading || _detail != null || widget.loadDetail == null) return;
    final historyVersion = widget.order.historyVersion;
    final orderId = widget.order.orderId;
    bool current() => mounted && widget.order.orderId == orderId &&
        widget.order.historyVersion == historyVersion;
    setState(() { _loading = true; _error = null; });
    try {
      final detail = await widget.loadDetail!(orderId);
      if (current()) setState(() => _detail = detail);
    } catch (error) {
      if (current()) {
        setState(() => _error = error is MobileApiException
            ? error.message : 'Tarix yuklanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (!current() && _expanded) unawaited(_loadDetail());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _closedOrderDisplayCode(order);
    final title = _closedOrderTitle(order);
    final closedBy = _closedActorLabel(
      displayName: order.closedByDisplayName,
      role: order.closedByRole,
      ref: order.closedByRef,
    );
    final closedAt = _closedLogTimeLabel(order.completedAtUnix);
    final subtitle = [
      if (order.logs.any((log) => log.action == 'close_early')) 'Erta yopilgan',
      if (order.productCode.trim().isNotEmpty) order.productCode.trim(),
      if (closedBy.isNotEmpty) 'Yopdi: $closedBy',
      if (closedAt.isNotEmpty) closedAt,
    ].join(' • ');
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            _expanded = expanded;
            updateKeepAlive();
            if (expanded) unawaited(_loadDetail());
          },
          tilePadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: _OpenedOrderIndexBadge(index: index),
          title: Text(
            code.isEmpty ? title : '$code • $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.15,
                  ),
                ),
          children: [
            if (_loading) const LinearProgressIndicator()
            else if (_error != null)
              TextButton(onPressed: _loadDetail, child: Text('$_error · Qayta yuklash'))
            else if (order.logs.isEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: UrduAwareText(
                  'Log yo‘q',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              _ClosedOrderLogList(
                order: order,
                logs: order.logs,
                apparatusCatalog: apparatusCatalog,
              ),
          ],
        ),
      ),
    );
  }
}

class _ClosedOrderLogList extends StatelessWidget {
  const _ClosedOrderLogList({
    required this.order,
    required this.logs,
    required this.apparatusCatalog,
  });
  final AdminClosedProductionOrder order;
  final List<AdminProductionOrderLogEntry> logs;
  final List<AdminApparatus> apparatusCatalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < logs.length; index++) ...[
          if (index > 0) const Divider(height: 16),
          _ClosedOrderLogRow(
            order: order,
            log: logs[index],
            apparatusCatalog: apparatusCatalog,
          ),
        ],
      ],
    );
  }
}

class _ClosedOrderLogRow extends StatelessWidget {
  const _ClosedOrderLogRow({
    required this.order,
    required this.log,
    required this.apparatusCatalog,
  });
  final AdminClosedProductionOrder order;
  final AdminProductionOrderLogEntry log;
  final List<AdminApparatus> apparatusCatalog;

  IconData get _icon {
    if (log.freeze != null) {
      return Icons.lock_clock_rounded;
    }
    if (log.transfer != null) {
      return Icons.swap_horiz_rounded;
    }
    return switch (log.action.trim()) {
      'start' => Icons.play_arrow_rounded,
      'pause' => Icons.pause_rounded,
      'detach_roll' => Icons.unarchive_rounded,
      'merge' => Icons.link_rounded,
      'resume' => Icons.replay_rounded,
      'roll_complete' => Icons.done_all_rounded,
      'complete' => Icons.check_rounded,
      'close_early' => Icons.stop_circle_outlined,
      _ => Icons.history_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = _closedActorLabel(
      displayName: log.actorDisplayName,
      role: log.actorRole,
      ref: log.actorRef,
    );
    final state = _closedLogStateLabel(log);
    final time = _closedLogTimeLabel(log.createdAtUnix);
    final apparatus = _closedLogApparatusLabel(log, apparatusCatalog);
    final transferReason = log.transfer?.reason.trim() ?? '';
    final subtitle = [
      actor,
      if (state.isNotEmpty) state,
      if (time.isNotEmpty) time,
      if (transferReason.isNotEmpty) 'Sabab: $transferReason',
      if (log.action == 'close_early' && log.issueNote.trim().isNotEmpty)
        'Sabab: ${log.issueNote.trim()}',
    ].join(' • ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showClosedOrderLogDetails(
          context,
          order: order,
          log: log,
          apparatusCatalog: apparatusCatalog,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _icon,
                    size: 18,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        _closedLogTitle(log),
                        if (apparatus.isNotEmpty) apparatus,
                      ].join(' • '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
