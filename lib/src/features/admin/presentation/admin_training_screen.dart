import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../admin/logic/production_map_chain.dart';
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
  List<AdminProgressBatch> _inputBatches = const [];
  bool _loading = true;
  String? _error;
  String? _savingId;
  String? _linkingOrderId;
  String? _linkingMaterialOrderId;
  String? _deletingOrderId;
  String? _deletingMaterialKey;
  String? _generatingInputBatchOrderId;
  String? _expandedId;
  String? _restartingId;
  Map<String, AdminTrainingOrderStatus> _statuses = const {};
  List<String> _loadWarnings = const [];
  Timer? _statusRefreshTimer;
  bool _statusRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_refreshTrainingStatuses()),
    );
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final hadExistingData = _hasTrainingData;
    if (mounted) {
      setState(() {
        _loading = !hadExistingData;
        _error = null;
      });
    }
    final results = await Future.wait<_AdminTrainingLoadPart>([
      _loadTrainingPart(
        'apparatus',
        () => MobileApi.instance.adminTrainingApparatus(),
      ),
      _loadTrainingPart(
        'orders',
        () => MobileApi.instance.adminTrainingProductionMaps(),
      ),
      _loadTrainingPart(
        'materials',
        () => MobileApi.instance.adminTrainingRawMaterialAssignments(),
      ),
      _loadTrainingPart(
        'calculate materials',
        () => MobileApi.instance.calculateMaterials(),
      ),
      _loadTrainingPart(
        'input batches',
        () => MobileApi.instance.adminTrainingInputBatches(),
      ),
    ]);
    final statuses = await _loadTrainingStatuses();
    if (!mounted) {
      return;
    }
    final apparatusResult = results[0].value;
    final ordersResult = results[1].value;
    final assignmentsResult = results[2].value;
    final materialsResult = results[3].value;
    final inputBatchesResult = results[4].value;
    final failedSections = [
      for (final result in results)
        if (result.error != null) result.name,
      if (statuses == null) 'statuses',
    ];
    final allDataRequestsFailed = results.every(
      (result) => result.error != null,
    );
    setState(() {
      if (apparatusResult is List<AdminApparatus>) {
        _apparatus = [...apparatusResult]..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
      }
      if (ordersResult is List<ProductionMapSaved>) {
        _orders = ordersResult
            .where((order) => order.map.id.trim().startsWith('training-'))
            .toList()
          ..sort(
            (left, right) => _trainingOrderLabel(left)
                .toLowerCase()
                .compareTo(_trainingOrderLabel(right).toLowerCase()),
          );
      }
      if (assignmentsResult is List<AdminRawMaterialAssignment>) {
        _assignments = [...assignmentsResult];
      }
      if (materialsResult is List<CalculateMaterial>) {
        _materials = [...materialsResult.where((material) => material.active)]
          ..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
      }
      if (inputBatchesResult is List<AdminProgressBatch>) {
        _inputBatches = [...inputBatchesResult];
      }
      if (statuses != null) {
        _statuses = statuses;
      }
      _loadWarnings = failedSections;
      _loading = false;
      _error = allDataRequestsFailed && !hadExistingData
          ? context.l10n.adminText('training.load_failed')
          : null;
    });
  }

  bool get _hasTrainingData =>
      _apparatus.isNotEmpty ||
      _materials.isNotEmpty ||
      _orders.isNotEmpty ||
      _assignments.isNotEmpty ||
      _inputBatches.isNotEmpty;

  Future<_AdminTrainingLoadPart> _loadTrainingPart<T>(
    String name,
    Future<T> Function() loader,
  ) async {
    try {
      return _AdminTrainingLoadPart(name: name, value: await loader());
    } catch (error, stackTrace) {
      debugPrint('Admin training $name load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _AdminTrainingLoadPart(name: name, error: error);
    }
  }

  Future<Map<String, AdminTrainingOrderStatus>?> _loadTrainingStatuses() async {
    try {
      return await MobileApi.instance.adminTrainingOrderStatuses();
    } catch (error, stackTrace) {
      debugPrint('Admin training statuses load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _refreshTrainingStatuses() async {
    if (!mounted || _statusRefreshInFlight) {
      return;
    }
    _statusRefreshInFlight = true;
    try {
      final statuses = await _loadTrainingStatuses();
      if (mounted) {
        final nextStatuses = statuses;
        if (nextStatuses != null &&
            !_trainingStatusesEqual(_statuses, nextStatuses)) {
          setState(() => _statuses = nextStatuses);
        }
      }
    } finally {
      _statusRefreshInFlight = false;
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
        apparatus: apparatus,
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
        enabled
            ? context.l10n.adminText('training.enabled')
            : context.l10n.adminText('training.disabled'),
      );
    } catch (_) {
      if (mounted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('training.save_failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingId = null);
      }
    }
  }

  Future<void> _restartTraining(AdminApparatus apparatus) async {
    if (_restartingId != null) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: context.l10n.adminText(
        'training.restart_title',
        values: {'apparatus': apparatus.name},
      ),
      message: context.l10n.adminText('training.restart_message'),
      cancelLabel: context.l10n.adminText('action.cancel'),
      confirmLabel: context.l10n.adminText('training.restart_confirm'),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() => _restartingId = apparatus.id);
    try {
      await MobileApi.instance.adminRestartTraining(apparatus: apparatus.id);
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        context.l10n.adminText(
          'training.restarted',
          values: {'apparatus': apparatus.name},
        ),
        icon: Icons.restart_alt_rounded,
      );
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('training.restart_failed'),
          icon: Icons.error_outline,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _restartingId = null);
      }
    }
  }

  Future<void> _openOrderForApparatus(AdminApparatus apparatus) async {
    if (_linkingOrderId != null) {
      return;
    }
    if (!apparatus.trainingEnabled) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('training.enable_first'),
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
          trainingApparatusId: apparatus.id,
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
              : context.l10n.adminText('training.order_page_failed'),
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
        .where((item) => item.trainingEnabled)
        .toList(growable: false);
    if (available.isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('training.enable_one'),
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
            builder: (context) =>
                _TrainingApparatusPicker(apparatus: available),
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
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          title: Text(l10n.adminText('training.order_delete_title')),
          content: Text(
            l10n.adminText(
              'training.order_delete_message',
              values: {'order': _trainingOrderLabel(order)},
            ),
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
                    child: Text(l10n.adminText('action.delete')),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(l10n.adminText('action.cancel')),
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
        _inputBatches = [
          for (final item in _inputBatches)
            if (item.orderId.trim() != orderId) item,
        ];
      });
      showAdminTopNotice(
        context,
        l10n.adminText('training.order_deleted'),
        icon: Icons.check_circle_outline,
      );
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : l10n.adminText('training.order_delete_failed'),
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
        apparatusCatalog: _apparatus,
        assignments: [
          for (final assignment in _assignments)
            if (assignment.orderId.trim() == order.map.id.trim()) assignment,
        ],
        inputBatches: _inputBatchesFor(order),
        onLinkMaterial: () => _linkTrainingMaterial(order),
        onDeleteMaterial: _deleteTrainingMaterial,
        onPrintMaterialAndQolip: (assignments) =>
            _printTrainingMaterialAndQolip(order, assignments),
        onGenerateInputBatch: () => _generateTrainingInputBatch(order),
        onBatchTap: _showTrainingInputBatchDetails,
      ),
    );
  }

  Future<AdminProgressBatch?> _generateTrainingInputBatch(
    ProductionMapSaved order,
  ) async {
    final orderId = order.map.id.trim();
    if (_generatingInputBatchOrderId != null || orderId.isEmpty) {
      return null;
    }
    final l10n = context.l10n;
    setState(() => _generatingInputBatchOrderId = orderId);
    try {
      final batch = await MobileApi.instance.adminGenerateTrainingInputBatch(
        orderId: orderId,
      );
      if (!mounted) {
        return batch;
      }
      setState(() {
        _inputBatches = [
          for (final item in _inputBatches)
            if (item.batchId.trim() != batch.batchId.trim()) item,
          batch,
        ];
      });
      showAdminTopNotice(
        context,
        l10n.adminText('training.batch_created'),
        icon: Icons.qr_code_2_rounded,
      );
      return batch;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : l10n.adminText('training.batch_create_failed'),
          icon: Icons.error_outline,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _generatingInputBatchOrderId = null);
      }
    }
  }

  List<AdminProgressBatch> _inputBatchesFor(ProductionMapSaved order) {
    final orderId = order.map.id.trim();
    return [
      for (final batch in _inputBatches)
        if (batch.orderId.trim() == orderId) batch,
    ];
  }

  void _showTrainingInputBatchDetails(AdminProgressBatch batch) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => RpsQrReprintSheet(
        title: l10n.adminText('training.batch_qr_title'),
        payload: batch.qrPayload,
        itemName: batch.labelItemName,
        previewKey: ValueKey('training-input-batch-qr-${batch.batchId}'),
        reprintButtonKey: ValueKey(
          'training-input-batch-qr-reprint-${batch.batchId}',
        ),
        details: [
          RpsQrDetail(l10n.adminText('training.batch_id'), batch.batchId),
          RpsQrDetail(l10n.adminText('training.order_label'), batch.orderId),
          RpsQrDetail(
            l10n.adminText('training.stage'),
            _trainingApparatusDisplayName(batch.apparatus, _apparatus),
          ),
          RpsQrDetail(
            l10n.adminText('training.next_apparatus'),
            _trainingApparatusDisplayName(batch.nextApparatus, _apparatus),
          ),
          RpsQrDetail(
            l10n.adminText('training.quantity'),
            '${formatRawQuantity(batch.producedQty)} ${batch.uom}',
          ),
          RpsQrDetail(
            l10n.adminText('training.status'),
            l10n.adminText('training.batch_status'),
          ),
        ],
        onReprint: () => _reprintTrainingInputBatch(batch),
        onDelete: () => _deleteTrainingInputBatch(batch),
        deleteButtonKey: ValueKey(
          'training-input-batch-qr-delete-${batch.batchId}',
        ),
        errorMessage: (error) => error is MobileApiException
            ? error.message
            : error.toString().replaceFirst('Bad state: ', ''),
      ),
    );
  }

  Future<void> _deleteTrainingInputBatch(AdminProgressBatch batch) async {
    await MobileApi.instance.adminDeleteTrainingInputBatch(
      orderId: batch.orderId,
      apparatus: batch.nextApparatus,
      qrPayload: batch.qrPayload,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _inputBatches = [
        for (final item in _inputBatches)
          if (item.batchId.trim() != batch.batchId.trim()) item,
      ];
    });
    showAdminTopNotice(
      context,
      context.l10n.adminText('training.batch_deleted'),
      icon: Icons.delete_outline_rounded,
    );
  }

  Future<String?> _reprintTrainingInputBatch(AdminProgressBatch batch) async {
    final qrPayload = batch.qrPayload.trim();
    if (qrPayload.isEmpty) {
      throw StateError(context.l10n.adminText('training.batch_code_missing'));
    }
    final printer = await pickProgressPrinter(context);
    if (!mounted) {
      return null;
    }
    if (printer == null) {
      throw StateError(context.l10n.adminText('training.printer_missing'));
    }
    final printRequest = UsbRpsPrintRequest(
      epc: qrPayload,
      itemCode: batch.labelItemCode.trim().isEmpty
          ? 'TRAINING-BATCH'
          : batch.labelItemCode.trim(),
      itemName: batch.labelItemName.trim().isEmpty
          ? 'Training batch'
          : batch.labelItemName.trim(),
      apparatus: batch.apparatus.trim(),
      warehouse: 'Training',
      printer: printer.printer.trim().isEmpty ? 'godex' : printer.printer,
      printMode: printer.printMode.trim().isEmpty ? 'label' : printer.printMode,
      grossQty: batch.producedQty > 0 ? batch.producedQty : 1,
      unit: batch.uom.trim().isEmpty ? 'kg' : batch.uom.trim(),
      labelKind: 'progress',
      executorName: batch.executorName,
      progressQty: batch.producedQty,
      progressUnit: batch.uom.trim().isEmpty ? 'kg' : batch.uom.trim(),
    );
    await _printTrainingLabel(printer, printRequest);
    return null;
  }

  Future<bool> _deleteTrainingMaterial(
    AdminRawMaterialAssignment assignment,
  ) async {
    final materialKey = _trainingMaterialKey(assignment);
    if (_deletingMaterialKey != null) {
      return false;
    }
    final itemName = assignment.itemName.trim().isEmpty
        ? assignment.barcode.trim()
        : assignment.itemName.trim();
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title: context.l10n.adminText('training.material_delete_title'),
      message: context.l10n.adminText(
        'training.material_delete_message',
        values: {'item': itemName},
      ),
      cancelLabel: context.l10n.adminText('action.cancel'),
      confirmLabel: context.l10n.adminText('action.delete'),
    );
    if (!mounted || confirmed != true) {
      return false;
    }
    setState(() => _deletingMaterialKey = materialKey);
    try {
      await MobileApi.instance.adminDeleteTrainingRawMaterial(
        orderId: assignment.orderId,
        apparatus: assignment.apparatus,
        barcode: assignment.barcode,
      );
      if (!mounted) {
        return true;
      }
      setState(() {
        _assignments = [
          for (final item in _assignments)
            if (_trainingMaterialKey(item) != materialKey) item,
        ];
      });
      showAdminTopNotice(
        context,
        context.l10n.adminText('training.material_deleted'),
        icon: Icons.link_off_rounded,
      );
      return true;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('training.material_delete_failed'),
          icon: Icons.error_outline,
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _deletingMaterialKey = null);
      }
    }
  }

  void _showTrainingMaterialDetails(AdminRawMaterialAssignment assignment) {
    final itemName = assignment.itemName.trim().isEmpty
        ? context.l10n.adminText('training.material_fallback')
        : assignment.itemName.trim();
    final quantity = assignment.stockQty > 0
        ? '${formatRawQuantity(assignment.stockQty)} ${assignment.stockUom}'
            .trim()
        : '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => RpsQrReprintSheet(
        title: this.context.l10n.adminText('training.material_qr_title'),
        payload: assignment.barcode,
        itemName: itemName,
        previewKey: ValueKey('training-material-qr-${assignment.barcode}'),
        reprintButtonKey: ValueKey(
          'training-material-qr-reprint-${assignment.barcode}',
        ),
        details: [
          RpsQrDetail(
            this.context.l10n.adminText('label.item_code'),
            assignment.itemCode,
          ),
          RpsQrDetail(
            this.context.l10n.adminText('label.group'),
            assignment.itemGroup,
          ),
          RpsQrDetail(this.context.l10n.adminText('label.quantity'), quantity),
          RpsQrDetail(
            this.context.l10n.adminText('label.warehouse'),
            assignment.stockWarehouse,
          ),
          RpsQrDetail(
            this.context.l10n.adminText('label.apparatus'),
            _trainingApparatusDisplayName(
              assignment.apparatus,
              _apparatus,
            ),
          ),
          RpsQrDetail(
            this.context.l10n.adminText('label.status'),
            _trainingRawMaterialStatusLabel(
              this.context.l10n,
              assignment.stockStatus,
            ),
          ),
          if (assignment.orderId.trim().isNotEmpty)
            RpsQrDetail(
              this.context.l10n.adminText('training.order_label'),
              assignment.orderId,
            ),
          if (assignment.assignedByName.trim().isNotEmpty)
            RpsQrDetail(
              this.context.l10n.adminText('training.assigned_by'),
              assignment.assignedByName,
            ),
          if (assignment.assignedAt.trim().isNotEmpty)
            RpsQrDetail(
              this.context.l10n.adminText('training.assigned_at'),
              assignment.assignedAt,
            ),
        ],
        onReprint: () => _reprintTrainingMaterial(assignment),
        errorMessage: (error) => error is MobileApiException
            ? error.message
            : error.toString().replaceFirst('Bad state: ', ''),
      ),
    );
  }

  Future<String?> _reprintTrainingMaterial(
    AdminRawMaterialAssignment assignment,
  ) async {
    final barcode = assignment.barcode.trim();
    if (barcode.isEmpty) {
      throw StateError(context.l10n.adminText('training.material_qr_missing'));
    }
    final printer = await pickProgressPrinter(context);
    if (!mounted) {
      return null;
    }
    if (printer == null) {
      throw StateError(context.l10n.adminText('training.printer_missing'));
    }
    final printRequest = _trainingMaterialPrintRequest(assignment, printer);
    await _printTrainingLabel(printer, printRequest);
    return null;
  }

  UsbRpsPrintRequest _trainingMaterialPrintRequest(
    AdminRawMaterialAssignment assignment,
    ProgressPrinterOption printer,
  ) {
    return UsbRpsPrintRequest(
      epc: assignment.barcode.trim(),
      itemCode: assignment.itemCode.trim().isEmpty
          ? 'TRAINING-MATERIAL'
          : assignment.itemCode.trim(),
      itemName: assignment.itemName.trim().isEmpty
          ? context.l10n.adminText('training.material_fallback')
          : assignment.itemName.trim(),
      apparatus: assignment.apparatus.trim(),
      warehouse: assignment.stockWarehouse.trim().isEmpty
          ? 'Training'
          : assignment.stockWarehouse.trim(),
      printer: printer.printer.trim().isEmpty ? 'godex' : printer.printer,
      printMode: printer.printMode.trim().isEmpty ? 'label' : printer.printMode,
      grossQty: assignment.stockQty > 0 ? assignment.stockQty : 1,
      unit: assignment.stockUom.trim().isEmpty ? 'kg' : assignment.stockUom,
      labelKind: 'material_product',
    );
  }

  Future<AdminRawMaterialAssignment?> _linkTrainingMaterial(
    ProductionMapSaved order,
  ) async {
    final orderId = order.map.id.trim();
    if (_linkingMaterialOrderId != null) {
      return null;
    }
    final apparatusId = order.map.nodes
        .where((node) => node.kind == 'apparatus')
        .map((node) => node.apparatusId.trim())
        .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    if (orderId.isEmpty || apparatusId.isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('training.order_apparatus_missing'),
      );
      return null;
    }
    final apparatusName = _trainingApparatusDisplayName(
      apparatusId,
      _apparatus,
    );
    if (_materials.isEmpty) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('training.no_active_material'),
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
          apparatus: apparatusName,
          materials: _materials,
        ),
      );
      if (draft == null || !mounted) {
        return null;
      }
      final printer = await pickProgressPrinter(context);
      if (!mounted || printer == null) {
        if (mounted) {
          showAdminTopNotice(
            context,
            context.l10n.adminText('training.printer_missing'),
          );
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
        apparatus: apparatusName,
        warehouse: 'Training: $apparatusName',
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
        apparatus: apparatusId,
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
        context.l10n.adminText('training.material_linked'),
        icon: Icons.link_rounded,
      );
      return assignment;
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('training.material_link_failed'),
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
    final l10n = context.l10n;
    if (printer.transport.isLocal) {
      final result = await PrintService.printRps(
        request,
        printerProfile: printer.offlinePrinter,
        bluetoothPrinter: printer.bluetoothPrinter,
        transport: printer.transport,
      );
      if (!result.ok) {
        throw StateError(l10n.adminText('training.print_failed'));
      }
      return;
    }
    final server = printer.server;
    if (server == null) {
      throw StateError(l10n.adminText('training.printer_server_missing'));
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
        detail.isEmpty ? l10n.adminText('training.print_failed') : detail,
      );
    }
  }

  Future<bool> _printTrainingMaterialAndQolip(
    ProductionMapSaved order,
    List<AdminRawMaterialAssignment> assignments,
  ) async {
    final l10n = context.l10n;
    if (assignments.isEmpty) {
      showAdminTopNotice(
        context,
        l10n.adminText('training.no_material_assigned'),
        icon: Icons.inventory_2_outlined,
      );
      return false;
    }
    try {
      final products = await MobileApi.instance.qolipProducts(
        query: order.map.productCode,
        limit: 20,
        withQolipOnly: true,
      );
      final qolip = trainingQolipForOrder(order: order, products: products);
      if (qolip == null) {
        throw StateError(l10n.adminText('training.qolip_missing'));
      }
      if (!mounted) {
        return false;
      }
      final printer = await pickProgressPrinter(context);
      if (!mounted || printer == null) {
        if (mounted) {
          showAdminTopNotice(
            context,
            l10n.adminText('training.printer_missing'),
            icon: Icons.print_disabled_outlined,
          );
        }
        return false;
      }
      for (final assignment in assignments) {
        if (assignment.barcode.trim().isEmpty) {
          throw StateError(l10n.adminText('training.material_qr_missing'));
        }
        await _printTrainingLabel(
          printer,
          _trainingMaterialPrintRequest(assignment, printer),
        );
      }
      await _printTrainingQolipLabel(printer, qolip);
      if (mounted) {
        showAdminTopNotice(
          context,
          l10n.adminText('training.material_qolip_printed'),
          icon: Icons.print_rounded,
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        final message = error is MobileApiException
            ? error.message
            : error.toString().replaceFirst('Bad state: ', '');
        showAdminTopNotice(
          context,
          message.trim().isEmpty
              ? l10n.adminText('training.material_qolip_print_failed')
              : message,
          icon: Icons.error_outline,
        );
      }
      return false;
    }
  }

  Future<void> _printTrainingQolipLabel(
    ProgressPrinterOption printer,
    QolipProduct qolip,
  ) async {
    final qolipPrintFailedMessage =
        context.l10n.adminText('training.qolip_print_failed');
    final code = qolip.qolipCode.trim();
    if (code.isEmpty) {
      throw StateError(context.l10n.adminText('training.qolip_missing'));
    }
    final selectedPrinter =
        printer.printer.trim().isEmpty ? 'godex' : printer.printer.trim();
    final selectedPrintMode =
        printer.printMode.trim().isEmpty ? 'label' : printer.printMode.trim();
    final result = await MobileApi.instance.qolipPrintCodeQr(
      qolipCode: code,
      driverUrl: printer.driverUrl,
      printer: selectedPrinter,
      printMode: selectedPrintMode,
      customerName: qolip.customerNames.join(', '),
      qolipColor: qolip.qolipColor,
      printTransport: printer.transport,
    );
    if (!printer.transport.isLocal) {
      return;
    }
    final printResult = await PrintService.printRps(
      result.printJob,
      printerProfile: printer.offlinePrinter,
      bluetoothPrinter: printer.bluetoothPrinter,
      transport: printer.transport,
    );
    if (!printResult.ok) {
      throw StateError(qolipPrintFailedMessage);
    }
  }

  List<ProductionMapSaved> _ordersFor(AdminApparatus apparatus) {
    return [
      for (final order in _orders)
        if (order.map.nodes.any(
          (node) =>
              node.kind == 'apparatus' &&
              node.apparatusId.trim() == apparatus.id.trim(),
        ))
          order,
    ];
  }

  List<AdminRawMaterialAssignment> _assignmentsFor(AdminApparatus apparatus) {
    return [
      for (final assignment in _assignments)
        if (assignment.apparatus.trim() == apparatus.id.trim()) assignment,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 112;
    return AdminShell(
      title: l10n.adminText('training.title'),
      selectedRouteName: AppRoutes.adminTraining,
      activeTab: AdminDockTab.home,
      primaryFabActions: [
        AdminFabMenuAction(
          title: l10n.adminText('training.order_add'),
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
                      if (_loadWarnings.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    l10n.adminText('training.partial_load'),
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      if (_apparatus.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child:
                                Text(l10n.adminText('training.no_apparatus')),
                          ),
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
                                inputBatchesByOrder: {
                                  for (final order
                                      in _ordersFor(_apparatus[index]))
                                    order.map.id.trim():
                                        _inputBatchesFor(order),
                                },
                                orders: _ordersFor(_apparatus[index]),
                                statuses: _statuses,
                                expanded: _expandedId == _apparatus[index].id,
                                saving: _savingId == _apparatus[index].id,
                                linking:
                                    _linkingOrderId == _apparatus[index].id,
                                restarting:
                                    _restartingId == _apparatus[index].id,
                                deletingOrderId: _deletingOrderId,
                                deletingMaterialKey: _deletingMaterialKey,
                                generatingInputBatchOrderId:
                                    _generatingInputBatchOrderId,
                                onDeleteOrder: _deleteTrainingOrder,
                                onDeleteMaterial: _deleteTrainingMaterial,
                                onOrderTap: _showTrainingOrderDetails,
                                onAssignmentTap: _showTrainingMaterialDetails,
                                onBatchTap: _showTrainingInputBatchDetails,
                                onGenerateInputBatch:
                                    _generateTrainingInputBatch,
                                onExpandedChanged: (expanded) {
                                  setState(() {
                                    _expandedId =
                                        expanded ? _apparatus[index].id : null;
                                  });
                                },
                                onTrainingChanged: (enabled) =>
                                    _setTrainingEnabled(
                                        _apparatus[index], enabled),
                                onLinkOrder: () =>
                                    _openOrderForApparatus(_apparatus[index]),
                                onRestart: () =>
                                    _restartTraining(_apparatus[index]),
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

class _AdminTrainingLoadPart {
  const _AdminTrainingLoadPart({required this.name, this.value, this.error});

  final String name;
  final Object? value;
  final Object? error;
}

bool _trainingStatusesEqual(
  Map<String, AdminTrainingOrderStatus> left,
  Map<String, AdminTrainingOrderStatus> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    final next = right[entry.key];
    if (next == null || !_trainingStatusEqual(entry.value, next)) {
      return false;
    }
  }
  return true;
}

bool _trainingStatusEqual(
  AdminTrainingOrderStatus left,
  AdminTrainingOrderStatus right,
) {
  return left.orderId == right.orderId &&
      left.apparatus == right.apparatus &&
      left.state == right.state &&
      left.action == right.action &&
      left.actorRef == right.actorRef &&
      left.actorDisplayName == right.actorDisplayName &&
      left.updatedAtUnix == right.updatedAtUnix &&
      left.completedAtUnix == right.completedAtUnix;
}

enum _TrainingOrderStatusTone { pending, inProgress, paused, completed }

_TrainingOrderStatusTone _trainingOrderStatusTone(
  AdminTrainingOrderStatus? status,
) {
  switch (status?.state.trim().toLowerCase()) {
    case 'completed':
      return _TrainingOrderStatusTone.completed;
    case 'in_progress':
      return _TrainingOrderStatusTone.inProgress;
    case 'paused':
      return _TrainingOrderStatusTone.paused;
    default:
      return _TrainingOrderStatusTone.pending;
  }
}

String _trainingOrderStatusLabel(
  AppLocalizations l10n,
  AdminTrainingOrderStatus status,
) {
  switch (_trainingOrderStatusTone(status)) {
    case _TrainingOrderStatusTone.completed:
      return l10n.adminText('training.status_completed');
    case _TrainingOrderStatusTone.inProgress:
      return l10n.adminText('training.status_in_progress');
    case _TrainingOrderStatusTone.paused:
      return l10n.adminText('training.status_paused');
    case _TrainingOrderStatusTone.pending:
      return l10n.adminText('training.status_pending');
  }
}

String _trainingRawMaterialStatusLabel(AppLocalizations l10n, String status) {
  switch (status.trim().toLowerCase()) {
    case 'available':
      return l10n.adminText('stock.status.available');
    case 'reserved':
      return l10n.adminText('stock.status.reserved');
    case 'in_use':
      return l10n.adminText('stock.status.in_use');
    case 'consumed':
      return l10n.adminText('stock.status.consumed');
    default:
      return status.trim().isEmpty
          ? l10n.adminText('status.no_data')
          : status.trim();
  }
}

IconData _trainingOrderStatusIcon(AdminTrainingOrderStatus? status) {
  switch (_trainingOrderStatusTone(status)) {
    case _TrainingOrderStatusTone.completed:
      return Icons.check_circle_rounded;
    case _TrainingOrderStatusTone.inProgress:
      return Icons.play_circle_outline_rounded;
    case _TrainingOrderStatusTone.paused:
      return Icons.pause_circle_outline_rounded;
    case _TrainingOrderStatusTone.pending:
      return Icons.receipt_long_outlined;
  }
}

Color _trainingOrderStatusColor(
  BuildContext context,
  AdminTrainingOrderStatus? status,
) {
  final scheme = Theme.of(context).colorScheme;
  switch (_trainingOrderStatusTone(status)) {
    case _TrainingOrderStatusTone.completed:
      return const Color(0xFF2E7D32);
    case _TrainingOrderStatusTone.inProgress:
      return scheme.primary;
    case _TrainingOrderStatusTone.paused:
      return scheme.tertiary;
    case _TrainingOrderStatusTone.pending:
      return scheme.onSurfaceVariant;
  }
}

class _TrainingApparatusTile extends StatelessWidget {
  const _TrainingApparatusTile({
    required this.apparatus,
    required this.assignments,
    required this.inputBatchesByOrder,
    required this.orders,
    required this.statuses,
    required this.expanded,
    required this.saving,
    required this.linking,
    required this.restarting,
    required this.deletingOrderId,
    required this.deletingMaterialKey,
    required this.generatingInputBatchOrderId,
    required this.onExpandedChanged,
    required this.onTrainingChanged,
    required this.onLinkOrder,
    required this.onDeleteOrder,
    required this.onDeleteMaterial,
    required this.onOrderTap,
    required this.onAssignmentTap,
    required this.onBatchTap,
    required this.onGenerateInputBatch,
    required this.onRestart,
    required this.slot,
  });

  final AdminApparatus apparatus;
  final List<AdminRawMaterialAssignment> assignments;
  final Map<String, List<AdminProgressBatch>> inputBatchesByOrder;
  final List<ProductionMapSaved> orders;
  final Map<String, AdminTrainingOrderStatus> statuses;
  final bool expanded;
  final bool saving;
  final bool linking;
  final bool restarting;
  final String? deletingOrderId;
  final String? deletingMaterialKey;
  final String? generatingInputBatchOrderId;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<bool> onTrainingChanged;
  final VoidCallback onLinkOrder;
  final ValueChanged<ProductionMapSaved> onDeleteOrder;
  final Future<bool> Function(AdminRawMaterialAssignment) onDeleteMaterial;
  final ValueChanged<ProductionMapSaved> onOrderTap;
  final ValueChanged<AdminRawMaterialAssignment> onAssignmentTap;
  final ValueChanged<AdminProgressBatch> onBatchTap;
  final Future<AdminProgressBatch?> Function(ProductionMapSaved)
      onGenerateInputBatch;
  final VoidCallback onRestart;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final completedCount = orders
        .where((order) => statuses[order.map.id.trim()]?.isCompleted == true)
        .length;
    final assignmentsByOrderId = <String, List<AdminRawMaterialAssignment>>{};
    for (final assignment in assignments) {
      final orderId = assignment.orderId.trim();
      if (orderId.isEmpty) {
        continue;
      }
      assignmentsByOrderId.putIfAbsent(orderId, () => []).add(assignment);
    }
    final summaryParts = <String>[
      apparatus.trainingEnabled
          ? l10n.adminText('training.mode_summary')
          : l10n.adminText('training.production_summary'),
      if (orders.isNotEmpty)
        l10n.adminText(
          'training.test_orders_count',
          values: {'count': orders.length},
        ),
      if (completedCount > 0)
        l10n.adminText(
          'training.completed_count',
          values: {'count': completedCount},
        ),
      if (assignments.isNotEmpty)
        l10n.adminText(
          'training.test_materials_count',
          values: {'count': assignments.length},
        ),
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
                      key: ValueKey('admin-training-details-${apparatus.id}'),
                      tooltip: expanded
                          ? l10n.adminText('training.collapse')
                          : l10n.adminText('training.expand'),
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                                    ? l10n.adminText('training.mode_on')
                                    : l10n.adminText(
                                        'training.production_mode_on',
                                      ),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: restarting ? null : onRestart,
                            icon: restarting
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.restart_alt_rounded),
                            label: Text(l10n.adminText('training.restart')),
                          ),
                        ),
                        const SizedBox(height: 4),
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
                            label: Text(
                              l10n.adminText('training.attach_order'),
                            ),
                          ),
                        ),
                        if (orders.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          for (final order in orders)
                            _TrainingOrderCard(
                              order: order,
                              apparatusCatalog: [apparatus],
                              status: statuses[order.map.id.trim()],
                              assignments:
                                  assignmentsByOrderId[order.map.id.trim()] ??
                                      const [],
                              inputBatches:
                                  inputBatchesByOrder[order.map.id.trim()] ??
                                      const [],
                              deleting: deletingOrderId == order.map.id.trim(),
                              deletingMaterialKey: deletingMaterialKey,
                              generatingInputBatch:
                                  generatingInputBatchOrderId ==
                                      order.map.id.trim(),
                              onDelete: () => onDeleteOrder(order),
                              onDeleteMaterial: onDeleteMaterial,
                              onOpenDetails: () => onOrderTap(order),
                              onAssignmentTap: onAssignmentTap,
                              onBatchTap: onBatchTap,
                              onGenerateInputBatch: () =>
                                  onGenerateInputBatch(order),
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

class _TrainingOrderCard extends StatefulWidget {
  const _TrainingOrderCard({
    required this.order,
    required this.apparatusCatalog,
    required this.status,
    required this.assignments,
    required this.inputBatches,
    required this.deleting,
    required this.deletingMaterialKey,
    required this.generatingInputBatch,
    required this.onDelete,
    required this.onDeleteMaterial,
    required this.onOpenDetails,
    required this.onAssignmentTap,
    required this.onBatchTap,
    required this.onGenerateInputBatch,
  });

  final ProductionMapSaved order;
  final List<AdminApparatus> apparatusCatalog;
  final AdminTrainingOrderStatus? status;
  final List<AdminRawMaterialAssignment> assignments;
  final List<AdminProgressBatch> inputBatches;
  final bool deleting;
  final String? deletingMaterialKey;
  final bool generatingInputBatch;
  final VoidCallback onDelete;
  final Future<bool> Function(AdminRawMaterialAssignment) onDeleteMaterial;
  final VoidCallback onOpenDetails;
  final ValueChanged<AdminRawMaterialAssignment> onAssignmentTap;
  final ValueChanged<AdminProgressBatch> onBatchTap;
  final Future<AdminProgressBatch?> Function() onGenerateInputBatch;

  @override
  State<_TrainingOrderCard> createState() => _TrainingOrderCardState();
}

class _TrainingOrderCardState extends State<_TrainingOrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = widget.status;
    final color = _trainingOrderStatusColor(context, status);
    final subtitleParts = <String>[
      if (widget.order.map.productCode.trim().isNotEmpty)
        widget.order.map.productCode.trim(),
      if (status != null) _trainingOrderStatusLabel(l10n, status),
      if (status != null && status.actorDisplayName.trim().isNotEmpty)
        status.actorDisplayName.trim(),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: status == null
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.32)
            : color.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              onLongPress: widget.onOpenDetails,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    Icon(
                      _trainingOrderStatusIcon(status),
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _trainingOrderLabel(widget.order),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleParts.isEmpty
                                ? l10n.adminText('training.order_label')
                                : subtitleParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    widget.deleting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.adminText('training.order_delete'),
                            onPressed: widget.onDelete,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(40, 0, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 4),
                          if (widget.assignments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                l10n.adminText('training.no_material_assigned'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          for (final assignment in widget.assignments)
                            Builder(
                              builder: (context) {
                                final materialKey = _trainingMaterialKey(
                                  assignment,
                                );
                                final deleting =
                                    widget.deletingMaterialKey == materialKey;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.qr_code_2_rounded,
                                    size: 20,
                                    color: color,
                                  ),
                                  title: Text(
                                    assignment.itemName.isEmpty
                                        ? assignment.barcode
                                        : assignment.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    assignment.barcode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      deleting
                                          ? const SizedBox.square(
                                              dimension: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              tooltip: l10n.adminText(
                                                'training.material_delete_tooltip',
                                              ),
                                              onPressed: () {
                                                unawaited(
                                                  widget.onDeleteMaterial(
                                                    assignment,
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                            ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  onTap: () =>
                                      widget.onAssignmentTap(assignment),
                                );
                              },
                            ),
                          if (_trainingOrderNeedsGeneratedInputBatch(
                            widget.order.map,
                            widget.apparatusCatalog,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: OutlinedButton.icon(
                                onPressed: widget.generatingInputBatch
                                    ? null
                                    : () => unawaited(
                                          widget.onGenerateInputBatch(),
                                        ),
                                icon: widget.generatingInputBatch
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.qr_code_2_rounded),
                                label: Text(
                                  widget.inputBatches.isNotEmpty
                                      ? l10n.adminText(
                                          'training.batch_generate_more',
                                          values: {
                                            'count': widget.inputBatches.length,
                                          },
                                        )
                                      : l10n.adminText(
                                          'training.batch_generate',
                                        ),
                                ),
                              ),
                            ),
                          for (final batch in widget.inputBatches)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.qr_code_2_rounded,
                                size: 20,
                                color: color,
                              ),
                              title: Text(
                                l10n.adminText('training.batch_qr_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                batch.qrPayload,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                              ),
                              onTap: () => widget.onBatchTap(batch),
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

class _TrainingOrderDetailsSheet extends StatefulWidget {
  const _TrainingOrderDetailsSheet({
    required this.order,
    required this.apparatusCatalog,
    required this.assignments,
    required this.inputBatches,
    required this.onLinkMaterial,
    required this.onDeleteMaterial,
    required this.onPrintMaterialAndQolip,
    required this.onGenerateInputBatch,
    required this.onBatchTap,
  });

  final ProductionMapSaved order;
  final List<AdminApparatus> apparatusCatalog;
  final List<AdminRawMaterialAssignment> assignments;
  final List<AdminProgressBatch> inputBatches;
  final Future<AdminRawMaterialAssignment?> Function() onLinkMaterial;
  final Future<bool> Function(AdminRawMaterialAssignment) onDeleteMaterial;
  final Future<bool> Function(List<AdminRawMaterialAssignment>)
      onPrintMaterialAndQolip;
  final Future<AdminProgressBatch?> Function() onGenerateInputBatch;
  final ValueChanged<AdminProgressBatch> onBatchTap;

  @override
  State<_TrainingOrderDetailsSheet> createState() =>
      _TrainingOrderDetailsSheetState();
}

class _TrainingOrderDetailsSheetState
    extends State<_TrainingOrderDetailsSheet> {
  late List<AdminRawMaterialAssignment> _assignments;
  late List<AdminProgressBatch> _inputBatches;
  bool _linking = false;
  bool _generatingInputBatch = false;
  bool _printingMaterialAndQolip = false;
  String? _deletingMaterialKey;

  @override
  void initState() {
    super.initState();
    _assignments = [...widget.assignments];
    _inputBatches = [...widget.inputBatches];
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

  Future<void> _generateInputBatch() async {
    if (_generatingInputBatch) {
      return;
    }
    setState(() => _generatingInputBatch = true);
    try {
      final batch = await widget.onGenerateInputBatch();
      if (!mounted || batch == null) {
        return;
      }
      setState(() {
        _inputBatches = [
          for (final item in _inputBatches)
            if (item.batchId.trim() != batch.batchId.trim()) item,
          batch,
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _generatingInputBatch = false);
      }
    }
  }

  Future<void> _deleteMaterial(AdminRawMaterialAssignment assignment) async {
    final materialKey = _trainingMaterialKey(assignment);
    if (_deletingMaterialKey != null) {
      return;
    }
    setState(() => _deletingMaterialKey = materialKey);
    try {
      final deleted = await widget.onDeleteMaterial(assignment);
      if (mounted && deleted) {
        setState(() {
          _assignments = [
            for (final item in _assignments)
              if (_trainingMaterialKey(item) != materialKey) item,
          ];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _deletingMaterialKey = null);
      }
    }
  }

  Future<void> _printMaterialAndQolip() async {
    if (_printingMaterialAndQolip || _assignments.isEmpty) {
      return;
    }
    setState(() => _printingMaterialAndQolip = true);
    try {
      await widget.onPrintMaterialAndQolip(_assignments);
    } finally {
      if (mounted) {
        setState(() => _printingMaterialAndQolip = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = widget.order.map;
    final apparatus = map.nodes
        .where(
          (node) =>
              node.kind == 'apparatus' && node.apparatusId.trim().isNotEmpty,
        )
        .map(
          (node) => _trainingApparatusDisplayName(
            node.apparatusId,
            widget.apparatusCatalog,
          ),
        )
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
                          l10n.adminText('training.order_details'),
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
                title: l10n.adminText('training.order_information'),
                icon: Icons.info_outline_rounded,
                children: [
                  if (map.orderNumber.trim().isNotEmpty)
                    AppInfoRow(
                      label: l10n.adminText('training.order_number'),
                      value: map.orderNumber,
                      selectable: true,
                    ),
                  AppInfoRow(
                    label: l10n.adminText('training.product'),
                    value: map.title,
                  ),
                  if (map.productCode.trim().isNotEmpty)
                    AppInfoRow(
                      label: l10n.adminText('training.product_code'),
                      value: map.productCode,
                      selectable: true,
                    ),
                  if (map.code.trim().isNotEmpty)
                    AppInfoRow(
                      label: l10n.adminText('label.code'),
                      value: map.code,
                    ),
                  if (map.customerName.trim().isNotEmpty)
                    AppInfoRow(
                      label: l10n.adminText('training.customer'),
                      value: map.customerName,
                    ),
                  if (map.rollCount != null && map.rollCount! > 0)
                    AppInfoRow(
                      label: l10n.adminText('training.roll_count'),
                      value: l10n.adminText(
                        'training.roll_count_value',
                        values: {'value': formatRawQuantity(map.rollCount!)},
                      ),
                    ),
                  if (map.widthMm != null && map.widthMm! > 0)
                    AppInfoRow(
                      label: l10n.adminText('training.width'),
                      value: l10n.adminText(
                        'training.width_value',
                        values: {'value': formatRawQuantity(map.widthMm!)},
                      ),
                    ),
                  if (map.orderKg != null && map.orderKg! > 0)
                    AppInfoRow(
                      label: l10n.adminText('training.planned_weight'),
                      value: l10n.adminText(
                        'training.weight_value',
                        values: {'value': formatRawQuantity(map.orderKg!)},
                      ),
                    ),
                  if (map.baseLength != null && map.baseLength! > 0)
                    AppInfoRow(
                      label: l10n.adminText('training.planned_length'),
                      value: l10n.adminText(
                        'training.length_value',
                        values: {'value': formatRawQuantity(map.baseLength!)},
                      ),
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
                  _linking
                      ? l10n.adminText('training.linking')
                      : l10n.adminText('training.material_link'),
                ),
              ),
              if (_trainingOrderNeedsGeneratedInputBatch(
                map,
                widget.apparatusCatalog,
              )) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _generatingInputBatch ? null : _generateInputBatch,
                  icon: _generatingInputBatch
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    _inputBatches.isNotEmpty
                        ? l10n.adminText(
                            'training.batch_generate_more',
                            values: {'count': _inputBatches.length},
                          )
                        : l10n.adminText('training.batch_generate'),
                  ),
                ),
              ],
              if (_assignments.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('training-print-material-qolip'),
                  onPressed:
                      _printingMaterialAndQolip ? null : _printMaterialAndQolip,
                  icon: _printingMaterialAndQolip
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined),
                  label: Text(
                    _printingMaterialAndQolip
                        ? l10n.adminText(
                            'training.printing_material_qolip',
                          )
                        : l10n.adminText('training.print_material_qolip'),
                  ),
                ),
                const SizedBox(height: 8),
                _TrainingOrderDetailsSection(
                  title: l10n.adminText('training.assigned_materials'),
                  icon: Icons.inventory_2_outlined,
                  children: [
                    for (final assignment in _assignments)
                      AppInfoRow(
                        label: assignment.itemName.trim().isEmpty
                            ? l10n.adminText('training.material')
                            : assignment.itemName,
                        value: assignment.barcode,
                        selectable: true,
                        trailing: _deletingMaterialKey ==
                                _trainingMaterialKey(assignment)
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                tooltip: l10n.adminText(
                                  'training.material_delete_tooltip',
                                ),
                                onPressed: () {
                                  unawaited(_deleteMaterial(assignment));
                                },
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                      ),
                  ],
                ),
              ],
              if (_inputBatches.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TrainingOrderDetailsSection(
                  title: l10n.adminText('training.assigned_batches'),
                  icon: Icons.qr_code_2_rounded,
                  children: [
                    for (final batch in _inputBatches)
                      AppInfoRow(
                        label: l10n.adminText('training.batch_qr'),
                        value: batch.qrPayload,
                        selectable: true,
                        onTap: () => widget.onBatchTap(batch),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                  ],
                ),
              ],
              if (apparatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TrainingOrderDetailsSection(
                  title: l10n.adminText('training.assigned_apparatus'),
                  icon: Icons.precision_manufacturing_outlined,
                  children: [
                    AppInfoRow(
                      label: l10n.adminText('training.apparatus'),
                      value: apparatus,
                    ),
                  ],
                ),
              ],
              if (stages.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TrainingOrderDetailsSection(
                  title: l10n.adminText('training.production_stages'),
                  icon: Icons.account_tree_outlined,
                  children: [
                    for (var index = 0; index < stages.length; index++)
                      AppInfoRow(
                        label: l10n.adminText(
                          'training.stage_number',
                          values: {'number': index + 1},
                        ),
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
        _validationMessage = context.l10n.adminText('training.micron_required');
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(_TrainingMaterialLinkDraft(material: _material!, micron: micron));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                l10n.adminText('training.link_material_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.adminText(
                  'training.apparatus_value',
                  values: {'apparatus': widget.apparatus},
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<CalculateMaterial>(
                initialValue: _material,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.adminText('training.material_name'),
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
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
                decoration: InputDecoration(
                  labelText: l10n.adminText('label.micron'),
                  hintText: l10n.adminText('training.micron_hint'),
                  prefixIcon: const Icon(Icons.straighten_outlined),
                  suffixText: 'µm',
                ),
              ),
              const SizedBox(height: 12),
              _TrainingSheetNotice(
                icon: Icons.print_outlined,
                text: l10n.adminText('training.material_link_notice'),
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
                label: Text(l10n.adminText('training.continue_micron')),
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

bool _trainingOrderNeedsGeneratedInputBatch(
  ProductionMapDefinition map,
  Iterable<AdminApparatus> apparatusCatalog,
) {
  final operationById = {
    for (final apparatus in apparatusCatalog)
      apparatus.id.trim(): apparatus.operation.trim().toLowerCase(),
  };
  return map.nodes.any((node) {
    final operation = operationById[node.apparatusId.trim()];
    if (node.kind != 'apparatus' ||
        (operation != 'laminate' && operation != 'cut')) {
      return false;
    }
    return productionMapPreviousWorkStageStation(
          map: map,
          station: node.apparatusId,
        ) ==
        null;
  });
}

String _trainingApparatusDisplayName(
  String apparatusId,
  Iterable<AdminApparatus> catalog,
) {
  final normalized = apparatusId.trim();
  if (normalized == 'training-input:bosma') return 'Bosma aparat';
  if (normalized == 'training-input:laminatsiya') {
    return 'Laminatsiya aparat';
  }
  for (final apparatus in catalog) {
    if (apparatus.id.trim() == normalized) return apparatus.name.trim();
  }
  return normalized;
}

String _trainingMaterialKey(AdminRawMaterialAssignment assignment) {
  return '${assignment.orderId.trim()}::'
      '${assignment.apparatus.trim()}::'
      '${assignment.barcode.trim().toUpperCase()}';
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
            context.l10n.adminText('training.apparatus_select'),
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
