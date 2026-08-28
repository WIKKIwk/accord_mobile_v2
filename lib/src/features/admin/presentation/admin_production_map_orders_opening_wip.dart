part of 'admin_production_map_orders_screen.dart';

class AdminOpeningWipScreen extends StatefulWidget {
  const AdminOpeningWipScreen({
    super.key,
    this.progressDriverUrlPicker,
  });

  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<AdminOpeningWipScreen> createState() => _AdminOpeningWipScreenState();
}

class _AdminOpeningWipScreenState extends State<AdminOpeningWipScreen> {
  late Future<_OpeningWipPageData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_OpeningWipPageData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminProductionMaps(),
      MobileApi.instance.adminApparatus(limit: 10000),
      MobileApi.instance.adminProductionMapQueueSnapshot(),
    ]);
    final orders = results[0] as List<ProductionMapSaved>;
    final apparatus = results[1] as List<AdminApparatus>;
    final snapshot = results[2] as AdminApparatusQueueSnapshot;
    return _OpeningWipPageData(
      orders: _openingWipEligibleOrders(
        orders: orders,
        queueStatesByApparatus: snapshot.queueStates,
      ),
      apparatus: apparatus,
    );
  }

  Future<void> _reload() async {
    final nextFuture = _load();
    setState(() => _future = nextFuture);
    await nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: context.l10n.adminText('production.opening_wip.title'),
      selectedRouteName: AppRoutes.adminOpeningWip,
      activeTab: AdminDockTab.home,
      bottomDockFadeStrength: null,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: FutureBuilder<_OpeningWipPageData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: _reload);
            }
            final data = snapshot.data!;
            return _OpeningWipWizard(
              orders: data.orders,
              apparatusCatalog: data.apparatus,
              progressDriverUrlPicker: widget.progressDriverUrlPicker,
            );
          },
        ),
      ),
    );
  }
}

