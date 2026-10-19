part of 'admin_production_map_orders_screen.dart';

class _OrderCalculationDetails extends StatefulWidget {
  const _OrderCalculationDetails({required this.map});

  final ProductionMapDefinition map;

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
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text('calculation_loading')),
      );
    }
    if (_failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    final calculation = _calculation!;
    final products = calculation.products;
    final frameCount = products.isEmpty
        ? calculation.frameCount
        : products
            .fold<int>(0, (sum, product) => sum + product.frameCount)
            .toDouble();
    final layers = calculation.effectiveLayers;
    final width = widget.map.widthMm ?? calculation.widthMm;
    return Column(
      key: const ValueKey('production-order-calculation-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (width.isFinite && width > 0)
          AppInfoRow(
            label: text('material_width'),
            value: '${formatRawQuantity(width)} mm',
            icon: Icons.width_normal_outlined,
          ),
        if (frameCount.isFinite && frameCount > 0)
          AppInfoRow(
            label: text('frame_count'),
            value: text('frame_count_value', {
              'count': formatRawQuantity(frameCount),
            }),
            icon: Icons.view_week_outlined,
          ),
        if (products.isEmpty && calculation.frameProductSizeMm > 0)
          AppInfoRow(
            label: text('frame_width'),
            value: '${formatRawQuantity(calculation.frameProductSizeMm)} mm',
            icon: Icons.straighten_rounded,
          ),
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
        const Divider(height: 24),
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
