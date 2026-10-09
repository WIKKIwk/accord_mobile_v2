part of 'aparatchi_paddon_detail_screen.dart';

extension _PaddonQrAddition on _AparatchiPaddonDetailScreenState {
  void _startQrScanning(AdminPaddonSnapshot snapshot) {
    if (_busy ||
        widget.busy ||
        _printingQr ||
        !widget.manageItems ||
        !snapshot.canManageItems) {
      return;
    }
    _updateQrScan(() {
      _qrScanGeneration += 1;
      _qrScanScope = currentSessionReadScope();
      _qrScanMode = true;
      _selectionMode = false;
      _bobinaFilterUnits = null;
      _selectedAvailableBatchIds.clear();
      _selectedAssignedBatchIds.clear();
      _qrScanStatus = '';
      _qrScanFeedback = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scannerContext = _qrScannerKey.currentContext;
      if (!mounted || scannerContext == null) return;
      unawaited(Scrollable.ensureVisible(
        scannerContext,
        alignment: 0.08,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      ));
    });
  }

  bool _isCurrentQrScan(int generation, Object? scope) =>
      mounted &&
      _qrScanMode &&
      generation == _qrScanGeneration &&
      scope == currentSessionReadScope();

  void _showQrScanFeedback(
      String message, ProductionQuickScanFeedback feedback) {
    _qrScanFeedbackTimer?.cancel();
    _updateQrScan(() {
      _qrScanStatus = message;
      _qrScanFeedback = feedback;
    });
    _qrScanFeedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _updateQrScan(() => _qrScanFeedback = null);
    });
  }

  Future<void> _stageScannedQr(String rawValue) async {
    if (!_isCurrentQrScan(_qrScanGeneration, _qrScanScope) ||
        _busy ||
        widget.busy ||
        _printingQr ||
        _qrReviewOpen) {
      return;
    }
    final l10n = context.l10n;
    final qr = rawMaterialBarcodeFromQr(rawValue).trim();
    final key = qr.toUpperCase();
    if (qr.isEmpty || _queuedQrValues.contains(key)) return;
    final knownBatchId = _scannedBatchIdsByQr[key];
    if (knownBatchId != null && _scannedWips.containsKey(knownBatchId)) {
      _showQrScanFeedback(
        l10n.productionText('worker.paddon.scan.duplicate'),
        ProductionQuickScanFeedback.none,
      );
      return;
    }
    if (_scannedWips.length + _qrLookupsPending >= 500) {
      _showQrScanFeedback(
        l10n.productionText('worker.paddon.scan.limit'),
        ProductionQuickScanFeedback.rejected,
      );
      return;
    }
    final generation = _qrScanGeneration;
    final scope = _qrScanScope;
    _updateQrScan(() {
      _queuedQrValues.add(key);
      _qrLookupsPending += 1;
    });
    // Keep rapid detections queued while the previous QR is being checked.
    final operation = _qrScanQueue.then((_) async {
      try {
        if (!_isCurrentQrScan(generation, scope)) return;
        final batch = await MobileApi.instance.adminProgressQrLookup(qr);
        if (!_isCurrentQrScan(generation, scope)) return;
        final snapshot = widget.snapshot ?? await _future;
        if (!_isCurrentQrScan(generation, scope)) return;
        if (!snapshot.canManageItems) {
          throw const MobileApiException(code: 'paddon_locked', message: '');
        }
        final batchId = batch.batchId.trim();
        if (batchId.isEmpty || batch.qrPayload.trim().isEmpty) {
          throw const MobileApiException(
            code: 'progress_qr_invalid_response',
            message: '',
          );
        }
        if (snapshot.items.any((item) => item.batchId.trim() == batchId)) {
          _showQrScanFeedback(
            l10n.productionText('worker.paddon.scan.already_assigned'),
            ProductionQuickScanFeedback.none,
          );
          return;
        }
        if (_scannedWips.containsKey(batchId)) {
          _showQrScanFeedback(
            l10n.productionText('worker.paddon.scan.duplicate'),
            ProductionQuickScanFeedback.none,
          );
          return;
        }
        if (batch.wipStatus != 'waiting' ||
            (batch.payloadJson['finished_goods_stock_id']?.toString() ?? '')
                .isNotEmpty ||
            (batch.payloadJson['received_warehouse']?.toString() ?? '')
                .isNotEmpty) {
          throw const MobileApiException(
            code: 'progress_batch_not_accepted',
            message: '',
          );
        }
        _updateQrScan(() {
          _scannedWips[batchId] = batch;
          _scannedBatchIdsByQr[key] = batchId;
        });
        _showQrScanFeedback(
          l10n.productionText('worker.paddon.scan.accepted',
              values: {'count': _scannedWips.length}),
          ProductionQuickScanFeedback.accepted,
        );
      } catch (error) {
        if (_isCurrentQrScan(generation, scope)) {
          final fallback =
              l10n.productionText('worker.paddon.scan.lookup_failed');
          _showQrScanFeedback(
            error is MobileApiException
                ? l10n.productionErrorMessage(error.code, fallback: fallback)
                : fallback,
            ProductionQuickScanFeedback.rejected,
          );
        }
      } finally {
        if (mounted && generation == _qrScanGeneration) {
          _updateQrScan(() {
            _queuedQrValues.remove(key);
            _qrLookupsPending -= 1;
          });
        }
      }
    });
    _qrScanQueue = operation;
    await operation;
  }

  String _qrConfirmLabel(BuildContext context) => context.l10n.productionText(
        'worker.paddon.scan.confirm',
        values: {'count': _scannedWips.length},
      );

  Future<void> _confirmScannedWips() async {
    if (_busy ||
        widget.busy ||
        _printingQr ||
        _qrLookupsPending > 0 ||
        _scannedWips.isEmpty ||
        !_isCurrentQrScan(_qrScanGeneration, _qrScanScope)) {
      return;
    }
    final l10n = context.l10n;
    final generation = _qrScanGeneration;
    final scope = _qrScanScope;
    final ids = _scannedWips.keys.toList(growable: false);
    final applied = await _runMutation(
      () => MobileApi.instance.adminPaddonAddWips(
        paddonCode: widget.code,
        progressBatchIds: ids,
      ),
      expectedReadScope: scope,
      confirmsApplied: (snapshot) {
        final assigned =
            snapshot.items.map((item) => item.batchId.trim()).toSet();
        return ids.every(assigned.contains);
      },
      fallbackMessage: l10n.productionText('worker.paddon.add_failed'),
    );
    if (!_isCurrentQrScan(generation, scope)) return;
    if (applied) {
      _updateQrScan(_resetQrScanning);
    } else {
      _showQrScanFeedback(
        l10n.productionText('worker.paddon.add_failed'),
        ProductionQuickScanFeedback.rejected,
      );
    }
  }

  void _resetQrScanning() {
    _qrScanGeneration += 1;
    _qrScanMode = false;
    _qrScanScope = null;
    _qrLookupsPending = 0;
    _qrScanQueue = Future<void>.value();
    _queuedQrValues.clear();
    _scannedWips.clear();
    _scannedBatchIdsByQr.clear();
    _qrScanStatus = '';
    _qrScanFeedback = null;
    _qrScanFeedbackTimer?.cancel();
  }

  Future<bool> _cancelQrScanning() async {
    if (_busy || widget.busy || !_qrScanMode || _qrReviewOpen) return false;
    if (_scannedWips.isNotEmpty || _qrLookupsPending > 0) {
      _updateQrScan(() => _qrReviewOpen = true);
      bool? confirmed;
      try {
        confirmed = await showM3ConfirmDialog(
          context: context,
          title:
              context.l10n.productionText('worker.paddon.scan.discard.title'),
          message:
              context.l10n.productionText('worker.paddon.scan.discard.body'),
          cancelLabel: context.l10n.no,
          confirmLabel: context.l10n.yes,
          confirmButtonKey: const ValueKey('paddon-scan-discard-confirm'),
          cancelButtonKey: const ValueKey('paddon-scan-discard-cancel'),
        );
      } finally {
        if (mounted) _updateQrScan(() => _qrReviewOpen = false);
      }
      if (confirmed != true || !mounted || _busy) return false;
    }
    _updateQrScan(_resetQrScanning);
    return true;
  }

  Future<void> _leaveQrScanPage() async {
    if (await _cancelQrScanning() && mounted) Navigator.of(context).pop();
  }

  Future<void> _reviewScannedWips({required bool canConfirm}) async {
    if (_busy ||
        widget.busy ||
        _qrReviewOpen ||
        _qrLookupsPending > 0 ||
        _scannedWips.isEmpty) {
      return;
    }
    final generation = _qrScanGeneration;
    final scope = _qrScanScope;
    if (!_isCurrentQrScan(generation, scope)) return;
    _updateQrScan(() => _qrReviewOpen = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _PaddonScannedWipsDialog(
          items: _scannedWips.values.toList(growable: false),
          canConfirm: canConfirm,
          onRemove: (batchId) {
            if (!_isCurrentQrScan(generation, scope)) return;
            _updateQrScan(() {
              _scannedWips.remove(batchId);
              _scannedBatchIdsByQr.removeWhere((_, id) => id == batchId);
            });
          },
        ),
      );
      if (confirmed == true && _isCurrentQrScan(generation, scope)) {
        await _confirmScannedWips();
      }
    } finally {
      if (mounted) _updateQrScan(() => _qrReviewOpen = false);
    }
  }

  Widget _buildQrScanSection(BuildContext context, AdminPaddonSnapshot data) {
    final scannedWips = _scannedWips.values.toList(growable: false);
    final canConfirm = data.canManageItems &&
        !_busy &&
        !widget.busy &&
        _qrLookupsPending == 0 &&
        _scannedWips.isNotEmpty;
    return KeyedSubtree(
      key: _qrScannerKey,
      child: Column(
        children: [
          if (data.canManageItems && !_busy && !widget.busy && !_qrReviewOpen)
            ProductionQuickScannerPanel(
              key: const ValueKey('paddon-inline-qr-scanner'),
              statusText: _qrScanStatus.isEmpty
                  ? context.l10n.productionText('worker.paddon.scan.ready')
                  : _qrScanStatus,
              busy: _qrLookupsPending > 0,
              feedback: _qrScanFeedback,
              allowConcurrentDetections: true,
              onCodeDetected: _stageScannedQr,
            ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('paddon-scan-close'),
                  onPressed: _busy || widget.busy
                      ? null
                      : () => unawaited(_cancelQrScanning()),
                  child: Text(
                      context.l10n.productionText('worker.paddon.scan.close')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('paddon-scan-confirm'),
                  onPressed: canConfirm
                      ? () => unawaited(_confirmScannedWips())
                      : null,
                  child: Text(_qrConfirmLabel(context)),
                ),
              ),
            ],
          ),
          if (scannedWips.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                context.l10n.productionText('worker.paddon.scan.list.title'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            M3SegmentSpacedColumn(
              key: const ValueKey('paddon-scanned-wip-list'),
              children: [
                for (var index = 0; index < scannedWips.length; index++)
                  _PaddonWipCard(
                    key: ValueKey(
                        'paddon-scanned-wip-${scannedWips[index].batchId}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index, scannedWips.length),
                    batch: scannedWips[index],
                    selectionIcon: Icons.add_circle_outline_rounded,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PaddonScannedWipsDialog extends StatefulWidget {
  const _PaddonScannedWipsDialog(
      {required this.items, required this.onRemove, required this.canConfirm});

  final List<AdminProgressBatch> items;
  final ValueChanged<String> onRemove;
  final bool canConfirm;

  @override
  State<_PaddonScannedWipsDialog> createState() =>
      _PaddonScannedWipsDialogState();
}

class _PaddonScannedWipsDialogState extends State<_PaddonScannedWipsDialog> {
  late final _items = List<AdminProgressBatch>.of(widget.items);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('paddon-scan-review-dialog'),
      title: Text(context.l10n.productionText('worker.paddon.scan.pending',
          values: {'count': _items.length})),
      content: SizedBox(
        width: 500,
        height: (MediaQuery.sizeOf(context).height * 0.45).clamp(160.0, 400.0),
        child: ListView.separated(
          itemCount: _items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final batch = _items[index];
            return _PaddonWipCard(
              key: ValueKey('paddon-pending-wip-${batch.batchId}'),
              slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index, _items.length),
              batch: batch,
              selectionIcon: Icons.close_rounded,
              onSelect: () {
                widget.onRemove(batch.batchId.trim());
                setState(() => _items.removeAt(index));
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.productionText('worker.action.close')),
        ),
        FilledButton(
          key: const ValueKey('paddon-scan-review-confirm'),
          onPressed: _items.isEmpty || !widget.canConfirm
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text(context.l10n.productionText('worker.paddon.scan.confirm',
              values: {'count': _items.length})),
        ),
      ],
    );
  }
}
