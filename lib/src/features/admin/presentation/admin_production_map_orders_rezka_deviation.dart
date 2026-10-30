part of 'admin_production_map_orders_screen.dart';

enum _RezkaDeviationField { kg, meter, diameter }

class _RezkaCorrectionFocus {
  _RezkaCorrectionFocus(this.index, this.field);

  final int index;
  final _RezkaDeviationField field;
  bool dialogClosed = false;
}

class _RezkaOutputDeviation {
  const _RezkaOutputDeviation(this.field, this.label, this.unit, this.reference,
      this.entered, this.percent);

  final _RezkaDeviationField field;
  final String label;
  final String unit;
  final double reference;
  final double entered;
  final double percent;
}

extension _RezkaDeviationWarning on _ProgressQtyDialogState {
  void _requestRezkaCorrectionFocus(int index, _RezkaDeviationField field,
      ModalRoute<dynamic>? warningRoute) {
    final target = _RezkaCorrectionFocus(index, field);
    _rezkaCorrectionFocus = target;
    // The pop result arrives before the warning's reverse animation finishes.
    // Wait for removal so the outgoing route cannot take focus back.
    unawaited((warningRoute?.completed ?? Future<void>.value()).then((_) {
      if (!mounted || !identical(_rezkaCorrectionFocus, target)) return;
      target.dialogClosed = true;
      _scheduleRezkaCorrectionFocus();
    }));
  }

