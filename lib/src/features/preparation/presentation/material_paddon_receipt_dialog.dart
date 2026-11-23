import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';

Future<String?> showMaterialPaddonReceipt(BuildContext context) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MaterialPaddonReceiptDialog(),
    );

class _PaddonLine {
  SupplierItem? item;
  String kind = 'bag';
  final lot = TextEditingController();
  final count = TextEditingController(text: '1');
  final kg = TextEditingController();
  final width = TextEditingController();
  final micron = TextEditingController();

  Map<String, Object> get payload => {
        'item_code': item!.code,
        'lot_number': lot.text.trim(),
        'kind': kind,
        'count': int.parse(count.text.trim()),
        'unit_kg': _normalizedNumber(kg.text),
        if (kind == 'roll') 'width_mm': _normalizedNumber(width.text),
        if (kind == 'roll') 'micron': _normalizedNumber(micron.text),
      };

  void dispose() {
    for (final field in [lot, count, kg, width, micron]) {
      field.dispose();
    }
  }
}

String _normalizedNumber(String value) => value.trim().replaceAll(',', '.');

String? _positiveKg(String? value) {
  final normalized = _normalizedNumber(value ?? '');
  return RegExp(r'^\d+(\.\d{1,6})?$').hasMatch(normalized) &&
          (double.tryParse(normalized) ?? 0) > 0
      ? null
      : 'Musbat son kiriting';
}

class _MaterialPaddonReceiptDialog extends StatefulWidget {
  const _MaterialPaddonReceiptDialog();

  @override
  State<_MaterialPaddonReceiptDialog> createState() =>
      _MaterialPaddonReceiptDialogState();
}

