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

enum _OpenedOrderModule { orders, move, sequence, closed }

class _WorkerWatchTab {
  const _WorkerWatchTab.apparatus(this.apparatus) : isCompleted = false;
  const _WorkerWatchTab.completed()
      : apparatus = null,
        isCompleted = true;

  final AdminWarehouse? apparatus;
  final bool isCompleted;
}

class _WorkerCompletedOrderEntry {
  const _WorkerCompletedOrderEntry({
    required this.order,
    required this.apparatus,
  });

  final ProductionMapSaved order;
  final AdminWarehouse? apparatus;
}

const double _openedOrderPanelCardGap = 4;
const double _openedOrderPanelTopGap = 8;

const _moveUnassignedWarehouse = AdminWarehouse(
  warehouse: 'Tanlanmagan',
  parentWarehouse: 'production-map-unassigned',
);

bool _isMoveUnassignedApparatus(AdminWarehouse? apparatus) {
  return apparatus?.parentWarehouse == _moveUnassignedWarehouse.parentWarehouse;
}

double? _productionMapOrderKg(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) {
  final stored = map.orderKg;
  if (stored != null && stored > 0) {
    return stored;
  }
  final template = _calculateTemplateForProductionMap(map, templates);
  if (template != null && template.kg > 0) {
    return template.kg;
  }
  return null;
}

List<String> _productionMapWorkflowLines(
  ProductionMapDefinition map, {
  double? baseMetraj,
  double? orderKg,
}) {
  final workSteps = <String>[];
  for (final node in _linearProductionMapNodes(map)) {
    if (node.kind == 'start' || node.kind == 'end') {
      continue;
    }
    final title = _productionMapNodeDisplayTitle(node);
    if (title.isEmpty) {
      continue;
    }
    switch (node.kind) {
      case 'apparatus':
        workSteps.add('$title aparatidan');
        break;
      case 'task':
        workSteps.add(title);
        break;
      default:
        break;
    }
  }
  if (workSteps.isEmpty) {
    final result = _productionMapResultSummary(
      map,
      baseMetraj: baseMetraj,
      orderKg: orderKg,
    );
    return result.isEmpty ? const [] : ['Natija: $result'];
  }

  final lines = <String>['Ish tartibi:'];
  for (var index = 0; index < workSteps.length; index++) {
    final step = workSteps[index];
    if (index == 0) {
      lines.add('${index + 1}. Birinchi bosqich — $step boshlanadi');
    } else if (index == workSteps.length - 1) {
      lines.add('${index + 1}. So‘ng — $step');
    } else {
      lines.add('${index + 1}. Keyin — $step');
    }
  }
  final result = _productionMapResultSummary(
    map,
    baseMetraj: baseMetraj,
    orderKg: orderKg,
  );
  if (result.isNotEmpty) {
    lines.add('Natija: $result');
  }
  return lines;
}

CalculateOrderTemplate? _calculateTemplateForProductionMap(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) {
  final mapId = map.id.trim();
  for (final template in templates) {
    if (template.sourceMapId.trim() == mapId) {
      return template;
    }
  }
  final orderNumber = map.orderNumber.trim();
  final code = map.code.trim();
  final idSuffix = mapId.startsWith('zakaz-') ? mapId.substring(6).trim() : '';
  final orderKeys =
      {orderNumber, code, idSuffix}.where((value) => value.isNotEmpty).toSet();
  for (final template in templates) {
    final templateOrder = template.orderNumber.trim();
    final templateCode = template.code.trim();
    if (orderKeys.contains(templateOrder) || orderKeys.contains(templateCode)) {
      return template;
    }
  }
  final productKeys = {
    map.productCode.trim().toLowerCase(),
    map.title.trim().toLowerCase(),
    _openedOrderProductTitle(map).toLowerCase(),
  }..removeWhere((value) => value.isEmpty);
  if (productKeys.isEmpty) {
    return null;
  }
  CalculateOrderTemplate? fallback;
  for (final template in templates) {
    if (template.kg <= 0) {
      continue;
    }
    final templateProduct = template.product.trim().toLowerCase();
    final templateItem = template.itemCode.trim().toLowerCase();
    if (!productKeys.contains(templateProduct) &&
        !productKeys.contains(templateItem)) {
      continue;
    }
    if (map.widthMm != null &&
        map.widthMm! > 0 &&
        template.widthMm > 0 &&
        (map.widthMm! - template.widthMm).abs() > 0.5) {
      continue;
    }
    fallback = template;
    if (template.sourceMapId.trim().isNotEmpty) {
      return template;
    }
  }
  return fallback;
}

