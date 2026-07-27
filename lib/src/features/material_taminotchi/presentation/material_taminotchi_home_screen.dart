import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/admin_raw_material_assignment_screen.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import 'widgets/material_taminotchi_dock.dart';
import 'widgets/material_taminotchi_navigation_drawer.dart';
import 'package:flutter/material.dart';

class MaterialTaminotchiHistoryScreen extends StatefulWidget {
  const MaterialTaminotchiHistoryScreen({super.key});

  @override
  State<MaterialTaminotchiHistoryScreen> createState() =>
      _MaterialTaminotchiHistoryScreenState();
}

class _MaterialTaminotchiHistoryScreenState
    extends State<MaterialTaminotchiHistoryScreen> {
  late Future<List<AdminRawMaterialEvent>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<AdminRawMaterialEvent>> _loadHistory() {
    return MobileApi.instance.adminRawMaterialHistory(limit: 100);
  }

  Future<void> _refresh() async {
    final future = _loadHistory();
    setState(() {
      _historyFuture = future;
    });
    await future;
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _goBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed(AppRoutes.materialHome);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: _goBack,
      ),
      title: 'Harakatlar tarixi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: MaterialTaminotchiNavigationDrawer(
        selectedRouteName: AppRoutes.materialHistory,
        onNavigate: _openDrawerRoute,
      ),
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      bottom: const MaterialTaminotchiDock(
        activeTab: MaterialTaminotchiDockTab.home,
      ),
      child: AppRefreshIndicator(
        onRefresh: _refresh,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
          children: [
            _MaterialHistoryPanel(
              future: _historyFuture,
              maxItems: 100,
              onRetry: () {
                setState(() {
                  _historyFuture = _loadHistory();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MaterialTaminotchiHomeScreen extends StatefulWidget {
  const MaterialTaminotchiHomeScreen({super.key});

  @override
  State<MaterialTaminotchiHomeScreen> createState() =>
      _MaterialTaminotchiHomeScreenState();
}

class _MaterialTaminotchiHomeScreenState
    extends State<MaterialTaminotchiHomeScreen> {
  Future<void> _refreshProfile() async {
    try {
      await MobileApi.instance.profile();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openRoute(String route) {
    if (route == AppRoutes.profile || route == AppRoutes.gscaleMode) {
      Navigator.of(context).pushNamed(route);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _scanRawMaterial(bool hasMaterialGroupScope) async {
    if (!hasMaterialGroupScope) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval material guruhlari biriktirilishi kerak'),
        ),
      );
      return;
    }
    final barcode = await showRawMaterialScanDialog(context);
    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.adminRawMaterialAssignments,
      arguments: AdminRawMaterialAssignmentArgs(
        initialBarcode: rawMaterialBarcodeFromQr(barcode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final groups = profile?.assignedItemGroups ?? const <String>[];
    final hasMaterialGroupScope = groups.isNotEmpty;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Material ta’minotchisi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: MaterialTaminotchiNavigationDrawer(
        selectedRouteName: AppRoutes.materialHome,
        onNavigate: _openDrawerRoute,
      ),
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      bottom: const MaterialTaminotchiDock(
        activeTab: MaterialTaminotchiDockTab.home,
      ),
      child: Stack(
        children: [
          AppRefreshIndicator(
            onRefresh: _refreshProfile,
            allowRefreshOnShortContent: true,
            child: ListView(
              physics: const TopRefreshScrollPhysics(),
              padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
              children: [
                if (!hasMaterialGroupScope) ...[
                  const SmoothAppear(
                    delay: Duration(milliseconds: 20),
                    child: _MaterialScopeNotice(),
                  ),
                  const SizedBox(height: 14),
                ],
                SmoothAppear(
                  delay: const Duration(milliseconds: 40),
                  child: _MaterialActionPanel(
                    hasMaterialGroupScope: hasMaterialGroupScope,
                    onOpenRoute: _openRoute,
                  ),
                ),
              ],
            ),
          ),
          if (AppRouter.canOpenRoute(AppRoutes.adminRawMaterialAssignments))
            PositionedDirectional(
              end: 16,
              bottom: 16,
              child: FloatingActionButton(
                key: const ValueKey('material-raw-material-scan-fab'),
                heroTag: 'material-raw-material-scan',
                tooltip: 'Homashyo QR scan',
                onPressed: () => _scanRawMaterial(hasMaterialGroupScope),
                child: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _MaterialHistoryPanel extends StatelessWidget {
  const _MaterialHistoryPanel({
    required this.future,
    required this.onRetry,
    this.maxItems = 6,
  });

  final Future<List<AdminRawMaterialEvent>> future;
  final VoidCallback onRetry;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<List<AdminRawMaterialEvent>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _MaterialHistoryLoading();
              }
              if (snapshot.hasError) {
                final message = _materialHistoryErrorMessage(snapshot.error);
                return _MaterialHistoryMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Tarix yuklanmadi',
                  subtitle: message,
                  onTap: onRetry,
                );
              }
              final events = snapshot.data ?? const <AdminRawMaterialEvent>[];
              if (events.isEmpty) {
                return const _MaterialHistoryMessage(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Harakatlar hali yo‘q',
                );
              }
              final visible = events.take(maxItems).toList(growable: false);
              return M3SegmentSpacedColumn(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < visible.length; i++)
                    _MaterialHistoryCard(
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        i,
                        visible.length,
                      ),
                      event: visible[i],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MaterialHistoryLoading extends StatelessWidget {
  const _MaterialHistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _MaterialHistoryMessage extends StatelessWidget {
  const _MaterialHistoryMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.top,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.actionSurface(context)
          : scheme.surfaceContainerLowest,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!.trim(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialHistoryCard extends StatefulWidget {
  const _MaterialHistoryCard({required this.slot, required this.event});

  final M3SegmentVerticalSlot slot;
  final AdminRawMaterialEvent event;

  @override
  State<_MaterialHistoryCard> createState() => _MaterialHistoryCardState();
}

class _MaterialHistoryCardState extends State<_MaterialHistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? AppTheme.actionSurface(context)
        : scheme.surfaceContainerLowest;
    return M3SegmentFilledSurface(
      slot: widget.slot,
      cornerRadius: widget.slot == M3SegmentVerticalSlot.middle
          ? M3SegmentedListGeometry.cornerMiddle
          : M3SegmentedListGeometry.cornerLarge,
      backgroundColor: backgroundColor,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _materialHistoryIcon(widget.event.eventType),
                  size: 22,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _materialHistoryTitle(widget.event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _materialHistorySubtitle(widget.event),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _materialHistoryTime(widget.event.occurredAtUnix),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(left: 34, top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final detail
                              in _materialHistoryDetails(widget.event))
                            _MaterialHistoryDetailLine(
                              label: detail.label,
                              value: detail.value,
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialHistoryDetailLine extends StatelessWidget {
  const _MaterialHistoryDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialActionPanel extends StatelessWidget {
  const _MaterialActionPanel({
    required this.hasMaterialGroupScope,
    required this.onOpenRoute,
  });

  final bool hasMaterialGroupScope;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final actions = _materialHomeActions(hasMaterialGroupScope);
    return M3SegmentSpacedColumn(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        for (var i = 0; i < actions.length; i++)
          _MaterialActionCard(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              i,
              actions.length,
            ),
            action: actions[i],
            onTap: () => actions[i].open(context, onOpenRoute),
          ),
      ],
    );
  }
}

class _MaterialHomeAction {
  const _MaterialHomeAction({
    required this.icon,
    required this.title,
    required this.routeName,
    this.requiresMaterialGroupScope = false,
  });

  final IconData icon;
  final String title;
  final String routeName;
  final bool requiresMaterialGroupScope;

  void open(BuildContext context, ValueChanged<String> onOpenRoute) {
    if (requiresMaterialGroupScope) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval material guruhlari biriktirilishi kerak'),
        ),
      );
      return;
    }
    onOpenRoute(routeName);
  }
}

List<_MaterialHomeAction> _materialHomeActions(bool hasMaterialGroupScope) {
  final candidates = [
    const _MaterialHomeAction(
      icon: Icons.scale_outlined,
      title: 'Tarozilar rejimi',
      routeName: AppRoutes.gscaleMode,
    ),
    _MaterialHomeAction(
      icon: Icons.inventory_2_outlined,
      title: 'Homashyo biriktirish',
      routeName: AppRoutes.adminRawMaterialAssignments,
      requiresMaterialGroupScope: !hasMaterialGroupScope,
    ),
    const _MaterialHomeAction(
      icon: Icons.warehouse_outlined,
      title: 'Omborlarim',
      routeName: AppRoutes.adminWarehouses,
    ),
    const _MaterialHomeAction(
      icon: Icons.swap_horiz_rounded,
      title: 'Joylashtirish va transfer',
      routeName: AppRoutes.inventoryMovements,
    ),
  ];
  return candidates
      .where((action) => AppRouter.canOpenRoute(action.routeName))
      .toList(growable: false);
}

class _MaterialActionCard extends StatelessWidget {
  const _MaterialActionCard({
    required this.slot,
    required this.action,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final _MaterialHomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? AppTheme.actionSurface(context)
        : scheme.surfaceContainerLowest;
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: slot == M3SegmentVerticalSlot.middle
          ? M3SegmentedListGeometry.cornerMiddle
          : M3SegmentedListGeometry.cornerLarge,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(action.icon, size: 23, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(action.title, style: theme.textTheme.titleMedium),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialScopeNotice extends StatelessWidget {
  const _MaterialScopeNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mahsulot guruhi biriktirilmagan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Homashyo qabul qilish va zakazga ulash uchun admin avval material guruhini biriktirishi kerak.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      height: 1.25,
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

IconData _materialHistoryIcon(String type) {
  return switch (type) {
    'receipt_posted' => Icons.add_business_outlined,
    'order_reserved' => Icons.outbox_outlined,
    'order_unreserved' => Icons.undo_rounded,
    'usage_started' => Icons.play_circle_outline_rounded,
    'consumption_posted' => Icons.done_all_rounded,
    'adjustment_increase' => Icons.add_circle_outline_rounded,
    'adjustment_decrease' => Icons.remove_circle_outline_rounded,
    'transfer_in' => Icons.call_received_rounded,
    'transfer_out' => Icons.call_made_rounded,
    _ => Icons.history_rounded,
  };
}

List<({String label, String value})> _materialHistoryDetails(
  AdminRawMaterialEvent event,
) {
  final details = <({String label, String value})>[];

  void add(String label, String value) {
    if (value.trim().isNotEmpty) {
      details.add((label: label, value: value.trim()));
    }
  }

  final itemName = event.itemName.trim();
  add('Harakat turi', _materialHistoryEventTypeLabel(event.eventType));
  add('Mahsulot', itemName.isEmpty ? event.itemCode : itemName);
  add('Mahsulot kodi', event.itemCode);
  add('Ombor', event.warehouse);
  add('Miqdor', _materialHistoryQuantity(event.qtyDelta, event.uom));
  add('Shtrix-kod', event.barcode);

  final before = _materialHistoryStatusLabel(event.stockStatusBefore);
  final after = _materialHistoryStatusLabel(event.stockStatusAfter);
  add(
    'Holati',
    before.isEmpty || after.isEmpty || before == after
        ? after.isNotEmpty
            ? after
            : before
        : '$before → $after',
  );
  add('Zakaz', event.orderId);
  add('Apparat', event.apparatus);

  final actor = [
    event.actorDisplayName.trim(),
    event.actorRef.trim(),
  ].where((value) => value.isNotEmpty).join(' • ');
  add('Bajargan', actor);
  add('Rol', _materialHistoryRoleLabel(event.actorRole));
  add('Manba', _materialHistorySourceLabel(event.sourceType));
  add('Receipt raqami', event.sourceId);
  add('Event ID', event.eventId);
  add('Vaqt', _materialHistoryDateTime(event.occurredAtUnix));
  add('Yozilgan vaqt', _materialHistoryDateTime(event.recordedAtUnix));
  return details;
}

String _materialHistoryEventTypeLabel(String type) {
  return switch (type.trim().toLowerCase()) {
    'receipt_posted' => 'Omborga kirim qilindi',
    'order_reserved' => 'Zakaz uchun band qilindi',
    'order_unreserved' => 'Zakaz bandi yechildi',
    'usage_started' => 'Ishlatishga o‘tkazildi',
    'consumption_posted' => 'Material sarflandi',
    'adjustment_increase' => 'Miqdor oshirildi',
    'adjustment_decrease' => 'Miqdor kamaytirildi',
    'transfer_in' => 'Omborga transfer qilindi',
    'transfer_out' => 'Ombordan transfer qilindi',
    final value when value.isEmpty => '',
    final value => value,
  };
}

String _materialHistoryStatusLabel(String status) {
  return switch (status.trim().toLowerCase()) {
    'available' => 'Mavjud',
    'reserved' => 'Band qilingan',
    'in_use' => 'Ishlatilmoqda',
    'consumed' => 'Sarflangan',
    final value when value.isEmpty => '',
    final value => value,
  };
}

String _materialHistoryQuantity(double quantity, String uom) {
  if (quantity == 0) {
    return '';
  }
  final sign = quantity > 0 ? '+' : '';
  final unit = uom.trim();
  return '$sign${quantity.toStringAsFixed(3)}${unit.isEmpty ? '' : ' $unit'}';
}

String _materialHistoryRoleLabel(String role) {
  return switch (role.trim().toLowerCase()) {
    'material_taminotchi' => 'Material ta’minotchisi',
    'admin' => 'Administrator',
    'werka' => 'Werka',
    'supplier' => 'Ta’minotchi',
    final value when value.isEmpty => '',
    final value => value,
  };
}

String _materialHistorySourceLabel(String source) {
  return switch (source.trim().toLowerCase()) {
    'gscale_receipt' => 'Tarozi kirimi',
    'order_assignment' => 'Zakaz biriktirishi',
    'consumption' => 'Sarflanish',
    'manual_adjustment' => 'Qo‘lda tuzatish',
    'warehouse_transfer' => 'Omborlararo transfer',
    'system' => 'Tizim',
    final value when value.isEmpty => '',
    final value => value,
  };
}

String _materialHistoryTitle(AdminRawMaterialEvent event) {
  final item = event.itemName.trim().isNotEmpty
      ? event.itemName.trim()
      : event.itemCode.trim();
  final qty = event.qtyDelta == 0
      ? ''
      : ' ${event.qtyDelta.abs().toStringAsFixed(3)} ${event.uom}';
  return switch (event.eventType) {
    'receipt_posted' => '$item kirim$qty',
    'order_reserved' => '$item berildi',
    'order_unreserved' => '$item yechildi',
    'usage_started' => '$item ishlatishga o‘tdi',
    'consumption_posted' => '$item sarflandi$qty',
    'adjustment_increase' => '$item tuzatildi$qty',
    'adjustment_decrease' => '$item kamaytirildi$qty',
    'transfer_in' => '$item transfer kirim$qty',
    'transfer_out' => '$item transfer chiqim$qty',
    _ => item,
  };
}

String _materialHistorySubtitle(AdminRawMaterialEvent event) {
  final parts = <String>[
    if (event.warehouse.trim().isNotEmpty) event.warehouse.trim(),
    if (event.orderId.trim().isNotEmpty) 'Zakaz ${event.orderId.trim()}',
    if (event.apparatus.trim().isNotEmpty) event.apparatus.trim(),
    if (event.barcode.trim().isNotEmpty) event.barcode.trim(),
  ];
  return parts.join(' • ');
}

String _materialHistoryTime(int unix) {
  if (unix <= 0) {
    return '';
  }
  final time = DateTime.fromMillisecondsSinceEpoch(
    unix * 1000,
    isUtc: true,
  ).toLocal();
  final now = DateTime.now();
  final clock = '${_two(time.hour)}:${_two(time.minute)}';
  if (time.year == now.year && time.month == now.month && time.day == now.day) {
    return clock;
  }
  return '${_two(time.day)}.${_two(time.month)} $clock';
}

String _materialHistoryDateTime(int unix) {
  if (unix <= 0) {
    return '';
  }
  final time = DateTime.fromMillisecondsSinceEpoch(
    unix * 1000,
    isUtc: true,
  ).toLocal();
  return '${_two(time.day)}.${_two(time.month)}.${time.year} '
      '${_two(time.hour)}:${_two(time.minute)}';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _materialHistoryErrorMessage(Object? error) {
  if (error is MobileApiException) {
    final status = error.statusCode == null ? '' : ' (${error.statusCode})';
    if (error.code == 'raw_material_history_not_found') {
      return 'Backend hali yangi history endpoint bilan ko‘tarilmagan$status';
    }
    return '${error.message}$status';
  }
  return 'Serverdan ma’lumot olinmadi';
}
