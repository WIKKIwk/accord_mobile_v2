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
    final response = await MobileApi.instance.adminProductionMapLiveConnect();
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw MobileApiException(
        code: 'production_map_live',
        message: 'Live ulanish ochilmadi',
        statusCode: response.statusCode,
      );
    }

    final completer = Completer<void>();
    final dataLines = <String>[];

    await _liveStreamSubscription?.cancel();
    _liveStreamSubscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (!mounted || generation != _liveStreamGeneration) {
          return;
        }
        if (line.isEmpty) {
          if (dataLines.isEmpty) {
            return;
          }
          final payloadText = dataLines.join('\n');
          dataLines.clear();
          final payload = jsonDecode(payloadText) as Map<String, dynamic>;
          if (payload['ok'] != true) {
            return;
          }
          _applyWorkerLiveSnapshot(
            AdminProductionMapLiveSnapshot.fromJson(payload),
          );
          return;
        }
        if (line.startsWith(':')) {
          return;
        }
        if (line.startsWith('data:')) {
          dataLines.add(line.substring(5).trimLeft());
        }
      },
      onError: (error, _) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  Future<void> _loadWorkerApparatus() async {
    final apparatus = await MobileApi.instance.adminWarehouses(
      parent: 'aparat - A',
      limit: 200,
    );
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
    final orders = snapshot.maps
        .where((item) => item.map.id.trim().startsWith('zakaz-'))
        .toList(growable: false);
    final newRejectedDecisions = widget.workerMode
        ? snapshot.completionRequestDecisions
            .where((decision) =>
                decision.decision.trim() == 'rejected' &&
                decision.eventId.trim().isNotEmpty &&
                !_shownCompletionDecisionIds.contains(decision.eventId.trim()))
            .toList(growable: false)
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
        decision.message.trim().isNotEmpty
            ? decision.message.trim()
            : "Sizni so'rovingiz rad etildi",
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
        if (widget.workerMode) {
          await _refreshMapsAndApparatus(initial: runInitial);
          await _refreshQueueSnapshot();
          await _refreshWorkerCompletedOrders();
          await _refreshWorkerCompletionRequestDecisions();
        } else {
          await Future.wait([
            _refreshMapsAndApparatus(initial: runInitial),
            _refreshQueueSnapshot(),
            _refreshCompletionRequests(),
            _refreshClosedOrders(),
          ]);
        }
        if (!_liveRefreshQueued) {
          return;
        }
        runInitial = false;
      }
    } finally {
      _liveRefreshInFlight = false;
    }
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
    if (!widget.workerMode) {
      return;
    }
    try {
      final completed =
          await MobileApi.instance.adminCompletedProductionMapOrders();
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
    if (!widget.workerMode) {
      return;
    }
    try {
      final decisions = await MobileApi.instance
          .adminProductionMapCompletionRequestDecisions();
      if (!mounted) {
        return;
      }
      final newRejectedDecisions = decisions
          .where((decision) =>
              decision.decision.trim() == 'rejected' &&
              decision.eventId.trim().isNotEmpty &&
              !_shownCompletionDecisionIds.contains(decision.eventId.trim()))
          .toList(growable: false);
      for (final decision in newRejectedDecisions) {
        _shownCompletionDecisionIds.add(decision.eventId.trim());
        showAdminTopNotice(
          context,
          decision.message.trim().isNotEmpty
              ? decision.message.trim()
              : "Sizni so'rovingiz rad etildi",
        );
      }
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshClosedOrders() async {
    if (widget.workerMode) {
      return;
    }
    try {
      final closed = await MobileApi.instance.adminClosedProductionMapOrders();
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
    if (widget.workerMode) {
      return;
    }
    try {
      final requests =
          await MobileApi.instance.adminProductionMapCompletionRequests();
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
      final results = await Future.wait([
        MobileApi.instance.adminProductionMaps(),
        MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200),
      ]);
      if (!mounted) {
        return;
      }
      final maps = results[0] as List<ProductionMapSaved>;
      final apparatus = results[1] as List<AdminWarehouse>;
      final orders = maps
          .where((item) => item.map.id.trim().startsWith('zakaz-'))
          .toList(growable: false);
      if (!initial &&
          _ordersRevision(orders) == _ordersRevision(_orders) &&
          _apparatus.length == apparatus.length &&
          _apparatus.every(
            (item) => apparatus.any((next) => next.warehouse == item.warehouse),
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
    final metraj = await _productionMapBaseMetrajByMapId(orders, templates);
    final kgByMap = <String, double>{};
    for (final order in orders) {
      final mapId = order.map.id.trim();
      if (mapId.isEmpty) {
        continue;
      }
      final kg = _productionMapOrderKg(order.map, templates);
      if (kg != null && kg > 0) {
        kgByMap[mapId] = kg;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _baseMetrajByMapId = metraj;
      _orderKgByMapId = kgByMap;
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

  int _workerWatchTabCount(List<AdminWarehouse> apparatus) {
    return apparatus.isEmpty ? 1 : apparatus.length + 1;
  }

  List<AdminWarehouse> _workerWatchApparatusOrder() {
    final ordered = List<AdminWarehouse>.from(_apparatus);
    final index = _initialWatchApparatusIndex(ordered);
    if (index > 0) {
      final assigned = ordered.removeAt(index);
      ordered.insert(0, assigned);
    }
    return ordered;
  }

  List<_WorkerWatchTab> _workerWatchTabs() {
    final ordered = _workerWatchApparatusOrder();
    if (ordered.isEmpty) {
      return const [];
    }
    return [
      _WorkerWatchTab.apparatus(ordered.first),
      const _WorkerWatchTab.completed(),
      for (final item in ordered.skip(1)) _WorkerWatchTab.apparatus(item),
    ];
  }

  int _initialWatchApparatusIndex(List<AdminWarehouse> apparatus) {
    final assigned = AppSession.instance.profile?.assignedApparatus
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty) ??
        const <String>[];
    for (final item in assigned) {
      final index = apparatus.indexWhere(
        (entry) => _apparatusTitlesMatch(entry.warehouse, item),
      );
      if (index >= 0) {
        return index;
      }
    }
    return 0;
  }

  bool _isAssignedWatchApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final assigned =
        AppSession.instance.profile?.assignedApparatus ?? const <String>[];
    return assigned.any((item) => _apparatusTitlesMatch(title, item));
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
      final result = await _submitQueueAction(
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
      if (completionRequestNote.trim().isNotEmpty &&
          result.completionRequest != null) {
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
        error is MobileApiException
            ? error.message
            : 'Navbat amali bajarilmadi',
      );
      return null;
    } finally {
      _queueActionInFlight = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<AdminApparatusQueueActionResult> _submitQueueAction({
    required String apparatus,
    required String orderId,
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
  }) {
    return MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: apparatus,
      orderId: orderId,
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
  }

  Future<AdminApparatusQueueSnapshot> _loadQueueSnapshot() async {
    try {
      return await MobileApi.instance.adminProductionMapQueueSnapshot();
    } catch (_) {
      return const AdminApparatusQueueSnapshot(
        sequences: {},
        queueStates: {},
        queuePolicies: {},
      );
    }
  }

  void _syncMoveApparatusDefaults(List<AdminWarehouse> source) {
    final pechat = source
        .where((item) => productionMapPechatColorCount(item.warehouse) != null)
        .toList(growable: false);
    final candidates = pechat.isEmpty ? source : pechat;
    if (candidates.isEmpty) {
      _moveTopApparatus = null;
      _moveBottomApparatus = null;
      return;
    }
    _moveTopApparatus ??= candidates.first;
    if (_moveBottomApparatus == null) {
      if (candidates.length > 1) {
        _moveBottomApparatus = candidates[1];
      } else {
        for (final item in source) {
          if (item.warehouse != candidates.first.warehouse) {
            _moveBottomApparatus = item;
            break;
          }
        }
      }
    }
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
        canManageQueue: _isAssignedWatchApparatus(apparatus),
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

  List<ProductionMapSaved> _visibleOrders() {
    return _filterOrdersBySearch(_orders);
  }

  List<AdminClosedProductionOrder> _visibleClosedOrders() {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _closedOrders;
    }
    return _closedOrders.where((order) {
      final haystack = [
        order.orderId,
        _closedOrderDisplayCode(order),
        order.orderNumber,
        order.title,
        order.productCode,
        order.closedByRole,
        order.closedByRef,
        order.closedByDisplayName,
        for (final log in order.logs) ...[
          log.apparatus,
          log.action,
          log.fromState,
          log.toState,
          log.actorRole,
          log.actorRef,
          log.actorDisplayName,
        ],
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  List<ProductionMapSaved> _filterOrdersBySearch(
    List<ProductionMapSaved> orders,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return orders;
    }
    return orders.where(_orderMatchesSearch).toList(growable: false);
  }

  bool _orderMatchesSearch(ProductionMapSaved order) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final map = order.map;
    final haystack = [
      _openedOrderDisplayCode(map),
      map.code,
      map.orderNumber,
      map.title,
      map.productCode,
      for (final node in map.nodes) node.title,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  List<ProductionMapSaved> _baseOrdersForApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    return _orders.where((order) {
      if (_isFlexoOrderBlockedForColorPechat(order.map, apparatus)) {
        return false;
      }
      final hasAlternative = _hasAlternativeApparatus(order.map);
      if (hasAlternative) {
        return _alternativeOrderAssignedToApparatus(order.map, apparatus);
      }
      return productionMapMapHasWorkStageForStation(
        map: order.map,
        station: title,
      );
    }).toList();
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminWarehouse apparatus) {
    final filtered = _baseOrdersForApparatus(apparatus);
    final sequence = _sequenceOrderIdsForApparatus(
      apparatus,
      sequenceByApparatus: _sequenceByApparatus,
    );
    List<ProductionMapSaved> ordered;
    if (sequence.isEmpty) {
      ordered = filtered;
    } else {
      final byId = {for (final order in filtered) order.map.id: order};
      ordered = [
        for (final id in sequence)
          if (byId.containsKey(id)) byId.remove(id)!,
        ...byId.values,
      ];
    }
    if (widget.workerMode) {
      final states = _queueStatesForApparatus(
        apparatus,
        queueStatesByApparatus: _queueStatesByApparatus,
      );
      ordered = ordered
          .where(
            (order) =>
                apparatusQueueOrderStateFromRaw(
                  states[order.map.id.trim()],
                ) !=
                ApparatusQueueOrderState.completed,
          )
          .toList(growable: false);
    }
    return widget.workerMode ? _filterOrdersBySearch(ordered) : ordered;
  }

  List<_WorkerCompletedOrderEntry> _workerCompletedOrders() {
    final byId = {for (final order in _orders) order.map.id.trim(): order};
    final seen = <String>{};
    final orders = <_WorkerCompletedOrderEntry>[];
    for (final completed in _completedWorkerOrders) {
      final orderId = completed.orderId.trim();
      if (orderId.isEmpty || !seen.add(orderId)) {
        continue;
      }
      final order = byId[orderId];
      if (order != null) {
        orders.add(
          _WorkerCompletedOrderEntry(
            order: order,
            apparatus: _completedOrderApparatus(completed),
          ),
        );
      }
    }
    final filtered = _filterOrdersBySearch(
      orders.map((entry) => entry.order).toList(growable: false),
    );
    final visibleIds = filtered.map((order) => order.map.id.trim()).toSet();
    return orders
        .where((entry) => visibleIds.contains(entry.order.map.id.trim()))
        .toList(growable: false);
  }

  AdminWarehouse? _completedOrderApparatus(AdminCompletedQueueOrder completed) {
    final title = completed.apparatus.trim();
    if (title.isEmpty) {
      return null;
    }
    for (final apparatus in _apparatus) {
      if (_apparatusTitlesMatch(apparatus.warehouse, title)) {
        return apparatus;
      }
    }
    return AdminWarehouse(warehouse: title, parentWarehouse: 'aparat - A');
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
        error is MobileApiException ? error.message : 'Ketma-ketlik saqlanmadi',
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
    final orderId = order.map.id.trim();
    final selectedFromZone = zoneOrders
        .where((item) => _selectedMoveOrderIds.contains(item.map.id.trim()))
        .toList(growable: false);
    final orders = selectedFromZone.isEmpty
        ? [order]
        : [
            ...selectedFromZone,
            if (!selectedFromZone.any((item) => item.map.id.trim() == orderId))
              order,
          ];
    return _MoveDragPayload(orders: orders, source: source);
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
    final orderIds = orders.map((order) => order.map.id.trim()).toSet();
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
      final savedById = {for (final item in saved) item.map.id.trim(): item};
      if (savedById.length != orderIds.length ||
          !orderIds.every(savedById.containsKey)) {
        throw const MobileApiException(
          code: 'move_incomplete',
          message: 'Zakazlar to‘liq ko‘chirilmadi',
        );
      }
      setState(() {
        _selectedMoveOrderIds.removeAll(orderIds);
        _orders = [
          for (final item in _orders)
            if (savedById.containsKey(item.map.id.trim()))
              savedById[item.map.id.trim()]!
            else
              item,
        ];
      });
      showAdminTopNotice(
        context,
        orders.length == 1
            ? 'Zakaz ko‘chirildi'
            : '${orders.length} ta zakaz ko‘chirildi',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Zakaz ko‘chirilmadi',
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
    final converted = <MapEntry<ProductionMapSaved, ProductionMapDefinition>>[];
    for (final order in orders) {
      final map = _returnAssignedMapToAlternatives(order.map, source);
      if (map == null) {
        showAdminTopNotice(context, 'Bu zakaz tanlanmagan holatga qaytmaydi');
        return;
      }
      converted.add(MapEntry(order, map));
    }
    final orderIds = orders.map((order) => order.map.id.trim()).toSet();
    setState(() {
      _draggingMoveOrders = const [];
      _draggingMoveSource = null;
    });
    try {
      final saved = <ProductionMapSaved>[];
      for (final entry in converted) {
        saved.add(await MobileApi.instance.adminSaveProductionMap(entry.value));
      }
      if (!mounted) {
        return;
      }
      final savedById = {for (final item in saved) item.map.id.trim(): item};
      if (savedById.length != orderIds.length ||
          !orderIds.every(savedById.containsKey)) {
        throw const MobileApiException(
          code: 'move_incomplete',
          message: 'Zakazlar to‘liq tanlanmagan holatga qaytmadi',
        );
      }
      setState(() {
        _selectedMoveOrderIds.removeAll(orderIds);
        _orders = [
          for (final item in _orders)
            if (savedById.containsKey(item.map.id.trim()))
              savedById[item.map.id.trim()]!
            else
              item,
        ];
      });
      showAdminTopNotice(
        context,
        orders.length == 1
            ? 'Zakaz tanlanmagan holatga qaytarildi'
            : '${orders.length} ta zakaz tanlanmagan holatga qaytarildi',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : 'Zakaz tanlanmagan holatga qaytmadi',
      );
      await _load();
    }
  }

  ProductionMapDefinition? _returnAssignedMapToAlternatives(
    ProductionMapDefinition map,
    AdminWarehouse source,
  ) {
    final sourceTitle = source.warehouse.trim();
    final assignedGroupId = _assignedAlternativeGroupIdForApparatus(
      map,
      sourceTitle,
    );
    if (assignedGroupId == null) {
      return null;
    }
    return map.copyWith(
      nodes: [
        for (final node in map.nodes)
          node.alternativeGroupId.trim() == assignedGroupId
              ? node.copyWith(alternativeAssignedTitle: '')
              : node,
      ],
    );
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
    final orderIds = orders.map((order) => order.map.id.trim()).toSet();
    setState(() {
      _draggingMoveOrders = const [];
      _draggingMoveSource = null;
    });
    try {
      final saved = <ProductionMapSaved>[];
      for (final order in orders) {
        final assignedMap = _assignAlternativeMapToApparatus(
          order.map,
          apparatus,
        );
        saved.add(await MobileApi.instance.adminSaveProductionMap(assignedMap));
      }
      if (!mounted) {
        return;
      }
      final savedById = {for (final item in saved) item.map.id.trim(): item};
      if (savedById.length != orderIds.length ||
          !orderIds.every(savedById.containsKey)) {
        throw const MobileApiException(
          code: 'move_incomplete',
          message: 'Zakazlar to‘liq biriktirilmadi',
        );
      }
      setState(() {
        _selectedMoveOrderIds.removeAll(orderIds);
        _orders = [
          for (final item in _orders)
            if (savedById.containsKey(item.map.id.trim()))
              savedById[item.map.id.trim()]!
            else
              item,
        ];
      });
      showAdminTopNotice(
        context,
        orders.length == 1
            ? 'Zakaz aparatga biriktirildi'
            : '${orders.length} ta zakaz aparatga biriktirildi',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException ? error.message : 'Zakaz biriktirilmadi',
      );
      await _load();
    }
  }

  ProductionMapDefinition _assignAlternativeMapToApparatus(
    ProductionMapDefinition map,
    AdminWarehouse apparatus,
  ) {
    final targetTitle = apparatus.warehouse.trim();
    final targetNode = map.nodes
        .where((node) {
          return node.kind == 'apparatus' &&
              node.alternativeGroupId.trim().isNotEmpty &&
              productionMapWarehouseTitlesMatch(node.title, targetTitle);
        })
        .cast<ProductionMapNode?>()
        .firstWhere((node) => node != null, orElse: () => null);
    if (targetNode == null) {
      return map;
    }
    final groupId = targetNode.alternativeGroupId.trim();
    return map.copyWith(
      nodes: [
        for (final node in map.nodes)
          node.alternativeGroupId.trim() == groupId
              ? node.copyWith(alternativeAssignedTitle: targetTitle)
              : node,
      ],
    );
  }

  bool _canMoveOrderToApparatus(
    ProductionMapSaved order,
    AdminWarehouse target, {
    required AdminWarehouse source,
  }) {
    if (_isMoveUnassignedApparatus(source)) {
      return !_isMoveUnassignedApparatus(target) &&
          _isAlternativeOrderForApparatus(order, target);
    }
    if (_isMoveUnassignedApparatus(target)) {
      return _returnAssignedMapToAlternatives(order.map, source) != null;
    }
    return productionMapCanMoveOrderToApparatus(
      nodes: order.map.nodes,
      fromApparatus: source.warehouse,
      toApparatus: target.warehouse,
      rollCount: order.map.rollCount,
      widthMm: order.map.widthMm,
      isFlexoOrder: productionMapIsFlexoOrder(order.map),
    );
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
    if (oppositeApparatus == null ||
        _isMoveUnassignedApparatus(oppositeApparatus)) {
      return _apparatus;
    }
    final oppositeTitle = oppositeApparatus.warehouse.trim();
    return _apparatus
        .where(
          (apparatus) => !productionMapWarehouseTitlesMatch(
            apparatus.warehouse,
            oppositeTitle,
          ),
        )
        .toList(growable: false);
  }

  List<ProductionMapSaved> _alternativeOrdersForApparatus(
    AdminWarehouse apparatus,
  ) {
    return _orders
        .where(
          (order) =>
              !_isFlexoOrderBlockedForColorPechat(order.map, apparatus) &&
              _hasUnassignedAlternativeGroupForApparatus(order.map, apparatus),
        )
        .toList(growable: false);
  }

  bool _isAlternativeOrderForApparatus(
    ProductionMapSaved order,
    AdminWarehouse apparatus,
  ) {
    if (_isFlexoOrderBlockedForColorPechat(order.map, apparatus)) {
      return false;
    }
    return order.map.nodes.any((node) {
      return node.kind == 'apparatus' &&
          node.alternativeGroupId.trim().isNotEmpty &&
          productionMapWarehouseTitlesMatch(node.title, apparatus.warehouse);
    });
  }

  bool _hasAlternativeApparatus(ProductionMapDefinition map) {
    return map.nodes.any(
      (node) =>
          node.kind == 'apparatus' && node.alternativeGroupId.trim().isNotEmpty,
    );
  }

  bool _hasUnassignedAlternativeGroupForApparatus(
    ProductionMapDefinition map,
    AdminWarehouse apparatus,
  ) {
    final matchingGroups = <String>{};
    final assignedGroups = <String>{};
    for (final node in map.nodes) {
      if (node.kind != 'apparatus') {
        continue;
      }
      final groupId = node.alternativeGroupId.trim();
      if (groupId.isEmpty) {
        continue;
      }
      if (productionMapWarehouseTitlesMatch(node.title, apparatus.warehouse)) {
        matchingGroups.add(groupId);
      }
      if (node.alternativeAssignedTitle.trim().isNotEmpty) {
        assignedGroups.add(groupId);
      }
    }
    return matchingGroups.any((groupId) => !assignedGroups.contains(groupId));
  }

  bool _alternativeOrderAssignedToApparatus(
    ProductionMapDefinition map,
    AdminWarehouse apparatus,
  ) {
    final title = apparatus.warehouse.trim();
    return map.nodes.any(
      (node) =>
          node.kind == 'apparatus' &&
          node.alternativeGroupId.trim().isNotEmpty &&
          productionMapWarehouseTitlesMatch(
            node.alternativeAssignedTitle,
            title,
          ),
    );
  }

  bool _isFlexoOrderBlockedForColorPechat(
    ProductionMapDefinition map,
    AdminWarehouse apparatus,
  ) {
    return productionMapIsFlexoOrder(map) &&
        productionMapPechatColorCount(apparatus.warehouse) != null;
  }

  String? _assignedAlternativeGroupIdForApparatus(
    ProductionMapDefinition map,
    String apparatusTitle,
  ) {
    for (final node in map.nodes) {
      if (node.kind == 'apparatus' &&
          node.alternativeGroupId.trim().isNotEmpty &&
          productionMapWarehouseTitlesMatch(
            node.alternativeAssignedTitle,
            apparatusTitle,
          )) {
        return node.alternativeGroupId.trim();
      }
    }
    return null;
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
                                      visibleOrders: _visibleOrders(),
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
                                      visibleClosedOrders:
                                          _visibleClosedOrders(),
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
    final tabs = _workerWatchTabs();
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
                    orders: _workerCompletedOrders(),
                    bottomPadding: bottomPadding,
                    onTapOrder: _showCompletedOrderDetail,
                  )
                else
                  _AparatchiWatchSequencePage(
                    apparatus: tab.apparatus!,
                    orders: _ordersForApparatus(tab.apparatus!),
                    bottomPadding: bottomPadding,
                    isAssigned: _isAssignedWatchApparatus(tab.apparatus!),
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
  final Future<AdminApparatusQueueActionResult?> Function({
    required AdminWarehouse apparatus,
    required ProductionMapSaved order,
    required String action,
    List<String> materialBarcodes,
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
    String uom,
    String qrPayload,
    String progressBatchId,
    String driverUrl,
    String completionRequestNote,
  })? onQueueAction;
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
    final apparatus = widget.apparatus;
    final onQueueAction = widget.onQueueAction;
    if (apparatus == null || onQueueAction == null || _actionInFlight) {
      return;
    }
    final materialAssignments = _stationMaterialAssignments(
      assignments: _materialAssignments,
      orderId: widget.order.map.id.trim(),
      station: apparatus.warehouse.trim(),
    );
    if (action == 'start' &&
        materialAssignments.isNotEmpty &&
        !_allMaterialsScanned(
          assignments: materialAssignments,
          scannedBarcodes: _scannedMaterialBarcodes,
          orderId: widget.order.map.id.trim(),
        )) {
      showAdminTopNotice(context, 'Avval hamma homashyoni QR scan qiling');
      return;
    }
    final station = apparatus.warehouse.trim();
    final previousStage = station.isEmpty
        ? null
        : productionMapPreviousWorkStageStation(
            map: widget.order.map,
            station: station,
          );
    final startInputProgressBatch =
        action == 'start' ? _startInputProgressBatch : null;
    if (action == 'start' &&
        previousStage != null &&
        startInputProgressBatch == null) {
      showAdminTopNotice(context, 'Oldingi bosqich QR sini scan qiling');
      return;
    }
    setState(() => _actionInFlight = true);
    try {
      final states = await onQueueAction(
        apparatus: apparatus,
        order: widget.order,
        action: action,
        materialBarcodes: action == 'start'
            ? materialAssignments.map((item) => item.barcode).toList()
            : const [],
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
        qrPayload: qrPayload.trim().isEmpty
            ? (startInputProgressBatch?.qrPayload ?? '')
            : qrPayload,
        progressBatchId: progressBatchId.trim().isEmpty
            ? (startInputProgressBatch?.batchId ?? '')
            : progressBatchId,
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
        if (action == 'start' && states != null) {
          _startInputProgressBatch = null;
        }
      });
      if (action == 'start' && states != null) {
        unawaited(_loadMaterialAssignments());
      }
    } on MobileApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _actionInFlight = false);
      showAdminTopNotice(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _actionInFlight = false);
      showAdminTopNotice(context, 'Amal bajarilmadi');
    }
  }

  Future<void> _runProgressAction(String action) async {
    final isBosma =
        productionMapPechatColorCount(widget.apparatus?.warehouse ?? '') !=
            null;
    final isLaminatsiya =
        productionMapIsLaminatsiyaApparatus(widget.apparatus?.warehouse ?? '');
    final isRezka =
        productionMapIsRezkaApparatus(widget.apparatus?.warehouse ?? '');
    final input = await _showProgressQtyDialog(
      context,
      action,
      isBosma: isBosma,
      isLaminatsiya: isLaminatsiya,
      isRezka: isRezka,
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
    final driverUrl = widget.progressDriverUrlPicker != null
        ? await widget.progressDriverUrlPicker!(context)
        : (await _showProgressPrinterPicker(context))?.driverUrl;
    if (!mounted || driverUrl == null) {
      return;
    }
    await _runQueueAction(
      action,
      producedQty: input.meterQty,
      grossQty: input.kgQty,
      returnInkKg: input.returnInkKg,
      laminationPrintLeftoverRolls: input.laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: input.laminationFilmLeftoverRolls,
      rezkaBosmaWaste: input.rezkaBosmaWaste,
      rezkaLaminationWaste: input.rezkaLaminationWaste,
      rezkaEdgeWaste: input.rezkaEdgeWaste,
      totalWaste: input.totalWaste,
      finishedGoodsKg: input.finishedGoodsKg,
      finishedGoodsMeter: input.finishedGoodsMeter,
      uom: 'm',
      driverUrl: driverUrl,
    );
  }

  Future<void> _scanMaterial() async {
    final materialAssignments = _stationMaterialAssignments(
      assignments: _materialAssignments,
      orderId: widget.order.map.id.trim(),
      station: widget.apparatus?.warehouse.trim() ?? '',
    );
    if (materialAssignments.isEmpty) {
      return;
    }
    final barcode = await showRawMaterialScanDialog(context);
    if (!mounted || barcode == null || barcode.trim().isEmpty) {
      return;
    }
    final normalized = _materialBarcodeKey(rawMaterialBarcodeFromQr(barcode));
    final match = materialAssignments
        .where((item) => _materialBarcodeKey(item.barcode) == normalized)
        .cast<AdminRawMaterialAssignment?>()
        .firstWhere((item) => item != null, orElse: () => null);
    if (match == null) {
      showAdminTopNotice(context, 'Bu homashyo zakazga mos emas');
      return;
    }
    setState(() {
      _scannedMaterialBarcodes.add(_materialBarcodeKey(match.barcode));
    });
    if (_allMaterialsScanned(
      assignments: materialAssignments,
      scannedBarcodes: _scannedMaterialBarcodes,
      orderId: widget.order.map.id.trim(),
    )) {
      showAdminTopNotice(context, 'Homashyolar tasdiqlandi');
    }
  }

  Future<void> _scanStartInputProgressQr(String previousStage) async {
    final raw = await showRawMaterialScanDialog(
      context,
      title: 'Progress QR',
      manualLabel: 'EPC',
    );
    if (!mounted || raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final batch = await MobileApi.instance.adminProgressQrLookup(
        rawMaterialBarcodeFromQr(raw),
      );
      if (!mounted) {
        return;
      }
      final action = batch.action.trim().toLowerCase();
      final status = batch.status.trim().toLowerCase();
      final matchesOrder = batch.orderId.trim() == widget.order.map.id.trim();
      final matchesStage = productionMapWarehouseTitlesMatch(
        batch.apparatus,
        previousStage,
      );
      final usableAction = action == 'pause' || action == 'complete';
      final usableStatus =
          status == 'paused' || status == 'completed' || status == 'resumed';
      if (!matchesOrder || !matchesStage || !usableAction || !usableStatus) {
        showAdminTopNotice(
            context, 'Bu QR oldingi bosqich mahsulotiga mos emas');
        return;
      }
      setState(() => _startInputProgressBatch = batch);
      showAdminTopNotice(context, 'Oldingi bosqich QR tasdiqlandi');
    } on MobileApiException catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(context, error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(context, 'Progress QR tekshirilmadi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = widget.order.map;
    final steps = _linearProductionMapNodes(map);
    final orderId = map.id.trim();
    final station = widget.apparatus?.warehouse.trim() ?? '';
    final queueState = apparatusQueueOrderStateFromRaw(_queueStates[orderId]);
    final materialAssignments = _stationMaterialAssignments(
      assignments: _materialAssignments,
      orderId: orderId,
      station: station,
    );
    final hasMaterialAssignments = materialAssignments.isNotEmpty;
    final allMaterialsScanned = _allMaterialsScanned(
      assignments: materialAssignments,
      scannedBarcodes: _scannedMaterialBarcodes,
      orderId: orderId,
    );
    final confirmedMaterialBarcodes = _confirmedMaterialBarcodes(
      assignments: materialAssignments,
      scannedBarcodes: _scannedMaterialBarcodes,
      orderId: orderId,
    );
    final previousStage = station.isEmpty
        ? null
        : productionMapPreviousWorkStageStation(map: map, station: station);
    final actionableId = widget.canManageQueue
        ? firstActionableQueueOrderId(
            sequence: widget.sequenceOrderIds.isNotEmpty
                ? widget.sequenceOrderIds
                : widget.visibleOrderIds,
            states: _queueStates,
            visibleOrderIds: widget.visibleOrderIds,
          )
        : null;
    final activeOrderId = widget.canManageQueue
        ? firstInProgressQueueOrderId(
            sequence: widget.sequenceOrderIds.isNotEmpty
                ? widget.sequenceOrderIds
                : widget.visibleOrderIds,
            states: _queueStates,
            visibleOrderIds: widget.visibleOrderIds,
          )
        : null;
    final freePick = widget.queuePolicy == ApparatusQueuePolicy.freePick;
    final canStartWithPreviousProgress = previousStage != null &&
        queueState == ApparatusQueueOrderState.pending &&
        (activeOrderId == null || activeOrderId == orderId);
    final isActionable = widget.canManageQueue &&
        (freePick
            ? activeOrderId == null || activeOrderId == orderId
            : actionableId == orderId || canStartWithPreviousProgress);
    final previousProgressRequired = previousStage != null;
    final previousProgressReady =
        !previousProgressRequired || _startInputProgressBatch != null;
    final showStart =
        isActionable && queueState == ApparatusQueueOrderState.pending;
    final showPause =
        isActionable && queueState == ApparatusQueueOrderState.inProgress;
    final showComplete =
        isActionable && queueState == ApparatusQueueOrderState.inProgress;
    final showResume =
        isActionable && queueState == ApparatusQueueOrderState.paused;
    final showWaitingForPrevious = false;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        final scannedCount = confirmedMaterialBarcodes.length;
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            children: [
              _OrderStartUnifiedCard(
                orderCode: _openedOrderDisplayCode(map),
                productTitle: _productTitle(map),
                assignments: materialAssignments,
                materialsLoading: _materialsLoading,
                materialsError: _materialsError,
                scannedBarcodes: confirmedMaterialBarcodes,
                scannedCount: scannedCount,
                showStart: showStart,
                hasMaterialAssignments: hasMaterialAssignments,
                allMaterialsScanned: allMaterialsScanned,
                actionInFlight: _actionInFlight,
                showPause: showPause,
                showComplete: showComplete,
                showResume: showResume,
                showWaitingForPrevious: showWaitingForPrevious,
                previousStage: previousStage,
                previousProgressRequired: previousProgressRequired,
                previousProgressReady: previousProgressReady,
                previousProgressBatch: _startInputProgressBatch,
                onScan: () => unawaited(_scanMaterial()),
                onProgressScan: previousStage == null
                    ? null
                    : () => unawaited(_scanStartInputProgressQr(previousStage)),
                onStart: () => unawaited(_runQueueAction('start')),
                onPause: () => unawaited(_runProgressAction('pause')),
                onComplete: () => unawaited(_runProgressAction('complete')),
                onResume: () => unawaited(_runQueueAction('resume')),
              ),
              const SizedBox(height: 10),
              _OrderMapProgressCard(
                steps: steps,
                orderId: orderId,
                currentStation: station,
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
