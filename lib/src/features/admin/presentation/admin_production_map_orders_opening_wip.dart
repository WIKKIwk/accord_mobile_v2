part of 'admin_production_map_orders_screen.dart';

const int _openingWipListFetchLimit = 500;

class _OpeningWipWizardState extends State<_OpeningWipWizard> {
  final _formKey = GlobalKey<FormState>();
  final _sourceFieldKey = GlobalKey<FormFieldState<String>>();
  final _rollCountController = TextEditingController(text: '1');
  final List<_OpeningWipRollControllers> _rollControllers = [
    _OpeningWipRollControllers(),
  ];
  ProductionMapSaved? _selectedOrder;
  String _sourceStageNodeId = '';
  AdminOpeningWipQuantityBasis _quantityBasis =
      AdminOpeningWipQuantityBasis.measured;
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
    _sourceStageNodeId = _availableSourceStages.isEmpty
        ? ''
        : _availableSourceStages.first.nodeId;
  }

  @override
  void dispose() {
    _rollCountController.dispose();
    for (final controller in _rollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ProductionMapChainStage> get _availableSourceStages =>
      _openingWipSourceStages(_selectedOrder, widget.stageStatesByOrderId);

  ProductionMapChainStage? get _selectedSourceStage {
    for (final stage in _availableSourceStages) {
      if (stage.nodeId.trim() == _sourceStageNodeId.trim()) return stage;
    }
    return null;
  }

  String get _sourceApparatus =>
      _selectedSourceStage?.apparatusId?.trim() ?? '';

  AdminApparatus? get _sourceApparatusDefinition {
    for (final apparatus in widget.apparatusCatalog) {
      if (apparatus.id.trim() == _sourceApparatus) return apparatus;
    }
    return null;
  }

  bool get _requiresDiameter =>
      _sourceApparatusDefinition?.operation.trim().toLowerCase() == 'cut';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final order = _selectedOrder;
    final availableSourceStages = _availableSourceStages;
    final requiresDiameter = _requiresDiameter;
    final created = _createdRecord;
    return PopScope(
      canPop: !_submitting,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  child: ListView(
                    key: const ValueKey('opening-wip-fields'),
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      AbsorbPointer(
                        absorbing: created != null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child:
                                  DropdownButtonFormField<ProductionMapSaved>(
                                key: const ValueKey('opening-wip-order'),
                                initialValue: order,
                                decoration: _openingWipInputDecoration(
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
                            ),
                            const SizedBox(height: 12),
                            KeyedSubtree(
                              key: const ValueKey(
                                  'opening-wip-source-apparatus'),
                              child: DropdownButtonFormField<String>(
                                key: _sourceFieldKey,
                                initialValue: _sourceStageNodeId.isEmpty
                                    ? null
                                    : _sourceStageNodeId,
                                decoration: _openingWipInputDecoration(
                                  labelText: context.l10n.adminText(
                                    'production.opening_wip.source_apparatus',
                                  ),
                                ),
                                isExpanded: true,
                                items: [
                                  for (final stage in availableSourceStages)
                                    DropdownMenuItem(
                                      value: stage.nodeId,
                                      child: Text(
                                        stage.displayTitle.trim().isEmpty
                                            ? _apparatusLabel(
                                                stage.apparatusId!)
                                            : stage.displayTitle.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: availableSourceStages.isEmpty
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _sourceStageNodeId = value ?? '';
                                          for (final roll in _rollControllers) {
                                            if (!_requiresDiameter) {
                                              roll.diameter.clear();
                                            }
                                          }
                                        });
                                      },
                                validator: (value) {
                                  if (availableSourceStages.isEmpty) {
                                    return context.l10n.adminText(
                                      'production.opening_wip.location_missing',
                                    );
                                  }
                                  return _requiredText(value);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: const ValueKey('opening-wip-roll-count'),
                              controller: _rollCountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: _openingWipInputDecoration(
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
                            DropdownButtonFormField<
                                AdminOpeningWipQuantityBasis>(
                              key: const ValueKey(
                                'opening-wip-quantity-basis',
                              ),
                              initialValue: _quantityBasis,
                              decoration: _openingWipInputDecoration(
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
                                  border:
                                      Border.all(color: scheme.outlineVariant),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      context.l10n.adminText(
                                        'production.opening_wip.roll_title',
                                        values: {'index': '${index + 1}'},
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
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
                                      controller:
                                          _rollControllers[index].bobinaKg,
                                      labelKey:
                                          'production.opening_wip.bobina_kg',
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
                                        labelKey:
                                            'production.opening_wip.diameter',
                                        unit: 'mm',
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
            ],
          ),
        ),
      ),
    );
  }
}
