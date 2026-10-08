part of 'aparatchi_paddon_detail_screen.dart';

class _PaddonSwipeRemoveCard extends StatefulWidget {
  const _PaddonSwipeRemoveCard({
    required this.actionKey,
    required this.borderRadius,
    required this.label,
    required this.onRemove,
    required this.child,
  });

  final Key actionKey;
  final BorderRadius borderRadius;
  final String label;
  final VoidCallback onRemove;
  final Widget child;

  @override
  State<_PaddonSwipeRemoveCard> createState() => _PaddonSwipeRemoveCardState();
}

class _PaddonSwipeRemoveCardState extends State<_PaddonSwipeRemoveCard>
    with SingleTickerProviderStateMixin {
  static const _actionWidth = 64.0;
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _settle(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final open =
        velocity < -300 || (velocity <= 300 && _controller.value >= 0.5);
    _controller.animateTo(open ? 1 : 0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final revealed = _controller.value > 0;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _controller.stop(),
          onHorizontalDragUpdate: (details) {
            _controller.value =
                (_controller.value - details.delta.dx / _actionWidth)
                    .clamp(0.0, 1.0);
          },
          onHorizontalDragEnd: _settle,
          onHorizontalDragCancel: () => _controller.reverse(),
          onTap: revealed ? () => _controller.reverse() : null,
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: _actionWidth,
                      height: double.infinity,
                      child: IgnorePointer(
                        ignoring: !revealed,
                        child: ExcludeSemantics(
                          excluding: !revealed,
                          child: Tooltip(
                            message: widget.label,
                            child: Material(
                              color: scheme.error,
                              child: InkWell(
                                key: widget.actionKey,
                                onTap: widget.onRemove,
                                child: Semantics(
                                  button: true,
                                  label: widget.label,
                                  child: Center(
                                    child: Icon(
                                      Icons.remove_rounded,
                                      color: scheme.onError,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(-_actionWidth * _controller.value, 0),
                  child: AbsorbPointer(absorbing: revealed, child: child),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
