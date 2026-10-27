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
    final result = await reuseQolipSetInput(context,
        product: product, identifier: identifier, lookup: _setLookup);
    if (mounted && result.products != null) {
      _finishSpecSave(product, result.products!, result.setId!);
    }
    return result.handled;
  }

  Future<void> _reuseSuggestedSet(QolipManagedSet entry) async {
    final product = _product;
    if (_saving || product == null || !_setLookup.isCurrent) return;
    FocusScope.of(context).unfocus();
    _update(() => _saving = true);
    try {
      final saved = await reuseSelectedQolipSet(context, entry.set, product,
          setName: entry.name);
      if (mounted && saved != null) {
        _finishSpecSave(product, saved, entry.set.id);
      }
    } catch (error) {
      if (mounted) {
        await _showSpecSaveError(qolipErrorMessage(error, l10n: context.l10n));
      }
    } finally {
      _update(() => _saving = false);
    }
  }

  void _finishSpecSave(
      QolipProduct product, List<QolipProduct> saved, String code) {
    if (saved.isEmpty) throw StateError('empty_qolip_set');
    _update(() {
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
