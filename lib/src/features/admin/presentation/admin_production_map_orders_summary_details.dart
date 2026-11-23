part of 'admin_production_map_orders_screen.dart';

Widget _orderSummaryLengthRow(BuildContext context, int meters) {
  final l10n = context.l10n;
  return AppInfoRow(
    label: l10n.productionText('worker.summary.length'),
    value: l10n.productionText(
      'worker.summary.length_value',
      values: {'value': meters.toString()},
    ),
    icon: Icons.straighten_rounded,
  );
}

class _OrderCalculationDetails extends StatefulWidget {
  const _OrderCalculationDetails({
    required this.map,
    required this.plannedMeters,
    required this.summaryRows,
  });

  final ProductionMapDefinition map;
  final int? plannedMeters;
  final List<Widget> summaryRows;

  @override
  State<_OrderCalculationDetails> createState() =>
      _OrderCalculationDetailsState();
}

class _OrderCalculationDetailsState extends State<_OrderCalculationDetails> {
  CalculateOrderTemplate? _calculation;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final scope = currentSessionReadScope();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final calculation = await MobileApi.instance
          .adminProductionMapOrderSummary(widget.map.id);
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() {
        _calculation = calculation;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    String text(String key, [Map<String, Object> values = const {}]) =>
        l10n.productionText('worker.summary.$key', values: values);
    final calculation = _calculation;
    final plannedMeters = widget.plannedMeters;
    final showMicronVariants = calculation != null &&
        AppSession.instance.profile?.role == UserRole.admin &&
        calculation.effectiveLayers
            .any((layer) => layer.alternativeMicrons.isNotEmpty);
    final summaryRows = <Widget>[
      Text(
        text('expected.subtitle'),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
      ),
      const SizedBox(height: 6),
      if (showMicronVariants)
        _OrderMicronVariants(
          key: ValueKey(calculation),
          map: widget.map,
          template: calculation,
          plannedMeters: plannedMeters,
        )
      else if (plannedMeters != null)
        _orderSummaryLengthRow(context, plannedMeters),
      ...widget.summaryRows,
    ];
    if (_loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...summaryRows,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(text('calculation_loading')),
          ),
        ],
      );
    }
    if (_failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...summaryRows,
          const Divider(height: 24),
          Text(text('calculation_unavailable')),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(text('calculation_retry')),
          ),
        ],
      );
    }
    final products = calculation!.products;
    final layers = calculation.effectiveLayers;
    final width = widget.map.widthMm ?? calculation.widthMm;
    return Column(
      key: const ValueKey('production-order-calculation-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text('materials'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (layers.isEmpty)
          Text(text('materials_missing'))
        else
          for (var index = 0; index < layers.length; index++)
            AppInfoRow(
              label: text('layer', {'index': index + 1}),
              value: [
                if (layers[index].material.trim().isNotEmpty)
                  layers[index].material.trim(),
                if (layers[index].micron.trim().isNotEmpty)
                  text('micron_value', {'value': layers[index].micron.trim()}),
              ].join(' · '),
              icon: Icons.layers_outlined,
            ),
        if (width.isFinite && width > 0)
          AppInfoRow(
            label: text('material_width'),
            value: '${formatRawQuantity(width)} mm',
            icon: Icons.width_normal_outlined,
          ),
        const Divider(height: 24),
        ...summaryRows,
        AppInfoRow(
          label: text('waste_percent'),
          value: '${formatRawQuantity(calculation.wastePercent)} %',
          icon: Icons.percent_rounded,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            text('planned_explanation'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (products.isNotEmpty) ...[
          const Divider(height: 24),
          Text(text('product_frames'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final product in products)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.product,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(text('product_frame_value', {
                    'code': product.itemCode,
                    'count': product.frameCount,
                    'width': formatRawQuantity(product.frameProductSizeMm),
                  })),
                ],
              ),
            ),
        ],
        if (calculation.note.trim().isNotEmpty) ...[
          const Divider(height: 24),
          Text(text('note'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(calculation.note.trim()),
        ],
      ],
    );
  }
}

class _OrderMicronVariants extends StatefulWidget {
  const _OrderMicronVariants({
    super.key,
    required this.map,
    required this.template,
    required this.plannedMeters,
  });

