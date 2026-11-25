part of 'preparation_production_screen.dart';

typedef _AttachedRolls = ({
  String code,
  List<String> receiptNames,
  String? batchId,
});

Future<_AttachedRolls?> _pickProductionPaddon(
  BuildContext context, {
  required bool Function() currentAccount,
  List<String> receiptNames = const [],
  String? batchId,
}) async {
  final result = await showDialog<_AttachedRolls>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProductionPaddonPicker(
      receiptNames: receiptNames,
      batchId: batchId,
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
    required this.batchId,
    required this.currentAccount,
  });

  final List<String> receiptNames;
  final String? batchId;
  final bool Function() currentAccount;

  @override
  State<_ProductionPaddonPicker> createState() =>
      _ProductionPaddonPickerState();
}

class _ProductionPaddonPickerState extends State<_ProductionPaddonPicker> {
  final _api = MobileApi.instance;
  final _paddons = <PreparationMaterialPaddon>[];
  PreparationPendingCommand? _pending;
  PreparationBatchPaddonSelection? _batchSelection;
  String? _selectedCode, _error;
  int? _nextOffset;
  bool _loading = false, _saving = false;

  bool get _current => mounted && widget.currentAccount();
  PreparationMaterialPaddon? get _selectedPaddon =>
      _paddons.where((paddon) => paddon.code == _selectedCode).firstOrNull;
  List<String> get _selectedReceipts => widget.batchId == null
      ? widget.receiptNames
      : _batchSelection?.receiptsFor(_selectedPaddon?.warehouse) ?? const [];

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

  Future<void> _load({int offset = 0}) async {
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
      final batchId = widget.batchId;
      final (page, selection) = batchId == null
          ? (
              await _api.preparationPaddonOptions(
                widget.receiptNames,
                offset: offset,
              ),
              null,
            )
          : await _api.preparationBatchPaddonOptions(batchId, offset: offset);
      if (!_current) return;
      setState(() {
        _batchSelection = selection;
        if (offset == 0) _paddons.clear();
        final known = _paddons.map((paddon) => paddon.code).toSet();
        _paddons.addAll(page.paddons.where((paddon) => known.add(paddon.code)));
        if (selection != null) {
          _paddons.removeWhere(
            (paddon) => selection.receiptsFor(paddon.warehouse).isEmpty,
          );
          if (_selectedPaddon == null) _selectedCode = null;
        }
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

  Future<void> _save() async {
    if (!_current || _loading || _saving) return;
    final pending = _pending;
    final code = pending?.payload['code'] as String? ?? _selectedCode;
    if (code == null) return;
    final names =
        (pending?.payload['receipt_names'] as List?)?.cast<String>() ??
            _selectedReceipts;
    if (names.isEmpty) return;
    final batchId = pending == null
        ? widget.batchId
        : pending.payload['batch_id'] as String?;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.attachPreparationRollsToPaddon(code, names, batchId: batchId);
      if (_current) {
        Navigator.of(context).pop(
          (code: code, receiptNames: names, batchId: batchId),
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
          if (widget.batchId != null && retry == null) {
            _batchSelection = null;
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

  Widget _batchSummary(PreparationBatchPaddonSelection selection) {
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
        UrduAwareText(
          '${selection.totalRolls} ta rulondan $count tasi '
          '${selected == null ? 'biriktirishga yaroqli' : 'biriktiriladi'}',
        ),
        for (final entry in selection.skipped.entries)
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
    final batch = _batchSelection;
    final nextOffset = _nextOffset;
    return PopScope(
      canPop: !_saving,
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
                if (batch != null)
                  _batchSummary(batch)
                else if (widget.batchId == null)
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
                    onTap: _loading || _saving
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
                    batch?.eligibleCount != 0)
                  UrduAwareText(
                    batch == null
                        ? 'Shu omborda paddon topilmadi.'
                        : 'Mos paddon topilmadi.',
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
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const UrduAwareText('Bekor qilish'),
          ),
          FilledButton(
            key: const ValueKey('production-attach-paddon-save'),
            onPressed: _loading ||
                    _saving ||
                    (pending == null &&
                        (_selectedCode == null || _selectedReceipts.isEmpty))
                ? null
                : _save,
            child: UrduAwareText(
              _saving
                  ? 'Biriktirilmoqda…'
                  : pending == null
                      ? 'Biriktirish'
                      : 'Natijani tekshirish',
            ),
          ),
        ],
      ),
    );
  }
}
