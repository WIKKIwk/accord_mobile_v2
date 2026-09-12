import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';
import 'preparation_navigation.dart';

/// Tayyorlov masteri uchun formula sahifasi.
///
/// - FAB da faqat "Formula qo'shish" turadi.
/// - Uni bosganda markaziy card ochiladi: "Seriya tanlang" -> foiz maydoni.
/// - Card dagi "Seriya qo'shish" yana bir qator qo'shadi.
/// - Seriya tanlash bottom sheet da seriyalar ro'yxatini ko'rsatadi.
/// - "Saqlash" formula chizig'ini [productCode] ga bog'lab ERP ga yozadi
///   (alifbo tartibida). Keyingi safar shu mahsulot ochilganda ro'yxat chiqadi.
class PreparationOrderFormulaScreen extends StatefulWidget {
  const PreparationOrderFormulaScreen({
    super.key,
    required this.orderId,
    required this.orderCode,
    required this.productCode,
    required this.productTitle,
    this.customerName,
  });

  final String orderId;
  final String orderCode;
  final String productCode;
  final String productTitle;
  final String? customerName;

  static Route<void> route({
    required String orderId,
    required String orderCode,
    required String productCode,
    required String productTitle,
    String? customerName,
  }) {
    return PreparationOrderFormulaRoute(
      builder: (_) => PreparationOrderFormulaScreen(
        orderId: orderId,
        orderCode: orderCode,
        productCode: productCode,
        productTitle: productTitle,
        customerName: customerName,
      ),
    );
  }

  @override
  State<PreparationOrderFormulaScreen> createState() =>
      _PreparationOrderFormulaScreenState();
}

class _FormulaRow {
  _FormulaRow({String? percent})
      : percentController = TextEditingController(text: percent ?? '');
  PreparationMaterial? material;
  final TextEditingController percentController;
  void dispose() => percentController.dispose();
}

