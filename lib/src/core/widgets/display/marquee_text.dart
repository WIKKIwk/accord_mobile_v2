import 'dart:async';

import 'package:flutter/material.dart';

/// Faqat sig'magan matnni avtomatik "karusel" qiladigan widget.
///
/// - Matn eni mavjud kenglikka sig'sa: oddiy [Text] (ellipsis) qaytaradi,
///   hech qanday animatsiya ishlamaydi.
/// - Sig'masa: boshida pauza -> ohirigacha sekin surilish -> ohirida pauza ->
///   boshiga sekin qaytish, takrorlanadi (avtobus bekati tablosi kabi).
/// - Foydalanuvchi qo'lda sura olmaydi ([NeverScrollableScrollPhysics] emas,
///   umuman scrollable yo'q — [Transform] ishlatiladi), shuning uchun
///   [ReorderableListView] drag bilan konflikt qilmaydi.
class OverflowMarqueeText extends StatelessWidget {
  const OverflowMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.startDelay = const Duration(milliseconds: 900),
    this.endPause = const Duration(milliseconds: 2200),
    this.returnPause = const Duration(milliseconds: 1400),
    this.pixelsPerSecond = 24,
    this.maxScrollDuration = const Duration(seconds: 9),
    this.minScrollDuration = const Duration(seconds: 2),
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration startDelay;
  final Duration endPause;
  final Duration returnPause;
  final double pixelsPerSecond;
  final Duration maxScrollDuration;
  final Duration minScrollDuration;

  @override
  Widget build(BuildContext context) {
    final trimmed = text;
    if (trimmed.isEmpty) {
      return Text(trimmed, style: style, maxLines: 1);
    }
    // Reduce-motion hurmati: animatsiyani o'chirish so'ralgan bo'lsa
    // oddiy ellipsis ko'rsatamiz.
    if (MediaQuery.of(context).disableAnimations) {
      return Text(
        trimmed,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (!maxWidth.isFinite) {
          return Text(
            trimmed,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          );
        }
        final scaler = MediaQuery.textScalerOf(context);
        // Font o'lchami/usi bir xil bo'lishi uchun TextPainter ni
        // xuddi shu style + scaler bilan o'lchaymiz.
        final painter = TextPainter(
          text: TextSpan(text: trimmed, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);
        final textWidth = painter.width;
        final textHeight = painter.height;
        painter.dispose();
        // Kichik farqlarni e'tiborsiz qoldiramiz (1px).
        if (textWidth <= maxWidth + 1) {
          return Text(
            trimmed,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          );
        }
        return _MarqueeRunner(
          text: trimmed,
          style: style,
          textAlign: textAlign,
          scaler: scaler,
          maxWidth: maxWidth,
          textWidth: textWidth,
          textHeight: textHeight,
          extra: textWidth - maxWidth,
          startDelay: startDelay,
          endPause: endPause,
          returnPause: returnPause,
          pixelsPerSecond: pixelsPerSecond,
          maxScrollDuration: maxScrollDuration,
          minScrollDuration: minScrollDuration,
        );
      },
    );
  }
}

class _MarqueeRunner extends StatefulWidget {
  const _MarqueeRunner({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.scaler,
    required this.maxWidth,
    required this.textWidth,
    required this.textHeight,
    required this.extra,
    required this.startDelay,
    required this.endPause,
    required this.returnPause,
    required this.pixelsPerSecond,
    required this.maxScrollDuration,
    required this.minScrollDuration,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextScaler scaler;
  final double maxWidth;
  final double textWidth;
  final double textHeight;
  final double extra;
  final Duration startDelay;
  final Duration endPause;
  final Duration returnPause;
  final double pixelsPerSecond;
  final Duration maxScrollDuration;
  final Duration minScrollDuration;

  @override
  State<_MarqueeRunner> createState() => _MarqueeRunnerState();
}

class _MarqueeRunnerState extends State<_MarqueeRunner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _disposed = false;
  Timer? _pauseTimer;

  Duration get _scrollDuration {
    final millis = (widget.extra / widget.pixelsPerSecond * 1000).round();
    final d = Duration(milliseconds: millis);
    if (d < widget.minScrollDuration) return widget.minScrollDuration;
    if (d > widget.maxScrollDuration) return widget.maxScrollDuration;
    return d;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: 0);
    _loop();
  }

  @override
  void didUpdateWidget(covariant _MarqueeRunner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.extra != widget.extra ||
        oldWidget.style != widget.style) {
      _controller.value = 0;
    }
  }

  /// Bekor qilinadigan pauza: dispose'da timer o'chiriladi, shuning uchun
  /// daraxt yopilgandan keyin osilib qolgan timer qolmaydi.
  Future<void> _pause(Duration duration) {
    if (_disposed || !mounted) {
      return Future.value();
    }
    final completer = Completer<void>();
    _pauseTimer?.cancel();
    _pauseTimer = Timer(duration, () {
      _pauseTimer = null;
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> _loop() async {
    // Birinchi kadr chizilgach boshlaymiz.
    await _pause(widget.startDelay);
    while (!_disposed && mounted) {
      try {
        await _controller.animateTo(
          1,
          duration: _scrollDuration,
          curve: Curves.easeInOut,
        );
      } on TickerCanceled {
        return;
      }
      if (_disposed || !mounted) return;
      await _pause(widget.endPause);
      if (_disposed || !mounted) return;
      try {
        await _controller.animateTo(
          0,
          duration: _scrollDuration,
          curve: Curves.easeInOut,
        );
      } on TickerCanceled {
        return;
      }
      if (_disposed || !mounted) return;
      await _pause(widget.returnPause);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sliver (ReorderableListView) ichida balandlik chegarasiz keladi:
    // OverflowBox ga har ikki o'qda ham aniq o'lcham beramiz, aks holda
    // u infinite size so'rab layout'ni buzadi.
    return ClipRect(
      child: SizedBox(
        width: widget.maxWidth,
        height: widget.textHeight,
        child: OverflowBox(
          maxWidth: widget.textWidth,
          maxHeight: widget.textHeight,
          alignment: Alignment.centerLeft,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-widget.extra * _controller.value, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: widget.textWidth,
              height: widget.textHeight,
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: widget.textAlign,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
