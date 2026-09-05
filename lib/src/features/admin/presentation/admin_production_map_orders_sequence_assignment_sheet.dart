part of 'admin_production_map_orders_screen.dart';

class _SequenceRawMaterialAssignmentSheetState
    extends State<_SequenceRawMaterialAssignmentSheet> {
  List<AdminRawMaterialAssignmentCandidate> _candidates = const [];
  List<AdminRawMaterialAssignment> _assignments = const [];
  String _loadError = '';
  String _actionMessage = '';
  String _assigningBarcode = '';
  String _qrScannerStatus = '';
  bool _actionSucceeded = false;
  String _lastQrScanValue = '';

  DateTime? _lastQrScanAt;
  int _qrDiagnosticRequestId = 0;
  final Set<String> _selectedCandidateBarcodes = <String>{};
  late final List<String> _apparatusOptions;
  String _selectedApparatus = '';
  bool _apparatusFilterExpanded = false;
  bool _qrScannerVisible = false;
  bool _bulkAssigning = false;
  bool _loading = true;
  bool _localizedStateInitialized = false;

  AdminApparatus? get _selectedCanonicalApparatus {
    final selectedId = _selectedApparatus.trim();
    for (final apparatus in widget.apparatusCatalog) {
      if (apparatus.id.trim() == selectedId) return apparatus;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _apparatusOptions = productionMapAuthorizedOrderApparatus(
      map: widget.order.map,
      assignedApparatus: widget.assignedApparatus,
    );
    _selectedApparatus = _apparatusOptions.firstWhere(
      (apparatus) => apparatus.trim() == widget.initialApparatus.trim(),
      orElse: () => _apparatusOptions.isEmpty ? '' : _apparatusOptions.first,
    );
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localizedStateInitialized) return;
    _localizedStateInitialized = true;
    _qrScannerStatus = context.l10n.adminText(
      'production.assignment.qr_prompt',
    );
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
                  scannerVisible: _qrScannerVisible,
                  onToggleScanner: _toggleQrScanner,
                  onClose: () => Navigator.of(context).pop(),
                ),
                if (_qrScannerVisible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: ProductionQuickScannerPanel(
                      key: const ValueKey('sequence-assignment-qr-scanner'),
                      statusText: _qrScannerStatus,
                      busy: _loading ||
                          _bulkAssigning ||
                          _assigningBarcode.isNotEmpty,
                      onCodeDetected: _handleQrScan,
                    ),
                  ),
                _SequenceAssignmentApparatusFilter(
                  map: widget.order.map,
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
                          color:
                              _actionSucceeded ? scheme.primary : scheme.error,
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

  Future<void> _load({bool showLoading = true}) async {
    final orderId = widget.order.map.id.trim();
    if (orderId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = context.l10n.adminText(
            'production.assignment.order_missing',
          );
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
          _selectedApparatus.trim() != apparatus) {
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
            : context.l10n.adminText('production.assignment.load_failed');
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
        !_candidateApparatusOptions(candidate)
            .any((option) => option.trim() == apparatus)) {
      setState(() {
        _actionMessage = context.l10n.adminText(
          'production.assignment.apparatus_missing',
        );
        _actionSucceeded = false;
      });
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
        _actionMessage = context.l10n.adminText(
          'production.assignment.linked',
        );
        _actionSucceeded = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _actionMessage = error is MobileApiException
            ? error.message
            : context.l10n.adminText('production.assignment.failed');
        _actionSucceeded = false;
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

  void _toggleQrScanner() {
    if (_bulkAssigning || _assigningBarcode.isNotEmpty) {
      return;
    }
    setState(() {
      ++_qrDiagnosticRequestId;
      _qrScannerVisible = !_qrScannerVisible;
      if (_qrScannerVisible) {
        _qrScannerStatus = context.l10n.adminText(
          'production.assignment.qr_prompt',
        );
        _lastQrScanValue = '';
        _lastQrScanAt = null;
      }
    });
  }

  Future<void> _handleQrScan(String rawValue) async {
    if (_loading || _bulkAssigning || _assigningBarcode.isNotEmpty) {
      return;
    }
    final normalized = rawMaterialBarcodeFromQr(rawValue).trim();
    final key = _barcodeKey(normalized);
    if (key.isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (_lastQrScanValue == key &&
        _lastQrScanAt != null &&
        now.difference(_lastQrScanAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastQrScanValue = key;
    _lastQrScanAt = now;
    final diagnosticRequestId = ++_qrDiagnosticRequestId;

    AdminRawMaterialAssignmentCandidate? matchedCandidate;
    for (final candidate in _candidates) {
      if (_candidateKey(candidate) == key) {
        matchedCandidate = candidate;
        break;
      }
    }
    if (!mounted) {
      return;
    }
    if (matchedCandidate == null) {
      final diagnosticOrderId = widget.order.map.id.trim();
      final diagnosticApparatus = _selectedApparatus.trim();
      try {
        final diagnostic =
            await MobileApi.instance.adminRawMaterialAssignmentDiagnostics(
          barcode: normalized,
          orderId: diagnosticOrderId,
          apparatus: diagnosticApparatus,
        );
        if (!mounted ||
            diagnosticRequestId != _qrDiagnosticRequestId ||
            _lastQrScanValue != key ||
            widget.order.map.id.trim() != diagnosticOrderId ||
            _selectedApparatus.trim() != diagnosticApparatus) {
          return;
        }
        setState(
          () => _qrScannerStatus = _sequenceRawMaterialDiagnosticMessage(
            context,
            diagnostic,
          ),
        );
      } catch (error) {
        if (!mounted ||
            diagnosticRequestId != _qrDiagnosticRequestId ||
            _lastQrScanValue != key ||
            widget.order.map.id.trim() != diagnosticOrderId ||
            _selectedApparatus.trim() != diagnosticApparatus) {
          return;
        }
        setState(
          () => _qrScannerStatus = error is MobileApiException
              ? error.message
              : context.l10n.adminText(
                  'production.assignment.diagnostic_failed',
                ),
        );
      }
      return;
    }
    final apparatus = _selectedApparatus.trim();
    if (apparatus.isEmpty ||
        !_candidateApparatusOptions(matchedCandidate)
            .any((option) => option.trim() == apparatus)) {
      setState(
        () => _qrScannerStatus = context.l10n.adminText(
          'production.assignment.qr_wrong_apparatus',
        ),
      );
      return;
    }

    final alreadySelected = _selectedCandidateBarcodes.contains(key);
    final title = matchedCandidate.itemName.trim().isEmpty
        ? matchedCandidate.itemCode.trim()
        : matchedCandidate.itemName.trim();
    setState(() {
      _selectedCandidateBarcodes.add(key);
      _actionMessage = '';
      _qrScannerStatus = alreadySelected
          ? context.l10n.adminText(
              'production.assignment.already_selected',
              values: {'count': _selectedCandidateBarcodes.length},
            )
          : context.l10n.adminText(
              'production.assignment.selected',
              values: {
                'title': title.isEmpty
                    ? context.l10n.adminText('label.item')
                    : title,
                'count': _selectedCandidateBarcodes.length,
              },
            );
    });
  }

  void _selectApparatus(String apparatus) {
    if (_bulkAssigning || _assigningBarcode.isNotEmpty) {
      return;
    }
    final normalized = apparatus.trim();
    if (normalized.isEmpty || normalized == _selectedApparatus.trim()) {
      setState(() => _apparatusFilterExpanded = false);
      return;
    }
    setState(() {
      ++_qrDiagnosticRequestId;
      _selectedApparatus = normalized;
      _apparatusFilterExpanded = false;
      _selectedCandidateBarcodes.clear();
      _candidates = const [];
      _assignments = const [];
      _actionMessage = '';
      _qrScannerStatus = context.l10n.adminText(
        'production.assignment.qr_prompt',
      );
      _lastQrScanValue = '';
      _lastQrScanAt = null;
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
            !_candidateApparatusOptions(candidate)
                .any((option) => option.trim() == apparatus)) {
          issue = context.l10n.adminText(
            'production.assignment.apparatus_missing',
          );
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
              : context.l10n.adminText('production.assignment.failed');
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
          _actionMessage = context.l10n.adminText(
            'production.assignment.linked_count',
            values: {'count': linkedCount},
          );
          _actionSucceeded = true;
          if (_qrScannerVisible) {
            _qrScannerStatus = context.l10n.adminText(
              'production.assignment.linked_scan_more',
              values: {'count': linkedCount},
            );
          }
        } else {
          _actionMessage = linkedCount > 0
              ? context.l10n.adminText(
                  'production.assignment.partial_linked',
                  values: {'count': linkedCount, 'error': issue},
                )
              : issue;
          _actionSucceeded = false;
        }
      });
    } finally {
      if (mounted && _bulkAssigning) {
        setState(() => _bulkAssigning = false);
      }
    }
  }

  Widget _buildBody(BuildContext context) {
    if (_apparatusOptions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: _SequenceAssignmentMessage(
          icon: Icons.lock_outline_rounded,
          title: context.l10n.adminText(
            'production.assignment.apparatus_access_title',
          ),
          message: context.l10n.adminText(
            'production.assignment.apparatus_access_message',
          ),
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
        title: context.l10n.adminText(
          'production.assignment.load_failed',
        ),
        message: _loadError,
        action: TextButton(
          onPressed: () => _load(),
          child: Text(context.l10n.adminText('production.qolip_retry')),
        ),
      );
    }

    final children = <Widget>[];
    final candidateMinimumAcceptedRollWidthMm =
        _sequenceMinimumAcceptedRollWidthMm(_candidates);
    final candidateMaximumAcceptedRollWidthMm =
        _sequenceMaximumAcceptedRollWidthMm(
      candidateMinimumAcceptedRollWidthMm,
      _selectedCanonicalApparatus,
    );
    final orderMinimumAcceptedRollWidthMm =
        _sequenceMinimumAcceptedRollWidthMmForOrder(
      widget.order,
      _selectedCanonicalApparatus,
    );
    final minimumAcceptedRollWidthMm =
        candidateMinimumAcceptedRollWidthMm ?? orderMinimumAcceptedRollWidthMm;
    final maximumAcceptedRollWidthMm = candidateMaximumAcceptedRollWidthMm ??
        _sequenceMaximumAcceptedRollWidthMm(
          minimumAcceptedRollWidthMm,
          _selectedCanonicalApparatus,
        );
    if (_candidates.isNotEmpty) {
      children.add(
        _SequenceAssignmentIntro(
          candidateCount: _candidates.length,
          assignedCount: _assignments.length,
          minimumAcceptedRollWidthMm: minimumAcceptedRollWidthMm,
          maximumAcceptedRollWidthMm: maximumAcceptedRollWidthMm,
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
            apparatusCatalog: widget.apparatusCatalog,
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
              ? context.l10n.adminText('production.assignment.no_matching')
              : context.l10n.adminText('production.assignment.all_linked'),
          message: _assignments.isEmpty
              ? context.l10n.adminText('production.assignment.no_stock')
              : context.l10n.adminText('production.assignment.refresh_hint'),
          minimumAcceptedRollWidthMm: minimumAcceptedRollWidthMm,
          maximumAcceptedRollWidthMm: maximumAcceptedRollWidthMm,
          action: TextButton(
            onPressed: _loading ? null : () => _load(),
            child: Text(context.l10n.adminText('action.retry')),
          ),
          centered: _assignments.isEmpty,
        ),
      );
    }

    if (_assignments.isNotEmpty) {
      children.addAll([
        const SizedBox(height: 18),
        Text(
          context.l10n.adminText('production.assignment.connected_title'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _assignments.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          _SequenceAssignedMaterialRow(
            assignment: _assignments[index],
            apparatusCatalog: widget.apparatusCatalog,
          ),
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

class _SequenceRawMaterialAssignmentSheet extends StatefulWidget {
  const _SequenceRawMaterialAssignmentSheet({
    required this.order,
    required this.initialApparatus,
    required this.assignedApparatus,
    required this.apparatusCatalog,
  });
  final ProductionMapSaved order;
  final String initialApparatus;
  final List<String> assignedApparatus;
  final List<AdminApparatus> apparatusCatalog;

  @override
  State<_SequenceRawMaterialAssignmentSheet> createState() =>
      _SequenceRawMaterialAssignmentSheetState();
}

class _SequenceAssignmentSheetHeader extends StatelessWidget {
  const _SequenceAssignmentSheetHeader({
    required this.order,
    required this.scannerVisible,
    required this.onToggleScanner,
    required this.onClose,
  });
  final ProductionMapSaved order;
  final bool scannerVisible;
  final VoidCallback onToggleScanner;
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
        context.l10n.adminText('production.assignment.title'),
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
            key: const ValueKey('sequence-assignment-qr-scan'),
            tooltip: scannerVisible
                ? context.l10n.adminText(
                    'production.assignment.qr_close',
                  )
                : context.l10n.adminText(
                    'production.assignment.qr_scan',
                  ),
            onPressed: onToggleScanner,
            color: scannerVisible ? theme.colorScheme.primary : null,
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
          IconButton(
            tooltip: context.l10n.adminText('action.close'),
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
    required this.map,
    required this.options,
    required this.selectedApparatus,
    required this.expanded,
    required this.busy,
    required this.onToggle,
    required this.onSelect,
  });
  final ProductionMapDefinition map;
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
            context.l10n.adminText(
              'production.assignment.apparatus_question',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          IgnorePointer(
            ignoring: busy,
            child: AdminExpandableFilterChip<String>(
              label: context.l10n.adminText('label.apparatus'),
              emptyLabel: options.isEmpty
                  ? context.l10n.adminText(
                      'production.assignment.not_allowed',
                    )
                  : context.l10n.adminText('production.assignment.select'),
              icon: Icons.precision_manufacturing_outlined,
              selectedValue:
                  selectedApparatus.trim().isEmpty ? null : selectedApparatus,
              options: [
                for (final apparatus in options)
                  AdminFilterChipOption<String>(
                    value: apparatus,
                    label: productionMapStageDisplayTitle(
                      map: map,
                      station: apparatus,
                    ),
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
                    context.l10n.adminText(
                      'production.assignment.candidate_count',
                      values: {'count': candidateCount},
                    ),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.adminText(
                      'production.assignment.match_hint',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.adminText(
                      'production.assignment.multi_hint',
                    ),
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
                      context.l10n.adminText(
                        'production.assignment.assigned_count',
                        values: {'count': assignedCount},
                      ),
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
      tooltip: context.l10n.adminText(
        'production.assignment.bulk_link',
      ),
      onPressed: busy ? null : onAssign,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.link_rounded),
      label: Text(
        context.l10n.adminText(
          'production.assignment.link_count',
          values: {'count': selectedCount},
        ),
      ),
    );
  }
}

class _SequenceCandidateCard extends StatelessWidget {
  const _SequenceCandidateCard({
    required this.candidate,
    required this.apparatusCatalog,
    required this.rank,
    required this.busy,
    required this.selected,
    required this.selectionMode,
    required this.onAction,
    required this.onLongPress,
  });
  final AdminRawMaterialAssignmentCandidate candidate;
  final List<AdminApparatus> apparatusCatalog;
  final int rank;
  final bool busy;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onAction;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
        l10n.adminText(
          'production.assignment.warehouse',
          values: {'value': candidate.warehouse.trim()},
        ),
      if (candidate.orderWidthMm != null)
        l10n.adminText(
          'production.assignment.order_width',
          values: {'value': _sequenceMillimeters(candidate.orderWidthMm!)},
        ),
      if (candidate.rollWidthMm != null)
        l10n.adminText(
          'production.assignment.roll_width',
          values: {'value': _sequenceMillimeters(candidate.rollWidthMm!)},
        ),
      if (candidate.leftoverWidthMm != null)
        l10n.adminText(
          'production.assignment.leftover_width',
          values: {'value': _sequenceMillimeters(candidate.leftoverWidthMm!)},
        ),
    ];
    final matchLabel = switch (candidate.matchType.trim()) {
      'exact_width' => l10n.adminText('production.assignment.exact'),
      'closest_width' => l10n.adminText('production.assignment.closest'),
      _ => l10n.adminText('production.assignment.compatible'),
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
                          title.isEmpty
                              ? l10n.adminText(
                                  'production.assignment.unnamed',
                                )
                              : title,
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
                  l10n.adminText(
                    'production.assignment.group_apparatus',
                    values: {
                      'group': candidate.itemGroup.trim(),
                      'apparatus': canonicalApparatusDisplayLabels(
                        candidate.apparatusOptions,
                        apparatusCatalog,
                      ).join(', '),
                    },
                  ),
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
                      ? l10n.adminText('production.assignment.linking')
                      : selectionMode
                          ? selected
                              ? l10n.adminText(
                                  'production.assignment.selected_label',
                                )
                              : l10n.adminText(
                                  'production.assignment.select',
                                )
                          : l10n.adminText('production.assignment.link'),
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
  const _SequenceAssignedMaterialRow({
    required this.assignment,
    required this.apparatusCatalog,
  });
  final AdminRawMaterialAssignment assignment;
  final List<AdminApparatus> apparatusCatalog;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode.trim()
        : assignment.itemName.trim();
    final subtitle = [
      if (assignment.barcode.trim().isNotEmpty) assignment.barcode.trim(),
      if (assignment.apparatus.trim().isNotEmpty)
        canonicalApparatusDisplayLabel(
          assignment.apparatus,
          apparatusCatalog,
        ),
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
        title: Text(
          title.isEmpty
              ? context.l10n.adminText('production.assignment.connected')
              : title,
        ),
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
              if (minimumRequirement != null) ...[
                const SizedBox(height: 14),
                minimumRequirement,
              ],
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
    final l10n = context.l10n;
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
                    ? l10n.adminText(
                        'production.assignment.minimum_width',
                        values: {
                          'value': _sequenceMillimeters(
                            minimumAcceptedRollWidthMm,
                          ),
                        },
                      )
                    : l10n.adminText(
                        'production.assignment.width_range',
                        values: {
                          'min': _sequenceMillimeters(
                            minimumAcceptedRollWidthMm,
                          ),
                          'max': _sequenceMillimeters(
                            maximumAcceptedRollWidthMm!,
                          ),
                        },
                      ),
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
  AdminApparatus? apparatus,
) {
  final width = order.map.widthMm;
  if (width == null || !width.isFinite || width <= 0) {
    return null;
  }
  final operation = apparatus?.operation.trim().toLowerCase();
  return operation == 'print' || operation == 'laminate' ? width : null;
}

double? _sequenceMaximumAcceptedRollWidthMm(
  double? minimumAcceptedRollWidthMm,
  AdminApparatus? apparatus,
) {
  if (minimumAcceptedRollWidthMm == null) {
    return null;
  }
  final operation = apparatus?.operation.trim().toLowerCase();
  if (operation == 'print') {
    return minimumAcceptedRollWidthMm + 20;
  }
  if (operation == 'laminate') {
    return minimumAcceptedRollWidthMm + 30;
  }
  return null;
}

String _sequenceRawMaterialDiagnosticMessage(
  BuildContext context,
  AdminRawMaterialAssignmentDiagnostic diagnostic,
) {
  final l10n = context.l10n;
  if (diagnostic.compatible) {
    return l10n.adminText(
      'production.assignment.diagnostic_compatible_refresh',
    );
  }
  final reason = diagnostic.reason.trim().toLowerCase();
  final actual = diagnostic.rollWidthMm;
  final minimum = diagnostic.minimumWidthMm ?? diagnostic.orderWidthMm;
  final maximum = diagnostic.maximumWidthMm;
  if (reason == 'raw_material_roll_size_mismatch' &&
      actual != null &&
      minimum != null &&
      actual.isFinite &&
      minimum.isFinite &&
      actual < minimum) {
    return l10n.adminText(
      'production.assignment.diagnostic_roll_too_narrow',
      values: {
        'actual': _sequenceMillimeters(actual),
        'min': _sequenceMillimeters(minimum),
      },
    );
  }
  if (reason == 'raw_material_roll_size_mismatch' &&
      actual != null &&
      minimum != null &&
      maximum != null &&
      actual.isFinite &&
      minimum.isFinite &&
      maximum.isFinite) {
    return l10n.adminText(
      'production.assignment.diagnostic_roll_too_wide',
      values: {
        'actual': _sequenceMillimeters(actual),
        'min': _sequenceMillimeters(minimum),
        'max': _sequenceMillimeters(maximum),
      },
    );
  }
  switch (reason) {
    case 'raw_material_roll_size_missing':
      return l10n.adminText(
        'production.assignment.diagnostic_roll_size_missing',
      );
    case 'raw_material_stock_unavailable':
      return l10n.adminText(
        'production.assignment.diagnostic_stock_unavailable',
      );
    case 'raw_material_already_assigned':
      if (diagnostic.orderTitle.trim().isNotEmpty) {
        return l10n.adminText(
          'production.assignment.diagnostic_already_assigned_named',
          values: {'order': diagnostic.orderTitle.trim()},
        );
      }
      return l10n.adminText(
        'production.assignment.diagnostic_already_assigned',
      );
    case 'raw_material_already_assigned_to_order':
      return l10n.adminText(
        'production.assignment.diagnostic_already_assigned_to_order',
      );
    case 'raw_material_order_not_active':
    case 'no_compatible_active_order':
      return l10n.adminText(
        'production.assignment.diagnostic_order_not_active',
      );
    case 'raw_material_group_not_allowed':
      return l10n.adminText(
        'production.assignment.diagnostic_group_not_allowed',
      );
    case 'apparatus_not_assigned':
      return l10n.adminText(
        'production.assignment.apparatus_access_message',
      );
    default:
      return l10n.adminText(
        'production.assignment.diagnostic_generic',
        values: {
          'reason': diagnostic.reason.trim().isEmpty
              ? l10n.adminText('production.assignment.qr_not_found')
              : diagnostic.reason,
        },
      );
  }
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
