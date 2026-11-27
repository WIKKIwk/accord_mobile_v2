import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/widgets/buttons/app_action_button_styles.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/forms/app_input_decoration.dart';
import 'waste_bin_details.dart';

class WasteBinFormResult {
  const WasteBinFormResult({
    required this.tareKg,
    required this.toleranceKg,
    required this.configuration,
  });

  final double tareKg;
  final double? toleranceKg;
  final WasteBinConfiguration configuration;

  bool sameRegistrationAs(WasteBinFormResult other) =>
      tareKg == other.tareKg &&
      toleranceKg == other.toleranceKg &&
      configuration.name.trim() == other.configuration.name.trim() &&
      setEquals(configuration.apparatusIds.toSet(),
          other.configuration.apparatusIds.toSet());
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
  final _tare = TextEditingController();
  final _tolerance = TextEditingController();
  late final _apparatusNames = {
    for (final option in widget.options.apparatuses) option.id: option.name,
  };
  late Set<String> _apparatus = {
    for (final id in widget.bin?.apparatusIds ?? const <String>[])
      if (_apparatusNames.containsKey(id)) id,
  };
  bool _needsApparatus = false;

  @override
  void dispose() {
    _name.dispose();
    _tare.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  Future<void> _pickApparatus() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _WasteApparatusPicker(
        options: widget.options.apparatuses,
        selected: _apparatus,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _apparatus = selected;
      _needsApparatus = false;
    });
  }

  void _save() {
    final validForm = _form.currentState!.validate();
    setState(() => _needsApparatus = _apparatus.isEmpty);
    if (!validForm || _needsApparatus) return;
    Navigator.pop(
      context,
      WasteBinFormResult(
        tareKg: widget.bin?.tareKg ?? wasteKgInput(_tare.text)!,
        toleranceKg: wasteKgInput(_tolerance.text),
        configuration: WasteBinConfiguration(
          name: _name.text,
          apparatusIds: _apparatus.toList(growable: false),
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
              if (widget.bin case final bin?) ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: bin.code,
                  readOnly: true,
                  decoration: appSurfaceInputDecoration(
                    context,
                    labelText: 'Quti kodi',
                  ),
                ),
              ],
              if (isNew) ...[
                const SizedBox(height: 12),
                _kgField(_tare, 'Bo‘sh quti vazni (kg)', required: true),
                const SizedBox(height: 12),
                _kgField(_tolerance, 'Ruxsat etilgan farq (kg)'),
              ],
              const SizedBox(height: 16),
              _apparatusField(),
              if (_needsApparatus) ...[
                const SizedBox(height: 8),
                Text(
                  'Kamida bitta apparatni tanlang.',
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

  Widget _apparatusField() {
    final selected =
        _apparatus.map((id) => _apparatusNames[id] ?? id).join(', ');
    return OutlinedButton(
      style: appOutlinedActionButtonStyle(),
      onPressed: _pickApparatus,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Apparatlarni tanlash'),
                if (selected.isNotEmpty)
                  Text(
                    selected,
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
  }

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

class _WasteApparatusPicker extends StatefulWidget {
  const _WasteApparatusPicker({
    required this.options,
    required this.selected,
  });

  final List<WasteBinApparatusOption> options;
  final Set<String> selected;

  @override
  State<_WasteApparatusPicker> createState() => _WasteApparatusPickerState();
}

class _WasteApparatusPickerState extends State<_WasteApparatusPicker> {
  late final _selection = Set<String>.of(widget.selected);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final options = widget.options
        .where((option) => option.name.toLowerCase().contains(_query))
        .toList(growable: false);
    return AlertDialog(
      title: const Text('Apparatlarni tanlash'),
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
                      title: Text(option.name),
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
