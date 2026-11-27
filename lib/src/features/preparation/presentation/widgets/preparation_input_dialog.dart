import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/urdu_aware_text.dart';
import '../../models/preparation_models.dart';

class PreparationInputDialog extends StatefulWidget {
  const PreparationInputDialog(
      {required this.title,
      required this.label,
      this.quantity = false,
      this.emptyError = 'Nom kiriting',
      this.initialValue = '',
      this.additionalField,
      this.maxLength = 160});
  final String title, label;
  final bool quantity;
  final String emptyError;
  final String initialValue;
  final Widget? additionalField;
  final int maxLength;
  @override
  State<PreparationInputDialog> createState() => _PreparationInputDialogState();
}

class _PreparationInputDialogState extends State<PreparationInputDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    void submit() {
      if (_form.currentState!.validate()) {
        Navigator.pop(context, _controller.text.trim());
      }
    }

    // Freym showM3ConfirmDialog bilan 1:1 (inset, fon, radius, border).
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 10),
              Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                        controller: _controller,
                        autofocus: true,
                        keyboardType: widget.quantity
                            ? const TextInputType.numberWithOptions(
                                decimal: true)
                            : TextInputType.text,
                        inputFormatters: widget.quantity
                            ? [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ]
                            : null,
                        decoration: InputDecoration(labelText: widget.label),
                        validator: (text) {
                          if (!widget.quantity) {
                            return (text ?? '').trim().isEmpty
                                ? widget.emptyError
                                : (text!.trim().length > widget.maxLength
                                    ? 'Matn juda uzun'
                                    : null);
                          }
                          try {
                            preparationDecimal(text ?? '');
                            return null;
                          } on FormatException catch (e) {
                            return e.message;
                          }
                        }),
                    if (widget.additionalField case final field?) ...[
                      const SizedBox(height: 12),
                      field,
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: submit, child: const UrduAwareText('Saqlash')),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const UrduAwareText('Bekor qilish')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
