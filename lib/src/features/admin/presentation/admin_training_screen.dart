import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../admin/logic/production_map_pechat_rules.dart';
import '../../admin/models/production_map_models.dart';
import '../../shared/models/app_models.dart';
import 'admin_calculate_screen.dart';
import 'admin_training_order_helpers.dart';
import 'progress_printer_picker.dart';
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
  List<CalculateMaterial> _materials = const [];
  List<ProductionMapSaved> _orders = const [];
  List<AdminRawMaterialAssignment> _assignments = const [];
  bool _loading = true;
  String? _error;
  String? _savingId;
  String? _linkingOrderId;
  String? _linkingMaterialOrderId;
  String? _deletingOrderId;
  String? _expandedId;
  bool _restarting = false;

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
        MobileApi.instance.calculateMaterials(),
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
        _materials = [
          ...(results[3] as List<CalculateMaterial>)
              .where((material) => material.active),
        ]..sort(
            (left, right) => left.name.toLowerCase().compareTo(
                  right.name.toLowerCase(),
                ),
          );
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

  Future<void> _restartTraining() async {
    if (_restarting) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: 'Trainingni qayta boshlash',
      message:
          'Barcha training orderlar 0-holatga qaytariladi. Orderlar va ulangan '
          'homashyolar saqlanadi. Production ma’lumotlari o‘zgarmaydi.',
      cancelLabel: 'Bekor qilish',
      confirmLabel: 'Qayta boshlash',
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _restarting = true);
    try {
      await MobileApi.instance.adminRestartTraining();
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        'Training qayta boshlandi: barcha natijalar 0 ga qaytarildi',
        icon: Icons.restart_alt_rounded,
      );
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Training qayta boshlanmadi',
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _restarting = false);
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

  void _showTrainingOrderDetails(ProductionMapSaved order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _TrainingOrderDetailsSheet(
        order: order,
        assignments: [
          for (final assignment in _assignments)
            if (assignment.orderId.trim() == order.map.id.trim()) assignment,
        ],
        onLinkMaterial: () => _linkTrainingMaterial(order),
      ),
    );
  }

  Future<AdminRawMaterialAssignment?> _linkTrainingMaterial(
    ProductionMapSaved order,
  ) async {
    final orderId = order.map.id.trim();
    if (_linkingMaterialOrderId != null) {
      return null;
    }
    final apparatus = order.map.nodes
        .where((node) => node.kind == 'apparatus')
        .map((node) => node.title.trim())
        .firstWhere((title) => title.isNotEmpty, orElse: () => '');
    if (orderId.isEmpty || apparatus.isEmpty) {
      showAdminTopNotice(context, 'Training order apparati topilmadi');
      return null;
    }
    if (_materials.isEmpty) {
      showAdminTopNotice(
        context,
        'Xomashyo mikronlari sahifasida faol homashyo yo‘q',
        icon: Icons.inventory_2_outlined,
      );
      return null;
    }
    setState(() => _linkingMaterialOrderId = orderId);
    try {
      final draft = await showModalBottomSheet<_TrainingMaterialLinkDraft>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _TrainingMaterialLinkSheet(
          apparatus: apparatus,
          materials: _materials,
        ),
      );
      if (draft == null || !mounted) {
        return null;
      }
      final printer = await pickProgressPrinter(context);
      if (!mounted || printer == null) {
        if (mounted) {
          showAdminTopNotice(context, 'Printer tanlanmadi');
        }
        return null;
      }
      final barcode = _nextTrainingBarcode();
      final itemCode = draft.material.id.trim().isEmpty
          ? 'TRAINING-MATERIAL'
          : draft.material.id.trim();
      final itemName = '${draft.material.name.trim()} / ${draft.micron} mikron';
      final printRequest = UsbRpsPrintRequest(
        epc: barcode,
        itemCode: itemCode,
        itemName: itemName,
        apparatus: apparatus,
        warehouse: 'Training: $apparatus',
        printer: printer.printer.trim().isEmpty ? 'godex' : printer.printer,
        printMode:
            printer.printMode.trim().isEmpty ? 'label' : printer.printMode,
        grossQty: 1,
        unit: 'kg',
        labelKind: 'material_product',
      );
      await _printTrainingLabel(printer, printRequest);
      final assignment = await MobileApi.instance.adminLinkTrainingRawMaterial(
        orderId: orderId,
        apparatus: apparatus,
        materialId: draft.material.id,
        materialName: draft.material.name,
        micron: draft.micron,
        barcode: barcode,
      );
      if (!mounted) {
        return assignment;
      }
      setState(() {
        _assignments = [
          assignment,
          for (final item in _assignments)
            if (item.orderId.trim() != assignment.orderId.trim() ||
                item.barcode.trim().toUpperCase() !=
                    assignment.barcode.trim().toUpperCase())
              item,
        ];
      });
      showAdminTopNotice(
        context,
        'QR chop etildi va homashyo training orderga ulandi',
        icon: Icons.link_rounded,
      );
      return assignment;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Training homashyosi ulanmagan yoki chop etilmadi',
          icon: Icons.error_outline,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _linkingMaterialOrderId = null);
      }
    }
  }

  Future<void> _printTrainingLabel(
    ProgressPrinterOption printer,
    UsbRpsPrintRequest request,
  ) async {
    if (printer.transport.isLocal) {
      final result = await PrintService.printRps(
        request,
        printerProfile: printer.offlinePrinter,
        bluetoothPrinter: printer.bluetoothPrinter,
        transport: printer.transport,
      );
      if (!result.ok) {
        throw StateError('Printer training QR kodini chop etmadi');
      }
      return;
    }
    final server = printer.server;
    if (server == null) {
      throw StateError('Printer serveri topilmadi');
    }
    final response = await http
        .post(
          Uri.parse('${server.endpoint.baseUrl}/v1/mobile/driver/print'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    final payload = jsonDecode(response.body);
    final ok = payload is Map && payload['ok'] == true;
    if (response.statusCode < 200 || response.statusCode > 299 || !ok) {
      final detail = payload is Map
          ? (payload['detail'] ?? payload['error'])?.toString().trim() ?? ''
          : '';
      throw StateError(
        detail.isEmpty ? 'Printer training QR kodini chop etmadi' : detail,
      );
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
      actions: [
        IconButton(
          tooltip: 'Trainingni qayta boshlash',
          onPressed: _restarting ? null : _restartTraining,
          icon: _restarting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.restart_alt_rounded),
        ),
      ],
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
                                onOrderTap: _showTrainingOrderDetails,
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
    required this.onOrderTap,
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
  final ValueChanged<ProductionMapSaved> onOrderTap;
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
                              onTap: () => onOrderTap(order),
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

class _TrainingOrderDetailsSheet extends StatefulWidget {
  const _TrainingOrderDetailsSheet({
    required this.order,
    required this.assignments,
    required this.onLinkMaterial,
  });

  final ProductionMapSaved order;
  final List<AdminRawMaterialAssignment> assignments;
  final Future<AdminRawMaterialAssignment?> Function() onLinkMaterial;

  @override
  State<_TrainingOrderDetailsSheet> createState() =>
      _TrainingOrderDetailsSheetState();
}

class _TrainingOrderDetailsSheetState
    extends State<_TrainingOrderDetailsSheet> {
  late List<AdminRawMaterialAssignment> _assignments;
  bool _linking = false;

  @override
  void initState() {
    super.initState();
    _assignments = [...widget.assignments];
  }

  Future<void> _linkMaterial() async {
    if (_linking) {
      return;
    }
    setState(() => _linking = true);
    try {
      final assignment = await widget.onLinkMaterial();
      if (!mounted || assignment == null) {
        return;
      }
      setState(() {
        _assignments = [
          assignment,
          for (final item in _assignments)
            if (item.barcode.trim().toUpperCase() !=
                assignment.barcode.trim().toUpperCase())
              item,
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _linking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = widget.order.map;
    final apparatus = map.nodes
        .where(
            (node) => node.kind == 'apparatus' && node.title.trim().isNotEmpty)
        .map((node) => node.title.trim())
        .join(', ');
    final stages = map.nodes
        .where((node) => node.kind == 'task' && node.title.trim().isNotEmpty)
        .toList(growable: false);
    final headerTitle = map.title.trim().isEmpty
        ? _trainingOrderLabel(widget.order)
        : map.title.trim();

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Training order ma’lumotlari',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _TrainingOrderDetailsSection(
                title: 'Buyurtma ma’lumotlari',
                icon: Icons.info_outline_rounded,
                children: [
                  if (map.orderNumber.trim().isNotEmpty)
                    AppInfoRow(
                      label: 'Buyurtma raqami',
                      value: map.orderNumber,
                      selectable: true,
                    ),
                  AppInfoRow(label: 'Mahsulot', value: map.title),
                  if (map.productCode.trim().isNotEmpty)
                    AppInfoRow(
                      label: 'Mahsulot kodi',
                      value: map.productCode,
                      selectable: true,
                    ),
                  if (map.code.trim().isNotEmpty)
                    AppInfoRow(label: 'Kod', value: map.code),
                  if (map.customerName.trim().isNotEmpty)
                    AppInfoRow(label: 'Mijoz', value: map.customerName),
                  if (map.rollCount != null && map.rollCount! > 0)
                    AppInfoRow(
                      label: 'Rulon soni',
                      value: '${formatRawQuantity(map.rollCount!)} ta',
                    ),
                  if (map.widthMm != null && map.widthMm! > 0)
                    AppInfoRow(
                      label: 'Eni',
                      value: '${formatRawQuantity(map.widthMm!)} mm',
                    ),
                  if (map.orderKg != null && map.orderKg! > 0)
                    AppInfoRow(
                      label: 'Rejadagi og‘irlik',
                      value: '${formatRawQuantity(map.orderKg!)} kg',
                    ),
                  if (map.baseLength != null && map.baseLength! > 0)
                    AppInfoRow(
                      label: 'Rejadagi uzunlik',
                      value: '${formatRawQuantity(map.baseLength!)} metr',
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _linking ? null : _linkMaterial,
                icon: _linking
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: Text(
                  _linking ? 'Ulanmoqda…' : 'Homashyo ulash va QR chiqarish',
                ),
              ),
              if (_assignments.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TrainingOrderDetailsSection(
                  title: 'Ulangan test homashyolar',
                  icon: Icons.inventory_2_outlined,
                  children: [
                    for (final assignment in _assignments)
                      AppInfoRow(
                        label: assignment.itemName.trim().isEmpty
                            ? 'Homashyo'
                            : assignment.itemName,
                        value: assignment.barcode,
                        selectable: true,
                      ),
                  ],
                ),
              ],
              if (apparatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TrainingOrderDetailsSection(
                  title: 'Ulangan aparat',
                  icon: Icons.precision_manufacturing_outlined,
                  children: [AppInfoRow(label: 'Apparat', value: apparatus)],
                ),
              ],
              if (stages.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TrainingOrderDetailsSection(
                  title: 'Production map bosqichlari',
                  icon: Icons.account_tree_outlined,
                  children: [
                    for (var index = 0; index < stages.length; index++)
                      AppInfoRow(
                        label: '${index + 1}-bosqich',
                        value: stages[index].title,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainingMaterialLinkDraft {
  const _TrainingMaterialLinkDraft({
    required this.material,
    required this.micron,
  });

  final CalculateMaterial material;
  final int micron;
}

class _TrainingMaterialLinkSheet extends StatefulWidget {
  const _TrainingMaterialLinkSheet({
    required this.apparatus,
    required this.materials,
  });

  final String apparatus;
  final List<CalculateMaterial> materials;

  @override
  State<_TrainingMaterialLinkSheet> createState() =>
      _TrainingMaterialLinkSheetState();
}

class _TrainingMaterialLinkSheetState
    extends State<_TrainingMaterialLinkSheet> {
  late final TextEditingController _micronController;
  CalculateMaterial? _material;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _micronController = TextEditingController();
    _material = widget.materials.isEmpty ? null : widget.materials.first;
  }

  @override
  void dispose() {
    _micronController.dispose();
    super.dispose();
  }

  void _submit() {
    final micron = int.tryParse(_micronController.text.trim());
    if (_material == null || micron == null || micron <= 0) {
      setState(() {
        _validationMessage = 'Homashyo va musbat micronni kiriting';
      });
      return;
    }
    Navigator.of(context).pop(
      _TrainingMaterialLinkDraft(material: _material!, micron: micron),
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
                'Training homashyosini ulash',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('Aparat: ${widget.apparatus}'),
              const SizedBox(height: 18),
              DropdownButtonFormField<CalculateMaterial>(
                initialValue: _material,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Homashyo nomi',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: [
                  for (final material in widget.materials)
                    DropdownMenuItem<CalculateMaterial>(
                      value: material,
                      child: Text(
                        material.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _material = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _micronController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Mikron',
                  hintText: 'Masalan, 50',
                  prefixIcon: Icon(Icons.straighten_outlined),
                  suffixText: 'µm',
                ),
              ),
              const SizedBox(height: 12),
              const _TrainingSheetNotice(
                icon: Icons.print_outlined,
                text: 'Printer tanlangandan keyin shu homashyo uchun qayta '
                    'ishlatiladigan QR chiqariladi va orderga biriktiriladi.',
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
                onPressed: widget.materials.isEmpty ? null : _submit,
                icon: const Icon(Icons.print_rounded),
                label: const Text('Mikronni yozib davom etish'),
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

class _TrainingOrderDetailsSection extends StatelessWidget {
  const _TrainingOrderDetailsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
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

int _trainingBarcodeSequence = 0;

String _nextTrainingBarcode() {
  _trainingBarcodeSequence += 1;
  return 'TRN-${DateTime.now().toUtc().millisecondsSinceEpoch}-$_trainingBarcodeSequence';
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
