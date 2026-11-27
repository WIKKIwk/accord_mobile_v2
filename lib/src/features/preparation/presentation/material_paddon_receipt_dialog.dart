import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';

typedef MaterialPaddonReceiptResult = ({
  String code,
  String warehouse,
  bool empty,
});

Future<MaterialPaddonReceiptResult?> showMaterialPaddonReceipt(
  BuildContext context, {
  String? emptyWarehouse,
}) =>
    showDialog<MaterialPaddonReceiptResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MaterialPaddonReceiptDialog(emptyWarehouse: emptyWarehouse),
    );

class _PaddonLine {
  SupplierItem? item;
  String kind = 'bag';
  bool showDimensions = false;
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
        if (kg.text.trim().isNotEmpty) 'unit_kg': _normalizedNumber(kg.text),
        if (kind == 'roll' && showDimensions && width.text.trim().isNotEmpty)
          'width_mm': _normalizedNumber(width.text),
        if (kind == 'roll' && showDimensions && micron.text.trim().isNotEmpty)
          'micron': _normalizedNumber(micron.text),
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
  const _MaterialPaddonReceiptDialog({this.emptyWarehouse});

  final String? emptyWarehouse;

  @override
  State<_MaterialPaddonReceiptDialog> createState() =>
      _MaterialPaddonReceiptDialogState();
}

