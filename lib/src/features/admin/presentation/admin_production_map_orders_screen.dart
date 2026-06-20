import 'dart:async';
import 'dart:convert';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/test_mode/test_mode_controller.dart';
import '../../../core/theme/app_theme.dart';
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
import 'package:http/http.dart' as http;

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

String _openedOrderDisplayCode(ProductionMapDefinition map) {
  final code = map.code.trim();
  if (code.isNotEmpty) {
    return code;
  }
  final orderNumber = map.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = map.id.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return '';
}

String _openedOrderPrimaryTitle(ProductionMapDefinition map) {
  final title = map.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  final product = _openedOrderProductTitle(map);
  if (product.isNotEmpty) {
    return product;
  }
  return 'Zakaz';
}

String _openedOrderProductTitle(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    final title = node.title.trim();
    if (node.kind == 'end' && title.isNotEmpty && title != map.title.trim()) {
      return title;
    }
  }
  return '';
}

String _openedOrderSubtitle(
  ProductionMapDefinition map, {
  bool includeApparatusCount = false,
}) {
  final productTitle = _openedOrderProductTitle(map);
  final apparatusCount =
      map.nodes.where((node) => node.kind == 'apparatus').length;
  return [
    if (productTitle.isNotEmpty) productTitle,
    if (map.productCode.trim().isNotEmpty) map.productCode.trim(),
    if (includeApparatusCount && apparatusCount > 0)
      '$apparatusCount ta aparat',
  ].join(' • ');
}

String _closedOrderDisplayCode(AdminClosedProductionOrder order) {
  final orderNumber = order.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = order.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _completionRequestDisplayCode(
  AdminCompletionRequestNotification request,
) {
  final orderNumber = request.orderNumber.trim();
  if (orderNumber.isNotEmpty) {
    return orderNumber;
  }
  final id = request.orderId.trim();
  const prefix = 'zakaz-';
  if (id.startsWith(prefix)) {
    final suffix = id.substring(prefix.length).trim();
    if (suffix.isNotEmpty) {
      return suffix;
    }
  }
  return id;
}

String _closedOrderTitle(AdminClosedProductionOrder order) {
  final title = order.title.trim();
  if (title.isNotEmpty) {
    return title;
  }
  return 'Zakaz';
}

String _closedActorLabel({
  required String displayName,
  required String role,
  required String ref,
}) {
  final display = displayName.trim();
  if (display.isNotEmpty) {
    return display;
  }
  final actorRef = ref.trim();
  if (actorRef.isNotEmpty) {
    return actorRef;
  }
  final actorRole = role.trim();
  if (actorRole.isNotEmpty) {
    return actorRole;
  }
  return 'Noma’lum ijrochi';
}

String _closedLogActionLabel(String action) {
  return switch (action.trim()) {
    'start' => 'Boshladi',
    'pause' => 'Pauza qildi',
    'resume' => 'Davom ettirdi',
    'complete' => 'Tugatdi',
    final value when value.isNotEmpty => value,
    _ => 'Harakat',
  };
}

String _closedLogTitle(AdminProductionOrderLogEntry log) {
  if (log.completedWithIssue) {
    final note = log.issueNote.trim();
    return note.isNotEmpty ? note : 'Muammo bilan yopildi';
  }
  return _closedLogActionLabel(log.action);
}

String _closedLogStateLabel(AdminProductionOrderLogEntry log) {
  final from = log.fromState.trim();
  final to = log.toState.trim();
  if (from.isNotEmpty && to.isNotEmpty) {
    return '$from → $to';
  }
  if (to.isNotEmpty) {
    return to;
  }
  return from;
}

String _closedLogTimeLabel(int unixSeconds) {
  if (unixSeconds <= 0) {
    return '';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

List<ProductionMapNode> _linearProductionMapNodes(ProductionMapDefinition map) {
  final byId = {for (final node in map.nodes) node.id: node};
  final byFrom = <String, List<ProductionMapEdge>>{};
  for (final edge in map.edges) {
    byFrom.putIfAbsent(edge.from, () => <ProductionMapEdge>[]).add(edge);
  }
  final start = map.nodes
      .where((node) => node.kind == 'start')
      .map((node) => node.id)
      .cast<String?>()
      .firstWhere((id) => id != null, orElse: () => null);
  if (start == null || !byId.containsKey(start)) {
    return map.nodes;
  }
  final result = <ProductionMapNode>[];
  final seen = <String>{};
  var current = start;
  while (seen.add(current)) {
    final node = byId[current];
    if (node != null) {
      result.add(node);
    }
    final next = byFrom[current]
        ?.map((edge) => edge.to)
        .where((id) => byId.containsKey(id))
        .cast<String?>()
        .firstWhere((id) => id != null, orElse: () => null);
    if (next == null) {
      break;
    }
    current = next;
  }
  return result.isEmpty ? map.nodes : result;
}

String _productionMapNodeDisplayTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  if (assigned.isNotEmpty) {
    return assigned;
  }
  return node.title.trim();
}

String _productionMapResultSummary(
  ProductionMapDefinition map, {
  double? baseMetraj,
  double? orderKg,
}) {
  final product = _openedOrderProductTitle(map);
  final title = product.isNotEmpty ? product : map.title.trim();
  if (title.isEmpty) {
    return '';
  }
  final details = <String>[];
  if (orderKg != null && orderKg > 0) {
    details.add('${_productionMapQtyLabel(orderKg)} kg');
  }
  if (baseMetraj != null && baseMetraj > 0) {
    details.add('${_productionMapMetrajLabel(baseMetraj)} m metraj');
  }
  final rollCount = map.rollCount;
  if (rollCount != null && rollCount > 0) {
    details.add('${_productionMapQtyLabel(rollCount)} rulon');
  }
  final widthMm = map.widthMm;
  if (widthMm != null && widthMm > 0) {
    details.add('${_productionMapQtyLabel(widthMm)} mm en');
  }
  if (map.productCode.trim().isNotEmpty) {
    details.add(map.productCode.trim());
  }
  if (details.isEmpty) {
    return '$title tayyor bo‘ladi';
  }
  return '$title tayyor bo‘ladi (${details.join(', ')})';
}

String _productionMapQtyLabel(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

String _productionMapMetrajLabel(double value) {
  return value.toStringAsFixed(1);
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
        isOrderReadyForStation: (orderId) {
          final match = _orders
              .where((item) => item.map.id.trim() == orderId.trim())
              .cast<ProductionMapSaved?>()
              .firstWhere((item) => item != null, orElse: () => null);
          if (match == null) {
            return true;
          }
          return productionMapOrderReadyForStation(
            map: match.map,
            orderId: orderId,
            station: apparatus.warehouse.trim(),
            queueStatesByApparatus: _queueStatesByApparatus,
          );
        },
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

class _ClosedOrdersModulePage extends StatelessWidget {
  const _ClosedOrdersModulePage({
    required this.bottomPadding,
    required this.closedOrders,
    required this.visibleClosedOrders,
  });

  final double bottomPadding;
  final List<AdminClosedProductionOrder> closedOrders;
  final List<AdminClosedProductionOrder> visibleClosedOrders;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        bottomPadding,
      ),
      children: [
        if (closedOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Yopilgan zakaz yo‘q')
        else if (visibleClosedOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Zakaz topilmadi')
        else
          M3SegmentSpacedColumn(
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < visibleClosedOrders.length; index++)
                _ClosedOrderTile(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    visibleClosedOrders.length,
                  ),
                  order: visibleClosedOrders[index],
                  index: index,
                ),
            ],
          ),
      ],
    );
  }
}

class _ClosedOrderTile extends StatelessWidget {
  const _ClosedOrderTile({
    required this.slot,
    required this.order,
    required this.index,
  });

