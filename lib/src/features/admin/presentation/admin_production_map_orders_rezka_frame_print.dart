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
    _autofillRezkaFrames(report);
  }

  void _autofillRezkaFrames(AdminRezkaOutputReport report) {
    if (!_showRezkaFrameInputs || _rezkaAutofillReference != null) return;
    for (var index = 0; index < _rezkaFrameControllers.length; index++) {
      final saved = report.frameAt(index);
      final source = _rezkaFrameControllers[index];
      if (saved == null || saved.isIssue || !_rezkaFrameMetricsComplete(source)) {
        continue;
      }
      // Keep this saved roll as the reference for the whole output cycle.
      // Subsequent saves/reprints must not replace it or overwrite draft edits.
      _rezkaAutofillReference = _RezkaFrameInput(
        meterQty: _parseQty(source.meter.text),
        kgQty: _parseQty(source.kg.text),
        bobinaKg: _parseQty(source.bobina.text),
        diameter: _parseQty(source.diameter.text),
      );
      for (var next = index + 1; next < _rezkaFrameControllers.length; next++) {
        final target = _rezkaFrameControllers[next];
        if (report.frameAt(next) != null ||
            _rezkaFrameHasAnyMetric(target) ||
            target.issueNote.text.trim().isNotEmpty) {
          continue;
        }
        target.meter.text = source.meter.text;
        target.kg.text = source.kg.text;
        target.bobina.text = source.bobina.text;
        target.diameter.text = source.diameter.text;
      }
      return;
    }
  }

  void _updateRezkaMeterFromWeight(int index, String value) {
    final reference = _rezkaAutofillReference;
    if (reference == null ||
        _rezkaSyncRequired ||
        _rezkaQueuedFrameIndexes.contains(index) ||
        _rezkaReport?.frameAt(index) != null) {
      return;
    }
    final kg = _parseQty(value);
    final meter = kg == null ? null : kg * reference.meterQty! / reference.kgQty!;
    _rezkaFrameControllers[index].meter.text =
        meter != null && meter.isFinite && meter > 0
            ? formatRawQuantity(meter)
            : '';
  }

  Future<void> _reportRezkaFrameIssue(int index) async {
    if (_rezkaPrintBusy ||
        _rezkaPrintQueue.isNotEmpty ||
        _rezkaSyncRequired ||
        !_canPrintRezkaFrames ||
        _rezkaReport?.frameAt(index) != null) {
      return;
    }
    _updateRezkaPrint(() {
      _rezkaPrintBusy = true;
      _rezkaIssueBusy = true;
    });
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
      if (mounted) {
        _updateRezkaPrint(() {
          _rezkaPrintBusy = false;
          _rezkaIssueBusy = false;
        });
      }
    }
  }

  String? _rezkaFramePrintStatus(int index) {
    final queuedIndex = _rezkaPrintQueue.indexWhere(
      (request) => request.index == index,
    );
    if (queuedIndex < 0) return _rezkaPrintStatus[index];
    if (_rezkaPrintQueuePaused && queuedIndex == 0) {
      return _rezkaPrintStatus[index];
    }
    if (_rezkaPrintQueueProcessing && queuedIndex == 0) {
      return _rezkaText('printing');
    }
    final position = queuedIndex + 1 - (_rezkaPrintQueueProcessing ? 1 : 0);
    return _rezkaText('queued', values: {'position': position});
  }

  bool _rezkaSavedFrameMatchesRequest(
    AdminRecordedRezkaFrame saved,
    _RezkaFrameInput requested,
  ) {
    double? savedValue(String key) =>
        _parseQty(saved.input[key]?.toString() ?? '');
    return savedValue('produced_qty') == requested.meterQty &&
        savedValue('gross_qty') == requested.kgQty &&
        savedValue('bobina_kg') == requested.bobinaKg &&
        savedValue('diameter') == requested.diameter;
  }

  void _printRezkaFrame(int index) {
    if (!_canPrintRezkaFrames || _rezkaSyncRequired || _rezkaIssueBusy) {
      return;
    }
    if (_rezkaPrintQueuePaused) {
      if (_rezkaPrintQueue.isEmpty ||
          _rezkaPrintQueue.first.index != index ||
          _rezkaPrintBusy) {
        return;
      }
      _updateRezkaPrint(() => _rezkaPrintQueuePaused = false);
      unawaited(_drainRezkaPrintQueue());
      return;
    }
    if (_rezkaPrintBusy && !_rezkaPrintQueueProcessing) return;
    if (_rezkaQueuedFrameIndexes.contains(index) ||
        _rezkaReport?.frameAt(index)?.isIssue == true) {
      return;
    }
    final frame = _rezkaFrameControllers[index];
    final saved = _rezkaReport!.frameAt(index);
    _RezkaFrameInput? input;
    if (saved == null) {
      if (!_rezkaFrameMetricsComplete(frame)) {
        _updateRezkaPrint(
            () => _rezkaPrintStatus[index] = _rezkaText('fill_roll'));
        return;
      }
      input = _RezkaFrameInput(
        meterQty: _parseQty(frame.meter.text),
        kgQty: _parseQty(frame.kg.text),
        bobinaKg: _parseQty(frame.bobina.text),
        diameter: _parseQty(frame.diameter.text),
      );
    }
    _updateRezkaPrint(() {
      _rezkaPrintQueue.add(_RezkaPrintRequest(index: index, input: input));
      _rezkaQueuedFrameIndexes.add(index);
      _rezkaPrintStatus[index] = _rezkaText('queued', values: {
        'position': _rezkaPrintQueue.length,
      });
    });
    unawaited(_drainRezkaPrintQueue());
  }

  Future<void> _drainRezkaPrintQueue() async {
    if (!mounted ||
        _rezkaPrintQueueProcessing ||
        _rezkaPrintQueuePaused ||
        _rezkaPrintBusy) {
      return;
    }
    _rezkaPrintQueueProcessing = true;
    _updateRezkaPrint(() => _rezkaPrintBusy = true);
    try {
      while (
          mounted && _rezkaPrintQueue.isNotEmpty && !_rezkaPrintQueuePaused) {
        final request = _rezkaPrintQueue.first;
        _updateRezkaPrint(
            () => _rezkaPrintStatus[request.index] = _rezkaText('printing'));
        try {
          await _performRezkaFramePrint(request);
        } catch (_) {
          if (!mounted) return;
          _updateRezkaPrint(() => _rezkaPrintQueuePaused = true);
          break;
        }
        if (!mounted) return;
        _updateRezkaPrint(() {
          _rezkaPrintQueue.removeAt(0);
          _rezkaQueuedFrameIndexes.remove(request.index);
        });
      }
    } finally {
      _rezkaPrintQueueProcessing = false;
      if (mounted) _updateRezkaPrint(() => _rezkaPrintBusy = false);
    }
  }

  Future<void> _performRezkaFramePrint(_RezkaPrintRequest request) async {
    final index = request.index;
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
      if (_rezkaReport?.frameAt(index)?.isIssue == true) {
        _rezkaSyncRequired = true;
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      _rezkaPrinter ??=
          await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
      if (!mounted) return;
      if (_rezkaPrinter == null) throw const _RezkaPrinterNotSelected();
      var saved = _rezkaReport!.frameAt(index);
      if (saved != null &&
          request.input != null &&
          !_rezkaSavedFrameMatchesRequest(saved, request.input!)) {
        throw const _RezkaFrameInputConflict();
      }
      if (saved == null) {
        final input = request.input;
        if (input == null) {
          throw const MobileApiException(
              code: 'rezka_output_cycle_conflict', message: '');
        }
        final result = await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: widget.apparatus,
          orderId: widget.order.map.id,
          action: 'roll_complete',
          rezkaRecordFrameIndex: index + 1,
          rezkaOutputCycle: _rezkaReport!.cycleId,
          rezkaFrames: [input.toJson()],
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
        final confirmed = await widget.reloadRezkaOutputReport?.call();
        if (confirmed == null ||
            confirmed.cycleId != _rezkaReport!.cycleId ||
            confirmed.frameAt(index) == null) {
          _rezkaSyncRequired = true;
          throw const MobileApiException(
              code: 'rezka_output_cycle_conflict', message: '');
        }
        _updateRezkaPrint(() => _restoreRezkaOutputReport(confirmed));
        saved = confirmed.frameAt(index)!;
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
    } catch (error) {
      // A timed-out save may have committed. Reconcile before pausing the
      // queue so retry always uses the saved QR rather than creating a new one.
      AdminRezkaOutputReport? latest;
      try {
        latest = await widget.reloadRezkaOutputReport?.call();
      } catch (_) {}
      if (!mounted) return;
      _updateRezkaPrint(() {
        if (error is! _RezkaFrameInputConflict &&
            latest != null &&
            latest.cycleId == _rezkaReport?.cycleId &&
            !latest.frames.any((slot) => slot.index > _rezkaFrameCount)) {
          _restoreRezkaOutputReport(latest);
          _rezkaSyncRequired = false;
        } else {
          _rezkaSyncRequired = true;
        }
        _rezkaPrintStatus[index] = _rezkaSyncRequired
            ? _rezkaText('sync_failed')
            : error is _RezkaPrinterNotSelected
                ? _rezkaText('printer_not_selected')
                : _rezkaReport?.frameAt(index) != null
                    ? _rezkaText(_rezkaReport!.frameAt(index)!.isIssue
                        ? 'issue_saved'
                        : 'saved_print_failed')
                    : _rezkaText(error is MobileApiException &&
                            const {
                              'paddon_not_found',
                              'paddon_invalid_input',
                              'paddon_item_already_assigned'
                            }.contains(error.code)
                        ? 'paddon_failed'
                        : 'save_failed');
        _rezkaPrinter = null;
      });
      rethrow;
    }
  }
}

class _RezkaPrinterNotSelected implements Exception {
  const _RezkaPrinterNotSelected();
}

class _RezkaFrameInputConflict implements Exception {
  const _RezkaFrameInputConflict();
}
