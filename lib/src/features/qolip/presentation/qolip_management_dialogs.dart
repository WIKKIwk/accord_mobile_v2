import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../qolip_set_search.dart';
import 'qolip_color_picker.dart';
import 'qolip_set_suggestions.dart';

Future<List<QolipProduct>?> reuseSelectedQolipSet(
    BuildContext context, QolipSharedSet initial, QolipProduct product,
    {String? setName}) async {
  var current = initial;
  var changed = false;
  while (true) {
    if (!context.mounted) return null;
    final l10n = context.l10n;
    final body = l10n.qolipSharedSetText('body', values: {
      'code': setName == null || setName.isEmpty
          ? current.id
          : '$setName (${current.id})',
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
        title: Text(l10n.qolipSharedSetText('title')),
        content: SingleChildScrollView(
            child: Text(
                '${changed ? '${l10n.qolipSharedSetText('changed')}\n\n' : ''}$body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.qolipSharedSetText('no')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.qolipSharedSetText('yes')),
          ),
        ],
      ),
    );
    if (accepted != true || !context.mounted) return null;
    try {
      return await MobileApi.instance
          .qolipReuseSet(set: current, product: product);
    } on MobileApiException catch (error) {
      if (error.code != 'qolip_set_changed') rethrow;
      final refreshed = await MobileApi.instance.qolipResolveSet(current.id);
      if (refreshed == null || refreshed.members.isEmpty) rethrow;
      current = refreshed;
      changed = true;
    }
  }
}

Future<({bool handled, List<QolipProduct>? products, String? setId})>
    reuseQolipSetInput(
  BuildContext context, {
  required QolipProduct product,
  required String identifier,
  required QolipSetLookup lookup,
  bool includeMoldCodes = true,
}) async {
  final sets = await lookup.load();
  if (!context.mounted) return (handled: true, products: null, setId: null);
  final needle = identifier.trim().toLowerCase();
  final moldMatches = sets
      .where((entry) => entry.set.members
          .any((mold) => mold.qolipCode.toLowerCase() == needle))
      .toList();
  // The existing-code tab adds one physical mold; set names/IDs reuse the set.
  if (!includeMoldCodes && moldMatches.isNotEmpty) {
    return (handled: false, products: null, setId: null);
  }
  var matches =
      sets.where((entry) => entry.set.id.toLowerCase() == needle).toList();
  if (matches.isEmpty && includeMoldCodes) matches = moldMatches;
  if (matches.isEmpty) {
    final name =
        identifier.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    matches = sets
        .where((entry) =>
            entry.name.isNotEmpty && entry.name.toLowerCase() == name)
        .toList();
  }
  if (matches.isEmpty) {
    matches = await searchQolipSets(sets, identifier,
        includeMoldCodes: includeMoldCodes);
  }
  if (!context.mounted || !lookup.isCurrent) {
    return (handled: true, products: null, setId: null);
  }
  if (matches.isEmpty) {
    if (!includeMoldCodes) return (handled: false, products: null, setId: null);
    final legacy = await MobileApi.instance.qolipResolveSet(identifier);
    if (legacy == null) return (handled: false, products: null, setId: null);
    if (!context.mounted || !lookup.isCurrent) {
      return (handled: true, products: null, setId: null);
    }
    final products = await reuseSelectedQolipSet(context, legacy, product);
    return (handled: true, products: products, setId: legacy.id);
  }
  final selected = matches.length == 1
      ? matches.single
      : await showQolipSetMatches(context, matches);
  if (!context.mounted || selected == null || !lookup.isCurrent) {
    return (handled: true, products: null, setId: null);
  }
  final products = await reuseSelectedQolipSet(context, selected.set, product,
      setName: selected.name);
  return (handled: true, products: products, setId: selected.set.id);
}

Future<QolipManagedSet?> showQolipSetPicker(BuildContext context) {
  Future<List<QolipManagedSet>>? future;
  final l10n = context.l10n;
  return showModalBottomSheet<QolipManagedSet>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => M3AsyncPickerSheet<QolipManagedSet>(
      title: l10n.qolipManagementText('choose'),
      hintText: l10n.qolipManagementText('search'),
      loadPage: (query, offset, limit) async {
        final sets = await (future ??= MobileApi.instance.qolipManagedSets());
        return (await searchQolipSets(sets, query))
            .skip(offset)
            .take(limit)
            .toList();
      },
      itemKey: (entry) => entry.set.id,
      itemTitle: (entry) => entry.displayName,
      itemSubtitle: (entry) => [
        if (entry.name.isNotEmpty) entry.set.id,
        l10n.qolipText('products.mold_count',
            values: {'count': entry.set.members.length}),
      ].join(' · '),
      onSelected: (entry) => Navigator.of(sheetContext).pop(entry),
    ),
  );
}

