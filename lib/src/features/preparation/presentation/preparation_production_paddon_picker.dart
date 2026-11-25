part of 'preparation_production_screen.dart';

typedef _AttachedRolls = ({
  String code,
  List<String> receiptNames,
  List<String> batchIds,
});

Future<_AttachedRolls?> _pickProductionPaddon(
  BuildContext context, {
  required bool Function() currentAccount,
  List<String> receiptNames = const [],
  List<String> batchIds = const [],
}) async {
  final result = await showDialog<_AttachedRolls>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProductionPaddonPicker(
      receiptNames: receiptNames,
      batchIds: batchIds,
      currentAccount: currentAccount,
    ),
  );
  if (result != null && context.mounted && currentAccount()) {
    showAdminTopNotice(
      context,
      AppLocalizations.of(context).uiText(
        '${result.receiptNames.length} ta rulon ${result.code} paddoniga biriktirildi',
      ),
      tone: AdminTopNoticeTone.success,
    );
  }
  return result;
}

class _ProductionPaddonPicker extends StatefulWidget {
  const _ProductionPaddonPicker({
    required this.receiptNames,
    required this.batchIds,
    required this.currentAccount,
  });

  final List<String> receiptNames;
  final List<String> batchIds;
  final bool Function() currentAccount;

  @override
  State<_ProductionPaddonPicker> createState() =>
      _ProductionPaddonPickerState();
}

class _ProductionPaddonPickerState extends State<_ProductionPaddonPicker> {
  final _api = MobileApi.instance;
  final _paddons = <PreparationMaterialPaddon>[];
  PreparationPendingCommand? _pending;
  PreparationPaddonSelection? _selection;
  String? _selectedCode, _error;
  int? _nextOffset;
  bool _loading = false, _saving = false, _creatingPaddon = false;

