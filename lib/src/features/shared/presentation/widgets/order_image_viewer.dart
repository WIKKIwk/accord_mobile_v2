import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/display/image_fade.dart';

/// Order photos use the whole viewport for gestures, without a smaller crop.
class OrderImageViewer extends StatefulWidget {
  const OrderImageViewer({
    super.key,
    required this.image,
    this.heroTag,
    this.maxScale = 64,
  });

  final ImageProvider? image;
  final Object? heroTag;
  final double maxScale;

  @override
  State<OrderImageViewer> createState() => _OrderImageViewerState();
}

class _OrderImageViewerState extends State<OrderImageViewer> {
  double _scale = 1;
  double _rotation = 0;
  Offset _offset = Offset.zero;
  double _startScale = 1;
  double _startRotation = 0;
  Offset _startScenePoint = Offset.zero;

  Offset _rotate(Offset point, double angle) => Offset(
        point.dx * math.cos(angle) - point.dy * math.sin(angle),
        point.dx * math.sin(angle) + point.dy * math.cos(angle),
      );

  Offset _scenePoint(Offset focalPoint, Offset center) =>
      _rotate(focalPoint - center - _offset, -_rotation) / _scale;

  void _start(ScaleStartDetails details, Offset center) {
    _startScale = _scale;
    _startRotation = _rotation;
    _startScenePoint = _scenePoint(details.localFocalPoint, center);
  }

  void _update(ScaleUpdateDetails details, Offset center) {
    setState(() {
      _scale = (_startScale * details.scale).clamp(0.1, widget.maxScale);
      _rotation = _startRotation + details.rotation;
      _offset = details.localFocalPoint -
          center -
          _rotate(_startScenePoint, _rotation) * _scale;
    });
  }

  void _scroll(PointerSignalEvent event, Offset center) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final scenePoint = _scenePoint(event.localPosition, center);
      setState(() {
        _scale = (_scale * math.exp(-event.scrollDelta.dy * 0.002))
            .clamp(0.1, widget.maxScale);
        _offset = event.localPosition -
            center -
            _rotate(scenePoint, _rotation) * _scale;
      });
    });
  }

  void _turn(double angle) {
    setState(() {
      _rotation += angle;
      _offset = _rotate(_offset, angle);
    });
  }

  void _reset() {
    setState(() {
      _scale = 1;
      _rotation = 0;
      _offset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final center = constraints.biggest.center(Offset.zero);
            Widget image = widget.image == null
                ? const Icon(Icons.image_outlined, color: Colors.white)
                : ImageFade(
                    image: widget.image!,
                    fit: BoxFit.contain,
                    placeholder: const SizedBox.shrink(),
                    errorBuilder: (_, __) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                    ),
                  );
            if (widget.heroTag != null) {
              image = Hero(tag: widget.heroTag!, child: image);
            }
            return ClipRect(
              child: Listener(
                onPointerSignal: (event) => _scroll(event, center),
                child: GestureDetector(
                  key: const ValueKey('order-image-viewport'),
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) => _start(details, center),
                  onScaleUpdate: (details) => _update(details, center),
                  child: Transform(
                    key: const ValueKey('order-image-transform'),
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                      ..rotateZ(_rotation)
                      ..scaleByDouble(_scale, _scale, _scale, 1),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox.expand(child: image),
                    ),
                  ),
                ),
              ),
            );
          }),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('order-image-rotate-left'),
                    tooltip:
                        context.l10n.productionText('worker.image.rotate_left'),
                    onPressed: () => _turn(-math.pi / 2),
                    icon: const Icon(Icons.rotate_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const ValueKey('order-image-rotate-right'),
                    tooltip: context.l10n
                        .productionText('worker.image.rotate_right'),
                    onPressed: () => _turn(math.pi / 2),
                    icon: const Icon(Icons.rotate_right_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const ValueKey('order-image-reset'),
                    tooltip: context.l10n.productionText('worker.image.reset'),
                    onPressed: _reset,
                    icon: const Icon(Icons.fit_screen_rounded),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    key: const ValueKey('order-image-close'),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
