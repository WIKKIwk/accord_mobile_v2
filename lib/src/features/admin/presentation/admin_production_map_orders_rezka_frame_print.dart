part of 'admin_production_map_orders_screen.dart';

extension _RezkaFramePrint on _ProgressQtyDialogState {
  String _rezkaLayoutLabel(int index) {
    final outputs = _rezkaReport?.layoutOutputs ?? const <Map<String, dynamic>>[];
    if (index < 0 || index >= outputs.length) return '';
    final output = outputs[index];
    final width = output['width_mm'];
    return '${output['name'] ?? ''} · ${width is num ? formatRawQuantity(width.toDouble()) : ''} mm';
  }

  bool get _canPrintRezkaFrames =>
      _showRezkaFrameInputs &&
      _rezkaReport != null &&
      !_isFreezeRequestSafeStop;
  String _rezkaText(String key, {Map<String, Object> values = const {}}) =>
      context.l10n.productionText('worker.rezka.print.$key', values: values);

  void _restoreRezkaOutputReport(AdminRezkaOutputReport? report) {
    if (report == null) return;
    if (report.atomicSaveEpoch.isNotEmpty) {
      _rezkaAtomicSaveEpoch = report.atomicSaveEpoch;
    }
    if (report.peremotkaSupported || report.atomicSaveEpoch.isNotEmpty) {
      _rezkaPeremotkaSupported = report.peremotkaSupported;
    }
    _rezkaBobinaMode = report.includeBobinaInNet ?? _rezkaBobinaMode;
    _rezkaReport = report;
    _refreshRezkaReference(report);
    widget.onRezkaOutputReportChanged?.call(report);
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
    if (widget.order.map.products.isNotEmpty) return;
    if (!_showRezkaFrameInputs) return;
    // Corrections refresh the reference without replacing draft measurements.
    if (_rezkaAutofillReference != null) {
      final saved = _rezkaReferenceFrameIndex == null
          ? null
          : report.frameAt(_rezkaReferenceFrameIndex!);
      if (saved != null && !saved.isIssue && !saved.isPeremotka) {
        _rezkaAutofillReference = _rezkaInputFromSaved(saved);
      }
      return;
    }
    for (var index = 0; index < _rezkaFrameControllers.length; index++) {
      if (_rezkaReferenceFrameIndex != null &&
          index != _rezkaReferenceFrameIndex) {
        continue;
      }
      final saved = report.frameAt(index);
      final source = _rezkaFrameControllers[index];
      if (saved == null ||
          saved.isIssue ||
          saved.isPeremotka ||
          !_rezkaFrameMetricsComplete(source)) {
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
        target.bobina.text = _rezkaNetIncludesBobina ? '' : source.bobina.text;
        target.diameter.text = source.diameter.text;
      }
      return;
    }
  }

