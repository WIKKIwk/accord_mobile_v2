import 'dart:async';
import 'dart:math' as math;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/navigation/app_navigation_bar.dart';
import '../../../core/widgets/navigation/dock_gesture_overlay.dart';
import '../../../core/widgets/navigation/dock_system_bottom_inset.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../logic/production_map_pechat_rules.dart';
import '../models/production_map_models.dart';
import '../state/calculate_order_store.dart';
import 'widgets/admin_create_hub_sheet.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_top_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'admin_production_map_test_formula_widgets.dart';
part 'admin_production_map_test_helpers.dart';
part 'admin_production_map_test_sheet_widgets.dart';
part 'admin_production_map_test_node_edit_sheets.dart';
part 'admin_production_map_test_node_visual.dart';
part 'admin_production_map_test_painters.dart';

const _productionMapDockHeight = 60.0;

class AdminProductionMapTestScreen extends StatefulWidget {
  const AdminProductionMapTestScreen({
    super.key,
    this.orderContext,
    this.savedMap,
    this.readOnly = false,
  });

  final ProductionMapOrderContext? orderContext;
  final ProductionMapDefinition? savedMap;
  final bool readOnly;

  @override
  State<AdminProductionMapTestScreen> createState() =>
      _AdminProductionMapTestScreenState();
}

