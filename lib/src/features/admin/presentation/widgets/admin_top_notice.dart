import 'package:flutter/material.dart';

_AdminTopNoticeHandle? _currentAdminTopNotice;

class _AdminTopNoticeHandle {
  _AdminTopNoticeHandle(this._close);

  final VoidCallback _close;
  bool _closed = false;

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _close();
  }
}

void showAdminTopNotice(
  BuildContext context,
  String message, {
  IconData? icon,
  GlobalKey? anchorKey,
}) {
  _currentAdminTopNotice?.close();
  _currentAdminTopNotice = null;
  if (anchorKey != null &&
      _showAnchoredAdminTopNotice(
        context,
        message,
        icon: icon,
        anchorKey: anchorKey,
      )) {
    return;
  }
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentMaterialBanner();

  final controller = messenger.showMaterialBanner(
    _adminNoticeBanner(context, message, icon: icon),
  );
  final handle = _AdminTopNoticeHandle(
    messenger.hideCurrentMaterialBanner,
  );
  _currentAdminTopNotice = handle;
  Future<void>.delayed(const Duration(milliseconds: 1850), () {
    if (_currentAdminTopNotice == handle) {
      controller.close();
      _currentAdminTopNotice = null;
    }
  });
}

bool _showAnchoredAdminTopNotice(
  BuildContext context,
  String message, {
  required GlobalKey anchorKey,
  IconData? icon,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final anchorContext = anchorKey.currentContext;
  final renderObject = anchorContext?.findRenderObject();
  if (overlay == null || renderObject is! RenderBox || !renderObject.hasSize) {
    return false;
  }
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final width = renderObject.size.width;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        left: topLeft.dx,
        top: topLeft.dy,
        width: width,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -48 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _adminNoticeBanner(context, message, icon: icon),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  final handle = _AdminTopNoticeHandle(entry.remove);
  _currentAdminTopNotice = handle;
  Future<void>.delayed(const Duration(milliseconds: 1850), () {
    if (_currentAdminTopNotice == handle) {
      handle.close();
      _currentAdminTopNotice = null;
    }
  });
  return true;
}

MaterialBanner _adminNoticeBanner(
  BuildContext context,
  String message, {
  IconData? icon,
}) {
  return MaterialBanner(
    elevation: 0,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    dividerColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    leading: icon == null ? null : Icon(icon),
    content: Text(message),
    contentTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
    actions: const [SizedBox.shrink()],
    minActionBarHeight: 0,
  );
}
