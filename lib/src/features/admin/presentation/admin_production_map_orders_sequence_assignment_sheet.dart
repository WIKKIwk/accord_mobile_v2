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
}
