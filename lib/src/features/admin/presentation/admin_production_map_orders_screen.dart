import 'dart:async';
import 'dart:convert';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import '../../../core/widgets/display/app_info_row.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../aparatchi/presentation/widgets/aparatchi_navigation_drawer.dart';
import '../../boyoqchi/models/returned_paint_models.dart';
import '../../boyoqchi/presentation/widgets/returned_paint_sheet.dart';
import '../../boyoqchi/state/returned_paint_draft_store.dart';
import '../../gscale/gscale_mobile_app.dart'
    show DiscoveredServer, driverUrlForRs, showPrintDevicePicker;
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../qolip/presentation/widgets/qolip_dock.dart';
import '../../qolip/presentation/widgets/qolip_navigation_drawer.dart';
import '../logic/apparatus_queue_state.dart';
import '../logic/production_map_chain.dart';
import '../logic/production_map_pechat_rules.dart';
import '../models/production_map_models.dart';
import '../state/calculate_order_store.dart';
import '../../shared/models/app_models.dart';
import 'raw_material_scan_dialog.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_catalog_search_field.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_top_notice.dart';
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
part 'admin_production_map_orders_apparatus_picker.dart';
part 'admin_production_map_orders_opened_widgets.dart';
part 'admin_production_map_orders_completion_widgets.dart';
part 'admin_production_map_orders_sequence_widgets.dart';
part 'admin_production_map_orders_sequence_assignment_sheet.dart';
part 'admin_production_map_orders_move_module.dart';
part 'admin_production_map_orders_progress_printer.dart';
part 'admin_production_map_orders_progress_qty.dart';
part 'admin_production_map_orders_module_pages.dart';
part 'admin_production_map_orders_models.dart';
part 'admin_production_map_orders_calculation_helpers.dart';
part 'admin_production_map_orders_read_only_helpers.dart';
part 'admin_production_map_orders_move_helpers.dart';
part 'admin_production_map_orders_queue_helpers.dart';
part 'admin_production_map_orders_search_helpers.dart';
part 'admin_production_map_orders_worker_helpers.dart';
part 'admin_production_map_orders_apparatus_helpers.dart';
part 'admin_production_map_orders_live_helpers.dart';

enum _OpenedOrderModule { orders, move, sequence, closed, audit }

const double _openedOrderPanelCardGap = 4;
const double _openedOrderPanelTopGap = 8;

Future<bool> showProductionMapFreezePauseFlow(
  BuildContext context, {
  required String requestId,
  required String orderId,
  required String apparatus,
}) async {
  final normalizedRequestId = requestId.trim();
  final normalizedOrderId = orderId.trim();
  final normalizedApparatus = apparatus.trim();
  if (normalizedRequestId.isEmpty ||
      normalizedOrderId.isEmpty ||
      normalizedApparatus.isEmpty) {
    throw const MobileApiException(
      code: 'order_freeze_request_invalid',
      message: 'Muzlatish so‘rovi ma’lumotlari to‘liq emas',
    );
  }
  final results = await Future.wait<Object>([
    MobileApi.instance.adminProductionMap(normalizedOrderId),
    MobileApi.instance.adminProductionMapQueueSnapshot(),
  ]);
  if (!context.mounted) return false;
  final order = results[0] as ProductionMapSaved;
  final snapshot = results[1] as AdminApparatusQueueSnapshot;
  final target = AdminApparatus(name: normalizedApparatus);
  List<String> visibleOrderIds = const <String>[];
  for (final entry in snapshot.visibleOrderIds.entries) {
    if (productionMapWarehouseTitlesMatch(entry.key, normalizedApparatus)) {
      visibleOrderIds = entry.value;
      break;
    }
  }
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _ReadOnlyOrderDetailSheet(
      order: order,
      apparatus: target,
      canManageQueue: true,
      initialQueueStates: _queueStatesForApparatus(
        target,
        queueStatesByApparatus: snapshot.queueStates,
      ),
      queueStatesByApparatus: snapshot.queueStates,
      queuePolicy: _queuePolicyForApparatus(
        target,
        queuePoliciesByApparatus: snapshot.queuePolicies,
      ),
      sequenceOrderIds: _sequenceOrderIdsForApparatus(
        target,
        sequenceByApparatus: snapshot.sequences,
      ),
      visibleOrderIds: visibleOrderIds,
      onQueueAction: (request) => _submitAdminApparatusQueueAction(
        request,
        apparatusKey: request.apparatus.name.trim(),
      ),
      initialOrderControls: snapshot.orderControls,
      initialPauseRequestId: normalizedRequestId,
      startPauseOnOpen: true,
    ),
  );
  return result ?? false;
}

