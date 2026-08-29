part of 'admin_production_map_test_screen.dart';

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
                                    enabled: !productionMapIncomingEdgeIsLocked(
                                      edge,
                                      widget.lockedNodeIds,
                                    ),
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
                                apparatusCatalog: widget.apparatusCatalog,
                                borderRadius: _nodeBorderRadius(node),
                                readOnly: widget.readOnly,
                                locked: widget.lockedNodeIds.contains(node.id),
                                onTap: widget.readOnly ||
                                        widget.lockedNodeIds.contains(node.id)
                                    ? () {}
                                    : () => widget.onNodeTap(node),
                                canDrag: widget.readOnly ||
                                        widget.lockedNodeIds.contains(node.id)
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
                                        widget.lockedNodeIds
                                            .contains(node.id) ||
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
}
