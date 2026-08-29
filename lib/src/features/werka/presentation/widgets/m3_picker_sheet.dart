import '../../../../core/theme/app_motion.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/search/search_normalizer.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../../core/widgets/lists/m3_segmented_list.dart';
import 'werka_ai_search_service.dart';
import 'dart:async';
import 'package:flutter/material.dart';

part 'm3_picker_sheet__M3AsyncPickerSheetState_methods_01.dart';
part 'm3_picker_sheet__M3AsyncPickerSheetState_methods_02.dart';
part 'm3_picker_sheet_widgets_part_01.dart';
part 'm3_picker_sheet_widgets_part_02.dart';

const AnimationStyle kM3PickerSheetAnimation = AnimationStyle(
  curve: AppMotion.standardDecelerate,
  reverseCurve: AppMotion.standardAccelerate,
  duration: Duration(milliseconds: 360),
  reverseDuration: Duration(milliseconds: 240),
);

const _pickerSheetBorderRadius = BorderRadius.vertical(
  top: Radius.circular(32),
);

class _M3AsyncPickerSheetState<T> extends State<M3AsyncPickerSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  String _query = '';
  List<String> _searchQueries = const <String>[];
  bool _scanning = false;
  bool _runningEmptyAction = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialSelectionHydrated = false;
  Object? _error;
  List<T> _items = <T>[];
  Map<String, int> _queryRankByItem = <String, int>{};
  Map<String, int> _queryMatchCountByItem = <String, int>{};
  final Map<Object, T> _selectedItems = <Object, T>{};
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    if (!_restoreMemoryCache()) {
      _reload(reset: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static const Set<String> _genericRemoteTokens = {
    'mahsulotlari',
    'products',
    'продукты',
    'молочные',
    'dairy',
    'milk',
    'sut',
    'noodles',
    'instant',
    'spicy',
    'achchiq',
    'курица',
    'острая',
    'kuritsa',
    'ostraya',
    'tovuq',
    'snack',
    'halal',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final l10n = context.l10n;
    final itemBackgroundColor = scheme.surfaceContainerHighest;
    final searchBackgroundColor = scheme.surfaceContainerHighest;

    Widget body;
    if (_loading) {
      body = const Center(child: AppLoadingIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.serverDisconnectedRetry,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => _reload(reset: true),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    } else if (_items.isEmpty) {
      final emptyQuery = _query.trim();
      final emptyActionLabel = widget.emptyActionLabel;
      final canRunEmptyAction = emptyQuery.isNotEmpty &&
          emptyActionLabel != null &&
          widget.onEmptyAction != null;
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRunEmptyAction) ...[
                FilledButton.icon(
                  onPressed: _runningEmptyAction ? null : _handleEmptyAction,
                  icon: _runningEmptyAction
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(emptyActionLabel(emptyQuery)),
                ),
              ] else
                Text(
                  l10n.noRecordsYet,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      final sortedItems = _sortedItems();
      body = ListView.separated(
        controller: _scrollController,
        shrinkWrap: true,
        itemCount: sortedItems.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: M3SegmentedListGeometry.gap),
        itemBuilder: (context, index) {
          if (index >= sortedItems.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: AppLoadingIndicator()),
            );
          }
          final item = sortedItems[index];
          final selected = _selectedItems.containsKey(_selectionKey(item)) ||
              widget.itemSelected?.call(item) == true;
          final subtitle = widget.itemSubtitle(item).trim();
          final slot = M3SegmentedListGeometry.standaloneListSlotForIndex(
            index,
            sortedItems.length,
          );
          final cornerRadius = M3SegmentedListGeometry.cornerRadiusForSlot(
            slot,
          );

          return M3SegmentFilledSurface(
            slot: slot,
            cornerRadius: cornerRadius,
            backgroundColor:
                selected ? scheme.secondaryContainer : itemBackgroundColor,
            onTap: () => _handleItemTap(item),
            onLongPress: widget.onMultiSelected == null
                ? null
                : () => _toggleSelection(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.itemTitle(item),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.onMultiSelected != null &&
                      (_selectedItems.isNotEmpty ||
                          widget.multiSelectOnTap)) ...[
                    const SizedBox(width: 12),
                    Checkbox(
                      value: selected,
                      onChanged: (_) => _toggleSelection(item),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    }

    return AnimatedPadding(
      duration: AppMotion.medium,
      curve: AppMotion.standardDecelerate,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: _M3PickerSurface(
              constraints: BoxConstraints(maxHeight: media.size.height * 0.66),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedItems.isEmpty
                                ? widget.title
                                : widget.selectedCountLabel?.call(
                                      _selectedItems.length,
                                    ) ??
                                    '${_selectedItems.length}',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        if (widget.onMultiSelected != null &&
                            (_selectedItems.isNotEmpty ||
                                widget.multiSelectOnTap))
                          IconButton.filled(
                            onPressed: _confirmMultiSelection,
                            tooltip: widget.confirmSelectionTooltip,
                            icon: const Icon(Icons.check_rounded),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    if ((widget.supportingText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.supportingText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SearchBar(
                      controller: _searchController,
                      hintText: widget.hintText,
                      constraints: const BoxConstraints(minHeight: 58),
                      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
                        EdgeInsets.symmetric(horizontal: 18),
                      ),
                      leading: Icon(
                        Icons.search_rounded,
                        size: 26,
                        color: scheme.onSurfaceVariant,
                      ),
                      trailing: _scanTrailing(scheme),
                      elevation: const WidgetStatePropertyAll<double>(0),
                      backgroundColor: WidgetStatePropertyAll<Color>(
                        searchBackgroundColor,
                      ),
                      side: WidgetStatePropertyAll<BorderSide>(
                        BorderSide(
                          color: scheme.outlineVariant.withValues(alpha: 0.56),
                        ),
                      ),
                      hintStyle: WidgetStatePropertyAll<TextStyle?>(
                        theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      textStyle: WidgetStatePropertyAll<TextStyle?>(
                        theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      shape: WidgetStatePropertyAll<OutlinedBorder>(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onChanged: _scheduleReload,
                    ),
                    const SizedBox(height: 14),
                    Flexible(child: body),
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
