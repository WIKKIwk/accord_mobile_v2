part of 'admin_production_map_orders_screen.dart';

extension _RezkaFramePrint on _ProgressQtyDialogState {
  bool get _canPrintRezkaFrames =>
      _showRezkaFrameInputs &&
      _rezkaReport != null &&
      !_isFreezeRequestSafeStop;
  String _rezkaText(String key, {Map<String, Object> values = const {}}) =>
      context.l10n.productionText('worker.rezka.print.$key', values: values);

  void _restoreRezkaOutputReport(AdminRezkaOutputReport? report) {
    if (report == null) return;
    _rezkaReport = report;
    for (var index = 0; index < _rezkaFrameControllers.length; index++) {
      final saved = report.frameAt(index);
      if (saved == null) continue;
      final frame = _rezkaFrameControllers[index];
      String number(String key) => saved.input[key]?.toString() ?? '';
      frame.meter.text = number('produced_qty');
      frame.kg.text = number('gross_qty');
      frame.bobina.text = number('bobina_kg');
      frame.diameter.text = number('diameter');
      frame.issueNote.text = saved.issueNote;
    }
  }

  Future<void> _reportRezkaFrameIssue(int index) async {
    if (_rezkaPrintBusy ||
        _rezkaSyncRequired ||
        !_canPrintRezkaFrames ||
        _rezkaReport?.frameAt(index) != null) {
      return;
    }
    _updateRezkaPrint(() => _rezkaPrintBusy = true);
    try {
      final formKey = GlobalKey<FormState>();
      var draft = '';
      final note = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_rezkaText('issue')),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.productionText(
                  'worker.progress.qty.rezka_output_roll',
                  values: {
                    'index': index + 1,
                    'frames': widget.rezkaOutputKadrCounts[index]
                  },
                )),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('rezka-frame-issue-note'),
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  decoration:
                      InputDecoration(labelText: _rezkaText('issue_note')),
                  onChanged: (value) => draft = value,
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : _rezkaText('issue_required'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.productionText('worker.action.cancel')),
            ),
            FilledButton(
              key: const ValueKey('rezka-frame-issue-confirm'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(draft.trim());
                }
              },
              child: Text(context.l10n.productionText('worker.action.confirm')),
            ),
          ],
        ),
      );
      if (note == null || !mounted) return;
      final latest = await widget.reloadRezkaOutputReport?.call();
      if (latest == null ||
          latest.cycleId != _rezkaReport!.cycleId ||
          latest.frames.any((slot) => slot.index > _rezkaFrameCount)) {
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      if (!mounted) return;
      _updateRezkaPrint(() => _restoreRezkaOutputReport(latest));
      // Another device may have printed or resolved this card while the note
      // dialog was open. A saved card cannot be converted into an issue.
      if (latest.frameAt(index) != null) return;
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: widget.apparatus,
        orderId: widget.order.map.id,
        action: 'roll_complete',
        rezkaRecordFrameIndex: index + 1,
        rezkaOutputCycle: latest.cycleId,
        rezkaFrames: [_RezkaFrameInput(issueNote: note).toJson()],
        uom: 'm',
      );
      if (!mounted) return;
      final report = result.rezkaOutputReport;
      if (report == null ||
          report.cycleId != latest.cycleId ||
          report.frameAt(index)?.isIssue != true) {
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      _updateRezkaPrint(() {
        _restoreRezkaOutputReport(report);
        _rezkaPrintStatus[index] = _rezkaText('issue_saved');
      });
    } catch (_) {
      AdminRezkaOutputReport? latest;
      try {
        latest = await widget.reloadRezkaOutputReport?.call();
      } catch (_) {}
      if (!mounted) return;
      _updateRezkaPrint(() {
        _rezkaSyncRequired = latest == null ||
            latest.cycleId != _rezkaReport?.cycleId ||
            latest.frames.any((slot) => slot.index > _rezkaFrameCount);
        if (!_rezkaSyncRequired) _restoreRezkaOutputReport(latest);
        final saved = _rezkaReport?.frameAt(index);
        _rezkaPrintStatus[index] = _rezkaText(_rezkaSyncRequired
            ? 'sync_failed'
            : saved == null
                ? 'issue_save_failed'
                : saved.isIssue
                    ? 'issue_saved'
                    : 'saved');
      });
    } finally {
      if (mounted) _updateRezkaPrint(() => _rezkaPrintBusy = false);
    }
  }

  Future<void> _printRezkaFrame(int index) async {
    if (_rezkaPrintBusy ||
        !_canPrintRezkaFrames ||
        _rezkaReport?.frameAt(index)?.isIssue == true) {
      return;
    }
    final frame = _rezkaFrameControllers[index];
    if (_rezkaReport!.frameAt(index) == null &&
        !_rezkaFrameMetricsComplete(frame)) {
      _updateRezkaPrint(
          () => _rezkaPrintStatus[index] = _rezkaText('fill_roll'));
      return;
    }
    _updateRezkaPrint(() => _rezkaPrintBusy = true);
    try {
      final latest = await widget.reloadRezkaOutputReport?.call();
      if (latest == null ||
          latest.cycleId != _rezkaReport!.cycleId ||
          latest.frames.any((slot) => slot.index > _rezkaFrameCount)) {
        _rezkaSyncRequired = true;
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      if (!mounted) return;
      _updateRezkaPrint(() {
        _restoreRezkaOutputReport(latest);
        _rezkaSyncRequired = false;
      });
      if (_rezkaReport?.frameAt(index)?.isIssue == true) return;
      _rezkaPrinter ??=
          await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
      if (!mounted || _rezkaPrinter == null) return;
      var saved = _rezkaReport!.frameAt(index);
      if (saved == null) {
        final result = await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: widget.apparatus,
          orderId: widget.order.map.id,
          action: 'roll_complete',
          rezkaRecordFrameIndex: index + 1,
          rezkaOutputCycle: _rezkaReport!.cycleId,
          rezkaFrames: [
            _RezkaFrameInput(
              meterQty: _parseQty(frame.meter.text),
              kgQty: _parseQty(frame.kg.text),
              bobinaKg: _parseQty(frame.bobina.text),
              diameter: _parseQty(frame.diameter.text),
            ).toJson()
          ],
          uom: 'm',
        );
        if (!mounted) return;
        final report = result.rezkaOutputReport;
        if (report == null ||
            report.cycleId != _rezkaReport!.cycleId ||
            report.frameAt(index) == null) {
          throw const MobileApiException(
              code: 'rezka_output_cycle_conflict', message: '');
        }
        _updateRezkaPrint(() {
          _restoreRezkaOutputReport(report);
          _rezkaPrintStatus[index] = _rezkaText('saved');
        });
        saved = report.frameAt(index)!;
      }
      final printer = _rezkaPrinter!;
      final result = await MobileApi.instance.adminProgressQrReprint(
        qrPayload: saved.qrPayload,
        progressBatchId: saved.batchId,
        driverUrl: printer.driverUrl,
        printer: printer.printer,
        printMode: printer.printMode,
        printTransport: printer.transport,
        printCount: 1,
      );
      if (!result.ok ||
          (printer.transport.isLocal && result.printJob == null)) {
        throw StateError('print_failed');
      }
      if (printer.transport.isLocal) {
        final printed = await PrintService.printRps(
          result.printJob!,
          printerProfile: printer.offlinePrinter,
          bluetoothPrinter: printer.bluetoothPrinter,
          transport: printer.transport,
        );
        if (!printed.ok) throw StateError('print_failed');
      }
      _updateRezkaPrint(() => _rezkaPrintStatus[index] = _rezkaText('printed'));
    } catch (_) {
      // A timed-out save may have committed. Reconcile before unlocking or
      // submitting the group, and always retry the saved QR via reprint.
      AdminRezkaOutputReport? latest;
      try {
        latest = await widget.reloadRezkaOutputReport?.call();
      } catch (_) {}
      if (!mounted) return;
      _updateRezkaPrint(() {
        if (latest != null && latest.cycleId == _rezkaReport?.cycleId) {
          _restoreRezkaOutputReport(latest);
          _rezkaSyncRequired = false;
        } else {
          _rezkaSyncRequired = true;
        }
        _rezkaPrintStatus[index] = _rezkaSyncRequired
            ? _rezkaText('sync_failed')
            : _rezkaReport?.frameAt(index) != null
                ? _rezkaText(_rezkaReport!.frameAt(index)!.isIssue
                    ? 'issue_saved'
                    : 'saved_print_failed')
                : _rezkaText('save_failed');
        _rezkaPrinter = null;
      });
    } finally {
      if (mounted) _updateRezkaPrint(() => _rezkaPrintBusy = false);
    }
  }
}
