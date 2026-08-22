part of 'admin_production_map_test_screen.dart';

class _PlainActionButton extends StatefulWidget {
  const _PlainActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_PlainActionButton> createState() => _PlainActionButtonState();
}

class _PlainActionButtonState extends State<_PlainActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onTap != null;
    final background = scheme.primary;
    final foreground = scheme.onPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.985 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            splashColor: scheme.onPrimary.withValues(alpha: 0.12),
            highlightColor: scheme.onPrimary.withValues(alpha: 0.08),
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
            onTapCancel:
                enabled ? () => setState(() => _pressed = false) : null,
            onTap: widget.onTap,
            child: Opacity(
              opacity: enabled ? 1 : 0.48,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: foreground, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w800,
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

class _DismissibleBottomSheetFrame extends StatelessWidget {
  const _DismissibleBottomSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: media.height * 0.9),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SafeArea(top: false, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ApparatusGroupPickResult {
  const _ApparatusGroupPickResult({this.apparatus, this.skip = false});

  final AdminApparatus? apparatus;
  final bool skip;
}

class _ApparatusGroupPickerSheet extends StatelessWidget {
  const _ApparatusGroupPickerSheet({
    required this.group,
    required this.apparatus,
  });

  final CanonicalApparatusGroup group;
  final List<AdminApparatus> apparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    canonicalApparatusGroupLabel(group, context.l10n),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const _ApparatusGroupPickResult(skip: true)),
                  child: const Text('Skip'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in apparatus)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                elevation: 0,
                color: scheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: const Icon(Icons.precision_manufacturing_rounded),
                  title: Text(item.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_ApparatusGroupPickResult(apparatus: item)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductionMapOrderConfirmationDialog extends StatelessWidget {
  const _ProductionMapOrderConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Zakaz ochish',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'production-map-order-confirm-close',
                        ),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Zakaz ochilsinmi? Raqam tizim tomonidan avtomatik beriladi.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey(
                            'production-map-order-cancel',
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Bekor qilish'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('production-map-order-confirm'),
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Tasdiqlash'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
