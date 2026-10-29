import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../models/preparation_models.dart';
import 'preparation_navigation.dart';
import 'preparation_order_formula_screen.dart';

class PreparationFormulaVariantsScreen extends StatefulWidget {
  const PreparationFormulaVariantsScreen(
      {super.key,
      required this.orderId,
      required this.orderCode,
      required this.productCode,
      required this.productTitle,
      required this.materialId,
      required this.materialName,
      this.customerName});
  final String orderId,
      orderCode,
      productCode,
      productTitle,
      materialId,
      materialName;
  final String? customerName;

  @override
  State<PreparationFormulaVariantsScreen> createState() =>
      _PreparationFormulaVariantsScreenState();
}

class _PreparationFormulaVariantsScreenState
    extends State<PreparationFormulaVariantsScreen> {
  List<PreparationFormulaVariant> _variants = [];
  bool _loading = true, _creating = false, _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final variants = await MobileApi.instance.preparationFormulaVariants(
          productCode: widget.productCode, materialId: widget.materialId);
      if (mounted) setState(() => _variants = variants);
    } catch (error) {
      if (mounted) {
        setState(() => _error = preparationFormulaErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(PreparationFormulaVariant variant) async {
    if (_opening) return;
    _opening = true;
    await Navigator.of(context).push(PreparationOrderFormulaScreen.route(
      orderId: widget.orderId,
      orderCode: widget.orderCode,
      productCode: widget.productCode,
      productTitle: widget.productTitle,
      materialId: widget.materialId,
      materialName: widget.materialName,
      customerName: widget.customerName,
      variantId: variant.id,
      variantName: variant.name,
      variantCode: variant.code,
    ));
    _opening = false;
    if (mounted) await _load();
  }

  Future<void> _create() async {
    if (_creating || _opening) return;
    setState(() => _creating = true);
    final variant = await showDialog<PreparationFormulaVariant>(
        context: context,
        builder: (_) => _CreateVariantDialog(
            productCode: widget.productCode, materialId: widget.materialId));
    if (!mounted) return;
    setState(() {
      _creating = false;
      if (variant != null && !_variants.any((v) => v.id == variant.id)) {
        _variants = [..._variants, variant];
      }
    });
    if (variant != null) await _open(variant);
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Shnek formulalar',
        subtitle: '${widget.materialName} • ${widget.orderCode}',
        nativeTopBar: true,
        contentPadding: EdgeInsets.zero,
        bottom: PreparationDock(primaryFabActions: [
          AdminFabMenuAction(
            title: 'Variant qo‘shish',
            icon: Icons.add_rounded,
            onTap: _create,
          )
        ]),
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : AppRefreshIndicator(
                onRefresh: _load,
                allowRefreshOnShortContent: true,
                child: ListView(
                  physics: const TopRefreshScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: UrduAwareText(
                            '${widget.orderCode} • ${widget.productTitle}',
                            style: Theme.of(context).textTheme.titleSmall)),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(children: [
                            Text(_error!),
                            TextButton(
                                onPressed: _load,
                                child: const UrduAwareText('Qayta urinish')),
                          ])),
                    if (_variants.isEmpty && _error == null)
                      const Padding(
                          padding: EdgeInsets.all(16),
                          child: UrduAwareText(
                              'Hali shnek varianti yo‘q. FAB orqali variant qo‘shing.')),
                    M3SegmentSpacedColumn(children: [
                      for (var i = 0; i < _variants.length; i++)
                        AdminCatalogListRow(
                          key: ValueKey(
                              'preparation-formula-variant-${_variants[i].id}'),
                          slot: M3SegmentedListGeometry
                              .standaloneListSlotForIndex(i, _variants.length),
                          icon: Icons.functions_rounded,
                          title: _variants[i].name,
                          subtitle: [
                            if (_variants[i].code.isNotEmpty) _variants[i].code,
                            _variants[i].formulaCount == 0
                                ? 'Tarkib hali kiritilmagan'
                                : '${_variants[i].formulaCount} ta ichki formula • ${_variants[i].sharesComplete ? 'jami 100%' : 'ulushlar belgilanmagan'}',
                          ].join(' • '),
                          onTap: _creating || _opening
                              ? null
                              : () => _open(_variants[i]),
                        ),
                    ]),
                  ],
                ),
              ),
      );
}

class _CreateVariantDialog extends StatefulWidget {
  const _CreateVariantDialog(
      {required this.productCode, required this.materialId});
  final String productCode, materialId;
  @override
  State<_CreateVariantDialog> createState() => _CreateVariantDialogState();
}

class _CreateVariantDialogState extends State<_CreateVariantDialog> {
  final _name = TextEditingController();
  final _requestId = newPreparationRequestId();
  bool _saving = false;
  String? _error;
  String get _value =>
      _name.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).join(' ');
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _value.isEmpty || _value.runes.length > 160) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final variant = await MobileApi.instance.preparationCreateFormulaVariant(
          productCode: widget.productCode,
          materialId: widget.materialId,
          name: _value,
          requestId: _requestId);
      if (mounted) Navigator.of(context).pop(variant);
    } catch (error) {
      if (mounted) {
        setState(() => _error = preparationFormulaErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const UrduAwareText('Shnek variantiga nom bering'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
              key: const ValueKey('preparation-variant-name'),
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Variant nomi'),
              onChanged: (_) => setState(() => _error = null),
              onFieldSubmitted: (_) => _save()),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ])),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const UrduAwareText('Bekor qilish')),
          FilledButton(
              key: const ValueKey('preparation-variant-create'),
              onPressed:
                  !_saving && _value.isNotEmpty && _value.runes.length <= 160
                      ? _save
                      : null,
              child: UrduAwareText(_saving ? 'Saqlanmoqda…' : 'Saqlash')),
        ],
      ));
}
