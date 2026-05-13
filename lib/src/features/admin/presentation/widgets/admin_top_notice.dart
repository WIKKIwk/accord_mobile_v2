import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

OverlayEntry? _currentAdminTopNotice;

void showAdminTopNotice(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
}) {
  _currentAdminTopNotice?.remove();
  _currentAdminTopNotice = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AdminTopNotice(
      message: message,
      icon: icon,
      onDismissed: () {
        if (_currentAdminTopNotice == entry) {
          _currentAdminTopNotice = null;
        }
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  _currentAdminTopNotice = entry;
  Overlay.of(context, rootOverlay: true).insert(entry);
}

class _AdminTopNotice extends StatefulWidget {
  const _AdminTopNotice({
    required this.message,
    required this.icon,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final VoidCallback onDismissed;

  @override
  State<_AdminTopNotice> createState() => _AdminTopNoticeState();
}

class _AdminTopNoticeState extends State<_AdminTopNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    reverseDuration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 1850), () async {
      if (!mounted) {
        return;
      }
      await _controller.reverse();
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top =
        MediaQuery.viewPaddingOf(context).top + AppTheme.appBarHeight + 8;
    return Positioned(
      top: top,
      left: 14,
      right: 14,
      child: SafeArea(
        top: false,
        bottom: false,
        child: FadeTransition(
          opacity: _curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.35),
              end: Offset.zero,
            ).animate(_curve),
            child: Material(
              elevation: 3,
              shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.18),
              color: theme.colorScheme.surfaceContainerHigh,
              surfaceTintColor: theme.colorScheme.surfaceTint,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
