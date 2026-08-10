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
  String? _deletingOrderId;
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

  Future<void> _openOrderForApparatus(AdminApparatus apparatus) async {
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
    setState(() => _linkingOrderId = apparatus.id);
    try {
      final result = await Navigator.of(context).pushNamed(
        AppRoutes.adminCalculate,
        arguments: AdminCalculateArgs(
          trainingMode: true,
          trainingApparatus: apparatus.name,
        ),
      );
      if (!mounted || result != true) {
        return;
      }
      await _load();
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Training order sahifasi ochilmadi',
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
    final available = _apparatus
        .where(
          (item) => item.trainingEnabled && isTrainingOrderApparatus(item),
        )
        .toList(growable: false);
    if (available.isEmpty) {
      showAdminTopNotice(
        context,
        'Avval 7 ta rangli bosma aparat uchun Training rejimini yoqing',
        icon: Icons.school_outlined,
      );
      return;
    }
    final apparatus = available.length == 1
        ? available.single
        : await showModalBottomSheet<AdminApparatus>(
            context: context,
            showDragHandle: true,
            useSafeArea: true,
            builder: (context) => _TrainingApparatusPicker(
              apparatus: available,
            ),
          );
    if (!mounted || apparatus == null) {
      return;
    }
    await _openOrderForApparatus(apparatus);
  }

  Future<void> _deleteTrainingOrder(ProductionMapSaved order) async {
    if (_deletingOrderId != null) {
      return;
    }
    final orderId = order.map.id.trim();
    if (orderId.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          title: const Text('Training orderni o‘chirish'),
          content: Text(
            '“${_trainingOrderLabel(order)}” va unga ulangan test homashyolar '
            'o‘chiriladi. Davom etilsinmi?',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          actions: [
            SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('O‘chirish'),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Bekor qilish'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _deletingOrderId = orderId);
    try {
      await MobileApi.instance.adminDeleteTrainingProductionMap(orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = [
          for (final item in _orders)
            if (item.map.id.trim() != orderId) item,
        ];
        _assignments = [
          for (final item in _assignments)
            if (item.orderId.trim() != orderId) item,
        ];
      });
      showAdminTopNotice(
        context,
        'Training order o‘chirildi',
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Training order o‘chirilmadi',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deletingOrderId = null);
      }
    }
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
                                deletingOrderId: _deletingOrderId,
                                onDeleteOrder: _deleteTrainingOrder,
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
                                    _openOrderForApparatus(_apparatus[index]),
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
    required this.deletingOrderId,
    required this.onExpandedChanged,
    required this.onTrainingChanged,
    required this.onLinkOrder,
    required this.onDeleteOrder,
    required this.slot,
  });

  final AdminApparatus apparatus;
  final List<AdminRawMaterialAssignment> assignments;
  final List<ProductionMapSaved> orders;
  final bool expanded;
  final bool saving;
  final bool linking;
  final String? deletingOrderId;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<bool> onTrainingChanged;
  final VoidCallback onLinkOrder;
  final ValueChanged<ProductionMapSaved> onDeleteOrder;
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
                              trailing: deletingOrderId == order.map.id.trim()
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: 'Training orderni o‘chirish',
                                      onPressed: () => onDeleteOrder(order),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
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

class _TrainingApparatusPicker extends StatelessWidget {
  const _TrainingApparatusPicker({required this.apparatus});

  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Training apparatini tanlang',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in apparatus)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.precision_manufacturing_outlined),
              title: Text(item.name),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).pop(item),
            ),
        ],
      ),
    );
  }
}
