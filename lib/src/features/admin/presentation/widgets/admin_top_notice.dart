import 'dart:async';

import 'package:flutter/material.dart';

enum AdminTopNoticeTone { success, error }

const _sheetNoticeAnimationDuration = Duration(milliseconds: 220);
_AdminTopNoticeHandle? _currentAdminTopNotice;

class _AdminTopNoticeHandle {
  _AdminTopNoticeHandle(this._close, {VoidCallback? onTimeout})
      : _onTimeout = onTimeout;

  final VoidCallback _close;
  final VoidCallback? _onTimeout;
  Timer? _timer;
  bool _closed = false;

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _timer?.cancel();
    _timer = null;
    _close();
  }

  void autoCloseAfter(Duration duration) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (_currentAdminTopNotice == this) {
        final onTimeout = _onTimeout;
        if (onTimeout != null) {
          onTimeout();
        } else {
          _currentAdminTopNotice = null;
          close();
        }
      }
    });
  }
}

/// Anchored sheet notices slide from the bottom; other notices use a top banner.
void showAdminTopNotice(
  BuildContext context,
  String message, {
  IconData? icon,
  GlobalKey? anchorKey,
  required AdminTopNoticeTone tone,
}) {
  _currentAdminTopNotice?.close();
  _currentAdminTopNotice = null;
  if (anchorKey != null &&
      _showAnchoredAdminBottomNotice(
        context,
        message,
        icon: icon,
        anchorKey: anchorKey,
        tone: tone,
      )) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentMaterialBanner();

  messenger.showMaterialBanner(
    _adminNoticeBanner(context, message, icon: icon, tone: tone),
  );
  final handle = _AdminTopNoticeHandle(
    messenger.hideCurrentMaterialBanner,
  );
  _currentAdminTopNotice = handle;
  handle.autoCloseAfter(const Duration(seconds: 5));
}

void dismissAdminTopNotice() {
  final handle = _currentAdminTopNotice;
  _currentAdminTopNotice = null;
  handle?.close();
}

bool _showAnchoredAdminBottomNotice(
  BuildContext context,
  String message, {
  required GlobalKey anchorKey,
  IconData? icon,
  required AdminTopNoticeTone tone,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final anchorContext = anchorKey.currentContext;
  final renderObject = anchorContext?.findRenderObject();
  if (overlay == null || renderObject is! RenderBox || !renderObject.hasSize) {
    return false;
  }
  final visibility = ValueNotifier<double>(1);
  Timer? exitTimer;
  late final OverlayEntry entry;
  late final _AdminTopNoticeHandle handle;
  void closeNotice() {
    if (_currentAdminTopNotice == handle) {
      _currentAdminTopNotice = null;
    }
    handle.close();
  }

  entry = OverlayEntry(
    builder: (context) {
      final mediaQuery = MediaQuery.of(context);
      return Positioned.fill(
        child: IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final anchor = anchorKey.currentContext?.findRenderObject();
              final overlayBox = overlay.context.findRenderObject();
              if (anchor is! RenderBox ||
                  !anchor.hasSize ||
                  overlayBox is! RenderBox) {
                return const SizedBox.shrink();
              }
              final topLeft = anchor.localToGlobal(
                Offset.zero,
                ancestor: overlayBox,
              );
              final bounds = (topLeft & anchor.size).intersect(
                Rect.fromLTRB(
                  0,
                  0,
                  constraints.maxWidth,
                  constraints.maxHeight - mediaQuery.viewInsets.bottom,
                ),
              );
              if (bounds.isEmpty) {
                return const SizedBox.shrink();
              }
              final bottomInset = (mediaQuery.padding.bottom -
                      (constraints.maxHeight - bounds.bottom))
                  .clamp(0.0, mediaQuery.padding.bottom)
                  .toDouble();
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: bounds,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ValueListenableBuilder<double>(
                          valueListenable: visibility,
                          builder: (context, target, child) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: target),
                              duration: _sheetNoticeAnimationDuration,
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return FractionalTranslation(
                                  translation: Offset(0, 1 - value),
                                  child: Opacity(opacity: value, child: child),
                                );
                              },
                              child: child,
                            );
                          },
                          child: _adminNoticeBanner(
                            context,
                            message,
                            icon: icon,
                            tone: tone,
                            bottomInset: bottomInset,
                          ),
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
    },
  );
  handle = _AdminTopNoticeHandle(
    () {
      exitTimer?.cancel();
      entry.remove();
      entry.dispose();
      visibility.dispose();
    },
    onTimeout: () {
      visibility.value = 0;
      exitTimer = Timer(_sheetNoticeAnimationDuration, closeNotice);
    },
  );
  overlay.insert(entry);
  _currentAdminTopNotice = handle;
  handle.autoCloseAfter(const Duration(seconds: 5));
  return true;
}

MaterialBanner _adminNoticeBanner(
  BuildContext context,
  String message, {
  IconData? icon,
  required AdminTopNoticeTone tone,
  double bottomInset = 0,
}) {
  const successBackground = Color(0xFFE6F4EA);
  const successForeground = Color(0xFF173A24);
  const errorBackground = Color(0xFFFCE8E6);
  const errorForeground = Color(0xFF5F1412);
  return MaterialBanner(
    elevation: 0,
    backgroundColor: switch (tone) {
      AdminTopNoticeTone.success => successBackground,
      AdminTopNoticeTone.error => errorBackground,
    },
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    dividerColor: Colors.transparent,
    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
    leading: icon == null ? null : Icon(icon),
    content: Text(message),
    contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: switch (tone) {
            AdminTopNoticeTone.success => successForeground,
            AdminTopNoticeTone.error => errorForeground,
          },
        ),
    actions: const [SizedBox.shrink()],
    minActionBarHeight: 0,
  );
}