  final M3SegmentVerticalSlot slot;
  final AdminClosedProductionOrder order;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _closedOrderDisplayCode(order);
    final title = _closedOrderTitle(order);
    final closedBy = _closedActorLabel(
      displayName: order.closedByDisplayName,
      role: order.closedByRole,
      ref: order.closedByRef,
    );
    final closedAt = _closedLogTimeLabel(order.completedAtUnix);
    final subtitle = [
      if (order.productCode.trim().isNotEmpty) order.productCode.trim(),
      if (closedBy.isNotEmpty) 'Yopdi: $closedBy',
      if (closedAt.isNotEmpty) closedAt,
    ].join(' • ');
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: _OpenedOrderIndexBadge(index: index),
          title: Text(
            code.isEmpty ? title : '$code • $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.15,
                  ),
                ),
          children: [
            if (order.logs.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Log yo‘q',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              _ClosedOrderLogList(logs: order.logs),
          ],
        ),
      ),
    );
  }
}

class _ClosedOrderLogList extends StatelessWidget {
  const _ClosedOrderLogList({required this.logs});

  final List<AdminProductionOrderLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < logs.length; index++) ...[
          if (index > 0) const Divider(height: 16),
          _ClosedOrderLogRow(log: logs[index]),
        ],
      ],
    );
  }
}

class _ClosedOrderLogRow extends StatelessWidget {
  const _ClosedOrderLogRow({required this.log});

  final AdminProductionOrderLogEntry log;

  IconData get _icon {
    return switch (log.action.trim()) {
      'start' => Icons.play_arrow_rounded,
      'pause' => Icons.pause_rounded,
      'resume' => Icons.replay_rounded,
      'complete' => Icons.check_rounded,
      _ => Icons.history_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = _closedActorLabel(
      displayName: log.actorDisplayName,
      role: log.actorRole,
      ref: log.actorRef,
    );
    final state = _closedLogStateLabel(log);
    final time = _closedLogTimeLabel(log.createdAtUnix);
    final apparatus = log.apparatus.trim();
    final subtitle = [
      actor,
      if (state.isNotEmpty) state,
      if (time.isNotEmpty) time,
    ].join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: scheme.onSecondaryContainer),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  _closedLogTitle(log),
                  if (apparatus.isNotEmpty) apparatus,
                ].join(' • '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.15,
                ),
              ),
            ],
          ),
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

class _SequenceModulePage extends StatefulWidget {
  const _SequenceModulePage({
    required this.bottomPadding,
    required this.apparatus,
    required this.completionRequests,
    required this.orders,
    required this.readOnly,
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
    required this.onPickApparatus,
    required this.onReorder,
  });

  final double bottomPadding;
  final AdminWarehouse? apparatus;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<ProductionMapSaved> orders;
  final bool readOnly;
  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
  final VoidCallback onPickApparatus;
  final ReorderCallback onReorder;

  @override
  State<_SequenceModulePage> createState() => _SequenceModulePageState();
}

class _SequenceModulePageState extends State<_SequenceModulePage> {
  String? _expandedOrderId;
  String? _expandedCompletionRequestId;

  void _onExpandedChanged(ProductionMapSaved order, bool expanded) {
    setState(() {
      _expandedOrderId = expanded ? order.map.id.trim() : null;
    });
  }

