import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../models/preparation_models.dart';
import 'preparation_navigation.dart';

part 'preparation_screen_forms.dart';

const double _adminHomePanelCardGap = 4;

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
  const PreparationScreen({super.key});
  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  PreparationSnapshot? _snapshot;
  PreparationPendingCommand? _pending;
  PreparationOrder? _order;
  String? _warehouse, _error;
  bool _loading = true, _saving = false;
  final Map<String, TextEditingController> _percent = {};
  bool get _locked => _loading || _saving || _pending != null;
  void _update(VoidCallback action) => setState(action);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    for (final c in _percent.values) {
      c.dispose();
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
      final pending = await MobileApi.instance.preparationPendingCommand();
      if (mounted) setState(() => _pending = pending);
      final snapshot = await MobileApi.instance.preparationSnapshot();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (!snapshot.warehouses.contains(_warehouse)) {
          _warehouse = snapshot.warehouses.length == 1
              ? snapshot.warehouses.first
              : null;
        }
        if (_order != null) {
          final fresh =
              snapshot.orders.where((o) => o.id == _order!.id).firstOrNull;
          if (fresh == null || fresh.saved) {
            _clearRecipe();
          } else {
            _order = fresh;
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearRecipe() {
    _order = null;
    for (final c in _percent.values) {
      c.dispose();
    }
    _percent.clear();
  }

  /// Parent snapshot'dagi eng so'nggi material ro'yxati.
  /// [_submit] ichida [_reload] bo'lgani uchun mutation'dan keyin chaqirilsa
  /// yangi ma'lumot qaytaradi — qo'shimcha network so'rovsiz.
  List<PreparationMaterial> _syncedMaterials() =>
      _snapshot?.materials ?? const [];

  List<dynamic> _syncedHistory() => _snapshot?.history ?? const [];

  Future<void> _submit(String kind, Map<String, dynamic> payload) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await MobileApi.instance.preparationSubmit(kind, payload);
      if (!mounted) return;
      if (kind == 'consumptions') setState(_clearRecipe);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saqlandi')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        await _reload();
      }
    }
  }

  Future<void> _openAndReload(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) {
      await _reload();
    }
  }

  void _openWarehouse(PreparationSnapshot data) {
    _openAndReload(PreparationWarehouseScreen(
      warehouses: data.warehouses,
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
    ));
  }

  Future<void> _startKirim(PreparationSnapshot data) async {
    if (_warehouse == null) {
      _openWarehouse(data);
      return;
    }
    final material = await _pick<PreparationMaterial>(
      title: 'Homashyo tanlang',
      // Barcha homashyolar: yangi (qoldiqsiz) materialga ham birinchi
      // kirim shu yerdan qilinadi. Balans filtri uni yashirib qo'yardi.
      items: data.materials.toList(),
      label: (m) => m.name,
      subtitle: (m) =>
          'Mavjud: ${preparationDisplay(m.available(_warehouse))} kg',
    );
    if (material != null && mounted) await _receive(material);
  }

  List<AdminFabMenuAction> _fabActions(PreparationSnapshot data) => [
        AdminFabMenuAction(
          title: 'Ombor',
          icon: Icons.warehouse_outlined,
          onTap: () => _openWarehouse(data),
        ),
        AdminFabMenuAction(
          title: 'Kirim',
          icon: Icons.add_circle_outline_rounded,
          onTap: () => _startKirim(data),
        ),
        AdminFabMenuAction(
          title: 'Buyurtmalar',
          icon: Icons.list_alt_rounded,
          onTap: () => _openOrders(),
        ),
        AdminFabMenuAction(
          title: 'Tarix',
          icon: Icons.history_outlined,
          onTap: () => _openHistory(data),
        ),
      ];

  void _openOrders() {
    // Tayyorlov masteri uchun alohida generate qilingan Buyurtmalar
    // sahifasi olib tashlandi — o'rniga mavjud Ketma-ketlik sahifasi ochiladi.
    AppRootNavigation.replaceRootRoute(context, AppRoutes.supplySequence);
  }

  void _openHistory(PreparationSnapshot data) {
    _openAndReload(PreparationHistoryScreen(
      history: data.history,
      onReload: _reload,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final data = _snapshot;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Tayyorlov masteri',
      subtitle: 'Ichki homashyo ta’minoti',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      drawer: const PreparationDrawer(),
      bottom: PreparationDock(
          primaryFabActions: data == null ? null : _fabActions(data)),
      actions: [
        IconButton(
          tooltip: 'Yangilash',
          onPressed: _saving || _loading ? null : _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
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
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _loading ? null : _reload,
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
                    if (data.warehouses.isEmpty) ...[
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
                                  child: Text(
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
                        if (data.warehouses.isNotEmpty)
                          AdminSummaryCard(
                            slot: M3SegmentVerticalSlot.top,
                            cornerRadius: M3SegmentedListGeometry.cornerLarge,
                            backgroundColor: scheme.surfaceContainerLowest,
                            title: 'Ombor',
                            titleStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            value: _warehouse ?? 'Ombor tanlang',
                            onTap: _locked ? null : () => _openWarehouse(data),
                            elevation: 4,
                          ),
                        AdminSummaryCard(
                          slot: M3SegmentVerticalSlot.middle,
                          cornerRadius: M3SegmentedListGeometry.cornerMiddle,
                          backgroundColor: scheme.surfaceContainerLowest,
                          title: 'Buyurtmalar',
                          titleStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          value: '${data.orders.where((o) => !o.saved).length}',
                          onTap: () => _openOrders(),
                          elevation: 4,
                        ),
                        AdminSummaryCard(
                          slot: M3SegmentVerticalSlot.bottom,
                          cornerRadius: M3SegmentedListGeometry.cornerLarge,
                          backgroundColor: scheme.surfaceContainerLowest,
                          title: 'Tarix',
                          titleStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          value: '${data.history.length}',
                          onTap: () => _openHistory(data),
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