  void _updateRezkaMeterFromWeight(int index, String value) {
    if (widget.order.map.products.isNotEmpty) return;
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

  Future<void> _showRezkaFrameIssueActions(int index) async {
    if (!_rezkaPeremotkaSupported) {
      await _reportRezkaFrameIssue(index);
      return;
    }
    final peremotka = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(_rezkaText('issue')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_rezkaText('issue_note')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_rezkaText('peremotka')),
          ),
        ],
      ),
    );
    if (!mounted || peremotka == null) return;
    if (peremotka) {
      await _confirmRezkaPeremotka(index);
    } else {
      await _reportRezkaFrameIssue(index);
    }
  }

  Future<void> _confirmRezkaPeremotka(int index) async {
    if (!_rezkaPeremotkaSupported ||
        _rezkaReport?.frameAt(index) != null ||
        _rezkaQueuedFrameIndexes.contains(index) ||
        _rezkaSyncRequired) {
      return;
    }
    final frame = _rezkaFrameControllers[index];
    if (!_rezkaFrameMetricsComplete(frame)) {
      _updateRezkaPrint(() => _rezkaPrintStatus[index] =
          _rezkaText(_rezkaNetIncludesBobina ? 'fill_roll_with_bobina' : 'fill_roll'));
      return;
    }
    final formKey = GlobalKey<FormState>();
    var draft = '';
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_rezkaText('peremotka_confirm', values: {'index': index + 1})),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const ValueKey('rezka-peremotka-reason'),
            autofocus: true,
            maxLength: 250,
            maxLines: 3,
            decoration: InputDecoration(labelText: _rezkaText('issue_note')),
            onChanged: (value) => draft = value,
            validator: (value) => value?.trim().isNotEmpty == true &&
                    value!.trim().runes.length <= 250
                ? null
                : _rezkaText('peremotka_reason_required'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.productionText('worker.action.cancel')),
          ),
          FilledButton(
            key: const ValueKey('rezka-peremotka-confirm'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(draft.trim());
              }
            },
            child: Text(_rezkaText('peremotka_save_print')),
          ),
        ],
      ),
    );
    if (mounted && reason != null) {
      _printRezkaFrame(index, peremotkaReason: reason);
    }
  }

  Future<void> _reportRezkaFrameIssue(int index) async {
    if (_rezkaPrintBusy ||
        _rezkaConfirmationBusy ||
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
        savedValue('diameter') == requested.diameter &&
        saved.peremotkaReason == requested.peremotkaReason;
  }

  void _printRezkaFrame(int index, {String peremotkaReason = ''}) {
    if (peremotkaReason.isNotEmpty &&
        (!_rezkaPeremotkaSupported ||
            _rezkaPrintQueuePaused ||
            _rezkaReport?.frameAt(index) != null)) {
      return;
    }
    if (!_canPrintRezkaFrames ||
        _rezkaSyncRequired ||
        _rezkaIssueBusy ||
        _rezkaConfirmationBusy) {
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
        _updateRezkaPrint(() => _rezkaPrintStatus[index] =
            _rezkaBobinaTooLarge(frame)
                ? context.l10n
                    .productionText('worker.progress.qty.bobina_exceeds_gross')
                : _rezkaText(_rezkaNetIncludesBobina
                    ? 'fill_roll_with_bobina'
                    : 'fill_roll'));
        return;
      }
      input = _RezkaFrameInput(
        meterQty: _parseQty(frame.meter.text),
        kgQty: _parseQty(frame.kg.text),
        bobinaKg: _rezkaNetIncludesBobina ? null : _parseQty(frame.bobina.text),
        diameter: _parseQty(frame.diameter.text),
        peremotkaReason: peremotkaReason,
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
          _updateRezkaPrint(
            () => _rezkaPrintQueuePaused = _rezkaPrintQueue.isNotEmpty,
          );
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
    if (mounted && _canAutoConfirmRezkaPause) {
      await _confirmProgressQty();
    }
  }

  bool get _canAutoConfirmRezkaPause {
    if (widget.action != 'pause' ||
        !_canPrintRezkaFrames ||
        _progressQtyBusy ||
        _rezkaSyncRequired ||
        _rezkaPrintQueuePaused ||
        _rezkaPrintQueue.isNotEmpty) {
      return false;
    }
    for (var index = 0; index < _rezkaFrameCount; index++) {
      final saved = _rezkaReport?.frameAt(index);
      if (saved == null ||
          saved.isIssue ||
          !_rezkaPrintedFrameIndexes.contains(index)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _performRezkaFramePrint(_RezkaPrintRequest request) async {
    final index = request.index;
    if (_progressReadScope != currentSessionReadScope()) {
      throw const MobileApiException(
        code: 'rezka_output_cycle_conflict',
        message: '',
      );
    }
    try {
      // Previously saved cards still need a fresh read before a reprint.
      // New cards can use the write as their freshness check once the
      // scoped report has confirmed the server supports it.
      final canSaveDirectly = _rezkaAtomicSaveEpoch.isNotEmpty &&
          request.input != null &&
          _rezkaReport?.frameAt(index) == null;
      final latest = canSaveDirectly
          ? _rezkaReport
          : await widget.reloadRezkaOutputReport?.call();
      if (latest == null ||
          latest.cycleId != _rezkaReport!.cycleId ||
          latest.frames.any((slot) => slot.index > _rezkaFrameCount)) {
        _rezkaSyncRequired = true;
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      if (!mounted) return;
      _updateRezkaPrint(() {
        if (!canSaveDirectly) _rezkaAtomicSaveEpoch = latest.atomicSaveEpoch;
        _restoreRezkaOutputReport(latest);
        _rezkaSyncRequired = false;
      });
      if (_rezkaReport?.frameAt(index)?.isIssue == true) {
        _rezkaSyncRequired = true;
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      final holdForPeremotka = request.input?.peremotkaReason.isNotEmpty == true;
      if (holdForPeremotka && !_rezkaPeremotkaSupported) {
        throw const _RezkaFrameInputConflict();
      }
      if (_rezkaReport?.frameAt(index) == null &&
          request.input != null &&
          !holdForPeremotka &&
          !await _confirmFreshRezkaFrame(request)) {
        _updateRezkaPrint(() => _rezkaPrintStatus.remove(index));
        return;
      }
      if (!mounted) return;
      if (!holdForPeremotka) {
        _rezkaPrinter ??=
            await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
        if (!mounted) return;
        if (_rezkaPrinter == null) throw const _RezkaPrinterNotSelected();
      }
      if (_progressReadScope != currentSessionReadScope()) return;
      final savePrinter = _rezkaPrinter;
      final printCount = _duplicateRezkaLabelsForStage ? 2 : 1;
      UsbRpsPrintRequest? committedPrintJob;
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
          rezkaExpectedEpoch: _rezkaAtomicSaveEpoch,
          rezkaExpectedKadrCounts: _rezkaAtomicSaveEpoch.isEmpty
              ? const []
              : widget.rezkaOutputKadrCounts,
          rezkaFrames: [input.toJson()],
          uom: 'm',
          driverUrl: savePrinter?.driverUrl ?? '',
          printer: savePrinter?.printer ?? '',
          printMode: savePrinter?.printMode ?? '',
          printTransport: savePrinter?.transport ?? PrintTransport.wifi,
        );
        if (!mounted || _progressReadScope != currentSessionReadScope()) return;
        final report = result.rezkaOutputReport;
        if (report == null ||
            report.cycleId != _rezkaReport!.cycleId ||
            report.frames.any((slot) => slot.index > _rezkaFrameCount) ||
            report.frameAt(index) == null ||
            report.frameAt(index)!.isIssue) {
          throw const MobileApiException(
              code: 'rezka_output_cycle_conflict', message: '');
        }
        saved = report.frameAt(index)!;
        if (!_rezkaSavedFrameMatchesRequest(saved, input)) {
          throw const _RezkaFrameInputConflict();
        }
        _updateRezkaPrint(() {
          _restoreRezkaOutputReport(report);
          final payload = result.progressBatch?.payloadJson;
          if (payload?['rezka_output_kind'] == 'frame') {
            _rezkaBobinaMode = payload?['include_bobina_in_net'] == true;
          }
          _rezkaPrintStatus[index] = _rezkaText('saved');
        });
        if (_rezkaAtomicSaveEpoch.isNotEmpty && result.progressBatch == null) {
          // Another writer already saved this card. A deliberate reprint
          // can use its QR after the operator sees the recovered state.
          throw StateError('rezka_card_already_saved');
        }
        // The save response is authoritative for this cycle and slot. Local
        // labels can be prepared by that request without another API roundtrip.
        final prepared = result.printJob;
        if (savePrinter?.transport.isLocal == true &&
            prepared != null &&
            prepared.epc == saved.qrPayload &&
            prepared.isProgressLabel &&
            prepared.printCount == printCount) {
          committedPrintJob = prepared;
        }
      }
      // A held roll is recorded even when a printer still needs to be selected.
      _rezkaPrinter ??=
          await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
      if (!mounted || _progressReadScope != currentSessionReadScope()) return;
      final printer = _rezkaPrinter;
      if (printer == null) throw const _RezkaPrinterNotSelected();
      if (committedPrintJob == null) {
        // Reprints prepare the already committed QR.
        final result = await MobileApi.instance.adminProgressQrReprint(
          qrPayload: saved.qrPayload,
          progressBatchId: saved.batchId,
          driverUrl: printer.driverUrl,
          printer: printer.printer,
          printMode: printer.printMode,
          printTransport: printer.transport,
          printCount: printCount,
          automaticRezkaLabels: true,
        );
        if (!result.ok ||
            (printer.transport.isLocal && result.printJob == null)) {
          throw StateError('print_failed');
        }
        committedPrintJob = result.printJob;
      }
      if (printer.transport.isLocal) {
        if (!mounted || _progressReadScope != currentSessionReadScope()) return;
        final printed = await PrintService.printRps(
          committedPrintJob!,
          printerProfile: printer.offlinePrinter,
          bluetoothPrinter: printer.bluetoothPrinter,
          transport: printer.transport,
        );
        if (!printed.ok) throw StateError('print_failed');
      }
      _updateRezkaPrint(() {
        _rezkaPrintStatus[index] = _rezkaText('printed');
        _rezkaPrintedFrameIndexes.add(index);
      });
    } catch (error) {
      if (_applyRezkaBobinaModeError(error)) rethrow;
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
        final paddonRequired = error is MobileApiException &&
            const {'active_paddon_required', 'paddon_locked'}.contains(error.code);
        _rezkaPrintStatus[index] = paddonRequired
            ? context.l10n.productionErrorMessage(error.code)
            : _rezkaSyncRequired
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

  bool _applyRezkaBobinaModeError(Object error) {
    if (!mounted ||
        error is! MobileApiException ||
        error.code != 'rezka_bobina_mode_changed') {
      return false;
    }
    final mode = error.diagnostics['include_bobina_in_net'];
    if (mode is! bool) return false;
    _updateRezkaPrint(() {
      _rezkaBobinaMode = mode;
      // Queued cards captured their input before the change. Keep the
      // controller values and let the operator confirm them again.
      for (final request in _rezkaPrintQueue) {
        _rezkaPrintStatus.remove(request.index);
      }
      _rezkaPrintQueue.clear();
      _rezkaQueuedFrameIndexes.clear();
      _rezkaPrintQueuePaused = false;
    });
    _setCompletionError(
      context.l10n.productionText(mode
          ? 'worker.rezka.bobina_mode.total_weight'
          : 'worker.rezka.bobina_mode.tare_required'),
    );
    return true;
  }
}

class _RezkaPrinterNotSelected implements Exception {
  const _RezkaPrinterNotSelected();
}

class _RezkaFrameInputConflict implements Exception {
  const _RezkaFrameInputConflict();
}
