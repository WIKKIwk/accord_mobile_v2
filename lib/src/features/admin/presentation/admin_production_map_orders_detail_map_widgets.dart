part of 'admin_production_map_orders_screen.dart';

class _OrderMapProgressCard extends StatefulWidget {
  const _OrderMapProgressCard({
    required this.order,
    required this.map,
    required this.orderControlState,
    required this.workerMode,
    required this.steps,
    required this.apparatusCatalog,
    required this.orderId,
    required this.currentStation,
    required this.queueStates,
    required this.queueStatesByApparatus,
    required this.queueActionControlsByApparatus,
    required this.stageStates,
    required this.currentStageNodeId,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTapApparatus,
  });
  final bool workerMode;
  final ProductionMapSaved order;
  final ProductionMapDefinition map;
  final AdminOrderControlState orderControlState;
  final List<ProductionMapNode> steps;
  final List<AdminApparatus> apparatusCatalog;
  final String orderId;
  final String currentStation;
  final Map<String, String> queueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      queueActionControlsByApparatus;
  final Map<String, String> stageStates;
  final String currentStageNodeId;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<ProductionMapNode> onTapApparatus;

  @override
  State<_OrderMapProgressCard> createState() => _OrderMapProgressCardState();
}

class _OrderMapProgressCardState extends State<_OrderMapProgressCard> {
  AdminApparatusQueueSnapshot? _snapshot;
  Map<String, ProductionMapStageWipFacts> _facts = const {};
  bool _loading = false;
  bool _loadError = false;
  int _generation = 0;
  Timer? _poll;

  ProductionMapDefinition get map => widget.map;
  String get orderId => widget.orderId;
  String get currentStation => widget.currentStation;
  String get currentStageNodeId => widget.currentStageNodeId;
  List<ProductionMapNode> get steps => [
        for (final node in widget.steps)
          productionMapLiveStageNode(
            map: map,
            node: node,
            orderId: orderId,
            queueStates: queueStatesByApparatus,
            stageStates: _rawStageStates,
            controls: queueActionControlsByApparatus,
          ),
      ];
  List<AdminApparatus> get apparatusCatalog => widget.apparatusCatalog;
  bool get expanded => widget.expanded;
  bool get workerMode => widget.workerMode;
  VoidCallback get onToggleExpanded => widget.onToggleExpanded;
  ValueChanged<ProductionMapNode> get onTapApparatus => widget.onTapApparatus;
  Map<String, Map<String, String>> get queueStatesByApparatus =>
      _snapshot?.queueStates ?? widget.queueStatesByApparatus;
  Map<String, String> get queueStates => _snapshot == null
      ? widget.queueStates
      : _snapshot!.queueStates[currentStation] ?? const {};
  Map<String, String> get _rawStageStates => _snapshot == null
      ? widget.stageStates
      : _snapshot!.stageStates[orderId] ?? const {};
  Map<String, String> get stageStates => {
        ..._rawStageStates,
        for (final node in map.nodes.where((node) => node.kind == 'apparatus'))
          node.id: switch (productionMapStageQueueState(
            map: map,
            node: node,
            orderId: orderId,
            queueStates: {
              ...queueStatesByApparatus,
              if (currentStation.isNotEmpty) currentStation: queueStates,
            },
            stageStates: _rawStageStates,
            controls: queueActionControlsByApparatus,
          )) {
            ApparatusQueueOrderState.inProgress => 'in_progress',
            ApparatusQueueOrderState.printPreflight => 'print_preflight',
            final state? => state.name,
            null => 'unknown',
          },
      };
  Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      get queueActionControlsByApparatus =>
          _snapshot?.queueActionControls ??
          widget.queueActionControlsByApparatus;
  AdminOrderControlState get orderControlState =>
      _snapshot?.orderControlFor(orderId) ?? widget.orderControlState;

  @override
  void initState() {
    super.initState();
    if (expanded) _startRefresh();
  }

