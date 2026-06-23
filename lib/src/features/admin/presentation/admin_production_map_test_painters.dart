part of 'admin_production_map_test_screen.dart';

class _GridPaperPainter extends CustomPainter {
  const _GridPaperPainter({required this.scheme});

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size, scheme);
  }

  @override
  bool shouldRepaint(covariant _GridPaperPainter oldDelegate) {
    return oldDelegate.scheme != scheme;
  }
}

void _paintGrid(Canvas canvas, Size size, ColorScheme scheme) {
  final gridColor = scheme.brightness == Brightness.dark
      ? scheme.onSurface.withValues(alpha: 0.24)
      : scheme.outlineVariant.withValues(alpha: 0.42);
  final paint = Paint()
    ..color = gridColor
    ..strokeWidth = 1;
  for (var x = 0.0; x <= size.width; x += 40) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }
  for (var y = 0.0; y <= size.height; y += 40) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
}

class _MapCanvasPainter extends CustomPainter {
  const _MapCanvasPainter({
    required this.nodes,
    required this.edges,
    required this.connectionFromNodeID,
    required this.connectionFromBranch,
    required this.connectionPreviewEnd,
    required this.nodeSize,
    required this.scheme,
  });

  final List<ProductionMapNode> nodes;
  final List<ProductionMapEdge> edges;
  final String? connectionFromNodeID;
  final String connectionFromBranch;
  final Offset? connectionPreviewEnd;
  final Size nodeSize;
  final ColorScheme scheme;

  static const portRadius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final byID = {for (final node in nodes) node.id: node};
    for (final edge in edges) {
      final from = byID[edge.from];
      final to = byID[edge.to];
      if (from == null || to == null) {
        continue;
      }
      _paintEdge(canvas, from, to, edge.branch);
    }
    final previewFromID = connectionFromNodeID;
    final previewEnd = connectionPreviewEnd;
    if (previewFromID != null && previewEnd != null) {
      final from = byID[previewFromID];
      if (from != null) {
        _paintPreviewEdge(canvas, from, previewEnd, connectionFromBranch);
      }
    }
  }

  void _paintEdge(
    Canvas canvas,
    ProductionMapNode from,
    ProductionMapNode to,
    String branch,
  ) {
    final fromRect = _nodeRect(from);
    final toRect = _nodeRect(to);
    final branchKey = branch.trim().toLowerCase();
    final start = _startAnchor(from, branchKey, toRect.center);
    final end = _edgeAnchor(toRect, fromRect.center);
    final path = _elasticPath(
      start: start,
      end: end,
      startOrigin: fromRect.center,
      endOrigin: toRect.center,
    );
    final color = switch (branchKey) {
      'true' => scheme.primary,
      'false' => scheme.error,
      _ => scheme.onSurfaceVariant,
    };
    final paint = Paint()
      ..color = color.withValues(alpha: 0.76)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    _paintStartPort(canvas, from, branchKey, start, color);
    _paintArrow(canvas, end, start, color);
    if (branchKey.isNotEmpty) {
      _paintBranchLabel(
        canvas,
        Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2 - 16),
        productionMapBranchDisplayLabel(branchKey),
        color,
      );
    }
  }

  void _paintPreviewEdge(
    Canvas canvas,
    ProductionMapNode from,
    Offset previewEnd,
    String branch,
  ) {
    final branchKey = branch.trim().toLowerCase();
    final start = _startAnchor(from, branchKey, previewEnd);
    final path = _elasticPath(
      start: start,
      end: previewEnd,
      startOrigin: _nodeRect(from).center,
      endOrigin: previewEnd,
    );
    final color = switch (branchKey) {
      'true' => scheme.primary,
      'false' => scheme.error,
      _ => scheme.primary,
    };
    final paint = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
    _paintStartPort(canvas, from, branchKey, start, color);
    canvas.drawCircle(previewEnd, 7, Paint()..color = color);
    if (branchKey.isNotEmpty) {
      _paintBranchLabel(
        canvas,
        Offset(
          (start.dx + previewEnd.dx) / 2,
          (start.dy + previewEnd.dy) / 2 - 16,
        ),
        productionMapBranchDisplayLabel(branchKey),
        color,
      );
    }
  }

  Rect _nodeRect(ProductionMapNode node) {
    return Rect.fromLTWH(node.x, node.y, nodeSize.width, nodeSize.height);
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
    return anchor + vector / distance * portRadius;
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

  Path _elasticPath({
    required Offset start,
    required Offset end,
    required Offset startOrigin,
    required Offset endOrigin,
  }) {
    final distance = (end - start).distance;
    final handle = (distance * 0.42).clamp(54.0, 190.0);
    final startTangent = _normalizedOr(start - startOrigin, end - start);
    final endTangent = _normalizedOr(end - endOrigin, start - end);
    final control1 = start + startTangent * handle;
    final control2 = end + endTangent * handle;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
  }

  Offset _normalizedOr(Offset value, Offset fallback) {
    if (value.distance > 0.001) {
      return value / value.distance;
    }
    if (fallback.distance > 0.001) {
      return fallback / fallback.distance;
    }
    return const Offset(1, 0);
  }

  void _paintStartPort(
    Canvas canvas,
    ProductionMapNode node,
    String branchKey,
    Offset center,
    Color color,
  ) {
    if (node.kind == 'condition' && branchKey.isNotEmpty) {
      return;
    }
    canvas.drawCircle(
      center,
      portRadius,
      Paint()
        ..color = scheme.surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      portRadius,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke,
    );
  }

  void _paintArrow(Canvas canvas, Offset tip, Offset tail, Color color) {
    final angle = math.atan2(tip.dy - tail.dy, tip.dx - tail.dx);
    const arrowSize = 12.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - math.cos(angle - math.pi / 6) * arrowSize,
        tip.dy - math.sin(angle - math.pi / 6) * arrowSize,
      )
      ..lineTo(
        tip.dx - math.cos(angle + math.pi / 6) * arrowSize,
        tip.dy - math.sin(angle + math.pi / 6) * arrowSize,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _paintBranchLabel(
    Canvas canvas,
    Offset center,
    String label,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 18,
      height: textPainter.height + 10,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(99));
    canvas.drawRRect(rrect, Paint()..color = color);
    textPainter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - textPainter.width) / 2,
        rect.top + (rect.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return true;
  }
}
