part of 'qolip_products_screen.dart';

extension _QolipProductsReworks on _QolipProductsScreenState {
  Future<void> _sendSelectionToRework() async {
    if (_reworking || _deleting || _printing) return;
    final scope = currentSessionReadScope();
    if (_catalogScope != scope) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.qolipReworkText('session_changed'))));
      return;
    }
    final codes = <String, String>{
      for (final mold in _selectedProducts())
        mold.qolipCode.trim().toLowerCase(): mold.qolipCode.trim(),
    }.values.toList()
      ..sort();
    if (codes.isEmpty) return;
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: Text(l10n.qolipReworkText(
                  _selectionMode == _QolipSelectionMode.containers
                      ? 'send_sets'
                      : 'send_molds')),
              content: SingleChildScrollView(
                  child: Text(l10n.qolipReworkText('send_confirm', values: {
                'count': codes.length,
                'codes': codes.join(', ')
              }))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.qolipText('action.cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(l10n.qolipReworkText('send'))),
              ],
            ));
    if (!mounted || accepted != true) return;
    if (scope != currentSessionReadScope()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.qolipReworkText('session_changed'))));
      return;
    }
    final signature = codes.map((code) => code.toLowerCase()).join('\u0000');
    if (_reworkRequestSignature != signature) {
      _reworkRequestSignature = signature;
      _reworkRequestId = newQolipReworkRequestId();
    }
    _update(() => _reworking = true);
    try {
      await MobileApi.instance
          .qolipSendToRework(requestId: _reworkRequestId!, qolipCodes: codes);
      if (!mounted) return;
      _reworkRequestSignature = null;
      _reworkRequestId = null;
      QolipDataRevision.notifyLocationsChanged();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              l10n.qolipReworkText('sent', values: {'count': codes.length}))));
      await _reload(force: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(qolipErrorMessage(error,
                l10n: l10n, fallback: l10n.qolipReworkText('failed')))));
      }
    } finally {
      if (mounted) _update(() => _reworking = false);
    }
  }
}
