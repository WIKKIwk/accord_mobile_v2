part of 'admin_production_map_orders_screen.dart';

extension _IntegratedLaminationAstatka on _ReadOnlyOrderDetailSheetState {
  // Both label switches use this same report and remainder workflow.
  Future<_ProgressActionOutcome?> _runIntegratedLaminationAstatka({
    bool completeStage = false,
    bool fullCompletionReportRequired = false,
  }) async {
    if (_queueActionBusy) return _ProgressActionOutcome.failed;
    if (widget.beginPrintPreflight?.call() == false)
      return _ProgressActionOutcome.failed;
    _ownsPrintPreflight = true;
    final station = widget.apparatus?.id.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    final actorRef = AppSession.instance.profile?.ref ?? '';
    final requestScope = currentSessionReadScope();
    bool contextCurrent() =>
        mounted &&
        requestScope == currentSessionReadScope() &&
        _materialContextIsCurrent(orderId, station);
    final pendingKey = completeStage
        ? 'lamination_complete_pending:$actorRef:$station:$orderId'
        : 'lamination_astatka_pending:$actorRef:$station:$orderId';
    _ProgressPrinterOption? printer;
    var committed = false;
    var atomicPostSubmitted = false;
    _applyStateChange(() => _actionInFlight = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedJson = preferences.getString(pendingKey);
      Map<String, dynamic>? request = savedJson == null
          ? null
          : (jsonDecode(savedJson) as Map).cast<String, dynamic>();
      final snapshot = await MobileApi.instance.adminLaminationAstatkaSnapshot(
        apparatus: station,
        orderId: orderId,
        requestId: request?['request_id']?.toString() ?? '',
      );
      if (!contextCurrent()) return _ProgressActionOutcome.cancelled;
      AdminLaminationAstatkaResult? result = snapshot.requestResult;
      if (result != null) {
        committed = true;
        await preferences.remove(pendingKey);
      } else if (!snapshot.supportsRemainderWeights) {
        _showSheetNotice(context.l10n
            .productionText('worker.lamination_label.backend_required'));
        return _ProgressActionOutcome.failed;
      } else if (request != null) {
        final retry = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.productionText(completeStage
                ? 'worker.progress.qty.title.complete'
                : 'worker.laminatsiya.astatka.title')),
            content: Text(context.l10n.productionText(completeStage
                ? 'worker.lamination_complete.pending'
                : 'worker.lamination_astatka.pending')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child:
                    Text(context.l10n.productionText('worker.action.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.l10n
                    .productionText('worker.layer_remainder.retry')),
              ),
            ],
          ),
        );
        if (!contextCurrent() || retry != true)
          return _ProgressActionOutcome.cancelled;
      } else if ((completeStage || snapshot.sessionStatus == 'active') &&
          snapshot.sources.isEmpty &&
          !snapshot.allowEmptySources) {
        _showSheetNotice(context.l10n
            .productionText('worker.lamination_astatka.sources_missing'));
        return _ProgressActionOutcome.failed;
      } else if ((completeStage && snapshot.sessionStatus == 'completed') ||
          !const {'active', 'paused', 'roll_detached', 'completed'}
              .contains(snapshot.sessionStatus) ||
          (const {'paused', 'roll_detached'}.contains(snapshot.sessionStatus) &&
              snapshot.sources.isEmpty &&
              !snapshot.allowEmptySources)) {
        // Historical labels remain available after the stage is completed.
        await _showLaminationAstatkaLabels(
            resumeGuidance: const {'paused', 'roll_detached'}
                .contains(snapshot.sessionStatus));
        return _ProgressActionOutcome.cancelled;
      } else {
        final input = await _showProgressQtyDialogForApparatus(
          context,
          action: completeStage ? 'complete' : 'astatka',
          apparatus: widget.apparatus,
          order: widget.order,
          apparatusCatalog: widget.apparatusCatalog,
          astatkaReport: !completeStage,
          fullCompletionReportRequired: fullCompletionReportRequired,
          laminationAstatka: snapshot,
          progressDriverUrlPicker: widget.progressDriverUrlPicker,
        );
        if (!contextCurrent() || input == null)
          return _ProgressActionOutcome.cancelled;
        if (completeStage && input.isIssue) {
          // Keep the established Complete -> issue/freeze flow. It creates no
          // output or layer return when the worker reports a problem.
          widget.endPrintPreflight?.call();
          _ownsPrintPreflight = false;
          _applyStateChange(() => _actionInFlight = false);
          final frozen = await _runQueueAction(
            'freeze',
            freezeWithIssue: true,
            issueNote: input.description,
          );
          return frozen
              ? _ProgressActionOutcome.completed
              : _ProgressActionOutcome.failed;
        }
        request = {
          if (completeStage) ...{
            'action': 'complete',
            'full_completion_report_required':
                input.fullCompletionReportRequired,
          },
          'apparatus': station,
          'order_id': orderId,
          'session_id': snapshot.sessionId,
          'request_id':
              '${completeStage ? 'complete' : 'astatka'}-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
          'lamination_print_leftover_rolls': input.laminationPrintLeftoverRolls,
          'lamination_film_leftover_rolls': input.laminationFilmLeftoverRolls,
          'total_waste':
              completeStage ? input.totalWaste ?? 0 : input.totalWaste,
          if (input.finishedGoodsMeter != null)
            'finished_goods_meter': input.finishedGoodsMeter,
          if (input.finishedGoodsKg != null)
            'finished_goods_kg': input.finishedGoodsKg,
          if (input.bobinaKg != null) 'bobina_kg': input.bobinaKg,
          'description': input.description,
          'layer_remainder_weights': {
            'wip_net_kg': input.laminationPrintLeftoverRolls,
            'film_net_kg': input.laminationFilmLeftoverRolls,
            if (snapshot.wipInputRoll case final source?)
              'wip_source_id': source.sourceId,
            if (snapshot.filmInputRoll case final source?)
              'film_source_id': source.sourceId,
            'expected_sources': [
              for (final source in snapshot.sources)
                {
                  'source_kind': source.sourceKind,
                  'source_id': source.sourceId,
                  'expected_revision': source.revision,
                },
            ],
          },
          // Save first. Printer selection and hardware writes happen only
          // after the authoritative receipt supplies the enabled label jobs.
          'print_transport': 'offline',
          'print_count': 1,
        };
        // A lost response must never cause another output or residual to be made.
        final persisted =
            await preferences.setString(pendingKey, jsonEncode(request));
        if (!persisted) throw StateError('astatka_pending_not_saved');
      }
      if (!contextCurrent())
        return committed
            ? _ProgressActionOutcome.completed
            : _ProgressActionOutcome.cancelled;
      if (result == null) {
        // Replay keeps the exact saved business request. The response's labels
        // are reprinted explicitly when the original local printer is unknown.
        atomicPostSubmitted = true;
        result = await MobileApi.instance.adminSubmitLaminationAstatka({
          ...request!,
          // Older saved drafts may still name a remote printer. Preserve their
          // business identity while preparing labels for the post-save choice.
          'print_transport': 'offline',
          'print_count': 1,
        });
        committed = true;
        await preferences.remove(pendingKey);
      }
      if (!contextCurrent()) return _ProgressActionOutcome.completed;
      final hasOutput = result.progressBatches.isNotEmpty;
      _applyStateChange(() {
        _actionInFlight = false;
        if (hasOutput) _workerOutputRevision++;
        _queueActionControl = null;
        _scannedMaterialBarcodes.clear();
        _startInputProgressBatch = null;
        _startInputOpeningWipBatch = null;
      });
      unawaited(_refreshQueueActionControlAfterWrite());
      var printFailed = false;
      final expected = {
        for (final batch in result.progressBatches) batch.qrPayload,
        for (final remainder in result.remainders)
          if (remainder.remainingNetKg > 0 &&
              remainder.qrPayload.isNotEmpty &&
              result.labelSettings.prints(remainder.sourceKind))
            remainder.qrPayload,
      };
      var printPending = expected.isNotEmpty;
      if (expected.isNotEmpty && result.prints.isNotEmpty) {
        printer =
            await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
        if (!contextCurrent()) return _ProgressActionOutcome.completed;
        if (printer != null) {
          printPending = false;
          final remainders = {
            for (final r in result.remainders) r.qrPayload: r
          };
          final batches = {
            for (final b in result.progressBatches) b.qrPayload: b
          };
          final printed = <String>{};
          for (final rawPrint in result.prints) {
            try {
              final qr = rawPrint['qr_payload']?.toString() ?? '';
              if (!expected.contains(qr) ||
                  !printed.add(qr) ||
                  rawPrint['ok'] != true) {
                throw StateError('astatka_print_identity_invalid');
              }
              if (printer.transport.isLocal) {
                await _printAstatkaLocalJob(
                    UsbRpsPrintRequest.fromPrintJson(rawPrint), qr, printer);
              } else if (remainders[qr] case final remainder?) {
                final prepared =
                    await MobileApi.instance.adminLayerRemainderReprint(
                  apparatus: station,
                  orderId: orderId,
                  operationId: remainder.operationId,
                  driverUrl: printer.driverUrl,
                  printer: printer.printer,
                  printMode: printer.printMode,
                  printTransport: printer.transport,
                );
                if (!prepared.printOk || prepared.remainder.qrPayload != qr)
                  throw StateError('print_failed');
              } else if (batches[qr] case final batch?) {
                final prepared =
                    await MobileApi.instance.adminProgressQrReprint(
                  qrPayload: qr,
                  progressBatchId: batch.batchId,
                  driverUrl: printer.driverUrl,
                  printer: printer.printer,
                  printMode: printer.printMode,
                  printTransport: printer.transport,
                );
                if (!prepared.ok) throw StateError('print_failed');
              } else {
                throw StateError('print_identity_mismatch');
              }
            } catch (_) {
              printFailed = true;
            }
          }
          if (printed.length != expected.length) printFailed = true;
        }
      }
      if (!contextCurrent()) return _ProgressActionOutcome.completed;
      await _showLaminationAstatkaLabels(
          result: result, printFailed: printFailed, printPending: printPending);
      return _ProgressActionOutcome.completed;
    } catch (error) {
      if (!committed &&
          atomicPostSubmitted &&
          contextCurrent() &&
          error is MobileApiException &&
          const {400, 403, 404, 409, 422}.contains(error.statusCode)) {
        // Only a definitive rejection of this POST invalidates the draft.
        // Failed reconciliation reads leave its exact request ID intact.
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove(pendingKey);
      }
      if (mounted) {
        _showSheetNotice(committed
            ? context.l10n.productionText('worker.layer_remainder.print_failed')
            : _sheetActionErrorText(error));
      }
      return committed
          ? _ProgressActionOutcome.completed
          : _ProgressActionOutcome.failed;
    } finally {
      if (_ownsPrintPreflight) widget.endPrintPreflight?.call();
      _ownsPrintPreflight = false;
      if (mounted) _applyStateChange(() => _actionInFlight = false);
    }
  }

  Future<void> _showLaminationAstatkaLabels({
    AdminLaminationAstatkaResult? result,
    bool printFailed = false,
    bool printPending = false,
    bool resumeGuidance = false,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => LaminationLayerRemainderSheet(
          apparatus: widget.apparatus?.id ?? '',
          orderId: widget.order.map.id,
          progressDriverUrlPicker: widget.progressDriverUrlPicker,
          initialResult: result,
          printFailed: printFailed,
          printPending: printPending,
          resumeGuidance: resumeGuidance,
        ),
      );
}

