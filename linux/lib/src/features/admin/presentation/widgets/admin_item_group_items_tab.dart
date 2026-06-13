import '../../../shared/models/app_models.dart';
import 'admin_item_group_selected_items.dart';
import 'package:flutter/material.dart';

typedef ItemGroupItemsLoader =
    Future<List<SupplierItem>> Function(String group, int limit, int offset);

class AdminItemGroupItemsTab extends StatefulWidget {
  const AdminItemGroupItemsTab({
    super.key,
    required this.itemGroupsFuture,
    required this.selectedGroup,
    required this.onSelectGroup,
    required this.loadItemsPage,
  });

  final Future<List<String>> itemGroupsFuture;
  final String? selectedGroup;
  final ValueChanged<String> onSelectGroup;
  final ItemGroupItemsLoader loadItemsPage;

  @override
  State<AdminItemGroupItemsTab> createState() => _AdminItemGroupItemsTabState();
}

class _AdminItemGroupItemsTabState extends State<AdminItemGroupItemsTab> {
  static const int _pageSize = 40;
  static const double _loadMoreExtent = 420;

  final ScrollController _scrollController = ScrollController();
  String? _loadedGroup;
  List<SupplierItem> _items = const <SupplierItem>[];
  bool _initialLoading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _syncSelectedGroup();
  }

  @override
  void didUpdateWidget(covariant AdminItemGroupItemsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedGroup != widget.selectedGroup ||
        oldWidget.loadItemsPage != widget.loadItemsPage) {
      _syncSelectedGroup();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _syncSelectedGroup() {
    final group = widget.selectedGroup?.trim();
    if (group == null || group.isEmpty) {
      if (_loadedGroup != null || _items.isNotEmpty) {
        setState(_clearItems);
      }
      return;
    }
    if (group == _loadedGroup) {
      return;
    }
    _loadFirstPage(group);
  }

  Future<void> _refreshItems() async {
    final group = widget.selectedGroup?.trim();
    if (group == null || group.isEmpty) {
      return;
    }
    await _loadFirstPage(group);
  }

  void _clearItems() {
    _loadedGroup = null;
    _items = const <SupplierItem>[];
    _initialLoading = false;
    _loadingMore = false;
    _hasMore = false;
    _error = null;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.extentAfter <= _loadMoreExtent) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage(String group) async {
    setState(() {
      _loadedGroup = group;
      _items = const <SupplierItem>[];
      _initialLoading = true;
      _loadingMore = false;
      _hasMore = false;
      _error = null;
    });
    await _fetchPage(group: group, offset: 0, replace: true);
  }

  Future<void> _loadNextPage() async {
    final group = _loadedGroup?.trim();
    if (group == null ||
        group.isEmpty ||
        _initialLoading ||
        _loadingMore ||
        !_hasMore) {
      return;
    }
    setState(() => _loadingMore = true);
    await _fetchPage(group: group, offset: _items.length, replace: false);
  }

  Future<void> _fetchPage({
    required String group,
    required int offset,
    required bool replace,
  }) async {
    try {
      final page = await widget.loadItemsPage(group, _pageSize, offset);
      if (!mounted || _loadedGroup != group) {
        return;
      }
      setState(() {
        _items = replace ? page : <SupplierItem>[..._items, ...page];
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = page.length == _pageSize;
        _error = null;
      });
    } catch (error) {
      if (!mounted || _loadedGroup != group) {
        return;
      }
      setState(() {
        _initialLoading = false;
        _loadingMore = false;
        _hasMore = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedGroup?.trim();
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 240;
    return RefreshIndicator(
      onRefresh: _refreshItems,
      child: ListView(
        controller: _scrollController,
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
                onPressed: selected == null || selected.isEmpty
                    ? null
                    : _refreshItems,
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
            items: _items,
            initialLoading: _initialLoading,
            loadingMore: _loadingMore,
            hasMore: _hasMore,
            error: _error,
            onRetry: selected == null || selected.isEmpty
                ? null
                : () => _loadFirstPage(selected),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemBuilder: (context, index) {
          final group = groups[index];
          return _GroupTabButton(
            group: group,
            selected: group == selectedGroup,
            onTap: () => onSelectGroup(group),
          );
        },
        separatorBuilder: (_, index) => const SizedBox(width: 4),
        itemCount: groups.length,
      ),
    );
  }
}

class _GroupTabButton extends StatelessWidget {
  const _GroupTabButton({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final String group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 88),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: selected ? 48 : 0,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemsBody extends StatelessWidget {
  const _ItemsBody({
    required this.selectedGroup,
    required this.loadedGroup,
    required this.items,
    required this.initialLoading,
    required this.loadingMore,
    required this.hasMore,
    required this.error,
    required this.onRetry,
  });

  final String? selectedGroup;
  final String? loadedGroup;
  final List<SupplierItem> items;
  final bool initialLoading;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final selected = selectedGroup?.trim();
    if (selected == null || selected.isEmpty) {
      return const _NoticeCard(
        text: 'Tree’dan group uchun Show ni bosing yoki group tanlang',
      );
    }
    if (loadedGroup != selected || initialLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null && items.isEmpty) {
      return _NoticeCard(
        text: 'Group itemlari yuklanmadi',
        actionText: 'Qayta urinish',
        onAction: onRetry,
      );
    }
    return AdminItemGroupSelectedItems(
      group: selected,
      items: items,
      loadingMore: loadingMore,
      hasMore: hasMore,
      pageError: error,
      onRetry: onRetry,
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, this.actionText, this.onAction});

  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onAction, child: Text(actionText!)),
          ],
        ],
      ),
    );
  }
}
