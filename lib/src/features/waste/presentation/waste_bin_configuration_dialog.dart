import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/forms/app_input_decoration.dart';
import 'waste_bin_details.dart';

class WasteBinFormResult {
  const WasteBinFormResult({
    required this.code,
    required this.tareKg,
    required this.toleranceKg,
    required this.configuration,
  });

  final String code;
  final double tareKg;
  final double? toleranceKg;
  final WasteBinConfiguration configuration;
}

class WasteBinConfigurationDialog extends StatefulWidget {
  const WasteBinConfigurationDialog({
    super.key,
    required this.options,
    this.bin,
  });

  final WasteBinOptions options;
  final WasteBin? bin;

  @override
  State<WasteBinConfigurationDialog> createState() =>
      _WasteBinConfigurationDialogState();
}

class _WasteBinConfigurationDialogState
    extends State<WasteBinConfigurationDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bin?.name);
  late final _code = TextEditingController(text: widget.bin?.code);
  final _tare = TextEditingController();
  final _tolerance = TextEditingController();
  late final _apparatusNames = {
    for (final option in widget.options.apparatuses) option.id: option.name,
  };
  late Set<String> _apparatus = {
    for (final id in widget.bin?.apparatusIds ?? const <String>[])
      if (_apparatusNames.containsKey(id)) id,
  };
  late Set<WasteBinOperatorRef> _operators = {
    for (final option in _eligibleOperators)
      if (widget.bin?.operators.contains(option.identity) ?? false)
        option.identity,
  };
  String? _scopeError;

  List<WasteBinOperatorOption> get _eligibleOperators =>
      widget.options.operators
          .where((option) => option.apparatusIds.any(_apparatus.contains))
          .toList(growable: false);

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _tare.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  Future<void> _pickApparatus() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _WasteScopePicker(
        title: 'Apparatlarni tanlash',
        options: [
          for (final option in widget.options.apparatuses)
            _WasteScopeOption(option.id, option.name),
        ],
        selected: _apparatus,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _apparatus = selected;
      final allowed = _eligibleOperators.map((operator) => operator.identity);
      _operators = _operators.where(allowed.contains).toSet();
      _scopeError = null;
    });
  }

  Future<void> _pickOperators() async {
    final selected = await showDialog<Set<WasteBinOperatorRef>>(
      context: context,
      builder: (_) => _WasteScopePicker(
        title: 'Aparatchilarni tanlash',
        options: [
          for (final operator in _eligibleOperators)
            _WasteScopeOption(
              operator.identity,
              operator.displayName,
              subtitle: _operatorApparatus(operator).join(', '),
            ),
        ],
        selected: _operators,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _operators = selected;
      _scopeError = null;
    });
  }

  Iterable<String> _operatorApparatus(WasteBinOperatorOption operator) =>
      operator.apparatusIds
          .where(_apparatus.contains)
          .map((id) => _apparatusNames[id] ?? id);

  void _save() {
    final validForm = _form.currentState!.validate();
    String? error;
    if (_apparatus.isEmpty) {
      error = 'Kamida bitta apparatni tanlang.';
    } else if (_operators.isEmpty) {
      error = 'Aparatchini tanlang.';
    } else {
      final covered = {
        for (final option in _eligibleOperators)
          if (_operators.contains(option.identity)) ...option.apparatusIds,
      };
      final missing = _apparatus
          .where((id) => !covered.contains(id))
          .map((id) => _apparatusNames[id])
          .join(', ');
      if (missing.isNotEmpty) error = '$missing uchun aparatchini tanlang.';
    }
    setState(() => _scopeError = error);
    if (!validForm || error != null) return;
    Navigator.pop(
      context,
      WasteBinFormResult(
        code: _code.text,
        tareKg: widget.bin?.tareKg ?? wasteKgInput(_tare.text)!,
        toleranceKg: wasteKgInput(_tolerance.text),
        configuration: WasteBinConfiguration(
          name: _name.text,
          apparatusIds: _apparatus.toList(growable: false),
          operators: _operators.toList(growable: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.bin == null;
    return AlertDialog(
      title: Text(isNew
          ? 'Chiqindi qutisini ro‘yxatga olish'
          : 'Chiqindi qutisini sozlash'),
      scrollable: true,
      insetPadding: m3DialogInsetPadding,
      constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
      content: SizedBox(
        width: m3DialogMaxWidth,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: 'Quti nomi',
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Quti nomini kiriting';
                  if (name.runes.length > 120) {
                    return 'Nom 120 belgidan oshmasin';
                  }
                  if (RegExp(r'[\x00-\x1f\x7f-\x9f]').hasMatch(name)) {
                    return 'Quti nomini tekshiring';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                readOnly: !isNew,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: appSurfaceInputDecoration(
                  context,
                  labelText: 'Quti kodi',
                ),
                validator: (value) {
                  try {
                    wasteBinCode(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              if (isNew) ...[
                const SizedBox(height: 12),
                _kgField(_tare, 'Bo‘sh quti vazni (kg)', required: true),
                const SizedBox(height: 12),
                _kgField(_tolerance, 'Ruxsat etilgan farq (kg)'),
              ],
              const SizedBox(height: 16),
              _scopeField(
                title: 'Apparatlarni tanlash',
                selected: [
                  for (final id in _apparatus) _apparatusNames[id] ?? id,
                ],
                onPressed: _pickApparatus,
              ),
              const SizedBox(height: 12),
              _scopeField(
                title: 'Aparatchilarni tanlash',
                selected: [
                  for (final option in _eligibleOperators)
                    if (_operators.contains(option.identity))
                      option.displayName,
                ],
                onPressed: _apparatus.isEmpty ? null : _pickOperators,
              ),
              if (_scopeError case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              AppDialogActionRow(
                cancelLabel: 'Bekor qilish',
                confirmLabel: 'Saqlash',
                onCancel: () => Navigator.pop(context),
                onConfirm: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scopeField({
    required String title,
    required List<String> selected,
    required VoidCallback? onPressed,
  }) =>
      OutlinedButton(
        style: appOutlinedActionButtonStyle(),
        onPressed: onPressed,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (selected.isNotEmpty)
                    Text(
                      selected.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.expand_more),
          ],
        ),
      );

  Widget _kgField(
    TextEditingController controller,
    String label, {
    bool required = false,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        decoration: appSurfaceInputDecoration(context, labelText: label),
        validator: (value) {
          if (!required && (value ?? '').trim().isEmpty) return null;
          return wasteKgInput(value ?? '') == null
              ? 'Vaznni kg’da kiriting'
              : null;
        },
      );
}

class _WasteScopeOption<T extends Object> {
  const _WasteScopeOption(this.id, this.title, {this.subtitle = ''});

  final T id;
  final String title, subtitle;
}

class _WasteScopePicker<T extends Object> extends StatefulWidget {
  const _WasteScopePicker({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<_WasteScopeOption<T>> options;
  final Set<T> selected;

  @override
  State<_WasteScopePicker<T>> createState() => _WasteScopePickerState<T>();
}

class _WasteScopePickerState<T extends Object>
    extends State<_WasteScopePicker<T>> {
  late final _selection = Set<T>.of(widget.selected);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.options
        .where((option) =>
            '${option.title} ${option.subtitle}'.toLowerCase().contains(_query))
        .toList(growable: false);
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      insetPadding: m3DialogInsetPadding,
      constraints: const BoxConstraints(maxWidth: m3DialogMaxWidth),
      content: SizedBox(
        width: m3DialogMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration:
                  appSurfaceInputDecoration(context, labelText: 'Qidirish'),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Mos tanlov topilmadi'),
              )
            else
              SizedBox(
                height: (options.length * 72.0).clamp(72.0, 280.0),
                child: ListView.builder(
                  primary: false,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return CheckboxListTile(
                      title: Text(option.title),
                      subtitle: option.subtitle.isEmpty
                          ? null
                          : Text(option.subtitle),
                      value: _selection.contains(option.id),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          _selection.add(option.id);
                        } else {
                          _selection.remove(option.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            AppDialogActionRow(
              cancelLabel: 'Bekor qilish',
              confirmLabel: 'Tanlash',
              onCancel: () => Navigator.pop(context),
              onConfirm: () => Navigator.pop(context, _selection),
            ),
          ],
        ),
      ),
    );
  }
}
