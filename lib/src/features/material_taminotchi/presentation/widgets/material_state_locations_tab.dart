import 'dart:async';

import '../../../../core/api/mobile_api.dart';
import '../../../../core/formatters/quantity_formatters.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../../core/widgets/shell/app_retry_state.dart';
import '../../../../core/widgets/shell/app_shell.dart';
import '../../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../../admin/presentation/widgets/admin_summary_card.dart';
import '../../../shared/models/inventory_movement_models.dart';
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
    required this.onAssetReturned,
  });

  final double bottomPadding;
  final Future<void> Function() onAssetReturned;

  @override
  State<MaterialStateLocationsTab> createState() =>
      MaterialStateLocationsTabState();
}

class MaterialStateLocationsTabState extends State<MaterialStateLocationsTab> {
  late Future<_MaterialStateLocationsData> _future;
  Timer? _searchDebounce;
  String _query = '';
  String _selectedStateId = '';
  String _busyAssetKey = '';
  bool _filterExpanded = false;

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
    final future = _load();
    if (mounted) {
      setState(() {
        _future = future;
      });
    }
    await future;
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
    InventoryLocation? returnLocation;
    for (final location in locations) {
      if (location.isWarehouse &&
          location.warehouseId == asset.custodyWarehouseId) {
        returnLocation = location;
        break;
      }
    }
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
        onReturn: returnLocation == null
            ? null
            : () async {
                Navigator.of(sheetContext).pop();
                await _returnToWarehouse(asset, returnLocation!);
              },
      ),
    );
  }

  Future<void> _returnToWarehouse(
    InventoryAsset asset,
    InventoryLocation warehouseLocation,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Omborga qaytarish'),
            content: Text(
              '${asset.itemName.trim().isEmpty ? asset.itemCode : asset.itemName} '
              '${warehouseLocation.name} omboriga qaytarilsinmi?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Yo‘q'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Ha'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final assetKey = _inventoryStateAssetKey(asset);
    setState(() => _busyAssetKey = assetKey);
    try {
      await MobileApi.instance.inventoryRelocate(
        assetKind: asset.kind,
        assetRef: asset.assetRef,
        physicalLocationId: warehouseLocation.id,
        idempotencyKey: 'state-return-${DateTime.now().microsecondsSinceEpoch}',
        note: 'State’dan omborga qaytarildi',
      );
      await widget.onAssetReturned();
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
        final data = snapshot.data ??
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
          return [
            asset.itemName,
            asset.itemCode,
            asset.identifier,
            asset.assetRef,
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
                        _MaterialStateAssetRow(
                          key: ValueKey(
                            'material-state-asset-'
                            '${visibleAssets[index].assetRef}',
                          ),
                          slot: M3SegmentedListGeometry
                              .standaloneListSlotForIndex(
                            index,
                            visibleAssets.length,
                          ),
                          asset: visibleAssets[index],
                          busy: _busyAssetKey ==
                              _inventoryStateAssetKey(visibleAssets[index]),
                          onTap: () => _showAssetDetails(
                            visibleAssets[index],
                            data.locations,
                          ),
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
    required this.busy,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final InventoryAsset asset;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        asset.itemName.trim().isEmpty ? asset.itemCode : asset.itemName;
    final subtitle = [
      if (asset.identifier.trim().isNotEmpty) asset.identifier.trim(),
      '${formatRawQuantity(asset.qty)} ${asset.uom}'.trim(),
    ].join(' • ');
    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      onTap: onTap,
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      value: '',
      showChevron: false,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.category_outlined,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      trailing:
          busy ? const AppLoadingIndicator(size: 30, glyphSize: 18) : null,
      title: title,
      subtitle: subtitle,
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
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
  });

  final InventoryAsset asset;
  final bool busy;
  final bool canReturn;
  final Future<void> Function()? onReturn;

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

void _showMaterialStateNotice(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
  );
}
