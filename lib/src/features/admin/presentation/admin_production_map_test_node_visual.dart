part of 'admin_production_map_test_screen.dart';

class _MapNodeVisual extends StatefulWidget {
  const _MapNodeVisual({
    required this.node,
    required this.borderRadius,
    required this.readOnly,
    required this.onTap,
    required this.canDrag,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDelete,
    required this.onConnectionDragStart,
    required this.onConnectionDragUpdate,
    required this.onConnectionDragEnd,
    required this.onConnectionDragCancel,
    required this.floating,
    required this.highlighted,
  });

  final ProductionMapNode node;
  final BorderRadius borderRadius;
  final bool readOnly;
  final VoidCallback onTap;
  final bool Function() canDrag;
  final VoidCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback? onDelete;
  final ValueChanged<Offset> onConnectionDragStart;
  final ValueChanged<Offset> onConnectionDragUpdate;
  final VoidCallback onConnectionDragEnd;
  final VoidCallback onConnectionDragCancel;
  final bool floating;
  final bool highlighted;

  @override
  State<_MapNodeVisual> createState() => _MapNodeVisualState();
}

class _MapNodeVisualState extends State<_MapNodeVisual> {
  final Set<int> _activePointers = <int>{};
  int? _dragPointer;
  bool _dragging = false;

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length == 1 &&
        _dragPointer == null &&
        widget.canDrag()) {
      _dragPointer = event.pointer;
      _dragging = true;
      widget.onDragStart();
      return;
    }
    _stopDrag();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_dragging &&
        _activePointers.length == 1 &&
        _dragPointer == event.pointer &&
        widget.canDrag()) {
      widget.onDragUpdate(
        DragUpdateDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          delta: event.delta,
        ),
      );
    } else if (_dragging && !widget.canDrag()) {
      _stopDrag();
    }
  }

  void _handlePointerUp(PointerEvent event) {
    final wasDragPointer = _dragPointer == event.pointer;
    _activePointers.remove(event.pointer);
    if (wasDragPointer) {
      _stopDrag();
    }
    if (_activePointers.isEmpty) {
      _dragPointer = null;
    }
  }

  void _stopDrag() {
    if (!_dragging) {
      _dragPointer = null;
      return;
    }
    _dragging = false;
    _dragPointer = null;
    widget.onDragEnd();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = _backgroundFor(widget.node, scheme);
    final foreground = _foregroundFor(background);
    final mutedForeground = foreground.withValues(alpha: 0.72);
    return Semantics(
      button: true,
      label: '${widget.node.title} node',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: background,
            borderRadius: widget.borderRadius,
            border: widget.highlighted
                ? Border.all(color: scheme.primary, width: 2)
                : null,
            boxShadow: widget.floating
                ? [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerMove: _handlePointerMove,
                    onPointerUp: _handlePointerUp,
                    onPointerCancel: _handlePointerUp,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: foreground.withValues(alpha: 0.14),
                          child: Icon(
                            _iconFor(widget.node.kind),
                            size: 19,
                            color: foreground,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.node.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: foreground,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _subtitleFor(widget.node),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _labelFor(widget.node.kind),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mutedForeground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!widget.readOnly) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: ValueKey(
                      'production-map-node-connect-${widget.node.id}',
                    ),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) =>
                        widget.onConnectionDragStart(details.globalPosition),
                    onPanUpdate: (details) =>
                        widget.onConnectionDragUpdate(details.globalPosition),
                    onPanEnd: (_) => widget.onConnectionDragEnd(),
                    onPanCancel: widget.onConnectionDragCancel,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.add_link_rounded,
                        size: 20,
                        color: mutedForeground,
                      ),
                    ),
                  ),
                ],
                if (widget.onDelete != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: mutedForeground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String kind) {
    return switch (kind) {
      'apparatus' => Icons.precision_manufacturing_rounded,
      'formula' => Icons.functions_rounded,
      'condition' => Icons.call_split_rounded,
      'task' => Icons.engineering_rounded,
      'end' => Icons.flag_rounded,
      _ => Icons.play_arrow_rounded,
    };
  }

  Color _backgroundFor(ProductionMapNode node, ColorScheme scheme) {
    if (node.kind == 'apparatus' &&
        node.alternativeAssignedTitle.trim().isNotEmpty &&
        productionMapWarehouseTitlesMatch(
          node.title,
          node.alternativeAssignedTitle,
        )) {
      return Colors.green.shade100;
    }
    return _colorFor(node.kind, scheme);
  }

  Color _foregroundFor(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  String _labelFor(String kind) {
    return switch (kind) {
      'apparatus' => 'aparat',
      'formula' => 'formula',
      'condition' => 'if',
      'task' => 'ishlov',
      'end' => 'end',
      _ => 'start',
    };
  }

  String _subtitleFor(ProductionMapNode node) {
    if (_isRezkaProductionNode(node)) {
      final details = [
        if (node.rezkaKadrCount != null) '${node.rezkaKadrCount} kadr',
        if (node.rezkaLabelLength != null)
          'etiketka ${_formatRezkaNumber(node.rezkaLabelLength!)}',
      ];
      if (details.isNotEmpty) {
        return details.join(' • ');
      }
    }
    final formula = node.formula;
    if (formula != null) {
      if (node.kind == 'condition') {
        return formula.expression;
      }
      return '${formula.target} = ${formula.expression}';
    }
    if (node.roleCode.trim().isNotEmpty) {
      return node.roleCode;
    }
    if (node.itemCode.trim().isNotEmpty) {
      return node.itemCode;
    }
    return node.kind;
  }

  Color _colorFor(String kind, ColorScheme scheme) {
    return switch (kind) {
      'apparatus' => scheme.secondaryContainer,
      'formula' => scheme.tertiaryContainer,
      'condition' => scheme.primaryContainer,
      'task' => scheme.secondaryContainer,
      _ => scheme.surfaceContainerHighest,
    };
  }
}
