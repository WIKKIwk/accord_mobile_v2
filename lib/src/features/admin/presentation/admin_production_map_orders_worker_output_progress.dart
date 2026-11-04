part of 'admin_production_map_orders_screen.dart';

int? _workerOrderPlannedMeters(double? baseLength) {
  if (baseLength == null || !baseLength.isFinite || baseLength <= 0) {
    return null;
  }
  return (baseLength / 500).ceil() * 500;
}

Widget? _workerOrderOutputProgress({
  required ProductionMapDefinition map,
  required AdminApparatus? apparatus,
  required _ReadOnlyOrderDetailUiState uiState,
  required double? baseMetraj,
  required int outputRevision,
}) {
  if (!uiState.showPause && !uiState.showComplete && !uiState.showResume) {
    return null;
  }
  final operation = apparatus?.operation.trim().toLowerCase();
  final station = uiState.station.trim();
  if ((operation != 'print' && operation != 'laminate') ||
      station.isEmpty ||
      station != apparatus?.id.trim()) {
    return null;
  }
  var stageId = uiState.stageNodeId.trim();
  if (stageId.isEmpty) {
    final matches = productionMapLinearWorkStages(map)
        .where((stage) => stage.apparatusId == station);
    if (matches.length != 1) return null;
    stageId = matches.single.nodeId;
  }
  final producers = productionMapWipConsumerIds(
    map: map,
    nextApparatus: station,
    nextStageNodeId: stageId,
  );
  if (producers.isEmpty) return null;
  return _WorkerOrderOutputProgress(
    key: ValueKey((map.id, stageId, producers.join('|'))),
    map: map,
    stageId: stageId,
    producers: producers,
    titleKey: 'worker.output_progress.$operation',
    plannedMeters: _workerOrderPlannedMeters(baseMetraj ?? map.baseLength),
    outputRevision: outputRevision,
  );
}

class _WorkerOrderOutputProgress extends StatefulWidget {
  const _WorkerOrderOutputProgress({
    super.key,
    required this.map,
    required this.stageId,
    required this.producers,
    required this.titleKey,
    required this.plannedMeters,
    required this.outputRevision,
  });

  final ProductionMapDefinition map;
  final String stageId;
  final List<String> producers;
  final String titleKey;
  final int? plannedMeters;
  final int outputRevision;

  @override
  State<_WorkerOrderOutputProgress> createState() =>
      _WorkerOrderOutputProgressState();
}

class _WorkerOrderOutputProgressState
    extends State<_WorkerOrderOutputProgress> {
  late final String _readScope;
  Timer? _refreshTimer;
  ({double meters, int known, int missing})? _output;
  bool _failed = false;
  bool _loading = false;
  bool _refreshPending = false;

  @override
  void initState() {
    super.initState();
    _readScope = currentSessionReadScope();
    unawaited(_refresh());
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if ((lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          ModalRoute.of(context)?.isCurrent != false &&
          !_loading) {
        unawaited(_refresh());
      }
    });
  }

  @override
  void didUpdateWidget(covariant _WorkerOrderOutputProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.outputRevision != oldWidget.outputRevision) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get _current => mounted && _readScope == currentSessionReadScope();

  Future<void> _refresh() async {
    if (!_current) return;
    if (_loading) {
      _refreshPending = true;
      return;
    }
    _loading = true;
    try {
      final pages = await Future.wait([
        for (final producer in widget.producers)
          MobileApi.instance.adminWipBatches(
            status: 'all',
            orderId: widget.map.id,
            producerApparatus: producer,
            limit: 500,
          ),
      ]);
      if (!_current) return;
      final output = _workerStageOutputMeters(
        widget.map,
        widget.stageId,
        pages.expand((page) => page),
      );
      setState(() {
        _output = output;
        _failed = false;
      });
    } catch (_) {
      if (!_current) return;
      setState(() {
        _output = null;
        _failed = true;
      });
    } finally {
      _loading = false;
      if (_refreshPending) {
        _refreshPending = false;
        unawaited(_refresh());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final output = _output;
    final plan = widget.plannedMeters?.toDouble();
    final ratio = output != null && output.missing == 0 && plan != null
        ? output.meters / plan
        : null;
    String meters(double value) {
      if (value == value.roundToDouble()) {
        return MaterialLocalizations.of(context).formatDecimal(value.round());
      }
      return formatQuantity(value, trimTrailingZeros: true);
    }

    final measured = output == null || (output.known == 0 && output.missing > 0)
        ? '—'
        : meters(output.meters);
    return Column(
      key: const ValueKey('worker-order-output-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.productionText(widget.titleKey),
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (ratio != null)
              Text('${(output!.meters * 100 / plan!).floor()}%',
                  style: theme.textTheme.titleSmall),
          ],
        ),
        if (ratio != null) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0).toDouble(),
            minHeight: 5,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
        const SizedBox(height: 4),
        if (output == null)
          Text(
            _failed
                ? l10n.productionText('worker.output_progress.unavailable')
                : l10n.loading,
            style: theme.textTheme.bodySmall,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan == null ? '$measured m' : '$measured / ${meters(plan)} m',
                style: theme.textTheme.bodyMedium,
              ),
              if (output.missing > 0)
                Text(
                  l10n.productionText('worker.output_progress.missing',
                      values: {'count': output.missing}),
                  style: theme.textTheme.bodySmall,
                )
              else if (plan != null)
                Text(
                  l10n.productionText('worker.output_progress.remaining',
                      values: {
                        'value': meters(max(0.0, plan - output.meters))
                      }),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
      ],
    );
  }
}

({double meters, int known, int missing}) _workerStageOutputMeters(
  ProductionMapDefinition map,
  String stageId,
  Iterable<AdminProgressBatch> batches,
) {
  final latestBatches = <String, AdminProgressBatch>{};
  for (final batch in batches) {
    if (batch.orderId != map.id || batch.batchId.isEmpty) continue;
    final previous = latestBatches[batch.batchId];
    if (previous == null || batch.revision > previous.revision) {
      latestBatches[batch.batchId] = batch;
    }
  }
  final stageMatches = <(String, String), bool>{};
  var units = 0;
  var known = 0;
  var missing = 0;
  for (final batch in latestBatches.values) {
    if (batch.wipStatus == 'void' ||
        batch.wipStatus == 'peremotka' ||
        batch.payloadJson['origin'] == 'layer_remainder') {
      continue;
    }
    final isOutput = switch ((batch.action, batch.status)) {
      ('pause', 'paused' || 'resumed') ||
      ('detach_roll', 'roll_detached' || 'resumed') ||
      ('roll_complete' || 'complete', 'completed') =>
        true,
      _ => false,
    };
    if (!isOutput) continue;
    final producer = batch.apparatus.trim();
    final sourceStageId = batch.payloadJson['stage_node_id']?.toString() ?? '';
    final belongsToStage = stageMatches.putIfAbsent(
      (producer, sourceStageId),
      () => productionMapWipConsumerIds(
        map: map,
        nextApparatus: producer,
        nextStageNodeId: sourceStageId,
        consumerStageNodeId: stageId,
      ).contains(producer),
    );
    if (!belongsToStage) continue;
    final meterUnits = _workerWipMeterUnits(batch);
    if (meterUnits == null) {
      missing++;
    } else {
      units += meterUnits;
      known++;
    }
  }
  return (meters: units / 1000000, known: known, missing: missing);
}
