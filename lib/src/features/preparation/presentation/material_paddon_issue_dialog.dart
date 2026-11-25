import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../shared/models/app_models.dart' show UserRole;
import '../../shared/models/inventory_movement_models.dart';
import '../models/preparation_models.dart';

extension PaddonLineDisplay on PreparationPaddonContent {
  String get selectionName => [
        itemName,
        unit,
        if (lotNumber.isNotEmpty) lotNumber,
        if (preparedBarcode case final barcode?) barcode,
        if (widthMm != null) '${preparationDisplay(widthMm!)} mm',
        if (micron != null) '${preparationDisplay(micron!)} mkm',
        if (openUnitNo == null && unitKg != null)
          '${preparationDisplay(unitKg!)} kg dan',
        if (openUnitNo != null)
          'Ochilgan №$openUnitNo · ${preparationDisplay(remainingKg)} kg',
      ].join(' • ');
}

Future<PreparationPaddonIssue?> showMaterialPaddonIssue(
  BuildContext context,
  PreparationMaterialPaddon paddon,
  PreparationPendingCommand? pending,
) =>
    showDialog<PreparationPaddonIssue>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaterialPaddonIssueDialog(paddon, pending),
    );

class _MaterialPaddonIssueDialog extends StatefulWidget {
  const _MaterialPaddonIssueDialog(this.paddon, this.pending);

  final PreparationMaterialPaddon paddon;
  final PreparationPendingCommand? pending;

  @override
  State<_MaterialPaddonIssueDialog> createState() =>
      _MaterialPaddonIssueDialogState();
}