Future<bool?> showQolipMoldAddDialog(
  BuildContext context, {
  required String scope,
  required Future<void> Function(QolipMoldDraft) onSave,
  bool allowExisting = false,
  QolipProduct? product,
  int initialSize = 0,
  int? availablePantonNumber = 1,
}) =>
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MoldAddDialog(
        scope: scope,
        onSave: onSave,
        allowExisting: allowExisting,
        product: product,
        initialSize: initialSize,
        availablePantonNumber: availablePantonNumber,
      ),
    );

class _MoldAddDialog extends StatefulWidget {
  const _MoldAddDialog({
    required this.scope,
    required this.onSave,
    required this.allowExisting,
    required this.product,
    required this.initialSize,
    required this.availablePantonNumber,
  });
  final String scope;
  final Future<void> Function(QolipMoldDraft) onSave;
  final bool allowExisting;
  final QolipProduct? product;
  final int initialSize;
  final int? availablePantonNumber;

  @override
  State<_MoldAddDialog> createState() => _MoldAddDialogState();
}

class _MoldAddDialogState extends State<_MoldAddDialog> {
  final _code = TextEditingController();
  late final _size = TextEditingController(
      text: widget.initialSize > 0 ? '${widget.initialSize}' : '');
  String? _color;
  String? _error;
  bool _existing = false;
  bool _saving = false;
  bool _hasSetMatches = false;
  final _setLookup = QolipSetLookup();

  String? get _validationError {
    if (_code.text.trim().isEmpty) return 'code_required';
    if (_hasSetMatches) return null;
    return _moldValidationError;
  }

  String? get _moldValidationError {
    if (_code.text.trim().isEmpty) return 'code_required';
    if (_existing) return null;
    final size = int.tryParse(_size.text.trim()) ?? 0;
    if (size <= 0 || size > 2147483647) return 'size_required';
    if (_color == null) return 'color_required';
    return null;
  }

  @override
  void dispose() {
    _code.dispose();
    _size.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final size = int.tryParse(_size.text.trim()) ?? 0;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.product != null) {
        final result = await reuseQolipSetInput(context,
            product: widget.product!,
            identifier: _code.text,
            lookup: _setLookup,
            includeMoldCodes: false);
        if (!mounted) return;
        if (result.handled) {
          if (result.products != null) Navigator.of(context).pop(true);
          return;
        }
      }
      final validation = _moldValidationError;
      if (validation != null) {
        setState(() => _error = l10n.qolipManagementText(validation));
        return;
      }
      await widget.onSave(QolipMoldDraft(
          code: _code.text.trim(),
          existingOnly: _existing,
          size: _existing ? 0 : size,
          color: _existing ? '' : _color!));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = qolipErrorMessage(error, l10n: l10n));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reuseSuggestion(QolipManagedSet entry) async {
    if (_saving || widget.product == null || !_setLookup.isCurrent) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await reuseSelectedQolipSet(
          context, entry.set, widget.product!,
          setName: entry.name);
      if (mounted && saved != null) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _error = qolipErrorMessage(error, l10n: context.l10n));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.qolipManagementText('add')),
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 440),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.scope),
              const SizedBox(height: 16),
              if (widget.allowExisting) ...[
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false,
                        label: Text(l10n.qolipManagementText('new_code'))),
                    ButtonSegment(
                        value: true,
                        label: Text(l10n.qolipManagementText('existing_code'))),
                  ],
                  selected: {_existing},
                  onSelectionChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _existing = value.single;
                            _error = null;
                          }),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _code,
                onChanged: (_) => setState(() {
                  _error = null;
                  _hasSetMatches = false;
                }),
                enabled: !_saving,
                autofocus: true,
                maxLength: 512,
                decoration: InputDecoration(
                    labelText: l10n.qolipText('products.code'),
                    hintText: widget.product == null
                        ? null
                        : l10n.qolipManagementText('set_name_hint'),
                    counterText: '',
                    border: const OutlineInputBorder()),
              ),
              if (widget.product != null)
                QolipSetSuggestions(
                  controller: _code,
                  lookup: _setLookup,
                  enabled: !_saving,
                  includeMoldCodes: false,
                  onSelected: _reuseSuggestion,
                  onMatchesChanged: (matches) {
                    if (mounted && _hasSetMatches != matches) {
                      setState(() => _hasSetMatches = matches);
                    }
                  },
                ),
              const SizedBox(height: 12),
              if (_existing)
                Text(l10n.qolipManagementText('existing_hint'))
              else ...[
                TextField(
                  controller: _size,
                  onChanged: (_) => setState(() => _error = null),
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: l10n.qolipText('products.size'),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                QolipColorPicker(
                  selectedColor: _color,
                  enabled: !_saving,
                  availablePantonNumber: widget.availablePantonNumber,
                  onChanged: (value) => setState(() => _color = value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed:
                      !_saving && _validationError == null ? _save : null,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.qolipText('action.save')),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  child: Text(l10n.qolipText('action.cancel')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
