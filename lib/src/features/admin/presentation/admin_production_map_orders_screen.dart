import 'dart:async';
import 'dart:math' show cos, sin;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../aparatchi/presentation/widgets/aparatchi_navigation_drawer.dart';
import '../../boyoqchi/models/returned_paint_models.dart';
import '../../boyoqchi/presentation/widgets/returned_paint_sheet.dart';
import '../../boyoqchi/state/returned_paint_draft_store.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../qolip/presentation/qolip_home_screen.dart'
    show showQolipProductSpecSheet;
import '../../qolip/presentation/widgets/qolip_dock.dart';
import '../../qolip/presentation/widgets/qolip_navigation_drawer.dart';
import '../logic/apparatus_queue_state.dart';
import '../logic/canonical_apparatus_display.dart';
import '../logic/production_map_edit_policy.dart';
import '../logic/production_map_chain.dart';
import '../logic/production_map_pechat_rules.dart';
import '../models/production_map_models.dart';
import '../state/calculate_order_store.dart';
import '../../shared/models/app_models.dart';
import 'raw_material_scan_dialog.dart';
import 'admin_production_map_test_screen.dart'
    show ProductionMapOrderContext, ProductionMapTestArgs;
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_top_notice.dart';
import 'progress_printer_picker.dart';
import 'admin_progress_qr_scan_screen.dart';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

