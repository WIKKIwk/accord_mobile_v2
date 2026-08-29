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

class _MaterialStateLocationsData {
  const _MaterialStateLocationsData({
    required this.assets,
    required this.locations,
  });

  final List<InventoryAsset> assets;
  final List<InventoryLocation> locations;
}

class MaterialStateLocationsTab extends StatefulWidget {
  const MaterialStateLocationsTab({
    super.key,
    required this.bottomPadding,
    this.onAssetReturned,
    this.onAssetsChanged,
    this.onAssetQrRequested,
    this.orderAssignments = const {},
    this.onOrderAssignmentChanged,
    this.onSelectionChanged,
  }) : assert(onAssetReturned != null || onAssetsChanged != null);

  final double bottomPadding;
  final Future<void> Function()? onAssetReturned;
  final Future<void> Function(List<InventoryAsset>)? onAssetsChanged;
  final Future<void> Function(InventoryAsset asset)? onAssetQrRequested;
  final Map<String, RawMaterialListAssignment> orderAssignments;
  final Future<void> Function()? onOrderAssignmentChanged;
  final ValueChanged<int>? onSelectionChanged;

  @override
  State<MaterialStateLocationsTab> createState() =>
      MaterialStateLocationsTabState();
}

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

  Future<void> _notifyAssetsChanged(List<InventoryAsset> assets) async {
    final onAssetsChanged = widget.onAssetsChanged;
    if (onAssetsChanged != null) {
      await onAssetsChanged(assets);
      return;
    }
    await widget.onAssetReturned?.call();
  }

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

  Future<_MaterialStateLocationsData> _load() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.inventoryAssets(
        assetKind: InventoryAssetKind.rawMaterial,
        currentUserStatesOnly: true,
        limit: 500,
      ),
      MobileApi.instance.inventoryLocations(),
    ]);
    final assets = (results[0] as List<InventoryAsset>)
        .where(
          (asset) => asset.physicalLocation.kind == InventoryLocationKind.state,
        )
        .toList(growable: false);
    final locations = (results[1] as List<InventoryLocation>)
        .where((location) => location.active)
        .toList(growable: false);
    return _MaterialStateLocationsData(
      assets: assets,
      locations: locations,
    );
  }

  Future<void> reload() async {
    clearSelection();
    final future = _load();
    if (mounted) {
      setState(() {
        _data = null;
        _future = future;
      });
    }
    await future;
  }

  Future<void> applyAssetMutations(List<InventoryAsset> mutations) async {
    final unique = <String, InventoryAsset>{
      for (final asset in mutations) _inventoryStateAssetKey(asset): asset,
    };
    if (unique.isEmpty) {
      return;
    }
    final current = _data ?? await _future;
    if (!mounted) {
      return;
    }
    final currentKeys = current.assets.map(_inventoryStateAssetKey).toSet();
    final exitingKeys = unique.entries
        .where(
          (entry) =>
              currentKeys.contains(entry.key) &&
              (entry.value.kind != InventoryAssetKind.rawMaterial ||
                  entry.value.physicalLocation.kind !=
                      InventoryLocationKind.state),
        )
        .map((entry) => entry.key)
        .toSet();
    if (exitingKeys.isNotEmpty) {
      setState(() => _exitingAssetKeys.addAll(exitingKeys));
      await Future<void>.delayed(m3ListMutationAnimationDuration);
      if (!mounted) {
        return;
      }
    }
    final enteringKeys = <String>{};
    setState(() {
      final next = List<InventoryAsset>.of(current.assets);
      for (final entry in unique.entries) {
        final index = next.indexWhere(
          (asset) => _inventoryStateAssetKey(asset) == entry.key,
        );
        final remainsInState = entry.value.kind ==
                InventoryAssetKind.rawMaterial &&
            entry.value.physicalLocation.kind == InventoryLocationKind.state;
        if (!remainsInState) {
          if (index >= 0) {
            next.removeAt(index);
          }
          continue;
        }
        if (index >= 0) {
          next[index] = entry.value;
        } else {
          next.add(entry.value);
          enteringKeys.add(entry.key);
        }
      }
      _data = _MaterialStateLocationsData(
        assets: List<InventoryAsset>.unmodifiable(next),
        locations: current.locations,
      );
      _exitingAssetKeys.removeAll(unique.keys);
      _enteringAssetKeys.addAll(enteringKeys);
      _selectedAssetKeys.removeWhere(
        (key) => !next.any((asset) => _inventoryStateAssetKey(asset) == key),
      );
    });
    widget.onSelectionChanged?.call(_selectedAssetKeys.length);
    if (enteringKeys.isNotEmpty) {
      unawaited(
        Future<void>.delayed(m3ListMutationAnimationDuration).then((_) {
          _enteringAssetKeys.removeAll(enteringKeys);
        }),
      );
    }
  }

  void clearSelection() {
    if (_selectedAssetKeys.isEmpty) {
      return;
    }
    setState(_selectedAssetKeys.clear);
    widget.onSelectionChanged?.call(0);
  }

  InventoryLocation? _returnLocation(
    InventoryAsset asset,
    List<InventoryLocation> locations,
  ) {
    for (final location in locations) {
      if (location.isWarehouse &&
          location.active &&
          location.warehouseId == asset.custodyWarehouseId) {
        return location;
      }
    }
    return null;
  }

  void _toggleSelection(
    InventoryAsset asset,
    List<InventoryLocation> locations,
  ) {
    if (widget.onSelectionChanged == null ||
        !asset.isAvailable ||
        _returnLocation(asset, locations) == null ||
        _busyAssetKey.isNotEmpty) {
      return;
    }
    final key = _inventoryStateAssetKey(asset);
    setState(() {
      if (!_selectedAssetKeys.add(key)) {
        _selectedAssetKeys.remove(key);
      }
    });
    widget.onSelectionChanged?.call(_selectedAssetKeys.length);
  }

  Future<void> returnSelectedAssets() async {
    if (_selectedAssetKeys.isEmpty || _busyAssetKey.isNotEmpty) {
      return;
    }
    final data = _data ?? await _future;
    if (!mounted) {
      return;
    }
    final assets = data.assets
        .where(
          (asset) =>
              _selectedAssetKeys.contains(_inventoryStateAssetKey(asset)),
        )
        .toList(growable: false);
    final allReturnable = assets.isNotEmpty &&
        assets.every(
          (asset) =>
              asset.isAvailable &&
              _returnLocation(asset, data.locations) != null,
        );
    if (!allReturnable) {
      if (mounted) {
        _showMaterialStateNotice(
          context,
          'Tanlangan mahsulotlardan birini omborga qaytarib bo‘lmaydi',
        );
      }
      return;
    }
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Omborga qaytarish',
          message: '${assets.length} ta mahsulot o‘z omborlariga '
              'qaytarilsinmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Qaytarish',
          verticalActions: true,
          confirmButtonKey: const ValueKey(
            'material-state-selection-return-confirm',
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busyAssetKey = 'return-batch');
    try {
      final updatedAssets =
          await MobileApi.instance.inventoryReturnToWarehousesBatch(
        assets: assets,
        idempotencyKey:
            'state-return-batch-${DateTime.now().microsecondsSinceEpoch}',
        note: 'State’dan o‘z omborlariga qaytarildi',
      );
      _selectedAssetKeys.clear();
      widget.onSelectionChanged?.call(0);
      await _notifyAssetsChanged(updatedAssets);
      if (mounted) {
        _showMaterialStateNotice(
          context,
          '${assets.length} ta mahsulot o‘z omboriga qaytarildi',
        );
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showMaterialStateNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMaterialStateNotice(
          context,
          'Mahsulotlarni omborga qaytarib bo‘lmadi',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyAssetKey = '');
      }
    }
  }

  void handleItemsSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  Future<void> _showAssetDetails(
    InventoryAsset asset,
    List<InventoryLocation> locations,
  ) async {
    final returnLocation = _returnLocation(asset, locations);
    final assetKey = _inventoryStateAssetKey(asset);
    final busy = _busyAssetKey == assetKey;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => _MaterialStateAssetSheet(
        asset: asset,
        busy: busy,
        canReturn: asset.isAvailable && returnLocation != null && !busy,
        onOrderAssignmentChanged: widget.onOrderAssignmentChanged,
        onQrRequested: widget.onAssetQrRequested == null
            ? null
            : () async {
                Navigator.of(sheetContext).pop();
                await widget.onAssetQrRequested!(asset);
              },
        onReturn: returnLocation == null
            ? null
            : () async {
                Navigator.of(sheetContext).pop();
                await _returnToWarehouse(asset, returnLocation);
              },
      ),
    );
  }

  Future<void> _returnToWarehouse(
    InventoryAsset asset,
    InventoryLocation warehouseLocation,
  ) async {
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Omborga qaytarish',
          message:
              '${asset.itemName.trim().isEmpty ? asset.itemCode : asset.itemName} '
              '${warehouseLocation.name} omboriga qaytarilsinmi?',
          cancelLabel: 'Yo‘q',
          confirmLabel: 'Ha',
          verticalActions: true,
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final assetKey = _inventoryStateAssetKey(asset);
    setState(() => _busyAssetKey = assetKey);
    try {
      final updated = await MobileApi.instance.inventoryRelocate(
        assetKind: asset.kind,
        assetRef: asset.assetRef,
        physicalLocationId: warehouseLocation.id,
        idempotencyKey: 'state-return-${DateTime.now().microsecondsSinceEpoch}',
        note: 'State’dan omborga qaytarildi',
      );
      await _notifyAssetsChanged([updated]);
      if (mounted) {
        _showMaterialStateNotice(
          context,
          '${warehouseLocation.name} omboriga qaytarildi',
        );
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showMaterialStateNotice(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMaterialStateNotice(
            context, 'Mahsulotni omborga qaytarib bo‘lmadi');
      }
    } finally {
      if (mounted) {
        setState(() => _busyAssetKey = '');
      }
    }
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

  Widget _buildAnimatedAssetRow({
    required InventoryAsset asset,
    required int index,
    required int visibleCount,
    required List<InventoryLocation> locations,
  }) {
    final assetKey = _inventoryStateAssetKey(asset);
    final exiting = _exitingAssetKeys.contains(assetKey);
    final orderAssignment =
        widget.orderAssignments[rawMaterialAssetBarcode(asset)];
    return M3AnimatedListEntry(
      key: ValueKey('material-state-asset-animation-$assetKey'),
      visible: !exiting,
      animateIn: _enteringAssetKeys.contains(assetKey),
      transitionKey: ValueKey<String>(
        exiting
            ? 'material-state-asset-exiting-${asset.assetRef}'
            : 'material-state-asset-transition-${asset.assetRef}',
      ),
      revision: '${asset.status}:${asset.transferId}:'
          '${asset.placementVersion}:${asset.physicalLocation.id}:'
          '${orderAssignment?.orderId ?? ''}:'
          '${orderAssignment?.orderControl.name ?? ''}',
      child: _MaterialStateAssetRow(
        key: ValueKey('material-state-asset-${asset.assetRef}'),
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
          index,
          visibleCount,
        ),
        asset: asset,
        orderAssignment: orderAssignment,
        busy: _busyAssetKey == assetKey ||
            (_busyAssetKey == 'return-batch' &&
                _selectedAssetKeys.contains(assetKey)),
        selected: _selectedAssetKeys.contains(assetKey),
        onTap: _selectionMode
            ? () => _toggleSelection(asset, locations)
            : () => _showAssetDetails(asset, locations),
        onLongPress: widget.onSelectionChanged != null
            ? () => _toggleSelection(asset, locations)
            : null,
      ),
    );
  }
}

