import 'package:flutter/material.dart';

const m3ListMutationAnimationDuration = Duration(milliseconds: 180);

class M3AnimatedListEntry extends StatefulWidget {
  const M3AnimatedListEntry({
    super.key,
    required this.visible,
    required this.revision,
    required this.child,
    this.animateIn = false,
    this.transitionKey,
  });

  final bool visible;
  final bool animateIn;
  final Object revision;
  final Key? transitionKey;
  final Widget child;

  @override
  State<M3AnimatedListEntry> createState() => _M3AnimatedListEntryState();
}

class _M3AnimatedListEntryState extends State<M3AnimatedListEntry> {
  late bool _entered;

  @override
  void initState() {
    super.initState();
    _entered = !widget.animateIn;
    if (!_entered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _entered = true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visible && _entered;
    return TweenAnimationBuilder<double>(
      duration: m3ListMutationAnimationDuration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: visible ? 1 : 0),
      builder: (context, factor, child) => ClipRect(
        child: Align(
          heightFactor: factor,
          alignment: Alignment.topCenter,
          child: Opacity(opacity: factor, child: child),
        ),
      ),
      child: KeyedSubtree(
        key: widget.transitionKey,
        child: AnimatedSwitcher(
          duration: m3ListMutationAnimationDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey<Object>(widget.revision),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
