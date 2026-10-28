import 'package:flutter/material.dart';

import '../../api/mobile_api.dart';
import '../../localization/app_localizations.dart';
import '../../session/session_read_scope.dart';

/// A combo identifies tooling for one layout; each row remains an output SKU.
class ProductionComboSummary extends StatelessWidget {
  const ProductionComboSummary(
      {super.key, required this.combo, required this.products});
  final ProductionComboReference combo;
  final List<OrderProduct> products;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Chip(
                  label: Text(
                      '${context.l10n.adminText('calculate.combo')} · v${combo.revision}')),
              Text(combo.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(combo.itemCode),
              if (products.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(context.l10n.adminText('calculate.combo_components')),
                for (final row in products)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          '${row.product} · ${row.itemCode} · ${row.frameProductSizeMm} mm × ${row.frameCount}')),
              ],
            ])),
      );
}

/// Catalog metadata is fetched by immutable revision SKU, without polling.
class ProductionComboCatalogSummary extends StatefulWidget {
  const ProductionComboCatalogSummary({super.key, required this.itemCode});
  final String itemCode;
  @override
  State<ProductionComboCatalogSummary> createState() =>
      _ProductionComboCatalogSummaryState();
}

class _ProductionComboCatalogSummaryState
    extends State<ProductionComboCatalogSummary> {
  late Future<ProductionComboCatalogEntry> _entry;
  Future<ProductionComboCatalogEntry> _load() async {
    final scope = currentSessionReadScope();
    final entry =
        await MobileApi.instance.adminProductionCombo(widget.itemCode);
    if (scope != currentSessionReadScope()) {
      throw StateError('Combo account changed');
    }
    return entry;
  }

  @override
  void initState() {
    super.initState();
    _entry = _load();
  }

  @override
  void didUpdateWidget(covariant ProductionComboCatalogSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCode != widget.itemCode) _entry = _load();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<ProductionComboCatalogEntry>(
          future: _entry,
          builder: (context, snapshot) {
            final value = snapshot.data;
            if (value != null) {
              return ProductionComboSummary(
                  combo: value.combo, products: value.template.products);
            }
            if (snapshot.hasError) {
              return TextButton.icon(
                  onPressed: () => setState(() => _entry = _load()),
                  icon: const Icon(Icons.refresh),
                  label: Text(
                      context.l10n.adminText('calculate.combo_load_failed')));
            }
            return const LinearProgressIndicator();
          });
}
