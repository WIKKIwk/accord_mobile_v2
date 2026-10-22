import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../models/preparation_models.dart';

Future<List<PreparationFormula>?> showPreparationFormulaSharesEditor(
  BuildContext context, {
  required String productCode,
  required String materialId,
  required String materialName,
  required List<PreparationFormula> formulas,
  bool savedOnly = false,
  String variantId = '',
}) =>
    showModalBottomSheet<List<PreparationFormula>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FormulaSharesSheet(
          productCode: productCode,
          materialId: materialId,
          materialName: materialName,
          formulas: formulas,
          savedOnly: savedOnly,
          variantId: variantId),
    );

class _FormulaSharesSheet extends StatefulWidget {
  const _FormulaSharesSheet(
      {required this.productCode,
      required this.materialId,
      required this.materialName,
      required this.formulas,
      required this.savedOnly,
      required this.variantId});
  final String productCode, materialId, materialName;
  final List<PreparationFormula> formulas;
  final bool savedOnly;
  final String variantId;
  @override
  State<_FormulaSharesSheet> createState() => _FormulaSharesSheetState();
}

class _FormulaSharesSheetState extends State<_FormulaSharesSheet> {
  late final _controllers = [
    for (final f in widget.formulas)
      TextEditingController(
          text:
              f.sharePercent == null ? '' : preparationDisplay(f.sharePercent!))
  ];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  BigInt? get _total {
    var total = BigInt.zero;
    for (final controller in _controllers) {
      try {
        final value = preparationDecimal(controller.text);
        if (value > BigInt.from(100000000)) return null;
        total += value;
      } on FormatException {
        return null;
      }
    }
    return total;
  }

  Future<void> _save() async {
    if (_saving || _total != BigInt.from(100000000)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final formulas = await MobileApi.instance.preparationUpdateFormulaShares(
        productCode: widget.productCode,
        materialId: widget.materialId,
        savedOnly: widget.savedOnly,
        variantId: widget.variantId,
        shares: [
          for (var i = 0; i < widget.formulas.length; i++)
            {
              'name': widget.formulas[i].name,
              'percent': preparationDecimalText(
                  preparationDecimal(_controllers[i].text)),
            }
        ],
      );
      if (mounted) {
        Navigator.of(context).pop(formulas);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is MobileApiException
            ? error.message
            : 'Shnek ulushlari saqlanmadi. Qayta urinib ko‘ring');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final valid = total == BigInt.from(100000000);
    return PopScope(
      canPop: !_saving,
      child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('preparation-screw-shares-sheet'),
            padding: EdgeInsets.fromLTRB(
                20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UrduAwareText('Shnek ulushlari',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                UrduAwareText(
                    '${widget.materialName.isEmpty ? 'Homashyo' : widget.materialName}: shnek ulushlari jami 100% bo‘lsin. Har bir shnek ichidagi seriyalar alohida 100% hisoblanadi.'),
                const SizedBox(height: 16),
                for (var i = 0; i < widget.formulas.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      key: ValueKey(
                          'preparation-screw-share-${widget.formulas[i].name}'),
                      controller: _controllers[i],
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: '${widget.formulas[i].name} shnek ulushi',
                          suffixText: '%'),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                UrduAwareText(
                    total == null
                        ? 'Har bir shnek uchun 0 dan katta, 100 gacha foiz kiriting'
                        : 'Jami: ${preparationDisplay(preparationDecimalText(total))}% / 100%',
                    key: const ValueKey('preparation-screw-share-total'),
                    style: TextStyle(
                        color: valid
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error)),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!)),
                const SizedBox(height: 16),
                FilledButton(
                    key: const ValueKey('preparation-screw-shares-save'),
                    onPressed: valid && !_saving ? _save : null,
                    child: UrduAwareText(_saving ? 'Saqlanmoqda…' : 'Saqlash')),
              ],
            ),
          )),
    );
  }
}
