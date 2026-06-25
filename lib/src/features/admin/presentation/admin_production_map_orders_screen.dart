import 'dart:async';
import 'dart:convert';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/forms/forms.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../aparatchi/presentation/widgets/aparatchi_dock.dart';
import '../../aparatchi/presentation/widgets/aparatchi_navigation_drawer.dart';
import '../../gscale/gscale_mobile_app.dart'
    show
        DiscoveredServer,
        discoverServers,
        discoverServersFast,
        driverUrlForRs,
        loadLastUsedServer,
        printTargetLabel;
import '../logic/apparatus_queue_state.dart';
import '../logic/production_map_chain.dart';
import '../logic/production_map_pechat_rules.dart';
import '../models/production_map_models.dart';
import '../state/calculate_order_store.dart';
import '../../shared/models/app_models.dart';
import 'raw_material_scan_dialog.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_drawer_navigation.dart';
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
part 'admin_production_map_orders_search_field.dart';
part 'admin_production_map_orders_opened_widgets.dart';
part 'admin_production_map_orders_completion_widgets.dart';
part 'admin_production_map_orders_sequence_widgets.dart';
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

enum _OpenedOrderModule { orders, move, sequence, closed }

const double _openedOrderPanelCardGap = 4;
const double _openedOrderPanelTopGap = 8;

class AdminProductionMapOrdersScreen extends StatefulWidget {
  const AdminProductionMapOrdersScreen({
    super.key,
    this.readOnly = false,
    this.workerMode = false,
    this.progressDriverUrlPicker,
  });

  final bool readOnly;
  final bool workerMode;
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
  AdminWarehouse? _selectedApparatus;
  AdminWarehouse? _moveTopApparatus;
  AdminWarehouse? _moveBottomApparatus;
  final Set<String> _selectedMoveOrderIds = {};
  List<ProductionMapSaved> _draggingMoveOrders = const [];
  AdminWarehouse? _draggingMoveSource;
  List<ProductionMapSaved> _orders = const [];
  List<AdminWarehouse> _apparatus = const [];
  final Map<String, List<String>> _sequenceByApparatus = {};
  final Map<String, Map<String, String>> _queueStatesByApparatus = {};
  final Map<String, AdminApparatusQueuePolicy> _queuePoliciesByApparatus = {};
  List<AdminCompletedQueueOrder> _completedWorkerOrders = const [];
  List<AdminCompletionRequestNotification> _completionRequests = const [];
  final Set<String> _shownCompletionDecisionIds = {};
  List<AdminClosedProductionOrder> _closedOrders = const [];
  bool _queueActionInFlight = false;
  Map<String, double> _baseMetrajByMapId = const {};
  Map<String, double> _orderKgByMapId = const {};

  @override
  void initState() {
    super.initState();
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
    return widget.workerMode
        ? const [_OpenedOrderModule.sequence]
        : _OpenedOrderModule.values;
  }

  void _recreateWorkerTabController(List<AdminWarehouse> apparatus) {
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
    final apparatusKey = request.apparatus.warehouse.trim();
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
        completionRequestNote: request.completionRequestNote,
        result: result,
      );
      return result;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      showAdminTopNotice(
        context,
        _queueActionErrorText(error),
      );
      return null;
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
    required String completionRequestNote,
    required AdminApparatusQueueActionResult result,
  }) {
    setState(() {
      _queueStatesByApparatus[apparatusKey] = result.states;
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
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _showOrderDetail(ProductionMapSaved order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReadOnlyOrderDetailSheet(order: order),
    );
  }

  void _showWatchOrderDetail({
    required AdminWarehouse apparatus,
    required ProductionMapSaved order,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReadOnlyOrderDetailSheet(
        order: order,
        apparatus: apparatus,
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
      ),
    );
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
  }

  Future<void> _pickSequenceApparatus() async {
    if (_apparatus.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<AdminWarehouse>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ApparatusPickerSheet(
        apparatus: _apparatus,
        selected: _selectedApparatus,
        orderCountFor: (apparatus) => _ordersForApparatus(apparatus).length,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _selectedApparatus = picked);
  }

  void _syncModuleFromTab() {
    final module = _modules[_tabController.index];
    if (_module != module) {
      setState(() => _module = module);
    }
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminWarehouse apparatus) {
    return _productionMapOrdersForApparatus(
      orders: _orders,
      apparatus: apparatus,
      sequenceByApparatus: _sequenceByApparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
      workerMode: widget.workerMode,
      query: _searchQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      drawer: widget.workerMode
          ? AparatchiNavigationDrawer(
              selectedIndex: 0,
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
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      titleWidget: _OpenedOrderSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) => setState(() => _searchQuery = value),
        onClear: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      ),
      bottom: widget.workerMode
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
              ? Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _loadError = null;
                      });
                      unawaited(_load());
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(_loadError!),
                  ),
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
                      queueStatesByApparatus: _queueStatesByApparatus,
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
                      baseMetrajByMapId: _baseMetrajByMapId,
                      orderKgByMapId: _orderKgByMapId,
                      selectedApparatus: _selectedApparatus,
                      completionRequests: _completionRequests,
                      readOnly: widget.readOnly,
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
                      onPickSequenceApparatus: _pickSequenceApparatus,
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
                    ),
    );
  }
}