  @override
  void didUpdateWidget(covariant _OrderMapProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != orderId || oldWidget.expanded != expanded) {
      _poll?.cancel();
      _generation++;
      _loading = false;
      if (oldWidget.orderId != orderId) {
        _snapshot = null;
        _facts = const {};
      }
      if (expanded) _startRefresh();
    }
  }

  void _startRefresh() {
    unawaited(_load());
    _poll =
        Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_load()));
  }

  Future<void> _load() async {
    if (_loading || !expanded) return;
    final generation = ++_generation;
    final requestedOrder = widget.order;
    final training = orderId.startsWith('training-');
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminProductionMapQueueSnapshot(),
        training
            ? Future.value(const <AdminProgressBatch>[])
            : MobileApi.instance
                .adminWipBatches(status: 'all', orderId: orderId, limit: 1000),
        training
            ? Future.value(const <AdminOpeningWipRecord>[])
            : MobileApi.instance.adminOpeningWipRecords(
                status: 'all', orderId: orderId, limit: 500),
      ]).timeout(const Duration(seconds: 12));
      if (!mounted || generation != _generation) return;
      final batches = _mergeWorkerWipBatches(
        results[1] as List<AdminProgressBatch>,
        _openingWipBatchesProducedByApparatus(
            results[2] as List<AdminOpeningWipRecord>,
            order: requestedOrder),
      );
      setState(() {
        _snapshot = results[0] as AdminApparatusQueueSnapshot;
        _facts = {
          for (final node
              in map.nodes.where((node) => node.kind == 'apparatus'))
            node.id: productionMapStageWipFacts(
                map: map, node: node, batches: batches),
        };
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _generation++;
    super.dispose();
  }

  FactoryMapStatus _displayStatus(ProductionMapNode node) =>
      productionMapStageDisplayStatus(
        map: map,
        node: node,
        queueState: _orderMapNodeStatus(node,
            orderId: orderId,
            currentStation: currentStation,
            queueStates: queueStates,
            queueStatesByApparatus: queueStatesByApparatus,
            stageStates: stageStates),
        control: queueActionControlsByApparatus[_orderMapNodeStationId(node)]
            ?[orderId],
        orderControl: orderControlState,
        wip: _facts[node.id] ?? const ProductionMapStageWipFacts(),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mapContent = AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      if (_loading && _snapshot == null)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: LinearProgressIndicator())
                      else if (_loadError)
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(children: [
                              Text(context.l10n
                                  .adminText('factory_map.wip.load_error')),
                              TextButton(
                                  onPressed: () => unawaited(_load()),
                                  child: Text(context.l10n
                                      .productionText('worker.action.retry'))),
                            ]))
                      else ...[
                        if (_loading) const LinearProgressIndicator(),
                        for (var index = 0; index < steps.length; index++) ...[
                          _SequenceStepTile(
                            node: steps[index],
                            wipFacts: _facts[steps[index].id],
                            displayStatus: steps[index].kind == 'apparatus'
                                ? _displayStatus(steps[index])
                                : null,
                            printPreflightPassed: _orderPrintPreflightPassed(
                              orderId: orderId,
                              apparatusId: steps[index].apparatusId,
                              stageNodeId: steps[index].id,
                              queueStates: {
                                ...queueStatesByApparatus,
                                if (currentStation.isNotEmpty)
                                  currentStation: queueStates,
                              },
                              controls: queueActionControlsByApparatus,
                            ),
                            operation: _canonicalNodeOperation(
                              steps[index],
                              apparatusCatalog,
                            ),
                            index: index,
                            isLast: index == steps.length - 1,
                            status: _orderMapNodeStatus(
                              steps[index],
                              orderId: orderId,
                              currentStation: currentStation,
                              queueStates: queueStates,
                              queueStatesByApparatus: queueStatesByApparatus,
                              stageStates: stageStates,
                            ),
                            current: _displayStatus(steps[index]) ==
                                    FactoryMapStatus.inProgress ||
                                productionMapNodeIsCurrentOccurrence(
                                  node: steps[index],
                                  currentStation: currentStation,
                                  currentStageNodeId: currentStageNodeId,
                                ),
                            isDone: steps[index].kind == 'apparatus'
                                ? _displayStatus(steps[index]) ==
                                    FactoryMapStatus.completed
                                : _orderMapStepIsDone(
                                    steps: steps,
                                    index: index,
                                    orderId: orderId,
                                    currentStation: currentStation,
                                    queueStates: queueStates,
                                    queueStatesByApparatus:
                                        queueStatesByApparatus,
                                    stageStates: stageStates,
                                  ),
                            onTap: steps[index].kind == 'apparatus' &&
                                    _orderMapNodeStationId(steps[index])
                                        .isNotEmpty
                                ? () => onTapApparatus(steps[index])
                                : null,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
    if (workerMode) {
      return mapContent;
    }
    return _orderDetailSurfaceCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.productionText('worker.action.view_map'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _orderMapProgressSummary(
                            l10n: context.l10n,
                            steps: steps,
                            orderId: orderId,
                            currentStation: currentStation,
                            queueStates: queueStates,
                            queueStatesByApparatus: queueStatesByApparatus,
                            stageStates: stageStates,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
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
          mapContent,
        ],
      ),
    );
  }
}

