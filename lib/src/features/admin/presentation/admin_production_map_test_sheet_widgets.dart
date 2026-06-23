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

class _ProductionMapOrderNumberDialog extends StatefulWidget {
  const _ProductionMapOrderNumberDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_ProductionMapOrderNumberDialog> createState() =>
      _ProductionMapOrderNumberDialogState();
}

class _ApparatusGroupPickResult {
  const _ApparatusGroupPickResult({this.apparatus, this.skip = false});

  final AdminWarehouse? apparatus;
  final bool skip;
}

class _ApparatusGroupPickerSheet extends StatelessWidget {
  const _ApparatusGroupPickerSheet({
    required this.group,
    required this.apparatus,
  });

  final AdminApparatusGroup group;
  final List<AdminWarehouse> apparatus;

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
                    group.name,
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
                  title: Text(item.warehouse),
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

class _ProductionMapOrderNumberDialogState
    extends State<_ProductionMapOrderNumberDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(value)) {
      setState(() => _errorText = '4 xonali raqam kiriting');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
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
                            'Zakaz raqami',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey(
                            'production-map-order-number-close',
                          ),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('production-map-order-number-field'),
                      controller: _controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 4,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: '4 xonali zakaz raqami',
                        counterText: '',
                        errorText: _errorText,
                      ),
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                      onSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const ValueKey('production-map-confirm-save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Saqlash'),
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
