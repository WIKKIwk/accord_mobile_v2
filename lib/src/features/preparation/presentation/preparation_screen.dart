import 'dart:async';

import '../../waste/presentation/waste_operator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/inventory/inventory_view_store.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/spring_bottom_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../admin/presentation/widgets/admin_surface_tab_bar.dart';
import '../../shared/models/inventory_movement_models.dart';
import '../../shared/models/app_models.dart' show UserRole;
import '../../inventory/presentation/inventory_movements_screen.dart'
    show PreparationTransfersArgs;
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';
import 'preparation_navigation.dart';
import 'preparation_production_paddon_picker.dart';
import '../../../core/models/preparation_output_note.dart'
    show preparationNoteSelectionLimit;
import 'preparation_order_formula_screen.dart';
import 'preparation_formula_variants_screen.dart'
    show showPreparationFormulaRenameDialog;
import 'preparation_formula_shares_sheet.dart';
import '../../../core/localization/urdu_aware_text.dart';

part 'preparation_screen_forms.dart';
part 'preparation_order_consumption.dart';
part 'preparation_warehouse_rolls.dart';
part 'preparation_warehouse_management.dart';
part 'preparation_materials_screen.dart';
part 'preparation_formula_orders_screen.dart';
part 'preparation_formula_catalog_screen.dart';

const double _adminHomePanelCardGap = 4;

Future<void> _openPreparationScaleReceipt(
    BuildContext context, String? warehouse) async {
  await Navigator.of(context).pushNamed(
    AppRoutes.gscaleMode,
    arguments: warehouse,
  );
}

