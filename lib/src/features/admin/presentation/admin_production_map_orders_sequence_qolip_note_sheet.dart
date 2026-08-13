part of 'admin_production_map_orders_screen.dart';

class _SequenceQolipOrderNoteSheet extends StatefulWidget {
  const _SequenceQolipOrderNoteSheet({required this.order});

  final ProductionMapSaved order;

  @override
  State<_SequenceQolipOrderNoteSheet> createState() =>
      _SequenceQolipOrderNoteSheetState();
}

class _SequenceQolipOrderNoteSheetState
    extends State<_SequenceQolipOrderNoteSheet> {
  AdminQolipOrderNoteDetails? _details;
  final Set<String> _selectedCodeKeys = {};
  String _error = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final details =
          await MobileApi.instance.adminProductionMapQolipOrderNoteDetails(
        orderId: widget.order.map.id,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _selectedCodeKeys
          ..clear()
          ..addAll(
            details.note?.qolipCodes
                    .map((code) => code.trim().toLowerCase())
                    .where((code) => code.isNotEmpty) ??
                const <String>[],
          );
        _loading = false;
        _error = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is MobileApiException
            ? error.message
            : context.l10n.adminText('production.qolip_load_failed');
      });
    }
  }

  List<String> _selectedCodes() {
    final details = _details;
    if (details == null) return const [];
    final givenCodeKeys = _givenCodeKeys;
    return [
      for (final item in details.requiredQolips)
        if ((givenCodeKeys.contains(item.qolipCode.trim().toLowerCase()) ||
                (!item.isInUse &&
                    _selectedCodeKeys.contains(
                      item.qolipCode.trim().toLowerCase(),
                    ))) &&
            item.qolipCode.trim().isNotEmpty)
          item.qolipCode.trim(),
    ];
  }

  Set<String> get _givenCodeKeys {
    final note = _details?.note;
    if (note?.isGiven != true) return const <String>{};
    return note!.qolipCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  void _toggle(String code, bool selected) {
    final key = code.trim().toLowerCase();
    if (key.isEmpty) return;
    setState(() {
      if (selected) {
        _selectedCodeKeys.add(key);
      } else {
        _selectedCodeKeys.remove(key);
      }
    });
  }

  Future<void> _saveGiven(List<String> codes) async {
    if (_saving || codes.isEmpty) return;
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
        orderId: widget.order.map.id,
        status: 'given',
        qolipCodes: codes,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is MobileApiException
            ? error.message
            : 'Qolip qaydi saqlanmadi';
      });
    }
  }

  Future<void> _saveReturned() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
        orderId: widget.order.map.id,
        status: 'returned',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is MobileApiException
            ? error.message
            : 'Qolip qaydi yangilanmadi';
      });
    }
  }

  Future<void> _addQolipForOrder() async {
    final details = _details;
    if (_saving || details == null) return;
    setState(() => _saving = true);
    try {
      final products = await MobileApi.instance.qolipProducts(
        query: details.itemCode,
        limit: 50,
      );
      QolipProduct? product;
      for (final candidate in products) {
        if (candidate.code.trim().toLowerCase() ==
            details.itemCode.trim().toLowerCase()) {
          product = candidate;
          break;
        }
      }
      if (!mounted) return;
      if (product == null) {
        setState(() {
          _error = context.l10n.adminText(
            'production.qolip_product_missing',
          );
        });
        return;
      }
      if (product.itemGroup.trim().isEmpty) {
        setState(() {
          _error = context.l10n.adminText(
            'production.qolip_group_missing',
          );
        });
        return;
      }
      await showQolipProductSpecSheet(
        context,
        initialProduct: product,
        closeAfterSave: true,
        lockProduct: true,
      );
      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is MobileApiException
            ? error.message
            : context.l10n.adminText('production.qolip_add_failed');
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = _details;
    final note = details?.note;
    final selectedCodes = _selectedCodes();
    final givenCodeKeys = _givenCodeKeys;
    final newSelectedCodes = selectedCodes
        .where((code) => !givenCodeKeys.contains(code.toLowerCase()))
        .toList(growable: false);
    final allAvailableCodes = details == null
        ? const <String>[]
        : [
            for (final item in details.requiredQolips)
              if (!item.isInUse ||
                  givenCodeKeys.contains(item.qolipCode.trim().toLowerCase()))
                item.qolipCode.trim(),
          ];
    final newAvailableCodes = allAvailableCodes
        .where((code) => !givenCodeKeys.contains(code.toLowerCase()))
        .toList(growable: false);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.adminText('production.qolip_title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.order.map.title.trim().isEmpty
                  ? widget.order.map.id
                  : widget.order.map.title.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.adminText('production.qolip_description'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (note != null) ...[
              const SizedBox(height: 10),
              _QolipOrderNoteStatusBanner(note: note),
            ],
            if (_error.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (_loading)
              const SizedBox(
                height: 160,
                child: Center(child: AppLoadingIndicator()),
              )
            else if (details == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.adminText('production.qolip_retry')),
                ),
              )
            else if (details.requiredQolips.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.adminText('production.qolip_empty'),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addQolipForOrder,
                icon: const Icon(Icons.add_box_outlined),
                label: Text(l10n.adminText('production.qolip_add')),
              ),
            ] else ...[
              if (details.requiredQolips.any((item) => item.isInUse)) ...[
                Text(
                  l10n.adminText('production.qolip_reserved'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                l10n.adminText('production.qolip_select'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in details.requiredQolips)
                CheckboxListTile(
                  value: givenCodeKeys
                          .contains(item.qolipCode.trim().toLowerCase()) ||
                      (!item.isInUse &&
                          _selectedCodeKeys.contains(
                            item.qolipCode.trim().toLowerCase(),
                          )),
                  onChanged: _saving ||
                          item.isInUse ||
                          givenCodeKeys.contains(
                            item.qolipCode.trim().toLowerCase(),
                          )
                      ? null
                      : (selected) => _toggle(
                            item.qolipCode,
                            selected ?? false,
                          ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.qolipCode),
                  subtitle: givenCodeKeys.contains(
                    item.qolipCode.trim().toLowerCase(),
                  )
                      ? Text(l10n.adminText('production.qolip_already_issued'))
                      : item.isInUse
                          ? Text(
                              l10n.adminText(
                                'production.qolip_reserved_other',
                              ),
                            )
                          : item.color.trim().isEmpty
                              ? null
                              : Text(
                                  l10n.adminText(
                                    'production.qolip_color',
                                    values: {'value': item.color.trim()},
                                  ),
                                ),
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving || newSelectedCodes.isEmpty
                    ? null
                    : () => _saveGiven(selectedCodes),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  newSelectedCodes.isEmpty
                      ? l10n.adminText('production.qolip_select_new')
                      : l10n.adminText('production.qolip_issued'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ||
                        details.requiredQolips.any((item) => item.isInUse) ||
                        newAvailableCodes.isEmpty
                    ? null
                    : () => _saveGiven(allAvailableCodes),
                icon: const Icon(Icons.done_all_rounded),
                label: Text(l10n.adminText('production.qolip_issue_all')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addQolipForOrder,
                icon: const Icon(Icons.add_box_outlined),
                label: Text(l10n.adminText('production.qolip_add')),
              ),
            ],
            if (note?.isGiven == true) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _saving ? null : _saveReturned,
                icon: const Icon(Icons.assignment_return_outlined),
                label: Text(l10n.adminText('production.qolip_returned')),
              ),
            ] else if (note?.isReturned == true) ...[
              const SizedBox(height: 14),
              Text(
                l10n.adminText('production.qolip_returned_note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QolipOrderNoteStatusBanner extends StatelessWidget {
  const _QolipOrderNoteStatusBanner({required this.note});

  final AdminQolipOrderNote note;

  @override
  Widget build(BuildContext context) {
    final given = note.isGiven;
    final color = given ? const Color(0xFF2E7D32) : const Color(0xFFF9A825);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              given ? Icons.check_circle_rounded : Icons.assignment_returned,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                given
                    ? context.l10n.adminText(
                        'production.qolip_given_banner',
                      )
                    : context.l10n.adminText(
                        'production.qolip_returned_banner',
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