  void _onCompletionRequestExpandedChanged(
    AdminCompletionRequestNotification request,
    bool expanded,
  ) {
    setState(() {
      _expandedCompletionRequestId = expanded ? request.eventId.trim() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.apparatus;
    final orders = widget.orders;
    final notifications = widget.completionRequests;
    final notificationSection = notifications.isEmpty
        ? const SizedBox.shrink()
        : _CompletionRequestsSection(
            requests: notifications,
            expandedRequestId: _expandedCompletionRequestId,
            onExpandedChanged: _onCompletionRequestExpandedChanged,
          );

    Widget buildOrderRow({
      required int index,
      required ProductionMapSaved order,
      required Key key,
    }) {
      final mapId = order.map.id.trim();
      return _SequenceExpandableOrderRow(
        key: key,
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
          index,
          orders.length,
        ),
        order: order,
        index: index,
        readOnly: widget.readOnly,
        expanded: _expandedOrderId == mapId,
        baseMetraj: widget.baseMetrajByMapId[mapId] ?? order.map.baseLength,
        orderKg: widget.orderKgByMapId[mapId] ?? order.map.orderKg,
        onExpandedChanged: (expanded) => _onExpandedChanged(order, expanded),
      );
    }

    if (!widget.readOnly && selected != null && orders.isNotEmpty) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _openedOrderPanelCardGap,
                _openedOrderPanelTopGap,
                _openedOrderPanelCardGap,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  notificationSection,
                  if (notifications.isNotEmpty) const SizedBox(height: 12),
                  _SequenceHeaderSelectors(
                    apparatus: selected,
                    orderCount: orders.length,
                    onPickApparatus: widget.onPickApparatus,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                key: ValueKey(
                  'sequence-list-${selected.warehouse}-'
                  '${orders.map((order) => order.map.id).join(',')}',
                ),
                padding: EdgeInsets.fromLTRB(
                  _openedOrderPanelCardGap,
                  8,
                  _openedOrderPanelCardGap,
                  widget.bottomPadding,
                ),
                buildDefaultDragHandles: false,
                itemCount: orders.length,
                onReorderItem: widget.onReorder,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Padding(
                    key: ValueKey(
                      'sequence-${selected.warehouse}-${order.map.id}',
                    ),
                    padding: EdgeInsets.only(
                      bottom: index < orders.length - 1
                          ? M3SegmentedListGeometry.gap
                          : 0,
                    ),
                    child: buildOrderRow(
                      index: index,
                      order: order,
                      key: ValueKey(
                        'sequence-row-${selected.warehouse}-${order.map.id}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _openedOrderPanelCardGap,
          _openedOrderPanelTopGap,
          _openedOrderPanelCardGap,
          widget.bottomPadding,
        ),
        children: [
          notificationSection,
          if (notifications.isNotEmpty) const SizedBox(height: 12),
          _SequenceHeaderSelectors(
            apparatus: selected,
            orderCount: orders.length,
            onPickApparatus: widget.onPickApparatus,
          ),
          if (selected == null)
            const _EmptyOpenedOrders(message: 'Avval aparat tanlang')
          else if (orders.isEmpty)
            _EmptyOpenedOrders(
              message: '${selected.warehouse} uchun zakaz yo‘q',
            )
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  buildOrderRow(
                    index: index,
                    order: orders[index],
                    key: ValueKey(
                      'sequence-static-${selected.warehouse}-'
                      '${orders[index].map.id}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CompletionRequestsSection extends StatelessWidget {
  const _CompletionRequestsSection({
    required this.requests,
    required this.expandedRequestId,
    required this.onExpandedChanged,
  });

  final List<AdminCompletionRequestNotification> requests;
  final String? expandedRequestId;
  final void Function(AdminCompletionRequestNotification request, bool expanded)
      onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            requests.any((request) => !request.decisionRequired)
                ? 'Bildirishnomalar'
                : 'Tugatish so‘rovlari',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        M3SegmentSpacedColumn(
          padding: EdgeInsets.zero,
          children: [
            for (var index = 0; index < requests.length; index++)
              _CompletionRequestRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index,
                  requests.length,
                ),
                request: requests[index],
                expanded: expandedRequestId == requests[index].eventId.trim(),
                onExpandedChanged: (expanded) =>
                    onExpandedChanged(requests[index], expanded),
              ),
          ],
        ),
      ],
    );
  }
}

class _CompletionRequestRow extends StatelessWidget {
  const _CompletionRequestRow({
    required this.slot,
    required this.request,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final M3SegmentVerticalSlot slot;
  final AdminCompletionRequestNotification request;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    final code = _completionRequestDisplayCode(request);
    final worker = _closedActorLabel(
      displayName: request.workerDisplayName,
      role: request.workerRole,
      ref: request.workerRef,
    );
    final decisionRequired = request.decisionRequired;
    final title = decisionRequired
        ? '$code zakaz 0 holatda'
        : '$code laminatsiya qoldig‘i';
    final subtitle = decisionRequired
        ? '${request.apparatus} dagi $worker tugatishga urinyapti'
        : '${request.apparatus} dagi $worker ikkala qavat qoldig‘ini yozdi';

    return Material(
      color:
          (decisionRequired ? scheme.errorContainer : scheme.secondaryContainer)
              .withValues(alpha: 0.32),
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          decisionRequired
                              ? Icons.priority_high_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: decisionRequired
                              ? scheme.onErrorContainer
                              : scheme.onSecondaryContainer,
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
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: scheme.onSurfaceVariant,
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
                ? _CompletionRequestDetail(request: request)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CompletionRequestDetail extends StatelessWidget {
  const _CompletionRequestDetail({required this.request});

  final AdminCompletionRequestNotification request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = <String>[
      if (request.orderTitle.trim().isNotEmpty)
        'Mahsulot: ${request.orderTitle.trim()}',
      if (request.productCode.trim().isNotEmpty)
        'Kod: ${request.productCode.trim()}',
      '${_apparatusDetailLabel(request.apparatus)}: ${request.apparatus.trim()}',
      'Ishchi: ${_closedActorLabel(
        displayName: request.workerDisplayName,
        role: request.workerRole,
        ref: request.workerRef,
      )}',
      if (_closedLogTimeLabel(request.createdAtUnix).isNotEmpty)
        'Vaqt: ${_closedLogTimeLabel(request.createdAtUnix)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 58, right: 12, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            request.description.trim(),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SequenceHeaderSelectors extends StatelessWidget {
  const _SequenceHeaderSelectors({
    required this.apparatus,
    required this.orderCount,
    required this.onPickApparatus,
  });

  final AdminWarehouse? apparatus;
  final int orderCount;
  final VoidCallback onPickApparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = apparatus?.warehouse.trim().isNotEmpty == true
        ? apparatus!.warehouse.trim()
        : 'Aparat tanlang';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surface,
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPickApparatus,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                        Icons.precision_manufacturing_rounded,
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (orderCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$orderCount ta zakaz',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.05,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (orderCount > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Tartibni o‘zgartirish uchun zakazni ushlab torting',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _SequenceExpandableOrderRow extends StatelessWidget {
  const _SequenceExpandableOrderRow({
    super.key,
    required this.slot,
    required this.order,
    required this.index,
    required this.readOnly,
    required this.expanded,
    required this.baseMetraj,
    required this.orderKg,
    required this.onExpandedChanged,
    this.backgroundColor,
    this.onTap,
    this.expandable = true,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final int index;
  final bool readOnly;
  final bool expanded;
  final double? baseMetraj;
  final double? orderKg;
  final ValueChanged<bool> onExpandedChanged;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(map);
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: backgroundColor ?? scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: expandable ? () => onExpandedChanged(!expanded) : onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    _OpenedOrderIndexBadge(index: index),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _OpenedOrderTitleLine(
                            map: map,
                            theme: theme,
                            scheme: scheme,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!readOnly)
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (expandable)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          if (expandable)
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _OpenedOrderWorkflowDetail(
                      map: map,
                      baseMetraj: baseMetraj,
                      orderKg: orderKg,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _MoveModulePage extends StatefulWidget {
  const _MoveModulePage({
    required this.topApparatus,
    required this.bottomApparatus,
    required this.topOrders,
    required this.bottomOrders,
    required this.selectedOrderIds,
    required this.draggingOrders,
    required this.draggingSource,
    required this.canMoveTo,
    required this.onPickTop,
    required this.onPickBottom,
    required this.onToggleSelect,
    required this.buildDragPayload,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });

  final AdminWarehouse? topApparatus;
  final AdminWarehouse? bottomApparatus;
  final List<ProductionMapSaved> topOrders;
  final List<ProductionMapSaved> bottomOrders;
  final Set<String> selectedOrderIds;
  final List<ProductionMapSaved> draggingOrders;
  final AdminWarehouse? draggingSource;
  final bool Function(
    ProductionMapSaved order,
    AdminWarehouse target,
    AdminWarehouse source,
  ) canMoveTo;
  final VoidCallback onPickTop;
  final VoidCallback onPickBottom;
  final ValueChanged<String> onToggleSelect;
  final _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) buildDragPayload;
  final ValueChanged<_MoveDragPayload> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) onMove;

  @override
  State<_MoveModulePage> createState() => _MoveModulePageState();
}

class _MoveModulePageState extends State<_MoveModulePage> {
  double _topZoneRatio = 0.5;

  AdminWarehouse? get topApparatus => widget.topApparatus;
  AdminWarehouse? get bottomApparatus => widget.bottomApparatus;
  List<ProductionMapSaved> get topOrders => widget.topOrders;
  List<ProductionMapSaved> get bottomOrders => widget.bottomOrders;
  Set<String> get selectedOrderIds => widget.selectedOrderIds;
  List<ProductionMapSaved> get draggingOrders => widget.draggingOrders;
  AdminWarehouse? get draggingSource => widget.draggingSource;
  bool Function(
    ProductionMapSaved order,
    AdminWarehouse target,
    AdminWarehouse source,
  ) get canMoveTo => widget.canMoveTo;
  VoidCallback get onPickTop => widget.onPickTop;
  VoidCallback get onPickBottom => widget.onPickBottom;
  ValueChanged<String> get onToggleSelect => widget.onToggleSelect;
  _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) get buildDragPayload => widget.buildDragPayload;
  ValueChanged<_MoveDragPayload> get onDragStarted => widget.onDragStarted;
  VoidCallback get onDragEnded => widget.onDragEnded;
  Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) get onMove => widget.onMove;

  void _resizeMoveZones(double delta, double availableHeight) {
    if (!availableHeight.isFinite || availableHeight <= 0) {
      return;
    }
    final next = (_topZoneRatio + delta / availableHeight).clamp(0.24, 0.76);
    if (next == _topZoneRatio) {
      return;
    }
    setState(() => _topZoneRatio = next);
  }

  @override
  Widget build(BuildContext context) {
    final top = topApparatus;
    final bottom = bottomApparatus;
    if (top == null || bottom == null) {
      return const _EmptyOpenedOrders(message: 'Ko‘chirish uchun aparat yo‘q');
    }
    final viewMetrics = MediaQueryData.fromView(View.of(context));
    final dockInset = dockLayoutBottomInset(
      viewMetrics,
      thinGestureBottom: DockGestureOverlayScope.thinGestureBottomOf(context),
    );
    final bottomInset = 60 + dockInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        bottomInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.7;
          final topFlex = (_topZoneRatio.clamp(0.24, 0.76) * 1000).round();
          final bottomFlex = 1000 - topFlex;
          return Column(
            children: [
              Expanded(
                flex: topFlex,
                child: Column(
                  children: [
                    _MoveApparatusHeader(
                      key: const ValueKey('move-top-apparatus-picker'),
                      apparatus: top,
                      alignment: Alignment.center,
                      onTap: onPickTop,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _MoveDropZone(
                        apparatus: top,
                        orders: topOrders,
                        selectedOrderIds: selectedOrderIds,
                        draggingOrders: draggingOrders,
                        draggingSource: draggingSource,
                        canMoveTo: canMoveTo,
                        onToggleSelect: onToggleSelect,
                        buildDragPayload: buildDragPayload,
                        onDragStarted: onDragStarted,
                        onDragEnded: onDragEnded,
                        onMove: onMove,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _MoveBoundary(
                  apparatus: bottom,
                  onTap: onPickBottom,
                  onVerticalDragUpdate: (delta) {
                    _resizeMoveZones(delta, availableHeight);
                  },
                ),
              ),
              Expanded(
                flex: bottomFlex,
                child: _MoveDropZone(
                  apparatus: bottom,
                  orders: bottomOrders,
                  selectedOrderIds: selectedOrderIds,
                  draggingOrders: draggingOrders,
                  draggingSource: draggingSource,
                  canMoveTo: canMoveTo,
                  onToggleSelect: onToggleSelect,
                  buildDragPayload: buildDragPayload,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                  onMove: onMove,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoveDropZone extends StatelessWidget {
  const _MoveDropZone({
    required this.apparatus,
    required this.orders,
    required this.selectedOrderIds,
    required this.draggingOrders,
    required this.draggingSource,
    required this.canMoveTo,
    required this.onToggleSelect,
    required this.buildDragPayload,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });

  final AdminWarehouse apparatus;
  final List<ProductionMapSaved> orders;
  final Set<String> selectedOrderIds;
  final List<ProductionMapSaved> draggingOrders;
  final AdminWarehouse? draggingSource;
  final bool Function(
    ProductionMapSaved order,
    AdminWarehouse target,
    AdminWarehouse source,
  ) canMoveTo;
  final ValueChanged<String> onToggleSelect;
  final _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) buildDragPayload;
  final ValueChanged<_MoveDragPayload> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) onMove;

  @override
  Widget build(BuildContext context) {
    final draggingIds = {
      for (final order in draggingOrders) order.map.id.trim(),
    };
    final dragSource = draggingSource;
    final isDropTarget = dragSource != null &&
        dragSource.warehouse.trim() != apparatus.warehouse.trim();
    final blocked = isDropTarget &&
        draggingOrders.isNotEmpty &&
        draggingOrders.any((order) => !canMoveTo(order, apparatus, dragSource));
    return DragTarget<_MoveDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (details.data.source.warehouse.trim() ==
            apparatus.warehouse.trim()) {
          return false;
        }
        return details.data.orders.every(
          (order) => canMoveTo(order, apparatus, details.data.source),
        );
      },
      onAcceptWithDetails: (details) {
        onMove(
          orders: details.data.orders,
          from: details.data.source,
          to: apparatus,
        );
      },
      builder: (context, candidate, rejected) {
        final showBlocked = blocked || rejected.isNotEmpty;
        final zoneBody = orders.isEmpty
            ? _MoveEmptyZone(apparatus: apparatus)
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderId = order.map.id.trim();
                  final isDragging = draggingIds.contains(orderId);
                  final slot =
                      M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    orders.length,
                  );
                  if (isDragging) {
                    return const AnimatedSize(
                      duration: Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox.shrink(),
                    );
                  }
                  final payload = buildDragPayload(
                    order: order,
                    source: apparatus,
                    zoneOrders: orders,
                  );
                  return Padding(
                    key: ValueKey(
                      'move-order-${apparatus.warehouse}-${order.map.id}',
                    ),
                    padding: EdgeInsets.only(
                      bottom: index < orders.length - 1
                          ? M3SegmentedListGeometry.gap
                          : 0,
                    ),
                    child: _MoveOrderTile(
                      order: order,
                      source: apparatus,
                      index: index,
                      slot: slot,
                      selected: selectedOrderIds.contains(orderId),
                      payload: payload,
                      onToggleSelect: () => onToggleSelect(orderId),
                      onDragStarted: () => onDragStarted(payload),
                      onDragEnded: onDragEnded,
                    ),
                  );
                },
              );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: showBlocked
                ? ImageFiltered(
                    key: const ValueKey('move-zone-blocked'),
                    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Opacity(
                      opacity: 0.42,
                      child: IgnorePointer(child: zoneBody),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('move-zone-active'),
                    child: zoneBody,
                  ),
          ),
        );
      },
    );
  }
}

class _MoveApparatusHeader extends StatelessWidget {
  const _MoveApparatusHeader({
    super.key,
    required this.apparatus,
    required this.alignment,
    required this.onTap,
  });

  final AdminWarehouse apparatus;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: alignment,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.precision_manufacturing_rounded,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    apparatus.warehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveBoundary extends StatelessWidget {
  const _MoveBoundary({
    required this.apparatus,
    required this.onTap,
    required this.onVerticalDragUpdate,
  });

  final AdminWarehouse apparatus;
  final VoidCallback onTap;
  final ValueChanged<double> onVerticalDragUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      key: const ValueKey('move-boundary-apparatus-picker'),
      behavior: HitTestBehavior.opaque,
      onPointerMove: (event) => onVerticalDragUpdate(event.delta.dy),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant)),
            IgnorePointer(
              child: _MoveApparatusHeader(
                apparatus: apparatus,
                alignment: Alignment.center,
                onTap: onTap,
              ),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant)),
          ],
        ),
      ),
    );
  }
}

class _MoveOrderTile extends StatelessWidget {
  const _MoveOrderTile({
    required this.order,
    required this.source,
    required this.index,
    required this.slot,
    required this.selected,
    required this.payload,
    required this.onToggleSelect,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final ProductionMapSaved order;
  final AdminWarehouse source;
  final int index;
  final M3SegmentVerticalSlot slot;
  final bool selected;
  final _MoveDragPayload payload;
  final VoidCallback onToggleSelect;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final feedbackRadius = BorderRadius.circular(
          M3SegmentedListGeometry.cornerLarge,
        );
        final scheme = Theme.of(context).colorScheme;
        final batchCount = payload.orders.length;
        return _MoveOrderCard(
          order: order,
          index: index,
          slot: slot,
          selected: selected,
          onToggleSelect: onToggleSelect,
          trailing: LongPressDraggable<_MoveDragPayload>(
            data: payload,
            axis: Axis.vertical,
            childWhenDragging: const SizedBox.shrink(),
            dragAnchorStrategy: (_, handleContext, position) {
              final box = handleContext.findRenderObject()! as RenderBox;
              final local = box.globalToLocal(position);
              return Offset(cardWidth - 28, local.dy);
            },
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: cardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MoveOrderCard(
                      order: order,
                      index: index,
                      slot: M3SegmentVerticalSlot.top,
                      selected: selected,
                      borderRadiusOverride: feedbackRadius,
                    ),
                    if (batchCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$batchCount ta zakaz',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            onDragStarted: onDragStarted,
            onDragEnd: (_) => onDragEnded(),
            onDraggableCanceled: (_, __) => onDragEnded(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleSelect,
              child: _MoveDragHandle(color: scheme.onSurfaceVariant),
            ),
          ),
        );
      },
    );
  }
}

class _MoveDragPayload {
  const _MoveDragPayload({required this.orders, required this.source});

  final List<ProductionMapSaved> orders;
  final AdminWarehouse source;
}

class _MoveOrderCard extends StatelessWidget {
  const _MoveOrderCard({
    required this.order,
    required this.index,
    required this.slot,
    this.selected = false,
    this.onToggleSelect,
    this.trailing,
    this.borderRadiusOverride,
  });

  final ProductionMapSaved order;
  final int index;
  final M3SegmentVerticalSlot slot;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final Widget? trailing;
  final BorderRadius? borderRadiusOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OpenedOrderCardRow(
      slot: slot,
      order: order,
      onTap: onToggleSelect,
      borderRadiusOverride: borderRadiusOverride,
      leading: _OpenedOrderIndexBadge(
        index: index,
        selected: selected,
        onTap: onToggleSelect,
      ),
      trailing: trailing ?? _MoveDragHandle(color: scheme.onSurfaceVariant),
    );
  }
}

class _MoveDragHandle extends StatelessWidget {
  const _MoveDragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(Icons.drag_handle_rounded, color: color),
    );
  }
}