part 'admin_production_map_orders_helpers.dart';
part 'admin_production_map_orders_detail_widgets.dart';
part 'admin_production_map_orders_read_only_sheet.dart';
part 'admin_production_map_orders_live_state.dart';
part 'admin_production_map_orders_move_state.dart';
part 'admin_production_map_orders_detail_material_widgets.dart';
part 'admin_production_map_orders_detail_map_widgets.dart';
part 'admin_production_map_orders_move_widgets.dart';
part 'admin_production_map_orders_closed_widgets.dart';
part 'admin_production_map_orders_closed_log_sheet.dart';
part 'admin_production_map_orders_apparatus_picker.dart';
part 'admin_production_map_orders_opened_widgets.dart';
part 'admin_production_map_orders_completion_widgets.dart';
part 'admin_production_map_orders_sequence_widgets.dart';
part 'admin_production_map_orders_sequence_assignment_sheet.dart';
part 'admin_production_map_orders_sequence_qolip_note_sheet.dart';
part 'admin_production_map_orders_move_module.dart';
part 'admin_production_map_orders_progress_printer.dart';
part 'admin_production_map_orders_progress_qty.dart';
part 'admin_production_map_orders_module_pages.dart';
part 'admin_production_map_orders_opening_wip.dart';
part 'admin_production_map_orders_wip_history_sheet.dart';
part 'admin_production_map_orders_models.dart';
part 'admin_production_map_orders_calculation_helpers.dart';
part 'admin_production_map_orders_read_only_helpers.dart';
part 'admin_production_map_orders_move_helpers.dart';
part 'admin_production_map_orders_queue_helpers.dart';
part 'admin_production_map_orders_search_helpers.dart';
part 'admin_production_map_orders_worker_helpers.dart';
part 'admin_production_map_orders_apparatus_helpers.dart';
part 'admin_production_map_orders_live_helpers.dart';
part 'admin_production_map_orders_closed_log_sheet_helpers_part_01.dart';
part 'admin_production_map_orders_closed_log_sheet_widgets_part_02.dart';
part 'admin_production_map_orders_detail_material_widgets_widgets_part_01.dart';
part 'admin_production_map_orders_detail_material_widgets_widgets_part_02.dart';
part 'admin_production_map_orders_detail_material_widgets_models_part_03.dart';
part 'admin_production_map_orders_detail_widgets_declarations_part_01.dart';
part 'admin_production_map_orders_detail_widgets_widgets_part_02.dart';
part 'admin_production_map_orders_detail_widgets_helpers_part_03.dart';
part 'admin_production_map_orders_live_state__AdminProductionMapOrdersLiveState_methods_01.dart';
part 'admin_production_map_orders_live_state__AdminProductionMapOrdersLiveState_methods_02.dart';
part 'admin_production_map_orders_module_pages_widgets_part_01.dart';
part 'admin_production_map_orders_module_pages_widgets_part_02.dart';
part 'admin_production_map_orders_module_pages_declarations_part_03.dart';
part 'admin_production_map_orders_module_pages_widgets_part_04.dart';
part 'admin_production_map_orders_move_state__AdminProductionMapOrdersMoveState_methods_01.dart';
part 'admin_production_map_orders_move_state__AdminProductionMapOrdersMoveState_methods_02.dart';
part 'admin_production_map_orders_move_state_widgets_part_01.dart';
part 'admin_production_map_orders_opened_widgets_declarations_part_01.dart';
part 'admin_production_map_orders_opened_widgets_declarations_part_02.dart';
part 'admin_production_map_orders_opening_wip__OpeningWipWizardState_methods_01.dart';
part 'admin_production_map_orders_opening_wip_widgets_part_01.dart';
part 'admin_production_map_orders_opening_wip_models_part_02.dart';
part 'admin_production_map_orders_opening_wip_models_part_03.dart';
part 'admin_production_map_orders_opening_wip_models_part_04.dart';
part 'admin_production_map_orders_progress_qty__ProgressQtyDialogState_methods_01.dart';
part 'admin_production_map_orders_progress_qty__ProgressQtyDialogState_methods_02.dart';
part 'admin_production_map_orders_progress_qty__ProgressQtyDialogState_methods_03.dart';
part 'admin_production_map_orders_progress_qty_declarations_part_01.dart';
part 'admin_production_map_orders_read_only_helpers_helpers_part_01.dart';
part 'admin_production_map_orders_read_only_helpers_helpers_part_02.dart';
part 'admin_production_map_orders_read_only_sheet__ReadOnlyOrderDetailSheetState_methods_01.dart';
part 'admin_production_map_orders_read_only_sheet__ReadOnlyOrderDetailSheetState_methods_02.dart';
part 'admin_production_map_orders_read_only_sheet__ReadOnlyOrderDetailSheetState_methods_03.dart';
part 'admin_production_map_orders_read_only_sheet__ReadOnlyOrderDetailSheetState_methods_04.dart';
part 'admin_production_map_orders_read_only_sheet_declarations_part_01.dart';
part 'admin_production_map_orders_screen__AdminProductionMapOrdersScreenState_methods_01.dart';
part 'admin_production_map_orders_screen__AdminProductionMapOrdersScreenState_methods_02.dart';
part 'admin_production_map_orders_screen__AdminProductionMapOrdersScreenState_methods_03.dart';
part 'admin_production_map_orders_screen_declarations_part_01.dart';
part 'admin_production_map_orders_sequence_assignment_sheet__SequenceRawMaterialAssignmentSheetState_methods_01.dart';
part 'admin_production_map_orders_sequence_assignment_sheet__SequenceRawMaterialAssignmentSheetState_methods_02.dart';
part 'admin_production_map_orders_sequence_assignment_sheet_widgets_part_01.dart';
part 'admin_production_map_orders_sequence_assignment_sheet_widgets_part_02.dart';
part 'admin_production_map_orders_sequence_assignment_sheet_declarations_part_03.dart';
part 'admin_production_map_orders_sequence_widgets_widgets_part_01.dart';
part 'admin_production_map_orders_sequence_widgets_widgets_part_02.dart';
part 'admin_production_map_orders_wip_history_sheet_widgets_part_01.dart';
part 'admin_production_map_orders_wip_history_sheet_models_part_02.dart';
part 'admin_production_map_orders_wip_history_sheet_helpers_part_03.dart';

const double _openedOrderPanelCardGap = 4;
const double _openedOrderPanelTopGap = 8;
const ShapeBorder _orderDetailSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