Future<void> _printAstatkaLocalJob(
    UsbRpsPrintRequest? job, String qr, _ProgressPrinterOption printer) async {
  if (!printer.transport.isLocal) return;
  if (job == null || job.epc != qr) throw StateError('print_identity_mismatch');
  final printed = await PrintService.printRps(
    job,
    printerProfile: printer.offlinePrinter,
    bluetoothPrinter: printer.bluetoothPrinter,
    transport: printer.transport,
  );
  if (!printed.ok) throw StateError('print_failed');
}

/// Astatka's saved labels and history. Recording happens in the existing report.
class LaminationLayerRemainderSheet extends StatefulWidget {
  const LaminationLayerRemainderSheet({
    super.key,
    required this.apparatus,
    required this.orderId,
    this.progressDriverUrlPicker,
    this.initialResult,
    this.printFailed = false,
    this.printPending = false,
    this.resumeGuidance = false,
  });

  final String apparatus;
  final String orderId;
  final Future<String?> Function(BuildContext)? progressDriverUrlPicker;
  final AdminLaminationAstatkaResult? initialResult;
  final bool printFailed;
  final bool printPending;
  final bool resumeGuidance;

  @override
  State<LaminationLayerRemainderSheet> createState() =>
      _LaminationLayerRemainderSheetState();
}