class _MoveEmptyZone extends StatelessWidget {
  const _MoveEmptyZone({required this.apparatus});

  final AdminWarehouse apparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = _isMoveUnassignedApparatus(apparatus)
        ? 'Tanlanmagan zakaz yo‘q'
        : '${apparatus.warehouse} uchun zakaz yo‘q';
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _ApparatusPickerSheet extends StatelessWidget {
  const _ApparatusPickerSheet({
    required this.apparatus,
    this.selected,
    this.orderCountFor,
    this.showUnassigned = false,
    this.unassignedOrderCount = 0,
  });

  final List<AdminWarehouse> apparatus;
  final AdminWarehouse? selected;
  final int Function(AdminWarehouse apparatus)? orderCountFor;
  final bool showUnassigned;
  final int unassignedOrderCount;

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.52).clamp(
      360.0,
      520.0,
    );
    return SafeArea(
      child: SizedBox(
        height: sheetHeight.toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Aparat tanlang',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ApparatusPickerList(
                apparatus: apparatus,
                selected: selected,
                orderCountFor: orderCountFor,
                showUnassigned: showUnassigned,
                unassignedOrderCount: unassignedOrderCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApparatusPickerList extends StatelessWidget {
  const _ApparatusPickerList({
    required this.apparatus,
    this.selected,
    this.orderCountFor,
    this.showUnassigned = false,
    this.unassignedOrderCount = 0,
  });

  final List<AdminWarehouse> apparatus;
  final AdminWarehouse? selected;
  final int Function(AdminWarehouse apparatus)? orderCountFor;
  final bool showUnassigned;
  final int unassignedOrderCount;

  @override
  Widget build(BuildContext context) {
    final itemCount = apparatus.length + (showUnassigned ? 1 : 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        M3SegmentSpacedColumn(
          children: [
            if (showUnassigned)
              _ApparatusRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  0,
                  itemCount,
                ),
                apparatus: _moveUnassignedWarehouse,
                selected: _isMoveUnassignedApparatus(selected),
                orderCount: unassignedOrderCount,
                onTap: () =>
                    Navigator.of(context).pop(_moveUnassignedWarehouse),
              ),
            for (var index = 0; index < apparatus.length; index++)
              _ApparatusRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index + (showUnassigned ? 1 : 0),
                  itemCount,
                ),
                apparatus: apparatus[index],
                selected: selected?.warehouse == apparatus[index].warehouse,
                orderCount: orderCountFor?.call(apparatus[index]) ?? 0,
                onTap: () => Navigator.of(context).pop(apparatus[index]),
              ),
          ],
        ),
      ],
    );
  }
}

