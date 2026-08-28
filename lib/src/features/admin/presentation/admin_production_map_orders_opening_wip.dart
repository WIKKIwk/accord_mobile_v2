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

List<String> _openingWipLocationApparatuses(ProductionMapSaved? order) {
  if (order == null) return const [];
  final seen = <String>{};
  return List<String>.unmodifiable([
    for (final stage in productionMapLinearWorkStages(order.map))
      if (stage.apparatusId?.trim().isNotEmpty == true &&
          canonicalApparatusIdIsValid(stage.apparatusId!.trim()) &&
          seen.add(stage.apparatusId!.trim()))
        stage.apparatusId!.trim(),
  ]);
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

class _OpeningWipRollControllers {
  final meter = TextEditingController();
  final kg = TextEditingController();
  final bobinaKg = TextEditingController();
  final diameter = TextEditingController();

  double? parse(TextEditingController controller) => double.tryParse(
        controller.text.trim().replaceAll(',', '.'),
      );

  String get fingerprint => [
        meter.text.trim(),
        kg.text.trim(),
        bobinaKg.text.trim(),
        diameter.text.trim(),
      ].join(',');

  void dispose() {
    meter.dispose();
    kg.dispose();
    bobinaKg.dispose();
    diameter.dispose();
  }
}

class _OpeningWipWizardState extends State<_OpeningWipWizard> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _rollCountController = TextEditingController(text: '1');
  final List<_OpeningWipRollControllers> _rollControllers = [
    _OpeningWipRollControllers(),
  ];
  ProductionMapSaved? _selectedOrder;
  String _currentLocation = '';
  AdminOpeningWipQuantityBasis _quantityBasis =
      AdminOpeningWipQuantityBasis.measured;
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
    _currentLocation =
        _availableLocations.isEmpty ? '' : _availableLocations.first;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _rollCountController.dispose();
    for (final controller in _rollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncRollControllers(String rawCount) {
    final count = int.tryParse(rawCount.trim());
    if (count == null || count < 1 || count > 500) return;
    setState(() {
      while (_rollControllers.length < count) {
        _rollControllers.add(_OpeningWipRollControllers());
      }
      while (_rollControllers.length > count) {
        _rollControllers.removeLast().dispose();
      }
    });
  }

  String get _entryApparatus => _selectedOrder == null
      ? ''
      : _openingWipEntryApparatus(_selectedOrder!) ?? '';

  AdminApparatus? get _entryApparatusDefinition {
    for (final apparatus in widget.apparatusCatalog) {
      if (apparatus.id.trim() == _entryApparatus) return apparatus;
    }
    return null;
  }

  bool get _requiresDiameter =>
      _entryApparatusDefinition?.operation.trim().toLowerCase() == 'cut';

  List<String> get _availableLocations =>
      _openingWipLocationApparatuses(_selectedOrder);

  void _selectOrder(ProductionMapSaved? order) {
    setState(() {
      _selectedOrder = order;
      final locations = _availableLocations;
      _currentLocation = locations.isEmpty ? '' : locations.first;
      for (final roll in _rollControllers) {
        if (!_requiresDiameter) roll.diameter.clear();
      }
    });
  }

  AdminOpeningWipBatchInput _rollInput(_OpeningWipRollControllers roll) {
    return AdminOpeningWipBatchInput(
      quantityBasis: _quantityBasis,
      finishedGoodsMeter: roll.parse(roll.meter)!,
      finishedGoodsKg: roll.parse(roll.kg)!,
      bobinaKg: roll.parse(roll.bobinaKg)!,
      diameter: _requiresDiameter ? roll.parse(roll.diameter) : null,
    );
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
  }) {
    final fingerprint = [
      order.map.id.trim(),
      entryApparatus,
      _currentLocation,
      _noteController.text.trim(),
      '$rollCount',
      _quantityBasis.apiValue,
      _rollControllers.map((roll) => roll.fingerprint).join(';'),
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
        final batches = [
          for (var index = 0; index < rollCount; index++)
            _rollInput(_rollControllers[index]),
        ];
        record = await MobileApi.instance.adminCreateOpeningWip(
          AdminOpeningWipCreateInput(
            idempotencyKey: _submissionIdempotencyKey(
              order: order,
              entryApparatus: entryApparatus,
              rollCount: rollCount,
            ),
            orderId: order.map.id,
            entryApparatus: entryApparatus,
            currentLocation: _currentLocation,
            note: _noteController.text,
            batches: batches,
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

  Widget _metricField({
    required Key key,
    required TextEditingController controller,
    required String labelKey,
    required String unit,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: context.l10n.adminText(labelKey),
        suffixText: unit,
      ),
      validator: (value) {
        final parsed = double.tryParse(
          (value ?? '').trim().replaceAll(',', '.'),
        );
        return parsed == null || !parsed.isFinite || parsed <= 0
            ? context.l10n.adminText(
                'production.opening_wip.invalid_quantity',
              )
            : null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = _selectedOrder;
    final entryApparatus =
        order == null ? null : _openingWipEntryApparatus(order);
    final availableLocations = _availableLocations;
    final requiresDiameter = _requiresDiameter;
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
                      key: const ValueKey('opening-wip-fields'),
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
                          onChanged: _selectOrder,
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
                        DropdownButtonFormField<String>(
                          key: const ValueKey('opening-wip-location'),
                          initialValue: _currentLocation.isEmpty
                              ? null
                              : _currentLocation,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.current_location',
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            for (final apparatusId in availableLocations)
                              DropdownMenuItem(
                                value: apparatusId,
                                child: Text(
                                  _apparatusLabel(apparatusId),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: availableLocations.isEmpty
                              ? null
                              : (value) {
                                  setState(
                                    () => _currentLocation = value ?? '',
                                  );
                                },
                          validator: (value) {
                            if (availableLocations.isEmpty) {
                              return context.l10n.adminText(
                                'production.opening_wip.location_missing',
                              );
                            }
                            return _requiredText(value);
                          },
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
                          onChanged: _syncRollControllers,
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
                          key: const ValueKey(
                            'opening-wip-quantity-basis',
                          ),
                          initialValue: _quantityBasis,
                          decoration: InputDecoration(
                            labelText: context.l10n.adminText(
                              'production.opening_wip.quantity_basis',
                            ),
                          ),
                          items: [
                            for (final basis in const [
                              AdminOpeningWipQuantityBasis.measured,
                              AdminOpeningWipQuantityBasis.estimated,
                            ])
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
                        for (var index = 0;
                            index < _rollControllers.length;
                            index++) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outlineVariant),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  context.l10n.adminText(
                                    'production.opening_wip.roll_title',
                                    values: {'index': '${index + 1}'},
                                  ),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 10),
                                _metricField(
                                  key: ValueKey(
                                    'opening-wip-roll-meter-$index',
                                  ),
                                  controller: _rollControllers[index].meter,
                                  labelKey:
                                      'production.opening_wip.finished_meter',
                                  unit: 'm',
                                ),
                                const SizedBox(height: 10),
                                _metricField(
                                  key: ValueKey(
                                    'opening-wip-roll-kg-$index',
                                  ),
                                  controller: _rollControllers[index].kg,
                                  labelKey:
                                      'production.opening_wip.finished_kg',
                                  unit: 'kg',
                                ),
                                const SizedBox(height: 10),
                                _metricField(
                                  key: ValueKey(
                                    'opening-wip-roll-bobina-$index',
                                  ),
                                  controller: _rollControllers[index].bobinaKg,
                                  labelKey: 'production.opening_wip.bobina_kg',
                                  unit: 'kg',
                                ),
                                if (requiresDiameter) ...[
                                  const SizedBox(height: 10),
                                  _metricField(
                                    key: ValueKey(
                                      'opening-wip-roll-diameter-$index',
                                    ),
                                    controller:
                                        _rollControllers[index].diameter,
                                    labelKey: 'production.opening_wip.diameter',
                                    unit: 'mm',
                                  ),
                                ],
                              ],
                            ),
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
