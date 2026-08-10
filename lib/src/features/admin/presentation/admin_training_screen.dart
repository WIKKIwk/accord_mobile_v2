import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../admin/logic/production_map_pechat_rules.dart';
import '../../admin/models/production_map_models.dart';
import '../../shared/models/app_models.dart';
import 'admin_calculate_screen.dart';
import 'admin_training_order_helpers.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_top_notice.dart';

const double _adminTrainingPanelGap = 4;

class AdminTrainingScreen extends StatefulWidget {
  const AdminTrainingScreen({super.key});

  @override
  State<AdminTrainingScreen> createState() => _AdminTrainingScreenState();
}

class _AdminTrainingScreenState extends State<AdminTrainingScreen> {
  List<AdminApparatus> _apparatus = const [];
  List<ProductionMapSaved> _orders = const [];
  List<AdminRawMaterialAssignment> _assignments = const [];
  bool _loading = true;
  String? _error;
  String? _savingId;
  String? _linkingOrderId;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        MobileApi.instance.adminTrainingApparatus(),
        MobileApi.instance.adminTrainingProductionMaps(),
        MobileApi.instance.adminTrainingRawMaterialAssignments(),
      ]);
      if (!mounted) {
        return;
      }
      final apparatus = [...results[0] as List<AdminApparatus>]..sort(
          (left, right) => left.name.toLowerCase().compareTo(
                right.name.toLowerCase(),
              ),
        );
      final orders = (results[1] as List<ProductionMapSaved>)
          .where(
            (order) => order.map.id.trim().startsWith('training-'),
          )
          .toList()
        ..sort(
          (left, right) => _trainingOrderLabel(left).toLowerCase().compareTo(
                _trainingOrderLabel(right).toLowerCase(),
              ),
        );
      setState(() {
        _apparatus = apparatus;
        _orders = orders;
        _assignments = [
          ...results[2] as List<AdminRawMaterialAssignment>,
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Training ma’lumotlari yuklanmadi';
      });
    }
  }

  Future<void> _setTrainingEnabled(
    AdminApparatus apparatus,
    bool enabled,
  ) async {
    if (_savingId != null) {
      return;
    }
    setState(() => _savingId = apparatus.id);
    try {
      await MobileApi.instance.adminSetTrainingApparatusMode(
        apparatus: apparatus.name,
        enabled: enabled,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _apparatus = [
          for (final item in _apparatus)
            if (item.id == apparatus.id)
              item.copyWith(trainingEnabled: enabled)
            else
              item,
        ];
      });
      showAdminTopNotice(
        context,
        enabled ? 'Training rejimi yoqildi' : 'Training rejimi o‘chirildi',
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(context, 'Training rejimi saqlanmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _savingId = null);
      }
    }
  }

  Future<void> _linkOrder(AdminApparatus apparatus) async {
    if (_linkingOrderId != null) {
      return;
    }
    if (!isTrainingOrderApparatus(apparatus)) {
      showAdminTopNotice(
        context,
        'Training order faqat 7 ta rangli bosma aparatga ulanadi',
      );
      return;
    }
    if (!apparatus.trainingEnabled) {
      showAdminTopNotice(
        context,
        'Avval shu aparat uchun Training rejimini yoqing',
      );
      return;
    }
    final availableOrders = _orders
        .where((order) => !trainingOrderHasApparatus(order.map))
        .toList(growable: false);
    setState(() => _linkingOrderId = apparatus.id);
    try {
      final draft = await showModalBottomSheet<_TrainingOrderLinkDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _TrainingOrderLinkSheet(
          apparatus: apparatus,
          orders: availableOrders,
        ),
      );
      if (draft == null || !mounted) {
        return;
      }
      final linkedMap = assignTrainingOrderToApparatus(
        map: draft.order.map,
        apparatus: apparatus.name,
      );
      final saved =
          await MobileApi.instance.adminSaveTrainingProductionMap(linkedMap);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = [
          for (final order in _orders)
            if (order.map.id == saved.map.id) saved else order,
        ];
      });
      showAdminTopNotice(
        context,
        '${_trainingOrderLabel(saved)} ${apparatus.name}ga ulandi',
        icon: Icons.link_rounded,
      );
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Training order ulanmagan',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _linkingOrderId = null);
      }
    }
  }

  Future<void> _openTrainingOrder() async {
    if (!_apparatus.any(
      (item) => item.trainingEnabled && isTrainingOrderApparatus(item),
    )) {
      showAdminTopNotice(
        context,
        'Avval 7 ta rangli bosma aparat uchun Training rejimini yoqing',
        icon: Icons.school_outlined,
      );
      return;
    }
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.adminCalculate,
      arguments: const AdminCalculateArgs(trainingMode: true),
    );
    if (!mounted || result != true) {
      return;
    }
    await _load();
  }

  List<ProductionMapSaved> _ordersFor(AdminApparatus apparatus) {
    return [
      for (final order in _orders)
        if (order.map.nodes.any(
          (node) =>
              node.kind == 'apparatus' &&
              productionMapWarehouseTitlesMatch(node.title, apparatus.name),
        ))
          order,
    ];
  }

  List<AdminRawMaterialAssignment> _assignmentsFor(
    AdminApparatus apparatus,
  ) {
    return [
      for (final assignment in _assignments)
        if (productionMapWarehouseTitlesMatch(
          assignment.apparatus,
          apparatus.name,
        ))
          assignment,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AdminShell(
      title: 'Training',
      selectedRouteName: AppRoutes.adminTraining,
      activeTab: AdminDockTab.home,
      primaryFabActions: [
        AdminFabMenuAction(
          title: 'Training order qo‘shish',
          icon: Icons.playlist_add_rounded,
          onTap: _openTrainingOrder,
        ),
      ],
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: _loading
            ? const Center(child: AppLoadingIndicator())
            : _error != null
                ? AppRetryState(onRetry: _load)
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      _adminTrainingPanelGap,
                      16,
                      _adminTrainingPanelGap,
                      bottomPadding,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.school_outlined),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Training apparat bo‘yicha yoqiladi. Aparatni ochib, '
                                  'rejimni almashtiring yoki 7 ta rangli aparat '
                                  'ichidan Order ulash amalini bosing.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_apparatus.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('Aparatlar topilmadi')),
                        )
                      else
                        M3SegmentSpacedColumn(
                          children: [
                            for (var index = 0;
                                index < _apparatus.length;
                                index += 1)
                              _TrainingApparatusTile(
                                apparatus: _apparatus[index],
                                assignments: _assignmentsFor(_apparatus[index]),
                                orders: _ordersFor(_apparatus[index]),
                                expanded: _expandedId == _apparatus[index].id,
                                saving: _savingId == _apparatus[index].id,
                                linking:
                                    _linkingOrderId == _apparatus[index].id,
                                onExpandedChanged: (expanded) {
                                  setState(() {
                                    _expandedId =
                                        expanded ? _apparatus[index].id : null;
                                  });
                                },
                                onTrainingChanged: (enabled) =>
                                    _setTrainingEnabled(
                                  _apparatus[index],
                                  enabled,
                                ),
                                onLinkOrder: () =>
                                    _linkOrder(_apparatus[index]),
                                slot: M3SegmentedListGeometry
                                    .standaloneListSlotForIndex(
                                  index,
                                  _apparatus.length,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _TrainingApparatusTile extends StatelessWidget {
  const _TrainingApparatusTile({
    required this.apparatus,
    required this.assignments,
    required this.orders,
    required this.expanded,
    required this.saving,
    required this.linking,
    required this.onExpandedChanged,
    required this.onTrainingChanged,
    required this.onLinkOrder,
    required this.slot,
  });

  final AdminApparatus apparatus;
  final List<AdminRawMaterialAssignment> assignments;
  final List<ProductionMapSaved> orders;
  final bool expanded;
  final bool saving;
  final bool linking;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<bool> onTrainingChanged;
  final VoidCallback onLinkOrder;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final summaryParts = <String>[
      apparatus.trainingEnabled ? 'Training rejimi' : 'Production rejimi',
      if (orders.isNotEmpty) '${orders.length} ta test order',
      if (assignments.isNotEmpty) '${assignments.length} ta test homashyo',
    ];
    final summary = summaryParts.join(' · ');
    return Material(
      key: ValueKey('admin-training-apparatus-card-${apparatus.id}'),
      color: scheme.surfaceContainerLowest,
      elevation: 4,
      shadowColor: scheme.shadow.withValues(alpha: 0.24),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 16,
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            apparatus.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey(
                        'admin-training-details-${apparatus.id}',
                      ),
                      tooltip: expanded ? 'Yopish' : 'Ochish',
                      onPressed: () => onExpandedChanged(!expanded),
                      icon: AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(58, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                apparatus.trainingEnabled
                                    ? 'Training rejimi yoqilgan'
                                    : 'Production rejimi yoqilgan',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (saving)
                              const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Switch.adaptive(
                                value: apparatus.trainingEnabled,
                                onChanged: onTrainingChanged,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (isTrainingOrderApparatus(apparatus))
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: apparatus.trainingEnabled && !linking
                                  ? onLinkOrder
                                  : null,
                              icon: linking
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.link_rounded),
                              label: const Text('Order ulash'),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Training order faqat 7 ta rangli bosma aparatga ulanadi',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (orders.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final order in orders)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.receipt_long_outlined,
                                size: 20,
                              ),
                              title: Text(
                                _trainingOrderLabel(order),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                order.map.productCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        if (assignments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final assignment in assignments)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 20,
                              ),
                              title: Text(
                                assignment.itemName.isEmpty
                                    ? assignment.barcode
                                    : assignment.itemName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${assignment.barcode} · ${_trainingOrderShortLabel(assignment.orderId)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TrainingOrderLinkDraft {
  const _TrainingOrderLinkDraft({required this.order});

  final ProductionMapSaved order;
}

class _TrainingOrderLinkSheet extends StatefulWidget {
  const _TrainingOrderLinkSheet({
    required this.apparatus,
    required this.orders,
  });

  final AdminApparatus apparatus;
  final List<ProductionMapSaved> orders;

  @override
  State<_TrainingOrderLinkSheet> createState() =>
      _TrainingOrderLinkSheetState();
}

class _TrainingOrderLinkSheetState extends State<_TrainingOrderLinkSheet> {
  ProductionMapSaved? _order;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _order = widget.orders.length == 1 ? widget.orders.first : null;
  }

  void _submit() {
    if (_order == null) {
      setState(() {
        _validationMessage = 'Ulash uchun orderni tanlang';
      });
      return;
    }
    Navigator.of(context).pop(
      _TrainingOrderLinkDraft(order: _order!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Training orderini ulash',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('Aparat: ${widget.apparatus.name}'),
              const SizedBox(height: 18),
              if (widget.orders.isEmpty)
                const _TrainingSheetNotice(
                  icon: Icons.receipt_long_outlined,
                  text:
                      'Avval FAB orqali training order oching. U order bu yerda tanlanmagan holatda ko‘rinadi.',
                )
              else
                DropdownButtonFormField<ProductionMapSaved>(
                  initialValue: _order,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Order',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                  items: [
                    for (final order in widget.orders)
                      DropdownMenuItem<ProductionMapSaved>(
                        value: order,
                        child: Text(
                          _trainingOrderLabel(order),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _order = value),
                ),
              const SizedBox(height: 12),
              const _TrainingSheetNotice(
                icon: Icons.link_rounded,
                text: 'Tanlangan order shu 7 rangli aparatning navbatiga '
                    'ulanadi. Keyin uning test homashyosi shu orderga qo‘shiladi.',
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _validationMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.orders.isNotEmpty ? _submit : null,
                icon: const Icon(Icons.link_rounded),
                label: const Text('Order ulash'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingSheetNotice extends StatelessWidget {
  const _TrainingSheetNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

String _trainingOrderLabel(ProductionMapSaved saved) {
  final map = saved.map;
  final values = [map.title, map.orderNumber, map.customerName]
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? map.id : values.join(' · ');
}

String _trainingOrderShortLabel(String orderId) {
  final normalized = orderId.trim();
  if (normalized.length <= 22) {
    return normalized;
  }
  return '${normalized.substring(0, 10)}…${normalized.substring(normalized.length - 8)}';
}