CalculateRequest _calculateRequestForOrder({
  required ProductionMapDefinition map,
  required CalculateOrderTemplate template,
}) {
  final widthMm = template.widthMm > 0 ? template.widthMm : (map.widthMm ?? 0);
  final frameProductSizeMm = template.frameProductSizeMm > 0
      ? template.frameProductSizeMm
      : (widthMm > kCalculateEdgeAllowanceMm
          ? widthMm - kCalculateEdgeAllowanceMm
          : 0.0);
  final frameCount = template.frameCount > 0 ? template.frameCount : 1.0;
  final kg = template.kg > 0 ? template.kg : (map.orderKg ?? 0);
  return CalculateRequest(
    orderNumber: template.orderNumber.isNotEmpty
        ? template.orderNumber
        : map.orderNumber,
    customer: template.customer,
    product: template.product.isNotEmpty ? template.product : map.title,
    status: template.status,
    materialDisplay: template.materialDisplay,
    color: template.color,
    kg: kg,
    frameProductSizeMm: frameProductSizeMm,
    frameCount: frameCount,
    edgeAllowanceMm: template.edgeAllowanceMm,
    wastePercent: template.wastePercent,
    rollCount: template.rollCount ?? map.rollCount,
    firstLayer: CalculateLayerInput(
      material: template.firstLayerMaterial,
      micron: template.firstLayerMicron,
    ),
    secondLayer: CalculateLayerInput(
      material: template.secondLayerMaterial,
      micron: template.secondLayerMicron,
    ),
    thirdLayer: CalculateLayerInput(
      material: template.thirdLayerMaterial,
      micron: template.thirdLayerMicron,
    ),
    note: template.note,
  );
}

Future<double?> _productionMapBaseMetrajForOrder(
  ProductionMapDefinition map,
  List<CalculateOrderTemplate> templates,
) async {
  final stored = map.baseLength;
  if (stored != null && stored > 0) {
    return stored;
  }
  final template = _calculateTemplateForProductionMap(map, templates);
  if (template == null && (map.orderKg ?? 0) <= 0) {
    return null;
  }
  if (template == null) {
    return _productionMapBaseMetrajFromMapOnly(map);
  }
  return _productionMapBaseMetrajForTemplate(map, template);
}

Future<double?> _productionMapBaseMetrajFromMapOnly(
  ProductionMapDefinition map,
) async {
  final kg = map.orderKg ?? 0;
  final widthMm = map.widthMm ?? 0;
  if (kg <= 0 || widthMm <= 0) {
    return null;
  }
  try {
    final response = await MobileApi.instance.calculate(
      CalculateRequest(
        product: map.title,
        kg: kg,
        frameProductSizeMm: widthMm > kCalculateEdgeAllowanceMm
            ? widthMm - kCalculateEdgeAllowanceMm
            : 0,
        frameCount: 1,
        edgeAllowanceMm: kCalculateEdgeAllowanceMm,
        rollCount: map.rollCount,
        firstLayer: const CalculateLayerInput(),
        secondLayer: const CalculateLayerInput(),
      ),
    );
    if (response.results.isEmpty) {
      return null;
    }
    final base = response.results.first.baseLength;
    return base > 0 ? base : null;
  } catch (_) {
    return null;
  }
}