class _AdminProductionMapTestScreenState
    extends State<AdminProductionMapTestScreen> {
  static const _nodeGap = 18.0;
  static const _nodeStepX = 280.0;
  static const _nodeStepY = 132.0;
  static const _minNodeX = -2400.0;
  static const _minNodeY = -1600.0;
  static const _maxNodeX = 6000.0;
  static const _maxNodeY = 6000.0;

  late final bool _orderMode;
  late final List<ProductionMapNode> nodes;
  late final List<ProductionMapEdge> edges;

  int _nextNodeIndex = 1;
  String? _connectingFromNodeID;
  String _connectingFromBranch = '';
  Offset? _connectionPreviewEnd;
  bool _savingMap = false;
  late String _orderNumber;
  CalculateOrderTemplate? _templateDraft;
  CalculateOrderTemplate? _lastSavedTemplate;
  List<AdminApparatusGroup> _apparatusGroups = const [];

  @override
  void initState() {
    super.initState();
    final savedMap = widget.savedMap;
    _orderMode = widget.orderContext != null ||
        (savedMap?.id.trim().startsWith('zakaz-') ?? false);
    nodes = savedMap != null
        ? List<ProductionMapNode>.from(savedMap.nodes)
        : _orderMode
            ? _orderFlowNodes(widget.orderContext!)
            : _defaultTestNodes();
    edges = savedMap != null
        ? List<ProductionMapEdge>.from(savedMap.edges)
        : _orderMode
            ? _orderFlowEdges()
            : _defaultTestEdges();
    _syncNextNodeIndexFromExistingNodes();
    _orderNumber = savedMap?.orderNumber.trim() ?? '';
    _templateDraft = widget.orderContext?.templateDraft;
    unawaited(_loadApparatusGroups());
  }

  void _syncNextNodeIndexFromExistingNodes() {
    var maxIndex = 0;
    for (final node in nodes) {
      final match = RegExp(r'_(\d+)$').firstMatch(node.id.trim());
      if (match == null) {
        continue;
      }
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value > maxIndex) {
        maxIndex = value;
      }
    }
    if (maxIndex >= _nextNodeIndex) {
      _nextNodeIndex = maxIndex + 1;
    }
  }

  Future<void> _loadApparatusGroups() async {
    try {
      final groups = await MobileApi.instance.adminApparatusGroups();
      if (mounted) {
        setState(() => _apparatusGroups = groups);
      }
    } catch (_) {
      return;
    }
  }

  List<ProductionMapNode> _defaultTestNodes() {
    return [
      const ProductionMapNode(
        id: 'start',
        kind: 'start',
        title: 'Start',
        x: 420,
        y: 32,
      ),
      const ProductionMapNode(
        id: 'cpp_calc',
        kind: 'formula',
        title: 'CPP hisob',
        x: 420,
        y: 164,
        formula: ProductionFormula(
          target: 'cpp_kg',
          expression: 'order_qty * 1.08',
        ),
      ),
      const ProductionMapNode(
        id: 'qty_check',
        kind: 'condition',
        title: 'Katta partiyami?',
        x: 420,
        y: 296,
        formula: ProductionFormula(target: '', expression: 'order_qty >= 100'),
      ),
      const ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: 'End',
        x: 420,
        y: 520,
      ),
    ];
  }

  List<ProductionMapEdge> _defaultTestEdges() {
    return [
      const ProductionMapEdge(from: 'start', to: 'cpp_calc'),
      const ProductionMapEdge(from: 'cpp_calc', to: 'qty_check'),
    ];
  }

  List<ProductionMapNode> _orderFlowNodes(ProductionMapOrderContext context) {
    final orderName =
        context.orderName.trim().isEmpty ? 'Zakaz' : context.orderName.trim();
    final productName = context.productName.trim().isEmpty
        ? 'Mahsulot'
        : context.productName.trim();
    return [
      const ProductionMapNode(
        id: 'start',
        kind: 'start',
        title: 'Start',
        x: 420,
        y: 32,
      ),
      ProductionMapNode(
        id: 'order',
        kind: 'task',
        title: orderName,
        roleCode: 'zakaz',
        x: 420,
        y: 164,
      ),
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: productName,
        itemCode: context.itemCode,
        x: 420,
        y: 296,
      ),
    ];
  }

  List<ProductionMapEdge> _orderFlowEdges() {
    return [
      const ProductionMapEdge(from: 'start', to: 'order'),
      const ProductionMapEdge(from: 'order', to: 'end'),
    ];
  }

  Future<void> _saveMap() async {
    if (widget.readOnly) {
      return;
    }
    if (_savingMap) {
      return;
    }
    final orderNumber = _orderMode ? await _resolveOrderNumberForSave() : null;
    if (_orderMode && orderNumber == null) {
      return;
    }
    setState(() => _savingMap = true);
    try {
      final definition = _currentMapDefinition(orderNumber: orderNumber);
      final draft = _templateDraft;
      if (draft != null) {
        final templateDefinition = definition.withoutAlternativeAssignments();
        // Single server-side operation: map + zakaz saved together.
        final result = await MobileApi.instance.adminSaveProductionMapWithOrder(
          map: templateDefinition,
          template: draft,
        );
        if (!mounted) {
          return;
        }
        _lastSavedTemplate = result.template;
        _templateDraft = result.template ?? draft;
        final savedTemplate = result.template;
        if (savedTemplate != null) {
          CalculateOrderTemplateStore.instance.remember(savedTemplate);
        }
        if (orderNumber != null) {
          _orderNumber = orderNumber;
        }
        showAdminTopNotice(context, 'Production map va zakaz saqlandi');
      } else {
        await MobileApi.instance.adminSaveProductionMap(definition);
        if (!mounted) {
          return;
        }
        if (orderNumber != null) {
          _orderNumber = orderNumber;
        }
        showAdminTopNotice(context, 'Production map saqlandi');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : 'Production map saqlanmadi',
      );
    } finally {
      if (mounted) {
        setState(() => _savingMap = false);
      }
    }
  }

  bool get _orderNumberLocked =>
      RegExp(r'^\d{4}$').hasMatch(_orderNumber.trim());

  Future<String?> _resolveOrderNumberForSave() async {
    if (_orderNumberLocked) {
      return _orderNumber.trim();
    }
    return _requestOrderNumber();
  }

  Future<String?> _requestOrderNumber() {
    // Uniqueness is enforced server-side on save (duplicate_order_number);
    // the dialog only checks the 4-digit format.
    return showProductionMapOrderNumberSheet(
      context,
      initialValue: _orderNumber,
    );
  }

  ProductionMapDefinition _currentMapDefinition({String? orderNumber}) {
    final context = widget.orderContext;
    final savedMap = widget.savedMap;
    final normalizedOrderNumber = (orderNumber ?? _orderNumber).trim();
    final title = context == null
        ? (savedMap?.title.trim().isNotEmpty ?? false)
            ? savedMap!.title.trim()
            : 'Production map test'
        : (context.orderName.trim().isEmpty
            ? 'Zakaz'
            : context.orderName.trim());
    final productCode = context == null
        ? (savedMap?.productCode.trim().isNotEmpty ?? false)
            ? savedMap!.productCode.trim()
            : 'production-map-test'
        : _firstNonEmpty([
            context.itemCode,
            context.productName,
            context.orderName,
            context.templateId,
          ]);
    return ProductionMapDefinition(
      id: _orderMode
          ? ((savedMap?.id.trim().isNotEmpty ?? false)
              ? savedMap!.id.trim()
              : _zakazMapId(normalizedOrderNumber, context: context))
          : (context == null
              ? (savedMap?.id.trim().isNotEmpty ?? false)
                  ? savedMap!.id.trim()
                  : 'production-map-test'
              : _orderMapId(context, normalizedOrderNumber)),
      productCode: productCode,
      title: title,
      code: _orderMode && normalizedOrderNumber.isNotEmpty
          ? normalizedOrderNumber
          : _firstNonEmpty([context?.orderCode ?? '', savedMap?.code ?? '']),
      orderNumber: normalizedOrderNumber,
      // Re-saving an opened zakaz must keep its pechat constraints.
      rollCount: context?.rollCount ?? savedMap?.rollCount,
      widthMm: context?.widthMm ?? savedMap?.widthMm,
      nodes: List<ProductionMapNode>.unmodifiable(nodes),
      edges: List<ProductionMapEdge>.unmodifiable(edges),
    );
  }

  String _zakazMapId(String orderNumber, {ProductionMapOrderContext? context}) {
    if (RegExp(r'^\d{4}$').hasMatch(orderNumber)) {
      return 'zakaz-$orderNumber';
    }
    if (context != null) {
      return _orderMapId(context, orderNumber);
    }
    return 'production-map-test';
  }

  String _orderMapId(ProductionMapOrderContext context, String orderNumber) {
    if (RegExp(r'^\d{4}$').hasMatch(orderNumber)) {
      return 'zakaz-$orderNumber';
    }
    final source = _firstNonEmpty([
      context.templateId,
      context.orderName,
      context.productName,
      context.itemCode,
    ]);
    return 'zakaz-${_slug(source)}';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return 'zakaz';
  }

  String _slug(String value) {
    final lower = value.trim().toLowerCase();
    final buffer = StringBuffer();
    var lastDash = false;
    for (final unit in lower.codeUnits) {
      final isLetter = unit >= 97 && unit <= 122;
      final isDigit = unit >= 48 && unit <= 57;
      if (isLetter || isDigit) {
        buffer.writeCharCode(unit);
        lastDash = false;
      } else if (!lastDash) {
        buffer.write('-');
        lastDash = true;
      }
    }
    final slug = buffer.toString().replaceAll(RegExp('^-+|-+\$'), '');
    return slug.isEmpty ? 'zakaz' : slug;
  }

  void _addNode(String kind) {
    final id = '${kind}_${_nextNodeIndex++}';
    setState(() {
      if (kind == 'condition') {
        _addConditionBranch(id);
      } else {
        _insertBeforeEnd(_newNode(id, kind));
      }
    });
    if (_orderMode && kind == 'task') {
      final index = nodes.indexWhere((node) => node.id == id);
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_editNode(index));
          }
        });
      }
    }
  }

  void _addRezkaNode() {
    final id = 'rezka_${_nextNodeIndex++}';
    setState(() {
      _insertBeforeEnd(_newNode(id, 'apparatus').copyWith(title: 'Rezka'));
    });
  }

  Future<void> _addApparatusGroup(AdminApparatusGroup group) async {
    final groupNames =
        group.apparatus.map((item) => item.trim().toLowerCase()).toSet();
    final warehouses = await MobileApi.instance.adminWarehouses(
      parent: 'aparat - A',
      limit: 200,
    );
    final compatible = warehouses
        .where(
          (warehouse) =>
              groupNames.contains(warehouse.warehouse.trim().toLowerCase()),
        )
        .where(
          (warehouse) => productionMapApparatusMatchesOrder(
            warehouse,
            widget.orderContext,
          ),
        )
        .toList(growable: false);
    if (!mounted) {
      return;
    }
    if (compatible.isEmpty) {
      showAdminTopNotice(context, 'Mos aparat topilmadi');
      return;
    }
    final picked = await showModalBottomSheet<_ApparatusGroupPickResult>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) =>
          _ApparatusGroupPickerSheet(group: group, apparatus: compatible),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (picked.skip) {
        _insertAlternativeApparatusNodes(group, compatible);
      } else if (picked.apparatus != null) {
        final id = 'apparatus_${_nextNodeIndex++}';
        _insertBeforeEnd(
          _newNode(
            id,
            'apparatus',
          ).copyWith(title: picked.apparatus!.warehouse),
        );
      }
    });
  }

  void _insertAlternativeApparatusNodes(
    AdminApparatusGroup group,
    List<AdminWarehouse> apparatus,
  ) {
    final endIndex = nodes.indexWhere((item) => item.kind == 'end');
    if (endIndex <= 0 || apparatus.isEmpty) {
      return;
    }
    final end = nodes[endIndex];
    final incomingEdges =
        edges.where((edge) => edge.to == end.id).toList(growable: false);
    final previousNodes = incomingEdges.isEmpty
        ? [nodes[endIndex - 1]]
        : [
            for (final edge in incomingEdges)
              if (nodes.any((node) => node.id == edge.from))
                nodes.firstWhere((node) => node.id == edge.from),
          ];
    if (previousNodes.isEmpty) {
      return;
    }
    final groupId = 'alt_${group.name.trim().toLowerCase()}_$_nextNodeIndex';
    final previousBottomY = previousNodes
        .map((node) => node.y)
        .fold<double>(_minNodeY, (max, y) => y > max ? y : max);
    final previousCenterX = previousNodes
            .map((node) => node.x + _ProductionMapCanvas._nodeSize.width / 2)
            .fold<double>(0, (sum, x) => sum + x) /
        previousNodes.length;
    final y = previousBottomY + _nodeStepY;
    final firstX = previousCenterX -
        (_ProductionMapCanvas._nodeSize.width * apparatus.length) / 2;
    final created = <ProductionMapNode>[];
    for (var index = 0; index < apparatus.length; index++) {
      final id = 'apparatus_${_nextNodeIndex++}';
      created.add(
        ProductionMapNode(
          id: id,
          kind: 'apparatus',
          title: apparatus[index].warehouse,
          alternativeGroupId: groupId,
          alternativeGroupLabel: group.name,
          x: firstX + index * _ProductionMapCanvas._nodeSize.width,
          y: y,
        ),
      );
    }
    nodes.insertAll(endIndex, created);
    edges.removeWhere((edge) => edge.to == end.id);
    for (final node in created) {
      for (final previous in previousNodes) {
        edges.add(ProductionMapEdge(from: previous.id, to: node.id));
      }
      edges.add(ProductionMapEdge(from: node.id, to: end.id));
    }
    _pushEndDown();
  }

  ProductionMapNode _newNode(String id, String kind) {
    final end = nodes.firstWhere((node) => node.kind == 'end');
    return switch (kind) {
      'apparatus' => ProductionMapNode(
          id: id,
          kind: 'apparatus',
          title: 'Aparat tanlang',
          x: end.x,
          y: end.y - 132,
        ),
      'formula' => ProductionMapNode(
          id: id,
          kind: 'formula',
          title: 'Hisob kitob',
          x: end.x,
          y: end.y - 132,
          formula: const ProductionFormula(
            target: 'result_kg',
            expression: 'order_qty',
          ),
        ),
      _ => ProductionMapNode(
          id: id,
          kind: 'task',
          title: _orderMode ? 'Stansiya tanlang' : 'Ishlov jarayoni',
          roleCode: 'worker',
          x: end.x,
          y: end.y - 132,
        ),
    };
  }

  void _insertBeforeEnd(ProductionMapNode node) {
    final endIndex = nodes.indexWhere((item) => item.kind == 'end');
    final previous = nodes[endIndex - 1];
    final end = nodes[endIndex];
    final placedNode = _placeNode(
      node.copyWith(x: previous.x, y: previous.y + _nodeStepY),
      ignoreIds: {end.id},
    );
    nodes.insert(endIndex, placedNode);
    edges.removeWhere((edge) => edge.from == previous.id && edge.to == end.id);
    edges
      ..add(ProductionMapEdge(from: previous.id, to: placedNode.id))
      ..add(ProductionMapEdge(from: placedNode.id, to: end.id));
    _pushEndDown();
  }

  void _addConditionBranch(String id) {
    final endIndex = nodes.indexWhere((item) => item.kind == 'end');
    final previous = nodes[endIndex - 1];
    final end = nodes[endIndex];
    final condition = _placeNode(
      ProductionMapNode(
        id: id,
        kind: 'condition',
        title: 'Shart',
        x: previous.x,
        y: previous.y + _nodeStepY,
        formula: const ProductionFormula(
          target: '',
          expression: 'order_qty >= 100',
        ),
      ),
      ignoreIds: {end.id},
    );
    nodes.insert(endIndex, condition);
    edges.removeWhere((edge) => edge.from == previous.id && edge.to == end.id);
    edges.add(ProductionMapEdge(from: previous.id, to: condition.id));
    _pushEndDown();
  }

  void _pushEndDown() {
    final endIndex = nodes.indexWhere((node) => node.kind == 'end');
    final end = nodes[endIndex];
    final deepest = nodes
        .where((node) => node.id != end.id)
        .map((node) => node.y)
        .fold<double>(end.y, (max, y) => y > max ? y : max);
    nodes[endIndex] = _placeNode(
      end.copyWith(y: deepest + _nodeStepY),
      ignoreIds: {end.id},
    );
  }

  void _moveNode(String nodeID, Offset delta) {
    final index = nodes.indexWhere((node) => node.id == nodeID);
    if (index < 0) {
      return;
    }
    final node = nodes[index];
    setState(() {
      final position = _clampNodePosition(Offset(node.x, node.y) + delta);
      nodes[index] = node.copyWith(x: position.dx, y: position.dy);
      _resolveNodeOverlaps(anchorID: nodeID);
    });
  }

  void _startConnection(String nodeID, [String branch = '']) {
    setState(() {
      _connectingFromNodeID = nodeID;
      _connectingFromBranch = branch.trim().toLowerCase();
      _connectionPreviewEnd = null;
    });
  }

  void _updateConnectionPreview(Offset canvasPosition) {
    if (_connectingFromNodeID == null) {
      return;
    }
    setState(() => _connectionPreviewEnd = canvasPosition);
  }

  void _finishConnection(Offset canvasPosition) {
    final fromID = _connectingFromNodeID;
    final branchKey = _connectingFromBranch;
    setState(() {
      _connectingFromNodeID = null;
      _connectingFromBranch = '';
      _connectionPreviewEnd = null;
      if (fromID == null) {
        return;
      }
      final target = _nodeAt(canvasPosition, exceptID: fromID);
      if (target == null) {
        return;
      }
      final source = nodes.firstWhere(
        (node) => node.id == fromID,
        orElse: () => target,
      );
      if (!_canCreateEdge(source, target)) {
        return;
      }
      final exists = edges.any(
        (edge) =>
            edge.from == fromID &&
            edge.to == target.id &&
            edge.branch.trim().toLowerCase() == branchKey,
      );
      if (!exists) {
        if (branchKey.isNotEmpty) {
          edges.removeWhere(
            (edge) =>
                edge.from == fromID &&
                edge.branch.trim().toLowerCase() == branchKey,
          );
        }
        edges.add(
          ProductionMapEdge(from: fromID, to: target.id, branch: branchKey),
        );
      }
    });
  }

  bool _canCreateEdge(ProductionMapNode from, ProductionMapNode to) {
    return productionMapCanCreateEdge(from, to);
  }

  void _cancelConnection() {
    setState(() {
      _connectingFromNodeID = null;
      _connectingFromBranch = '';
      _connectionPreviewEnd = null;
    });
  }

  void _removeEdge(ProductionMapEdge edge) {
    setState(() {
      edges.removeWhere(
        (item) =>
            item.from == edge.from &&
            item.to == edge.to &&
            item.branch == edge.branch,
      );
    });
  }

  ProductionMapNode? _nodeAt(Offset position, {required String exceptID}) {
    for (final node in nodes.reversed) {
      if (node.id == exceptID) {
        continue;
      }
      final rect = Rect.fromLTWH(
        node.x,
        node.y,
        _ProductionMapCanvas._nodeSize.width,
        _ProductionMapCanvas._nodeSize.height,
      );
      if (rect.contains(position)) {
        return node;
      }
    }
    return null;
  }

  ProductionMapNode _placeNode(
    ProductionMapNode node, {
    Set<String> ignoreIds = const {},
    List<ProductionMapNode> extraNodes = const [],
  }) {
    final position = _firstFreePosition(
      Offset(node.x, node.y),
      nodeID: node.id,
      ignoreIds: ignoreIds,
      extraNodes: extraNodes,
    );
    return node.copyWith(x: position.dx, y: position.dy);
  }

  Offset _firstFreePosition(
    Offset preferred, {
    required String nodeID,
    Set<String> ignoreIds = const {},
    List<ProductionMapNode> extraNodes = const [],
  }) {
    final origin = _clampNodePosition(preferred);
    final tried = <String>{};
    for (var row = 0; row < 80; row++) {
      for (final column in const [0, -1, 1, -2, 2, -3, 3, -4, 4]) {
        final position = _clampNodePosition(
          Offset(origin.dx + column * _nodeStepX, origin.dy + row * _nodeStepY),
        );
        final key = '${position.dx}:${position.dy}';
        if (!tried.add(key)) {
          continue;
        }
        if (!_positionOverlapsAny(
          position,
          nodeID: nodeID,
          ignoreIds: ignoreIds,
          extraNodes: extraNodes,
        )) {
          return position;
        }
      }
    }
    return origin;
  }

  void _resolveNodeOverlaps({required String anchorID}) {
    for (var pass = 0; pass < 80; pass++) {
      var moved = false;
      for (var a = 0; a < nodes.length; a++) {
        for (var b = a + 1; b < nodes.length; b++) {
          final separation = _overlapSeparation(nodes[a], nodes[b]);
          if (separation == Offset.zero) {
            continue;
          }
          moved = true;
          if (nodes[a].id == anchorID) {
            _moveNodeByIndex(b, separation);
          } else if (nodes[b].id == anchorID) {
            _moveNodeByIndex(a, -separation);
          } else {
            _moveNodeByIndex(a, -separation / 2);
            _moveNodeByIndex(b, separation / 2);
          }
        }
      }
      if (!moved) {
        _repackRemainingOverlaps(anchorID: anchorID);
        return;
      }
    }
    _repackRemainingOverlaps(anchorID: anchorID);
  }

  Offset _overlapSeparation(ProductionMapNode a, ProductionMapNode b) {
    final aRect = _collisionRectAt(Offset(a.x, a.y));
    final bRect = _collisionRectAt(Offset(b.x, b.y));
    if (!aRect.overlaps(bRect)) {
      return Offset.zero;
    }
    final overlapX = math.min(
      aRect.right - bRect.left,
      bRect.right - aRect.left,
    );
    final overlapY = math.min(
      aRect.bottom - bRect.top,
      bRect.bottom - aRect.top,
    );
    if (overlapX <= 0 || overlapY <= 0) {
      return Offset.zero;
    }
    if (overlapX <= overlapY) {
      final direction = bRect.center.dx >= aRect.center.dx ? 1.0 : -1.0;
      return Offset((overlapX + 0.5) * direction, 0);
    }
    final direction = bRect.center.dy >= aRect.center.dy ? 1.0 : -1.0;
    return Offset(0, (overlapY + 0.5) * direction);
  }

  void _moveNodeByIndex(int index, Offset delta) {
    final node = nodes[index];
    final position = _clampNodePosition(Offset(node.x, node.y) + delta);
    nodes[index] = node.copyWith(x: position.dx, y: position.dy);
  }

  void _repackRemainingOverlaps({required String anchorID}) {
    for (var pass = 0; pass < nodes.length; pass++) {
      var changed = false;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (node.id == anchorID || !_nodeOverlapsAny(node)) {
          continue;
        }
        final position = _firstFreePosition(
          Offset(node.x, node.y),
          nodeID: node.id,
        );
        if (position.dx != node.x || position.dy != node.y) {
          nodes[i] = node.copyWith(x: position.dx, y: position.dy);
          changed = true;
        }
      }
      if (!changed) {
        return;
      }
    }
  }

  bool _nodeOverlapsAny(ProductionMapNode node) {
    return _positionOverlapsAny(Offset(node.x, node.y), nodeID: node.id);
  }

  Offset _clampNodePosition(Offset position) {
    return Offset(
      position.dx.clamp(_minNodeX, _maxNodeX).toDouble(),
      position.dy.clamp(_minNodeY, _maxNodeY).toDouble(),
    );
  }

  bool _positionOverlapsAny(
    Offset position, {
    required String nodeID,
    Set<String> ignoreIds = const {},
    List<ProductionMapNode> extraNodes = const [],
  }) {
    final candidate = _collisionRectAt(position);
    for (final node in [...nodes, ...extraNodes]) {
      if (node.id == nodeID || ignoreIds.contains(node.id)) {
        continue;
      }
      if (candidate.overlaps(_collisionRectAt(Offset(node.x, node.y)))) {
        return true;
      }
    }
    return false;
  }

  Rect _collisionRectAt(Offset position) {
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      _ProductionMapCanvas._nodeSize.width,
      _ProductionMapCanvas._nodeSize.height,
    ).inflate(_nodeGap / 2);
  }

  bool _isOrderProductTask(ProductionMapNode node) {
    return node.kind == 'task' &&
        (node.id.trim() == 'order' || node.roleCode.trim() == 'zakaz');
  }

  bool _isStationTask(ProductionMapNode node) {
    return node.kind == 'task' && !_isOrderProductTask(node);
  }

  Future<AdminWarehouse?> _pickStationWarehouse({String? title}) async {
    return showModalBottomSheet<AdminWarehouse>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<AdminWarehouse>(
          title: title ?? 'Stansiya tanlang',
          hintText: 'Aparat qidiring',
          pageSize: 50,
          cacheKey: 'production-map:station-warehouses'
              ':${_apparatusFilterCacheSuffix()}',
          loadPage: (query, offset, limit) async {
            final warehouses = await MobileApi.instance.adminWarehouses(
              query: query,
              parent: 'aparat - A',
              limit: 200,
            );
            return warehouses
                .where(
                  (warehouse) => productionMapApparatusMatchesOrder(
                    warehouse,
                    widget.orderContext,
                  ),
                )
                .skip(offset)
                .take(limit)
                .toList(growable: false);
          },
          itemTitle: (item) => item.warehouse,
          itemSubtitle: (item) =>
              item.company.trim().isEmpty ? 'Aparat' : item.company,
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
  }

  Future<void> _editNode(int index) async {
    if (index < 0) {
      return;
    }
    final node = nodes[index];
    if (_isRezkaProductionNode(node)) {
      final edited = await showModalBottomSheet<ProductionMapNode>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        builder: (context) => _RezkaNodeEditSheet(node: node),
      );
      if (edited == null || !mounted) {
        return;
      }
      setState(() => nodes[index] = edited);
      return;
    }
    if (node.kind == 'apparatus') {
      final picked = await showModalBottomSheet<AdminWarehouse>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) {
          return M3AsyncPickerSheet<AdminWarehouse>(
            title: 'Aparat tanlang',
            hintText: 'Aparat qidiring',
            pageSize: 50,
            cacheKey: 'production-map:apparatus-warehouses'
                ':${_apparatusFilterCacheSuffix()}',
            loadPage: (query, offset, limit) async {
              final warehouses = await MobileApi.instance.adminWarehouses(
                query: query,
                parent: 'aparat - A',
                limit: 200,
              );
              return warehouses
                  .where(
                    (warehouse) => productionMapApparatusMatchesOrder(
                      warehouse,
                      widget.orderContext,
                    ),
                  )
                  .skip(offset)
                  .take(limit)
                  .toList(growable: false);
            },
            itemTitle: (item) => item.warehouse,
            itemSubtitle: (item) =>
                item.company.trim().isEmpty ? 'Aparat' : item.company,
            onSelected: (item) => Navigator.of(context).pop(item),
          );
        },
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() => nodes[index] = node.copyWith(title: picked.warehouse));
      return;
    }
    if (_isStationTask(node)) {
      final picked = await _pickStationWarehouse(title: 'Ishlov stansiyasi');
      if (picked == null || !mounted) {
        return;
      }
      setState(() => nodes[index] = node.copyWith(title: picked.warehouse));
      return;
    }
    final edited = await showModalBottomSheet<ProductionMapNode>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _NodeEditSheet(node: node),
    );
    if (edited == null || !mounted) {
      return;
    }
    setState(() => nodes[index] = edited);
  }

  String _apparatusFilterCacheSuffix() {
    final context = widget.orderContext;
    if (context == null) {
      return 'all';
    }
    final recommended = productionMapRecommendedPechatColorCount(
      rollCount: context.rollCount,
      widthMm: context.widthMm,
    );
    return [
      context.rollCount?.toStringAsFixed(0) ?? 'x',
      context.widthMm?.toStringAsFixed(0) ?? 'x',
      recommended?.toString() ?? 'none',
    ].join('-');
  }

  void _deleteNode(int index) {
    final node = nodes[index];
    if (node.kind == 'start' || node.kind == 'end') {
      return;
    }
    setState(() {
      nodes.removeAt(index);
      edges.removeWhere((edge) => edge.from == node.id || edge.to == node.id);
    });
  }

  void _runMapToolAction(VoidCallback action) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        action();
      }
    });
  }

  List<AdminFabMenuAction> _mapToolActions() {
    if (_orderMode) {
      final groupActions = [
        for (final group in _apparatusGroups)
          if (_apparatusGroupMatchesOrder(group))
            AdminFabMenuAction(
              title: group.name,
              icon: Icons.precision_manufacturing_rounded,
              onTap: () => _runMapToolAction(() {
                unawaited(_addApparatusGroup(group));
              }),
            ),
      ];
      return [
        if (groupActions.isEmpty)
          AdminFabMenuAction(
            title: 'Aparat',
            icon: Icons.precision_manufacturing_rounded,
            onTap: () => _runMapToolAction(() => _addNode('apparatus')),
          )
        else
          ...groupActions,
        AdminFabMenuAction(
          title: 'Ishlov',
          icon: Icons.engineering_rounded,
          onTap: () => _runMapToolAction(() => _addNode('task')),
        ),
        AdminFabMenuAction(
          title: 'Rezka',
          icon: Icons.content_cut_rounded,
          onTap: () => _runMapToolAction(_addRezkaNode),
        ),
      ];
    }
    return [
      AdminFabMenuAction(
        title: 'Ishlov',
        icon: Icons.engineering_rounded,
        onTap: () => _runMapToolAction(() => _addNode('task')),
      ),
      AdminFabMenuAction(
        title: 'Aparat',
        icon: Icons.precision_manufacturing_rounded,
        onTap: () => _runMapToolAction(() => _addNode('apparatus')),
      ),
      AdminFabMenuAction(
        title: 'Rezka',
        icon: Icons.content_cut_rounded,
        onTap: () => _runMapToolAction(_addRezkaNode),
      ),
      AdminFabMenuAction(
        title: 'Formula',
        icon: Icons.functions_rounded,
        onTap: () => _runMapToolAction(() => _addNode('formula')),
      ),
      AdminFabMenuAction(
        title: 'Condition',
        icon: Icons.call_split_rounded,
        onTap: () => _runMapToolAction(() => _addNode('condition')),
      ),
    ];
  }

  bool _apparatusGroupMatchesOrder(AdminApparatusGroup group) {
    return group.apparatus.any(
      (apparatus) => productionMapApparatusMatchesOrder(
        AdminWarehouse(warehouse: apparatus, parentWarehouse: 'aparat - A'),
        widget.orderContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewMetrics = MediaQueryData.fromView(View.of(context));
    final systemBottomInset = dockLayoutBottomInset(
      viewMetrics,
      thinGestureBottom: DockGestureOverlayScope.thinGestureBottomOf(context),
    );
    final dockHeight = appNavigationBarDockHeight(
      height: _productionMapDockHeight,
      systemBottomInset: systemBottomInset,
    );
    final fabBottom = math.max(
      0.0,
      appNavigationBarPrimaryButtonBottom(dockHeight: dockHeight) - dockHeight,
    );
    // System back (swipe) must also return the saved template to the caller.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop(_lastSavedTemplate);
        }
      },
      child: _buildShell(context, scheme, fabBottom),
    );
  }

  Widget _buildShell(
    BuildContext context,
    ColorScheme scheme,
    double fabBottom,
  ) {
    return AppShell(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop(_lastSavedTemplate);
          } else {
            nav.pushNamedAndRemoveUntil(AppRoutes.adminHome, (route) => false);
          }
        },
      ),
      title: 'Production map test',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      actions: [
        if (_orderMode && !widget.readOnly)
          AppShellIconAction(
            key: const ValueKey('production-map-save'),
            icon:
                _savingMap ? Icons.hourglass_top_rounded : Icons.save_outlined,
            onTap: _saveMap,
          ),
      ],
      contentPadding: EdgeInsets.zero,
      animateOnEnter: false,
      bottom: const AdminDock(
        activeTab: AdminDockTab.home,
        showPrimaryFab: false,
      ),
      child: ColoredBox(
        color: scheme.surface,
        child: Stack(
          children: [
            Positioned.fill(
              child: _ProductionMapCanvas(
                readOnly: widget.readOnly,
                nodes: nodes,
                edges: edges,
                connectingFromNodeID: _connectingFromNodeID,
                connectingFromBranch: _connectingFromBranch,
                connectionPreviewEnd: _connectionPreviewEnd,
                onNodeTap: (node) => _editNode(nodes.indexOf(node)),
                onNodeDelete: (node) => _deleteNode(nodes.indexOf(node)),
                onNodeMoved: _moveNode,
                onConnectionStart: _startConnection,
                onConnectionUpdate: _updateConnectionPreview,
                onConnectionEnd: _finishConnection,
                onConnectionCancel: _cancelConnection,
                onEdgeDelete: _removeEdge,
              ),
            ),
            if (!widget.readOnly)
              Positioned(
                left: 10,
                bottom: fabBottom,
                child: AdminFabOverlayActionMenu(
                  actions: _mapToolActions(),
                  closedLabel: 'Element qo‘shish',
                  openLabel: 'Yopish',
                  closedIcon: Icons.add_rounded,
                  alignEnd: false,
                  columns: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductionMapCanvas extends StatefulWidget {
  const _ProductionMapCanvas({
    required this.readOnly,
    required this.nodes,
    required this.edges,
    required this.connectingFromNodeID,
    required this.connectingFromBranch,
    required this.connectionPreviewEnd,
    required this.onNodeTap,
    required this.onNodeDelete,
    required this.onNodeMoved,
    required this.onConnectionStart,
    required this.onConnectionUpdate,
    required this.onConnectionEnd,
    required this.onConnectionCancel,
    required this.onEdgeDelete,
  });

  static const _minCanvasSize = Size(1180, 900);
  static const _nodeSize = Size(260, 60);

  final bool readOnly;
  final List<ProductionMapNode> nodes;
  final List<ProductionMapEdge> edges;
  final String? connectingFromNodeID;
  final String connectingFromBranch;
  final Offset? connectionPreviewEnd;
  final ValueChanged<ProductionMapNode> onNodeTap;
  final ValueChanged<ProductionMapNode> onNodeDelete;
  final void Function(String nodeID, Offset delta) onNodeMoved;
  final void Function(String nodeID, String branch) onConnectionStart;
  final ValueChanged<Offset> onConnectionUpdate;
  final ValueChanged<Offset> onConnectionEnd;
  final VoidCallback onConnectionCancel;
  final ValueChanged<ProductionMapEdge> onEdgeDelete;

  @override
  State<_ProductionMapCanvas> createState() => _ProductionMapCanvasState();
}

class _ProductionMapCanvasState extends State<_ProductionMapCanvas> {
  final _canvasKey = GlobalKey();
  late final TransformationController _transformController;
  bool _didSetInitialTransform = false;
  bool _nodeDragActive = false;
  final Set<int> _canvasPointers = <int>{};
  Offset? _lastConnectionPosition;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canvasSize = _canvasSizeFor(widget.nodes);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.56),
        ),
      ),
      child: SizedBox.expand(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _scheduleInitialTransform(
              viewportSize: constraints.biggest,
              canvasSize: canvasSize,
            );
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPaperPainter(scheme: scheme),
                  ),
                ),
                Listener(
                  onPointerDown: _handleCanvasPointerDown,
                  onPointerUp: _handleCanvasPointerEnd,
                  onPointerCancel: _handleCanvasPointerEnd,
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    constrained: false,
                    panEnabled: !_nodeDragActive,
                    minScale: 0.45,
                    maxScale: 2.4,
                    boundaryMargin: const EdgeInsets.all(760),
                    child: SizedBox(
                      key: _canvasKey,
                      width: canvasSize.width,
                      height: canvasSize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            width: canvasSize.width,
                            height: canvasSize.height,
                            child: CustomPaint(
                              size: canvasSize,
                              painter: _MapCanvasPainter(
                                nodes: widget.nodes,
                                edges: widget.edges,
                                connectionFromNodeID:
                                    widget.connectingFromNodeID,
                                connectionFromBranch:
                                    widget.connectingFromBranch,
                                connectionPreviewEnd:
                                    widget.connectionPreviewEnd,
                                nodeSize: _ProductionMapCanvas._nodeSize,
                                scheme: scheme,
                              ),
                            ),
                          ),
                          if (!widget.readOnly)
                            for (final edge in widget.edges)
                              if (_edgeActionPosition(edge)
                                  case final position?)
                                Positioned(
                                  left: position.dx - 13,
                                  top: position.dy - 13,
                                  child: _EdgeDeleteButton(
                                    edge: edge,
                                    onTap: () => widget.onEdgeDelete(edge),
                                  ),
                                ),
                          for (final node in widget.nodes)
                            Positioned(
                              left: node.x,
                              top: node.y,
                              width: _ProductionMapCanvas._nodeSize.width,
                              child: _MapNodeVisual(
                                node: node,
                                borderRadius: _nodeBorderRadius(node),
                                readOnly: widget.readOnly,
                                onTap: widget.readOnly
                                    ? () {}
                                    : () => widget.onNodeTap(node),
                                canDrag: widget.readOnly
                                    ? () => false
                                    : _canDragNode,
                                onDragStart: () {
                                  if (!_nodeDragActive) {
                                    setState(() => _nodeDragActive = true);
                                  }
                                },
                                onDragUpdate: (details) {
                                  final scale = _transformController.value
                                      .getMaxScaleOnAxis();
                                  widget.onNodeMoved(
                                    node.id,
                                    details.delta / scale,
                                  );
                                },
                                onDragEnd: () {
                                  if (_nodeDragActive) {
                                    setState(() => _nodeDragActive = false);
                                  }
                                },
                                onDelete: widget.readOnly ||
                                        node.kind == 'start' ||
                                        node.kind == 'end'
                                    ? null
                                    : () => widget.onNodeDelete(node),
                                onConnectionDragStart: (globalPosition) {
                                  final canvasPosition = _globalToCanvas(
                                    globalPosition,
                                  );
                                  _lastConnectionPosition = canvasPosition;
                                  widget.onConnectionStart(node.id, '');
                                  widget.onConnectionUpdate(canvasPosition);
                                },
                                onConnectionDragUpdate: (globalPosition) {
                                  final canvasPosition = _globalToCanvas(
                                    globalPosition,
                                  );
                                  _lastConnectionPosition = canvasPosition;
                                  widget.onConnectionUpdate(canvasPosition);
                                },
                                onConnectionDragEnd: () {
                                  final position = _lastConnectionPosition;
                                  _lastConnectionPosition = null;
                                  if (position == null) {
                                    widget.onConnectionCancel();
                                    return;
                                  }
                                  widget.onConnectionEnd(position);
                                },
                                onConnectionDragCancel: () {
                                  _lastConnectionPosition = null;
                                  widget.onConnectionCancel();
                                },
                                floating: false,
                                highlighted:
                                    widget.connectingFromNodeID == node.id,
                              ),
                            ),
                          for (final node in widget.nodes)
                            if (!widget.readOnly &&
                                node.kind == 'condition') ...[
                              Positioned(
                                left: _branchButtonLeft(node, 'true'),
                                top: _branchButtonTop(node),
                                child: _BranchAddButton(
                                  branch: 'true',
                                  onConnectionDragStart: (globalPosition) {
                                    final canvasPosition = _globalToCanvas(
                                      globalPosition,
                                    );
                                    _lastConnectionPosition = canvasPosition;
                                    widget.onConnectionStart(node.id, 'true');
                                    widget.onConnectionUpdate(canvasPosition);
                                  },
                                  onConnectionDragUpdate: (globalPosition) {
                                    final canvasPosition = _globalToCanvas(
                                      globalPosition,
                                    );
                                    _lastConnectionPosition = canvasPosition;
                                    widget.onConnectionUpdate(canvasPosition);
                                  },
                                  onConnectionDragEnd: () {
                                    final position = _lastConnectionPosition;
                                    _lastConnectionPosition = null;
                                    if (position == null) {
                                      widget.onConnectionCancel();
                                      return;
                                    }
                                    widget.onConnectionEnd(position);
                                  },
                                  onConnectionDragCancel: () {
                                    _lastConnectionPosition = null;
                                    widget.onConnectionCancel();
                                  },
                                ),
                              ),
                              Positioned(
                                left: _branchButtonLeft(node, 'false'),
                                top: _branchButtonTop(node),
                                child: _BranchAddButton(
                                  branch: 'false',
                                  onConnectionDragStart: (globalPosition) {
                                    final canvasPosition = _globalToCanvas(
                                      globalPosition,
                                    );
                                    _lastConnectionPosition = canvasPosition;
                                    widget.onConnectionStart(node.id, 'false');
                                    widget.onConnectionUpdate(canvasPosition);
                                  },
                                  onConnectionDragUpdate: (globalPosition) {
                                    final canvasPosition = _globalToCanvas(
                                      globalPosition,
                                    );
                                    _lastConnectionPosition = canvasPosition;
                                    widget.onConnectionUpdate(canvasPosition);
                                  },
                                  onConnectionDragEnd: () {
                                    final position = _lastConnectionPosition;
                                    _lastConnectionPosition = null;
                                    if (position == null) {
                                      widget.onConnectionCancel();
                                      return;
                                    }
                                    widget.onConnectionEnd(position);
                                  },
                                  onConnectionDragCancel: () {
                                    _lastConnectionPosition = null;
                                    widget.onConnectionCancel();
                                  },
                                ),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _scheduleInitialTransform({
    required Size viewportSize,
    required Size canvasSize,
  }) {
    if (_didSetInitialTransform || viewportSize.isEmpty) {
      return;
    }
    _didSetInitialTransform = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _transformController.value = _initialTransform(
        viewportSize: viewportSize,
        canvasSize: canvasSize,
      );
    });
  }

  bool _canDragNode() {
    return _canvasPointers.length <= 1;
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    _canvasPointers.add(event.pointer);
    if (_canvasPointers.length > 1 && _nodeDragActive) {
      setState(() => _nodeDragActive = false);
    }
  }

  void _handleCanvasPointerEnd(PointerEvent event) {
    _canvasPointers.remove(event.pointer);
  }

  Offset _globalToCanvas(Offset globalPosition) {
    final context = _canvasKey.currentContext;
    if (context == null) {
      return Offset.zero;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return Offset.zero;
    }
    return box.globalToLocal(globalPosition);
  }

  Matrix4 _initialTransform({
    required Size viewportSize,
    required Size canvasSize,
  }) {
    final bounds = _nodeBounds();
    if (bounds == null) {
      return Matrix4.identity();
    }
    const padding = 56.0;
    final scaleToFitWidth = viewportSize.width / (bounds.width + padding * 2);
    final readableScale = scaleToFitWidth.clamp(0.88, 1.08);
    final dx = viewportSize.width / 2 - bounds.center.dx * readableScale;
    final dy = padding - bounds.top * readableScale;
    final minDx = viewportSize.width - canvasSize.width * readableScale;
    final minDy = viewportSize.height - canvasSize.height * readableScale;
    final maxDx = math.max(minDx, padding);
    final maxDy = math.max(minDy, padding);
    return Matrix4.identity()
      ..setEntry(0, 0, readableScale)
      ..setEntry(1, 1, readableScale)
      ..setEntry(0, 3, dx.clamp(minDx, maxDx))
      ..setEntry(1, 3, dy.clamp(minDy, maxDy));
  }

  Rect? _nodeBounds() {
    Rect? bounds;
    for (final node in widget.nodes) {
      final rect = Rect.fromLTWH(
        node.x,
        node.y,
        _ProductionMapCanvas._nodeSize.width,
        _ProductionMapCanvas._nodeSize.height,
      );
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    return bounds;
  }

  Size _canvasSizeFor(List<ProductionMapNode> nodes) {
    var maxX = _ProductionMapCanvas._minCanvasSize.width;
    var maxY = _ProductionMapCanvas._minCanvasSize.height;
    for (final node in nodes) {
      final right = node.x + _ProductionMapCanvas._nodeSize.width + 320;
      final bottom = node.y + _ProductionMapCanvas._nodeSize.height + 360;
      if (right > maxX) {
        maxX = right;
      }
      if (bottom > maxY) {
        maxY = bottom;
      }
    }
    return Size(maxX, maxY);
  }

  double _branchButtonLeft(ProductionMapNode node, String branch) {
    const buttonWidth = _BranchAddButton.width;
    final left = switch (branch) {
      'true' => node.x - buttonWidth / 2,
      'false' =>
        node.x + _ProductionMapCanvas._nodeSize.width - buttonWidth / 2,
      _ => node.x,
    };
    return math.max(8, left);
  }

  double _branchButtonTop(ProductionMapNode node) {
    return node.y +
        _ProductionMapCanvas._nodeSize.height / 2 -
        _BranchAddButton.height / 2;
  }

  Offset? _edgeActionPosition(ProductionMapEdge edge) {
    final from = _nodeByID(edge.from);
    final to = _nodeByID(edge.to);
    if (from == null || to == null) {
      return null;
    }
    final fromRect = _nodeRect(from);
    final toRect = _nodeRect(to);
    final branchKey = edge.branch.trim().toLowerCase();
    final start = _startAnchor(from, branchKey, toRect.center);
    final end = _edgeAnchor(toRect, fromRect.center);
    return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  }

  ProductionMapNode? _nodeByID(String id) {
    for (final node in widget.nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  Rect _nodeRect(ProductionMapNode node) {
    return Rect.fromLTWH(
      node.x,
      node.y,
      _ProductionMapCanvas._nodeSize.width,
      _ProductionMapCanvas._nodeSize.height,
    );
  }

  BorderRadius _nodeBorderRadius(ProductionMapNode node) {
    final groupId = node.alternativeGroupId.trim();
    if (groupId.isEmpty) {
      return BorderRadius.circular(28);
    }
    final group = widget.nodes
        .where((item) => item.alternativeGroupId.trim() == groupId)
        .toList()
      ..sort((left, right) => left.x.compareTo(right.x));
    if (group.length <= 1) {
      return BorderRadius.circular(28);
    }
    final index = group.indexWhere((item) => item.id == node.id);
    const outer = Radius.circular(28);
    const inner = Radius.circular(2);
    if (index <= 0) {
      return const BorderRadius.horizontal(left: outer, right: inner);
    }
    if (index == group.length - 1) {
      return const BorderRadius.horizontal(left: inner, right: outer);
    }
    return BorderRadius.circular(2);
  }

  Offset _startAnchor(
    ProductionMapNode node,
    String branchKey,
    Offset fallbackToward,
  ) {
    final rect = _nodeRect(node);
    if (node.kind != 'condition') {
      return _externalPortCenter(rect, fallbackToward);
    }
    return switch (branchKey) {
      'true' => Offset(rect.left, rect.center.dy),
      'false' => Offset(rect.right, rect.center.dy),
      _ => _externalPortCenter(rect, fallbackToward),
    };
  }

  Offset _externalPortCenter(Rect rect, Offset toward) {
    final anchor = _edgeAnchor(rect, toward);
    final vector = anchor - rect.center;
    final distance = vector.distance;
    if (distance == 0) {
      return anchor;
    }
    return anchor + vector / distance * _MapCanvasPainter.portRadius;
  }

  Offset _edgeAnchor(Rect rect, Offset toward) {
    final center = rect.center;
    final dx = toward.dx - center.dx;
    final dy = toward.dy - center.dy;
    if (dx == 0 && dy == 0) {
      return center;
    }
    final halfWidth = rect.width / 2;
    final halfHeight = rect.height / 2;
    final ratio = math.max(dx.abs() / halfWidth, dy.abs() / halfHeight);
    return Offset(center.dx + dx / ratio, center.dy + dy / ratio);
  }
}

class _BranchAddButton extends StatelessWidget {
  const _BranchAddButton({
    required this.branch,
    required this.onConnectionDragStart,
    required this.onConnectionDragUpdate,
    required this.onConnectionDragEnd,
    required this.onConnectionDragCancel,
  });

  static const width = 34.0;
  static const height = 34.0;

  final String branch;
  final ValueChanged<Offset> onConnectionDragStart;
  final ValueChanged<Offset> onConnectionDragUpdate;
  final VoidCallback onConnectionDragEnd;
  final VoidCallback onConnectionDragCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branchKey = branch.trim().toLowerCase();
    final color = switch (branchKey) {
      'true' => scheme.primaryContainer,
      'false' => scheme.errorContainer,
      _ => scheme.secondaryContainer,
    };
    final foreground = switch (branchKey) {
      'true' => scheme.onPrimaryContainer,
      'false' => scheme.onErrorContainer,
      _ => scheme.onSecondaryContainer,
    };
    return Tooltip(
      message:
          '${productionMapBranchDisplayLabel(branch)} yo‘liga qo‘l tortish',
      child: SizedBox(
        key: ValueKey('production-map-branch-add-$branch'),
        width: width,
        height: height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) =>
              onConnectionDragStart(details.globalPosition),
          onPanUpdate: (details) =>
              onConnectionDragUpdate(details.globalPosition),
          onPanEnd: (_) => onConnectionDragEnd(),
          onPanCancel: onConnectionDragCancel,
          child: Material(
            color: color,
            borderRadius: BorderRadius.circular(99),
            elevation: 2,
            shadowColor: scheme.shadow.withValues(alpha: 0.18),
            clipBehavior: Clip.antiAlias,
            child: Icon(Icons.add_link_rounded, size: 18, color: foreground),
          ),
        ),
      ),
    );
  }
}

class _EdgeDeleteButton extends StatelessWidget {
  const _EdgeDeleteButton({required this.edge, required this.onTap});

  final ProductionMapEdge edge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final branchKey = edge.branch.trim().toLowerCase();
    final color = switch (branchKey) {
      'true' => scheme.primary,
      'false' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    return Tooltip(
      message: 'Yo‘lni uzish',
      child: Material(
        key: ValueKey(
          'production-map-edge-delete-${edge.from}-${edge.to}-${edge.branch}',
        ),
        color: scheme.surface,
        shape: const CircleBorder(),
        elevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.16),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 26,
            child: Icon(Icons.close_rounded, size: 17, color: color),
          ),
        ),
      ),
    );
  }
}
