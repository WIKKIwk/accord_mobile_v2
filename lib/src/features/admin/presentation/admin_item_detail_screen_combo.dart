part of 'admin_item_detail_screen.dart';

class _ComboItemDetailView extends StatefulWidget {
  const _ComboItemDetailView({required this.detail});

  final AdminItemDetail detail;

  @override
  State<_ComboItemDetailView> createState() => _ComboItemDetailViewState();
}

class _ComboItemDetailViewState extends State<_ComboItemDetailView> {
  Future<ProductionComboCatalogEntry>? _entry;
  String _scope = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ComboItemDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.code != widget.detail.code) _load();
  }

  void _load() {
    final scope = currentSessionReadScope();
    _scope = scope;
    _entry = canReadProductionComboCatalog
        ? MobileApi.instance
            .adminProductionCombo(widget.detail.code)
            .then((entry) {
            if (scope != currentSessionReadScope()) {
              throw StateError('Combo account changed');
            }
            return entry;
          })
        : null;
  }

  void _showActions() {
    showModalBottomSheet<_ItemDetailAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ItemDetailActionsSheet(isCombo: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_scope != currentSessionReadScope()) _load();
    return FutureBuilder<ProductionComboCatalogEntry>(
      key: ValueKey('$_scope:${widget.detail.code}'),
      future: _entry,
      builder: (context, snapshot) {
        final detail = widget.detail;
        final entry = snapshot.data;
        final imageId = entry?.template.imageId.trim() ?? '';
        final imageUrl = imageId.isNotEmpty
            ? Uri(
                path: '/v1/mobile/calculate/orders/image/view',
                queryParameters: {'id': imageId},
              ).toString()
            : entry?.template.imageUrl.trim() ?? '';
        final l10n = context.l10n;
        return ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
          children: [
            _ItemDetailHeader(
              detail: detail,
              saving: false,
              disabled: true,
              onEdit: () {},
              comboImageUrl: imageUrl,
              onComboActions: _showActions,
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: const ValueKey('admin-combo-components'),
              child: _ItemDetailSection(
                title: l10n.adminText('calculate.combo_components'),
                children: [
                  if (_entry != null &&
                      snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    )
                  else if (_entry == null || snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextButton.icon(
                        onPressed:
                            _entry == null ? null : () => setState(_load),
                        icon: const Icon(Icons.refresh),
                        label:
                            Text(l10n.adminText('calculate.combo_load_failed')),
                      ),
                    )
                  else if (entry == null || entry.template.products.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                          l10n.adminText('calculate.combo_products_empty')),
                    )
                  else
                    for (var index = 0;
                        index < entry.template.products.length;
                        index++) ...[
                      if (index > 0) const Divider(height: 1),
                      _ComboItemProductRow(
                        index: index,
                        product: entry.template.products[index],
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            KeyedSubtree(
              key: const ValueKey('admin-combo-information'),
              child: _ItemDetailSection(
                title: l10n.adminText('detail.main_info'),
                children: [
                  _ItemDetailRow(
                    label: l10n.adminText('item.uom_label'),
                    value: detail.uom,
                  ),
                  const Divider(height: 1),
                  _ItemDetailRow(
                    label: l10n.adminText('detail.created_at'),
                    value: formatUnixSecondsLocalDateTime(detail.createdAtUnix),
                    emptyText: l10n.adminText('detail.date_missing'),
                  ),
                  _ItemDetailRow(
                    label: l10n.adminText('detail.updated_at'),
                    value: formatUnixSecondsLocalDateTime(detail.updatedAtUnix),
                    emptyText: l10n.adminText('detail.not_changed'),
                  ),
                  const Divider(height: 1),
                  _ItemDetailCustomers(customers: detail.customers),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _ItemDetailAction { rename, customers, group, delete }

class _ItemDetailActionsSheet extends StatelessWidget {
  const _ItemDetailActionsSheet({required this.isCombo});

  final bool isCombo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.adminText(isCombo
                    ? 'calculate.combo_actions'
                    : 'detail.item_actions'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isCombo) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.adminText('calculate.combo_actions_locked'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                key: ValueKey(isCombo
                    ? 'admin-combo-action-rename'
                    : 'admin-finished-action-rename'),
                enabled: !isCombo,
                onTap: isCombo
                    ? null
                    : () => Navigator.pop(context, _ItemDetailAction.rename),
                leading: const Icon(Icons.edit_rounded),
                title: Text(l10n.adminText(isCombo
                    ? 'calculate.combo_action_rename'
                    : 'detail.edit_name_code')),
              ),
              ListTile(
                key: ValueKey(isCombo
                    ? 'admin-combo-action-customers'
                    : 'admin-finished-action-customers'),
                enabled: !isCombo,
                onTap: isCombo
                    ? null
                    : () => Navigator.pop(context, _ItemDetailAction.customers),
                leading: const Icon(Icons.people_outline_rounded),
                title: Text(l10n.adminText('detail.manage_customers')),
              ),
              ListTile(
                key: ValueKey(isCombo
                    ? 'admin-combo-action-group'
                    : 'admin-finished-action-group'),
                enabled: !isCombo,
                onTap: isCombo
                    ? null
                    : () => Navigator.pop(context, _ItemDetailAction.group),
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(l10n.adminText('detail.change_group')),
              ),
              ListTile(
                key: ValueKey(isCombo
                    ? 'admin-combo-action-delete'
                    : 'admin-finished-action-delete'),
                enabled: !isCombo,
                onTap: isCombo
                    ? null
                    : () => Navigator.pop(context, _ItemDetailAction.delete),
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l10n.adminText('detail.item_delete_title')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemDetailImage extends StatelessWidget {
  const _ItemDetailImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
    return SizedBox.square(
      dimension: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: imageUrl.isEmpty
            ? placeholder
            : ImageFade(
                image: OrderImageProvider(imageUrl, thumbnail: true),
                fit: BoxFit.cover,
                width: 56,
                height: 56,
                placeholder: placeholder,
                errorBuilder: (_, __) => placeholder,
              ),
      ),
    );
  }
}

class _ComboItemProductRow extends StatefulWidget {
  const _ComboItemProductRow({required this.index, required this.product});

  final int index;
  final OrderProduct product;

  @override
  State<_ComboItemProductRow> createState() => _ComboItemProductRowState();
}

class _ComboItemProductRowState extends State<_ComboItemProductRow> {
  Future<String?>? _resolvedName;
  String _scope = '';

  @override
  void initState() {
    super.initState();
    _resolveName();
  }

  @override
  void didUpdateWidget(covariant _ComboItemProductRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.itemCode != widget.product.itemCode ||
        oldWidget.product.product != widget.product.product) {
      _resolveName();
    }
  }

  void _resolveName() {
    final scope = currentSessionReadScope();
    _scope = scope;
    final name = widget.product.product.trim();
    final code = widget.product.itemCode.trim();
    _resolvedName = code.isNotEmpty &&
            (name.isEmpty || name.toLowerCase() == code.toLowerCase())
        ? _loadName(code, scope)
        : null;
  }

  Future<String?> _loadName(String code, String scope) async {
    try {
      final detail = await MobileApi.instance.adminItemDetail(code);
      if (scope != currentSessionReadScope()) return null;
      final name = detail.name.trim();
      return name.isEmpty || name.toLowerCase() == code.toLowerCase()
          ? null
          : name;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scope != currentSessionReadScope()) _resolveName();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final product = widget.product;
    final name = product.product.trim();
    final knownName = name.isNotEmpty &&
            name.toLowerCase() != product.itemCode.trim().toLowerCase()
        ? name
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '${widget.index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  key: ValueKey(
                      '$_scope:${product.itemCode}:${product.product}'),
                  future: _resolvedName,
                  builder: (context, snapshot) => Text(
                    knownName ??
                        snapshot.data ??
                        (snapshot.connectionState == ConnectionState.waiting
                            ? context.l10n.loading
                            : context.l10n
                                .adminText('calculate.combo_product_unnamed')),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatRawQuantity(product.frameProductSizeMm)} mm × ${product.frameCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemDetailCustomers extends StatelessWidget {
  const _ItemDetailCustomers({required this.customers});

  final List<CustomerDirectoryEntry> customers;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (customers.isEmpty) {
      return _ItemDetailRow(
        label: l10n.adminText('detail.customer'),
        value: '',
        emptyText: l10n.adminText('detail.unassigned'),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              l10n.adminText(customers.length > 1
                  ? 'detail.customers'
                  : 'detail.customer'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final customer in customers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          customer.name,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (customer.ref.trim().isNotEmpty ||
                            customer.phone.trim().isNotEmpty)
                          Text(
                            [customer.ref, customer.phone]
                                .where((value) => value.trim().isNotEmpty)
                                .join(' • '),
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