class _MaterialPaddonReceiptDialogState
    extends State<_MaterialPaddonReceiptDialog> {
  final _api = MobileApi.instance;
  final _scope = currentSessionReadScope();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lines = <_PaddonLine>[_PaddonLine()];
  late Future<void> _opening = _load();
  PreparationSnapshot? _preparation;
  List<String> _materialWarehouses = const [];
  List<String> _assignedWarehouses = const [];
  PreparationPendingCommand? _pending;
  String? _warehouse, _failure;
  bool _saving = false;
  late bool _emptyPaddon = widget.emptyWarehouse != null;

  bool get _current => mounted && currentSessionReadScope() == _scope;
  bool get _canChooseMode =>
      widget.emptyWarehouse == null &&
      AppSession.instance.profile?.role == UserRole.tayyorlovMasteri;

  List<String> get _warehouses {
    final available = _emptyPaddon ? _assignedWarehouses : _materialWarehouses;
    final requested = widget.emptyWarehouse;
    return requested == null
        ? available
        : available.where((warehouse) => warehouse == requested).toList();
  }

  void _selectWarehouse(String? value) {
    if (_warehouse == value) return;
    _warehouse = value;
    for (final line in _lines) {
      line.item = null;
    }
  }

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
    _assignedWarehouses =
        preparation?.assignedWarehouses ?? profile.assignedWarehouses;
    _materialWarehouses = preparation == null ||
            preparation.assignedWarehouseIds.isNotEmpty
        ? _assignedWarehouses
        : preparation.materialWarehouses;
    final warehouses = _warehouses;
    _warehouse = warehouses.length == 1 ? warehouses.single : null;
  }

  Future<List<SupplierItem>> _materials(
      String query, int offset, int limit) async {
    final search = query.trim().toLowerCase();
    final preparation = _preparation;
    final exclusiveWarehouses = preparation?.materialWarehouses ?? const <String>[];
    final manual = [
      for (final item
          in preparation?.materials ?? const <PreparationMaterial>[])
        if (item.canReceiveIn(_warehouse, exclusiveWarehouses) &&
            '${item.name} ${item.code}'.toLowerCase().contains(search))
          SupplierItem(
            name: item.name,
            code: item.code,
            uom: 'kg',
            warehouse: _warehouse!,
          ),
    ];
    final page = manual.skip(offset).take(limit).toList();
    if (page.length < limit &&
        (preparation == null || exclusiveWarehouses.contains(_warehouse)) &&
        AppSession.instance.can('gscale.catalog.read')) {
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
      line.showDimensions = item.requiresDimensions;
      line.width.clear();
      line.micron.clear();
    });
  }

  Future<void> _submit() async {
    if (_saving || !_current) return;
    final pending = _pending;
    if (pending == null && !(_form.currentState?.validate() ?? false)) return;
    if (pending == null && !_emptyPaddon) {
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
      final name = _name.text.trim();
      final payload = pending?.payload ??
          {
            'warehouse': _warehouse!,
            if (name.isNotEmpty) 'name': name,
            'contents': _emptyPaddon
                ? const []
                : [for (final line in _lines) line.payload],
          };
      final code = await _api.receiveMaterialPaddon(payload);
      if (_current) {
        final empty = (payload['contents'] as List).isEmpty;
        Navigator.of(context).pop((
          code: code,
          warehouse: payload['warehouse'] as String,
          empty: empty,
        ));
      }
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
    _name.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? suffix,
    bool showLabel = false,
  }) =>
      InputDecoration(
        labelText: label,
        suffixText: suffix,
        floatingLabelBehavior: showLabel ? FloatingLabelBehavior.always : null,
        counterText: '',
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        errorMaxLines: 2,
      );

  Widget _fieldPair(Widget first, Widget second) => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          if (constraints.maxWidth < 240 * scale) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 12), second],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 10),
              Expanded(child: second),
            ],
          );
        },
      );

  Widget _fields(_PaddonLine line, int index) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: ObjectKey(line),
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('paddon-item-$index'),
                  onPressed: _warehouse == null || _saving
                      ? null
                      : () => _pickItem(line),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: scheme.surface,
                    side: BorderSide(color: scheme.outlineVariant),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: UrduAwareText(
                          line.item?.name ?? 'Xomashyo tanlang',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
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
            const SizedBox(height: 12),
            _fieldPair(
              DropdownButtonFormField<String>(
                key: ValueKey('paddon-kind-$index-${line.item?.code}'),
                initialValue: line.kind,
                isExpanded: true,
                decoration: _fieldDecoration('Birlik turi', showLabel: true),
                items: const [
                  DropdownMenuItem(value: 'bag', child: UrduAwareText('Qop')),
                  DropdownMenuItem(
                      value: 'roll', child: UrduAwareText('Rulon')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => line.kind = value!),
              ),
              TextFormField(
                controller: line.lot,
                maxLength: 120,
                decoration: _fieldDecoration('Partiya raqami', showLabel: true),
              ),
            ),
            const SizedBox(height: 12),
            _fieldPair(
              TextFormField(
                key: ValueKey('paddon-count-$index'),
                controller: line.count,
                keyboardType: TextInputType.number,
                decoration: _fieldDecoration('Soni', showLabel: true),
                validator: (text) {
                  final count = int.tryParse(text?.trim() ?? '') ?? 0;
                  return count >= 1 && count <= 200
                      ? null
                      : '1–200 ta kiriting';
                },
              ),
              _number(line.kg, 'Birlik vazni',
                  suffix: 'kg',
                  optional: true,
                  key: ValueKey('paddon-unit-kg-$index')),
            ),
            if (line.kind == 'roll')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const UrduAwareText('Rulon o‘lchamlari'),
                value: line.showDimensions,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => line.showDimensions = value),
              ),
            if (line.kind == 'roll' && line.showDimensions) ...[
              const SizedBox(height: 12),
              _fieldPair(
                _number(line.width, 'Eni', suffix: 'mm', optional: true),
                _number(line.micron, 'Qalinligi',
                    suffix: 'mkm', optional: true),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _number(TextEditingController field, String label,
          {String? suffix, Key? key, bool optional = false}) =>
      TextFormField(
        key: key,
        controller: field,
        decoration: _fieldDecoration(label, suffix: suffix, showLabel: true)
            .copyWith(hintText: optional ? 'Ixtiyoriy' : null),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (text) =>
            optional && (text ?? '').trim().isEmpty ? null : _positiveKg(text),
      );

  Widget _formContent(AsyncSnapshot<void> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: AppLoadingIndicator());
    }
    if (snapshot.hasError) {
      return const UrduAwareText('Kirim ma’lumotlarini yuklab bo‘lmadi');
    }
    if (!_current) return const UrduAwareText('Akkaunt o‘zgargan');
    if (_pending case final pending?) {
      final warehouse = pending.payload['warehouse'];
      final empty = (pending.payload['contents'] as List?)?.isEmpty == true;
      return UrduAwareText(
        empty
            ? '$warehouse omborida paddon ochish natijasini tekshiring.'
            : '$warehouse omboridagi kirim natijasi hali tasdiqlanmagan. Qayta urinib tekshiring.',
      );
    }
    final warehouses = _warehouses;
    final theme = Theme.of(context);
    return AbsorbPointer(
      absorbing: _saving,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_canChooseMode)
              SwitchListTile(
                key: const ValueKey('paddon-empty-mode'),
                contentPadding: EdgeInsets.zero,
                title: const UrduAwareText('Bo‘sh paddon'),
                value: _emptyPaddon,
                onChanged: (value) => setState(() {
                  _emptyPaddon = value;
                  final available = _warehouses;
                  if (!available.contains(_warehouse)) {
                    _selectWarehouse(available.length == 1 ? available.single : null);
                  }
                  _failure = null;
                }),
              ),
            if (warehouses.isEmpty)
              UrduAwareText(
                _emptyPaddon
                    ? 'Paddon ochish uchun ombor biriktirilmagan'
                    : 'Kirim uchun ombor biriktirilmagan',
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey(
                  _emptyPaddon ? 'paddon-warehouse-empty' : 'paddon-warehouse-filled',
                ),
                initialValue: _warehouse,
                isExpanded: true,
                decoration: _fieldDecoration('Ombor').copyWith(
                  fillColor: theme.colorScheme.surfaceContainerLow,
                ),
                items: [
                  for (final warehouse in warehouses)
                    DropdownMenuItem(
                      value: warehouse,
                      child: UrduAwareText(warehouse,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: widget.emptyWarehouse == null
                    ? (value) => setState(() => _selectWarehouse(value))
                    : null,
                validator: (value) => value == null ? 'Omborni tanlang' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('paddon-name'),
                controller: _name,
                maxLength: 80,
                textInputAction: TextInputAction.next,
                decoration: _fieldDecoration('Paddon nomi (ixtiyoriy)'),
              ),
              if (!_emptyPaddon) ...[
                const SizedBox(height: 18),
                UrduAwareText('Paddon tarkibi', style: theme.textTheme.titleSmall),
                for (final (index, line) in _lines.indexed) ...[
                  const SizedBox(height: 8),
                  _fields(line, index),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _lines.add(_PaddonLine())),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const UrduAwareText('Yana xomashyo'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _actions(AsyncSnapshot<void> snapshot) {
    final ready = snapshot.connectionState == ConnectionState.done &&
        !snapshot.hasError &&
        _current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: OverflowBar(
        alignment: MainAxisAlignment.end,
        spacing: 8,
        overflowSpacing: 4,
        children: [
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
              style: FilledButton.styleFrom(
                minimumSize: const Size(132, 46),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saving ? null : _submit,
              child: UrduAwareText(_saving
                  ? 'Saqlanmoqda…'
                  : _pending != null
                      ? 'Qayta urinish'
                      : _emptyPaddon
                          ? 'Paddon ochish'
                          : 'Kirim qilish'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        constraints: const BoxConstraints(maxWidth: 420),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: SizedBox(
          width: 420,
          child: FutureBuilder<void>(
            future: _opening,
            builder: (context, snapshot) {
              final header = Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(Icons.inventory_2_outlined,
                            size: 21, color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        namesRoute: true,
                        child: UrduAwareText(
                          widget.emptyWarehouse == null
                              ? 'Paddon qo‘shish'
                              : 'Bo‘sh paddon ochish',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              );
              final body = Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _formContent(snapshot),
                    if (_failure case final failure?) ...[
                      const SizedBox(height: 8),
                      UrduAwareText(failure,
                          style: TextStyle(color: scheme.error)),
                    ],
                  ],
                ),
              );
              final footer = _actions(snapshot);
              return LayoutBuilder(
                builder: (context, constraints) {
                  const divider = Divider(height: 1);
                  if (constraints.maxHeight < 220) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [header, body, divider, footer],
                      ),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      Flexible(child: SingleChildScrollView(child: body)),
                      divider,
                      footer,
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
