part of 'preparation_screen.dart';

extension _PreparationForms on _PreparationScreenState {
  Future<T?> _pick<T>(
          {required String title,
          required List<T> items,
          required String Function(T) label,
          required String Function(T) subtitle}) =>
      showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          sheetAnimationStyle: kM3PickerSheetAnimation,
          builder: (sheetContext) => M3AsyncPickerSheet<T>(
              title: title,
              hintText: 'Qidirish',
              pageSize: 50,
              loadPage: (query, offset, limit) async => items
                  .where((item) => '${label(item)} ${subtitle(item)}'
                      .toLowerCase()
                      .contains(query.trim().toLowerCase()))
                  .skip(offset)
                  .take(limit)
                  .toList(),
              itemTitle: label,
              itemSubtitle: subtitle,
              onSelected: (item) => Navigator.of(sheetContext).pop(item)));

  Future<void> _pickWarehouse() async {
    final value = await _pick<String>(
        title: 'Ombor tanlang',
        items: _snapshot!.warehouses,
        label: (w) => w,
        subtitle: (_) => '');
    if (value != null && mounted) _update(() => _warehouse = value);
  }

  Future<String?> _input(
          {required String title,
          required String label,
          bool quantity = false}) =>
      showDialog<String>(
          context: context,
          builder: (_) => _PreparationInputDialog(
              title: title, label: label, quantity: quantity));

  Future<void> _createMaterial() async {
    final name = await _input(title: 'Yangi homashyo', label: 'Homashyo nomi');
    if (name != null && mounted) await _submit('materials', {'name': name});
  }

  Future<void> _receive(PreparationMaterial material) async {
    final warehouse = _warehouse!;
    final kg = await _input(
        title: '${material.name} — kirim', label: 'Kirim (kg)', quantity: true);
    if (kg != null && mounted) {
      await _submit('receipts', {
        'item_code': material.code,
        'warehouse': warehouse,
        'kg': preparationDecimalText(preparationDecimal(kg))
      });
    }
  }

  Future<void> _pickOrder() async {
    final order = await _pick<PreparationOrder>(
        title: 'Order tanlang',
        items: _snapshot!.orders.where((o) => !o.saved).toList(),
        label: (o) => o.label,
        subtitle: (o) => '${preparationDisplay(o.kg)} kg');
    if (order != null && mounted) {
      _update(() {
        _clearRecipe();
        _order = order;
      });
    }
  }

  Future<void> _addRecipeMaterial() async {
    final material = await _pick<PreparationMaterial>(
        title: 'Homashyo tanlang',
        items: _snapshot!.materials
            .where((m) => !_percent.containsKey(m.code))
            .toList(),
        label: (m) => m.name,
        subtitle: (m) =>
            'Mavjud: ${preparationDisplay(m.available(_warehouse))} kg');
    if (material != null && mounted) {
      _update(() => _percent[material.code] = TextEditingController());
    }
  }

  String? _lineError(PreparationMaterial material, String percent) {
    try {
      final need =
          preparationDecimal(preparationRequiredKg(_order!.kg, percent));
      return need >
              preparationDecimal(material.available(_warehouse),
                  allowZero: true)
          ? 'Omborda yetarli homashyo yo‘q'
          : null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  List<Widget> _recipe(PreparationSnapshot data) {
    final materials = {for (final m in data.materials) m.code: m};
    final valid = _order != null &&
        _warehouse != null &&
        _percent.isNotEmpty &&
        _percent.entries.every((e) =>
            materials[e.key] != null &&
            _lineError(materials[e.key]!, e.value.text) == null);
    return [
      _surface(ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_order?.label ?? 'Order tanlang'),
          subtitle: Text(_order == null
              ? 'Faqat KG miqdori bor faol orderlar'
              : 'Order: ${preparationDisplay(_order!.kg)} kg'),
          trailing: const Icon(Icons.expand_more),
          onTap: _locked ? null : _pickOrder)),
      if (_order != null) ...[
        const Text(
            'Sarf (kg) = Order KG × foiz ÷ 100. Har bir homashyo foizi alohida hisoblanadi.'),
        const SizedBox(height: 12),
        for (final entry in _percent.entries)
          if (materials[entry.key] != null)
            _surface(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(materials[entry.key]!.name,
                        style: Theme.of(context).textTheme.titleMedium)),
                IconButton(
                    tooltip: 'Olib tashlash',
                    onPressed: _locked
                        ? null
                        : () => _update(
                            () => _percent.remove(entry.key)?.dispose()),
                    icon: const Icon(Icons.close))
              ]),
              Text(
                  'Mavjud: ${preparationDisplay(materials[entry.key]!.available(_warehouse))} kg'),
              TextField(
                  key: Key('preparation-percent-${entry.key}'),
                  controller: entry.value,
                  enabled: !_locked,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _update(() {}),
                  decoration: InputDecoration(
                      labelText: 'Foiz (%)',
                      errorText: entry.value.text.isEmpty
                          ? null
                          : _lineError(
                              materials[entry.key]!, entry.value.text))),
              Builder(builder: (_) {
                try {
                  return Text(
                      'Sarf: ${preparationDisplay(preparationRequiredKg(_order!.kg, entry.value.text))} kg');
                } on FormatException {
                  return const Text('Sarf: —');
                }
              }),
            ])),
        OutlinedButton.icon(
            onPressed: _locked ? null : _addRecipeMaterial,
            icon: const Icon(Icons.add),
            label: const Text('Homashyo tanlash')),
        const SizedBox(height: 12),
        const Text(
            'Saqlash bosilganda ko‘rsatilgan miqdor ombordan sarflanadi. Bu orderning saqlangan retsepti qayta sarflanmaydi.'),
        FilledButton(
            key: const Key('preparation-save-recipe'),
            onPressed: _locked || !valid ? null : _saveRecipe,
            child: Text(_saving ? 'Saqlanmoqda…' : 'Saqlash va sarflash')),
      ],
    ];
  }

  Future<void> _saveRecipe() async {
    final confirmed = await showM3ConfirmDialog(
        context: context,
        title: 'Sarfni saqlash',
        message: 'Hisoblangan homashyolar ombordan sarflansinmi?',
        cancelLabel: 'Bekor qilish',
        confirmLabel: 'Saqlash va sarflash');
    if (confirmed == true && mounted && _order != null && !_locked) {
      await _submit('consumptions', {
        'warehouse': _warehouse,
        'order_id': _order!.id,
        'expected_order_kg': _order!.kg,
        'lines': [
          for (final e in _percent.entries)
            {
              'item_code': e.key,
              'percent':
                  preparationDecimalText(preparationDecimal(e.value.text))
            }
        ]
      });
    }
  }
}

class _PreparationInputDialog extends StatefulWidget {
  const _PreparationInputDialog(
      {required this.title, required this.label, required this.quantity});
  final String title, label;
  final bool quantity;
  @override
  State<_PreparationInputDialog> createState() =>
      _PreparationInputDialogState();
}

class _PreparationInputDialogState extends State<_PreparationInputDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: Form(
              key: _form,
              child: TextFormField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: widget.quantity
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.text,
                  decoration: InputDecoration(labelText: widget.label),
                  validator: (text) {
                    if (!widget.quantity) {
                      return (text ?? '').trim().isEmpty
                          ? 'Nom kiriting'
                          : (text!.trim().length > 160
                              ? 'Nom juda uzun'
                              : null);
                    }
                    try {
                      preparationDecimal(text ?? '');
                      return null;
                    } on FormatException catch (e) {
                      return e.message;
                    }
                  })),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bekor qilish')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _controller.text.trim());
                  }
                },
                child: const Text('Saqlash'))
          ]);
}
