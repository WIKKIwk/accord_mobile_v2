import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
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
  List<PreparationFormula> _formulas = const [];
  List<PreparationMaterial> _materials = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _editing = false;
  String? _editingName;
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
      List<PreparationFormula> formulas = const [];
      try {
        formulas =
            await MobileApi.instance.preparationFormulas(widget.productCode);
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
        _formulas = formulas;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshFormulas() async {
    try {
      final formulas =
          await MobileApi.instance.preparationFormulas(widget.productCode);
      if (mounted) setState(() => _formulas = formulas);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  /// Keyingi bo'sh harfli nom: A, B, ... Z, AA, AB, ...
  /// Formula nomini tizim avtomatik beradi — qo'lda kiritilmaydi.
  String _nextAutoName() {
    final used = {
      for (final f in _formulas) f.name.trim().toUpperCase(),
    };
    var i = 0;
    while (true) {
      final candidate = _lettersFor(i);
      if (!used.contains(candidate)) return candidate;
      i++;
    }
  }

  String _lettersFor(int index) {
    var result = '';
    var n = index;
    do {
      result = String.fromCharCode(65 + (n % 26)) + result;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return result;
  }

  void _openEditor({PreparationFormula? existing}) {
    setState(() {
      _editing = true;
      _editingName = existing?.name;
      final saved = existing?.lines ?? const <PreparationFormulaLine>[];
      if (saved.isEmpty) {
        if (_rows.isEmpty) _rows.add(_FormulaRow());
      } else {
        for (final row in _rows) {
          row.dispose();
        }
        _rows.clear();
        // Saqlangan qatorlar muharrirga yuklanadi (alifbo tartibida,
        // API shunday qaytaradi). Yangi seriya eskilar ustiga qo'shiladi.
        for (final line in saved) {
          final material = _materials
              .where((m) => m.code.trim() == line.itemCode.trim())
              .firstOrNull;
          final row = _FormulaRow(
            percent: preparationDisplay(line.percent),
          );
          row.material = material ??
              PreparationMaterial.fromJson({
                'item_code': line.itemCode,
                'name': line.name,
                'balances': const [],
              });
          _rows.add(row);
        }
      }
    });
  }

  void _closeEditor() {
    setState(() {
      _editing = false;
      _editingName = null;
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

  BigInt? _parsePercent(_FormulaRow row) {
    try {
      final pct = preparationDecimal(row.percentController.text);
      if (pct > BigInt.from(100000000)) return null;
      return pct;
    } on FormatException {
      return null;
    }
  }

  /// Hamma pars bo'lganda jami foiz (mikro-foizda), aks holda null.
  BigInt? get _totalPercent {
    var sum = BigInt.zero;
    for (final row in _rows) {
      final pct = _parsePercent(row);
      if (pct == null) return null;
      sum += pct;
    }
    return sum;
  }

  /// Bitta jamlovchi xatolik — Saqlash tugmasi tepasida chiqadi.
  /// Xavfsizlik qoidalari: seriya tanlanishi shart, dublikat taqiqlanadi,
  /// har bir foiz 0–100 oralig'ida, jami aniq 100% bo'lishi shart.
  /// Nom tizim tomonidan avtomatik beriladi (A, B, C...).
  String? get _editorError {
    if (_rows.isEmpty) return null;
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final code = row.material?.code.trim() ?? '';
      if (row.material == null || code.isEmpty) {
        return '${i + 1}-seriyada seriya tanlanmagan';
      }
    }
    final duplicates = _duplicateCodes;
    if (duplicates.isNotEmpty) {
      final name = _rows
          .firstWhere(
              (r) => duplicates.contains(r.material!.code.trim()))
          .material!
          .name
          .trim();
      final label = name.isEmpty ? 'Bu seriya' : '«$name»';
      return '$label takrorlangan — har bir seriya 1 marta bo‘lishi kerak';
    }
    for (var i = 0; i < _rows.length; i++) {
      if (_parsePercent(_rows[i]) == null) {
        return '${i + 1}-seriya foizini to‘g‘ri kiriting (0–100, masalan 25)';
      }
    }
    final total = _totalPercent;
    if (total == null) return null;
    final hundred = BigInt.from(100000000);
    final display = preparationDisplay(preparationDecimalText(total));
    if (total > hundred) {
      return 'Jami foiz 100 dan oshib ketdi (hozir $display%). Kamaytiring.';
    }
    if (total != hundred) {
      return 'Jami foiz 100% bo‘lishi kerak (hozir $display%). Saqlash uchun to‘ldiring.';
    }
    return null;
  }

  bool get _canSave {
    if (_rows.isEmpty || _saving) return false;
    return _editorError == null;
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
      final name = _editingName ?? _nextAutoName();
      await MobileApi.instance.preparationUpsertFormula(
        widget.productCode,
        lines,
        name: name,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      _closeEditor();
      await _refreshFormulas();
      if (!mounted) return;
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

  Future<void> _deleteFormula(PreparationFormula formula) async {
    if (_deleting) return;
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Formulani o‘chirish',
          message: '«${formula.name}» formulasi o‘chirilsinmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'O‘chirish',
          destructive: true,
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await MobileApi.instance.preparationDeleteFormula(
        widget.productCode,
        formula.name,
      );
      if (!mounted) return;
      setState(() => _deleting = false);
      await _refreshFormulas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formula o‘chirildi')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
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
                                    _editingName == null
                                        ? 'Yangi formula'
                                        : '«$_editingName»',
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
                            _FormulaNameBanner(
                              name: _editingName ?? _nextAutoName(),
                              auto: _editingName == null,
                            ),
                            const SizedBox(height: 12),
                            for (var i = 0; i < _rows.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _FormulaRowCard(
                                index: i,
                                row: _rows[i],
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
                            _FormulaTotalBar(total: _totalPercent),
                            if (_editorError != null) ...[
                              const SizedBox(height: 8),
                              _FormulaEditorError(message: _editorError!),
                            ],
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
                    'Saqlangan formulalar (${_formulas.length})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_formulas.isEmpty)
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
                  for (var f = 0; f < _formulas.length; f++) ...[
                    if (f > 0) const SizedBox(height: 12),
                    _SavedFormulaCard(
                      formula: _formulas[f],
                      deleting: _deleting,
                      onEdit: () => _openEditor(existing: _formulas[f]),
                      onDelete: () => _deleteFormula(_formulas[f]),
                    ),
                  ],
              ],
            ),
    );
  }
}

/// Formula nomi banneri. Yangi formulada nom avtomatik (A, B, C...),
/// tahrirlashda — card kaliti sifatida o'zgarmas.
class _FormulaNameBanner extends StatelessWidget {
  const _FormulaNameBanner({required this.name, this.auto = false});
  final String name;
  final bool auto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.label_outline_rounded,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Formula: $name',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (auto)
                    Text(
                      'Nom avtomatik beriladi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saqlangan bitta formula cardi: nomi yozilgan sarlavha + seriyalar.
/// Cardlar nom bo'yicha alifboda (API shunday qaytaradi).
class _SavedFormulaCard extends StatelessWidget {
  const _SavedFormulaCard({
    required this.formula,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });
  final PreparationFormula formula;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              key: ValueKey('preparation-formula-card-${formula.name}'),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.functions_rounded,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formula.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${formula.lines.length} ta seriya • tahrirlash uchun bosing',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'O‘chirish',
                      onPressed: deleting ? null : onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            for (var i = 0; i < formula.lines.length; i++)
              ListTile(
                key: ValueKey(
                    'preparation-formula-line-${formula.name}-${formula.lines[i].itemCode}'),
                leading: CircleAvatar(
                  child: Text('${i + 1}'),
                ),
                title: Text(
                  formula.lines[i].name.isEmpty
                      ? formula.lines[i].itemCode
                      : formula.lines[i].name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(formula.lines[i].itemCode),
                trailing: Text(
                  '${preparationDisplay(formula.lines[i].percent)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Jami foiz indikatori — Saqlash tugmasi tepasida doim ko'rinadi.
class _FormulaTotalBar extends StatelessWidget {
  const _FormulaTotalBar({required this.total});
  final BigInt? total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ok = total == BigInt.from(100000000);
    final text = total == null
        ? 'Jami: —'
        : 'Jami: ${preparationDisplay(preparationDecimalText(total!))}%';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ok
            ? Colors.green.withValues(alpha: 0.12)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok ? Colors.green : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.pie_chart_outline_rounded,
              size: 20,
              color: ok ? Colors.green : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ok ? Colors.green : scheme.onSurface,
                ),
              ),
            ),
            Text(
              '100% shart',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Validatsiya xatosi — fieldlar tagida emas, Saqlash tugmasi tepasida.
class _FormulaEditorError extends StatelessWidget {
  const _FormulaEditorError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      key: const ValueKey('preparation-formula-error'),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormulaRowCard extends StatelessWidget {
  const _FormulaRowCard({
    required this.index,
    required this.row,
    required this.saving,
    required this.onPick,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _FormulaRow row;
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
                decoration: const InputDecoration(
                  labelText: 'Foiz (%)',
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