class _OpeningWipPageData {
  const _OpeningWipPageData({
    required this.orders,
    required this.apparatus,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatus;
}

List<ProductionMapSaved> _openingWipEligibleOrders({
  required List<ProductionMapSaved> orders,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  return [
    for (final order in orders)
      if (_openingWipEntryApparatus(order) != null &&
          !_openingWipOrderHasStarted(
            order.map.id,
            queueStatesByApparatus,
          ))
        order,
  ];
}

String? _openingWipEntryApparatus(ProductionMapSaved order) {
  for (final stage in productionMapLinearWorkStages(order.map)) {
    final apparatusId = stage.apparatusId?.trim() ?? '';
    if (apparatusId.isNotEmpty && canonicalApparatusIdIsValid(apparatusId)) {
      return apparatusId;
    }
  }
  return null;
}

bool _openingWipOrderHasStarted(
  String orderId,
  Map<String, Map<String, String>> queueStatesByApparatus,
) {
  final normalizedOrderId = orderId.trim();
  for (final states in queueStatesByApparatus.values) {
    final state = states[normalizedOrderId]?.trim().toLowerCase() ?? '';
    if (state.isNotEmpty && state != 'pending') return true;
  }
  return false;
}

class _OpeningWipWizard extends StatefulWidget {
  const _OpeningWipWizard({
    required this.orders,
    required this.apparatusCatalog,
    this.progressDriverUrlPicker,
  });

  final List<ProductionMapSaved> orders;
  final List<AdminApparatus> apparatusCatalog;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<_OpeningWipWizard> createState() => _OpeningWipWizardState();
}

class _OpeningWipWizardState extends State<_OpeningWipWizard> {
  final _formKey = GlobalKey<FormState>();
  final _sourceOperationController = TextEditingController(text: 'Bosma');
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  final _rollCountController = TextEditingController(text: '1');
  final _quantityController = TextEditingController();
  final _uomController = TextEditingController(text: 'kg');
  ProductionMapSaved? _selectedOrder;
  String _sourceApparatus = '';
  AdminOpeningWipQuantityBasis _quantityBasis =
      AdminOpeningWipQuantityBasis.unknown;
  _ProgressPrinterOption? _printer;
  AdminOpeningWipRecord? _createdRecord;
  final Set<String> _printedBatchIds = {};
  String _idempotencyKey = '';
  String _idempotencyFingerprint = '';
  String _error = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedOrder = widget.orders.isEmpty ? null : widget.orders.first;
  }

  @override
  void dispose() {
    _sourceOperationController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    _rollCountController.dispose();
    _quantityController.dispose();
    _uomController.dispose();
    super.dispose();
  }

  Future<void> _pickPrinter() async {
    final selected = await _pickProgressPrinter(
      context,
      widget.progressDriverUrlPicker,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _printer = selected;
      _error = '';
    });
  }

  String _submissionIdempotencyKey({
    required ProductionMapSaved order,
    required String entryApparatus,
    required int rollCount,
    required double? quantity,
  }) {
    final fingerprint = [
      order.map.id.trim(),
      entryApparatus,
      _sourceOperationController.text.trim().toLowerCase(),
      _sourceApparatus,
      _locationController.text.trim(),
      _noteController.text.trim(),
      '$rollCount',
      _quantityBasis.apiValue,
      '${quantity ?? ''}',
      _quantityBasis == AdminOpeningWipQuantityBasis.unknown
          ? ''
          : _uomController.text.trim().toLowerCase(),
    ].join('|');
    if (_idempotencyKey.isEmpty || _idempotencyFingerprint != fingerprint) {
      _idempotencyFingerprint = fingerprint;
      final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      _idempotencyKey = 'mobile:opening-wip:$stamp';
    }
    return _idempotencyKey;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final created = _createdRecord;
    if (created == null && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final printer = _printer;
    if (printer == null) {
      setState(() {
        _error = context.l10n.adminText(
          'production.opening_wip.printer_required',
        );
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      var record = created;
      if (record == null) {
        final order = _selectedOrder!;
        final entryApparatus = _openingWipEntryApparatus(order)!;
        final rollCount = int.parse(_rollCountController.text.trim());
        final quantity = _quantityBasis == AdminOpeningWipQuantityBasis.unknown
            ? null
            : double.parse(
                _quantityController.text.trim().replaceAll(',', '.'),
              );
        final batchInput = AdminOpeningWipBatchInput(
          quantityBasis: _quantityBasis,
          quantity: quantity,
          uom: _quantityBasis == AdminOpeningWipQuantityBasis.unknown
              ? ''
              : _uomController.text.trim(),
        );
        record = await MobileApi.instance.adminCreateOpeningWip(
          AdminOpeningWipCreateInput(
            idempotencyKey: _submissionIdempotencyKey(
              order: order,
              entryApparatus: entryApparatus,
              rollCount: rollCount,
              quantity: quantity,
            ),
            orderId: order.map.id,
            entryApparatus: entryApparatus,
            sourceOperation: _sourceOperationController.text,
            sourceApparatus: _sourceApparatus,
            currentLocation: _locationController.text,
            note: _noteController.text,
            batches: List<AdminOpeningWipBatchInput>.filled(
              rollCount,
              batchInput,
              growable: false,
            ),
          ),
        );
        if (!mounted) return;
        setState(() => _createdRecord = record);
      }

      for (final batch in record.batches) {
        if (_printedBatchIds.contains(batch.batchId)) continue;
        final result = await MobileApi.instance.adminPrintOpeningWip(
          batchId: batch.batchId,
          qrPayload: batch.qrPayload,
          driverUrl: printer.driverUrl,
          printer: printer.printer,
          printMode: printer.printMode,
          printCount: 1,
          printTransport: printer.transport,
        );
        if (!result.ok) {
          throw StateError(result.printStatus);
        }
        if (printer.transport.isLocal) {
          final printJob = result.printJob;
          if (printJob == null) {
            throw StateError('Opening WIP print job missing');
          }
          final localResult = await PrintService.printRps(
            printJob,
            printerProfile: printer.offlinePrinter,
            bluetoothPrinter: printer.bluetoothPrinter,
            transport: printer.transport,
          );
          if (!localResult.ok) {
            throw StateError(localResult.printerStatus);
          }
        }
        if (!mounted) return;
        setState(() => _printedBatchIds.add(batch.batchId));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is MobileApiException
              ? error.message
              : context.l10n.adminText(
                  'production.opening_wip.print_failed',
                  values: {
                    'printed': _printedBatchIds.length,
                    'total': _createdRecord?.batches.length ?? 0,
                  },
                );
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _orderLabel(ProductionMapSaved order) {
    final number = order.map.orderNumber.trim().isEmpty
        ? order.map.id.trim()
        : order.map.orderNumber.trim();
    final title = order.map.title.trim();
    return title.isEmpty ? number : '$number • $title';
  }

  String _apparatusLabel(String apparatusId) {
    return canonicalApparatusDisplayLabel(
      apparatusId,
      widget.apparatusCatalog,
    );
  }

  String? _requiredText(String? value) {
    return value?.trim().isEmpty != false
        ? context.l10n.adminText('production.opening_wip.required')
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = _selectedOrder;
    final entryApparatus =
        order == null ? null : _openingWipEntryApparatus(order);
    final created = _createdRecord;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  context.l10n.adminText(
                    'production.opening_wip.cutover_notice',
                  ),
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.orders.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      context.l10n.adminText(
                        'production.opening_wip.no_eligible',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: AbsorbPointer(
                    absorbing: created != null,
                    child: ListView(
                      children: [
                        DropdownButtonFormField<ProductionMapSaved>(
                          key: const ValueKey('opening-wip-order'),
                          initialValue: order,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.order',
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            for (final item in widget.orders)
                              DropdownMenuItem(
                                value: item,
                                child: Text(
                                  _orderLabel(item),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedOrder = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.entry_apparatus',
                            ),
                          ),
                          child: Text(
                            entryApparatus == null
                                ? '—'
                                : _apparatusLabel(entryApparatus),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('opening-wip-source-operation'),
                          controller: _sourceOperationController,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.source_operation',
                            ),
                          ),
                          validator: _requiredText,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _sourceApparatus,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.source_apparatus',
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: '',
                              child: Text(
                                context.l10n.adminText(
                                  'production.opening_wip.source_none',
                                ),
                              ),
                            ),
                            for (final item in widget.apparatusCatalog)
                              if (item.id.trim().isNotEmpty)
                                DropdownMenuItem(
                                  value: item.id.trim(),
                                  child: Text(
                                    canonicalApparatusDisplayLabel(
                                      item.id,
                                      widget.apparatusCatalog,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          ],
                          onChanged: (value) {
                            setState(() => _sourceApparatus = value ?? '');
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('opening-wip-location'),
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.current_location',
                            ),
                          ),
                          validator: _requiredText,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.note',
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey('opening-wip-roll-count'),
                          controller: _rollCountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.roll_count',
                            ),
                          ),
                          validator: (value) {
                            final count = int.tryParse(value?.trim() ?? '');
                            return count == null || count < 1 || count > 500
                                ? context.l10n.adminText(
                                    'production.opening_wip.invalid_roll_count',
                                  )
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AdminOpeningWipQuantityBasis>(
                          initialValue: _quantityBasis,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.quantity_basis',
                            ),
                          ),
                          items: [
                            for (final basis
                                in AdminOpeningWipQuantityBasis.values)
                              DropdownMenuItem(
                                value: basis,
                                child: Text(
                                  context.l10n.adminText(
                                    'production.opening_wip.basis_${basis.apiValue}',
                                  ),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _quantityBasis = value);
                            }
                          },
                        ),
                        if (_quantityBasis !=
                            AdminOpeningWipQuantityBasis.unknown) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _quantityController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: context.l10n.adminText(
                                      'production.opening_wip.quantity',
                                    ),
                                  ),
                                  validator: (value) {
                                    final quantity = double.tryParse(
                                      (value ?? '').trim().replaceAll(',', '.'),
                                    );
                                    return quantity == null ||
                                            !quantity.isFinite ||
                                            quantity <= 0
                                        ? context.l10n.adminText(
                                            'production.opening_wip.invalid_quantity',
                                          )
                                        : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _uomController,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.adminText(
                                      'production.opening_wip.uom',
                                    ),
                                  ),
                                  validator: _requiredText,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const ValueKey('opening-wip-pick-printer'),
                          onPressed: _submitting ? null : _pickPrinter,
                          icon: const Icon(Icons.print_outlined),
                          label: Text(
                            _printer?.printerLabel ??
                                context.l10n.adminText(
                                  'production.opening_wip.select_printer',
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _error,
                  key: const ValueKey('opening-wip-error'),
                  style: TextStyle(color: scheme.error),
                ),
              ],
              if (widget.orders.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('opening-wip-submit'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_rounded),
                  label: Text(
                    created == null
                        ? context.l10n.adminText(
                            'production.opening_wip.create_print',
                          )
                        : context.l10n.adminText(
                            'production.opening_wip.retry_print',
                            values: {
                              'printed': _printedBatchIds.length,
                              'total': created.batches.length,
                            },
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
