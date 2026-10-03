import 'package:flutter/material.dart';

/// Shared layout of the production order and mold transfer pages.
class TwoPaneTransfer extends StatefulWidget {
  const TwoPaneTransfer({
    super.key,
    required this.topHeader,
    required this.topBody,
    required this.bottomHeader,
    required this.bottomBody,
  });

  final Widget topHeader;
  final Widget topBody;
  final Widget bottomHeader;
  final Widget bottomBody;

  @override
  State<TwoPaneTransfer> createState() => _TwoPaneTransferState();
}

class _TwoPaneTransferState extends State<TwoPaneTransfer> {
  double _topZoneRatio = 0.5;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.7;
          final topFlex = (_topZoneRatio * 1000).round();
          return Column(
            children: [
              Expanded(
                flex: topFlex,
                child: Column(children: [
                  widget.topHeader,
                  const SizedBox(height: 8),
                  Expanded(child: widget.topBody),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerMove: (event) {
                    if (height <= 0) return;
                    final ratio = (_topZoneRatio + event.delta.dy / height)
                        .clamp(0.24, 0.76)
                        .toDouble();
                    if (ratio != _topZoneRatio) {
                      setState(() => _topZoneRatio = ratio);
                    }
                  },
                  child: Row(children: [
                    Expanded(
                        child: Divider(
                            color:
                                Theme.of(context).colorScheme.outlineVariant)),
                    Flexible(child: widget.bottomHeader),
                    Expanded(
                        child: Divider(
                            color:
                                Theme.of(context).colorScheme.outlineVariant)),
                  ]),
                ),
              ),
              Expanded(flex: 1000 - topFlex, child: widget.bottomBody),
            ],
          );
        },
      );
}

class TransferPickerHeader extends StatelessWidget {
  const TransferPickerHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.alignment = Alignment.center,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: alignment,
      child: Tooltip(
        message: title,
        child: Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                )),
                const SizedBox(width: 6),
                Icon(Icons.expand_more_rounded,
                    size: 18, color: scheme.onPrimaryContainer),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