class _MaterialPaddonIssueDialogState
    extends State<_MaterialPaddonIssueDialog> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  final _form = GlobalKey<FormState>();
  final _count = TextEditingController(text: '1');
  final _remainder = TextEditingController();
  bool _partial = false;
  final _weights = List.filled(200, '');
  late final _lines = widget.paddon.contents
      .where((line) => line.lineNo != null && line.availableCount > 0)
      .toList(growable: false);
  late var _line = _lines.firstOrNull;
  late var _pending = widget.pending;
  late var _destinations = _loadDestinations();
  InventoryLocation? _destination;
  String? _failure;
  bool _saving = false;

  Future<List<InventoryLocation>> _loadDestinations() async {
    final session = AppSession.instance;
    final canMoveToState =
        session.profile?.role == UserRole.materialTaminotchi &&
            session.can('inventory.movement.manage');
    final masterCanTransfer =
        session.profile?.role == UserRole.tayyorlovMasteri &&
            session.can('preparation.access');
    if (!masterCanTransfer && !canMoveToState) {
      return [];
    }
    final locations = await _api.inventoryLocations();
    if (_scope != currentSessionReadScope()) return [];
    final own = widget.paddon.warehouse.trim().toLowerCase();
    return [
      for (final location in locations)
        if (location.active &&
            ((canMoveToState && location.isState) ||
                (location.isWarehouse &&
                    location.name.trim().toLowerCase() != own)))
          location,
    ];
  }

  @override
  void dispose() {
    _count.dispose();
    _remainder.dispose();
    super.dispose();
  }

  String? _validateCount(String? text) {
    final count = int.tryParse(text?.trim() ?? '');
    final available = _line?.availableCount ?? 0;
    if (count == null || count < 1 || count > available || count > 200) {
      return '1–${available.clamp(1, 200)} ta kiriting';
    }
    return null;
  }

  String? _validateWeight(String? text) {
    try {
      preparationDecimal(text ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String? _validateTaken(String? text) {
    final invalid = _validateWeight(text);
    if (invalid != null || _line?.openUnitNo == null) return invalid;
    final kg = preparationDecimal(text!);
    final balance = preparationDecimal(_line!.remainingKg);
    if (_partial && kg >= balance) return 'Qoldiqdan kamroq vazn kiriting';
    if (!_partial && kg != balance) {
      return 'Ochilgan birlik qoldig‘i ${preparationDisplay(_line!.remainingKg)} kg';
    }
    return null;
  }

  String? get _openRemainder {
    if (_line?.openUnitNo == null || _validateTaken(_weights.first) != null) {
      return null;
    }
    return preparationDecimalText(preparationDecimal(_line!.remainingKg) -
        preparationDecimal(_weights.first));
  }

  Future<void> _save() async {
    if (_saving || _scope != currentSessionReadScope()) return;
    final pending = _pending;
    if (pending != null && pending.payload['code'] != widget.paddon.code) {
      return;
    }
    if (pending == null && !(_form.currentState?.validate() ?? false)) return;
    final prepared = _line?.preparedBarcode != null;
    final destination = prepared ? null : _destination;
    final payload = pending?.payload ??
        {
          'code': widget.paddon.code,
          'line_no': _line!.lineNo,
          if (_line!.openUnitNo != null) ...{
            'open_unit_no': _line!.openUnitNo,
            'expected_open_kg': _line!.remainingKg,
          },
          if (_partial)
            'remainder_kg':
                _openRemainder ?? _remainder.text.trim().replaceAll(',', '.'),
          'weights': [
            if (prepared)
              _line!.remainingKg
            else
              for (final weight in _weights.take(int.parse(_count.text.trim())))
                weight.trim().replaceAll(',', '.'),
          ],
          if (destination != null)
            'destination': {
              'kind': destination.isState ? 'state' : 'warehouse',
              'id': destination.isState
                  ? destination.id
                  : destination.warehouseId,
            },
        };
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final issue = await _api.issueMaterialPaddon(payload);
      if (!mounted || _scope != currentSessionReadScope()) return;
      Navigator.of(context).pop(issue);
    } catch (error) {
      if (!mounted || _scope != currentSessionReadScope()) return;
      final pending =
          await _api.pendingMaterialPaddonIssue().onError((_, __) => null);
      if (!mounted || _scope != currentSessionReadScope()) return;
      setState(() {
        _pending = pending;
        _failure = error is MobileApiException
            ? error.message
            : 'Chiqim natijasi olinmadi. Qayta urinib ko‘ring';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _destinationPicker() => FutureBuilder<List<InventoryLocation>>(
        future: _destinations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: UrduAwareText(widget.paddon.warehouse),
              subtitle: const UrduAwareText('Boshqa manzillar yuklanmadi'),
              trailing: IconButton(
                tooltip: 'Qayta urinish',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _saving
                    ? null
                    : () {
                        final next = _loadDestinations();
                        setState(() {
                          _destinations = next;
                        });
                      },
              ),
            );
          }
          return DropdownButtonFormField<InventoryLocation>(
            key: const ValueKey('paddon-issue-destination'),
            decoration: const InputDecoration(labelText: 'Manzil'),
            isExpanded: true,
            initialValue: _destination,
            hint: UrduAwareText('Shu omborda • ${widget.paddon.warehouse}'),
            items: [
              DropdownMenuItem<InventoryLocation>(
                child:
                    UrduAwareText('Shu omborda • ${widget.paddon.warehouse}'),
              ),
              for (final location
                  in snapshot.data ?? const <InventoryLocation>[])
                DropdownMenuItem(
                  value: location,
                  child: UrduAwareText(
                    location.isState
                        ? '${location.name} • State'
                        : '${location.name} • Ombor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving || !snapshot.hasData
                ? null
                : (value) => setState(() => _destination = value),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final line = _line;
    final pending = _pending;
    final otherPaddon =
        pending != null && pending.payload['code'] != widget.paddon.code;
    final count =
        _validateCount(_count.text) == null ? int.parse(_count.text.trim()) : 0;
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        constraints: const BoxConstraints(maxWidth: 440),
        title: const UrduAwareText('Paddondan yechib olish'),
        content: SizedBox(
          width: 360,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UrduAwareText(widget.paddon.title),
                const SizedBox(height: 16),
                if (pending != null)
                  UrduAwareText(otherPaddon
                      ? '${pending.payload['code']} paddonidagi oldingi chiqimni tekshiring.'
                      : 'Oldingi chiqim natijasini tekshirish mumkin.')
                else if (line == null)
                  const UrduAwareText('Chiqim uchun qoldiq qolmagan.')
                else ...[
                  DropdownButtonFormField<PreparationPaddonContent>(
                    key: const ValueKey('paddon-issue-line'),
                    decoration:
                        const InputDecoration(labelText: 'Xomashyo va partiya'),
                    initialValue: line,
                    itemHeight: null,
                    isExpanded: true,
                    items: [
                      for (final item in _lines)
                        DropdownMenuItem(
                          value: item,
                          child: UrduAwareText(item.selectionName,
                              maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                              _line = value;
                              _partial = false;
                              _remainder.clear();
                              _count.text = '1';
                              _weights.fillRange(0, _weights.length, '');
                            }),
                  ),
                  const SizedBox(height: 12),
                  if (line.preparedBarcode != null)
                    UrduAwareText(
                      '${line.preparedBarcode} • ${preparationDisplay(line.remainingKg)} kg',
                    )
                  else ...[
                    if (line.issuableCount != null)
                      SwitchListTile(
                        key: const ValueKey('paddon-partial'),
                        contentPadding: EdgeInsets.zero,
                        title: const UrduAwareText('Qisman olish'),
                        value: _partial,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                  _partial = value;
                                  _count.text = '1';
                                  _weights.fillRange(0, _weights.length, '');
                                  _remainder.clear();
                                }),
                      ),
                    if (!_partial && line.openUnitNo == null)
                      TextFormField(
                        key: const ValueKey('paddon-issue-count'),
                        controller: _count,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Olinadigan ${line.unit} soni',
                          helperText:
                              'Olish mumkin: ${line.availableCount} ta ${line.unit}',
                        ),
                        validator: _validateCount,
                        onChanged: (_) => setState(() {}),
                      ),
                    for (var index = 0; index < count; index++)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        key: ValueKey(
                            (line.lineNo, line.openUnitNo, _partial, index)),
                        child: TextFormField(
                          key: ValueKey(
                              'paddon-issue-weight-${line.lineNo}-$index'),
                          initialValue: _weights[index],
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: _partial
                                ? 'Olingan qism vazni'
                                : '${index + 1}-${line.unit} vazni',
                            suffixText: 'kg',
                          ),
                          validator: _validateTaken,
                          onChanged: (value) =>
                              setState(() => _weights[index] = value),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_partial && line.openUnitNo == null)
                      TextFormField(
                        key: const ValueKey('paddon-remainder-kg'),
                        controller: _remainder,
                        enabled: !_saving,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Paddonda qolgan qism vazni',
                            suffixText: 'kg',
                            helperText: 'Qolgan qismini ham torting'),
                        validator: _validateWeight,
                      ),
                    if (_partial && _openRemainder != null)
                      UrduAwareText(
                          'Paddonda qoladi: ${preparationDisplay(_openRemainder!)} kg'),
                    _destinationPicker(),
                  ],
                ],
                if (_failure case final failure?)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: UrduAwareText(failure,
                        style: TextStyle(color: colors.error)),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const UrduAwareText('Bekor qilish'),
          ),
          FilledButton(
            key: const ValueKey('paddon-issue-save'),
            onPressed:
                _saving || otherPaddon || (pending == null && line == null)
                    ? null
                    : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18, child: AppLoadingIndicator())
                : UrduAwareText(pending == null
                    ? 'Chiqimni tasdiqlash'
                    : 'Natijani tekshirish'),
          ),
        ],
      ),
    );
  }
}
