part of 'qolip_home_screen.dart';

extension _QolipAttachSharedSets on _QolipAttachSheetState {
  Future<void> _showSpecSaveError(String message) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          constraints: const BoxConstraints.tightFor(width: 420),
          title: Text(context.l10n.qolipText('home.save_failed')),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
            ),
          ],
        ),
      );

  Future<bool> _reuseExistingSet(
      QolipProduct product, String identifier) async {
    var set = await MobileApi.instance.qolipResolveSet(identifier);
    if (set == null) return false;
    var changed = false;
    while (mounted) {
      final current = set!;
      final l10n = context.l10n;
      final body = l10n.qolipSharedSetText('body', values: {
        'code': current.code.isEmpty ? current.id : current.code,
        'products': current.productLabels.join(', '),
        'count': current.members.length,
        'members': current.members
            .map((member) =>
                '${member.qolipCode} · ${member.qolipColor.isEmpty ? '—' : member.qolipColor} · ${member.qolipSize}')
            .join('\n'),
        'target': '${product.name} (${product.code})',
      });
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          constraints: const BoxConstraints.tightFor(width: 420),
          title: Text(l10n.qolipSharedSetText('title')),
          content: SingleChildScrollView(
              child: Text(
                  '${changed ? '${l10n.qolipSharedSetText('changed')}\n\n' : ''}$body')),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(l10n.qolipSharedSetText('yes')),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(l10n.qolipSharedSetText('no')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return true;
      try {
        final saved = await MobileApi.instance
            .qolipReuseSet(set: current, product: product);
        if (mounted)
          _finishSpecSave(
              product, saved, current.code.isEmpty ? current.id : current.code);
        return true;
      } on MobileApiException catch (error) {
        if (error.code != 'qolip_set_changed') rethrow;
        set = await MobileApi.instance.qolipResolveSet(current.id);
        if (set == null) rethrow;
        changed = true;
      }
    }
    return true;
  }

  void _finishSpecSave(
      QolipProduct product, List<QolipProduct> saved, String code) {
    if (saved.isEmpty) throw StateError('empty_qolip_set');
    setState(() {
      _product = product;
      _selectedProducts = [saved.first];
      _savedProductSpecs = saved;
      _qolipCode.text = code;
      _size.text = '${saved.first.qolipSize}';
      _specWarehouse = saved.first.warehouse;
      _selectedColors
        ..clear()
        ..addAll(saved
            .map((member) => member.qolipColor.trim().toUpperCase())
            .where((color) => color.isNotEmpty));
    });
    QolipDataRevision.notifyLocationsChanged();
    if (widget.closeAfterSave) Navigator.of(context).pop();
  }
}