class _MaterialStateEmpty extends StatelessWidget {
  const _MaterialStateEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _MaterialStateAssetRow extends StatelessWidget {
  const _MaterialStateAssetRow({
    super.key,
    required this.slot,
    required this.asset,
    required this.orderAssignment,
    required this.busy,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final M3SegmentVerticalSlot slot;
  final InventoryAsset asset;
  final RawMaterialListAssignment? orderAssignment;
  final bool busy;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final materialTitle =
        asset.itemName.trim().isEmpty ? asset.itemCode : asset.itemName;
    final assigned = orderAssignment != null;
    final title = orderAssignment?.orderLabel ?? materialTitle;
    final subtitle = [
      if (assigned)
        materialTitle
      else if (asset.identifier.trim().isNotEmpty)
        asset.identifier.trim(),
      '${formatRawQuantity(asset.qty)} ${asset.uom}'.trim(),
      _materialStateStatusLabel(asset.status),
    ].join(' • ');
    final assignedGreen = theme.brightness == Brightness.dark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    final assignedColor = orderAssignment?.isFrozen == true
        ? (theme.brightness == Brightness.dark
            ? const Color(0xFF81D4FA)
            : const Color(0xFF0288D1))
        : assignedGreen;
    final backgroundColor = assigned
        ? Color.alphaBlend(
            assignedColor.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.20 : 0.12,
            ),
            scheme.surfaceContainerLowest,
          )
        : scheme.surfaceContainerLowest;
    return AdminSummaryCard(
      key: ValueKey('material-state-asset-card-${asset.assetRef}'),
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      onLongPress: onLongPress,
      backgroundColor: backgroundColor,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      value: '',
      showChevron: false,
      leading: SizedBox.square(
        key: selected
            ? ValueKey('material-state-asset-selected-${asset.assetRef}')
            : null,
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: assigned
                ? assignedColor.withValues(alpha: 0.18)
                : scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            selected ? Icons.check_rounded : Icons.category_outlined,
            size: 16,
            color: assigned ? assignedColor : scheme.onSecondaryContainer,
          ),
        ),
      ),
      trailing:
          busy ? const AppLoadingIndicator(size: 30, glyphSize: 18) : null,
      title: title,
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      subtitleStyle: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      elevation: 1,
    );
  }
}

