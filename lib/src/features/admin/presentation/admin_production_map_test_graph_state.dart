part of 'admin_production_map_test_screen.dart';

extension _AdminProductionMapTestGraphState
    on _AdminProductionMapTestScreenState {
  void _addNode(String kind) {
    final id = '${kind}_${_nextNodeIndex++}';
    _updateScreenState(() {
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

  Future<void> _addRezkaNode(AdminApparatus apparatus) async {
    final id = 'rezka_${_nextNodeIndex++}';
    final node = _newNode(id, 'apparatus').copyWith(
      title: apparatus.name,
      apparatusId: apparatus.id,
    );
    final edited = await _showRezkaEditSheet(node);
    if (edited == null || !mounted) {
      return;
    }
    _updateScreenState(() {
      _insertBeforeEnd(edited);
    });
  }

  Future<void> _addApparatusGroup(CanonicalApparatusGroup group) async {
    final compatible = group.apparatus
        .where((apparatus) => isCanonicalApparatusId(apparatus.id))
        .where(_apparatusMatchesCurrentMap)
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
    if (picked.skip) {
      _updateScreenState(() {
        _insertAlternativeApparatusNodes(group, compatible);
      });
      return;
    }
    final selected = picked.apparatus;
    if (selected == null) return;
    if (group.operation == 'cut') {
      await _addRezkaNode(selected);
      return;
    }
    _updateScreenState(() {
      final id = 'apparatus_${_nextNodeIndex++}';
      _insertBeforeEnd(
        _newNode(
          id,
          'apparatus',
        ).copyWith(
          title: selected.name,
          apparatusId: selected.id,
        ),
      );
    });
  }

  void _insertAlternativeApparatusNodes(
    CanonicalApparatusGroup group,
    List<AdminApparatus> apparatus,
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
    final groupId = 'alt_${group.operation}_$_nextNodeIndex';
    final groupLabel = canonicalApparatusGroupLabel(group, context.l10n);
    final previousBottomY = previousNodes.map((node) => node.y).fold<double>(
          _AdminProductionMapTestScreenState._minNodeY,
          (max, y) => y > max ? y : max,
        );
    final previousCenterX = previousNodes
            .map((node) => node.x + _ProductionMapCanvas._nodeSize.width / 2)
            .fold<double>(0, (sum, x) => sum + x) /
        previousNodes.length;
    final y = previousBottomY + _AdminProductionMapTestScreenState._nodeStepY;
    final firstX = previousCenterX -
        (_ProductionMapCanvas._nodeSize.width * apparatus.length) / 2;
    final created = <ProductionMapNode>[];
    for (var index = 0; index < apparatus.length; index++) {
      final id = 'apparatus_${_nextNodeIndex++}';
      created.add(
        ProductionMapNode(
          id: id,
          kind: 'apparatus',
          title: apparatus[index].name,
          apparatusId: apparatus[index].id,
          alternativeGroupId: groupId,
          alternativeGroupLabel: groupLabel,
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
      node.copyWith(
        x: previous.x,
        y: previous.y + _AdminProductionMapTestScreenState._nodeStepY,
      ),
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
        y: previous.y + _AdminProductionMapTestScreenState._nodeStepY,
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
      end.copyWith(
        y: deepest + _AdminProductionMapTestScreenState._nodeStepY,
      ),
      ignoreIds: {end.id},
    );
  }

  void _moveNode(String nodeID, Offset delta) {
    if (_isNodeLocked(nodeID)) {
      return;
    }
    final index = nodes.indexWhere((node) => node.id == nodeID);
    if (index < 0) {
      return;
    }
    final node = nodes[index];
    _updateScreenState(() {
      final position = _clampNodePosition(Offset(node.x, node.y) + delta);
      nodes[index] = node.copyWith(x: position.dx, y: position.dy);
      _resolveNodeOverlaps(anchorID: nodeID);
    });
  }

  void _startConnection(String nodeID, [String branch = '']) {
    if (_isNodeLocked(nodeID)) {
      return;
    }
    _updateScreenState(() {
      _connectingFromNodeID = nodeID;
      _connectingFromBranch = branch.trim().toLowerCase();
      _connectionPreviewEnd = null;
    });
  }

  void _updateConnectionPreview(Offset canvasPosition) {
    if (_connectingFromNodeID == null) {
      return;
    }
    _updateScreenState(() => _connectionPreviewEnd = canvasPosition);
  }

  void _finishConnection(Offset canvasPosition) {
    final fromID = _connectingFromNodeID;
    final branchKey = _connectingFromBranch;
    _updateScreenState(() {
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
      if (_isNodeLocked(source.id) || _isNodeLocked(target.id)) {
        return;
      }
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
    _updateScreenState(() {
      _connectingFromNodeID = null;
      _connectingFromBranch = '';
      _connectionPreviewEnd = null;
    });
  }

  void _removeEdge(ProductionMapEdge edge) {
    if (productionMapIncomingEdgeIsLocked(edge, _lockedNodeIds)) {
      return;
    }
    _updateScreenState(() {
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
          Offset(
            origin.dx + column * _AdminProductionMapTestScreenState._nodeStepX,
            origin.dy + row * _AdminProductionMapTestScreenState._nodeStepY,
          ),
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
          final aLocked = _isNodeLocked(nodes[a].id);
          final bLocked = _isNodeLocked(nodes[b].id);
          if (aLocked && bLocked) {
            continue;
          }
          moved = true;
          if (aLocked) {
            _moveNodeByIndex(b, separation);
          } else if (bLocked) {
            _moveNodeByIndex(a, -separation);
          } else if (nodes[a].id == anchorID) {
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
    if (_isNodeLocked(node.id)) {
      return;
    }
    final position = _clampNodePosition(Offset(node.x, node.y) + delta);
    nodes[index] = node.copyWith(x: position.dx, y: position.dy);
  }

  void _repackRemainingOverlaps({required String anchorID}) {
    for (var pass = 0; pass < nodes.length; pass++) {
      var changed = false;
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (node.id == anchorID ||
            _isNodeLocked(node.id) ||
            !_nodeOverlapsAny(node)) {
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
      position.dx
          .clamp(
            _AdminProductionMapTestScreenState._minNodeX,
            _AdminProductionMapTestScreenState._maxNodeX,
          )
          .toDouble(),
      position.dy
          .clamp(
            _AdminProductionMapTestScreenState._minNodeY,
            _AdminProductionMapTestScreenState._maxNodeY,
          )
          .toDouble(),
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
    ).inflate(_AdminProductionMapTestScreenState._nodeGap / 2);
  }

  bool _isOrderProductTask(ProductionMapNode node) {
    return node.kind == 'task' &&
        (node.id.trim() == 'order' || node.roleCode.trim() == 'zakaz');
  }

  bool _isStationTask(ProductionMapNode node) {
    return node.kind == 'task' && !_isOrderProductTask(node);
  }

  Future<AdminApparatus?> _pickStationApparatus({String? title}) async {
    return showModalBottomSheet<AdminApparatus>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<AdminApparatus>(
          title: title ?? 'Stansiya tanlang',
          hintText: 'Aparat qidiring',
          pageSize: 50,
          cacheKey: 'production-map:station-apparatus'
              ':${_apparatusFilterCacheSuffix()}',
          loadPage: (query, offset, limit) async {
            final apparatus = await MobileApi.instance.adminApparatus(
              query: query,
              limit: 200,
            );
            return apparatus
                .where(
                  (apparatus) => productionMapApparatusMatchesOrder(
                    apparatus,
                    widget.orderContext,
                  ),
                )
                .skip(offset)
                .take(limit)
                .toList(growable: false);
          },
          itemTitle: (item) => item.name,
          itemSubtitle: (_) => 'Aparat',
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
    if (_isNodeLocked(node.id)) {
      return;
    }
    if (_isRezkaProductionNode(node, _apparatusCatalog)) {
      final edited = await _showRezkaEditSheet(node);
      if (edited == null || !mounted) {
        return;
      }
      _updateScreenState(() => nodes[index] = edited);
      return;
    }
    if (node.kind == 'apparatus') {
      final picked = await showModalBottomSheet<AdminApparatus>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (context) {
          return M3AsyncPickerSheet<AdminApparatus>(
            title: 'Aparat tanlang',
            hintText: 'Aparat qidiring',
            pageSize: 50,
            cacheKey: 'production-map:apparatus'
                ':${_apparatusFilterCacheSuffix()}',
            loadPage: (query, offset, limit) async {
              final apparatus = await MobileApi.instance.adminApparatus(
                query: query,
                limit: 200,
              );
              return apparatus
                  .where(
                    _apparatusMatchesCurrentMap,
                  )
                  .skip(offset)
                  .take(limit)
                  .toList(growable: false);
            },
            itemTitle: (item) => item.name,
            itemSubtitle: (_) => 'Aparat',
            onSelected: (item) => Navigator.of(context).pop(item),
          );
        },
      );
      if (picked == null || !mounted) {
        return;
      }
      _updateScreenState(
        () => nodes[index] = node.copyWith(
          title: picked.name,
          apparatusId: picked.id,
        ),
      );
      return;
    }
    if (_isStationTask(node)) {
      final picked = await _pickStationApparatus(title: 'Ishlov stansiyasi');
      if (picked == null || !mounted) {
        return;
      }
      _updateScreenState(
        () => nodes[index] = node.copyWith(
          title: picked.name,
          apparatusId: picked.id,
        ),
      );
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
    _updateScreenState(() => nodes[index] = edited);
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
    if (_isNodeLocked(node.id) || node.kind == 'start' || node.kind == 'end') {
      return;
    }
    _updateScreenState(() {
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
    if (_apparatusCatalogLoading) {
      return [
        AdminFabMenuAction(
          title: 'Aparatlar yuklanmoqda',
          icon: Icons.hourglass_top_rounded,
          enabled: false,
          onTap: () {},
        ),
        _taskToolAction(),
      ];
    }
    if (_apparatusCatalogError != null) {
      return [
        AdminFabMenuAction(
          title: 'Aparatlarni qayta yuklash',
          icon: Icons.refresh_rounded,
          onTap: () => _runMapToolAction(
            () => unawaited(_loadCanonicalApparatusCatalog()),
          ),
        ),
        _taskToolAction(),
      ];
    }
    final groupActions = [
      for (final group in canonicalApparatusGroups(_apparatusCatalog))
        if (group.isClassified && _apparatusGroupMatchesOrder(group))
          AdminFabMenuAction(
            title: canonicalApparatusGroupLabel(group, context.l10n),
            icon: _apparatusGroupMenuIcon(group.operation),
            enabled: !_apparatusGroupBlocked(group),
            onTap: () => _runMapToolAction(() {
              if (_apparatusGroupBlocked(group)) {
                showAdminTopNotice(context, _laminatsiyaOversizeMessage);
                return;
              }
              unawaited(_addApparatusGroup(group));
            }),
          ),
    ];
    return [
      if (groupActions.isEmpty)
        AdminFabMenuAction(
          title: 'Mos aparatlar topilmadi',
          icon: Icons.precision_manufacturing_rounded,
          enabled: false,
          onTap: () {},
        )
      else
        ...groupActions,
      _taskToolAction(),
      if (!_orderMode) ...[
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
      ],
    ];
  }

  AdminFabMenuAction _taskToolAction() {
    return AdminFabMenuAction(
      title: 'Ishlov',
      icon: Icons.engineering_rounded,
      onTap: () => _runMapToolAction(() => _addNode('task')),
    );
  }

  IconData _apparatusGroupMenuIcon(String operation) {
    return switch (operation) {
      'print' => Icons.print_outlined,
      'laminate' => Icons.layers_outlined,
      'cut' => Icons.content_cut_rounded,
      'package' => Icons.inventory_2_outlined,
      'glue' => Icons.water_drop_outlined,
      _ => Icons.precision_manufacturing_rounded,
    };
  }

  bool _apparatusGroupMatchesOrder(CanonicalApparatusGroup group) {
    if (_apparatusGroupIsLaminatsiya(group)) {
      return true;
    }
    return group.apparatus.any(_apparatusMatchesCurrentMap);
  }

  bool _apparatusGroupIsLaminatsiya(CanonicalApparatusGroup group) {
    return group.operation == 'laminate';
  }

  bool _apparatusGroupBlocked(CanonicalApparatusGroup group) {
    return _apparatusGroupIsLaminatsiya(group) &&
        !_productionMapLaminatsiyaMatchesCurrentMap(
          widget.orderContext,
          nodes,
          _apparatusCatalog,
        );
  }

  bool _apparatusMatchesCurrentMap(AdminApparatus apparatus) {
    if (apparatus.operation == 'laminate') {
      return _productionMapLaminatsiyaMatchesCurrentMap(
        widget.orderContext,
        nodes,
        _apparatusCatalog,
      );
    }
    return productionMapApparatusMatchesOrder(apparatus, widget.orderContext);
  }

  Future<ProductionMapNode?> _showRezkaEditSheet(ProductionMapNode node) {
    return showModalBottomSheet<ProductionMapNode>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _RezkaNodeEditSheet(
        node: node,
        frameCount: _productionMapOrderFrameCount(widget.orderContext),
      ),
    );
  }
}