class _OpenedOrderSearchField extends StatelessWidget {
  const _OpenedOrderSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final searchFill = Color.alphaBlend(
      scheme.outlineVariant.withValues(alpha: 0.22),
      scheme.surfaceContainerHighest,
    );
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        final searchActive = focusNode.hasFocus;
        final showHint = !hasText && !searchActive;
        final field = Container(
          height: 58,
          decoration: BoxDecoration(
            color: searchFill,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 20,
                            child: EditableText(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              textAlign: TextAlign.start,
                              textInputAction: TextInputAction.search,
                              maxLines: 1,
                              cursorColor: scheme.primary,
                              backgroundCursorColor:
                                  scheme.surfaceContainerHighest,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        if (!hasText)
                          Align(
                            alignment: Alignment.center,
                            child: AnimatedOpacity(
                              opacity: showHint ? 1 : 0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              child: IgnorePointer(
                                child: Text(
                                  'Ochilgan zakaz qidirish',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (searchActive)
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: 'Yopish',
                    onPressed: focusNode.unfocus,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (hasText)
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: 'Tozalash',
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 18),
            ],
          ),
        );
        return SizedBox(
          width: MediaQuery.sizeOf(context).width - 20,
          height: AppTheme.appBarHeight,
          child: Align(
            alignment: Alignment.center,
            child: Row(
              children: [
                AnimatedContainer(
                  width: searchActive ? 0 : 38,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: ClipRect(
                    child: AnimatedOpacity(
                      opacity: searchActive ? 0 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).openAppDrawerTooltip,
                        style: IconButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () =>
                            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
                        icon: Icon(
                          Icons.menu_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  width: searchActive ? 0 : 6,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                ),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -1),
                    child: field,
                  ),
                ),
                AnimatedContainer(
                  width: searchActive ? 0 : 18,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OpenedOrderExpandableList extends StatelessWidget {
  const _OpenedOrderExpandableList({
    required this.orders,
    required this.expandedOrderId,
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
    required this.onExpandedChanged,
  });

  final List<ProductionMapSaved> orders;
  final String? expandedOrderId;
  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
  final void Function(ProductionMapSaved order, bool expanded)
      onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      children: [
        for (var index = 0; index < orders.length; index++)
          _OpenedOrderExpandableRow(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              orders.length,
            ),
            order: orders[index],
            baseMetraj: baseMetrajByMapId[orders[index].map.id.trim()] ??
                orders[index].map.baseLength,
            orderKg: orderKgByMapId[orders[index].map.id.trim()] ??
                orders[index].map.orderKg,
            expanded: expandedOrderId == orders[index].map.id.trim(),
            onExpandedChanged: (expanded) =>
                onExpandedChanged(orders[index], expanded),
          ),
      ],
    );
  }
}

class _OpenedOrderExpandableRow extends StatelessWidget {
  const _OpenedOrderExpandableRow({
    required this.slot,
    required this.order,
    required this.baseMetraj,
    required this.orderKg,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final double? baseMetraj;
  final double? orderKg;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(map, includeApparatusCount: true);

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: () => onExpandedChanged(!expanded),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 12 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
              child: Row(
                children: [
                  const _OpenedOrderTreeBadge(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OpenedOrderTitleLine(
                          map: map,
                          theme: theme,
                          scheme: scheme,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _OpenedOrderWorkflowDetail(
                      map: map,
                      baseMetraj: baseMetraj,
                      orderKg: orderKg,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenedOrderWorkflowDetail extends StatelessWidget {
  const _OpenedOrderWorkflowDetail({
    required this.map,
    this.baseMetraj,
    this.orderKg,
  });

  final ProductionMapDefinition map;
  final double? baseMetraj;
  final double? orderKg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lines = _productionMapWorkflowLines(
      map,
      baseMetraj: baseMetraj,
      orderKg: orderKg,
    );
    final code = _openedOrderDisplayCode(map);
    if (lines.isEmpty && code.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 44, top: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (code.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Buyurtma kodi: $code',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  fontWeight: line.startsWith('Ish tartibi') ||
                          line.startsWith('Natija')
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenedOrderCardRow extends StatelessWidget {
  const _OpenedOrderCardRow({
    required this.slot,
    required this.order,
    required this.leading,
    required this.trailing,
    this.onTap,
    this.borderRadiusOverride,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final Widget leading;
  final Widget trailing;
  final VoidCallback? onTap;
  final BorderRadius? borderRadiusOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(map);

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      borderRadiusOverride: borderRadiusOverride,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OpenedOrderTitleLine(map: map, theme: theme, scheme: scheme),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.05,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _OpenedOrderTitleLine extends StatelessWidget {
  const _OpenedOrderTitleLine({
    required this.map,
    required this.theme,
    required this.scheme,
  });

  final ProductionMapDefinition map;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final code = _openedOrderDisplayCode(map);
    final title = _openedOrderPrimaryTitle(map);
    final resolvedTitleStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final resolvedCodeStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );
    if (code.isEmpty) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: resolvedTitleStyle,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: code, style: resolvedCodeStyle),
          TextSpan(
            text: ' • ',
            style: resolvedCodeStyle?.copyWith(
              color: scheme.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: title, style: resolvedTitleStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _OpenedOrderIndexBadge extends StatelessWidget {
  const _OpenedOrderIndexBadge({
    required this.index,
    this.selected = false,
    this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) {
      return badge;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: badge,
      ),
    );
  }
}

class _OpenedOrderTreeBadge extends StatelessWidget {
  const _OpenedOrderTreeBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.account_tree_outlined,
          color: scheme.onPrimaryContainer,
          size: 16,
        ),
      ),
    );
  }
}

class _ApparatusRow extends StatelessWidget {
  const _ApparatusRow({
    required this.slot,
    required this.apparatus,
    required this.selected,
    required this.orderCount,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminWarehouse apparatus;
  final bool selected;
  final int orderCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.surface.withValues(alpha: 0.72)
                        : scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.precision_manufacturing_rounded,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onPrimaryContainer,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apparatus.warehouse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$orderCount ta zakaz',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOpenedOrders extends StatelessWidget {
  const _EmptyOpenedOrders({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
    this.isOrderReadyForStation,
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
  final bool Function(String orderId)? isOrderReadyForStation;
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
    if (_actionInFlight) {
      return;
    }
    final apparatus = widget.apparatus?.warehouse.trim() ?? '';
    if (apparatus.isEmpty) {
      return;
    }
    final nextStates = _queueStatesForStation(
      apparatus,
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
    setState(() => _actionInFlight = true);
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
      qrPayload: qrPayload,
      progressBatchId: progressBatchId,
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
    });
    if (action == 'start' && states != null) {
      unawaited(_loadMaterialAssignments());
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
    final chainReady = station.isEmpty ||
        productionMapOrderReadyForStation(
          map: map,
          orderId: orderId,
          station: station,
          queueStatesByApparatus: widget.queueStatesByApparatus,
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
            isOrderReady: widget.isOrderReadyForStation,
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
    final isActionable = widget.canManageQueue &&
        (freePick
            ? activeOrderId == null || activeOrderId == orderId
            : actionableId == orderId);
    final showStart = isActionable &&
        chainReady &&
        queueState == ApparatusQueueOrderState.pending;
    final showPause =
        isActionable && queueState == ApparatusQueueOrderState.inProgress;
    final showComplete =
        isActionable && queueState == ApparatusQueueOrderState.inProgress;
    final showResume =
        isActionable && queueState == ApparatusQueueOrderState.paused;
    final showWaitingForPrevious = widget.canManageQueue &&
        !chainReady &&
        queueState == ApparatusQueueOrderState.pending &&
        previousStage != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _DetailCard(
              children: [
                if (_openedOrderDisplayCode(map).isNotEmpty)
                  _DetailRow(
                    label: 'Zakaz kodi',
                    value: _openedOrderDisplayCode(map),
                  ),
                _DetailRow(label: 'Mahsulot', value: _productTitle(map)),
              ],
            ),
            const SizedBox(height: 14),
            _AssignedMaterialsCard(
              assignments: materialAssignments,
              loading: _materialsLoading,
              error: _materialsError,
              scannedBarcodes: confirmedMaterialBarcodes,
            ),
            if (showStart && hasMaterialAssignments) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _actionInFlight || allMaterialsScanned
                    ? null
                    : () => unawaited(_scanMaterial()),
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
              ),
            ],
            if (showStart) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _actionInFlight ||
                        (hasMaterialAssignments && !allMaterialsScanned)
                    ? null
                    : () => unawaited(_runQueueAction('start')),
                child: const Text('Boshlash'),
              ),
            ],
            if (showPause || showComplete) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _actionInFlight
                          ? null
                          : () => unawaited(_runProgressAction('pause')),
                      child: const Text('Pauza'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _actionInFlight
                          ? null
                          : () => unawaited(_runProgressAction('complete')),
                      child: const Text('Tugatish'),
                    ),
                  ),
                ],
              ),
            ],
            if (showResume) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _actionInFlight
                    ? null
                    : () => unawaited(_runQueueAction('resume')),
                child: const Text('Davom ettirish'),
              ),
            ],
            if (showWaitingForPrevious) ...[
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Oldingi bosqich tugallanguncha kutilmoqda: $previousStage',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _mapExpanded = !_mapExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mapni ko‘rish',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _mapExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: _mapExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              for (var index = 0; index < steps.length; index++)
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
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
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

  String _nodeStationTitle(ProductionMapNode node) {
    final assigned = node.alternativeAssignedTitle.trim();
    if (assigned.isNotEmpty) {
      return assigned;
    }
    return node.title.trim();
  }
}

class _ProgressQtyInput {
  const _ProgressQtyInput({
    this.meterQty,
    this.kgQty,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.finishedGoodsMeter,
    this.description = '',
    this.isCompletionRequest = false,
  });

  final double? meterQty;
  final double? kgQty;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? finishedGoodsMeter;
  final String description;
  final bool isCompletionRequest;
}

Future<_ProgressQtyInput?> _showProgressQtyDialog(
  BuildContext context,
  String action, {
  required bool isBosma,
  required bool isLaminatsiya,
  required bool isRezka,
}) {
  return showDialog<_ProgressQtyInput>(
    context: context,
    builder: (context) => _ProgressQtyDialog(
      action: action,
      isBosma: isBosma,
      isLaminatsiya: isLaminatsiya,
      isRezka: isRezka,
    ),
  );
}

class _ProgressQtyDialog extends StatefulWidget {
  const _ProgressQtyDialog({
    required this.action,
    required this.isBosma,
    required this.isLaminatsiya,
    required this.isRezka,
  });

  final String action;
  final bool isBosma;
  final bool isLaminatsiya;
  final bool isRezka;

  @override
  State<_ProgressQtyDialog> createState() => _ProgressQtyDialogState();
}

class _ProgressQtyDialogState extends State<_ProgressQtyDialog> {
  final _meterController = TextEditingController();
  final _kgController = TextEditingController();
  final _returnInkController = TextEditingController();
  final _printLeftoverController = TextEditingController();
  final _filmLeftoverController = TextEditingController();
  final _rezkaBosmaWasteController = TextEditingController();
  final _rezkaLaminationWasteController = TextEditingController();
  final _rezkaEdgeWasteController = TextEditingController();
  final _wasteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _completionError = '';

  bool get _isComplete => widget.action == 'complete';

  @override
  void dispose() {
    _descriptionController.dispose();
    _wasteController.dispose();
    _rezkaEdgeWasteController.dispose();
    _rezkaLaminationWasteController.dispose();
    _rezkaBosmaWasteController.dispose();
    _filmLeftoverController.dispose();
    _printLeftoverController.dispose();
    _returnInkController.dispose();
    _kgController.dispose();
    _meterController.dispose();
    super.dispose();
  }

  double? _parseQty(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Widget _qtyField({
    required TextEditingController controller,
    required String label,
    required String error,
    String suffix = '',
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label),
            validator: (value) {
              final qty = _parseQty(value ?? '');
              if (qty == null || !qty.isFinite || qty <= 0) {
                return error;
              }
              return null;
            },
          ),
        ),
        if (suffix.isNotEmpty) ...[
          const SizedBox(width: 10),
          Padding(padding: const EdgeInsets.only(top: 22), child: Text(suffix)),
        ],
      ],
    );
  }

  void _submit() {
    final meterQty = _parseQty(_meterController.text);
    final kgQty = _parseQty(_kgController.text);
    final returnInkKg = _parseQty(_returnInkController.text);
    final printLeftoverRolls = _parseQty(_printLeftoverController.text);
    final filmLeftoverRolls = _parseQty(_filmLeftoverController.text);
    final rezkaBosmaWaste = _parseQty(_rezkaBosmaWasteController.text);
    final rezkaLaminationWaste =
        _parseQty(_rezkaLaminationWasteController.text);
    final rezkaEdgeWaste = _parseQty(_rezkaEdgeWasteController.text);
    final totalWaste = _parseQty(_wasteController.text);
    final hasMeter = meterQty != null && meterQty.isFinite && meterQty > 0;
    final hasKg = kgQty != null && kgQty.isFinite && kgQty > 0;
    final hasReturnInk =
        returnInkKg != null && returnInkKg.isFinite && returnInkKg > 0;
    final hasPrintLeftover = printLeftoverRolls != null &&
        printLeftoverRolls.isFinite &&
        printLeftoverRolls > 0;
    final hasFilmLeftover = filmLeftoverRolls != null &&
        filmLeftoverRolls.isFinite &&
        filmLeftoverRolls > 0;
    final hasRezkaBosmaWaste = rezkaBosmaWaste != null &&
        rezkaBosmaWaste.isFinite &&
        rezkaBosmaWaste > 0;
    final hasRezkaLaminationWaste = rezkaLaminationWaste != null &&
        rezkaLaminationWaste.isFinite &&
        rezkaLaminationWaste > 0;
    final hasRezkaEdgeWaste =
        rezkaEdgeWaste != null && rezkaEdgeWaste.isFinite && rezkaEdgeWaste > 0;
    final hasWaste =
        totalWaste != null && totalWaste.isFinite && totalWaste > 0;
    final bosmaMetricsReady = _isComplete
        ? hasReturnInk && hasWaste && hasMeter && hasKg
        : hasWaste && hasMeter && hasKg;
    final laminatsiyaMetricsReady = _isComplete
        ? (hasPrintLeftover || hasFilmLeftover) && hasWaste && hasMeter && hasKg
        : hasFilmLeftover && hasWaste && hasMeter && hasKg;
    final rezkaMetricsReady = hasRezkaBosmaWaste &&
        hasRezkaLaminationWaste &&
        hasRezkaEdgeWaste &&
        hasMeter &&
        hasKg;
    if (!widget.isBosma &&
        !widget.isLaminatsiya &&
        !widget.isRezka &&
        hasMeter &&
        hasKg) {
      Navigator.of(context)
          .pop(_ProgressQtyInput(meterQty: meterQty, kgQty: kgQty));
      return;
    }
    if (widget.isBosma && bosmaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          returnInkKg: _isComplete ? returnInkKg : null,
          totalWaste: totalWaste,
        ),
      );
      return;
    }
    if (widget.isRezka && rezkaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          meterQty: meterQty,
          kgQty: kgQty,
          rezkaBosmaWaste: rezkaBosmaWaste,
          rezkaLaminationWaste: rezkaLaminationWaste,
          rezkaEdgeWaste: rezkaEdgeWaste,
        ),
      );
      return;
    }
    if (widget.isLaminatsiya && laminatsiyaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          laminationPrintLeftoverRolls: _isComplete ? printLeftoverRolls : null,
          laminationFilmLeftoverRolls: filmLeftoverRolls,
          totalWaste: totalWaste,
        ),
      );
      return;
    }
    if (_isComplete) {
      final description = _descriptionController.text.trim();
      if (description.isNotEmpty) {
        Navigator.of(context).pop(
          _ProgressQtyInput(
            description: description,
            isCompletionRequest: true,
          ),
        );
        return;
      }
      setState(() {
        _completionError = "Nega majburiy fieldlarni bo'sh qoldiryapsiz? "
            'Iltimos izoh kiritib tugatish tugmasini bosing';
      });
      return;
    }
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final isBosma = widget.isBosma;
    final isLaminatsiya = widget.isLaminatsiya;
    final isRezka = widget.isRezka;
    final hasDetailedMetrics = isBosma || isLaminatsiya;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.action == 'pause' ? 'Pauza miqdori' : 'Tugatish miqdori',
      ),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isComplete && isBosma) ...[
                _qtyField(
                  controller: _returnInkController,
                  label: 'Vazrat kraska kg',
                  error: 'Vazrat kraska kg kiriting',
                  suffix: 'kg',
                ),
                const SizedBox(height: 10),
              ],
              if (_isComplete && isLaminatsiya) ...[
                _qtyField(
                  controller: _printLeftoverController,
                  label: 'Bosmadan ortgan rulon',
                  error: 'Bosmadan ortgan rulonni kiriting',
                ),
                const SizedBox(height: 10),
              ],
              if (isLaminatsiya) ...[
                _qtyField(
                  controller: _filmLeftoverController,
                  label: 'Plyonkadan ortgan rulon',
                  error: 'Plyonkadan ortgan rulonni kiriting',
                ),
                const SizedBox(height: 10),
              ],
              if (isRezka) ...[
                _qtyField(
                  controller: _rezkaBosmaWasteController,
                  label: 'Bosmachining chiqindisi',
                  error: 'Bosmachining chiqindisini kiriting',
                  suffix: 'kg',
                ),
                const SizedBox(height: 10),
                _qtyField(
                  controller: _rezkaLaminationWasteController,
                  label: 'Laminatsiya chiqindisi',
                  error: 'Laminatsiya chiqindisini kiriting',
                  suffix: 'kg',
                ),
                const SizedBox(height: 10),
                _qtyField(
                  controller: _rezkaEdgeWasteController,
                  label: 'Tayyor mahsulot chetidan chiqqan chiqindi',
                  error: 'Tayyor mahsulot chetidan chiqqan chiqindini kiriting',
                  suffix: 'kg',
                ),
                const SizedBox(height: 10),
              ],
              if (hasDetailedMetrics) ...[
                _qtyField(
                  controller: _wasteController,
                  label: 'Jami atxot',
                  error: 'Jami atxot kiriting',
                ),
                const SizedBox(height: 10),
              ],
              _qtyField(
                controller: _meterController,
                label: hasDetailedMetrics ? 'Tayyor mahsulot metr' : 'Metraj',
                error: hasDetailedMetrics
                    ? 'Tayyor mahsulot metr kiriting'
                    : 'Metraj kiriting',
                suffix: 'metr',
              ),
              const SizedBox(height: 10),
              _qtyField(
                controller: _kgController,
                label: hasDetailedMetrics ? 'Tayyor mahsulot kg' : "Og'irlik",
                error: hasDetailedMetrics
                    ? 'Tayyor mahsulot kg kiriting'
                    : 'Kg kiriting',
                suffix: 'kg',
              ),
              if (_isComplete) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Izoh',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) {
                    if (_completionError.isNotEmpty) {
                      setState(() => _completionError = '');
                    }
                  },
                ),
                if (_completionError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _completionError,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            height: 1.25,
                          ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Tasdiqlash')),
      ],
    );
  }
}