class _MaterialStateAssetSheet extends StatelessWidget {
  const _MaterialStateAssetSheet({
    required this.asset,
    required this.busy,
    required this.canReturn,
    required this.onReturn,
    required this.onOrderAssignmentChanged,
    required this.onQrRequested,
  });

  final InventoryAsset asset;
  final bool busy;
  final bool canReturn;
  final Future<void> Function()? onReturn;
  final Future<void> Function()? onOrderAssignmentChanged;
  final Future<void> Function()? onQrRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title =
        asset.itemName.trim().isEmpty ? asset.itemCode : asset.itemName;
    return Material(
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (asset.itemCode.trim().isNotEmpty &&
                          asset.itemCode.trim() != title.trim()) ...[
                        const SizedBox(height: 2),
                        Text(
                          asset.itemCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onQrRequested != null)
                  IconButton(
                    key: ValueKey(
                      'material-state-asset-qr-button-${asset.assetRef}',
                    ),
                    onPressed: () => unawaited(onQrRequested!()),
                    tooltip: 'QR kodni ko‘rish',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.qr_code_2_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _MaterialStateAssetDetail(
              icon: Icons.qr_code_rounded,
              label: 'Identifikator',
              value: asset.identifier,
            ),
            _MaterialStateAssetDetail(
              icon: Icons.scale_outlined,
              label: 'Miqdor',
              value: '${formatRawQuantity(asset.qty)} ${asset.uom}'.trim(),
            ),
            _MaterialStateAssetDetail(
              icon: Icons.location_on_outlined,
              label: 'State',
              value: asset.physicalLocation.name,
            ),
            const SizedBox(height: 10),
            RawMaterialOrderAssignmentSection(
              key: ValueKey(
                'material-state-raw-assignment-${asset.assetRef}',
              ),
              barcode: rawMaterialAssetBarcode(asset),
              allowAssignment: true,
              onAssignmentChanged: onOrderAssignmentChanged,
            ),
            const SizedBox(height: 18),
            if (busy)
              const Center(child: AppLoadingIndicator())
            else
              FilledButton.icon(
                key: const ValueKey('material-state-return-button'),
                onPressed: canReturn && onReturn != null
                    ? () => unawaited(onReturn!())
                    : null,
                icon: const Icon(Icons.keyboard_return_rounded),
                label: const Text('Omborga qaytarish'),
              ),
            if (!canReturn && !busy) ...[
              const SizedBox(height: 8),
              Text(
                'Mahsulotni qaytarish uchun uning ombor joylashuvi faol '
                'bo‘lishi kerak.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MaterialStateAssetDetail extends StatelessWidget {
  const _MaterialStateAssetDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _inventoryStateAssetKey(InventoryAsset asset) =>
    '${asset.kind.apiValue}:${asset.assetRef.trim().toLowerCase()}';

String _materialStateStatusLabel(String status) =>
    switch (status.trim().toLowerCase()) {
      'available' => 'Mavjud',
      'reserved' => 'Band',
      'in_use' => 'Ishlatilmoqda',
      'consumed' => 'Sarflangan',
      _ => status.trim().isEmpty ? 'Noma’lum' : status.trim(),
    };

void _showMaterialStateNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
