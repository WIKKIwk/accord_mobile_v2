part of 'preparation_screen.dart';

class PreparationOrderConsumptionScreen extends StatefulWidget {
  const PreparationOrderConsumptionScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<PreparationOrderConsumptionScreen> createState() =>
      _PreparationOrderConsumptionState();
}

class _PreparationOrderConsumptionState
    extends State<PreparationOrderConsumptionScreen> {
  final _scope = currentSessionReadScope();
  final _percent = <String, String>{};
  PreparationSnapshot? _snapshot;
  PreparationPendingCommand? _pending;
  String? _warehouse, _error;
  bool _loading = true, _saving = false;

  bool get _current => mounted && _scope == currentSessionReadScope();
  PreparationOrder? get _order =>
      _snapshot?.orders.where((o) => o.id == widget.orderId).firstOrNull;
  bool get _canEdit =>
      !_loading &&
      !_saving &&
      _pending == null &&
      _current &&
      _order?.saved == false &&
      _warehouse != null;
  List<PreparationMaterial> get _materials => [
        for (final material
            in _snapshot?.materials ?? const <PreparationMaterial>[])
          if (material.isSeriyo != false &&
              material.visibleIn(_warehouse) &&
              preparationDecimal(material.consumable(_warehouse),
                      allowZero: true) >
                  BigInt.zero)
            material,
      ];

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (_current || !mounted) return;
    setState(() {
      _snapshot = null;
      _pending = null;
      _percent.clear();
      _loading = false;
      _error = 'Akkaunt o‘zgargan. Sahifani qayta oching';
    });
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _load() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = MobileApi.instance;
      final pending = await api.preparationPendingCommand();
      if (!_current) return;
      final snapshot = await api.preparationSnapshot();
      if (!_current) return;
      setState(() {
        _pending = pending;
        _snapshot = snapshot;
        if (!snapshot.assignedWarehouses.contains(_warehouse)) {
          _warehouse = snapshot.assignedWarehouses.length == 1
              ? snapshot.assignedWarehouses.single
              : null;
          _percent.clear();
        }
        _percent
            .removeWhere((code, _) => !_materials.any((m) => m.code == code));
      });
    } catch (error) {
      if (_current) setState(() => _error = error.toString());
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  String? _lineError(PreparationMaterial material) {
    try {
      final kg =
          preparationRequiredKg(_order!.kg, _percent[material.code] ?? '');
      if (preparationDecimal(kg) >
          preparationDecimal(material.consumable(_warehouse))) {
        return 'Sarfga tayyor qoldiq yetarli emas';
      }
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _pickMaterial() async {
    if (!_canEdit || _percent.length >= 100) return;
    final warehouse = _warehouse;
    final material = await _pickPreparationItem<PreparationMaterial>(
      context,
      title: 'Seriyo tanlash',
      items: _materials.where((m) => !_percent.containsKey(m.code)).toList(),
      label: (m) => m.name,
      subtitle: (m) =>
          'Sarfga tayyor · ${preparationDisplay(m.consumable(warehouse))} kg',
      searchText: (m) => '${m.name} ${m.code}',
    );
    if (material != null &&
        _canEdit &&
        _warehouse == warehouse &&
        _materials.any((m) => m.code == material.code)) {
      setState(() => _percent.putIfAbsent(material.code, () => ''));
    }
  }

  Future<void> _submit({bool replay = false}) async {
    if (!_current || _saving) return;
    final pending = _pending;
    final order = _order;
    final lines =
        _materials.where((m) => _percent.containsKey(m.code)).toList();
    late final Map<String, dynamic> payload;
    if (replay) {
      if (pending == null ||
          pending.kind != 'consumptions' ||
          pending.payload['order_id'] != widget.orderId) return;
      payload = pending.payload;
    } else {
      if (!_canEdit ||
          order == null ||
          lines.isEmpty ||
          lines.length > 100 ||
          lines.any((m) => _lineError(m) != null)) return;
      payload = {
        'order_id': order.id,
        'expected_order_kg': order.kg,
        'warehouse': _warehouse,
        'lines': [
          for (final m in lines)
            {
              'item_code': m.code,
              'percent':
                  preparationDecimalText(preparationDecimal(_percent[m.code]!)),
            },
        ],
      };
    }
    setState(() => _saving = true);
    try {
      if (!replay) {
        final summary = lines
            .map((m) =>
                '${m.name} · ${preparationDisplay(preparationRequiredKg(order!.kg, _percent[m.code]!))} kg')
            .join('\n');
        final yes = await showM3ConfirmDialog(
          context: context,
          title: 'Sarfni tasdiqlash',
          message: '${order!.label}\n$_warehouse\n\n$summary',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Sarfni tasdiqlash',
        );
        if (yes != true || !_current) return;
      }
      await MobileApi.instance.preparationSubmit('consumptions', payload);
      if (!_current) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: UrduAwareText('Sarf yozildi')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!_current) return;
      await _load();
      if (_current) setState(() => _error = error.toString());
    } finally {
      if (_current) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final snapshot = _snapshot;
    final materials = _materials;
    final selected = materials.where((m) => _percent.containsKey(m.code));
    final pending = _pending;
    return AppShell(
      title: 'Sarf yozish',
      subtitle: order?.label ?? '',
      nativeTopBar: true,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
              children: [
                if (_error != null) Text(_error!),
                if (snapshot == null && _current)
                  TextButton(
                      onPressed: _load,
                      child: const UrduAwareText('Qayta urinish')),
                if (pending != null)
                  if (pending.kind == 'consumptions' &&
                      pending.payload['order_id'] == widget.orderId)
                    OutlinedButton(
                        onPressed: _saving ? null : () => _submit(replay: true),
                        child: const UrduAwareText('Oldingi sarfni tekshirish'))
                  else
                    const UrduAwareText(
                        'Tayyorlov bosh sahifasida kutilayotgan amalni tekshiring.'),
                if (snapshot != null && order == null)
                  const UrduAwareText(
                      'Bu buyurtmaga hozir sarf yozib bo‘lmaydi.'),
                if (order != null && snapshot != null) ...[
                  Text('${order.label} · ${preparationDisplay(order.kg)} kg'),
                  if (order.saved)
                    const UrduAwareText('Bu buyurtmaga sarf yozilgan.')
                  else if (snapshot.assignedWarehouses.isEmpty)
                    const UrduAwareText('Sizga ombor biriktirilmagan.')
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: _warehouse,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: localizeUrduUiText('Ombor')),
                      items: [
                        for (final w in snapshot.assignedWarehouses)
                          DropdownMenuItem(value: w, child: Text(w))
                      ],
                      onChanged: _saving || pending != null
                          ? null
                          : (w) => setState(() {
                                _warehouse = w;
                                _percent.clear();
                              }),
                    ),
                    if (_warehouse != null && materials.isEmpty)
                      const UrduAwareText(
                          'Bu omborda sarfga tayyor seriyo yo‘q.'),
                    if (materials.length > _percent.length &&
                        _percent.length < 100)
                      OutlinedButton.icon(
                        onPressed: _canEdit ? _pickMaterial : null,
                        icon: const Icon(Icons.add),
                        label: const UrduAwareText('Seriyo tanlash'),
                      ),
                    for (final m in selected) ...[
                      Row(children: [
                        Expanded(
                            child: Text(
                                '${m.name} · ${preparationDisplay(m.consumable(_warehouse))} kg')),
                        IconButton(
                          tooltip:
                              localizeUrduUiText('Tanlovdan olib tashlash'),
                          onPressed: _canEdit
                              ? () => setState(() => _percent.remove(m.code))
                              : null,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ]),
                      TextFormField(
                        key: ValueKey((_warehouse, m.code)),
                        enabled: _canEdit,
                        initialValue: _percent[m.code],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: localizeUrduUiText('Foiz (%)'),
                          errorText:
                              _percent[m.code]!.isEmpty ? null : _lineError(m),
                          helperText: _lineError(m) == null
                              ? 'Sarf · ${preparationDisplay(preparationRequiredKg(order.kg, _percent[m.code]!))} kg'
                              : null,
                        ),
                        onChanged: (v) => setState(() => _percent[m.code] = v),
                      ),
                    ],
                    if (materials.isNotEmpty)
                      FilledButton(
                        onPressed: _canEdit &&
                                selected.isNotEmpty &&
                                selected.length <= 100 &&
                                selected.every((m) => _lineError(m) == null)
                            ? () => _submit()
                            : null,
                        child: const UrduAwareText('Sarfni ko‘rib chiqish'),
                      ),
                  ],
                ],
              ],
            ),
    );
  }
}
