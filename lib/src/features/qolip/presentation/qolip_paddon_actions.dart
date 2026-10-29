part of 'qolip_storage_screen.dart';

enum _PaddonMenuAction { add, delete }

extension _QolipStoragePaddonActions on _QolipStorageScreenState {
  bool get _paddonSessionIsCurrent =>
      mounted && !_sessionExpired && _scope == currentSessionReadScope();

  bool get _paddonPageIsCurrent =>
      _paddonSessionIsCurrent && ModalRoute.of(context)?.isCurrent == true;

  Future<void> _paddonActions(QolipPaddon paddon) async {
    if (_saving || !_paddonPageIsCurrent) return;
    final action = await showModalBottomSheet<_PaddonMenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _StorageOverlay(
        scope: _scope,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('qolip-paddon-menu-add'),
                leading: const Icon(Icons.playlist_add_rounded),
                title: Text(_s(sheetContext, 'add')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PaddonMenuAction.add),
              ),
              ListTile(
                key: const ValueKey('qolip-paddon-menu-delete'),
                leading: Icon(Icons.delete_outline_rounded,
                    color: Theme.of(sheetContext).colorScheme.error),
                title: Text(context.l10n.qolipText('action.delete'),
                    style: TextStyle(
                        color: Theme.of(sheetContext).colorScheme.error)),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PaddonMenuAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !_paddonPageIsCurrent) return;
    switch (action) {
      case _PaddonMenuAction.add:
        await _open(paddon.code, addMolds: true);
      case _PaddonMenuAction.delete:
        await _deletePaddon(paddon);
    }
  }

  Future<void> _deletePaddon(QolipPaddon paddon) async {
    if (_saving || !_paddonPageIsCurrent) return;
    final pending = _pendingPaddonDeletes[paddon.code];
    Map<String, dynamic> body;
    if (pending == null) {
      QolipPaddonDetail current;
      setState(() => _saving = true);
      try {
        current = await MobileApi.instance.qolipPaddonDetail(paddon.code);
      } catch (error) {
        if (!_paddonSessionIsCurrent) return;
        if (error is MobileApiException && error.statusCode == 404) {
          await _removeMissingPaddon(paddon.code);
        } else if (_paddonPageIsCurrent) {
          _error(context, error);
        }
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      if (!_paddonPageIsCurrent) return;
      if (current.paddon.itemCount != 0 || current.items.isNotEmpty) {
        _message(context, _s(context, 'paddon_not_empty'));
        if (current.paddon.revision != paddon.revision ||
            current.paddon.itemCount != paddon.itemCount) {
          await _load();
        }
        return;
      }
      if (current.paddon.archived) {
        _message(context, _s(context, 'archived_error'));
        await _load();
        return;
      }
      body = <String, dynamic>{
        'action': 'delete',
        'code': paddon.code,
        'expected_revision': current.paddon.revision,
      };
    } else {
      body = pending;
    }
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: _s(context, 'delete_paddon_title'),
      message: '${paddon.code}\n\n${_s(context, 'delete_paddon_confirm')}',
      cancelLabel: _s(context, 'cancel'),
      confirmLabel: context.l10n.qolipText('action.delete'),
      destructive: true,
      verticalActions: true,
      confirmButtonKey: const ValueKey('qolip-paddon-delete-confirm'),
      cancelButtonKey: const ValueKey('qolip-paddon-delete-cancel'),
    );
    if (confirmed != true || !_paddonPageIsCurrent) return;
    if (pending == null) {
      body['request_id'] = QolipStorageIntent().keyFor(body);
      _pendingPaddonDeletes[paddon.code] = body;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.qolipDeletePaddon(body);
      _pendingPaddonDeletes.remove(paddon.code);
      if (!_paddonSessionIsCurrent) return;
      setState(() => _paddons.removeWhere((item) => item.code == paddon.code));
      if (_paddonPageIsCurrent) _message(context, _s(context, 'paddon_deleted'));
      await _load();
    } catch (error) {
      if (!_paddonSessionIsCurrent) return;
      if (error is MobileApiException && error.statusCode == 404) {
        await _removeMissingPaddon(paddon.code);
        return;
      }
      if (error is MobileApiException && error.statusCode == 409) {
        _pendingPaddonDeletes.remove(paddon.code);
      }
      if (_paddonPageIsCurrent) _error(context, error);
      if (error is MobileApiException && error.statusCode == 409) {
        await _load();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeMissingPaddon(String code) async {
    if (!_paddonSessionIsCurrent) return;
    _pendingPaddonDeletes.remove(code);
    setState(() => _paddons.removeWhere((item) => item.code == code));
    if (_paddonPageIsCurrent) {
      _message(context, context.l10n.productionText('worker.paddon.not_found'));
    }
    await _load();
  }
}