  bool get _current => mounted && widget.currentAccount();
  bool get _fromBatches => widget.batchIds.isNotEmpty;
  PreparationMaterialPaddon? get _selectedPaddon =>
      _paddons.where((paddon) => paddon.code == _selectedCode).firstOrNull;
  List<String> get _selectedReceipts {
    if (_selection case final selection?) {
      return selection.receiptsFor(_selectedPaddon?.warehouse);
    }
    return _fromBatches ? const [] : widget.receiptNames;
  }

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_accountChanged);
    unawaited(_load());
  }

  void _accountChanged() {
    if (mounted && !_current && ModalRoute.isCurrentOf(context) == true) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_accountChanged);
    super.dispose();
  }

  Future<void> _load({int offset = 0, String? selectCode}) async {
    if (!_current || _loading || _saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (offset == 0) {
        final pending = await _api.pendingPreparationPaddonAttachment();
        if (!_current) return;
        if (pending != null) {
          setState(() => _pending = pending);
          return;
        }
      }
      final (page, selection) = _fromBatches
          ? await _api.preparationBatchPaddonOptions(widget.batchIds, offset: offset)
          : await _api.preparationPaddonOptions(widget.receiptNames, offset: offset);
      if (!_current) return;
      final created = selectCode != null &&
              page.hasMore &&
              !page.paddons.any((paddon) => paddon.code == selectCode)
          ? await _api.materialPaddonByCode(selectCode)
          : null;
      if (!_current) return;
      setState(() {
        _selection = selection;
        if (offset == 0) _paddons.clear();
        final known = _paddons.map((paddon) => paddon.code).toSet();
        _paddons.addAll(page.paddons.where((paddon) => known.add(paddon.code)));
        if (created != null && known.add(created.code)) _paddons.add(created);
        if (selection != null) {
          _paddons.removeWhere(
            (paddon) => selection.receiptsFor(paddon.warehouse).isEmpty,
          );
        }
        if (selectCode != null && _paddons.any((paddon) => paddon.code == selectCode)) {
          _selectedCode = selectCode;
        }
        if (_selectedPaddon == null) _selectedCode = null;
        _nextOffset = page.nextOffset;
      });
    } catch (error) {
      if (_current) {
        setState(() {
          _error = error is MobileApiException
              ? error.message
              : 'Mos paddonlar yuklanmadi';
        });
      }
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  Future<void> _openEmptyPaddon(String warehouse) async {
    if (!_current || _loading || _saving || _creatingPaddon) return;
    setState(() => _creatingPaddon = true);
    try {
      final result = await showMaterialPaddonReceipt(
        context,
        emptyWarehouse: warehouse,
      );
      if (!_current || result == null) return;
      await _load(
        selectCode: result.empty && result.warehouse == warehouse
            ? result.code
            : null,
      );
    } finally {
      if (_current) setState(() => _creatingPaddon = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _loading || _saving || _creatingPaddon) return;
    final pending = _pending;
    final code = pending?.payload['code'] as String? ?? _selectedCode;
    if (code == null) return;
    final names =
        (pending?.payload['receipt_names'] as List?)?.cast<String>() ??
            _selectedReceipts;
    if (names.isEmpty) return;
    final batchIds = switch (pending?.payload) {
      null => widget.batchIds,
      {'batch_ids': final List ids} => ids.cast<String>(),
      {'batch_id': final String id} => [id],
      _ => const <String>[],
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.attachPreparationRollsToPaddon(code, names, batchIds: batchIds);
      if (_current) {
        Navigator.of(context).pop(
          (code: code, receiptNames: names, batchIds: batchIds),
        );
      }
    } catch (error) {
      if (!_current) return;
      final retry = await _api
          .pendingPreparationPaddonAttachment()
          .onError((_, __) => null);
      if (_current) {
        setState(() {
          _pending = retry;
          if (retry == null) {
            _selection = null;
            _paddons.clear();
            _selectedCode = null;
            _nextOffset = null;
          }
          _error = error is MobileApiException
              ? error.message
              : 'Biriktirish natijasini qayta tekshiring';
        });
      }
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  Widget _packedRolls(int count, List<PreparationPackedRoll> rolls) =>
      ExpansionTile(
        key: const ValueKey('production-attach-packed-rolls'),
        tilePadding: EdgeInsets.zero,
        title: UrduAwareText('$count ta rulon allaqachon paddonda'),
        children: [
          for (final roll in rolls)
            ListTile(
              title: UrduAwareText(roll.barcode),
              subtitle: (roll.paddonName.isNotEmpty || roll.paddonCode.isNotEmpty)
                  ? UrduAwareText([
                      roll.paddonName,
                      roll.paddonCode,
                    ].where((part) => part.isNotEmpty).join(' • '))
                  : null,
            ),
        ],
      );

  Widget _selectionSummary(PreparationPaddonSelection selection) {
    if (selection.totalRolls == 0) {
      return const UrduAwareText('Hali rulon kirim qilinmagan.');
    }
    final selected = _selectedPaddon;
    final count = selected == null
        ? selection.eligibleCount
        : selection.receiptsFor(selected.warehouse).length;
    final elsewhere = selection.eligibleCount - count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selection.batchIds.length > 1)
          UrduAwareText('${selection.batchIds.length} ta batch tanlandi'),
        UrduAwareText(
          '${selection.totalRolls} ta rulondan $count tasi '
          '${selected == null ? 'biriktirishga yaroqli' : 'biriktiriladi'}',
        ),
        for (final entry in selection.skipped.entries)
          if (entry.key == 'packed' && selection.packedRolls.isNotEmpty)
            _packedRolls(entry.value, selection.packedRolls)
          else
            UrduAwareText('${entry.value} ta ${switch (entry.key) {
              'missing' => 'rulon omborda topilmadi',
              'packed' => 'rulon allaqachon paddonda',
              'consumed' => 'rulon kesilgan yoki sarflangan',
              'outside_warehouse' => 'rulon ko‘chirilmoqda yoki boshqa joyda',
              _ => 'rulon band yoki biriktirib bo‘lmaydi',
            }}'),
        if (elsewhere > 0) UrduAwareText('$elsewhere ta rulon boshqa omborda'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final selection = _selection;
    final nextOffset = _nextOffset;
    final partial = selection != null &&
        _selectedPaddon != null &&
        _selectedReceipts.length < selection.totalRolls;
    return PopScope(
      canPop: !_saving && !_creatingPaddon,
      child: AlertDialog(
        title: const UrduAwareText('Paddonga biriktirish'),
        scrollable: true,
        constraints: const BoxConstraints(maxWidth: 460),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pending != null)
                UrduAwareText(
                  '${pending.payload['code']} paddoniga biriktirish natijasini tekshiring.',
                )
              else ...[
                if (selection != null)
                  _selectionSummary(selection)
                else if (!_fromBatches)
                  UrduAwareText(
                    '${widget.receiptNames.length} ta tanlangan rulon',
                  ),
                const SizedBox(height: 8),
                for (final paddon in _paddons)
                  ListTile(
                    key: ValueKey('production-attach-paddon-${paddon.code}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _selectedCode == paddon.code
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    selected: _selectedCode == paddon.code,
                    title: UrduAwareText(paddon.title),
                    subtitle: UrduAwareText([
                      paddon.warehouse,
                      if (paddon.name.isNotEmpty) paddon.code,
                      materialPaddonBalance(paddon),
                    ].join(' • ')),
                    onTap: _loading || _saving || _creatingPaddon
                        ? null
                        : () => setState(() => _selectedCode = paddon.code),
                  ),
                if (_loading)
                  const Center(child: AppLoadingIndicator())
                else if (nextOffset != null)
                  TextButton(
                    onPressed: _saving ? null : () => _load(offset: nextOffset),
                    child: const UrduAwareText('Yana yuklash'),
                  )
                else if (_error == null &&
                    _paddons.isEmpty &&
                    selection?.eligibleCount != 0)
                  UrduAwareText(
                    selection == null
                        ? 'Shu omborda paddon topilmadi.'
                        : 'Mos paddon topilmadi.',
                  ),
                if (!_loading && _error == null && nextOffset == null &&
                    selection != null)
                  for (final entry in selection.receiptNamesByWarehouse.entries)
                    if (entry.value.isNotEmpty &&
                        !_paddons.any((paddon) => paddon.warehouse == entry.key))
                      ListTile(
                        key: ValueKey('production-open-paddon-${entry.key}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_rounded),
                        title: const UrduAwareText('Bo‘sh paddon ochish'),
                        subtitle: UrduAwareText(
                          '${entry.key} • ${entry.value.length} ta rulon',
                        ),
                        onTap: _saving || _creatingPaddon
                            ? null
                            : () => _openEmptyPaddon(entry.key),
                      ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 8),
                UrduAwareText(error,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                if (pending == null && _paddons.isEmpty)
                  TextButton(
                    onPressed: _loading || _saving ? null : () => _load(),
                    child: const UrduAwareText('Qayta urinish'),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving || _creatingPaddon
                ? null
                : () => Navigator.of(context).pop(),
            child: const UrduAwareText('Bekor qilish'),
          ),
          FilledButton(
            key: const ValueKey('production-attach-paddon-save'),
            onPressed: _loading ||
                    _saving ||
                    _creatingPaddon ||
                    (pending == null &&
                        (_selectedCode == null || _selectedReceipts.isEmpty))
                ? null
                : _save,
            child: UrduAwareText(
              _saving
                  ? 'Biriktirilmoqda…'
                  : pending != null
                      ? 'Natijani tekshirish'
                      : partial
                          ? 'Yaroqli rulonlarni biriktirish'
                          : 'Biriktirish',
            ),
          ),
        ],
      ),
    );
  }
}
