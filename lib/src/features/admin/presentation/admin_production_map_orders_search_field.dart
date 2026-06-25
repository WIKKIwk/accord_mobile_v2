part of 'admin_production_map_orders_screen.dart';

class _OpenedOrderSearchField extends StatelessWidget {
  const _OpenedOrderSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final searchFill = Color.alphaBlend(
      scheme.outlineVariant.withValues(alpha: 0.22),
      scheme.surfaceContainerHighest,
    );
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        final searchActive = focusNode.hasFocus;
        final showHint = !hasText && !searchActive;
        final field = Container(
          height: 58,
          decoration: BoxDecoration(
            color: searchFill,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              const SizedBox(width: 18),
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 20,
                            child: EditableText(
                              controller: controller,
                              focusNode: focusNode,
                              onChanged: onChanged,
                              textAlign: TextAlign.start,
                              textInputAction: TextInputAction.search,
                              maxLines: 1,
                              cursorColor: scheme.primary,
                              backgroundCursorColor:
                                  scheme.surfaceContainerHighest,
                              style: theme.textTheme.bodyMedium!.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        if (!hasText)
                          Align(
                            alignment: Alignment.center,
                            child: AnimatedOpacity(
                              opacity: showHint ? 1 : 0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              child: IgnorePointer(
                                child: Text(
                                  'Ochilgan zakaz qidirish',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w400,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (searchActive)
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: 'Yopish',
                    onPressed: focusNode.unfocus,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (hasText)
                SizedBox.square(
                  dimension: 48,
                  child: IconButton(
                    tooltip: 'Tozalash',
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 18),
            ],
          ),
        );
        return SizedBox(
          width: MediaQuery.sizeOf(context).width - 20,
          height: AppTheme.appBarHeight,
          child: Align(
            alignment: Alignment.center,
            child: Row(
              children: [
                AnimatedContainer(
                  width: searchActive ? 0 : 38,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: ClipRect(
                    child: AnimatedOpacity(
                      opacity: searchActive ? 0 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).openAppDrawerTooltip,
                        style: IconButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () =>
                            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
                        icon: Icon(
                          Icons.menu_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  width: searchActive ? 0 : 6,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                ),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -1),
                    child: field,
                  ),
                ),
                AnimatedContainer(
                  width: searchActive ? 0 : 6,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
