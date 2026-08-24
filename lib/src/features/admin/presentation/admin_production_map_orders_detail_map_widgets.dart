part of 'admin_production_map_orders_screen.dart';

class _OrderMapProgressCard extends StatelessWidget {
  const _OrderMapProgressCard({
    required this.steps,
    required this.apparatusCatalog,
    required this.orderId,
    required this.currentStation,
    required this.queueStates,
    required this.queueStatesByApparatus,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onTapApparatus,
  });

  final List<ProductionMapNode> steps;
  final List<AdminApparatus> apparatusCatalog;
  final String orderId;
  final String currentStation;
  final Map<String, String> queueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<ProductionMapNode> onTapApparatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
          AnimatedSize(
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
                                  queueStatesByApparatus:
                                      queueStatesByApparatus,
                                ),
                                current: _orderMapNodeMatchesStation(
                                  steps[index],
                                  currentStation,
                                ),
                                isDone: _orderMapStepIsDone(
                                  steps: steps,
                                  index: index,
                                  orderId: orderId,
                                  currentStation: currentStation,
                                  queueStates: queueStates,
                                  queueStatesByApparatus:
                                      queueStatesByApparatus,
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
          ),
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
}) {
  if (node.kind != 'apparatus') {
    return null;
  }
  final stationId = _orderMapNodeStationId(node);
  if (stationId.isEmpty) {
    return null;
  }
  if (_orderMapNodeMatchesStation(node, currentStation)) {
    return apparatusQueueOrderStateFromRaw(queueStates[orderId]);
  }
  return apparatusQueueOrderStateFromRaw(
    queueStatesByApparatus[stationId]?[orderId],
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
