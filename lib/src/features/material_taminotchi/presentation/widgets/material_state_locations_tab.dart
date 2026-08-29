import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import '../../../../core/formatters/quantity_formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../../core/widgets/lists/m3_animated_list_entry.dart';
import '../../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../../core/widgets/shell/app_retry_state.dart';
import '../../../../core/widgets/shell/app_shell.dart';
import '../../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../../admin/presentation/widgets/admin_summary_card.dart';
import '../../../shared/models/inventory_movement_models.dart';
import 'raw_material_list_assignment.dart';
import 'raw_material_order_assignment_section.dart';
import 'package:flutter/material.dart';

part 'material_state_locations_tab_MaterialStateLocationsTabState_resplit_methods_01.dart';
part 'material_state_locations_tab_models_resplit_part_01.dart';

class MaterialStateLocationsTabState extends State<MaterialStateLocationsTab> {
  late Future<_MaterialStateLocationsData> _future;
  _MaterialStateLocationsData? _data;
  Timer? _searchDebounce;
  String _query = '';
  String _selectedStateId = '';
  String _busyAssetKey = '';
  bool _filterExpanded = false;
  final Set<String> _selectedAssetKeys = {};
  final Set<String> _exitingAssetKeys = {};
  final Set<String> _enteringAssetKeys = {};

  bool get _selectionMode => _selectedAssetKeys.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MaterialStateLocationsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
          return AppRetryState(onRetry: reload);
        }
        final data = _data ??
            snapshot.data ??
            const _MaterialStateLocationsData(assets: [], locations: []);
        final stateNames = <String, String>{};
        for (final asset in data.assets) {
          final id = asset.physicalLocation.id.trim();
          if (id.isNotEmpty) {
            stateNames[id] = asset.physicalLocation.name.trim();
          }
        }
        final stateIds = stateNames.keys.toList(growable: false)
          ..sort((left, right) => stateNames[left]!.toLowerCase().compareTo(
                stateNames[right]!.toLowerCase(),
              ));
        final selectedStateId =
            stateNames.containsKey(_selectedStateId) ? _selectedStateId : '';
        final visibleAssets = data.assets.where((asset) {
          if (selectedStateId.isEmpty ||
              asset.physicalLocation.id != selectedStateId) {
            return false;
          }
          if (_query.isEmpty) {
            return true;
          }
          final orderAssignment =
              widget.orderAssignments[rawMaterialAssetBarcode(asset)];
          return [
            asset.itemName,
            asset.itemCode,
            asset.identifier,
            asset.assetRef,
            if (orderAssignment != null) orderAssignment.orderLabel,
          ].any((value) => value.toLowerCase().contains(_query));
        }).toList(growable: false);
        return ColoredBox(
          color: AppTheme.shellStart(context),
          child: AppRefreshIndicator(
            onRefresh: reload,
            allowRefreshOnShortContent: true,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(4, 4, 4, widget.bottomPadding),
              children: [
                AdminExpandableFilterChip<String>(
                  key: const ValueKey('material-state-filter'),
                  chipKey: const ValueKey('material-state-filter-chip'),
                  label: 'State',
                  emptyLabel: 'Tanlanmagan',
                  icon: Icons.location_on_outlined,
                  selectedValue:
                      selectedStateId.isEmpty ? null : selectedStateId,
                  options: [
                    for (final stateId in stateIds)
                      AdminFilterChipOption<String>(
                        value: stateId,
                        label: stateNames[stateId]!,
                        key: ValueKey('material-state-option-$stateId'),
                      ),
                  ],
                  expanded: _filterExpanded,
                  onToggle: () => setState(
                    () => _filterExpanded = !_filterExpanded,
                  ),
                  onSelect: (stateId) {
                    clearSelection();
                    setState(() {
                      _selectedStateId = stateId;
                      _filterExpanded = false;
                    });
                  },
                  optionKeyPrefix: 'material-state-option-chip',
                ),
                if (stateIds.isEmpty)
                  const _MaterialStateEmpty(
                    message: 'Siz joylashtirgan State’dagi mahsulot topilmadi',
                  )
                else if (selectedStateId.isEmpty)
                  const _MaterialStateEmpty(message: 'State tanlanmagan')
                else if (visibleAssets.isEmpty)
                  const _MaterialStateEmpty(message: 'Mahsulot topilmadi')
                else
                  M3SegmentSpacedColumn(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    children: [
                      for (var index = 0; index < visibleAssets.length; index++)
                        _buildAnimatedAssetRow(
                          asset: visibleAssets[index],
                          index: index,
                          visibleCount: visibleAssets.length,
                          locations: data.locations,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
