part of 'qolip_products_screen.dart';

extension _QolipProductsManagement on _QolipProductsScreenState {
  Future<void> _addQolip(QolipProduct product) async {
    final l10n = context.l10n;
    showAdminCreateHubSheet(
      context,
      actions: [
        AdminFabMenuAction(
          title: l10n.qolipManagementText('add'),
          icon: Icons.add_rounded,
          onTap: () => unawaited(_addProductMold(product)),
        ),
        AdminFabMenuAction(
          title: l10n.qolipManagementText('choose'),
          icon: Icons.layers_outlined,
          onTap: () => unawaited(_chooseProductSet(product)),
        ),
        AdminFabMenuAction(
          title: l10n.qolipManagementText('new_set'),
          icon: Icons.playlist_add_rounded,
          onTap: () => unawaited(
              _openQolipSpecSheet(initialProduct: product, lockProduct: true)),
        ),
      ],
    );
  }

  Future<void> _addProductMold(QolipProduct product) async {
    final existing = (_cachedProducts ?? const <QolipProduct>[])
        .where((m) => m.code.toLowerCase() == product.code.toLowerCase());
    final used = existing.map((m) => qolipPantonNumber(m.qolipColor)).toSet();
    final available = List.generate(qolipPantonMaxNumber, (i) => i + 1)
        .where((i) => !used.contains(i))
        .firstOrNull;
    final saved = await showQolipMoldAddDialog(
      context,
      scope:
          '${product.name}\n${context.l10n.qolipManagementText('product_scope')}',
      allowExisting: true,
      initialSize: existing.firstOrNull?.qolipSize ?? 0,
      availablePantonNumber: available,
      onSave: (draft) => MobileApi.instance.qolipAddProductMold(product, draft),
    );
    if (saved != true || !mounted) return;
    QolipDataRevision.notifyLocationsChanged();
    await _reload(force: false, preserveExpandedContainerKey: _catalogKeyForCode(product.code));
  }

  Future<void> _chooseProductSet(QolipProduct product) async {
    final selected = await showQolipSetPicker(context);
    if (selected == null || !mounted) return;
    try {
      final saved = await reuseSelectedQolipSet(context, selected.set, product);
      if (!mounted || saved == null) return;
      QolipDataRevision.notifyLocationsChanged();
      await _reload(force: false, preserveExpandedContainerKey: _catalogKeyForCode(product.code));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(qolipErrorMessage(error, l10n: context.l10n))));
      }
    }
  }
}