class _PreparationOrderFormulaScreenState
    extends State<PreparationOrderFormulaScreen> {
  PreparationFormula? _formula;
  List<PreparationMaterial> _materials = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  final List<_FormulaRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await MobileApi.instance.preparationSnapshot();
      PreparationFormula formula = PreparationFormula(
        productCode: widget.productCode.trim(),
        lines: const [],
      );
      try {
        formula =
            await MobileApi.instance.preparationFormula(widget.productCode);
      } catch (_) {
        // Formula yo'q bo'lsa bo'sh ro'yxat — xatolik emas.
      }
      if (!mounted) return;
      final materials = [...snapshot.materials]
        ..sort((a, b) {
          final byName =
              a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return byName != 0 ? byName : a.code.compareTo(b.code);
        });
      setState(() {
        _materials = materials;
        _formula = formula;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditor() {
    setState(() {
      _editing = true;
      if (_rows.isEmpty) _rows.add(_FormulaRow());
    });
  }

  void _closeEditor() {
    setState(() {
      _editing = false;
      for (final row in _rows) {
        row.dispose();
      }
      _rows.clear();
    });
  }

  Future<void> _pickSeriya(int index) async {
    final picked = await showModalBottomSheet<PreparationMaterial>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (sheetContext) => M3AsyncPickerSheet<PreparationMaterial>(
        title: 'Seriya tanlang',
        hintText: 'Qidirish',
        pageSize: 50,
        loadPage: (query, offset, limit) async => _materials
            .where((m) => '${m.name} ${m.code}'
                .toLowerCase()
                .contains(query.trim().toLowerCase()))
            .skip(offset)
            .take(limit)
            .toList(),
        itemTitle: (m) => m.name,
        itemSubtitle: (m) => m.code,
        onSelected: (m) => Navigator.of(sheetContext).pop(m),
      ),
    );
    if (picked != null && mounted && index < _rows.length) {
      setState(() => _rows[index].material = picked);
    }
  }

  /// Bir xil seriya ikki marta tanlangan qatorlar kodlari.
  /// Backend ham dublikatni rad etadi — Saqlash shunda inactive bo'ladi.
  Set<String> get _duplicateCodes {
    final counts = <String, int>{};
    for (final row in _rows) {
      final code = row.material?.code.trim() ?? '';
      if (code.isEmpty) continue;
      counts[code] = (counts[code] ?? 0) + 1;
    }
    return {for (final e in counts.entries) if (e.value > 1) e.key};
  }

  String? _rowError(_FormulaRow row) {
    if (row.material == null) return 'Seriya tanlang';
    final code = row.material!.code.trim();
    if (code.isEmpty) return 'Seriya tanlang';
    if (_duplicateCodes.contains(code)) {
      return 'Bu seriya allaqachon tanlangan';
    }
    try {
      final pct = preparationDecimal(row.percentController.text);
      if (pct > BigInt.from(100000000)) return 'Foiz 100 dan oshmasligi kerak';
    } on FormatException catch (e) {
      return e.message;
    }
    return null;
  }

  bool get _canSave {
    if (_rows.isEmpty || _saving) return false;
    final seen = <String>{};
    for (final row in _rows) {
      if (_rowError(row) != null) return false;
      final code = row.material!.code.trim();
      if (code.isEmpty || !seen.add(code)) return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      final lines = [
        for (final row in _rows)
          {
            'item_code': row.material!.code.trim(),
            'percent': preparationDecimalText(
              preparationDecimal(row.percentController.text),
            ),
          },
      ];
      final saved = await MobileApi.instance.preparationUpsertFormula(
        widget.productCode,
        lines,
      );
      if (!mounted) return;
      setState(() {
        _formula = saved;
        _saving = false;
      });
      _closeEditor();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formula saqlandi')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final customer = widget.customerName?.trim() ?? '';
    final subtitle = customer.isEmpty
        ? widget.productTitle
        : widget.productTitle.isEmpty
            ? customer
            : '$customer • ${widget.productTitle}';
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final lines = _formula?.lines ?? const <PreparationFormulaLine>[];

    return AppShell(
      title: 'Formulalar',
      subtitle: widget.orderCode.isEmpty ? '' : widget.orderCode,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: PreparationDock(
        primaryFabActions: [
          AdminFabMenuAction(
            title: 'Formula qo‘shish',
            icon: Icons.functions_rounded,
            onTap: _openEditor,
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          onPressed: _loading || _saving ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: [
                const SizedBox(height: 4),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: scheme.errorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Card(
                    margin: EdgeInsets.zero,
                    color: scheme.surfaceContainerLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zakaz kodi: ${widget.orderCode.isEmpty ? '-' : widget.orderCode}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (_editing) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: scheme.primary, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.functions_rounded,
                                    color: scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Yangi formula',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Bekor qilish',
                                  onPressed:
                                      _saving ? null : _closeEditor,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < _rows.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _FormulaRowCard(
                                index: i,
                                row: _rows[i],
                                error: _rowError(_rows[i]),
                                saving: _saving,
                                onPick: () => _pickSeriya(i),
                                onChanged: (_) => setState(() {}),
                                onRemove: _rows.length <= 1
                                    ? null
                                    : () => setState(() {
                                          _rows[i].dispose();
                                          _rows.removeAt(i);
                                        }),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              key: const ValueKey(
                                  'preparation-formula-add-seriya'),
                              onPressed: _saving
                                  ? null
                                  : () => setState(
                                      () => _rows.add(_FormulaRow())),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Seriya qo‘shish'),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              key: const ValueKey(
                                  'preparation-formula-save'),
                              onPressed:
                                  _canSave ? _save : null,
                              child: Text(
                                  _saving ? 'Saqlanmoqda…' : 'Saqlash'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Saqlangan formula',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Hali formula yo‘q. FAB orqali formula qo‘shing.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < lines.length; i++)
                            ListTile(
                              key: ValueKey(
                                  'preparation-formula-line-${lines[i].itemCode}'),
                              leading: CircleAvatar(
                                child: Text('${i + 1}'),
                              ),
                              title: Text(
                                lines[i].name.isEmpty
                                    ? lines[i].itemCode
                                    : lines[i].name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(lines[i].itemCode),
                              trailing: Text(
                                '${preparationDisplay(lines[i].percent)}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FormulaRowCard extends StatelessWidget {
  const _FormulaRowCard({
    required this.index,
    required this.row,
    required this.error,
    required this.saving,
    required this.onPick,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _FormulaRow row;
  final String? error;
  final bool saving;
  final VoidCallback onPick;
  final ValueChanged<String> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = row.material;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}-seriya',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Olib tashlash',
                    onPressed: saving ? null : onRemove,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: ValueKey('preparation-formula-pick-$index'),
              onPressed: saving ? null : onPick,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(
                material == null
                    ? 'Seriya tanlang'
                    : material.name.isEmpty
                        ? material.code
                        : '${material.name} • ${material.code}',
              ),
            ),
            if (material != null) ...[
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('preparation-formula-percent-$index'),
                controller: row.percentController,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: onChanged,
                decoration: InputDecoration(
                  labelText: 'Foiz (%)',
                  errorText: row.percentController.text.isEmpty
                      ? null
                      : error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barcha sahifalar bilan bir xil kirish/chiqish animatsiyasi.
/// [AppRoutes] dagi `_AppMaterialPageRoute` bilan 1:1
/// ([AppMotion.pageEnter]/[AppMotion.pageExit]).
class PreparationOrderFormulaRoute<T> extends MaterialPageRoute<T> {
  PreparationOrderFormulaRoute({
    required super.builder,
    super.settings,
  });

  @override
  Duration get transitionDuration => AppMotion.pageEnter;

  @override
  Duration get reverseTransitionDuration => AppMotion.pageExit;
}
