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

  Future<PreparationOrder?> _pickOrder() async {
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
    return order;
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

String _formatDateTime(dynamic raw) {
  if (raw == null) return '';
  final dt = DateTime.tryParse(raw.toString())?.toLocal();
  if (dt == null) return raw.toString();
  return dt.toString().split('.').first;
}

String _linesSummary(dynamic lines) {
  if (lines is! List) return '';
  return lines.map((l) {
    final name = l['name'] ?? '';
    final pct = preparationDisplay(l['percent']?.toString() ?? '0');
    final kg = preparationDisplay(l['kg']?.toString() ?? '0');
    return '$name: $pct% → $kg kg';
  }).join('\n');
}

class PreparationKirimScreen extends StatelessWidget {
  const PreparationKirimScreen({
    super.key,
    required this.warehouse,
    required this.materials,
    required this.history,
    required this.locked,
    required this.onReceive,
    required this.onReload,
  });

  final String? warehouse;
  final List<PreparationMaterial> materials;
  final List<dynamic> history;
  final bool locked;
  final Future<void> Function(PreparationMaterial) onReceive;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final receipts = history.where((d) => d['kind'] == 'receipt').toList();
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Kirim',
      subtitle: warehouse ?? 'Ombor tanlanmagan',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh),
          onPressed: locked ? null : onReload,
        ),
      ],
      child: AppRefreshIndicator(
        onRefresh: onReload,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            const SizedBox(height: _adminHomePanelCardGap),
            if (warehouse == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                child: Card.filled(
                  margin: EdgeInsets.zero,
                  color: scheme.tertiaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      M3SegmentedListGeometry.cornerLarge,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Kirim qilish uchun avval bosh sahifada ombor tanlang.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Homashyoni tanlab, qabul qilingan miqdorni (kg) kiriting:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (materials.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _adminHomePanelCardGap,
                  ),
                  child: AdminSummaryCard(
                    slot: M3SegmentVerticalSlot.top,
                    cornerRadius: M3SegmentedListGeometry.cornerLarge,
                    borderRadiusOverride: BorderRadius.circular(
                      M3SegmentedListGeometry.cornerLarge,
                    ),
                    backgroundColor: scheme.surfaceContainerLowest,
                    title: 'Homashyo mavjud emas',
                    subtitle: 'Avval "Homashyo" bo‘limidan homashyo qo‘shing',
                    value: '',
                    leading: Icon(
                      Icons.info_outline_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                    showChevron: false,
                    elevation: 4,
                  ),
                )
              else
                M3SegmentSpacedColumn(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _adminHomePanelCardGap,
                  ),
                  children: [
                    for (var i = 0; i < materials.length; i++)
                      AdminSummaryCard(
                        slot: _slotFor(i, materials.length),
                        cornerRadius:
                            M3SegmentedListGeometry.cornerRadiusForSlot(
                          _slotFor(i, materials.length),
                        ),
                        backgroundColor: scheme.surfaceContainerLowest,
                        title: materials[i].name,
                        subtitle:
                            'Mavjud: ${preparationDisplay(materials[i].available(warehouse))} kg',
                        value: '',
                        leading: Icon(
                          Icons.add_business_outlined,
                          size: 23,
                          color: scheme.onSurfaceVariant,
                        ),
                        trailing: Icon(
                          Icons.add_circle_outline,
                          color: scheme.primary,
                        ),
                        showChevron: false,
                        onTap: locked ? null : () => onReceive(materials[i]),
                        elevation: 4,
                      ),
                  ],
                ),
              if (receipts.isNotEmpty) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Oxirgi kirimlar',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                M3SegmentSpacedColumn(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _adminHomePanelCardGap,
                  ),
                  children: [
                    for (var i = 0; i < receipts.length; i++)
                      AdminSummaryCard(
                        slot: _slotFor(i, receipts.length),
                        cornerRadius:
                            M3SegmentedListGeometry.cornerRadiusForSlot(
                          _slotFor(i, receipts.length),
                        ),
                        backgroundColor: scheme.surfaceContainerLowest,
                        title: receipts[i]['name'] as String? ?? 'Kirim',
                        subtitle:
                            '${receipts[i]['warehouse']} • ${_formatDateTime(receipts[i]['created_at'])}',
                        value:
                            '+${preparationDisplay(receipts[i]['kg'] as String? ?? '0')} kg',
                        leading: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                        ),
                        showChevron: false,
                        elevation: 4,
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class PreparationMaterialsScreen extends StatelessWidget {
  const PreparationMaterialsScreen({
    super.key,
    required this.warehouse,
    required this.materials,
    required this.locked,
    required this.onCreateMaterial,
    required this.onReceive,
    required this.onReload,
  });

  final String? warehouse;
  final List<PreparationMaterial> materials;
  final bool locked;
  final Future<void> Function() onCreateMaterial;
  final Future<void> Function(PreparationMaterial) onReceive;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Homashyo',
      subtitle: warehouse ?? '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh),
          onPressed: locked ? null : onReload,
        ),
      ],
      child: AppRefreshIndicator(
        onRefresh: onReload,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            const SizedBox(height: _adminHomePanelCardGap),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _adminHomePanelCardGap,
                vertical: 4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const Key('preparation-add-material'),
                  onPressed: locked ? null : onCreateMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Homashyo qo‘shish'),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (materials.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hali homashyo qo‘shilmagan.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              M3SegmentSpacedColumn(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                children: [
                  for (var i = 0; i < materials.length; i++)
                    AdminSummaryCard(
                      slot: _slotFor(i, materials.length),
                      cornerRadius:
                          M3SegmentedListGeometry.cornerRadiusForSlot(
                        _slotFor(i, materials.length),
                      ),
                      backgroundColor: scheme.surfaceContainerLowest,
                      title: materials[i].name,
                      subtitle: 'Mavjud qoldiq',
                      value:
                          '${preparationDisplay(materials[i].available(warehouse))} kg',
                      leading: Icon(
                        Icons.inventory_2_outlined,
                        size: 23,
                        color: scheme.onSurfaceVariant,
                      ),
                      trailing: Icon(
                        Icons.add_circle_outline,
                        color: scheme.primary,
                      ),
                      showChevron: false,
                      onTap: locked || warehouse == null
                          ? null
                          : () => onReceive(materials[i]),
                      elevation: 4,
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Kirim qilish uchun homashyo nomini bosing. Qoldiq — sarflash mumkin bo‘lgan miqdor.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PreparationOrdersScreen extends StatefulWidget {
  const PreparationOrdersScreen({
    super.key,
    required this.warehouse,
    required this.order,
    required this.orders,
    required this.materials,
    required this.percent,
    required this.locked,
    required this.saving,
    required this.onPickOrder,
    required this.onAddMaterial,
    required this.onRemoveMaterial,
    required this.onSaveRecipe,
    required this.onReload,
    required this.update,
    required this.lineError,
  });

  final String? warehouse;
  final PreparationOrder? order;
  final List<PreparationOrder> orders;
  final List<PreparationMaterial> materials;
  final Map<String, TextEditingController> percent;
  final bool locked;
  final bool saving;
  final Future<PreparationOrder?> Function() onPickOrder;
  final Future<void> Function() onAddMaterial;
  final void Function(String itemCode) onRemoveMaterial;
  final Future<void> Function() onSaveRecipe;
  final Future<void> Function() onReload;
  final void Function(VoidCallback) update;
  final String? Function(PreparationMaterial, String) lineError;

  @override
  State<PreparationOrdersScreen> createState() =>
      _PreparationOrdersScreenState();
}

class _PreparationOrdersScreenState extends State<PreparationOrdersScreen> {
  late PreparationOrder? _order = widget.order;

  bool get _valid {
    final materials = {for (final m in widget.materials) m.code: m};
    return _order != null &&
        widget.warehouse != null &&
        widget.percent.isNotEmpty &&
        widget.percent.entries.every((e) =>
            materials[e.key] != null &&
            widget.lineError(materials[e.key]!, e.value.text) == null);
  }

  Future<void> _handlePickOrder() async {
    final picked = await widget.onPickOrder();
    if (picked != null && mounted) {
      setState(() => _order = picked);
    }
  }

  Future<void> _handleAddMaterial() async {
    await widget.onAddMaterial();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final materials = {for (final m in widget.materials) m.code: m};
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Buyurtmalar',
      subtitle: widget.warehouse ?? '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh),
          onPressed: widget.locked ? null : widget.onReload,
        ),
      ],
      child: AppRefreshIndicator(
        onRefresh: widget.onReload,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            const SizedBox(height: _adminHomePanelCardGap),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _adminHomePanelCardGap,
              ),
              child: AdminSummaryCard(
                slot: M3SegmentVerticalSlot.top,
                cornerRadius: M3SegmentedListGeometry.cornerLarge,
                borderRadiusOverride: BorderRadius.circular(
                  M3SegmentedListGeometry.cornerLarge,
                ),
                backgroundColor: scheme.surfaceContainerLowest,
                title: _order?.label ?? 'Order tanlang',
                subtitle: _order == null
                    ? 'Faqat KG miqdori bor faol orderlar'
                    : 'Order: ${preparationDisplay(_order!.kg)} kg',
                value: '',
                leading: Icon(
                  Icons.list_alt_rounded,
                  size: 23,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: widget.locked ? null : _handlePickOrder,
                elevation: 4,
              ),
            ),
            if (_order != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sarf (kg) = Order KG × foiz ÷ 100. Har bir homashyo foizi alohida hisoblanadi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in widget.percent.entries)
                if (materials[entry.key] != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _adminHomePanelCardGap,
                      vertical: 3,
                    ),
                    child: Card.filled(
                      margin: EdgeInsets.zero,
                      color: scheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    materials[entry.key]!.name,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Olib tashlash',
                                  onPressed: widget.locked
                                      ? null
                                      : () {
                                          widget.onRemoveMaterial(entry.key);
                                          setState(() {});
                                        },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            Text(
                              'Mavjud: ${preparationDisplay(materials[entry.key]!.available(widget.warehouse))} kg',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              key: Key('preparation-percent-${entry.key}'),
                              controller: entry.value,
                              enabled: !widget.locked,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (_) {
                                setState(() {});
                                widget.update(() {});
                              },
                              decoration: InputDecoration(
                                labelText: 'Foiz (%)',
                                errorText: entry.value.text.isEmpty
                                    ? null
                                    : widget.lineError(
                                        materials[entry.key]!,
                                        entry.value.text,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (_) {
                                try {
                                  return Text(
                                    'Sarf: ${preparationDisplay(preparationRequiredKg(_order!.kg, entry.value.text))} kg',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  );
                                } on FormatException {
                                  return const Text('Sarf: —');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                  vertical: 8,
                ),
                child: OutlinedButton.icon(
                  onPressed: widget.locked ? null : _handleAddMaterial,
                  icon: const Icon(Icons.add),
                  label: const Text('Homashyo tanlash'),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Saqlash bosilganda ko‘rsatilgan miqdor ombordan sarflanadi. Bu orderning saqlangan retsepti qayta sarflanmaydi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                child: FilledButton(
                  key: const Key('preparation-save-recipe'),
                  onPressed: widget.locked || !_valid
                      ? null
                      : () async {
                          await widget.onSaveRecipe();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                  child: Text(
                    widget.saving ? 'Saqlanmoqda…' : 'Saqlash va sarflash',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PreparationHistoryScreen extends StatelessWidget {
  const PreparationHistoryScreen({
    super.key,
    required this.history,
    required this.onReload,
  });

  final List<dynamic> history;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Tarix',
      subtitle: 'Oxirgi 100 ta kirim va sarf',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          icon: const Icon(Icons.refresh),
          onPressed: onReload,
        ),
      ],
      child: AppRefreshIndicator(
        onRefresh: onReload,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            const SizedBox(height: _adminHomePanelCardGap),
            if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Hali kirim yoki sarf yo‘q.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              M3SegmentSpacedColumn(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                children: [
                  for (var i = 0; i < history.length; i++)
                    _buildHistoryCard(
                      context,
                      history[i] as Map<String, dynamic>,
                      _slotFor(i, history.length),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    Map<String, dynamic> doc,
    M3SegmentVerticalSlot slot,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final isReceipt = doc['kind'] == 'receipt';

    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
      title: isReceipt
          ? 'Kirim — ${doc['name']}'
          : 'Sarf — ${doc['order_code']} ${doc['order_title']}',
      subtitle: isReceipt
          ? '${doc['warehouse']} • ${_formatDateTime(doc['created_at'])}'
          : '${doc['warehouse']} • ${_formatDateTime(doc['created_at'])}\n${_linesSummary(doc['lines'])}',
      value: isReceipt
          ? '+${preparationDisplay(doc['kg'] as String? ?? '0')} kg'
          : 'Order: ${preparationDisplay(doc['order_kg'] as String? ?? '0')} kg',
      leading: Icon(
        isReceipt
            ? Icons.check_circle_outline_rounded
            : Icons.remove_circle_outline_rounded,
        color: isReceipt ? Colors.green : Colors.orange,
      ),
      showChevron: false,
      elevation: 4,
    );
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