Future<double?> _productionMapBaseMetrajForTemplate(
  ProductionMapDefinition map,
  CalculateOrderTemplate template,
) async {
  final widthMm = template.widthMm > 0 ? template.widthMm : (map.widthMm ?? 0);
  final kg = template.kg > 0 ? template.kg : (map.orderKg ?? 0);
  if (kg <= 0 || widthMm <= 0) {
    return null;
  }
  try {
    final response = await MobileApi.instance.calculate(
      _calculateRequestForOrder(map: map, template: template),
    );
    if (response.results.isEmpty) {
      return null;
    }
    final base = response.results.first.baseLength;
    return base > 0 ? base : null;
  } catch (_) {
    return null;
  }
}

Future<Map<String, double>> _productionMapBaseMetrajByMapId(
  List<ProductionMapSaved> orders,
  List<CalculateOrderTemplate> templates,
) async {
  final metraj = <String, double>{};
  for (final order in orders) {
    final mapId = order.map.id.trim();
    if (mapId.isEmpty || metraj.containsKey(mapId)) {
      continue;
    }
    final base = await _productionMapBaseMetrajForOrder(order.map, templates);
    if (base != null) {
      metraj[mapId] = base;
    }
  }
  return metraj;
}

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
      if (!_queueSnapshotChanged(queueSnapshot)) {
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

  bool _queueSnapshotChanged(AdminApparatusQueueSnapshot snapshot) {
    if (_sequenceByApparatus.length != snapshot.sequences.length ||
        _queueStatesByApparatus.length != snapshot.queueStates.length ||
        _queuePoliciesByApparatus.length != snapshot.queuePolicies.length) {
      return true;
    }
    for (final entry in snapshot.sequences.entries) {
      final current = _sequenceByApparatus[entry.key];
      if (current == null ||
          current.length != entry.value.length ||
          !_stringListsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.queueStates.entries) {
      final current = _queueStatesByApparatus[entry.key];
      if (current == null || !_stringMapsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.queuePolicies.entries) {
      final current = _queuePoliciesByApparatus[entry.key];
      if (current == null ||
          current.policy != entry.value.policy ||
          current.locked != entry.value.locked) {
        return true;
      }
    }
    return false;
  }

  bool _stringListsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  bool _stringMapsEqual(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  int _ordersRevision(List<ProductionMapSaved> orders) {
    return Object.hashAll(
      orders.map(
        (item) => Object.hash(
          item.map.id,
          item.map.code,
          item.map.orderNumber,
          item.map.title,
          item.map.productCode,
          item.map.rollCount,
          item.map.widthMm,
          item.map.nodes.length,
          Object.hashAll(
            item.map.nodes.map(
              (node) => Object.hash(
                node.id,
                node.kind,
                node.title,
                node.alternativeGroupId,
                node.alternativeAssignedTitle,
              ),
            ),
          ),
          item.map.edges.length,
          Object.hashAll(
            item.map.edges.map(
              (edge) => Object.hash(edge.from, edge.to, edge.branch),
            ),
          ),
        ),
      ),
    );
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

  bool _apparatusTitlesMatch(String left, String right) {
    return productionMapWarehouseTitlesMatch(left, right);
  }

  bool _isAssignedWatchApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final assigned =
        AppSession.instance.profile?.assignedApparatus ?? const <String>[];
    return assigned.any((item) => _apparatusTitlesMatch(title, item));
  }

  Map<String, String> _queueStatesForApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final direct = _queueStatesByApparatus[title];
    if (direct != null) {
      return direct;
    }
    final color = productionMapPechatColorCount(title);
    if (color != null) {
      for (final entry in _queueStatesByApparatus.entries) {
        if (productionMapPechatColorCount(entry.key) == color) {
          return entry.value;
        }
      }
    }
    return const {};
  }

  List<String> _sequenceOrderIdsForApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    final direct = _sequenceByApparatus[title];
    if (direct != null) {
      return direct;
    }
    final color = productionMapPechatColorCount(title);
    if (color != null) {
      for (final entry in _sequenceByApparatus.entries) {
        if (productionMapPechatColorCount(entry.key) == color) {
          return entry.value;
        }
      }
    }
    return const [];
  }

  ApparatusQueuePolicy _queuePolicyForApparatus(AdminWarehouse apparatus) {
    final title = apparatus.warehouse.trim();
    if (productionMapPechatColorCount(title) != null) {
      return ApparatusQueuePolicy.strictSequence;
    }
    final direct = _queuePoliciesByApparatus[title];
    if (direct != null) {
      return direct.policy;
    }
    for (final entry in _queuePoliciesByApparatus.entries) {
      if (productionMapWarehouseTitlesMatch(entry.key, title)) {
        return entry.value.policy;
      }
    }
    return ApparatusQueuePolicy.strictSequence;
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
        initialQueueStates: _queueStatesForApparatus(apparatus),
        queueStatesByApparatus: _queueStatesByApparatus,
        queuePolicy: _queuePolicyForApparatus(apparatus),
        sequenceOrderIds: _sequenceOrderIdsForApparatus(apparatus),
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
    final sequence = _sequenceOrderIdsForApparatus(apparatus);
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
      final states = _queueStatesForApparatus(apparatus);
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
                    queueStates: _queueStatesForApparatus(tab.apparatus!),
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

class _OrdersModulePage extends StatefulWidget {
  const _OrdersModulePage({
    required this.bottomPadding,
    required this.orders,
    required this.visibleOrders,
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
  });

  final double bottomPadding;
  final List<ProductionMapSaved> orders;
  final List<ProductionMapSaved> visibleOrders;
  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;

  @override
  State<_OrdersModulePage> createState() => _OrdersModulePageState();
}

class _OrdersModulePageState extends State<_OrdersModulePage> {
  String? _expandedOrderId;

  void _onExpandedChanged(ProductionMapSaved order, bool expanded) {
    setState(() {
      _expandedOrderId = expanded ? order.map.id.trim() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        widget.bottomPadding,
      ),
      children: [
        if (widget.orders.isEmpty)
          const _EmptyOpenedOrders(message: 'Ochilgan zakaz yo‘q')
        else if (widget.visibleOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Zakaz topilmadi')
        else
          _OpenedOrderExpandableList(
            orders: widget.visibleOrders,
            expandedOrderId: _expandedOrderId,
            baseMetrajByMapId: widget.baseMetrajByMapId,
            orderKgByMapId: widget.orderKgByMapId,
            onExpandedChanged: _onExpandedChanged,
          ),
      ],
    );
  }
}

class _AparatchiWatchSequencePage extends StatelessWidget {
  const _AparatchiWatchSequencePage({
    required this.apparatus,
    required this.orders,
    required this.bottomPadding,
    required this.isAssigned,
    required this.queueStates,
    required this.onTapOrder,
  });

  final AdminWarehouse apparatus;
  final List<ProductionMapSaved> orders;
  final double bottomPadding;
  final bool isAssigned;
  final Map<String, String> queueStates;
  final ValueChanged<ProductionMapSaved> onTapOrder;

  Color? _cardBackground(ApparatusQueueOrderState state) {
    return switch (state) {
      ApparatusQueueOrderState.inProgress => const Color(0xFFFFECB3),
      ApparatusQueueOrderState.paused => const Color(0xFFFFCDD2),
      ApparatusQueueOrderState.completed => const Color(0xFFC8E6C9),
      ApparatusQueueOrderState.pending => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _openedOrderPanelCardGap,
          _openedOrderPanelTopGap,
          _openedOrderPanelCardGap,
          bottomPadding,
        ),
        children: [
          if (isAssigned)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Sizning aparatingiz',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (orders.isEmpty)
            _EmptyOpenedOrders(
                message: '${apparatus.warehouse} uchun zakaz yo‘q')
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  _SequenceExpandableOrderRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      orders.length,
                    ),
                    order: orders[index],
                    index: index,
                    readOnly: true,
                    expanded: false,
                    baseMetraj: orders[index].map.baseLength,
                    orderKg: orders[index].map.orderKg,
                    onExpandedChanged: (_) {},
                    expandable: false,
                    onTap: () => onTapOrder(orders[index]),
                    backgroundColor: _cardBackground(
                      apparatusQueueOrderStateFromRaw(
                        queueStates[orders[index].map.id.trim()],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AparatchiCompletedOrdersPage extends StatelessWidget {
  const _AparatchiCompletedOrdersPage({
    required this.orders,
    required this.bottomPadding,
    required this.onTapOrder,
  });

  final List<_WorkerCompletedOrderEntry> orders;
  final double bottomPadding;
  final ValueChanged<_WorkerCompletedOrderEntry> onTapOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _openedOrderPanelCardGap,
          _openedOrderPanelTopGap,
          _openedOrderPanelCardGap,
          bottomPadding,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'Tugallangan zakazlar',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (orders.isEmpty)
            const _EmptyOpenedOrders(message: 'Tugallangan zakaz yo‘q')
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  _SequenceExpandableOrderRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      orders.length,
                    ),
                    order: orders[index].order,
                    index: index,
                    readOnly: true,
                    expanded: false,
                    baseMetraj: orders[index].order.map.baseLength,
                    orderKg: orders[index].order.map.orderKg,
                    onExpandedChanged: (_) {},
                    expandable: false,
                    onTap: () => onTapOrder(orders[index]),
                    backgroundColor: const Color(0xFFC8E6C9),
                  ),
              ],
            ),
        ],
      ),
    );
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

  Map<String, String> _queueStatesForStation(
    String station,
    Map<String, Map<String, String>> queueStatesByApparatus,
  ) {
    final direct = queueStatesByApparatus[station];
    if (direct != null) {
      return direct;
    }
    for (final entry in queueStatesByApparatus.entries) {
      if (productionMapWarehouseTitlesMatch(entry.key, station)) {
        return entry.value;
      }
    }
    return const {};
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
    final materialAssignments = _stationMaterialAssignments();
    if (action == 'start' &&
        materialAssignments.isNotEmpty &&
        !_allMaterialsScanned(materialAssignments)) {
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
    final materialAssignments = _stationMaterialAssignments();
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
    if (_allMaterialsScanned(materialAssignments)) {
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

  List<AdminRawMaterialAssignment> _stationMaterialAssignments() {
    final orderId = widget.order.map.id.trim();
    final station = widget.apparatus?.warehouse.trim() ?? '';
    final result = _materialAssignments.where((assignment) {
      if (assignment.orderId.trim() != orderId) {
        return false;
      }
      if (station.isEmpty) {
        return true;
      }
      return productionMapWarehouseTitlesMatch(assignment.apparatus, station);
    }).toList();
    result.sort((left, right) {
      final leftTitle =
          left.itemName.trim().isEmpty ? left.itemCode : left.itemName;
      final rightTitle =
          right.itemName.trim().isEmpty ? right.itemCode : right.itemName;
      return leftTitle.toLowerCase().compareTo(rightTitle.toLowerCase());
    });
    return result;
  }

  bool _allMaterialsScanned(List<AdminRawMaterialAssignment> assignments) {
    if (assignments.isEmpty) {
      return true;
    }
    return assignments.every(_materialAssignmentConfirmed);
  }

  bool _materialAssignmentConfirmed(AdminRawMaterialAssignment assignment) {
    if (_scannedMaterialBarcodes
        .contains(_materialBarcodeKey(assignment.barcode))) {
      return true;
    }
    final stockStatus = assignment.stockStatus.trim().toLowerCase();
    final reservedOrderId = assignment.reservedOrderId.trim();
    final orderId = widget.order.map.id.trim();
    return reservedOrderId == orderId &&
        (stockStatus == 'in_use' || stockStatus == 'consumed');
  }

  String _materialBarcodeKey(String value) => value.trim().toUpperCase();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = widget.order.map;
    final steps = _linearProductionMapNodes(map);
    final orderId = map.id.trim();
    final station = widget.apparatus?.warehouse.trim() ?? '';
    final queueState = apparatusQueueOrderStateFromRaw(_queueStates[orderId]);
    final materialAssignments = _stationMaterialAssignments();
    final hasMaterialAssignments = materialAssignments.isNotEmpty;
    final allMaterialsScanned = _allMaterialsScanned(materialAssignments);
    final confirmedMaterialBarcodes = {
      for (final assignment in materialAssignments)
        if (_materialAssignmentConfirmed(assignment))
          _materialBarcodeKey(assignment.barcode),
    };
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
              _orderDetailSurfaceCard(
                context: context,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => _mapExpanded = !_mapExpanded),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              color: scheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mapni ko‘rish',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _mapProgressSummary(
                                      steps: steps,
                                      orderId: orderId,
                                      currentStation: station,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: _mapExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _mapExpanded
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    children: [
                                      for (var index = 0;
                                          index < steps.length;
                                          index++) ...[
                                        _SequenceStepTile(
                                          node: steps[index],
                                          index: index,
                                          isLast: index == steps.length - 1,
                                          status: _nodeStatus(
                                            steps[index],
                                            orderId: orderId,
                                            currentStation: station,
                                          ),
                                          current: _nodeMatchesStation(
                                            steps[index],
                                            station,
                                          ),
                                          isDone: _mapStepIsDone(
                                            steps: steps,
                                            index: index,
                                            orderId: orderId,
                                            currentStation: station,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _productTitle(ProductionMapDefinition map) {
    for (final node in map.nodes) {
      final title = node.title.trim();
      if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
        return title;
      }
    }
    return map.title;
  }

  ApparatusQueueOrderState? _nodeStatus(
    ProductionMapNode node, {
    required String orderId,
    required String currentStation,
  }) {
    if (node.kind != 'apparatus') {
      return null;
    }
    final station = _nodeStationTitle(node);
    if (station.isEmpty) {
      return null;
    }
    if (_nodeMatchesStation(node, currentStation)) {
      return apparatusQueueOrderStateFromRaw(_queueStates[orderId]);
    }
    for (final entry in widget.queueStatesByApparatus.entries) {
      if (productionMapWarehouseTitlesMatch(entry.key, station)) {
        return apparatusQueueOrderStateFromRaw(entry.value[orderId]);
      }
    }
    return ApparatusQueueOrderState.pending;
  }

  bool _nodeMatchesStation(ProductionMapNode node, String station) {
    return station.trim().isNotEmpty &&
        productionMapWarehouseTitlesMatch(_nodeStationTitle(node), station);
  }

  int _mapCurrentStepIndex(
    List<ProductionMapNode> steps,
    String currentStation,
  ) {
    if (currentStation.trim().isEmpty) {
      return -1;
    }
    return steps.indexWhere(
      (node) => _nodeMatchesStation(node, currentStation),
    );
  }

  bool _mapStepIsPast({
    required List<ProductionMapNode> steps,
    required int index,
    required String currentStation,
  }) {
    final currentIndex = _mapCurrentStepIndex(steps, currentStation);
    return currentIndex >= 0 && index < currentIndex;
  }

  bool _mapStepIsDone({
    required List<ProductionMapNode> steps,
    required int index,
    required String orderId,
    required String currentStation,
  }) {
    if (_mapStepIsPast(
      steps: steps,
      index: index,
      currentStation: currentStation,
    )) {
      return true;
    }
    final status = _nodeStatus(
      steps[index],
      orderId: orderId,
      currentStation: currentStation,
    );
    return status == ApparatusQueueOrderState.completed;
  }

  String _mapProgressSummary({
    required List<ProductionMapNode> steps,
    required String orderId,
    required String currentStation,
  }) {
    var completed = 0;
    for (var index = 0; index < steps.length; index++) {
      if (_mapStepIsDone(
        steps: steps,
        index: index,
        orderId: orderId,
        currentStation: currentStation,
      )) {
        completed++;
      }
    }
    return '$completed / ${steps.length} bosqich';
  }

  String _nodeStationTitle(ProductionMapNode node) {
    final assigned = node.alternativeAssignedTitle.trim();
    if (assigned.isNotEmpty) {
      return assigned;
    }
    return node.title.trim();
  }
}

Widget _orderDetailSurfaceCard({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
}) {
  final scheme = Theme.of(context).colorScheme;
  return Material(
    color: scheme.surface,
    elevation: 2,
    shadowColor: scheme.shadow.withValues(alpha: 0.16),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class _OrderStartUnifiedCard extends StatelessWidget {
  const _OrderStartUnifiedCard({
    required this.orderCode,
    required this.productTitle,
    required this.assignments,
    required this.materialsLoading,
    required this.materialsError,
    required this.scannedBarcodes,
    required this.scannedCount,
    required this.showStart,
    required this.hasMaterialAssignments,
    required this.allMaterialsScanned,
    required this.actionInFlight,
    required this.showPause,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
    required this.previousStage,
    required this.previousProgressRequired,
    required this.previousProgressReady,
    required this.previousProgressBatch,
    required this.onScan,
    required this.onProgressScan,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onResume,
  });

  final String orderCode;
  final String productTitle;
  final List<AdminRawMaterialAssignment> assignments;
  final bool materialsLoading;
  final String materialsError;
  final Set<String> scannedBarcodes;
  final int scannedCount;
  final bool showStart;
  final bool hasMaterialAssignments;
  final bool allMaterialsScanned;
  final bool actionInFlight;
  final bool showPause;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;
  final String? previousStage;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final AdminProgressBatch? previousProgressBatch;
  final VoidCallback onScan;
  final VoidCallback? onProgressScan;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalCount = assignments.length;
    final hasActions = showStart ||
        showPause ||
        showComplete ||
        showResume ||
        showWaitingForPrevious;

    return _orderDetailSurfaceCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zakaz kodi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderCode.trim().isEmpty ? '-' : orderCode.trim(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mahsulot',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      productTitle.trim().isEmpty ? '-' : productTitle.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
              height: 28, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Biriktirilgan homashyolar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!materialsLoading &&
                  materialsError.trim().isEmpty &&
                  totalCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scannedCount == totalCount
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$scannedCount/$totalCount',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scannedCount == totalCount
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (materialsLoading)
            Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Yuklanmoqda',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (materialsError.trim().isNotEmpty)
            Text(
              materialsError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (assignments.isEmpty)
            Text(
              'Homashyo biriktirilmagan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < assignments.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _AssignedMaterialTile(
                    assignment: assignments[index],
                    scanned: scannedBarcodes.contains(
                      assignments[index].barcode.trim().toUpperCase(),
                    ),
                  ),
                ],
              ],
            ),
          if (hasActions) ...[
            Divider(
                height: 28,
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
            if (showStart && hasMaterialAssignments)
              FilledButton.tonalIcon(
                onPressed:
                    actionInFlight || allMaterialsScanned ? null : onScan,
                icon: Icon(
                  allMaterialsScanned
                      ? Icons.check_circle_rounded
                      : Icons.qr_code_scanner_rounded,
                ),
                label: Text(
                  allMaterialsScanned
                      ? 'Homashyolar tasdiqlandi'
                      : 'Homashyo QR scan',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (showStart && hasMaterialAssignments) const SizedBox(height: 10),
            if (showStart && previousProgressRequired) ...[
              _PreviousProgressQrTile(
                previousStage: previousStage ?? '',
                ready: previousProgressReady,
                batch: previousProgressBatch,
                actionInFlight: actionInFlight,
                onScan: onProgressScan,
              ),
              const SizedBox(height: 10),
            ],
            if (showStart)
              FilledButton.icon(
                onPressed: actionInFlight ||
                        (hasMaterialAssignments && !allMaterialsScanned) ||
                        !previousProgressReady
                    ? null
                    : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Boshlash'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (showPause || showComplete) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: actionInFlight ? null : onPause,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Pauza'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: actionInFlight ? null : onComplete,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Tugatish'),
                    ),
                  ),
                ],
              ),
            ],
            if (showResume) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: actionInFlight ? null : onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Davom ettirish'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            if (showWaitingForPrevious && previousStage != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Oldingi bosqich tugallanguncha kutilmoqda: $previousStage',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

String _apparatusDetailLabel(String apparatus) {
  return productionMapIsLaminatsiyaApparatus(apparatus)
      ? 'Laminatsiya mashinasi'
      : productionMapIsRezkaApparatus(apparatus)
          ? 'Rezka mashinasi'
          : 'Aparat';
}
