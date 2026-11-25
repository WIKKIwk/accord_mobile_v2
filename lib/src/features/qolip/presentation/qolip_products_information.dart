part of 'qolip_products_screen.dart';

extension _QolipProductsInformation on _QolipProductsScreenState {
  Future<void> _openProductInformation(
    QolipProductContainer container, {
    bool edit = false,
  }) async {
    final scope = currentSessionReadScope();
    final id = container.catalogId;
    if (scope != _catalogScope || id == null) {
      return;
    }
    final saved = await showQolipProductInformationSheet(
      context,
      catalogId: id,
      productName: container.name,
      productCode: container.code,
      edit: edit,
    );
    if (!mounted || saved == null || scope != currentSessionReadScope()) return;
    QolipCatalogStore.instance.recordProductInformation(id, saved);
    if (_selectionMode != null) _cancelSelection();
    _update(() => _expandedContainerKey = id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.qolipInformationText('saved'))),
    );
  }
}