class _MaterialPaddonReceiptDialogState
    extends State<_MaterialPaddonReceiptDialog> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  final _form = GlobalKey<FormState>();
  final _lines = <_PaddonLine>[_PaddonLine()];
  late Future<void> _opening = _load();
  PreparationSnapshot? _preparation;
  List<String> _warehouses = const [];
  PreparationPendingCommand? _pending;
  String? _warehouse, _failure;
  bool _saving = false;

  bool get _current => mounted && currentSessionReadScope() == _scope;

  Future<void> _load() async {
    final profile = AppSession.instance.profile!;
    final pending = await _api.pendingMaterialPaddon();
    if (pending != null && pending.kind != 'raw_material_paddon') {
      throw const FormatException('Saqlanayotgan kirim ma’lumoti noto‘g‘ri');
    }
    final preparation =
        pending == null && profile.role == UserRole.tayyorlovMasteri
            ? await _api.preparationSnapshot()
            : null;
    if (!_current) throw StateError('Akkaunt o‘zgargan');
    _pending = pending;
    _preparation = preparation;
    _warehouses = preparation?.materialWarehouses ?? profile.assignedWarehouses;
    _warehouse = _warehouses.length == 1 ? _warehouses.single : null;
  }

  Future<List<SupplierItem>> _materials(
      String query, int offset, int limit) async {
    final search = query.trim().toLowerCase();
    final manual = [
      for (final item
          in _preparation?.materials ?? const <PreparationMaterial>[])
        if (item.canReceive &&
            item.visibleIn(_warehouse) &&
            '${item.name} ${item.code}'.toLowerCase().contains(search))
          SupplierItem(
            name: item.name,
            code: item.code,
            uom: 'kg',
            warehouse: _warehouse!,
          ),
    ];
    final page = manual.skip(offset).take(limit).toList();
    if (page.length < limit && AppSession.instance.can('gscale.catalog.read')) {
      final otherOffset = offset > manual.length ? offset - manual.length : 0;
      final items = await _api.gscaleItemsPage(
          query: query,
          offset: otherOffset,
          limit: limit - page.length,
          useBackend: true);
      if (!_current) throw StateError('Akkaunt o‘zgargan');
      page.addAll(items);
    }
    return page;
  }

  Future<void> _pickItem(_PaddonLine line) async {
    final item = await showModalBottomSheet<SupplierItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => M3AsyncPickerSheet<SupplierItem>(
        title: 'Xomashyo tanlang',
        hintText: 'Nomi yoki kodi',
        pageSize: 50,
        loadPage: _materials,
        itemTitle: (item) => item.name,
        itemSubtitle: (item) => item.code,
        onSelected: (item) => Navigator.of(context).pop(item),
      ),
    );
    if (!_current || item == null) return;
    setState(() {
      line.item = item;
      line.kind = item.requiresDimensions ? 'roll' : 'bag';
    });
  }

  Future<void> _submit() async {
    if (_saving || !_current) return;
    final pending = _pending;
    if (pending == null) {
      if (!(_form.currentState?.validate() ?? false)) return;
      final count = _lines.fold(
          0, (sum, line) => sum + int.parse(line.count.text.trim()));
      if (count > 200 || _lines.any((line) => line.item == null)) {
        setState(() => _failure = count > 200
            ? 'Bir paddonga 200 tagacha birlik kiriting'
            : 'Har bir qatorda xomashyo tanlang');
        return;
      }
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final code = await _api.receiveMaterialPaddon(pending?.payload ??
          {
            'warehouse': _warehouse!,
            'contents': [for (final line in _lines) line.payload],
          });
      if (_current) Navigator.of(context).pop(code);
    } catch (failure) {
      if (!_current) return;
      final pending =
          await _api.pendingMaterialPaddon().onError((_, __) => null);
      if (_current) {
        setState(() {
          _pending = pending;
          _failure = failure is MobileApiException
              ? failure.message
              : 'Kirim natijasini tekshirib bo‘lmadi. Qayta urinib ko‘ring';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Widget _fields(_PaddonLine line, int index) => Column(
        key: ObjectKey(line),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                key: ValueKey('paddon-item-$index'),
                onPressed: _warehouse == null || _saving
                    ? null
                    : () => _pickItem(line),
                child: UrduAwareText(line.item?.name ?? 'Xomashyo tanlang'),
              ),
            ),
            if (_lines.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Qatorni olib tashlash',
                onPressed: _saving
                    ? null
                    : () {
                        setState(() => _lines.remove(line));
                        line.dispose();
                      },
              ),
          ]),
          DropdownButtonFormField<String>(
            key: ValueKey('paddon-kind-$index-${line.item?.code}'),
            initialValue: line.kind,
            decoration: const InputDecoration(labelText: 'Birlik turi'),
            items: const [
              DropdownMenuItem(value: 'bag', child: UrduAwareText('Qop')),
              DropdownMenuItem(value: 'roll', child: UrduAwareText('Rulon')),
            ],
            onChanged: _saving || line.item?.requiresDimensions == true
                ? null
                : (value) => setState(() => line.kind = value!),
          ),
          TextFormField(
            controller: line.lot,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Partiya raqami'),
          ),
          TextFormField(
            key: ValueKey('paddon-count-$index'),
            controller: line.count,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Soni'),
            validator: (text) {
              final count = int.tryParse(text?.trim() ?? '') ?? 0;
              return count >= 1 && count <= 200 ? null : '1–200 ta kiriting';
            },
          ),
          _number(line.kg, 'Bir birlik og‘irligi (kg)',
              key: ValueKey('paddon-unit-kg-$index')),
          if (line.kind == 'roll') ...[
            _number(line.width, 'Eni (mm)'),
            _number(line.micron, 'Mikron'),
          ],
        ],
      );

  Widget _number(TextEditingController field, String label, {Key? key}) =>
      TextFormField(
        key: key,
        controller: field,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _positiveKg,
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: FutureBuilder<void>(
          future: _opening,
          builder: (context, snapshot) {
            final ready = snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError &&
                _current;
            return AlertDialog(
              title: const UrduAwareText('Paddon qo‘shish'),
              scrollable: true,
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.connectionState != ConnectionState.done)
                      const AppLoadingIndicator()
                    else if (snapshot.hasError)
                      const UrduAwareText(
                          'Kirim ma’lumotlarini yuklab bo‘lmadi')
                    else if (!_current)
                      const UrduAwareText('Akkaunt o‘zgargan')
                    else if (_pending case final pending?)
                      UrduAwareText(
                          '${pending.payload['warehouse']} omboridagi kirim natijasi hali tasdiqlanmagan. Qayta urinib tekshiring.')
                    else if (_warehouses.isEmpty)
                      const UrduAwareText('Kirim uchun ombor biriktirilmagan')
                    else
                      AbsorbPointer(
                        absorbing: _saving,
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _warehouse,
                                decoration:
                                    const InputDecoration(labelText: 'Ombor'),
                                items: [
                                  for (final warehouse in _warehouses)
                                    DropdownMenuItem(
                                      value: warehouse,
                                      child: UrduAwareText(warehouse),
                                    ),
                                ],
                                onChanged: (value) => setState(() {
                                  _warehouse = value;
                                  for (final line in _lines) {
                                    line.item = null;
                                  }
                                }),
                                validator: (value) =>
                                    value == null ? 'Omborni tanlang' : null,
                              ),
                              for (final (index, line) in _lines.indexed) ...[
                                const SizedBox(height: 12),
                                _fields(line, index),
                              ],
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _lines.add(_PaddonLine())),
                                icon: const Icon(Icons.add),
                                label: const UrduAwareText('Yana xomashyo'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_failure case final failure?)
                      UrduAwareText(failure,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const UrduAwareText('Bekor qilish'),
                ),
                if (snapshot.hasError)
                  TextButton(
                    onPressed: () => setState(() => _opening = _load()),
                    child: const UrduAwareText('Qayta urinish'),
                  )
                else if (ready && (_pending != null || _warehouses.isNotEmpty))
                  FilledButton(
                    key: const ValueKey('paddon-receipt-save'),
                    onPressed: _saving ? null : _submit,
                    child: UrduAwareText(_saving
                        ? 'Saqlanmoqda…'
                        : _pending == null
                            ? 'Kirim qilish'
                            : 'Qayta urinish'),
                  ),
              ],
            );
          },
        ),
      );
}
