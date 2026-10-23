import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/production/production_data_revision.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';

/// The server supplies only free, compatible material physically placed at this apparatus.
class WorkerMaterialUsePanel extends StatefulWidget {
  const WorkerMaterialUsePanel(
      {super.key,
      required this.orderId,
      required this.apparatusId,
      required this.onMaterialsUsed});
  final String orderId, apparatusId;
  final ValueChanged<String> onMaterialsUsed;
  @override
  State<WorkerMaterialUsePanel> createState() => _WorkerMaterialUsePanelState();
}

class _WorkerMaterialUsePanelState extends State<WorkerMaterialUsePanel>
    with WidgetsBindingObserver {
  WorkerMaterialCandidates? _snapshot;
  Timer? _feedbackTimer;
  Future<void>? _refreshing;
  bool _refreshQueued = false;
  bool _scannerOpen = false, _busy = false, _confirming = false;
  ProductionQuickScanFeedback? _feedback;
  String _status = '';
  int _generation = 0;
  late Object _observedScope;
  Object get _scope =>
      (currentSessionReadScope(), widget.orderId, widget.apparatusId);
  bool _current(Object scope, int generation) =>
      mounted && scope == _scope && generation == _generation;
  bool get _canRefresh =>
      !_busy &&
      !_confirming &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);
  List<WorkerMaterialCandidate> get _candidates =>
      _snapshot?.enabled == true ? _snapshot!.candidates : const [];

  @override
  void initState() {
    super.initState();
    _observedScope = _scope;
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_sessionChanged);
    ProductionDataRevision.revision.addListener(_productionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if ((_snapshot == null || _refreshQueued) && _canRefresh) {
      unawaited(_refresh());
    }
  }

  @override
  void didUpdateWidget(covariant WorkerMaterialUsePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_observedScope != _scope) _reset();
  }

  void _sessionChanged() {
    if (_observedScope != _scope) _reset();
  }

  void _productionChanged() {
    if (!ProductionDataRevision.isCurrentScope) return;
    _refreshQueued = true;
    _drainRefresh();
  }

  void _drainRefresh() {
    if (mounted && _refreshQueued && _canRefresh) unawaited(_refresh());
  }

  void _reset() {
    _observedScope = _scope;
    _generation++;
    _refreshing = null;
    _refreshQueued = false;
    setState(() {
      _snapshot = null;
      _scannerOpen = _busy = _confirming = false;
      _feedback = null;
      _status = '';
    });
    if (_canRefresh) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _canRefresh) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    ProductionDataRevision.revision.removeListener(_productionChanged);
    _feedbackTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _refresh() {
    if (_refreshing case final pending?) return pending;
    _refreshQueued = false;
    late Future<void> pending;
    pending = _read().whenComplete(() {
      if (identical(_refreshing, pending)) {
        _refreshing = null;
        _drainRefresh();
      }
    });
    return _refreshing = pending;
  }

  Future<void> _read() async {
    final scope = _scope;
    final generation = _generation;
    try {
      final snapshot = await MobileApi.instance.workerMaterialCandidates(
          orderId: widget.orderId, apparatus: widget.apparatusId);
      if (!_current(scope, generation)) return;
      setState(() {
        _snapshot = snapshot;
        if (_candidates.isEmpty) _scannerOpen = false;
      });
    } catch (_) {
      // A failed read cannot leave a previously permitted roll available for a new scan.
      if (_current(scope, generation)) setState(() => _snapshot = null);
    }
  }

  void _showFeedback(ProductionQuickScanFeedback feedback, String status) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedback = feedback;
      _status = status;
    });
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  Future<void> _scan(String raw) async {
    if (_busy || _confirming || !_scannerOpen) return;
    final l10n = context.l10n;
    final scope = _scope;
    final generation = _generation;
    final barcode = rawMaterialBarcodeFromQr(raw).trim().toUpperCase();
    final material = _candidates
        .where((row) => row.barcode.toUpperCase() == barcode)
        .firstOrNull;
    if (material == null) {
      _showFeedback(ProductionQuickScanFeedback.rejected,
          l10n.productionText('worker.material_use.rejected'));
      return;
    }
    _showFeedback(ProductionQuickScanFeedback.accepted,
        l10n.productionText('worker.material_use.accepted'));
    setState(() => _confirming = true);
    try {
      final confirmed = await showM3ConfirmDialog(
            context: context,
            title: l10n.productionText('worker.material_use.confirm'),
            message: '${material.itemName}\n${material.barcode}',
            cancelLabel: l10n.productionText('worker.material_use.no'),
            confirmLabel: l10n.productionText('worker.material_use.yes'),
            confirmButtonKey: const ValueKey('worker-material-use-confirm'),
            verticalActions: true,
          ) ??
          false;
      if (!confirmed || !_current(scope, generation)) return;
      // Retire a pre-confirmation read before the authoritative write and refresh.
      _generation++;
      _refreshing = null;
      final mutationGeneration = _generation;
      setState(() => _busy = true);
      try {
        await MobileApi.instance.useWorkerMaterial(
            orderId: widget.orderId,
            apparatus: widget.apparatusId,
            material: material);
        if (!_current(scope, mutationGeneration)) return;
        widget.onMaterialsUsed(material.barcode);
        await _refresh();
      } catch (error) {
        if (!_current(scope, mutationGeneration)) return;
        _showFeedback(
            ProductionQuickScanFeedback.rejected,
            error is MobileApiException
                ? error.message
                : l10n.productionText('worker.material_use.failed'));
        await _refresh();
      } finally {
        if (_current(scope, mutationGeneration)) {
          setState(() {
            _busy = false;
            _confirming = false;
          });
          _drainRefresh();
        }
      }
    } finally {
      if (_current(scope, generation)) {
        setState(() => _confirming = false);
        _drainRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candidates.isEmpty && !_busy && !_confirming) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OutlinedButton.icon(
        key: const ValueKey('worker-material-use-button'),
        onPressed: _busy || _confirming || _candidates.isEmpty
            ? null
            : () async {
                await _refresh();
                if (mounted && _candidates.isNotEmpty) {
                  setState(() => _scannerOpen = !_scannerOpen);
                }
              },
        icon: const Icon(Icons.qr_code_scanner),
        label: Text(context.l10n.productionText('worker.material_use.button')),
      ),
      if (_scannerOpen) ...[
        const SizedBox(height: 8),
        ProductionQuickScannerPanel(
          onCodeDetected: _scan,
          busy: _busy || _confirming,
          feedback: _feedback,
          statusText: _status.isEmpty
              ? context.l10n.productionText('worker.material_use.scan')
              : _status,
        ),
      ],
    ]);
  }
}
