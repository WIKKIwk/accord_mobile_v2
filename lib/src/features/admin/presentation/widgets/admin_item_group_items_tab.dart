import '../../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

typedef ItemGroupItemsLoader = Future<List<SupplierItem>> Function(
  String group,
);

class AdminItemGroupItemsTab extends StatefulWidget {
  const AdminItemGroupItemsTab({
    super.key,
    required this.itemGroupsFuture,
    required this.selectedGroup,
    required this.onSelectGroup,
    required this.loadItems,
  });

  final Future<List<String>> itemGroupsFuture;
  final String? selectedGroup;
  final ValueChanged<String> onSelectGroup;
  final ItemGroupItemsLoader loadItems;

  @override
  State<AdminItemGroupItemsTab> createState() => _AdminItemGroupItemsTabState();
}

class _AdminItemGroupItemsTabState extends State<AdminItemGroupItemsTab> {
  String? _loadedGroup;
  Future<List<SupplierItem>>? _itemsFuture;

  @override
  void initState() {
    super.initState();
    _syncSelectedGroup();
  }

  @override
  void didUpdateWidget(covariant AdminItemGroupItemsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGroup != widget.selectedGroup ||
        oldWidget.loadItems != widget.loadItems) {
      _syncSelectedGroup();
    }
  }

  void _syncSelectedGroup() {
    final group = widget.selectedGroup?.trim();
    if (group == null || group.isEmpty || group == _loadedGroup) {
      return;
    }
    _loadedGroup = group;
    _itemsFuture = widget.loadItems(group);
  }

  Future<void> _refreshItems() async {
    final group = widget.selectedGroup?.trim();
    if (group == null || group.isEmpty) {
      return;
    }
    final future = widget.loadItems(group);
    setState(() {
      _loadedGroup = group;
      _itemsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedGroup?.trim();
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;
    return RefreshIndicator(
      onRefresh: _refreshItems,
      child: ListView(
        padding: EdgeInsets.fromLTRB(12, 16, 12, bottomPadding),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Group itemlari',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                onPressed:
                    selected == null || selected.isEmpty ? null : _refreshItems,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Group tanlanganda mahsulotlar lazy load bilan yuklanadi.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<String>>(
            future: widget.itemGroupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return const _NoticeCard(text: 'Grouplar yuklanmadi');
              }
              return _GroupSelector(
                groups: _displayGroups(
                  snapshot.data ?? const <String>[],
                  selected,
                ),
                selectedGroup: selected,
                onSelectGroup: widget.onSelectGroup,
              );
            },
          ),
          const SizedBox(height: 14),
          _ItemsBody(
            selectedGroup: selected,
            loadedGroup: _loadedGroup,
            itemsFuture: _itemsFuture,
          ),
        ],
      ),
    );
  }
}

List<String> _displayGroups(List<String> groups, String? selectedGroup) {
  final seen = <String>{};
  final result = <String>[];
  final selected = selectedGroup?.trim();
  if (selected != null && selected.isNotEmpty && seen.add(selected)) {
    result.add(selected);
  }
  for (final group in groups) {
    final trimmed = group.trim();
    if (trimmed.isEmpty || !seen.add(trimmed)) {
      continue;
    }
    result.add(trimmed);
  }
  return result;
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.groups,
    required this.selectedGroup,
    required this.onSelectGroup,
  });

  final List<String> groups;
  final String? selectedGroup;
  final ValueChanged<String> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const _NoticeCard(text: 'Group topilmadi');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final group in groups)
          ChoiceChip(
            label: Text(group),
            selected: group == selectedGroup,
            onSelected: (_) => onSelectGroup(group),
          ),
      ],
    );
  }
}

class _ItemsBody extends StatelessWidget {
  const _ItemsBody({
    required this.selectedGroup,
    required this.loadedGroup,
    required this.itemsFuture,
  });

  final String? selectedGroup;
  final String? loadedGroup;
  final Future<List<SupplierItem>>? itemsFuture;

  @override
  Widget build(BuildContext context) {
    final selected = selectedGroup?.trim();
    if (selected == null || selected.isEmpty) {
      return const _NoticeCard(
        text: 'Tree’dan group uchun Show ni bosing yoki group tanlang',
      );
    }
    if (loadedGroup != selected || itemsFuture == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    return FutureBuilder<List<SupplierItem>>(
      future: itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return const _NoticeCard(text: 'Group itemlari yuklanmadi');
        }
        return _SelectedGroupItems(
          group: selected,
          items: snapshot.data ?? const <SupplierItem>[],
        );
      },
    );
  }
}

class _SelectedGroupItems extends StatelessWidget {
  const _SelectedGroupItems({
    required this.group,
    required this.items,
  });

  final String group;
  final List<SupplierItem> items;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _CountBadge(count: items.length),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Bu groupda mahsulot yo‘q',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            for (int index = 0; index < items.length; index++) ...[
              _ItemTile(item: items[index]),
              if (index != items.length - 1)
                Divider(
                  height: 1,
                  indent: 12,
                  endIndent: 12,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
            ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final SupplierItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = item.name.trim().isEmpty ? item.code : item.name;
    final subtitleParts = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      if (item.uom.trim().isNotEmpty) item.uom.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.category_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count item',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium,
        textAlign: TextAlign.center,
      ),
    );
  }
}
