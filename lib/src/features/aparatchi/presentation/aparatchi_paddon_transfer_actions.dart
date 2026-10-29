part of 'aparatchi_paddon_transfer_screen.dart';

extension _PaddonTransferActions on _AparatchiPaddonTransferScreenState {
  Future<void> _reload() async {
    final generation = ++_generation;
    final scope = currentSessionReadScope();
    _updateState(() {
      _loading = true;
      _error = null;
      _selected.clear();
      _dragging = null;
    });
    try {
      final profile = AppSession.instance.profile;
      final catalog = await MobileApi.instance.adminApparatus(limit: 10000);
      if (!mounted || generation != _generation || !_isCurrentScope(scope)) {
        return;
      }
      final List<AdminPaddon> paddons;
      if (profile?.role == UserRole.aparatchi) {
        final assigned = assignedPaddonApparatus(
          catalog,
          profile!.assignedApparatus,
        );
        // Worker list reads remain scoped and authorized by the backend for
        // every assigned cutting apparatus, including the destination.
        final pages = await Future.wait(assigned.map((apparatus) async {
          final page = await MobileApi.instance.adminPaddons(
            limit: 200,
            selectableOnly: true,
            apparatus: apparatus.id,
          );
          return page.where((paddon) => paddon.apparatusId == apparatus.id);
        }));
        paddons = pages.expand((page) => page).toList();
      } else {
        paddons = await MobileApi.instance.adminPaddons(
          limit: 200,
          selectableOnly: true,
        );
      }
      if (!mounted || generation != _generation || !_isCurrentScope(scope)) {
        return;
      }
      final available = paddons.where((p) => !p.isLocked).toList();
      final codes = available.map((p) => p.code).toSet();
      final sourceCode = codes.contains(_source?.paddon.code)
          ? _source!.paddon.code
          : (available
                      .where(
                          (paddon) => paddon.apparatusId == widget.apparatusId)
                      .firstOrNull ??
                  available.firstOrNull)
              ?.code;
      final targetCode = codes.contains(_target?.paddon.code) &&
              _target?.paddon.code != sourceCode
          ? _target!.paddon.code
          : available.where((p) => p.code != sourceCode).firstOrNull?.code;
      final snapshots = await Future.wait([
        if (sourceCode != null)
          MobileApi.instance.adminPaddonQrReport(sourceCode),
        if (targetCode != null)
          MobileApi.instance.adminPaddonQrReport(targetCode),
      ]);
      if (!mounted || generation != _generation || !_isCurrentScope(scope)) {
        return;
      }
      _updateState(() {
        _apparatus = catalog;
        _paddons = available;
        _source = sourceCode == null ? null : snapshots.first;
        _target = targetCode == null ? null : snapshots.last;
        _loading = false;
      });
    } catch (error) {
      if (mounted && generation == _generation && _isCurrentScope(scope)) {
        _updateState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _pick(bool top) async {
    final scope = currentSessionReadScope();
    final generation = _generation;
    final other = top ? _target?.paddon.code : _source?.paddon.code;
    final picked = await showModalBottomSheet<AdminPaddon>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: ListView(children: [
          for (final paddon in _paddons.where((p) => p.code != other))
            ListTile(
              key: ValueKey('paddon-transfer-pick-${paddon.code}'),
              leading: const Icon(Icons.pallet),
              title: Text(paddon.code),
              subtitle: Text([
                _paddonLocation(paddon),
                '${paddon.itemCount} WIP',
              ].where((value) => value.isNotEmpty).join(' • ')),
              onTap: () => Navigator.of(context).pop(paddon),
            ),
        ]),
      ),
    );
    if (picked == null ||
        !mounted ||
        !_isCurrentScope(scope) ||
        generation != _generation) {
      return;
    }
    _updateState(() {
      _saving = true;
      _selected.clear();
    });
    try {
      final snapshot =
          await MobileApi.instance.adminPaddonQrReport(picked.code);
      if (!mounted || !_isCurrentScope(scope) || generation != _generation) {
        return;
      }
      if (!_editable(snapshot)) {
        throw MobileApiException(
            code: snapshot.paddon.isLocked
                ? 'paddon_locked'
                : !snapshot.canManageItems
                    ? 'paddon_already_received'
                    : 'paddon_transfer_forbidden',
            message: 'Paddon cannot be edited');
      }
      _updateState(() {
        if (top) {
          _source = snapshot;
        } else {
          _target = snapshot;
        }
      });
    } catch (error) {
      if (mounted && _isCurrentScope(scope)) {
        _showTransferError(error);
      }
    } finally {
      if (mounted && _isCurrentScope(scope) && generation == _generation) {
        _updateState(() => _saving = false);
      }
    }
  }

  Future<void> _move(List<String> ids,
      {required String from, required String to}) async {
    if (_saving ||
        ids.isEmpty ||
        from == to ||
        !_editable(_source) ||
        !_editable(_target)) {
      return;
    }
    final scope = currentSessionReadScope();
    final generation = _generation;
    _updateState(() => _saving = true);
    try {
      final confirmed = await showM3ConfirmDialog(
        context: context,
        title: _text('title'),
        message: _text('confirm',
            values: {'count': ids.length, 'source': from, 'target': to}),
        cancelLabel: context.l10n.productionText('worker.action.cancel'),
        confirmLabel: _text('move', values: {'count': ids.length}),
        confirmButtonKey: const ValueKey('paddon-transfer-confirm'),
      );
      if (confirmed != true ||
          !mounted ||
          !_isCurrentScope(scope) ||
          generation != _generation) {
        return;
      }
      await MobileApi.instance.transferPaddonItems(
          sourceCode: from, targetCode: to, progressBatchIds: ids);
      if (!mounted || !_isCurrentScope(scope)) {
        return;
      }
      await _reload();
      if (mounted && _isCurrentScope(scope)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_text('success'))));
      }
    } catch (error) {
      if (mounted && _isCurrentScope(scope)) {
        // A timeout may follow a committed transaction. Reload both sides and
        // require a fresh selection instead of replaying a stale transfer.
        await _reload();
        if (mounted && _isCurrentScope(scope)) {
          _showTransferError(error);
        }
      }
    } finally {
      if (mounted && _isCurrentScope(scope)) {
        _updateState(() => _saving = false);
      }
    }
  }

  void _showTransferError(Object error) {
    final fallback = _text('failed');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
      error is MobileApiException && error.code == 'paddon_transfer_forbidden'
          ? _text('forbidden')
          : error is MobileApiException
              ? context.l10n
                  .productionErrorMessage(error.code, fallback: fallback)
              : fallback,
    )));
  }
}
