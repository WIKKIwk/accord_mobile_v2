import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'qolip_color_picker.dart';

Future<List<QolipProduct>?> reuseSelectedQolipSet(
    BuildContext context, QolipSharedSet initial, QolipProduct product) async {
  var current = initial;
  var changed = false;
  while (true) {
    if (!context.mounted) return null;
    final l10n = context.l10n;
    final body = l10n.qolipSharedSetText('body', values: {
      'code': current.id,
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
        final needle = query.trim().toLowerCase();
        return sets
            .where((entry) =>
                entry.set.members.isNotEmpty &&
                [
                  entry.set.id,
                  ...entry.set.members.map((m) => m.qolipCode)
                ].any((value) => value.toLowerCase().contains(needle)))
            .skip(offset)
            .take(limit)
            .toList();
      },
      itemKey: (entry) => entry.set.id,
      itemTitle: (entry) => entry.set.id,
      itemSubtitle: (entry) => l10n.qolipText('products.mold_count',
          values: {'count': entry.set.members.length}),
      onSelected: (entry) => Navigator.of(sheetContext).pop(entry),
    ),
  );
}

Future<bool?> showQolipMoldAddDialog(
  BuildContext context, {
  required String scope,
  required Future<void> Function(QolipMoldDraft) onSave,
  bool allowExisting = false,
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
        initialSize: initialSize,
        availablePantonNumber: availablePantonNumber,
      ),
    );

class _MoldAddDialog extends StatefulWidget {
  const _MoldAddDialog({
    required this.scope,
    required this.onSave,
    required this.allowExisting,
    required this.initialSize,
    required this.availablePantonNumber,
  });
  final String scope;
  final Future<void> Function(QolipMoldDraft) onSave;
  final bool allowExisting;
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
    final validation = _code.text.trim().isEmpty
        ? 'code_required'
        : !_existing && (size <= 0 || size > 2147483647)
            ? 'size_required'
            : !_existing && _color == null
                ? 'color_required'
                : null;
    if (validation != null) {
      setState(() => _error = l10n.qolipManagementText(validation));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
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
                enabled: !_saving,
                autofocus: true,
                maxLength: 512,
                decoration: InputDecoration(
                    labelText: l10n.qolipText('products.code'),
                    counterText: '',
                    border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (_existing)
                Text(l10n.qolipManagementText('existing_hint'))
              else ...[
                TextField(
                  controller: _size,
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
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(l10n.qolipText('action.cancel')),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.qolipText('action.save')),
          ),
        ],
      ),
    );
  }
}
