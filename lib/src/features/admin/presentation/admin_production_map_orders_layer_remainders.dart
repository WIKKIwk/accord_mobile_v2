part of 'admin_production_map_orders_screen.dart';

/// Uses the same physical input identities and printer transports as production.
class LaminationLayerRemainderSheet extends StatefulWidget {
  const LaminationLayerRemainderSheet({
    super.key,
    required this.apparatus,
    required this.orderId,
    this.progressDriverUrlPicker,
  });

  final String apparatus;
  final String orderId;
  final Future<String?> Function(BuildContext)? progressDriverUrlPicker;

  @override
  State<LaminationLayerRemainderSheet> createState() =>
      _LaminationLayerRemainderSheetState();
}

class _LaminationLayerRemainderSheetState
    extends State<LaminationLayerRemainderSheet> {
  final _kgController = TextEditingController();
  AdminLayerRemainderSnapshot? _snapshot;
  AdminLayerRemainderSource? _selected;
  AdminLayerRemainder? _saved;
  Map<String, dynamic>? _pending;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _status;
  late final String _requestProfileRef;

  String get _pendingKey =>
      'lamination_layer_remainder_pending:$_requestProfileRef:${widget.apparatus}:${widget.orderId}';

  String _text(String key, {Map<String, String> args = const {}}) =>
      context.l10n.productionText('worker.layer_remainder.$key', values: args);

  @override
  void initState() {
    super.initState();
    _requestProfileRef = AppSession.instance.profile?.ref ?? '';
    unawaited(_load());
  }

  @override
  void dispose() {
    _kgController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      final pendingJson = preferences.getString(_pendingKey);
      Map<String, dynamic>? pending;
      if (pendingJson != null) {
        pending = (jsonDecode(pendingJson) as Map).cast<String, dynamic>();
      }
      final snapshot = await MobileApi.instance.adminLayerRemainders(
          apparatus: widget.apparatus, orderId: widget.orderId);
      AdminLayerRemainder? reconciled;
      if (pending != null) {
        for (final remainder in snapshot.remainders) {
          if (remainder.requestId == pending['request_id']) {
            reconciled = remainder;
            break;
          }
        }
        if (reconciled != null) {
          await preferences.remove(_pendingKey);
          pending = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _pending = pending;
        _saved = reconciled ?? _saved;
        _selected = pending == null
            ? null
            : AdminLayerRemainderSource.fromJson(
                (pending!['source'] as Map).cast<String, dynamic>());
        if (pending != null) {
          _kgController.text = pending!['remaining_net_kg'].toString();
        }
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  double? get _remainingKg =>
      double.tryParse(_kgController.text.trim().replaceAll(',', '.'));

  String _number(double value) =>
      value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

  String _errorText(Object error) {
    if (error is MobileApiException) {
      return context.l10n
          .productionErrorMessage(error.code, fallback: error.message);
    }
    return _text('failed');
  }

  Future<void> _clearPending() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingKey);
    if (mounted) setState(() => _pending = null);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final source = _selected;
    final netKg = _remainingKg;
    if (source == null ||
        netKg == null ||
        source.estimateMeter(netKg) == null) {
      setState(() => _error = _text('invalid_weight'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    var committed = false;
    try {
      final printer =
          await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
      if (!mounted || printer == null) return;
      final pending = _pending ??
          {
            'request_id':
                'layer-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}',
            'source': source.toJson(),
            'remaining_net_kg': netKg,
          };
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_pendingKey, jsonEncode(pending));
      if (mounted) setState(() => _pending = pending);
      final result = await MobileApi.instance.adminRecordLayerRemainder(
        apparatus: widget.apparatus,
        orderId: widget.orderId,
        source: source,
        remainingNetKg: netKg,
        requestId: pending['request_id'] as String,
        driverUrl: printer.driverUrl,
        printer: printer.printer,
        printMode: printer.printMode,
        printTransport: printer.transport,
      );
      committed = true;
      // Printing is subsequent work: retain the saved operation even if it fails.
      if (mounted) {
        setState(() {
          _saved = result.remainder;
          _selected = null;
          _kgController.clear();
          _status = _text('saved');
        });
      }
      await _clearPending();
      await _load();
      await _printResult(result, printer);
      if (mounted) setState(() => _status = _text('printed'));
    } catch (error) {
      if (error is MobileApiException &&
          const {400, 403, 404, 409, 422}.contains(error.statusCode)) {
        await _clearPending();
        if (error.statusCode == 409 || error.statusCode == 404) await _load();
      }
      if (mounted) {
        setState(() =>
            _error = committed ? _text('print_failed') : _errorText(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printResult(
      AdminLayerRemainderResult result, _ProgressPrinterOption printer) async {
    if (!result.printOk) throw StateError('print_failed');
    if (!printer.transport.isLocal) return;
    final job = result.printJob;
    if (job == null || job.epc != result.remainder.qrPayload) {
      throw StateError('print_identity_mismatch');
    }
    final printed = await PrintService.printRps(
      job,
      printerProfile: printer.offlinePrinter,
      bluetoothPrinter: printer.bluetoothPrinter,
      transport: printer.transport,
    );
    if (!printed.ok) throw StateError('print_failed');
  }

  Future<void> _reprint(AdminLayerRemainder remainder) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _saved = remainder;
    });
    try {
      final printer =
          await _pickProgressPrinter(context, widget.progressDriverUrlPicker);
      if (!mounted || printer == null) return;
      final result = await MobileApi.instance.adminLayerRemainderReprint(
        apparatus: widget.apparatus,
        orderId: widget.orderId,
        operationId: remainder.operationId,
        driverUrl: printer.driverUrl,
        printer: printer.printer,
        printMode: printer.printMode,
        printTransport: printer.transport,
      );
      await _printResult(result, printer);
      if (mounted) setState(() => _status = _text('printed'));
    } catch (error) {
      if (mounted) setState(() => _error = _text('print_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selected;
    final remainingKg = _remainingKg;
    final estimate = selected == null || remainingKg == null
        ? null
        : selected.estimateMeter(remainingKg);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_text('title'), style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_text('description'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_error!,
                        key: const ValueKey('layer-remainder-error'),
                        style: TextStyle(color: scheme.error))),
              if (_status != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_status!)),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          if (_snapshot == null)
                            OutlinedButton.icon(
                                onPressed: _busy ? null : _load,
                                icon: const Icon(Icons.refresh),
                                label: Text(_text('retry'))),
                          if (_pending != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(_text('pending')),
                            ),
                          if (_snapshot?.sources.isEmpty == true &&
                              _pending == null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(_text('empty')),
                            ),
                          for (final source in _snapshot?.sources ??
                              const <AdminLayerRemainderSource>[])
                            Card(
                              child: ListTile(
                                key: ValueKey(
                                    'layer-remainder-source-${source.sourceKind}-${source.sourceId}'),
                                enabled: !_busy &&
                                    _pending == null &&
                                    source.canCalculate,
                                selected: selected?.sourceId ==
                                        source.sourceId &&
                                    selected?.sourceKind == source.sourceKind,
                                leading: Icon(
                                    source.sourceKind == 'raw_material'
                                        ? Icons.layers_outlined
                                        : Icons.print_outlined),
                                title: Text(source.itemName.isEmpty
                                    ? source.itemCode
                                    : source.itemName),
                                subtitle: Text([
                                  _text(source.sourceKind == 'raw_material'
                                      ? 'raw_material'
                                      : 'printed_roll'),
                                  '${_number(source.sourceNetKg)} kg · ${_number(source.sourceMeter)} m',
                                  if (source.producerName.isNotEmpty)
                                    source.producerName,
                                  if (!source.canCalculate)
                                    _text('missing_basis'),
                                  source.qrPayload,
                                ].join('\n')),
                                trailing:
                                    selected?.sourceId == source.sourceId &&
                                            selected?.sourceKind ==
                                                source.sourceKind
                                        ? const Icon(Icons.check_circle)
                                        : null,
                                onTap: () => setState(() {
                                  _selected = source;
                                  _kgController.clear();
                                  _error = null;
                                }),
                              ),
                            ),
                          if (selected != null) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('layer-remainder-net-kg'),
                              controller: _kgController,
                              enabled: !_busy && _pending == null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                labelText: _text('net_weight'),
                                suffixText: 'kg',
                                helperText: _text('max_weight', args: {
                                  'kg': _number(selected.sourceNetKg)
                                }),
                              ),
                              onChanged: (_) => setState(() => _error = null),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _text('estimated_meter', args: {
                                'meter':
                                    estimate == null ? '—' : _number(estimate),
                              }),
                              key: const ValueKey('layer-remainder-meter'),
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              key: const ValueKey('layer-remainder-save'),
                              onPressed:
                                  _busy || estimate == null ? null : _submit,
                              icon: const Icon(Icons.print_outlined),
                              label: Text(_text(
                                  _pending == null ? 'save_print' : 'retry')),
                            ),
                          ],
                          if (_saved case final saved?) ...[
                            const SizedBox(height: 20),
                            Text(_text('saved'),
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                                '${_number(saved.remainingNetKg)} kg · ≈ ${_number(saved.remainingMeter)} m'),
                            if (saved.producerName.isNotEmpty)
                              Text(_text('producer',
                                  args: {'name': saved.producerName})),
                            if (saved.recordedByName.isNotEmpty)
                              Text(_text('recorded_by',
                                  args: {'name': saved.recordedByName})),
                            SelectableText(saved.qrPayload),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              key: const ValueKey('layer-remainder-reprint'),
                              onPressed: _busy ? null : () => _reprint(saved),
                              icon: const Icon(Icons.print_outlined),
                              label: Text(_text('reprint')),
                            ),
                          ],
                          if (_snapshot?.remainders.isNotEmpty == true) ...[
                            const SizedBox(height: 20),
                            Text(_text('history'),
                                style: theme.textTheme.titleMedium),
                            for (final remainder in _snapshot!.remainders)
                              ListTile(
                                key: ValueKey(
                                    'layer-remainder-history-${remainder.operationId}'),
                                title: Text(remainder.itemName.isEmpty
                                    ? _text(
                                        remainder.sourceKind == 'raw_material'
                                            ? 'raw_material'
                                            : 'printed_roll')
                                    : remainder.itemName),
                                subtitle: Text(
                                    '${_number(remainder.remainingNetKg)} kg · ≈ ${_number(remainder.remainingMeter)} m\n${remainder.qrPayload}'),
                                trailing: const Icon(Icons.print_outlined),
                                onTap: _busy ? null : () => _reprint(remainder),
                              ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(_saved != null),
                child: Text(_text('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
