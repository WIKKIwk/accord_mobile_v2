import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../localization/urdu_aware_text.dart';
import '../display/marquee_text.dart';
import '../lists/m3_segmented_list.dart';

// The existing admin transfer list, parameterized for its data and callbacks.
class TransferDragPayload<T, Z> {
  const TransferDragPayload({required this.items, required this.source});
  final List<T> items;
  final Z source;
}

typedef TransferItemCardBuilder<T> = Widget Function({
  required T item,
  required int index,
  required M3SegmentVerticalSlot slot,
  required bool selected,
  required bool disabled,
  required VoidCallback? onToggleSelect,
  required Widget? trailing,
  required BorderRadius? borderRadiusOverride,
});

class TransferListRow extends StatelessWidget {
  const TransferListRow({
    super.key,
    required this.slot,
    required this.title,
    required this.subtitle,
    required this.identity,
    required this.leading,
    required this.trailing,
    this.onTap,
    this.borderRadiusOverride,
    this.disabled = false,
  });
  final M3SegmentVerticalSlot slot;
  final Widget title;
  final String subtitle;
  final String identity;
  final Widget leading;
  final Widget trailing;
  final VoidCallback? onTap;
  final BorderRadius? borderRadiusOverride;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      borderRadiusOverride: borderRadiusOverride,
      backgroundColor: disabled ? scheme.surfaceContainerHighest : null,
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.48 : 1,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      OverflowMarqueeText(
                        text: subtitle,
                        startDelay: Duration(
                          milliseconds:
                              1000 + (identity.hashCode.abs() % 5) * 350,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class TransferItemTitle extends StatelessWidget {
  const TransferItemTitle({
    super.key,
    required this.code,
    required this.title,
    required this.identity,
    required this.theme,
    required this.scheme,
    this.titleColor,
    this.secondaryColor,
  });
  final String code;
  final String title;
  final String identity;
  final ThemeData theme;
  final ColorScheme scheme;
  final Color? titleColor;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final resolvedTitleStyle = theme.textTheme.titleMedium?.copyWith(
      color: titleColor,
      fontWeight: FontWeight.w700,
    );
    final resolvedCodeStyle = theme.textTheme.labelMedium?.copyWith(
      color: secondaryColor ?? scheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );
    // Qatorlar bir vaqtda sinxron yugurmasligi uchun har bir zakazga
    // o'z hashidan kelib chiqqan kichik start-delay beramiz.
    final staggerMs = 700 + (identity.hashCode.abs() % 5) * 350;
    final marqueeDelay = Duration(milliseconds: staggerMs);
    if (code.isEmpty) {
      return OverflowMarqueeText(
        text: title,
        style: resolvedTitleStyle,
        startDelay: marqueeDelay,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Cheksiz kenglikda (masalan o'lchov bosqichida) eski ellipsis.
        if (!constraints.maxWidth.isFinite) {
          return Text.rich(
            TextSpan(
              children: [
                TextSpan(text: code, style: resolvedCodeStyle),
                TextSpan(
                  text: ' • ',
                  style: resolvedCodeStyle?.copyWith(
                    color: secondaryColor ?? scheme.outline,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: title, style: resolvedTitleStyle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        // Kod doim ko'rinib turadi, faqat uzun nom karusel bo'ladi.
        return Row(
          children: [
            Flexible(
              flex: 0,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: code, style: resolvedCodeStyle),
                    TextSpan(
                      text: ' • ',
                      style: resolvedCodeStyle?.copyWith(
                        color: secondaryColor ?? scheme.outline,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
              ),
            ),
            Expanded(
              child: OverflowMarqueeText(
                text: title,
                style: resolvedTitleStyle,
                startDelay: marqueeDelay,
              ),
            ),
          ],
        );
      },
    );
  }
}

class TransferIndexBadge extends StatelessWidget {
  const TransferIndexBadge({
    super.key,
    required this.index,
    this.selected = false,
    this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: UrduAwareText(
            '${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) {
      return badge;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: badge,
      ),
    );
  }
}

class TransferDragHandle extends StatelessWidget {
  const TransferDragHandle({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(Icons.drag_handle_rounded, color: color),
    );
  }
}

class TransferDropZone<T, Z, P extends TransferDragPayload<T, Z>>
    extends StatelessWidget {
  const TransferDropZone({
    super.key,
    required this.zone,
    required this.items,
    required this.selectedItemIds,
    required this.draggingItems,
    required this.draggingSource,
    required this.canMoveTo,
    required this.isItemDisabled,
    required this.sameZone,
    required this.itemId,
    required this.itemKey,
    required this.emptyState,
    required this.itemCardBuilder,
    required this.batchLabel,
    this.listKey,
    this.scrollController,
    required this.onToggleSelect,
    required this.buildDragPayload,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });
  final Z zone;
  final List<T> items;
  final Set<String> selectedItemIds;
  final List<T> draggingItems;
  final Z? draggingSource;
  final bool Function(
    T item,
    Z target,
    Z source,
  ) canMoveTo;
  final bool Function(T item, Z zone) isItemDisabled;
  final bool Function(Z a, Z b) sameZone;
  final String Function(T item) itemId;
  final Key Function(T item, Z zone, bool disabled) itemKey;
  final Widget emptyState;
  final TransferItemCardBuilder<T> itemCardBuilder;
  final String Function(int count) batchLabel;
  final Key? listKey;
  final ScrollController? scrollController;
  final ValueChanged<String> onToggleSelect;
  final P Function({
    required T item,
    required Z source,
    required List<T> zoneItems,
  }) buildDragPayload;
  final ValueChanged<P> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required List<T> items,
    required Z from,
    required Z to,
  }) onMove;

  @override
  Widget build(BuildContext context) {
    final draggingIds = {
      for (final item in draggingItems) itemId(item),
    };
    final dragSource = draggingSource;
    final isDropTarget = dragSource != null && !sameZone(dragSource, zone);
    final blocked = isDropTarget &&
        draggingItems.isNotEmpty &&
        draggingItems.any((item) => !canMoveTo(item, zone, dragSource));
    return DragTarget<P>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (details) {
        if (sameZone(details.data.source, zone)) {
          return false;
        }
        return details.data.items.every(
          (item) => canMoveTo(item, zone, details.data.source),
        );
      },
      onAcceptWithDetails: (details) {
        onMove(
          items: details.data.items,
          from: details.data.source,
          to: zone,
        );
      },
      builder: (context, candidate, rejected) {
        final showBlocked = blocked || rejected.isNotEmpty;
        final zoneBody = items.isEmpty
            ? emptyState
            : ListView.builder(
                key: listKey,
                controller: scrollController,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = itemId(item);
                  final isDragging = dragSource != null &&
                      sameZone(dragSource, zone) &&
                      draggingIds.contains(id);
                  final slot =
                      M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    items.length,
                  );
                  if (isDragging) {
                    return const AnimatedSize(
                      duration: Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox.shrink(),
                    );
                  }
                  final payload = buildDragPayload(
                    item: item,
                    source: zone,
                    zoneItems: items,
                  );
                  final disabled = isItemDisabled(item, zone);
                  return Padding(
                    key: itemKey(item, zone, disabled),
                    padding: EdgeInsets.only(
                      bottom: index < items.length - 1
                          ? M3SegmentedListGeometry.gap
                          : 0,
                    ),
                    child: _TransferItemTile<T, Z, P>(
                      item: item,
                      source: zone,
                      itemCardBuilder: itemCardBuilder,
                      batchLabel: batchLabel,
                      index: index,
                      slot: slot,
                      selected: selectedItemIds.contains(id),
                      disabled: disabled,
                      payload: payload,
                      onToggleSelect: () => onToggleSelect(id),
                      onDragStarted: () => onDragStarted(payload),
                      onDragEnded: onDragEnded,
                    ),
                  );
                },
              );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: showBlocked
                ? ImageFiltered(
                    key: const ValueKey('move-zone-blocked'),
                    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Opacity(
                      opacity: 0.42,
                      child: IgnorePointer(child: zoneBody),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('move-zone-active'),
                    child: zoneBody,
                  ),
          ),
        );
      },
    );
  }
}

class _TransferItemTile<T, Z, P extends TransferDragPayload<T, Z>>
    extends StatelessWidget {
  const _TransferItemTile({
    required this.item,
    required this.itemCardBuilder,
    required this.batchLabel,
    required this.source,
    required this.index,
    required this.slot,
    required this.selected,
    required this.disabled,
    required this.payload,
    required this.onToggleSelect,
    required this.onDragStarted,
    required this.onDragEnded,
  });
  final T item;
  final TransferItemCardBuilder<T> itemCardBuilder;
  final String Function(int count) batchLabel;
  final Z source;
  final int index;
  final M3SegmentVerticalSlot slot;
  final bool selected;
  final bool disabled;
  final P payload;
  final VoidCallback onToggleSelect;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final feedbackRadius = BorderRadius.circular(
          M3SegmentedListGeometry.cornerLarge,
        );
        final scheme = Theme.of(context).colorScheme;
        final batchCount = payload.items.length;
        return itemCardBuilder(
          item: item,
          index: index,
          slot: slot,
          selected: selected,
          disabled: disabled,
          onToggleSelect: disabled ? null : onToggleSelect,
          borderRadiusOverride: null,
          trailing: disabled
              ? TransferDragHandle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                )
              : LongPressDraggable<P>(
                  data: payload,
                  axis: Axis.vertical,
                  childWhenDragging: const SizedBox.shrink(),
                  dragAnchorStrategy: (_, handleContext, position) {
                    final box = handleContext.findRenderObject()! as RenderBox;
                    final local = box.globalToLocal(position);
                    return Offset(cardWidth - 28, local.dy);
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: cardWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          itemCardBuilder(
                            item: item,
                            index: index,
                            slot: M3SegmentVerticalSlot.top,
                            selected: selected,
                            disabled: false,
                            onToggleSelect: null,
                            trailing: null,
                            borderRadiusOverride: feedbackRadius,
                          ),
                          if (batchCount > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: UrduAwareText(
                                batchLabel(batchCount),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  onDragStarted: onDragStarted,
                  onDragEnd: (_) => onDragEnded(),
                  onDraggableCanceled: (_, __) => onDragEnded(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleSelect,
                    child: TransferDragHandle(color: scheme.onSurfaceVariant),
                  ),
                ),
        );
      },
    );
  }
}
