import 'package:flutter/material.dart';

import 'm3_segmented_list.dart';

/// Shared sequence list used by the work map and material catalog. Fixed rows
/// are rendered in the footer, outside the reorderable range.
class M3SequenceList extends StatelessWidget {
  const M3SequenceList({
    super.key,
    required this.itemCount,
    required this.itemKey,
    required this.itemBuilder,
    required this.onReorder,
    this.reorderableItemCount,
    this.listKey,
    this.padding,
    this.header,
  }) : assert(reorderableItemCount == null ||
            (reorderableItemCount >= 0 && reorderableItemCount <= itemCount));

  final int itemCount;
  final int? reorderableItemCount;
  final Key? listKey;
  final Key Function(int index) itemKey;
  final IndexedWidgetBuilder itemBuilder;
  final ReorderCallback onReorder;
  final EdgeInsets? padding;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final movableCount = reorderableItemCount ?? itemCount;
    Widget row(int index) => Padding(
          key: itemKey(index),
          padding: EdgeInsets.only(
            bottom: index < itemCount - 1 ? M3SegmentedListGeometry.gap : 0,
          ),
          child: itemBuilder(context, index),
        );
    return ReorderableListView.builder(
      key: listKey,
      padding: padding,
      header: header,
      footer: movableCount < itemCount
          ? Column(
              children: [
                for (var index = movableCount; index < itemCount; index++)
                  row(index),
              ],
            )
          : null,
      buildDefaultDragHandles: false,
      itemCount: movableCount,
      // onReorderItem supplies the final index, including downward moves.
      onReorderItem: onReorder,
      itemBuilder: (context, index) => row(index),
    );
  }
}

class M3SequenceDragHandle extends StatelessWidget {
  const M3SequenceDragHandle({
    super.key,
    required this.index,
    this.enabled = true,
  });

  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
        index: index,
        enabled: enabled,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.drag_handle_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
