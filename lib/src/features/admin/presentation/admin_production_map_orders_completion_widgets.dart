part of 'admin_production_map_orders_screen.dart';

class _CompletionRequestsSection extends StatelessWidget {
  const _CompletionRequestsSection({
    required this.requests,
    required this.expandedRequestId,
    required this.onExpandedChanged,
  });

  final List<AdminCompletionRequestNotification> requests;
  final String? expandedRequestId;
  final void Function(AdminCompletionRequestNotification request, bool expanded)
      onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            requests.any((request) => !request.decisionRequired)
                ? 'Bildirishnomalar'
                : 'Tugatish so‘rovlari',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        M3SegmentSpacedColumn(
          padding: EdgeInsets.zero,
          children: [
            for (var index = 0; index < requests.length; index++)
              _CompletionRequestRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  requests.length,
                ),
                request: requests[index],
                expanded: expandedRequestId == requests[index].eventId.trim(),
                onExpandedChanged: (expanded) =>
                    onExpandedChanged(requests[index], expanded),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompletionRequestRow extends StatelessWidget {
  const _CompletionRequestRow({
    required this.slot,
    required this.request,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final M3SegmentVerticalSlot slot;
  final AdminCompletionRequestNotification request;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final code = _completionRequestDisplayCode(request);
    final worker = _closedActorLabel(
      displayName: request.workerDisplayName,
      role: request.workerRole,
      ref: request.workerRef,
    );
    final decisionRequired = request.decisionRequired;
    final title = decisionRequired
        ? '$code zakaz 0 holatda'
        : '$code laminatsiya qoldig‘i';
    final subtitle = decisionRequired
        ? '${request.apparatus} dagi $worker tugatishga urinyapti'
        : '${request.apparatus} dagi $worker ikkala qavat qoldig‘ini yozdi';

    return Material(
      color:
          (decisionRequired ? scheme.errorContainer : scheme.secondaryContainer)
              .withValues(alpha: 0.32),
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          decisionRequired
                              ? Icons.priority_high_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: decisionRequired
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.15,
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
                        size: 22,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _CompletionRequestDetail(request: request)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CompletionRequestDetail extends StatelessWidget {
  const _CompletionRequestDetail({required this.request});

  final AdminCompletionRequestNotification request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = <String>[
      if (request.orderTitle.trim().isNotEmpty)
        'Mahsulot: ${request.orderTitle.trim()}',
      if (request.productCode.trim().isNotEmpty)
        'Kod: ${request.productCode.trim()}',
      '${_apparatusDetailLabel(request.apparatus)}: ${request.apparatus.trim()}',
      'Ishchi: ${_closedActorLabel(
        displayName: request.workerDisplayName,
        role: request.workerRole,
        ref: request.workerRef,
      )}',
      if (_closedLogTimeLabel(request.createdAtUnix).isNotEmpty)
        'Vaqt: ${_closedLogTimeLabel(request.createdAtUnix)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 58, right: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            request.description.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