ApparatusQueueOrderState? _orderMapNodeStatus(
  ProductionMapNode node, {
  required String orderId,
  required String currentStation,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, String> stageStates,
}) {
  final station = _orderMapNodeStationId(node);
  final raw = stageStates[node.id.trim()] ??
      (station == currentStation
          ? queueStates[orderId.trim()]
          : queueStatesByApparatus[station]?[orderId.trim()]);
  if (raw == null ||
      !const {
        'pending',
        'in_progress',
        'print_preflight',
        'paused',
        'frozen',
        'completed'
      }.contains(raw.trim().toLowerCase())) return null;
  return productionMapNodeQueueState(
    node: node,
    orderId: orderId,
    currentStation: currentStation,
    currentQueueStates: queueStates,
    queueStatesByApparatus: queueStatesByApparatus,
    stageStates: stageStates,
  );
}

bool _orderMapStepIsIntro({
  required List<ProductionMapNode> steps,
  required int index,
}) {
  if (index < 0 || index >= steps.length) {
    return false;
  }
  final firstApparatusIndex =
      steps.indexWhere((node) => node.kind == 'apparatus');
  return firstApparatusIndex > 0 && index < firstApparatusIndex;
}

bool _orderMapStepIsDone({
  required List<ProductionMapNode> steps,
  required int index,
  required String orderId,
  required String currentStation,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, String> stageStates,
}) {
  if (_orderMapStepIsIntro(
    steps: steps,
    index: index,
  )) {
    return true;
  }
  final status = _orderMapNodeStatus(
    steps[index],
    orderId: orderId,
    currentStation: currentStation,
    queueStates: queueStates,
    queueStatesByApparatus: queueStatesByApparatus,
    stageStates: stageStates,
  );
  return status == ApparatusQueueOrderState.completed;
}

String _orderMapProgressSummary({
  required AppLocalizations l10n,
  required List<ProductionMapNode> steps,
  required String orderId,
  required String currentStation,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required Map<String, String> stageStates,
}) {
  var completed = 0;
  for (var index = 0; index < steps.length; index++) {
    if (_orderMapStepIsDone(
      steps: steps,
      index: index,
      orderId: orderId,
      currentStation: currentStation,
      queueStates: queueStates,
      queueStatesByApparatus: queueStatesByApparatus,
      stageStates: stageStates,
    )) {
      completed++;
    }
  }
  return l10n.productionText(
    'worker.map.progress',
    values: {'completed': completed, 'total': steps.length},
  );
}

String _orderMapNodeStationId(ProductionMapNode node) {
  final assignedId = node.alternativeAssignedApparatusId.trim();
  return node.alternativeGroupId.trim().isNotEmpty || assignedId.isEmpty
      ? node.apparatusId.trim()
      : assignedId;
}