class AdminProductionMapOrdersScreen extends StatefulWidget {
  const AdminProductionMapOrdersScreen({
    super.key,
    this.readOnly = false,
    this.workerMode = false,
    this.supplyViewerMode = false,
    this.progressDriverUrlPicker,
  }) : assert(!(workerMode && supplyViewerMode));

  final bool readOnly;
  final bool workerMode;
  final bool supplyViewerMode;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<AdminProductionMapOrdersScreen> createState() =>
      _AdminProductionMapOrdersScreenState();
}

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
  int _liveStreamGeneration = 0;
  StreamSubscription<AdminProductionMapLiveSnapshot>? _liveStreamSubscription;
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
  final Map<String, AdminApparatusQueuePolicy> _queuePoliciesByApparatus = {};
  final Map<String, AdminOrderControlState> _orderControlsByOrderId = {};
  final Map<String, AdminProductionOrderStatusDetail> _orderStatusesByOrderId =
      {};
  List<AdminCompletedQueueOrder> _completedWorkerOrders = const [];
  List<AdminCompletionRequestNotification> _completionRequests = const [];
  final Set<String> _shownCompletionDecisionIds = {};
  List<AdminClosedProductionOrder> _closedOrders = const [];
  AdminProductionWorkflowAuditReport? _workflowAudit;
  String? _workflowAuditError;
  bool _workflowAuditLoading = false;
  bool _queueActionInFlight = false;
  bool _orderControlActionInFlight = false;
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

  void _updateScreenState(VoidCallback callback) {
    setState(callback);
  }

  List<_OpenedOrderModule> get _modules {
    return widget.workerMode || widget.supplyViewerMode
        ? const [_OpenedOrderModule.sequence]
        : _OpenedOrderModule.values;
  }

  void _recreateWorkerTabController(List<AdminApparatus> apparatus) {
    final length = _workerWatchTabCount(apparatus);
    if (_tabController.length == length) {
      return;
    }
    _tabController.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: 0,
    );
  }

  Future<AdminApparatusQueueActionResult?> _handleQueueAction(
    _ReadOnlyQueueActionRequest request,
  ) async {
    if (_queueActionInFlight) {
      return null;
    }
    final apparatusKey = request.apparatus.name.trim();
    _setQueueActionInFlight(true);
    try {
      final result = await _submitAdminApparatusQueueAction(
        request,
        apparatusKey: apparatusKey,
      );
      if (!mounted) {
        return null;
      }
      _applyQueueActionResult(
        apparatusKey: apparatusKey,
        orderId: request.order.map.id.trim(),
        completionRequestNote: request.completionRequestNote,
        result: result,
      );
      return result;
    } finally {
      _setQueueActionInFlight(false);
    }
  }

  void _setQueueActionInFlight(bool value) {
    _queueActionInFlight = value;
    if (mounted) {
      setState(() {});
    }
  }

  void _applyQueueActionResult({
    required String apparatusKey,
    required String orderId,
    required String completionRequestNote,
    required AdminApparatusQueueActionResult result,
  }) {
    setState(() {
      _queueStatesByApparatus[apparatusKey] = result.states;
      _orderStatusesByOrderId[orderId] = result.orderStatus;
    });
    if (_queueActionSentCompletionRequest(
      completionRequestNote: completionRequestNote,
      result: result,
    )) {
      showAdminTopNotice(context, 'Tugatish so‘rovi adminga yuborildi');
    }
    unawaited(_refreshLive());
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    if (widget.supplyViewerMode) {
      Navigator.of(context).pushReplacementNamed(routeName);
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _showOrderDetail(ProductionMapSaved order) {
    final mapId = order.map.id.trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReadOnlyOrderDetailSheet(
        order: order,
        baseMetraj: _baseMetrajByMapId[mapId] ?? order.map.baseLength,
        orderKg: _orderKgByMapId[mapId] ?? order.map.orderKg,
        customerName: _customerByMapId[mapId] ?? order.map.customerName,
        queueStatesByApparatus: _queueStatesByApparatus,
        initialOrderControls: _orderControlsByOrderId,
      ),
    );
  }

  void _showWatchOrderDetail({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) {
    final mapId = order.map.id.trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReadOnlyOrderDetailSheet(
        order: order,
        apparatus: apparatus,
        customerName: _customerByMapId[mapId] ?? order.map.customerName,
        canManageQueue: _isAssignedWatchApparatus(
          apparatus,
          assignedApparatus: AppSession.instance.profile?.assignedApparatus ??
              const <String>[],
        ),
        initialQueueStates: _queueStatesForApparatus(
          apparatus,
          queueStatesByApparatus: _queueStatesByApparatus,
        ),
        queueStatesByApparatus: _queueStatesByApparatus,
        queuePolicy: _queuePolicyForApparatus(
          apparatus,
          queuePoliciesByApparatus: _queuePoliciesByApparatus,
        ),
        sequenceOrderIds: _sequenceOrderIdsForApparatus(
          apparatus,
          sequenceByApparatus: _sequenceByApparatus,
        ),
        visibleOrderIds: _ordersForApparatus(
          apparatus,
        ).map((item) => item.map.id).toList(growable: false),
        onQueueAction: _handleQueueAction,
        progressDriverUrlPicker: widget.progressDriverUrlPicker,
        initialOrderControls: _orderControlsByOrderId,
      ),
    );
  }

  Future<void> _showSupplyRawMaterialAssignment(
    ProductionMapSaved order,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SequenceRawMaterialAssignmentSheet(
        order: order,
      ),
    );
  }

  Future<void> _showOrderActions(ProductionMapSaved order) async {
    if (widget.readOnly ||
        widget.workerMode ||
        widget.supplyViewerMode ||
        _orderControlActionInFlight) {
      return;
    }
    final orderId = order.map.id.trim();
    final control =
        _orderControlsByOrderId[orderId] ?? AdminOrderControlState.active;
    final action = await showModalBottomSheet<AdminOrderControlAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (control == AdminOrderControlState.active) ...[
              ListTile(
                leading: const Icon(Icons.ac_unit_rounded),
                title: const Text('Muzlatish'),
                onTap: () => Navigator.pop(
                  context,
                  AdminOrderControlAction.freeze,
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'O‘chirish',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  AdminOrderControlAction.delete,
                ),
              ),
            ],
            if (control == AdminOrderControlState.freezeRequested)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Muzlatish so‘rovini bekor qilish'),
                onTap: () => Navigator.pop(
                  context,
                  AdminOrderControlAction.cancelFreeze,
                ),
              ),
            if (control == AdminOrderControlState.frozen)
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: const Text('Muzdan chiqarish'),
                onTap: () => Navigator.pop(
                  context,
                  AdminOrderControlAction.unfreeze,
                ),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == AdminOrderControlAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Buyurtmani o‘chirish'),
          content: const Text(
            'Bu amal buyurtmani butunlay o‘chiradi. Server ish '
            'boshlanganini, navbatdagi 1-o‘rinni va biriktirilgan '
            'homashyoni qayta tekshiradi.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('O‘chirishni tasdiqlash'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Bekor qilish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await _runOrderControlAction(order, action);
  }

  Future<void> _runOrderControlAction(
    ProductionMapSaved order,
    AdminOrderControlAction action,
  ) async {
    final orderId = order.map.id.trim();
    setState(() => _orderControlActionInFlight = true);
    try {
      final next = await MobileApi.instance.adminProductionMapOrderControl(
        orderId: orderId,
        action: action,
      );
      if (!mounted) return;
      setState(() {
        if (action == AdminOrderControlAction.delete) {
          _orders = [
            for (final item in _orders)
              if (item.map.id.trim() != orderId) item,
          ];
          _orderControlsByOrderId.remove(orderId);
          for (final sequence in _sequenceByApparatus.values) {
            sequence.removeWhere((id) => id.trim() == orderId);
          }
        } else if (next != null) {
          _orderControlsByOrderId[orderId] = next;
        }
      });
      showAdminTopNotice(
        context,
        switch (action) {
          AdminOrderControlAction.freeze =>
            next == AdminOrderControlState.frozen
                ? 'Buyurtma muzlatildi'
                : 'Worker pauzasi kutilmoqda',
          AdminOrderControlAction.cancelFreeze =>
            'Muzlatish so‘rovi bekor qilindi',
          AdminOrderControlAction.unfreeze => 'Buyurtma aktiv holatga qaytdi',
          AdminOrderControlAction.delete => 'Buyurtma o‘chirildi',
        },
      );
      unawaited(_refreshLive());
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Buyurtma amali bajarilmadi',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _orderControlActionInFlight = false);
      }
    }
  }

  void _showCompletedOrderDetail(_WorkerCompletedOrderEntry entry) {
    final apparatus = entry.apparatus;
    if (apparatus == null) {
      _showOrderDetail(entry.order);
      return;
    }
    _showWatchOrderDetail(apparatus: apparatus, order: entry.order);
  }

  void _setModule(_OpenedOrderModule module) {
    if (_module != module) {
      setState(() => _module = module);
    }
    final index = _modules.indexOf(module);
    if (index < 0) {
      return;
    }
    if (_tabController.index != index) {
      _tabController.animateTo(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    if (module == _OpenedOrderModule.audit) {
      unawaited(_refreshWorkflowAudit());
    }
  }

  void _syncModuleFromTab() {
    final module = _modules[_tabController.index];
    if (_module != module) {
      setState(() => _module = module);
    }
    if (module == _OpenedOrderModule.audit) {
      unawaited(_refreshWorkflowAudit());
    }
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminApparatus apparatus) {
    return _productionMapOrdersForApparatus(
      orders: _orders,
      apparatus: apparatus,
      visibleOrderIdsByApparatus: _visibleOrderIdsByApparatus,
      sequenceByApparatus: _sequenceByApparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
      workerMode: widget.workerMode,
      query: _searchQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final role = AppSession.instance.profile?.role;
    final isMaterialTaminotchi = role == UserRole.materialTaminotchi;
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
            ? 'Ketma-ketlikdan zakaz qidirish'
            : 'Ochilgan zakaz qidirish',
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
              ? const AparatchiDock(activeTab: AparatchiDockTab.home)
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
              : widget.workerMode
                  ? _WorkerWatchBody(
                      apparatus: _apparatus,
                      assignedApparatus:
                          AppSession.instance.profile?.assignedApparatus ??
                              const <String>[],
                      orders: _orders,
                      completedOrders: _completedWorkerOrders,
                      sequenceByApparatus: _sequenceByApparatus,
                      visibleOrderIdsByApparatus: _visibleOrderIdsByApparatus,
                      queueStatesByApparatus: _queueStatesByApparatus,
                      orderStatusesByOrderId: _orderStatusesByOrderId,
                      orderControlsByOrderId: _orderControlsByOrderId,
                      searchQuery: _searchQuery,
                      bottomPadding: bottomPadding,
                      tabController: _tabController,
                      onTapCompletedOrder: _showCompletedOrderDetail,
                      onTapWatchOrder: _showWatchOrderDetail,
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
                      readOnly: widget.readOnly || widget.supplyViewerMode,
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
                          _reorderSelectedApparatusOrders(oldIndex, newIndex),
                        );
                      },
                      onPickMoveTop: () => _pickMoveApparatus(top: true),
                      onPickMoveBottom: () => _pickMoveApparatus(top: false),
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
                      onInfoSequenceOrder:
                          widget.supplyViewerMode && !isMaterialTaminotchi
                              ? null
                              : _showWatchOrderDetail,
                      customerNameByMapId: _customerByMapId,
                      queueStatesByApparatus: _queueStatesByApparatus,
                      orderStatusesByOrderId: _orderStatusesByOrderId,
                      orderControlsByOrderId: _orderControlsByOrderId,
                      workflowAudit: _workflowAudit,
                      workflowAuditError: _workflowAuditError,
                      workflowAuditLoading: _workflowAuditLoading,
                      onRefreshWorkflowAudit: () =>
                          _refreshWorkflowAudit(force: true),
                      onLongPressOrder: (order) {
                        unawaited(
                          widget.supplyViewerMode && isMaterialTaminotchi
                              ? _showSupplyRawMaterialAssignment(order)
                              : _showOrderActions(order),
                        );
                      },
                    ),
    );
  }
}

class _OpenedOrdersLoadErrorBody extends StatelessWidget {
  const _OpenedOrdersLoadErrorBody({
    required this.message,
    required this.bottomPadding,
    required this.onRefresh,
  });

  final String message;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      allowRefreshOnShortContent: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const TopRefreshScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
            children: [
              SizedBox(height: constraints.maxHeight * 0.42),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
