part of 'admin_production_map_orders_screen.dart';

class _OrderMapProgressCard extends StatelessWidget {
  const _OrderMapProgressCard({
    required this.workerMode,
    required this.steps,
    required this.apparatusCatalog,
    required this.orderId,
    required this.currentStation,
    required this.queueStates,
    required this.queueStatesByApparatus,
    required this.stageStates,
    required this.currentStageNodeId,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTapApparatus,
  });

  final bool workerMode;
  final List<ProductionMapNode> steps;
  final List<AdminApparatus> apparatusCatalog;
  final String orderId;
  final String currentStation;
  final Map<String, String> queueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, String> stageStates;
  final String currentStageNodeId;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<ProductionMapNode> onTapApparatus;

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
                      for (var index = 0;
                          index < steps.length;
                          index++) ...[
                        _SequenceStepTile(
                          node: steps[index],
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
                          current: productionMapNodeIsCurrentOccurrence(
                            node: steps[index],
                            currentStation: currentStation,
                            currentStageNodeId: currentStageNodeId,
                          ),
                          isDone: _orderMapStepIsDone(
                            steps: steps,
                            index: index,
                            orderId: orderId,
                            currentStation: currentStation,
                            queueStates: queueStates,
                            queueStatesByApparatus: queueStatesByApparatus,
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
                  Icon(
                    Icons.account_tree_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
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
  return productionMapNodeQueueState(
    node: node,
    orderId: orderId,
    currentStation: currentStation,
    currentQueueStates: queueStates,
    queueStatesByApparatus: queueStatesByApparatus,
    stageStates: stageStates,
  );
}

bool _orderMapNodeMatchesStation(ProductionMapNode node, String station) {
  return productionMapNodeMatchesStation(node: node, station: station);
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
  return assignedId.isEmpty ? node.apparatusId.trim() : assignedId;
}