  void _scheduleRezkaCorrectionFocus() {
    if (_rezkaCorrectionFocus?.dialogClosed != true ||
        _rezkaCorrectionFocusScheduled) {
      return;
    }
    _rezkaCorrectionFocusScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rezkaCorrectionFocusScheduled = false;
      if (!mounted) return;
      final target = _rezkaCorrectionFocus;
      if (target == null || !target.dialogClosed) return;
      if (_rezkaReport?.frameAt(target.index) != null) {
        _rezkaCorrectionFocus = null;
        return;
      }
      // A queued print must release this card first. Other queued warnings or
      // printer pickers keep their focus until they are dismissed as well.
      if (_rezkaQueuedFrameIndexes.contains(target.index) ||
          _rezkaConfirmationBusy ||
          _rezkaSyncRequired ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final frame = _rezkaFrameControllers[target.index];
      final node = switch (target.field) {
        _RezkaDeviationField.kg => frame.kgFocusNode,
        _RezkaDeviationField.meter => frame.meterFocusNode,
        _RezkaDeviationField.diameter => frame.diameterFocusNode,
      };
      final fieldContext = node.context;
      if (fieldContext == null || !node.canRequestFocus) return;
      _rezkaCorrectionFocus = null;
      // requestKeyboard also shows the keyboard when the field already has
      // focus, unlike requesting the same FocusNode again.
      fieldContext
          .findAncestorStateOfType<EditableTextState>()
          ?.requestKeyboard();
      unawaited(Scrollable.ensureVisible(fieldContext,
          alignment: 0.35,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  _RezkaFrameInput _rezkaInputFromSaved(AdminRecordedRezkaFrame saved) {
    double? value(String key, [String? fallback]) => _parseQty(
        (saved.input[key] ?? saved.input[fallback])?.toString() ?? '');
    return _RezkaFrameInput(
      meterQty: value('produced_qty', 'finished_goods_meter'),
      kgQty: value('gross_qty', 'finished_goods_kg'),
      bobinaKg: value('bobina_kg'),
      diameter: value('diameter'),
      issueNote: saved.issueNote,
    );
  }

  void _refreshRezkaReference(AdminRezkaOutputReport report) {
    if (_rezkaReferenceCycle != report.cycleId) {
      _rezkaReferenceCycle = report.cycleId;
      _rezkaReferenceFrameIndex = null;
      _rezkaAutofillReference = null;
      _rezkaAcknowledgedDeviations.clear();
    }
    final current = _rezkaReferenceFrameIndex;
    if (report.referenceFrameIndex != null) {
      _rezkaReferenceFrameIndex = report.referenceFrameIndex! - 1;
      return;
    }
    final saved = current == null ? null : report.frameAt(current);
    if (saved != null && !saved.isIssue) return;
    _rezkaReferenceFrameIndex = null;
    for (final slot in report.frames) {
      if (!slot.isIssue) {
        _rezkaReferenceFrameIndex = slot.index - 1;
        break;
      }
    }
  }

  String _rezkaDeviationText(String key,
          {Map<String, Object> values = const {}}) =>
      context.l10n
          .productionText('worker.rezka.deviation.$key', values: values);

  List<_RezkaOutputDeviation> _rezkaOutputDeviations(
      _RezkaFrameInput reference, _RezkaFrameInput entered) {
    final result = <_RezkaOutputDeviation>[];
    void check(_RezkaDeviationField field, String key, String unit,
        double? expected, double? actual) {
      final percent =
          rezkaOutputDeviationPercent(reference: expected, actual: actual);
      if (percent != null) {
        result.add(_RezkaOutputDeviation(
            field,
            context.l10n.productionText(key),
            unit,
            expected!,
            actual!,
            percent));
      }
    }

    check(_RezkaDeviationField.kg, 'worker.daily.field.weight', 'kg',
        reference.kgQty, entered.kgQty);
    check(_RezkaDeviationField.meter, 'worker.daily.field.length', 'm',
        reference.meterQty, entered.meterQty);
    check(_RezkaDeviationField.diameter, 'worker.daily.field.diameter', 'mm',
        reference.diameter, entered.diameter);
    return result;
  }

  /// Only invoked at a save/print boundary. Saved cards are reprints, and the
  /// first healthy output establishes the reference without an extra prompt.
  /// Approvals apply to one exact measurement and its reference, never a whole
  /// card: correcting another field must not approve or repeat this warning.
  Future<bool> _confirmRezkaOutputDeviations(
      Map<int, _RezkaFrameInput> pending) async {
    if (!_showRezkaFrameInputs || pending.isEmpty) return true;
    int? referenceIndex = _rezkaReferenceFrameIndex;
    final savedReference =
        referenceIndex == null ? null : _rezkaReport?.frameAt(referenceIndex);
    _RezkaFrameInput? reference =
        savedReference == null || savedReference.isIssue
            ? null
            : _rezkaInputFromSaved(savedReference);
    final indices = pending.keys.toList()..sort();
    if (reference == null) {
      for (final index in indices) {
        final input = pending[index]!;
        if (!input.isIssue &&
            _rezkaFrameMetricsComplete(_rezkaFrameControllers[index])) {
          referenceIndex = index;
          reference = input;
          break;
        }
      }
    }
    if (reference == null) return true;
    _updateRezkaPrint(() => _rezkaConfirmationBusy = true);
    try {
      for (final index in indices) {
        final entered = pending[index]!;
        if (index == referenceIndex ||
            entered.isIssue ||
            _rezkaReport?.frameAt(index) != null) {
          continue;
        }
        final deviations = _rezkaOutputDeviations(reference, entered);
        for (final deviation in deviations) {
          final approval = jsonEncode([
            _rezkaReport?.cycleId,
            referenceIndex,
            index,
            deviation.field.name,
            deviation.reference,
            deviation.entered,
          ]);
          if (_rezkaAcknowledgedDeviations.contains(approval)) continue;
          if (!mounted) return false;
          ModalRoute<dynamic>? warningRoute;
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              warningRoute = ModalRoute.of(dialogContext);
              return AlertDialog(
                key: const ValueKey('rezka-deviation-warning'),
                icon: const Icon(Icons.warning_amber_rounded),
                title: Text(_rezkaDeviationText('title')),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                          _rezkaDeviationText('frame',
                              values: {'index': index + 1}),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Text(deviation.label),
                      Text(
                          '${formatRawQuantity(deviation.entered)} ${deviation.unit}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${_rezkaDeviationText('reference')}: '
                          '${formatRawQuantity(deviation.reference)} ${deviation.unit}'),
                      Text('${_rezkaDeviationText('difference')}: '
                          '${deviation.percent > 0 ? '+' : ''}'
                          '${formatRawQuantity(double.parse(deviation.percent.toStringAsFixed(2)))}%'),
                      const SizedBox(height: 16),
                      Text(_rezkaDeviationText('question')),
                    ],
                  ),
                ),
                actions: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        key: const ValueKey('rezka-deviation-edit'),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(_rezkaDeviationText('edit')),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('rezka-deviation-confirm'),
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(_rezkaDeviationText('confirm')),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
          if (mounted && confirmed == false) {
            _requestRezkaCorrectionFocus(index, deviation.field, warningRoute);
          }
          if (!mounted || confirmed != true) return false;
          _rezkaAcknowledgedDeviations.add(approval);
        }
      }
      return true;
    } finally {
      if (mounted) _updateRezkaPrint(() => _rezkaConfirmationBusy = false);
    }
  }

  // A correction may arrive while the operator considers the warning. Confirm
  // against the refreshed measurements before committing a new physical WIP.
  Future<bool> _confirmFreshRezkaFrame(_RezkaPrintRequest request) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final approvedCount = _rezkaAcknowledgedDeviations.length;
      if (!await _confirmRezkaOutputDeviations(
              {request.index: request.input!}) ||
          !mounted) {
        return false;
      }
      if (_rezkaAcknowledgedDeviations.length == approvedCount) return true;
      final latest = await widget.reloadRezkaOutputReport?.call();
      if (!mounted) return false;
      if (latest == null ||
          latest.cycleId != _rezkaReport?.cycleId ||
          latest.frames.any((slot) => slot.index > _rezkaFrameCount)) {
        throw const MobileApiException(
            code: 'rezka_output_cycle_conflict', message: '');
      }
      _updateRezkaPrint(() => _restoreRezkaOutputReport(latest));
    }
    throw const MobileApiException(
        code: 'rezka_output_cycle_conflict', message: '');
  }
}
