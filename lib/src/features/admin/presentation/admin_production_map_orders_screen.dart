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
  StreamSubscription<String>? _liveStreamSubscription;
  final http.Client _liveHttpClient = http.Client();
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
    _liveHttpClient.close();
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

  Future<void> _startWorkerLive() async {
    await _loadWorkerApparatus();
    if (!mounted) {
      return;
    }
    if (await TestModeController.instance.isEnabled()) {
      await _refreshLive(initial: true);
      return;
    }
    _stopWorkerLiveStream();
    _liveStreamGeneration++;
    unawaited(_runWorkerLiveStream(_liveStreamGeneration));
  }

  Future<void> _startAdminLive() async {
    await _refreshLive(initial: true);
    if (!mounted) {
      return;
    }
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    _stopWorkerLiveStream();
    _liveStreamGeneration++;
    unawaited(_runWorkerLiveStream(_liveStreamGeneration));
  }

  void _stopWorkerLiveStream() {
    _liveStreamGeneration++;
    final subscription = _liveStreamSubscription;
    _liveStreamSubscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> _runWorkerLiveStream(int generation) async {
    while (mounted && generation == _liveStreamGeneration) {
      try {
        await _connectWorkerLiveStreamOnce(generation);
      } catch (_) {
        if (!mounted || generation != _liveStreamGeneration) {
          return;
        }
        await _refreshLive(initial: _loading);
      }
      if (!mounted || generation != _liveStreamGeneration) {
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _connectWorkerLiveStreamOnce(int generation) async {
    final response = await _connectProductionMapLiveStream();
    await _liveStreamSubscription?.cancel();
    final connection = _productionMapLiveConnection(
      response: response,
      isActive: () => mounted && generation == _liveStreamGeneration,
      onSnapshot: _applyWorkerLiveSnapshot,
    );
    _liveStreamSubscription = connection.subscription;
    await connection.completed;
  }

  Future<void> _loadWorkerApparatus() async {
    final apparatus = await _loadProductionMapApparatus();
    if (!mounted) {
      return;
    }
    if (widget.workerMode &&
        _workerWatchTabCount(apparatus) != _tabController.length) {
      _recreateWorkerTabController(apparatus);
    }
    setState(() {
      _apparatus = apparatus;
    });
  }

  void _applyWorkerLiveSnapshot(AdminProductionMapLiveSnapshot snapshot) {
    final orders = _productionMapZakazOrders(snapshot.maps);
    final newRejectedDecisions = widget.workerMode
        ? _newRejectedCompletionRequestDecisions(
            decisions: snapshot.completionRequestDecisions,
            shownDecisionIds: _shownCompletionDecisionIds,
          )
        : const <AdminCompletionRequestDecisionNotification>[];
    setState(() {
      _orders = orders;
      _sequenceByApparatus
        ..clear()
        ..addAll(snapshot.sequences);
      _queueStatesByApparatus
        ..clear()
        ..addAll(snapshot.queueStates);
      _queuePoliciesByApparatus
        ..clear()
        ..addAll(snapshot.queuePolicies);
      _completedWorkerOrders = snapshot.completedOrders;
      _completionRequests = snapshot.completionRequests;
      _loading = false;
    });
    for (final decision in newRejectedDecisions) {
      _shownCompletionDecisionIds.add(decision.eventId.trim());
      showAdminTopNotice(
        context,
        _completionRejectedNoticeText(decision),
      );
    }
  }

  Future<void> _refreshLive({bool initial = false}) async {
    if (_liveRefreshInFlight) {
      _liveRefreshQueued = true;
      return;
    }
    _liveRefreshInFlight = true;
    var runInitial = initial;
    try {
      while (mounted) {
        _liveRefreshQueued = false;
        await _refreshLiveBatch(initial: runInitial);
        if (!_liveRefreshQueued) {
          return;
        }
        runInitial = false;
      }
    } finally {
      _liveRefreshInFlight = false;
    }
  }

  Future<void> _refreshLiveBatch({required bool initial}) {
    return widget.workerMode
        ? _refreshWorkerLiveBatch(initial: initial)
        : _refreshAdminLiveBatch(initial: initial);
  }

  Future<void> _refreshWorkerLiveBatch({required bool initial}) async {
    await _refreshMapsAndApparatus(initial: initial);
    await _refreshQueueSnapshot();
    await _refreshWorkerCompletedOrders();
    await _refreshWorkerCompletionRequestDecisions();
  }

  Future<void> _refreshAdminLiveBatch({required bool initial}) {
    return Future.wait([
      _refreshMapsAndApparatus(initial: initial),
      _refreshQueueSnapshot(),
      _refreshCompletionRequests(),
      _refreshClosedOrders(),
    ]);
  }

  Future<void> _refreshQueueSnapshot() async {
    try {
      final queueSnapshot = await _loadQueueSnapshot();
      if (!mounted) {
        return;
      }
      if (!_queueSnapshotChanged(
        snapshot: queueSnapshot,
        sequenceByApparatus: _sequenceByApparatus,
        queueStatesByApparatus: _queueStatesByApparatus,
        queuePoliciesByApparatus: _queuePoliciesByApparatus,
      )) {
        return;
      }
      setState(() {
        _sequenceByApparatus
          ..clear()
          ..addAll(queueSnapshot.sequences);
        _queueStatesByApparatus
          ..clear()
          ..addAll(queueSnapshot.queueStates);
        _queuePoliciesByApparatus
          ..clear()
          ..addAll(queueSnapshot.queuePolicies);
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshWorkerCompletedOrders() async {
    if (!_shouldRefreshWorkerOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final completed = await _loadCompletedProductionMapOrders();
      if (!mounted) {
        return;
      }
      setState(() {
        _completedWorkerOrders = completed;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshWorkerCompletionRequestDecisions() async {
    if (!_shouldRefreshWorkerOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final decisions = await _loadProductionMapCompletionRequestDecisions();
      if (!mounted) {
        return;
      }
      final newRejectedDecisions = _newRejectedCompletionRequestDecisions(
        decisions: decisions,
        shownDecisionIds: _shownCompletionDecisionIds,
      );
      for (final decision in newRejectedDecisions) {
        _shownCompletionDecisionIds.add(decision.eventId.trim());
        showAdminTopNotice(
          context,
          _completionRejectedNoticeText(decision),
        );
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshClosedOrders() async {
    if (!_shouldRefreshAdminOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final closed = await _loadClosedProductionMapOrders();
      if (!mounted) {
        return;
      }
      setState(() {
        _closedOrders = closed;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshCompletionRequests() async {
    if (!_shouldRefreshAdminOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final requests = await _loadProductionMapCompletionRequests();
      if (!mounted) {
        return;
      }
      setState(() {
        _completionRequests = requests;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshMapsAndApparatus({bool initial = false}) async {
    if (!initial && _mapsRefreshInFlight) {
      return;
    }
    if (!initial) {
      _mapsRefreshInFlight = true;
    }
    try {
      final loaded = await _loadProductionMapOrdersAndApparatus();
      if (!mounted) {
        return;
      }
      final orders = loaded.orders;
      final apparatus = loaded.apparatus;
      if (!initial &&
          !_productionMapOrdersOrApparatusChanged(
            currentOrders: _orders,
            nextOrders: orders,
            currentApparatus: _apparatus,
            nextApparatus: apparatus,
          )) {
        return;
      }
      if (widget.workerMode &&
          (initial ||
              _workerWatchTabCount(apparatus) != _tabController.length)) {
        _recreateWorkerTabController(apparatus);
      }
      setState(() {
        _loadError = null;
        _orders = orders;
        _apparatus = apparatus;
        if (!widget.workerMode) {
          _selectedApparatus ??= apparatus.isEmpty ? null : apparatus.first;
          _syncMoveApparatusDefaults(apparatus);
        }
        if (initial) {
          _loading = false;
        }
      });
      unawaited(_refreshOrderBaseMetraj(orders));
    } catch (_) {
      if (mounted && initial) {
        setState(() {
          _loading = false;
          _loadError = 'Reja menu yuklanmadi';
        });
      }
    } finally {
      _mapsRefreshInFlight = false;
    }
  }

  Future<void> _refreshOrderBaseMetraj(List<ProductionMapSaved> orders) async {
    try {
      await CalculateOrderTemplateStore.instance.load(force: true);
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    final templates = CalculateOrderTemplateStore.instance.templates;
    final metrics = await _productionMapOrderMetrics(orders, templates);
    if (!mounted) {
      return;
    }
    setState(() {
      _baseMetrajByMapId = metrics.baseMetrajByMapId;
      _orderKgByMapId = metrics.orderKgByMapId;
    });
  }

  Future<void> _load() => _refreshLive(initial: true);

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

  Future<AdminApparatusQueueActionResult?> _handleQueueAction({
    required AdminWarehouse apparatus,
    required ProductionMapSaved order,
    required String action,
    List<String> materialBarcodes = const [],
    double? producedQty,
    double? grossQty,
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String driverUrl = '',
    String completionRequestNote = '',
  }) async {
    if (_queueActionInFlight) {
      return null;
    }
    final apparatusKey = apparatus.warehouse.trim();
    _queueActionInFlight = true;
    setState(() {});
    try {
      final result = await _submitAdminApparatusQueueAction(
        apparatus: apparatusKey,
        orderId: order.map.id,
        action: action,
        materialBarcodes: materialBarcodes,
        producedQty: producedQty,
        grossQty: grossQty,
        returnInkKg: returnInkKg,
        laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
        laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
        rezkaBosmaWaste: rezkaBosmaWaste,
        rezkaLaminationWaste: rezkaLaminationWaste,
        rezkaEdgeWaste: rezkaEdgeWaste,
        totalWaste: totalWaste,
        finishedGoodsKg: finishedGoodsKg,
        finishedGoodsMeter: finishedGoodsMeter,
        uom: uom,
        qrPayload: qrPayload,
        progressBatchId: progressBatchId,
        driverUrl: driverUrl,
        completionRequestNote: completionRequestNote,
      );
      if (!mounted) {
        return null;
      }
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
      _queueActionInFlight = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _syncMoveApparatusDefaults(List<AdminWarehouse> source) {
    final defaults = _moveApparatusDefaults(
      source: source,
      currentTop: _moveTopApparatus,
      currentBottom: _moveBottomApparatus,
    );
    _moveTopApparatus = defaults.top;
    _moveBottomApparatus = defaults.bottom;
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

  List<ProductionMapSaved> _moveOrdersForApparatus({
    required AdminWarehouse source,
    required AdminWarehouse target,
  }) {
    if (_isMoveUnassignedApparatus(source)) {
      if (_isMoveUnassignedApparatus(target)) {
        return const [];
      }
      return _alternativeOrdersForApparatus(target);
    }
    if (_isMoveUnassignedApparatus(target)) {
      return _ordersForApparatus(source);
    }
    return _ordersForApparatus(source)
        .where(
          (order) => _canMoveOrderToApparatus(order, target, source: source),
        )
        .toList(growable: false);
  }

  Future<void> _reorderSelectedApparatusOrders(
    int oldIndex,
    int newIndex,
  ) async {
    if (widget.readOnly) {
      return;
    }
    final apparatus = _selectedApparatus;
    if (apparatus == null) {
      return;
    }
    final orders = List<ProductionMapSaved>.from(
      _ordersForApparatus(apparatus),
    );
    if (oldIndex == newIndex) {
      return;
    }
    final previousOrderIds =
        orders.map((order) => order.map.id).toList(growable: false);
    final moved = orders.removeAt(oldIndex);
    orders.insert(newIndex, moved);
    final apparatusKey = apparatus.warehouse.trim();
    final orderIds =
        orders.map((order) => order.map.id).toList(growable: false);
    setState(() {
      _sequenceByApparatus[apparatusKey] = orderIds;
    });
    await _persistApparatusSequence(
      apparatus: apparatusKey,
      orderIds: orderIds,
      previousOrderIds: previousOrderIds,
    );
  }

  Future<void> _persistApparatusSequence({
    required String apparatus,
    required List<String> orderIds,
    required List<String> previousOrderIds,
  }) async {
    try {
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: apparatus,
        orderIds: orderIds,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sequenceByApparatus[apparatus] = previousOrderIds;
      });
      showAdminTopNotice(
        context,
        _adminActionErrorText(error, 'Ketma-ketlik saqlanmadi'),
      );
    }
  }

  void _toggleMoveOrderSelection(String orderId) {
    if (widget.readOnly) {
      return;
    }
    final normalized = orderId.trim();
    setState(() {
      if (_selectedMoveOrderIds.contains(normalized)) {
        _selectedMoveOrderIds.remove(normalized);
      } else {
        _selectedMoveOrderIds.add(normalized);
      }
    });
  }

  _MoveDragPayload _buildMoveDragPayload({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) {
    return _moveDragPayload(
      order: order,
      source: source,
      zoneOrders: zoneOrders,
      selectedOrderIds: _selectedMoveOrderIds,
    );
  }

  Future<void> _moveOrdersBetweenApparatus({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) async {
    if (_isMoveUnassignedApparatus(from) && !_isMoveUnassignedApparatus(to)) {
      await _assignAlternativeOrdersToApparatus(orders: orders, apparatus: to);
      return;
    }
    if (!_isMoveUnassignedApparatus(from) && _isMoveUnassignedApparatus(to)) {
      await _returnOrdersToUnassigned(orders: orders, source: from);
      return;
    }
    if (widget.readOnly ||
        from.warehouse.trim() == to.warehouse.trim() ||
        _isMoveUnassignedApparatus(from) ||
        _isMoveUnassignedApparatus(to) ||
        orders.isEmpty) {
      return;
    }
    final blocked = orders.any(
      (order) => !_canMoveOrderToApparatus(order, to, source: from),
    );
    if (blocked) {
      showAdminTopNotice(context, 'Tanlangan zakazlar bu aparatga tushmaydi');
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    setState(() {
      _draggingMoveOrders = const [];
      _draggingMoveSource = null;
    });
    try {
      final saved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
        mapIds: orders.map((order) => order.map.id).toList(growable: false),
        fromApparatus: from.warehouse,
        toApparatus: to.warehouse,
      );
      if (!mounted) {
        return;
      }
      final savedById = _savedProductionMapOrdersByIdOrThrow(
        saved: saved,
        expectedOrderIds: orderIds,
        incompleteMessage: 'Zakazlar to‘liq ko‘chirilmadi',
      );
      setState(() {
        _selectedMoveOrderIds.removeAll(orderIds);
        _orders = _mergeSavedProductionMapOrders(_orders, savedById);
      });
      showAdminTopNotice(context, _moveOrdersSuccessText(orders.length));
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        _adminActionErrorText(error, 'Zakaz ko‘chirilmadi'),
      );
      // Some orders may already be moved on the server; re-sync instead of
      // restoring a stale local state.
      await _load();
    }
  }

  Future<void> _returnOrdersToUnassigned({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse source,
  }) async {
    if (widget.readOnly || orders.isEmpty) {
      return;
    }
    final convertedMaps = _returnAssignedMapsToAlternatives(
      orders: orders,
      source: source,
    );
    if (convertedMaps == null) {
      showAdminTopNotice(context, 'Bu zakaz tanlanmagan holatga qaytmaydi');
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    setState(() {
      _draggingMoveOrders = const [];
      _draggingMoveSource = null;
    });
    try {
      final saved = await _saveProductionMapDefinitions(convertedMaps);
      if (!mounted) {
        return;
      }
      final savedById = _savedProductionMapOrdersByIdOrThrow(
        saved: saved,
        expectedOrderIds: orderIds,
        incompleteMessage: 'Zakazlar to‘liq tanlanmagan holatga qaytmadi',
      );
      setState(() {
        _selectedMoveOrderIds.removeAll(orderIds);
        _orders = _mergeSavedProductionMapOrders(_orders, savedById);
      });
      showAdminTopNotice(
        context,
        _returnOrdersToUnassignedSuccessText(orders.length),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        _adminActionErrorText(error, 'Zakaz tanlanmagan holatga qaytmadi'),
      );
      await _load();
    }
  }

  Future<void> _assignAlternativeOrdersToApparatus({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse apparatus,
  }) async {
    if (widget.readOnly || orders.isEmpty) {
      return;
    }
    final blocked = orders.any(
      (order) => !_isAlternativeOrderForApparatus(order, apparatus),
    );
    if (blocked) {
      showAdminTopNotice(context, 'Tanlangan zakazlar bu aparatga tushmaydi');
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    setState(() {
      _draggingMoveOrders = const [];
      _draggingMoveSource = null;
    });
    try {
      final assignedMaps = _assignAlternativeMapsToApparatus(
        orders: orders,
        apparatus: apparatus,
      );
      final saved = await _saveProductionMapDefinitions(assignedMaps);
      if (!mounted) {
        return;
      }
      final savedById = _savedProductionMapOrdersByIdOrThrow(
        saved: saved,
        expectedOrderIds: orderIds,
        incompleteMessage: 'Zakazlar to‘liq biriktirilmadi',
      );
      setState(() {
        _selectedMoveOrderIds.removeAll(orderIds);
        _orders = _mergeSavedProductionMapOrders(_orders, savedById);
      });
      showAdminTopNotice(
        context,
        _assignAlternativeOrdersSuccessText(orders.length),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        _adminActionErrorText(error, 'Zakaz biriktirilmadi'),
      );
      await _load();
    }
  }

  Future<void> _pickMoveApparatus({required bool top}) async {
    final anchor = top ? _moveBottomApparatus : _moveTopApparatus;
    final pickerApparatus = _movePickerApparatusOptions(anchor);
    final unassignedOrderCount =
        anchor == null || _isMoveUnassignedApparatus(anchor)
            ? 0
            : _alternativeOrdersForApparatus(anchor).length;
    final picked = await showModalBottomSheet<AdminWarehouse>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ApparatusPickerSheet(
        apparatus: pickerApparatus,
        selected: top ? _moveTopApparatus : _moveBottomApparatus,
        orderCountFor: (apparatus) => _ordersForApparatus(apparatus).length,
        showUnassigned: anchor != null && !_isMoveUnassignedApparatus(anchor),
        unassignedOrderCount: unassignedOrderCount,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (top) {
        _moveTopApparatus = picked;
      } else {
        _moveBottomApparatus = picked;
      }
    });
  }

  List<AdminWarehouse> _movePickerApparatusOptions(
    AdminWarehouse? oppositeApparatus,
  ) {
    return _movePickerApparatusOptionsForList(
      apparatus: _apparatus,
      oppositeApparatus: oppositeApparatus,
    );
  }

  List<ProductionMapSaved> _alternativeOrdersForApparatus(
    AdminWarehouse apparatus,
  ) {
    return _alternativeOrdersForApparatusList(
      orders: _orders,
      apparatus: apparatus,
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
                  ? _buildWorkerWatchBody(bottomPadding)
                  : Column(
                      children: [
                        if (_modules.length > 1)
                          Material(
                            color:
                                Theme.of(context).colorScheme.surfaceContainer,
                            child: TabBar(
                              controller: _tabController,
                              onTap: (index) => _setModule(_modules[index]),
                              tabs: [
                                for (final module in _modules)
                                  Tab(height: 38, text: _moduleLabel(module)),
                              ],
                            ),
                          ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              for (final module in _modules)
                                switch (module) {
                                  _OpenedOrderModule.orders =>
                                    _OrdersModulePage(
                                      bottomPadding: bottomPadding,
                                      orders: _orders,
                                      visibleOrders: _visibleOrders(
                                        orders: _orders,
                                        query: _searchQuery,
                                      ),
                                      baseMetrajByMapId: _baseMetrajByMapId,
                                      orderKgByMapId: _orderKgByMapId,
                                    ),
                                  _OpenedOrderModule.sequence =>
                                    _SequenceModulePage(
                                      bottomPadding: bottomPadding,
                                      apparatus: _selectedApparatus,
                                      completionRequests: _completionRequests,
                                      orders: _selectedApparatus == null
                                          ? const []
                                          : _ordersForApparatus(
                                              _selectedApparatus!,
                                            ),
                                      readOnly: widget.readOnly,
                                      baseMetrajByMapId: _baseMetrajByMapId,
                                      orderKgByMapId: _orderKgByMapId,
                                      onPickApparatus: _pickSequenceApparatus,
                                      onReorder: (oldIndex, newIndex) {
                                        unawaited(
                                          _reorderSelectedApparatusOrders(
                                            oldIndex,
                                            newIndex,
                                          ),
                                        );
                                      },
                                    ),
                                  _OpenedOrderModule.move => _MoveModulePage(
                                      topApparatus: _moveTopApparatus,
                                      bottomApparatus: _moveBottomApparatus,
                                      topOrders: _moveTopApparatus == null ||
                                              _moveBottomApparatus == null
                                          ? const []
                                          : _moveOrdersForApparatus(
                                              source: _moveTopApparatus!,
                                              target: _moveBottomApparatus!,
                                            ),
                                      bottomOrders: _moveTopApparatus == null ||
                                              _moveBottomApparatus == null
                                          ? const []
                                          : _moveOrdersForApparatus(
                                              source: _moveBottomApparatus!,
                                              target: _moveTopApparatus!,
                                            ),
                                      selectedOrderIds: _selectedMoveOrderIds,
                                      draggingOrders: _draggingMoveOrders,
                                      draggingSource: _draggingMoveSource,
                                      canMoveTo: (order, target, source) =>
                                          _canMoveOrderToApparatus(
                                        order,
                                        target,
                                        source: source,
                                      ),
                                      onPickTop: () =>
                                          _pickMoveApparatus(top: true),
                                      onPickBottom: () =>
                                          _pickMoveApparatus(top: false),
                                      onToggleSelect: _toggleMoveOrderSelection,
                                      buildDragPayload: _buildMoveDragPayload,
                                      onDragStarted: (payload) {
                                        setState(() {
                                          _draggingMoveOrders = payload.orders;
                                          _draggingMoveSource = payload.source;
                                        });
                                      },
                                      onDragEnded: () {
                                        setState(() {
                                          _draggingMoveOrders = const [];
                                          _draggingMoveSource = null;
                                        });
                                      },
                                      onMove: _moveOrdersBetweenApparatus,
                                    ),
                                  _OpenedOrderModule.closed =>
                                    _ClosedOrdersModulePage(
                                      bottomPadding: bottomPadding,
                                      closedOrders: _closedOrders,
                                      visibleClosedOrders: _visibleClosedOrders(
                                        orders: _closedOrders,
                                        query: _searchQuery,
                                      ),
                                    ),
                                },
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildWorkerWatchBody(double bottomPadding) {
    if (_apparatus.isEmpty) {
      return const Center(
        child: _EmptyOpenedOrders(message: 'Aparatlar topilmadi'),
      );
    }
    final tabs = _workerWatchTabs(
      apparatus: _apparatus,
      assignedApparatus:
          AppSession.instance.profile?.assignedApparatus ?? const <String>[],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              for (final tab in tabs)
                Tab(height: 38, text: _workerWatchTabLabel(tab)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final tab in tabs)
                if (tab.isCompleted)
                  _AparatchiCompletedOrdersPage(
                    orders: _workerCompletedOrders(
                      orders: _orders,
                      completedOrders: _completedWorkerOrders,
                      apparatus: _apparatus,
                      query: _searchQuery,
                    ),
                    bottomPadding: bottomPadding,
                    onTapOrder: _showCompletedOrderDetail,
                  )
                else
                  _AparatchiWatchSequencePage(
                    apparatus: tab.apparatus!,
                    orders: _ordersForApparatus(tab.apparatus!),
                    bottomPadding: bottomPadding,
                    isAssigned: _isAssignedWatchApparatus(
                      tab.apparatus!,
                      assignedApparatus:
                          AppSession.instance.profile?.assignedApparatus ??
                              const <String>[],
                    ),
                    queueStates: _queueStatesForApparatus(
                      tab.apparatus!,
                      queueStatesByApparatus: _queueStatesByApparatus,
                    ),
                    onTapOrder: (order) => _showWatchOrderDetail(
                      apparatus: tab.apparatus!,
                      order: order,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  String _moduleLabel(_OpenedOrderModule module) {
    return switch (module) {
      _OpenedOrderModule.orders => 'Buyurtmalar',
      _OpenedOrderModule.sequence => 'Ketma-ketlik',
      _OpenedOrderModule.move => 'Ko‘chirish',
      _OpenedOrderModule.closed => 'Yopilgan',
    };
  }

  String _workerWatchTabLabel(_WorkerWatchTab tab) {
    if (tab.isCompleted) {
      return 'Tugallangan';
    }
    return productionMapPechatTabLabel(tab.apparatus!.warehouse);
  }
}

class _ReadOnlyOrderDetailSheet extends StatefulWidget {
  const _ReadOnlyOrderDetailSheet({
    required this.order,
    this.apparatus,
    this.canManageQueue = false,
    this.initialQueueStates = const {},
    this.queueStatesByApparatus = const {},
    this.queuePolicy = ApparatusQueuePolicy.strictSequence,
    this.sequenceOrderIds = const [],
    this.visibleOrderIds = const [],
    this.onQueueAction,
    this.progressDriverUrlPicker,
  });

  final ProductionMapSaved order;
  final AdminWarehouse? apparatus;
  final bool canManageQueue;
  final Map<String, String> initialQueueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final ApparatusQueuePolicy queuePolicy;
  final List<String> sequenceOrderIds;
  final List<String> visibleOrderIds;
  final _ReadOnlyQueueActionCallback? onQueueAction;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<_ReadOnlyOrderDetailSheet> createState() =>
      _ReadOnlyOrderDetailSheetState();
}

class _ReadOnlyOrderDetailSheetState extends State<_ReadOnlyOrderDetailSheet> {
  late Map<String, String> _queueStates;
  List<AdminRawMaterialAssignment> _materialAssignments = const [];
  final Set<String> _scannedMaterialBarcodes = {};
  AdminProgressBatch? _startInputProgressBatch;
  bool _actionInFlight = false;
  bool _materialsLoading = true;
  String _materialsError = '';
  bool _mapExpanded = false;

  @override
  void initState() {
    super.initState();
    _queueStates = Map<String, String>.from(widget.initialQueueStates);
    unawaited(_loadMaterialAssignments());
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyOrderDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStation = oldWidget.apparatus?.warehouse.trim() ?? '';
    final station = widget.apparatus?.warehouse.trim() ?? '';
    if (oldWidget.order.map.id.trim() != widget.order.map.id.trim() ||
        oldStation != station) {
      _scannedMaterialBarcodes.clear();
      _startInputProgressBatch = null;
    }
    if (_actionInFlight) {
      return;
    }
    if (station.isEmpty) {
      return;
    }
    final nextStates = _queueStatesForStation(
      station,
      widget.queueStatesByApparatus,
    );
    if (!mapEquals(_queueStates, nextStates)) {
      setState(() => _queueStates = Map<String, String>.from(nextStates));
    }
  }

  Future<void> _loadMaterialAssignments() async {
    setState(() {
      _materialsLoading = true;
      _materialsError = '';
    });
    try {
      final assignments =
          await MobileApi.instance.adminRawMaterialAssignments();
      if (!mounted) {
        return;
      }
      setState(() {
        _materialAssignments = assignments;
        _materialsLoading = false;
        _materialsError = '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _materialAssignments = const [];
        _materialsLoading = false;
        _materialsError = '';
      });
    }
  }

  Future<void> _runQueueAction(
    String action, {
    _ProgressQtyInput? progressInput,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String driverUrl = '',
    String completionRequestNote = '',
  }) async {
    final prepared = _prepareReadOnlyQueueAction(
      action: action,
      apparatus: widget.apparatus,
      onQueueAction: widget.onQueueAction,
      actionInFlight: _actionInFlight,
      materialAssignments: _materialAssignments,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      startInputProgressBatch: _startInputProgressBatch,
      order: widget.order,
    );
    if (prepared == null) {
      return;
    }
    if (prepared.blockReason != null) {
      showAdminTopNotice(context, prepared.blockReason!);
      return;
    }
    setState(() => _actionInFlight = true);
    try {
      final states = await prepared.onQueueAction(
        apparatus: prepared.apparatus,
        order: widget.order,
        action: action,
        materialBarcodes: _queueActionMaterialBarcodes(
          action: action,
          assignments: prepared.materialAssignments,
        ),
        producedQty: progressInput?.meterQty,
        grossQty: progressInput?.kgQty,
        returnInkKg: progressInput?.returnInkKg,
        laminationPrintLeftoverRolls:
            progressInput?.laminationPrintLeftoverRolls,
        laminationFilmLeftoverRolls: progressInput?.laminationFilmLeftoverRolls,
        rezkaBosmaWaste: progressInput?.rezkaBosmaWaste,
        rezkaLaminationWaste: progressInput?.rezkaLaminationWaste,
        rezkaEdgeWaste: progressInput?.rezkaEdgeWaste,
        totalWaste: progressInput?.totalWaste,
        finishedGoodsKg: progressInput?.finishedGoodsKg,
        finishedGoodsMeter: progressInput?.finishedGoodsMeter,
        uom: uom,
        qrPayload: _queueActionQrPayload(
          qrPayload: qrPayload,
          startInputProgressBatch: prepared.startInputProgressBatch,
        ),
        progressBatchId: _queueActionProgressBatchId(
          progressBatchId: progressBatchId,
          startInputProgressBatch: prepared.startInputProgressBatch,
        ),
        driverUrl: driverUrl,
        completionRequestNote: completionRequestNote,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _actionInFlight = false;
        if (states != null) {
          _queueStates = states.states;
        }
        if (_queueActionShouldClearStartInputProgress(
          action: action,
          result: states,
        )) {
          _startInputProgressBatch = null;
        }
      });
      if (_queueActionShouldReloadMaterials(action: action, result: states)) {
        unawaited(_loadMaterialAssignments());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _actionInFlight = false);
      showAdminTopNotice(context, _readOnlyQueueActionErrorText(error));
    }
  }

  Future<void> _runProgressAction(String action) async {
    final input = await _showProgressQtyDialogForApparatus(
      context,
      action: action,
      apparatus: widget.apparatus,
    );
    if (!mounted || input == null) {
      return;
    }
    if (input.isCompletionRequest) {
      await _runQueueAction(
        action,
        completionRequestNote: input.description,
      );
      return;
    }
    final driverUrl = await _pickProgressDriverUrl(
      context,
      widget.progressDriverUrlPicker,
    );
    if (!mounted || driverUrl == null) {
      return;
    }
    await _runQueueAction(
      action,
      progressInput: input,
      uom: 'm',
      driverUrl: driverUrl,
    );
  }

  Future<void> _scanMaterial() async {
    final orderId = widget.order.map.id.trim();
    final materialAssignments = _stationMaterialAssignments(
      assignments: _materialAssignments,
      orderId: orderId,
      station: widget.apparatus?.warehouse.trim() ?? '',
    );
    if (materialAssignments.isEmpty) {
      return;
    }
    final scan = await _scanMaterialAssignmentFromDialog(
      context: context,
      assignments: materialAssignments,
    );
    if (!mounted || scan == null) {
      return;
    }
    final match = scan.assignment;
    if (match == null) {
      showAdminTopNotice(context, 'Bu homashyo zakazga mos emas');
      return;
    }
    setState(() {
      _scannedMaterialBarcodes.add(_materialBarcodeKey(match.barcode));
    });
    if (_materialScanCompleted(
      assignments: materialAssignments,
      scannedBarcodes: _scannedMaterialBarcodes,
      orderId: orderId,
    )) {
      showAdminTopNotice(context, 'Homashyolar tasdiqlandi');
    }
  }

  Future<void> _scanStartInputProgressQr(String previousStage) async {
    try {
      final batch = await _scanProgressBatchFromQrDialog(context);
      if (!mounted) {
        return;
      }
      if (batch == null) {
        return;
      }
      if (!_progressBatchMatchesPreviousStage(
        batch: batch,
        orderId: widget.order.map.id.trim(),
        previousStage: previousStage,
      )) {
        showAdminTopNotice(
            context, 'Bu QR oldingi bosqich mahsulotiga mos emas');
        return;
      }
      setState(() => _startInputProgressBatch = batch);
      showAdminTopNotice(context, 'Oldingi bosqich QR tasdiqlandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(context, _progressQrLookupErrorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = widget.order.map;
    final steps = _linearProductionMapNodes(map);
    final uiState = _readOnlyOrderDetailUiState(
      order: widget.order,
      apparatus: widget.apparatus,
      queueStates: _queueStates,
      materialAssignments: _materialAssignments,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      canManageQueue: widget.canManageQueue,
      sequenceOrderIds: widget.sequenceOrderIds,
      visibleOrderIds: widget.visibleOrderIds,
      queuePolicy: widget.queuePolicy,
      startInputProgressBatch: _startInputProgressBatch,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            children: [
              _OrderStartUnifiedCard(
                orderCode: _openedOrderDisplayCode(map),
                productTitle: _productTitle(map),
                assignments: uiState.materialAssignments,
                materialsLoading: _materialsLoading,
                materialsError: _materialsError,
                scannedBarcodes: uiState.confirmedMaterialBarcodes,
                scannedCount: uiState.scannedCount,
                showStart: uiState.showStart,
                hasMaterialAssignments: uiState.hasMaterialAssignments,
                allMaterialsScanned: uiState.allMaterialsScanned,
                actionInFlight: _actionInFlight,
                showPause: uiState.showPause,
                showComplete: uiState.showComplete,
                showResume: uiState.showResume,
                showWaitingForPrevious: uiState.showWaitingForPrevious,
                previousStage: uiState.previousStage,
                previousProgressRequired: uiState.previousProgressRequired,
                previousProgressReady: uiState.previousProgressReady,
                previousProgressBatch: _startInputProgressBatch,
                onScan: () => unawaited(_scanMaterial()),
                onProgressScan: uiState.previousStage == null
                    ? null
                    : () => unawaited(
                          _scanStartInputProgressQr(uiState.previousStage!),
                        ),
                onStart: () => unawaited(_runQueueAction('start')),
                onPause: () => unawaited(_runProgressAction('pause')),
                onComplete: () => unawaited(_runProgressAction('complete')),
                onResume: () => unawaited(_runQueueAction('resume')),
              ),
              const SizedBox(height: 10),
              _OrderMapProgressCard(
                steps: steps,
                orderId: uiState.orderId,
                currentStation: uiState.station,
                queueStates: _queueStates,
                queueStatesByApparatus: widget.queueStatesByApparatus,
                expanded: _mapExpanded,
                onToggleExpanded: () {
                  setState(() => _mapExpanded = !_mapExpanded);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
