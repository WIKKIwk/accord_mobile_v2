part of 'preparation_production_screen.dart';

typedef _AttachedRolls = ({String code, List<String> receiptNames});

class _ProductionPaddonPicker extends StatefulWidget {
  const _ProductionPaddonPicker({
    required this.receiptNames,
    required this.currentAccount,
  });

  final List<String> receiptNames;
  final bool Function() currentAccount;

  @override
  State<_ProductionPaddonPicker> createState() =>
      _ProductionPaddonPickerState();
}

class _ProductionPaddonPickerState extends State<_ProductionPaddonPicker> {
  final _api = MobileApi.instance;
  final _paddons = <PreparationMaterialPaddon>[];
  PreparationPendingCommand? _pending;
  String? _selectedCode, _error;
  int? _nextOffset;
  bool _loading = false, _saving = false;

  bool get _current => mounted && widget.currentAccount();

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
      final page = await _api.preparationPaddonOptions(
        widget.receiptNames,
        offset: offset,
      );
      if (!_current) return;
      setState(() {
        if (offset == 0) _paddons.clear();
        final known = _paddons.map((paddon) => paddon.code).toSet();
        _paddons.addAll(page.paddons.where((paddon) => known.add(paddon.code)));
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
            widget.receiptNames;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _api.attachPreparationRollsToPaddon(code, names);
      if (_current) {
        Navigator.of(context).pop((code: code, receiptNames: names));
      }
    } catch (error) {
      if (!_current) return;
      final retry = await _api
          .pendingPreparationPaddonAttachment()
          .onError((_, __) => null);
      if (_current) {
        setState(() {
          _pending = retry;
          _error = error is MobileApiException
              ? error.message
              : 'Biriktirish natijasini qayta tekshiring';
        });
      }
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
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
                UrduAwareText(
                    '${widget.receiptNames.length} ta tanlangan rulon'),
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
                else if (_error == null && _paddons.isEmpty)
                  const UrduAwareText('Shu omborda paddon topilmadi.')
                else if (nextOffset != null)
                  TextButton(
                    onPressed: _saving ? null : () => _load(offset: nextOffset),
                    child: const UrduAwareText('Yana yuklash'),
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
                    (pending == null && _selectedCode == null)
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