class _ProgressPrinterOption {
  const _ProgressPrinterOption({
    required this.server,
    required this.driverUrl,
    required this.printerLabel,
  });

  final DiscoveredServer server;
  final String driverUrl;
  final String printerLabel;
}

Future<_ProgressPrinterOption?> _showProgressPrinterPicker(
  BuildContext context,
) {
  return showModalBottomSheet<_ProgressPrinterOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _ProgressPrinterPickerSheet(),
  );
}

class _ProgressPrinterPickerSheet extends StatefulWidget {
  const _ProgressPrinterPickerSheet();

  @override
  State<_ProgressPrinterPickerSheet> createState() =>
      _ProgressPrinterPickerSheetState();
}

class _ProgressPrinterPickerSheetState
    extends State<_ProgressPrinterPickerSheet> {
  final http.Client _client = http.Client();
  List<_ProgressPrinterOption> _options = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrinters());
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final preferredEndpoint = await loadLastUsedServer();
      final fast = await discoverServersFast(
        _client,
        preferredEndpoint: preferredEndpoint,
      );
      var options = await _connectedProgressPrinters(_client, fast.servers);
      if (options.isEmpty) {
        final full = await discoverServers(
          _client,
          preferredEndpoint: preferredEndpoint,
        );
        options = await _connectedProgressPrinters(_client, [
          ...fast.servers,
          ...full.servers,
        ]);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _options = options;
        _loading = false;
        _error = options.isEmpty ? 'Printer ulangan RPS topilmadi' : '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _options = const [];
        _loading = false;
        _error = 'Printer ulangan RPS topilmadi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.62,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Printerni tanlang',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _loading ? null : () => unawaited(_loadPrinters()),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Yangilash',
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (!_loading && _error.isNotEmpty) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: scheme.surfaceContainerHighest,
                      leading: const Icon(Icons.print_rounded),
                      title: Text(
                        printTargetLabel(option.server),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${option.printerLabel} • ${option.driverUrl}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<_ProgressPrinterOption>> _connectedProgressPrinters(
  http.Client client,
  List<DiscoveredServer> servers,
) async {
  final seen = <String>{};
  final uniqueServers = <DiscoveredServer>[];
  for (final server in servers) {
    if (seen.add(server.endpoint.baseUrl)) {
      uniqueServers.add(server);
    }
  }
  final options = await Future.wait(
    uniqueServers.map((server) => _connectedProgressPrinter(client, server)),
  );
  return [
    for (final option in options)
      if (option != null) option,
  ];
}

Future<_ProgressPrinterOption?> _connectedProgressPrinter(
  http.Client client,
  DiscoveredServer server,
) async {
  try {
    final response = await client
        .get(Uri.parse('${server.endpoint.baseUrl}/v1/mobile/monitor/state'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode < 200 || response.statusCode > 299) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final printerRaw = (payload['printer'] as Map?)?.cast<String, dynamic>() ??
        ((payload['state'] as Map?)?['printer'] as Map?)
            ?.cast<String, dynamic>();
    if (printerRaw == null) {
      return null;
    }
    final connected =
        _jsonBool(printerRaw['connected']) || _jsonBool(printerRaw['ok']);
    if (!connected) {
      return null;
    }
    final kind = _jsonText(printerRaw['kind'], fallback: 'printer');
    return _ProgressPrinterOption(
      server: server,
      driverUrl: driverUrlForRs(server).replaceFirst(RegExp(r'/+$'), ''),
      printerLabel: _jsonText(printerRaw['label'], fallback: kind),
    );
  } catch (_) {
    return null;
  }
}

bool _jsonBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

String _jsonText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(children: children),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedMaterialsCard extends StatelessWidget {
  const _AssignedMaterialsCard({
    required this.assignments,
    required this.loading,
    required this.error,
    required this.scannedBarcodes,
  });

  final List<AdminRawMaterialAssignment> assignments;
  final bool loading;
  final String error;
  final Set<String> scannedBarcodes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Biriktirilgan homashyolar',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
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
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else if (error.trim().isNotEmpty)
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              )
            else if (assignments.isEmpty)
              Text(
                'Homashyo biriktirilmagan',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Column(
                children: [
                  for (var index = 0; index < assignments.length; index++) ...[
                    _AssignedMaterialTile(
                      assignment: assignments[index],
                      scanned: scannedBarcodes.contains(
                        assignments[index].barcode.trim().toUpperCase(),
                      ),
                    ),
                    if (index != assignments.length - 1)
                      Divider(height: 14, color: scheme.outlineVariant),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AssignedMaterialTile extends StatelessWidget {
  const _AssignedMaterialTile({
    required this.assignment,
    required this.scanned,
  });

  final AdminRawMaterialAssignment assignment;
  final bool scanned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode.trim()
        : assignment.itemName.trim();
    final meta = [
      if (assignment.itemCode.trim().isNotEmpty) assignment.itemCode.trim(),
      if (assignment.itemGroup.trim().isNotEmpty) assignment.itemGroup.trim(),
      assignment.barcode.trim(),
    ].where((item) => item.isNotEmpty).join(' • ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          scanned ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: scanned ? const Color(0xFF2E7D32) : scheme.onSurfaceVariant,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? assignment.barcode : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SequenceStepTile extends StatelessWidget {
  const _SequenceStepTile({
    required this.node,
    required this.index,
    required this.isLast,
    required this.status,
    required this.current,
  });

  final ProductionMapNode node;
  final int index;
  final bool isLast;
  final ApparatusQueueOrderState? status;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (node.kind) {
      'start' => Icons.play_arrow_rounded,
      'apparatus' => Icons.precision_manufacturing_rounded,
      'end' => Icons.flag_rounded,
      _ => Icons.account_tree_outlined,
    };
    final statusColor = _statusColor(scheme);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            SizedBox.square(
              dimension: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: current ? scheme.primary : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: current ? scheme.onPrimary : scheme.onPrimaryContainer,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                margin: const EdgeInsets.symmetric(vertical: 3),
                color: current ? scheme.primary : scheme.outlineVariant,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.title.trim().isEmpty ? 'Qadam ${index + 1}' : node.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _kindLabel(node),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    _statusLabel(status!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (current) ...[
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.keyboard_arrow_left_rounded,
              color: scheme.primary,
              size: 30,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              current ? scheme.primaryContainer.withValues(alpha: 0.34) : null,
          borderRadius: BorderRadius.circular(14),
          border: current ? Border.all(color: scheme.primary) : null,
        ),
        child: Padding(
          padding: current
              ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
              : EdgeInsets.zero,
          child: content,
        ),
      ),
    );
  }

  Color _statusColor(ColorScheme scheme) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => const Color(0xFFB26A00),
      ApparatusQueueOrderState.paused => const Color(0xFFC62828),
      ApparatusQueueOrderState.completed => const Color(0xFF2E7D32),
      ApparatusQueueOrderState.pending => scheme.primary,
      null => scheme.onSurfaceVariant,
    };
  }

  String _statusLabel(ApparatusQueueOrderState status) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => 'Jarayonda',
      ApparatusQueueOrderState.paused => 'Pauzada',
      ApparatusQueueOrderState.completed => 'Tugagan',
      ApparatusQueueOrderState.pending => 'Kutmoqda',
    };
  }

  String _kindLabel(ProductionMapNode node) {
    return switch (node.kind) {
      'start' => 'Boshlanish',
      'apparatus' => productionMapIsLaminatsiyaApparatus(node.title)
          ? 'Laminatsiya mashinasi'
          : productionMapIsRezkaApparatus(node.title)
              ? 'Rezka mashinasi'
              : 'Aparat',
      'end' => 'Yakun',
      _ => node.kind,
    };
  }
}

String _apparatusDetailLabel(String apparatus) {
  return productionMapIsLaminatsiyaApparatus(apparatus)
      ? 'Laminatsiya mashinasi'
      : productionMapIsRezkaApparatus(apparatus)
          ? 'Rezka mashinasi'
          : 'Aparat';
}