  final ProductionMapDefinition map;
  final CalculateOrderTemplate template;
  final int? plannedMeters;

  @override
  State<_OrderMicronVariants> createState() => _OrderMicronVariantsState();
}

class _OrderMicronVariantsState extends State<_OrderMicronVariants> {
  var _otherVariants = const AsyncSnapshot<List<CalculateResult>>.nothing();

  Iterable<MapEntry<int, CalculateLayerInput>> get _changingLayers =>
      widget.template.effectiveLayers.asMap().entries.where(
            (entry) => entry.value.alternativeMicrons.isNotEmpty,
          );

  Map<int, int> get _plannedMicrons => {
        for (final entry in _changingLayers)
          if (entry.value.plannedMicron case final int micron)
            if (micron != int.tryParse(entry.value.micron.trim()))
              entry.key: micron,
      };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final request = _calculateRequestForOrder(
      map: widget.map,
      template: widget.template,
    );
    final count = _changingLayers.fold<int>(
          1,
          (total, entry) => total * (entry.value.alternativeMicrons.length + 1),
        ) -
        1;
    final scope = currentSessionReadScope();
    setState(
        () => _otherVariants = _otherVariants.inState(ConnectionState.waiting));
    try {
      final variants =
          await _calculateVariants(request, _plannedMicrons, count);
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _otherVariants =
          AsyncSnapshot.withData(ConnectionState.done, variants));
    } catch (error, stackTrace) {
      if (!mounted || scope != currentSessionReadScope()) return;
      setState(() => _otherVariants =
          AsyncSnapshot.withError(ConnectionState.done, error, stackTrace));
    }
  }

  Future<List<CalculateResult>> _calculateVariants(
    CalculateRequest request,
    Map<int, int> plannedMicrons,
    int count,
  ) async {
    final response = await MobileApi.instance.calculate(request);
    var hasPlan = false;
    final others = <CalculateResult>[];
    for (final result in response.results) {
      if (mapEquals(result.micronOverrides, plannedMicrons)) {
        hasPlan = true;
      } else if (!others.any((other) =>
          mapEquals(other.micronOverrides, result.micronOverrides))) {
        others.add(result);
      }
    }
    if (!response.ok ||
        !hasPlan ||
        others.length != count ||
        others.any((result) =>
            !result.roundedLength.isFinite || result.roundedLength <= 0)) {
      throw const FormatException('Incomplete order micron results');
    }
    return others;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final changingLayers = _changingLayers;
    String describe(Map<int, int> microns) {
      return changingLayers.map((entry) {
        final layer = l10n.productionText('worker.summary.layer',
            values: {'index': entry.key + 1});
        final micron = microns[entry.key] ?? entry.value.micron;
        return '$layer · ${entry.value.material} $micron µm';
      }).join('\n');
    }

    String length(int meters) => l10n.productionText(
          'worker.summary.length_value',
          values: {
            'value': MaterialLocalizations.of(context).formatDecimal(meters)
          },
        );
    final plannedMeters = widget.plannedMeters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInfoRow(
          label: l10n.productionText('worker.summary.current_micron_plan'),
          value: [
            if (plannedMeters != null) length(plannedMeters),
            describe(_plannedMicrons),
          ].join('\n'),
          icon: Icons.straighten_rounded,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.productionText('worker.summary.micron_variants'),
          key: const ValueKey('order-other-micron-variants'),
          style: theme.textTheme.titleSmall,
        ),
        if (_otherVariants.connectionState == ConnectionState.waiting)
          Text(l10n.loading)
        else if (_otherVariants.hasError) ...[
          Text(l10n
              .productionText('worker.summary.micron_variants_unavailable')),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => unawaited(_load()),
              child:
                  Text(l10n.productionText('worker.summary.calculation_retry')),
            ),
          ),
        ] else
          for (final variant
              in _otherVariants.data ?? const <CalculateResult>[])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(describe(variant.micronOverrides)),
              subtitle: Text(l10n.adminText(variant.micronOverrides.isEmpty
                  ? 'calculate.primary'
                  : 'calculate.micron_alternative')),
              trailing: Text(length(variant.roundedLength.round()),
                  style: theme.textTheme.titleSmall),
            ),
      ],
    );
  }
}