M3SegmentVerticalSlot _slotFor(int index, int length) {
  if (length <= 1) {
    return M3SegmentVerticalSlot.top;
  }
  if (index == 0) {
    return M3SegmentVerticalSlot.top;
  }
  if (index == length - 1) {
    return M3SegmentVerticalSlot.bottom;
  }
  return M3SegmentVerticalSlot.middle;
}

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({super.key, this.warehouseOnly = false});
  final bool warehouseOnly;
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  final _scope = currentSessionReadScope();
  bool get _current => mounted && _scope == currentSessionReadScope();
  PreparationSnapshot? _snapshot;
  PreparationPendingCommand? _pending;
  String? _warehouse, _error;
  bool _loading = true, _saving = false;
  bool get _locked => !_current || _loading || _saving || _pending != null;
  void _update(VoidCallback action) => setState(action);

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionChanged);
    _reload();
  }

  void _sessionChanged() {
    if (_current || !mounted) return;
    setState(() {
      _snapshot = null;
      _pending = null;
      _warehouse = null;
      _loading = false;
      _error = 'Akkaunt o‘zgargan. Sahifani qayta oching';
    });
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!_current) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pending = await MobileApi.instance.preparationPendingCommand();
      if (_current) setState(() => _pending = pending);
      final snapshot = await MobileApi.instance.preparationSnapshot();
      if (!_current) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.assignedWarehouses.contains(_warehouse)) {
          _warehouse = snapshot.assignedWarehouses.length == 1
              ? snapshot.assignedWarehouses.first
              : null;
        }
      });
    } catch (e) {
      if (_current) setState(() => _error = e.toString());
    } finally {
      if (_current) setState(() => _loading = false);
    }
  }

  /// Parent snapshot'dagi eng so'nggi material ro'yxati.
  /// [_submit] ichida [_reload] bo'lgani uchun mutation'dan keyin chaqirilsa
  /// yangi ma'lumot qaytaradi — qo'shimcha network so'rovsiz.
  List<PreparationMaterial> _syncedMaterials() =>
      _snapshot?.materials ?? const [];

  List<String> _syncedAssignedWarehouses() =>
      _snapshot?.assignedWarehouses ?? const [];

  List<String> _syncedMaterialWarehouses() =>
      _snapshot?.materialWarehouses ?? const [];

  List<dynamic> _syncedHistory() => _snapshot?.history ?? const [];

  Future<void> _submit(String kind, Map<String, dynamic> payload) async {
    if (_saving || !_current) return;
    setState(() => _saving = true);
    try {
      await MobileApi.instance.preparationSubmit(kind, payload);
      if (!_current) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: UrduAwareText('Saqlandi')));
    } catch (e) {
      if (_current) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (_current) {
        setState(() => _saving = false);
        await _reload();
      }
    }
  }

  Future<void> _openAndReload(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (_current) {
      await _reload();
    }
  }

  PreparationWarehouseScreen _warehouseScreen(PreparationSnapshot data) =>
      PreparationWarehouseScreen(
        warehouses: data.assignedWarehouses,
        assignedWarehouses: data.assignedWarehouses,
        materialWarehouses: data.materialWarehouses,
        initialWarehouse: _warehouse,
        materials: data.materials,
        history: data.history,
        locked: _locked,
        onWarehouseSelected: (w) => _update(() => _warehouse = w),
        onReceive: _receive,
        onCreateMaterial: _createMaterial,
        onReload: _reload,
        freshMaterials: _syncedMaterials,
        freshHistory: _syncedHistory,
        freshAssignedWarehouses: _syncedAssignedWarehouses,
        freshMaterialWarehouses: _syncedMaterialWarehouses,
        freshManagedWarehouses: () => _snapshot?.managedWarehouses ?? const [],
        freshAssignedWarehouseIds: () =>
            _snapshot?.assignedWarehouseIds ?? const {},
      );

  Future<void> _openWarehouse(PreparationSnapshot data) =>
      _openAndReload(_warehouseScreen(data));

  Future<void> _startSeriyoReceipt(PreparationSnapshot data) async {
    final warehouses = data.assignedWarehouses
        .where((w) =>
            _receivableSeriyo(data.materials, w, data.materialWarehouses)
                .isNotEmpty)
        .toList();
    if (warehouses.isEmpty || _locked) return;
    final warehouse = warehouses.contains(_warehouse)
        ? _warehouse
        : warehouses.length == 1
            ? warehouses.single
            : await _pickPreparationItem<String>(
                context,
                title: 'Seriyo kirimi uchun ombor tanlang',
                items: warehouses,
                label: (w) => w,
                subtitle: (_) => '',
              );
    if (!mounted || warehouse == null || _locked) return;
    setState(() => _warehouse = warehouse);
    final material = await _pickSeriyo(
        context, warehouse, data.materials, data.materialWarehouses);
    if (material != null && mounted && _warehouse == warehouse) {
      await _receive(material);
    }
  }

  List<AdminFabMenuAction> _fabActions(PreparationSnapshot data) => [
        if (!_locked &&
            data.assignedWarehouses.any((w) =>
                _receivableSeriyo(data.materials, w, data.materialWarehouses)
                    .isNotEmpty))
          AdminFabMenuAction(
            title: 'Seriyo kirimi',
            icon: Icons.add_circle_outline_rounded,
            onTap: () => _startSeriyoReceipt(data),
          ),
        if (!_locked && AppRouter.canOpenRoute(AppRoutes.gscaleMode))
          AdminFabMenuAction(
            title: 'Rulonni tortish',
            icon: Icons.scale_outlined,
            onTap: () async {
              await _openPreparationScaleReceipt(context, _warehouse);
              if (_current) await _reload();
            },
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = _snapshot;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    if (widget.warehouseOnly && data != null) return _warehouseScreen(data);
    return AppShell(
      title: 'Tayyorlov masteri',
      subtitle: 'Ichki homashyo ta’minoti',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      actions: const [WasteOperatorAction()],
      drawer: const PreparationDrawer(),
      bottom: PreparationDock(
          primaryFabActions: data == null ? null : _fabActions(data)),
      child: data == null && _loading
          ? const Center(child: AppLoadingIndicator())
          : AppRefreshIndicator(
              onRefresh: () async {
                if (!_saving && !_loading) await _reload();
              },
              allowRefreshOnShortContent: true,
              child: ListView(
                physics: const TopRefreshScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomPadding),
                children: [
                  const SizedBox(height: _adminHomePanelCardGap),
                  if (_error != null) ...[
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
                        backgroundColor: scheme.errorContainer,
                        title: 'Xatolik yuz berdi',
                        subtitle: _error,
                        value: '',
                        leading: Icon(
                          Icons.error_outline_rounded,
                          color: scheme.onErrorContainer,
                        ),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_pending != null) ...[
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
                        backgroundColor: scheme.tertiaryContainer,
                        title: 'Tasdiqlanmagan operatsiya',
                        subtitle: _pending!.kind == 'receipts'
                            ? 'Kirim: ${_pending!.payload['kg']} kg'
                            : _pending!.kind == 'materials'
                                ? 'Homashyo: ${_pending!.payload['name']}'
                                : 'Order: ${_pending!.payload['order_id']}',
                        value: 'Tekshirish',
                        leading: Icon(
                          Icons.pending_actions_rounded,
                          color: scheme.onTertiaryContainer,
                        ),
                        onTap: _saving
                            ? null
                            : () => _submit(
                                  _pending!.kind,
                                  _pending!.payload,
                                ),
                        elevation: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (data != null) ...[
                    if (data.assignedWarehouses.isEmpty) ...[
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
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warehouse_outlined,
                                  color: scheme.onTertiaryContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: UrduAwareText(
                                    'Sizga ombor biriktirilmagan. Admin foydalanuvchi kartasidan ombor biriktirishi kerak.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    M3SegmentSpacedColumn(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _adminHomePanelCardGap,
                      ),
                      children: [
                        for (final (slot, title, description, open) in [
                          (
                            M3SegmentVerticalSlot.top,
                            'Ombor',
                            'Seriyo, tayyor rulonlar va transferlar',
                            () => _openWarehouse(data)
                          ),
                          if (AppRouter.canOpenRoute(
                              AppRoutes.preparationTransferHistory))
                            (
                              M3SegmentVerticalSlot.middle,
                              'Transfer tarixi',
                              'Omborlar orasidagi yakunlangan transferlar',
                              () => Navigator.of(context).pushNamed(
                                  AppRoutes.preparationTransferHistory)
                            ),
                          if (AppRouter.canOpenRoute(AppRoutes.supplySequence))
                            (
                              M3SegmentVerticalSlot.middle,
                              'Buyurtmalar',
                              'Faol buyurtmalar navbati',
                              () => Navigator.of(context)
                                  .pushNamed(AppRoutes.supplySequence)
                            ),
                          (
                            M3SegmentVerticalSlot.middle,
                            'Ishlab chiqarish',
                            'Partiyalar, rulonlar va paddonlar',
                            () => Navigator.of(context)
                                .pushNamed(AppRoutes.preparationProduction)
                          ),
                          (
                            M3SegmentVerticalSlot.bottom,
                            'Formulalar',
                            'Mahsulot bo‘yicha va saqlangan formulalar',
                            () => _openAndReload(
                                const PreparationFormulaOrdersScreen())
                          ),
                        ])
                          AdminSummaryCard(
                            slot: slot,
                            cornerRadius: slot == M3SegmentVerticalSlot.middle
                                ? M3SegmentedListGeometry.cornerMiddle
                                : M3SegmentedListGeometry.cornerLarge,
                            backgroundColor: scheme.surfaceContainerLowest,
                            title: localizeUrduUiText(title),
                            subtitle: localizeUrduUiText(description),
                            titleStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            value: title == 'Ombor' ? (_warehouse ?? '') : '',
                            showChevron: false,
                            onTap: open,
                            elevation: 4,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
