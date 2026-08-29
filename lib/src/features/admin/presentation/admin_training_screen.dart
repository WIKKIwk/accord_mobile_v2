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

part 'admin_training_screen__AdminTrainingScreenState_methods_01.dart';
part 'admin_training_screen__AdminTrainingScreenState_methods_02.dart';
part 'admin_training_screen__AdminTrainingScreenState_methods_03.dart';
part 'admin_training_screen_widgets_part_01.dart';
part 'admin_training_screen_widgets_part_02.dart';
part 'admin_training_screen_models_part_03.dart';
part 'admin_training_screen_models_part_04.dart';
part 'admin_training_screen_models_part_05.dart';

const double _adminTrainingPanelGap = 4;

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

  bool get _hasTrainingData =>
      _apparatus.isNotEmpty ||
      _materials.isNotEmpty ||
      _orders.isNotEmpty ||
      _assignments.isNotEmpty ||
      _inputBatches.isNotEmpty;

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
                                onPrintMaterialAndQolip:
                                    _printTrainingMaterialAndQolip,
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

int _trainingBarcodeSequence = 0;