class _AdminProductionMapOrdersScreenState
    extends State<AdminProductionMapOrdersScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late TabController _tabController;
  bool _loading = true;
  String? _loadError;
  bool _liveRefreshInFlight = false;
  bool _liveRefreshQueued = false;
  bool _mapsRefreshInFlight = false;
  bool _queueSnapshotRefreshInFlight = false;
  bool _queueSnapshotRefreshQueued = false;
  bool _queueSnapshotContractError = false;
  String? _queueSnapshotErrorMessage;
  bool _workerCompletedHistoryError = false;
  String? _workerCompletedHistoryErrorMessage;
  String? _closedOrdersErrorMessage;
  String? _completionRequestsErrorMessage;
  int _liveStreamGeneration = 0;
  int _queueSnapshotGeneration = 0;
  StreamSubscription<AdminProductionMapLiveSnapshot>? _liveStreamSubscription;
  Timer? _queueSnapshotPollTimer;
  String _searchQuery = '';
  _OpenedOrderModule _module = _OpenedOrderModule.orders;
  AdminApparatus? _selectedApparatus;
  AdminApparatus? _moveTopApparatus;
  AdminApparatus? _moveBottomApparatus;
  final Set<String> _selectedMoveOrderIds = {};
  List<ProductionMapSaved> _draggingMoveOrders = const [];
  AdminApparatus? _draggingMoveSource;
  List<ProductionMapSaved> _orders = const [];
  List<AdminApparatus> _apparatus = const [];
  final Map<String, List<String>> _sequenceByApparatus = {};
  final Map<String, List<String>> _visibleOrderIdsByApparatus = {};
  final Map<String, Map<String, String>> _queueStatesByApparatus = {};
  final Map<String, Map<String, String>> _stageStatesByOrderId = {};
  final Map<String, AdminApparatusQueuePolicy> _queuePoliciesByApparatus = {};
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      _queueActionControlsByApparatus = {};
  final Map<String, List<AdminFrozenQueueOrder>> _frozenOrdersByApparatus = {};
  final Map<String, AdminOrderControlState> _orderControlsByOrderId = {};
  final Map<String, AdminProductionOrderStatusDetail> _orderStatusesByOrderId =
      {};
  final Map<String, AdminQolipOrderNote> _qolipOrderNotesByOrderId = {};
  List<AdminCompletedQueueOrder> _completedWorkerOrders = const [];
  List<AdminCompletionRequestNotification> _completionRequests = const [];
  final Set<String> _shownCompletionDecisionIds = {};
  List<AdminClosedProductionOrder> _closedOrders = const [];
  AdminProductionWorkflowAuditReport? _workflowAudit;
  String? _workflowAuditError;
  bool _workflowAuditLoading = false;
  final Set<String> _queueActionsInFlight = {};
  final Set<String> _orderControlActionsInFlight = {};
  Map<String, double> _baseMetrajByMapId = const {};
  Map<String, double> _orderKgByMapId = const {};
  Map<String, String> _customerByMapId = const {};

  @override
  void initState() {
    super.initState();
    if (widget.supplyViewerMode) {
      _module = _OpenedOrderModule.sequence;
    }
    if (widget.workerMode) {
      _tabController = TabController(length: 1, vsync: this);
    } else {
      _tabController = TabController(
        length: _modules.length,
        vsync: this,
        initialIndex: _modules.indexOf(_module).clamp(0, _modules.length - 1),
      );
      _tabController.addListener(_syncModuleFromTab);
    }
    if (widget.workerMode) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_startWorkerLive());
    } else {
      unawaited(_startAdminLive());
    }
  }

  @override
  void dispose() {
    if (widget.workerMode) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _stopWorkerLiveStream();
    _queueSnapshotPollTimer?.cancel();
    _queueSnapshotPollTimer = null;
    if (!widget.workerMode) {
      _tabController.removeListener(_syncModuleFromTab);
    }
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.workerMode && state == AppLifecycleState.resumed) {
      unawaited(_startWorkerLive());
    }
  }

  List<_OpenedOrderModule> get _modules {
    return widget.workerMode || widget.supplyViewerMode
        ? const [_OpenedOrderModule.sequence]
        : _OpenedOrderModule.values;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final role = AppSession.instance.profile?.role;
    final isQolipchi = role == UserRole.qolipchi;
    final isMaterialTaminotchi = role == UserRole.materialTaminotchi;
    final canViewSupplyOrderInfo =
        role == UserRole.qolipchi || isMaterialTaminotchi;
    final supplyDrawer = switch (role) {
      UserRole.qolipchi => QolipNavigationDrawer(
          selectedIndex: 0,
          selectedRouteName: AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      UserRole.materialTaminotchi => MaterialTaminotchiNavigationDrawer(
          selectedRouteName: AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      _ => null,
    };
    final supplyDock = switch (role) {
      UserRole.qolipchi => const QolipDock(activeTab: null),
      UserRole.materialTaminotchi =>
        const MaterialTaminotchiDock(activeTab: null),
      _ => null,
    };
    return AppShell(
      drawer: widget.supplyViewerMode
          ? supplyDrawer
          : widget.workerMode
              ? AparatchiNavigationDrawer(
                  selectedIndex: 0,
                  selectedRouteName: AppRoutes.apparatusQueue,
                  onNavigate: _openDrawerRoute,
                )
              : AdminNavigationDrawer(
                  selectedIndex: 0,
                  selectedRouteName: AppRoutes.adminProductionMapOrders,
                  onNavigate: _openDrawerRoute,
                ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: widget.supplyViewerMode
            ? context.l10n.productionText('worker.queue.search.sequence')
            : context.l10n.productionText('worker.queue.search.open'),
        onChanged: (value) => setState(() => _searchQuery = value),
        onClear: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
        onBack: widget.workerMode || widget.supplyViewerMode
            ? null
            : () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                  return;
                }
                nav.pushNamedAndRemoveUntil(
                  AppRoutes.adminHome,
                  (route) => false,
                );
              },
        onBackWithContext: widget.workerMode || widget.supplyViewerMode
            ? (context) => AppShellDrawerScope.maybeOf(context)?.openDrawer()
            : null,
        leadingIcon: widget.workerMode || widget.supplyViewerMode
            ? Icons.menu_rounded
            : Icons.arrow_back_rounded,
        leadingTooltip: widget.workerMode || widget.supplyViewerMode
            ? MaterialLocalizations.of(context).openAppDrawerTooltip
            : null,
      ),
      bottom: widget.supplyViewerMode
          ? supplyDock
          : widget.workerMode
              ? AparatchiDock(
                  activeTab: AparatchiDockTab.home,
                  onQrScanRequested: _openWorkerQrScanner,
                )
              : AdminDock(
                  activeTab: AdminDockTab.home,
                  showPrimaryFab: _module != _OpenedOrderModule.sequence &&
                      _module != _OpenedOrderModule.move,
                ),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : _loadError != null
              ? _OpenedOrdersLoadErrorBody(
                  message: _loadError!,
                  bottomPadding: bottomPadding,
                  onRefresh: _load,
                )
              : Column(
                  children: [
                    if (_queueSnapshotContractError)
                      _QueueSnapshotWarningBanner(
                        message: _queueSnapshotErrorMessage ??
                            context.l10n.productionText('worker.error.sync'),
                        onRetry: _refreshQueueSnapshot,
                      ),
                    if (widget.workerMode && _workerCompletedHistoryError)
                      _QueueSnapshotWarningBanner(
                        message: _workerCompletedHistoryErrorMessage ??
                            context.l10n.productionText('worker.error.sync'),
                        onRetry: _refreshWorkerCompletedOrders,
                      ),
                    if (!widget.workerMode &&
                        _completionRequestsErrorMessage != null)
                      _QueueSnapshotWarningBanner(
                        message: _completionRequestsErrorMessage!,
                        onRetry: _refreshCompletionRequests,
                      ),
                    if (!widget.workerMode && _closedOrdersErrorMessage != null)
                      _QueueSnapshotWarningBanner(
                        message: _closedOrdersErrorMessage!,
                        onRetry: _refreshClosedOrders,
                      ),
                    Expanded(
                      child: widget.workerMode
                          ? _WorkerWatchBody(
                              apparatus: _apparatus,
                              assignedApparatus: AppSession
                                      .instance.profile?.assignedApparatus ??
                                  const <String>[],
                              orders: _orders,
                              completedOrders: _completedWorkerOrders,
                              sequenceByApparatus: _sequenceByApparatus,
                              visibleOrderIdsByApparatus:
                                  _visibleOrderIdsByApparatus,
                              queueStatesByApparatus: _queueStatesByApparatus,
                              frozenOrdersByApparatus: _frozenOrdersByApparatus,
                              orderStatusesByOrderId: _orderStatusesByOrderId,
                              orderControlsByOrderId: _orderControlsByOrderId,
                              searchQuery: _searchQuery,
                              bottomPadding: bottomPadding,
                              tabController: _tabController,
                              onTapCompletedOrder: _showCompletedOrderDetail,
                              onTapWatchOrder: _showWatchOrderInfo,
                              onLongPressWatchOrder: _showWatchOrderLongPress,
                            )
                          : _AdminModulesBody(
                              modules: _modules,
                              currentModule: _module,
                              tabController: _tabController,
                              bottomPadding: bottomPadding,
                              orders: _orders,
                              searchQuery: _searchQuery,
                              apparatus: _apparatus,
                              selectedApparatus: _selectedApparatus,
                              completionRequests: _completionRequests,
                              readOnly:
                                  widget.readOnly || widget.supplyViewerMode,
                              moveTopApparatus: _moveTopApparatus,
                              moveBottomApparatus: _moveBottomApparatus,
                              selectedMoveOrderIds: _selectedMoveOrderIds,
                              draggingMoveOrders: _draggingMoveOrders,
                              draggingMoveSource: _draggingMoveSource,
                              closedOrders: _closedOrders,
                              onSetModule: _setModule,
                              ordersForApparatus: _ordersForApparatus,
                              moveOrdersForApparatus: _moveOrdersForApparatus,
                              canMoveTo: _canMoveOrderToApparatus,
                              onSelectSequenceApparatus: (apparatus) {
                                setState(() => _selectedApparatus = apparatus);
                              },
                              onReorder: (oldIndex, newIndex) {
                                unawaited(
                                  _reorderSelectedApparatusOrders(
                                      oldIndex, newIndex),
                                );
                              },
                              onPickMoveTop: () =>
                                  _pickMoveApparatus(top: true),
                              onPickMoveBottom: () =>
                                  _pickMoveApparatus(top: false),
                              onToggleMoveSelection: _toggleMoveOrderSelection,
                              buildMoveDragPayload: _buildMoveDragPayload,
                              onMoveDragStarted: (payload) {
                                setState(() {
                                  _draggingMoveOrders = payload.orders;
                                  _draggingMoveSource = payload.source;
                                });
                              },
                              onMoveDragEnded: () {
                                setState(() {
                                  _draggingMoveOrders = const [];
                                  _draggingMoveSource = null;
                                });
                              },
                              onMove: _moveOrdersBetweenApparatus,
                              onInfoOrder: _showOrderDetail,
                              onInfoSequenceOrder: widget.supplyViewerMode &&
                                      !canViewSupplyOrderInfo
                                  ? null
                                  : _showWatchOrderDetail,
                              customerNameByMapId: _customerByMapId,
                              queueStatesByApparatus: _queueStatesByApparatus,
                              visibleOrderIdsByApparatus:
                                  _visibleOrderIdsByApparatus,
                              frozenOrdersByApparatus: _frozenOrdersByApparatus,
                              orderStatusesByOrderId: _orderStatusesByOrderId,
                              qolipOrderNotesByOrderId:
                                  _qolipOrderNotesByOrderId,
                              sequenceInteractionHint: isQolipchi
                                  ? 'Bir marta bosing — ma’lumot. Uzoq bosing — qolip qaydini ochish.'
                                  : null,
                              orderControlsByOrderId: _orderControlsByOrderId,
                              workflowAudit: _workflowAudit,
                              workflowAuditError: _workflowAuditError,
                              workflowAuditLoading: _workflowAuditLoading,
                              onRefreshWorkflowAudit: () =>
                                  _refreshWorkflowAudit(force: true),
                              onLongPressOrder: (order) {
                                unawaited(
                                  widget.supplyViewerMode && isQolipchi
                                      ? _showQolipOrderNote(order)
                                      : widget.supplyViewerMode &&
                                              isMaterialTaminotchi
                                          ? _showSupplyRawMaterialAssignment(
                                              order)
                                          : _showOrderActions(order),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
