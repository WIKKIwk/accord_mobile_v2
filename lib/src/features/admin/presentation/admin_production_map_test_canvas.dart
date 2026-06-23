part of 'admin_production_map_test_screen.dart';

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
