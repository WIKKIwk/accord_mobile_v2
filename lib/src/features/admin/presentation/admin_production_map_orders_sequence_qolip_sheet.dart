part of 'admin_production_map_orders_screen.dart';

class _SequenceQolipSheet extends StatefulWidget {
  const _SequenceQolipSheet({required this.order});
  final ProductionMapSaved order;

  @override
  State<_SequenceQolipSheet> createState() => _SequenceQolipSheetState();
}

class _SequenceQolipSheetState extends State<_SequenceQolipSheet> {
  List<QolipProduct> _qolips = const [];
  String _error = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final itemCode = widget.order.map.productCode.trim();
      final products = itemCode.isEmpty
          ? const <QolipProduct>[]
          : await MobileApi.instance.qolipProducts(
              query: itemCode,
              limit: 200,
              withQolipOnly: true,
            );
      final seen = <String>{};
      final qolips = [
        for (final product in products)
          if (product.code.trim().toLowerCase() == itemCode.toLowerCase() &&
              product.qolipCode.trim().isNotEmpty &&
              seen.add(product.qolipCode.trim().toLowerCase()))
            product,
      ]..sort(
          (left, right) => left.qolipCode
              .toLowerCase()
              .compareTo(right.qolipCode.toLowerCase()),
        );
      if (!mounted) return;
      setState(() {
        _qolips = qolips;
        _loading = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MobileApiException
            ? error.message
            : context.l10n.adminText('production.qolip_load_failed');
      });
    }
  }

  Future<void> _addQolipForOrder() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final products = await MobileApi.instance.qolipProducts(
        query: widget.order.map.productCode,
        limit: 50,
      );
      QolipProduct? product;
      for (final candidate in products) {
        if (candidate.code.trim().toLowerCase() ==
            widget.order.map.productCode.trim().toLowerCase()) {
          product = candidate;
          break;
        }
      }
      if (!mounted) return;
      if (product == null) {
        setState(() {
          _error = context.l10n.adminText('production.qolip_product_missing');
        });
        return;
      }
      if (product.itemGroup.trim().isEmpty) {
        setState(() {
          _error = context.l10n.adminText('production.qolip_group_missing');
        });
        return;
      }
      await showQolipProductSpecSheet(
        context,
        initialProduct: product,
        closeAfterSave: true,
        lockProduct: true,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is MobileApiException
            ? error.message
            : context.l10n.adminText('production.qolip_add_failed');
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.adminText('production.qolip_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.order.map.title.trim().isEmpty
                  ? widget.order.map.id
                  : widget.order.map.title.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.adminText('production.qolip_description'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (_error.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loading)
              const SizedBox(
                height: 160,
                child: Center(child: AppLoadingIndicator()),
              )
            else if (_qolips.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.adminText('production.qolip_empty')),
              ),
            ] else ...[
              for (final qolip in _qolips)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      qolip.isInUse
                          ? Icons.precision_manufacturing_rounded
                          : Icons.inventory_2_outlined,
                      color: qolip.isInUse
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(
                      qolip.qolipCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (qolip.qolipColor.trim().isNotEmpty)
                          qolip.qolipColor.trim(),
                        if (qolip.qolipSize > 0) '${qolip.qolipSize}',
                      ].join(' • '),
                    ),
                    trailing: Text(
                      l10n.adminText(
                        qolip.isInUse
                            ? 'production.qolip_in_use'
                            : 'production.qolip_available',
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: qolip.isInUse
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _addQolipForOrder,
              icon: const Icon(Icons.add_box_outlined),
              label: Text(l10n.adminText('production.qolip_add')),
            ),
          ],
        ),
      ),
    );
  }
}
