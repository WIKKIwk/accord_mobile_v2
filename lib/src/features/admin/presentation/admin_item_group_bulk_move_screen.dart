import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/search/search_normalizer.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_summary_card.dart';

part 'admin_item_group_bulk_move_screen__AdminItemGroupBulkMoveTabState_methods_01.dart';
part 'admin_item_group_bulk_move_screen__AdminItemGroupBulkMoveTabState_methods_02.dart';
part 'admin_item_group_bulk_move_screen_widgets_part_01.dart';
part 'admin_item_group_bulk_move_screen_declarations_part_02.dart';

class _AdminItemGroupBulkMoveTabState extends State<AdminItemGroupBulkMoveTab> {
  static const int _initialPageSize = 30;
  static const int _scrollPageSize = 50;
  static const double _prefetchExtent = 2800;
  static _AdminItemGroupBulkMoveCache? _cache;

  final ScrollController _scrollController = ScrollController();
  final List<SupplierItem> _items = <SupplierItem>[];
  final List<String> _groups = <String>[];
  final Set<String> _selectedCodes = <String>{};
  late final TextEditingController _searchController;
  late final bool _ownsSearchController;

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _submitting = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _selectedGroup;
  bool _groupMenuOpen = false;
  bool _showScrollTopButton = false;
  Timer? _searchDebounce;
  Timer? _autoTopUpTimer;
  List<SupplierItem>? _serverSearchItems;
  String? _serverSearchQuery;
  int _serverSearchGeneration = 0;
  bool _autoTopUpDone = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ownsSearchController = widget.searchController == null;
    _searchController = widget.searchController ?? TextEditingController();
    _searchController.addListener(_handleSearchControllerChanged);
    _scrollController.addListener(_handleScroll);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _autoTopUpTimer?.cancel();
    _searchController.removeListener(_handleSearchControllerChanged);
    if (_ownsSearchController) {
      _searchController.dispose();
    }
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _selectedCodes.isNotEmpty &&
        (_selectedGroup?.trim().isNotEmpty ?? false) &&
        !_submitting;
    final searchTerm = _searchController.text.trim();
    final visibleItems = _visibleItems(searchTerm);
    final rowCount = visibleItems.isEmpty ? 1 : visibleItems.length;
    final listItemCount = 2 + rowCount + (_loadingMore ? 1 : 0);

    final content = _initialLoading
        ? const Center(child: AppLoadingIndicator())
        : _errorText != null && _items.isEmpty
            ? _ErrorView(
                message: _errorText!,
                onRetry: () =>
                    _loadInitial(clearGroup: false, forceRefresh: true),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      EdgeInsets.fromLTRB(4, 8, 4, widget.embedded ? 24 : 164),
                  itemCount: listItemCount,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _BulkMoveHeader(
                        groups: _groups,
                        selectedGroup: _selectedGroup,
                        groupMenuOpen: _groupMenuOpen,
                        selectedCount: _selectedCodes.length,
                        submitting: _submitting,
                        canSubmit: canSubmit,
                        onChooseGroup: _chooseGroup,
                        onSelectGroup: _selectGroup,
                        searchController:
                            _ownsSearchController ? _searchController : null,
                        onSubmit: _moveSelected,
                      );
                    }

                    if (index == 1) {
                      return const SizedBox(height: 12);
                    }

                    if (visibleItems.isEmpty && index == 2) {
                      return const _EmptyItemsView();
                    }

                    final rowIndex = index - 2;
                    if (rowIndex >= 0 && rowIndex < visibleItems.length) {
                      final item = visibleItems[rowIndex];
                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          4,
                          rowIndex == 0 ? 0 : M3SegmentedListGeometry.gap,
                          4,
                          0,
                        ),
                        child: _ItemRow(
                          slot: M3SegmentedListGeometry
                              .standaloneListSlotForIndex(
                            rowIndex,
                            visibleItems.length,
                          ),
                          item: item,
                          selected: _selectedCodes.contains(item.code),
                          onTap: _submitting ? null : () => _toggleItem(item),
                        ),
                      );
                    }

                    if (_loadingMore && index == listItemCount - 1) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: AppLoadingIndicator()),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              );

    if (!_showScrollTopButton) {
      return ExcludeSemantics(child: content);
    }

    return ExcludeSemantics(
      child: Stack(
        children: [
          content,
          PositionedDirectional(
            end: 16,
            bottom: widget.embedded ? 16 : 96,
            child: _ScrollToTopButton(size: 48, onTap: _scrollToTop),
          ),
        ],
      ),
    );
  }
}
