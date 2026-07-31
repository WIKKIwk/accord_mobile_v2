part of 'admin_production_map_orders_screen.dart';

class _SequenceRawMaterialAssignmentSheet extends StatefulWidget {
  const _SequenceRawMaterialAssignmentSheet({required this.order});

  final ProductionMapSaved order;

  @override
  State<_SequenceRawMaterialAssignmentSheet> createState() =>
      _SequenceRawMaterialAssignmentSheetState();
}

class _SequenceRawMaterialAssignmentSheetState
    extends State<_SequenceRawMaterialAssignmentSheet> {
  List<AdminRawMaterialAssignmentCandidate> _candidates = const [];
  List<AdminRawMaterialAssignment> _assignments = const [];
  String _loadError = '';
  String _actionMessage = '';
  String _assigningBarcode = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool showLoading = true}) async {
    final orderId = widget.order.map.id.trim();
    if (orderId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Order identifikatori topilmadi';
        });
      }
      return;
    }
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = '';
      });
    }
    try {
      final result = await Future.wait<Object>([
        MobileApi.instance.adminRawMaterialAssignmentCandidates(
          orderId: orderId,
        ),
        MobileApi.instance.adminRawMaterialAssignments(orderId: orderId),
      ]);
      if (!mounted || widget.order.map.id.trim() != orderId) {
        return;
      }
      setState(() {
        _candidates = result[0] as List<AdminRawMaterialAssignmentCandidate>;
        _assignments = result[1] as List<AdminRawMaterialAssignment>;
        _loading = false;
        _loadError = '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error is MobileApiException
            ? error.message
            : 'Mos homashyolar yuklanmadi';
      });
    }
  }

  Future<void> _assign(AdminRawMaterialAssignmentCandidate candidate) async {
    if (_assigningBarcode.isNotEmpty) {
      return;
    }
    final options = candidate.apparatusOptions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (options.isEmpty) {
      setState(() => _actionMessage = 'Bu homashyo uchun aparat topilmadi');
      return;
    }
    final apparatus =
        options.length == 1 ? options.single : await _pickApparatus(options);
    if (!mounted || apparatus == null || apparatus.trim().isEmpty) {
      return;
    }
    final barcode = candidate.barcode.trim();
    setState(() {
      _assigningBarcode = barcode.toUpperCase();
      _actionMessage = '';
    });
    try {
      final saved = await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: widget.order.map.id.trim(),
        barcode: barcode,
        apparatus: apparatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = [
          for (final item in _candidates)
            if (item.barcode.trim().toUpperCase() != barcode.toUpperCase())
              item,
        ];
        _assignments = [
          saved,
          for (final item in _assignments)
            if (item.barcode.trim().toUpperCase() != barcode.toUpperCase())
              item,
        ];
        _actionMessage = 'Homashyo orderga ulandi';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actionMessage =
            error is MobileApiException ? error.message : 'Homashyo ulanmagan';
      });
      await _load(showLoading: false);
    } finally {
      if (mounted) {
        setState(() => _assigningBarcode = '');
      }
    }
  }

  Future<String?> _pickApparatus(List<String> options) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Qaysi aparatga ulaymiz?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bu homashyo bir nechta bosqichga mos keladi.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final option in options)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.precision_manufacturing_outlined),
                    title: Text(option),
                    onTap: () => Navigator.of(sheetContext).pop(option),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SequenceAssignmentSheetHeader(
              order: widget.order,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (_actionMessage.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _actionMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _actionMessage == 'Homashyo orderga ulandi'
                          ? scheme.primary
                          : scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 156,
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (_loadError.trim().isNotEmpty) {
      return _SequenceAssignmentMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Mos homashyolar yuklanmadi',
        message: _loadError,
        action: TextButton(
          onPressed: () => _load(),
          child: const Text('Qayta urinish'),
        ),
      );
    }

    final children = <Widget>[];
    if (_candidates.isNotEmpty) {
      children.add(
        _SequenceAssignmentIntro(
          candidateCount: _candidates.length,
          assignedCount: _assignments.length,
        ),
      );
      children.add(const SizedBox(height: 10));
      for (var index = 0; index < _candidates.length; index++) {
        if (index > 0) {
          children.add(const SizedBox(height: 10));
        }
        final candidate = _candidates[index];
        children.add(
          _SequenceCandidateCard(
            candidate: candidate,
            rank: index + 1,
            busy: _assigningBarcode == candidate.barcode.trim().toUpperCase(),
            onAssign: () => _assign(candidate),
          ),
        );
      }
    } else {
      children.add(
        _SequenceAssignmentMessage(
          title: _assignments.isEmpty
              ? 'Mos homashyo topilmadi'
              : 'Barcha mos homashyolar ulangan',
          message: _assignments.isEmpty
              ? 'Bu order uchun sizga ajratilgan omborda mos homashyo yo‘q.'
              : 'Yangi mos variant chiqsa, Yangilash tugmasini bosing.',
          action: TextButton(
            onPressed: _loading ? null : () => _load(),
            child: const Text('Yangilash'),
          ),
          centered: _assignments.isEmpty,
        ),
      );
    }

    if (_assignments.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 18),
        Text(
          'Ulangan homashyolar',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _assignments.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _SequenceAssignedMaterialRow(assignment: _assignments[index]),
        ],
      ]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SequenceAssignmentSheetHeader extends StatelessWidget {
  const _SequenceAssignmentSheetHeader({
    required this.order,
    required this.onClose,
  });

  final ProductionMapSaved order;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = order.map;
    final customer = map.customerName.trim();
    final subtitle = [
      _sequenceOrderLabel(order),
      if (customer.isNotEmpty) customer,
    ].join(' • ');
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      leading: const Icon(Icons.inventory_2_outlined),
      title: Text(
        'Orderga homashyo ulash',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Yopish',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _SequenceAssignmentIntro extends StatelessWidget {
  const _SequenceAssignmentIntro({
    required this.candidateCount,
    required this.assignedCount,
  });

  final int candidateCount;
  final int assignedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.sort_rounded, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$candidateCount ta mos homashyo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Aniq moslik va eng kam astatka yuqoridan boshlab ko‘rsatilgan.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  if (assignedCount > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      '$assignedCount ta homashyo allaqachon ulangan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SequenceCandidateCard extends StatelessWidget {
  const _SequenceCandidateCard({
    required this.candidate,
    required this.rank,
    required this.busy,
    required this.onAssign,
  });

  final AdminRawMaterialAssignmentCandidate candidate;
  final int rank;
  final bool busy;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final exact = candidate.matchType.trim() == 'exact_width';
    final title = candidate.itemName.trim().isEmpty
        ? candidate.itemCode.trim()
        : candidate.itemName.trim();
    final subtitle = [
      if (candidate.itemCode.trim().isNotEmpty &&
          candidate.itemCode.trim() != title)
        candidate.itemCode.trim(),
      if (candidate.barcode.trim().isNotEmpty) 'QR ${candidate.barcode.trim()}',
      if (candidate.warehouse.trim().isNotEmpty) candidate.warehouse.trim(),
      if (candidate.qty > 0)
        formatQuantityWithUnit(
          candidate.qty,
          candidate.uom,
          decimalPlaces: 3,
          trimTrailingZeros: true,
        ),
    ].join(' • ');
    final widthDetails = <String>[
      if (candidate.orderWidthMm != null)
        'Order ${_sequenceMillimeters(candidate.orderWidthMm!)}',
      if (candidate.rollWidthMm != null)
        'Rulon ${_sequenceMillimeters(candidate.rollWidthMm!)}',
      if (candidate.leftoverWidthMm != null)
        'Astatka ${_sequenceMillimeters(candidate.leftoverWidthMm!)}',
    ];
    final matchLabel = switch (candidate.matchType.trim()) {
      'exact_width' => 'Aniq mos',
      'closest_width' => 'Eng yaqin',
      _ => 'Mos variant',
    };

    return Card(
      margin: EdgeInsets.zero,
      color: exact
          ? scheme.primaryContainer.withValues(alpha: 0.62)
          : scheme.surfaceContainerLow,
      elevation: exact ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: exact
              ? scheme.primary.withValues(alpha: 0.45)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onAssign,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: exact ? scheme.primary : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#$rank',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: exact
                            ? scheme.onPrimary
                            : scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Nomsiz homashyo' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: exact
                          ? scheme.primary.withValues(alpha: 0.15)
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        matchLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color:
                              exact ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (widthDetails.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final detail in widthDetails)
                      Chip(
                        label: Text(detail),
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: exact
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: exact
                            ? scheme.primaryContainer.withValues(alpha: 0.72)
                            : scheme.surfaceContainerHighest,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                  ],
                ),
              ],
              if (candidate.itemGroup.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Guruh: ${candidate.itemGroup.trim()} • Aparat: ${candidate.apparatusOptions.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: busy ? null : onAssign,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(busy ? 'Ulanmoqda...' : 'Orderga ulash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SequenceAssignedMaterialRow extends StatelessWidget {
  const _SequenceAssignedMaterialRow({required this.assignment});

  final AdminRawMaterialAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode.trim()
        : assignment.itemName.trim();
    final subtitle = [
      if (assignment.barcode.trim().isNotEmpty) assignment.barcode.trim(),
      if (assignment.apparatus.trim().isNotEmpty) assignment.apparatus.trim(),
      if (assignment.stockWarehouse.trim().isNotEmpty)
        assignment.stockWarehouse.trim(),
    ].join(' • ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        leading:
            Icon(Icons.check_circle_outline_rounded, color: scheme.primary),
        title: Text(title.isEmpty ? 'Ulangan homashyo' : title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
      ),
    );
  }
}

class _SequenceAssignmentMessage extends StatelessWidget {
  const _SequenceAssignmentMessage({
    required this.message,
    this.title,
    this.action,
    this.icon,
    this.centered = false,
  });

  final String message;
  final String? title;
  final Widget? action;
  final IconData? icon;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (centered) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null && title!.trim().isNotEmpty)
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: 12),
                  action!,
                ],
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Card.filled(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 28, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null && title!.trim().isNotEmpty)
                          Text(
                            title!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: action!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _sequenceMillimeters(double value) {
  return '${formatQuantity(value, decimalPlaces: 1, trimTrailingZeros: true)} mm';
}

String _sequenceOrderLabel(ProductionMapSaved order) {
  final map = order.map;
  final code = map.code.trim().isNotEmpty
      ? map.code.trim()
      : map.orderNumber.trim().isNotEmpty
          ? map.orderNumber.trim()
          : map.id.trim();
  final title = map.title.trim().isNotEmpty ? map.title.trim() : 'Zakaz';
  return '$code · $title';
}
