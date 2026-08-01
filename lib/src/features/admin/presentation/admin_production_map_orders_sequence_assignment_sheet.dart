part of 'admin_production_map_orders_screen.dart';

class _SequenceRawMaterialAssignmentSheet extends StatefulWidget {
  const _SequenceRawMaterialAssignmentSheet({
    required this.order,
    required this.initialApparatus,
    required this.assignedApparatus,
  });

  final ProductionMapSaved order;
  final String initialApparatus;
  final List<String> assignedApparatus;

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
  final Set<String> _selectedCandidateBarcodes = <String>{};
  late final List<String> _apparatusOptions;
  String _selectedApparatus = '';
  bool _apparatusFilterExpanded = false;
  bool _bulkAssigning = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _apparatusOptions = _sequenceAuthorizedOrderApparatus(
      order: widget.order,
      assignedApparatus: widget.assignedApparatus,
    );
    _selectedApparatus = _apparatusOptions.firstWhere(
      (apparatus) => productionMapStationTitlesMatch(
        apparatus,
        widget.initialApparatus,
      ),
      orElse: () => _apparatusOptions.isEmpty ? '' : _apparatusOptions.first,
    );
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
    final apparatus = _selectedApparatus.trim();
    if (apparatus.isEmpty) {
      if (mounted) {
        setState(() {
          _candidates = const [];
          _assignments = const [];
          _loading = false;
          _loadError = '';
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
          apparatus: apparatus,
        ),
        MobileApi.instance.adminRawMaterialAssignments(
          orderId: orderId,
          apparatus: apparatus,
        ),
      ]);
      if (!mounted ||
          widget.order.map.id.trim() != orderId ||
          !productionMapStationTitlesMatch(_selectedApparatus, apparatus)) {
        return;
      }
      final candidates = result[0] as List<AdminRawMaterialAssignmentCandidate>;
      setState(() {
        _candidates = candidates;
        _assignments = result[1] as List<AdminRawMaterialAssignment>;
        final availableKeys = candidates.map(_candidateKey).toSet();
        _selectedCandidateBarcodes
            .removeWhere((key) => !availableKeys.contains(key));
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
    if (_assigningBarcode.isNotEmpty ||
        _bulkAssigning ||
        _selectedCandidateBarcodes.isNotEmpty) {
      return;
    }
    final apparatus = _selectedApparatus.trim();
    if (apparatus.isEmpty ||
        !_candidateApparatusOptions(candidate).any(
          (option) => productionMapStationTitlesMatch(option, apparatus),
        )) {
      setState(() => _actionMessage = 'Bu homashyo uchun aparat topilmadi');
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

  List<String> _candidateApparatusOptions(
    AdminRawMaterialAssignmentCandidate candidate,
  ) {
    return candidate.apparatusOptions
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _candidateKey(AdminRawMaterialAssignmentCandidate candidate) {
    return _barcodeKey(candidate.barcode);
  }

  String _barcodeKey(String barcode) {
    return barcode.trim().toUpperCase();
  }

  void _toggleCandidateSelection(
    AdminRawMaterialAssignmentCandidate candidate,
  ) {
    if (_bulkAssigning || _assigningBarcode.isNotEmpty) {
      return;
    }
    final key = _candidateKey(candidate);
    if (key.isEmpty) {
      return;
    }
    setState(() {
      if (_selectedCandidateBarcodes.contains(key)) {
        _selectedCandidateBarcodes.remove(key);
      } else {
        _selectedCandidateBarcodes.add(key);
      }
      _actionMessage = '';
    });
  }

  void _clearCandidateSelection() {
    if (_bulkAssigning) {
      return;
    }
    setState(() {
      _selectedCandidateBarcodes.clear();
      _actionMessage = '';
    });
  }

  void _selectApparatus(String apparatus) {
    if (_bulkAssigning || _assigningBarcode.isNotEmpty) {
      return;
    }
    final normalized = apparatus.trim();
    if (normalized.isEmpty ||
        productionMapStationTitlesMatch(normalized, _selectedApparatus)) {
      setState(() => _apparatusFilterExpanded = false);
      return;
    }
    setState(() {
      _selectedApparatus = normalized;
      _apparatusFilterExpanded = false;
      _selectedCandidateBarcodes.clear();
      _candidates = const [];
      _assignments = const [];
      _actionMessage = '';
    });
    unawaited(_load());
  }

  Future<void> _assignSelected() async {
    if (_bulkAssigning ||
        _assigningBarcode.isNotEmpty ||
        _selectedCandidateBarcodes.isEmpty) {
      return;
    }
    final selected = _candidates
        .where(
          (candidate) =>
              _selectedCandidateBarcodes.contains(_candidateKey(candidate)),
        )
        .toList(growable: false);
    if (selected.isEmpty) {
      _clearCandidateSelection();
      return;
    }

    setState(() {
      _bulkAssigning = true;
      _actionMessage = '';
    });

    var linkedCount = 0;
    String? issue;
    var shouldReload = false;
    try {
      for (final candidate in selected) {
        if (!mounted) {
          return;
        }
        final apparatus = _selectedApparatus.trim();
        if (apparatus.isEmpty ||
            !_candidateApparatusOptions(candidate).any(
              (option) => productionMapStationTitlesMatch(option, apparatus),
            )) {
          issue = 'Bu homashyo uchun aparat topilmadi';
          break;
        }

        final barcode = candidate.barcode.trim();
        final key = _candidateKey(candidate);
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
                if (_candidateKey(item) != key) item,
            ];
            _assignments = [
              saved,
              for (final item in _assignments)
                if (_barcodeKey(item.barcode) != key) item,
            ];
            _selectedCandidateBarcodes.remove(key);
          });
          linkedCount++;
        } catch (error) {
          issue = error is MobileApiException
              ? error.message
              : 'Homashyo ulanmagan';
          shouldReload = true;
          break;
        }
      }
      if (!mounted) {
        return;
      }
      if (shouldReload) {
        await _load(showLoading: false);
        if (!mounted) {
          return;
        }
      }
      setState(() {
        _bulkAssigning = false;
        if (issue == null) {
          _selectedCandidateBarcodes.clear();
          _actionMessage = '$linkedCount ta homashyo orderga ulandi';
        } else {
          _actionMessage = linkedCount > 0
              ? '$linkedCount ta homashyo ulandi. $issue'
              : issue;
        }
      });
    } finally {
      if (mounted && _bulkAssigning) {
        setState(() => _bulkAssigning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasSelection = _selectedCandidateBarcodes.isNotEmpty;
    return SafeArea(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: hasSelection ? 104 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SequenceAssignmentSheetHeader(
                  order: widget.order,
                  onClose: () => Navigator.of(context).pop(),
                ),
                _SequenceAssignmentApparatusFilter(
                  options: _apparatusOptions,
                  selectedApparatus: _selectedApparatus,
                  expanded: _apparatusFilterExpanded,
                  busy: _bulkAssigning || _assigningBarcode.isNotEmpty,
                  onToggle: () {
                    if (_apparatusOptions.isEmpty ||
                        _bulkAssigning ||
                        _assigningBarcode.isNotEmpty) {
                      return;
                    }
                    setState(
                      () =>
                          _apparatusFilterExpanded = !_apparatusFilterExpanded,
                    );
                  },
                  onSelect: _selectApparatus,
                ),
                if (_actionMessage.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _actionMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _actionMessage == 'Homashyo orderga ulandi' ||
                                  _actionMessage.endsWith(
                                    'ta homashyo orderga ulandi',
                                  )
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
          if (hasSelection)
            Positioned(
              right: 16,
              bottom: 16,
              child: _SequenceBulkAssignmentFab(
                selectedCount: _selectedCandidateBarcodes.length,
                busy: _bulkAssigning,
                onAssign: _assignSelected,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_apparatusOptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: _SequenceAssignmentMessage(
          icon: Icons.lock_outline_rounded,
          title: 'Ruxsat berilgan aparat topilmadi',
          message:
              'Admin user details’da material ta’minotchiga kamida bitta aparat biriktiring.',
        ),
      );
    }
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
    final candidateMinimumAcceptedRollWidthMm =
        _sequenceMinimumAcceptedRollWidthMm(_candidates);
    final candidateMaximumAcceptedRollWidthMm =
        _sequenceMaximumAcceptedRollWidthMm(
      candidateMinimumAcceptedRollWidthMm,
      _selectedApparatus,
    );
    final emptyMinimumAcceptedRollWidthMm =
        candidateMinimumAcceptedRollWidthMm ??
            _sequenceMinimumAcceptedRollWidthMmForOrder(
              widget.order,
              _selectedApparatus,
            );
    if (_candidates.isNotEmpty) {
      children.add(
        _SequenceAssignmentIntro(
          candidateCount: _candidates.length,
          assignedCount: _assignments.length,
          minimumAcceptedRollWidthMm: candidateMinimumAcceptedRollWidthMm,
          maximumAcceptedRollWidthMm: candidateMaximumAcceptedRollWidthMm,
        ),
      );
      children.add(const SizedBox(height: 10));
      for (var index = 0; index < _candidates.length; index++) {
        if (index > 0) {
          children.add(const SizedBox(height: 10));
        }
        final candidate = _candidates[index];
        final candidateKey = _candidateKey(candidate);
        final selectionMode = _selectedCandidateBarcodes.isNotEmpty;
        children.add(
          _SequenceCandidateCard(
            candidate: candidate,
            rank: index + 1,
            selected: _selectedCandidateBarcodes.contains(candidateKey),
            selectionMode: selectionMode,
            busy: _assigningBarcode == candidateKey ||
                (_bulkAssigning &&
                    _selectedCandidateBarcodes.contains(candidateKey)),
            onAction: selectionMode
                ? () => _toggleCandidateSelection(candidate)
                : () => _assign(candidate),
            onLongPress: () => _toggleCandidateSelection(candidate),
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
          minimumAcceptedRollWidthMm:
              _assignments.isEmpty ? emptyMinimumAcceptedRollWidthMm : null,
          maximumAcceptedRollWidthMm: _assignments.isEmpty
              ? _sequenceMaximumAcceptedRollWidthMm(
                  emptyMinimumAcceptedRollWidthMm,
                  _selectedApparatus,
                )
              : null,
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

class _SequenceAssignmentApparatusFilter extends StatelessWidget {
  const _SequenceAssignmentApparatusFilter({
    required this.options,
    required this.selectedApparatus,
    required this.expanded,
    required this.busy,
    required this.onToggle,
    required this.onSelect,
  });

  final List<String> options;
  final String selectedApparatus;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bu orderning qaysi aparatiga homashyo ulamoqchisiz?',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          IgnorePointer(
            ignoring: busy,
            child: AdminExpandableFilterChip<String>(
              label: 'Aparat',
              emptyLabel: options.isEmpty ? 'Ruxsat yo‘q' : 'Tanlang',
              icon: Icons.precision_manufacturing_outlined,
              selectedValue:
                  selectedApparatus.trim().isEmpty ? null : selectedApparatus,
              options: [
                for (final apparatus in options)
                  AdminFilterChipOption<String>(
                    value: apparatus,
                    label: apparatus,
                    key: ValueKey('sequence-apparatus-option-$apparatus'),
                  ),
              ],
              expanded: expanded,
              onToggle: onToggle,
              onSelect: onSelect,
              padding: EdgeInsets.zero,
              chipKey: const ValueKey('sequence-apparatus-filter'),
              optionKeyPrefix: 'sequence-apparatus-option',
            ),
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
    this.minimumAcceptedRollWidthMm,
    this.maximumAcceptedRollWidthMm,
  });

  final int candidateCount;
  final int assignedCount;
  final double? minimumAcceptedRollWidthMm;
  final double? maximumAcceptedRollWidthMm;

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
                  const SizedBox(height: 3),
                  Text(
                    'Bir nechta ulash uchun cardni bosib turing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
                  if (minimumAcceptedRollWidthMm != null) ...[
                    const SizedBox(height: 8),
                    _SequenceMinimumRequirementCard(
                      minimumAcceptedRollWidthMm: minimumAcceptedRollWidthMm!,
                      maximumAcceptedRollWidthMm: maximumAcceptedRollWidthMm,
                    ),
                  ],
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

class _SequenceBulkAssignmentFab extends StatelessWidget {
  const _SequenceBulkAssignmentFab({
    required this.selectedCount,
    required this.busy,
    required this.onAssign,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'sequence-bulk-assignment-fab',
      tooltip: 'Tanlanganlarni ulash',
      onPressed: busy ? null : onAssign,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.link_rounded),
      label: Text('Ulash · $selectedCount'),
    );
  }
}

class _SequenceCandidateCard extends StatelessWidget {
  const _SequenceCandidateCard({
    required this.candidate,
    required this.rank,
    required this.busy,
    required this.selected,
    required this.selectionMode,
    required this.onAction,
    required this.onLongPress,
  });

  final AdminRawMaterialAssignmentCandidate candidate;
  final int rank;
  final bool busy;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onAction;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = candidate.itemName.trim().isEmpty
        ? candidate.itemCode.trim()
        : candidate.itemName.trim();
    final subtitle = [
      if (candidate.itemCode.trim().isNotEmpty &&
          candidate.itemCode.trim() != title)
        candidate.itemCode.trim(),
      if (candidate.barcode.trim().isNotEmpty) 'QR ${candidate.barcode.trim()}',
      if (candidate.qty > 0)
        formatQuantityWithUnit(
          candidate.qty,
          candidate.uom,
          decimalPlaces: 3,
          trimTrailingZeros: true,
        ),
    ].join(' • ');
    final materialDetails = <String>[
      if (candidate.warehouse.trim().isNotEmpty)
        'Ombor: ${candidate.warehouse.trim()}',
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
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.62)
          : scheme.surfaceContainerLow,
      elevation: selected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onAction,
        onLongPress: busy ? null : onLongPress,
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
                      color:
                          selected ? scheme.primary : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: scheme.onPrimary,
                          )
                        : Text(
                            '#$rank',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSecondaryContainer,
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
                  if (selected)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
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
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (materialDetails.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final detail in materialDetails)
                      Chip(
                        label: Text(detail),
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: selected
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
                onPressed: busy ? null : onAction,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        selectionMode
                            ? selected
                                ? Icons.check_rounded
                                : Icons.check_box_outline_blank_rounded
                            : Icons.link_rounded,
                      ),
                label: Text(
                  busy
                      ? 'Ulanmoqda...'
                      : selectionMode
                          ? selected
                              ? 'Tanlandi'
                              : 'Tanlash'
                          : 'Orderga ulash',
                ),
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
    this.minimumAcceptedRollWidthMm,
    this.maximumAcceptedRollWidthMm,
    this.centered = false,
  });

  final String message;
  final String? title;
  final Widget? action;
  final IconData? icon;
  final double? minimumAcceptedRollWidthMm;
  final double? maximumAcceptedRollWidthMm;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final minimumRequirement = minimumAcceptedRollWidthMm == null
        ? null
        : _SequenceMinimumRequirementCard(
            minimumAcceptedRollWidthMm: minimumAcceptedRollWidthMm!,
            maximumAcceptedRollWidthMm: maximumAcceptedRollWidthMm,
          );
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
                if (minimumRequirement != null) ...[
                  const SizedBox(height: 14),
                  minimumRequirement,
                ],
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

class _SequenceMinimumRequirementCard extends StatelessWidget {
  const _SequenceMinimumRequirementCard({
    required this.minimumAcceptedRollWidthMm,
    this.maximumAcceptedRollWidthMm,
  });

  final double minimumAcceptedRollWidthMm;
  final double? maximumAcceptedRollWidthMm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.rule_rounded,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                maximumAcceptedRollWidthMm == null
                    ? 'Tizim qabul qiladigan minimum: rulon eni '
                        '${_sequenceMillimeters(minimumAcceptedRollWidthMm)} '
                        'dan kichik bo‘lmasin.'
                    : 'Tizim qabul qiladigan rulon eni: '
                        '${_sequenceMillimeters(minimumAcceptedRollWidthMm)} dan '
                        '${_sequenceMillimeters(maximumAcceptedRollWidthMm!)} gacha.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _sequenceMillimeters(double value) {
  return '${formatQuantity(value, decimalPlaces: 1, trimTrailingZeros: true)} mm';
}

double? _sequenceMinimumAcceptedRollWidthMm(
  List<AdminRawMaterialAssignmentCandidate> candidates,
) {
  double? minimum;
  for (final candidate in candidates) {
    final width = candidate.orderWidthMm;
    if (width != null && width.isFinite && width > 0) {
      minimum = minimum == null || width < minimum ? width : minimum;
    }
  }
  return minimum;
}

double? _sequenceMinimumAcceptedRollWidthMmForOrder(
  ProductionMapSaved order,
  String apparatus,
) {
  final width = order.map.widthMm;
  if (width == null || !width.isFinite || width <= 0) {
    return null;
  }
  return productionMapIsPechatApparatus(apparatus) ||
          productionMapIsLaminatsiyaApparatus(apparatus)
      ? width
      : null;
}

double? _sequenceMaximumAcceptedRollWidthMm(
  double? minimumAcceptedRollWidthMm,
  String apparatus,
) {
  if (minimumAcceptedRollWidthMm == null) {
    return null;
  }
  if (productionMapIsPechatApparatus(apparatus)) {
    return minimumAcceptedRollWidthMm + 20;
  }
  if (productionMapIsLaminatsiyaApparatus(apparatus)) {
    return minimumAcceptedRollWidthMm + 30;
  }
  return null;
}

List<String> _sequenceAuthorizedOrderApparatus({
  required ProductionMapSaved order,
  required List<String> assignedApparatus,
}) {
  final result = <String>[];
  for (final stage in productionMapLinearWorkStages(order.map)) {
    final apparatus = stage.stationTitle.trim();
    if (apparatus.isEmpty ||
        !assignedApparatus.any(
          (assigned) => productionMapStationTitlesMatch(apparatus, assigned),
        ) ||
        result.any(
          (existing) => productionMapStationTitlesMatch(existing, apparatus),
        )) {
      continue;
    }
    result.add(apparatus);
  }
  return List<String>.unmodifiable(result);
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