class _LaminationLayerRemainderSheetState
    extends State<LaminationLayerRemainderSheet> {
  List<AdminLayerRemainder> _remainders = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _status;

  String _text(String key, {Map<String, String> args = const {}}) =>
      context.l10n.productionText('worker.layer_remainder.$key', values: args);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final snapshot = await MobileApi.instance.adminLayerRemainders(
          apparatus: widget.apparatus, orderId: widget.orderId);
      if (!mounted) return;
      setState(() {
        _remainders = snapshot.remainders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _remainders = widget.initialResult?.remainders ?? const [];
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  String _errorText(Object error) => error is MobileApiException
      ? context.l10n.productionErrorMessage(error.code, fallback: error.message)
      : _text('failed');

  Future<void> _reprint(
      {AdminLayerRemainder? remainder, AdminProgressBatch? batch}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final printer =
          await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
      if (!mounted || printer == null) return;
      if (remainder != null) {
        final prepared = await MobileApi.instance.adminLayerRemainderReprint(
          apparatus: widget.apparatus,
          orderId: widget.orderId,
          operationId: remainder.operationId,
          driverUrl: printer.driverUrl,
          printer: printer.printer,
          printMode: printer.printMode,
          printTransport: printer.transport,
        );
        if (!prepared.printOk) throw StateError('print_failed');
        await _printAstatkaLocalJob(
            prepared.printJob, remainder.qrPayload, printer);
      } else if (batch != null) {
        final prepared = await MobileApi.instance.adminProgressQrReprint(
          qrPayload: batch.qrPayload,
          progressBatchId: batch.batchId,
          driverUrl: printer.driverUrl,
          printer: printer.printer,
          printMode: printer.printMode,
          printTransport: printer.transport,
        );
        if (!prepared.ok) throw StateError('print_failed');
        await _printAstatkaLocalJob(
            prepared.printJob, batch.qrPayload, printer);
      }
      if (mounted) setState(() => _status = _text('printed'));
    } catch (_) {
      if (mounted) setState(() => _error = _text('print_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  context.l10n.productionText(
                      widget.initialResult?.action == 'complete'
                          ? 'worker.progress.qty.title.complete'
                          : 'worker.laminatsiya.astatka.title'),
                  style: theme.textTheme.titleLarge),
              if (widget.initialResult != null) ...[
                const SizedBox(height: 8),
                Text(context.l10n
                    .productionText(widget.initialResult?.action == 'complete'
                        ? 'worker.lamination_complete.saved'
                        : widget.initialResult?.sessionStatus == 'completed'
                            ? 'worker.lamination_astatka.saved_completed'
                            : 'worker.lamination_astatka.saved')),
              ],
              if (widget.resumeGuidance)
                Text(context.l10n
                    .productionText('worker.lamination_astatka.resume_scan')),
              if (widget.printPending) Text(_text('print_pending')),
              if (widget.printFailed)
                Text(_text('print_failed'),
                    style: TextStyle(color: theme.colorScheme.error)),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              if (_status != null) Text(_status!),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          for (final batch
                              in widget.initialResult?.progressBatches ??
                                  const <AdminProgressBatch>[])
                            ListTile(
                              title: Text(context.l10n.productionText(
                                  'worker.progress.qty.finished_goods')),
                              subtitle: Text(
                                  '${formatQuantity(batch.finishedGoodsKg ?? batch.producedQty)} kg · ${formatQuantity(batch.finishedGoodsMeter ?? 0)} m\n${batch.qrPayload}'),
                              trailing: const Icon(Icons.print_outlined),
                              onTap:
                                  _busy ? null : () => _reprint(batch: batch),
                            ),
                          Text(_text('history'),
                              style: theme.textTheme.titleMedium),
                          if (_remainders.isEmpty)
                            Text(context.l10n.productionText(
                                'worker.lamination_astatka.history_empty')),
                          for (final remainder in _remainders)
                            Card(
                              child: ListTile(
                                title: Text(remainder.itemName.isEmpty
                                    ? _text(
                                        remainder.sourceKind == 'raw_material'
                                            ? 'raw_material'
                                            : 'printed_roll')
                                    : remainder.itemName),
                                subtitle: Text([
                                  '${formatQuantity(remainder.remainingNetKg)} kg · ≈ ${formatQuantity(remainder.remainingMeter)} m',
                                  if (remainder.producerName.isNotEmpty)
                                    _text('producer',
                                        args: {'name': remainder.producerName}),
                                  if (remainder.recordedByName.isNotEmpty)
                                    _text('recorded_by', args: {
                                      'name': remainder.recordedByName
                                    }),
                                  remainder.qrPayload,
                                ].join('\n')),
                                trailing: remainder.remainingNetKg > 0 &&
                                        remainder.qrPayload.isNotEmpty
                                    ? const Icon(Icons.print_outlined)
                                    : null,
                                onTap: _busy ||
                                        remainder.remainingNetKg <= 0 ||
                                        remainder.qrPayload.isEmpty
                                    ? null
                                    : () => _reprint(remainder: remainder),
                              ),
                            ),
                        ],
                      ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () =>
                        Navigator.of(context).pop(widget.initialResult != null),
                child: Text(_text('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
