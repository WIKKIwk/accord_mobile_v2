import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart';
import '../../shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';

class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({super.key});

  @override
  State<InventoryMovementsScreen> createState() =>
      _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<InventoryLocation> _locations = const [];
  List<InventoryAsset> _assets = const [];
  List<InventoryTransfer> _allIncoming = const [];
  List<InventoryTransfer> _allOutgoing = const [];
  List<InventoryTransfer> _incoming = const [];
  List<InventoryTransfer> _outgoing = const [];
  String _selectedWarehouseId = '';
  bool _loading = true;
  bool _assetsLoading = false;
  bool _warehouseFilterExpanded = false;
  String _error = '';
  final Set<String> _busyKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<InventoryLocation> get _warehouseLocations => _locations
      .where((location) => location.isWarehouse && location.active)
      .toList(growable: false);

  List<InventoryLocation> get _stateLocations => _locations
      .where((location) => location.isState && location.active)
      .toList(growable: false);

  Set<String> get _assignedWarehouseNames =>
      (AppSession.instance.profile?.assignedWarehouses ?? const <String>[])
          .map((name) => name.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet();

  bool get _isAdmin => AppSession.instance.can('admin.access');

  bool get _materialScoped =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }
    try {
      final locations = await MobileApi.instance.inventoryLocations();
      final warehouses = locations
          .where((location) => location.isWarehouse && location.active)
          .toList(growable: false);
      var selected = _selectedWarehouseId;
      if (!warehouses.any((item) => item.warehouseId == selected)) {
        final assigned = _assignedWarehouseNames;
        final preferred = warehouses.where(
          (item) => assigned.contains(item.name.trim().toLowerCase()),
        );
        selected = preferred.isNotEmpty
            ? preferred.first.warehouseId
            : (_isAdmin && warehouses.isNotEmpty
                ? warehouses.first.warehouseId
                : '');
      }
      final results = await Future.wait([
        MobileApi.instance.inventoryTransfers(direction: 'incoming'),
        MobileApi.instance.inventoryTransfers(direction: 'outgoing'),
        if (selected.isNotEmpty)
          MobileApi.instance.inventoryAssets(
            warehouseId: selected,
            query: _searchController.text,
          )
        else
          Future.value(const <InventoryAsset>[]),
      ]);
      if (!mounted) {
        return;
      }
      final selectedWarehouse = warehouses.where(
        (item) => item.warehouseId == selected,
      );
      final selectedWarehouseName =
          selectedWarehouse.isEmpty ? '' : selectedWarehouse.first.name;
      final incoming = _filterTransfersByWarehouse(
        results[0] as List<InventoryTransfer>,
        warehouseName: selectedWarehouseName,
        incoming: true,
      );
      final outgoing = _filterTransfersByWarehouse(
        results[1] as List<InventoryTransfer>,
        warehouseName: selectedWarehouseName,
        incoming: false,
      );
      setState(() {
        _locations = locations;
        _selectedWarehouseId = selected;
        _allIncoming = results[0] as List<InventoryTransfer>;
        _allOutgoing = results[1] as List<InventoryTransfer>;
        _incoming = incoming;
        _outgoing = outgoing;
        _assets = results[2] as List<InventoryAsset>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _loadAssets() async {
    if (_selectedWarehouseId.isEmpty) {
      setState(() => _assets = const []);
      return;
    }
    setState(() => _assetsLoading = true);
    try {
      final assets = await MobileApi.instance.inventoryAssets(
        warehouseId: _selectedWarehouseId,
        query: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _assets = assets;
          _assetsLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _assetsLoading = false);
        _showMessage(_message(error));
      }
    }
  }

  void _onSearchChanged(String _) {
    _refreshTransferFilters();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadAssets);
  }

  void _refreshTransferFilters() {
    final selected = _warehouseLocations.where(
      (item) => item.warehouseId == _selectedWarehouseId,
    );
    if (selected.isEmpty || !mounted) {
      return;
    }
    final warehouseName = selected.first.name;
    setState(() {
      _incoming = _filterTransfersByWarehouse(
        _allIncoming,
        warehouseName: warehouseName,
        incoming: true,
      );
      _outgoing = _filterTransfersByWarehouse(
        _allOutgoing,
        warehouseName: warehouseName,
        incoming: false,
      );
    });
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  void _goBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    nav.pushReplacementNamed(
      _materialScoped ? AppRoutes.materialHome : AppRoutes.adminHome,
    );
  }

  Future<void> _relocate(InventoryAsset asset) async {
    final destinations = <InventoryLocation>[
      ..._stateLocations,
      ..._warehouseLocations.where(
        (location) =>
            location.warehouseId == asset.custodyWarehouseId &&
            location.id != asset.physicalLocation.id,
      ),
    ];
    final selected = await _pickLocation(
      title: 'Fizik joylashuv',
      locations: destinations,
      emptyMessage: 'Faol state topilmadi',
    );
    if (selected == null || !mounted) {
      return;
    }
    final busyKey = 'relocate:${asset.kind.apiValue}:${asset.assetRef}';
    await _runBusy(busyKey, () async {
      await MobileApi.instance.inventoryRelocate(
        assetKind: asset.kind,
        assetRef: asset.assetRef,
        physicalLocationId: selected.id,
        idempotencyKey: _idempotencyKey('relocate'),
      );
      _showMessage('${asset.itemName} — ${selected.name}');
      await _loadAll();
    });
  }

  Future<void> _requestTransfer(InventoryAsset asset) async {
    final destinations = _warehouseLocations
        .where(
          (location) =>
              location.warehouseId != asset.custodyWarehouseId &&
              location.active,
        )
        .toList(growable: false);
    final selected = await _pickLocation(
      title: 'Qabul qiluvchi ombor',
      locations: destinations,
      emptyMessage: 'Boshqa ombor topilmadi',
    );
    if (selected == null || !mounted) {
      return;
    }
    final internalTransfer = _assignedWarehouseNames.contains(
          asset.custodyWarehouse.trim().toLowerCase(),
        ) &&
        _assignedWarehouseNames.contains(selected.name.trim().toLowerCase());
    final transferExplanation = internalTransfer
        ? 'Ikkala ombor ham sizga biriktirilgan. Mahsulot darhol '
            'qabul qiluvchi omborga ko‘chiriladi.'
        : 'Qabul qiluvchi tasdiqlamaguncha mahsulot manba omborda '
            'band holatda qoladi.';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              internalTransfer ? 'Ichki ko‘chirish' : 'Transfer so‘rovi',
            ),
            content: Text(
              '${asset.itemName} (${_qty(asset.qty)} ${asset.uom})\n'
              '${asset.custodyWarehouse} → ${selected.name}\n\n'
              '$transferExplanation',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Bekor qilish'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  internalTransfer ? 'Ko‘chirish' : 'So‘rov yuborish',
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final busyKey = 'transfer:${asset.kind.apiValue}:${asset.assetRef}';
    await _runBusy(busyKey, () async {
      final transfer = await MobileApi.instance.inventoryCreateTransfer(
        sourceWarehouseId: asset.custodyWarehouseId,
        destinationWarehouseId: selected.warehouseId,
        assets: [asset],
        idempotencyKey: _idempotencyKey('transfer'),
      );
      _showMessage(
        transfer.status == InventoryTransferStatus.received
            ? '${asset.itemName} — ${selected.name} omboriga ko‘chirildi'
            : 'Transfer so‘rovi yuborildi',
      );
      await _loadAll();
    });
  }

  Future<void> _showAssetDetails(InventoryAsset asset) async {
    final key = '${asset.kind.apiValue}:${asset.assetRef}';
    final busy = _busyKeys.any((item) => item.contains(key));
    final physicallyInWarehouse =
        asset.physicalLocation.kind == InventoryLocationKind.warehouse;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => _InventoryAssetDetailsSheet(
        asset: asset,
        busy: busy,
        transferRequiresWarehouseLocation: !physicallyInWarehouse,
        onRelocate: asset.isAvailable && !busy
            ? () async {
                Navigator.of(sheetContext).pop();
                await _relocate(asset);
              }
            : null,
        onTransfer: asset.isAvailable && physicallyInWarehouse && !busy
            ? () async {
                Navigator.of(sheetContext).pop();
                await _requestTransfer(asset);
              }
            : null,
      ),
    );
  }

  Future<void> _transferAction(
    InventoryTransfer transfer,
    String action,
  ) async {
    final completesInternalTransfer = _managesTransferInternally(transfer) &&
        ((action == 'approve' &&
                transfer.status == InventoryTransferStatus.requested) ||
            (action == 'dispatch' &&
                transfer.status == InventoryTransferStatus.approved));
    final labels = {
      'approve': 'Transferni tasdiqlaysizmi?',
      'reject': 'Transferni rad qilasizmi?',
      'dispatch': 'Mahsulot jo‘natildimi?',
      'receive': 'Mahsulot to‘liq qabul qilindimi?',
      'cancel': 'Transfer bekor qilinsinmi?',
    };
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              completesInternalTransfer
                  ? 'Ichki ko‘chirishni yakunlaysizmi?'
                  : labels[action] ?? 'Transfer',
            ),
            content: Text(
              '${transfer.sourceWarehouse} → '
              '${transfer.destinationWarehouse}\n'
              '${transfer.lines.length} ta pozitsiya',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Yo‘q'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ha'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _runBusy('${transfer.id}:$action', () async {
      await MobileApi.instance.inventoryTransferAction(
        transferId: transfer.id,
        action: action,
        idempotencyKey: _idempotencyKey(action),
      );
      await _loadAll();
    });
  }

  Future<InventoryLocation?> _pickLocation({
    required String title,
    required List<InventoryLocation> locations,
    required String emptyMessage,
  }) {
    return showModalBottomSheet<InventoryLocation>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.76,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: locations.isEmpty
                    ? Center(child: Text(emptyMessage))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        itemCount: locations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final location = locations[index];
                          final apparatus = location.apparatus
                              .map((item) => item.name)
                              .join(', ');
                          return ListTile(
                            key: ValueKey('inventory-location-${location.id}'),
                            leading: Icon(
                              location.isState
                                  ? Icons.location_on_outlined
                                  : Icons.warehouse_outlined,
                            ),
                            title: Text(location.name),
                            subtitle:
                                apparatus.isEmpty ? null : Text(apparatus),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.pop(context, location),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runBusy(String key, Future<void> Function() action) async {
    if (_busyKeys.contains(key)) {
      return;
    }
    setState(() => _busyKeys.add(key));
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _showMessage(_message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _busyKeys.remove(key));
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppShell(
        animateOnEnter: false,
        title: '',
        subtitle: '',
        nativeTopBar: true,
        automaticallyImplyNativeLeading: false,
        profileActionListenable: _searchFocusNode,
        showProfileActionResolver: () => !_searchFocusNode.hasFocus,
        titleWidget: AdminCatalogSearchField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          hintText: 'Mahsulot, kod yoki QR qidirish',
          onChanged: _onSearchChanged,
          onClear: () {
            _searchController.clear();
            _onSearchChanged('');
          },
          onBack: _goBack,
        ),
        drawer: _materialScoped
            ? MaterialTaminotchiNavigationDrawer(
                selectedRouteName: AppRoutes.inventoryMovements,
                onNavigate: _openDrawerRoute,
              )
            : null,
        bottom: _materialScoped
            ? const MaterialTaminotchiDock(
                activeTab: MaterialTaminotchiDockTab.home,
              )
            : null,
        contentPadding: EdgeInsets.zero,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Mahsulotlar'),
                Tab(text: 'Kiruvchi'),
                Tab(text: 'Chiquvchi'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: AppLoadingIndicator())
                  : _error.isNotEmpty
                      ? _InventoryErrorState(
                          message: _error,
                          onRetry: _loadAll,
                        )
                      : TabBarView(
                          children: [
                            _buildAssetsTab(),
                            _TransferList(
                              transfers: _incoming,
                              emptyMessage: 'Kiruvchi transfer yo‘q',
                              header: _warehouseFilter(),
                              busyKeys: _busyKeys,
                              actionsFor: (_) => const [],
                              onTransferTap: _showTransferDetails,
                              onRefresh: _loadAll,
                            ),
                            _TransferList(
                              transfers: _outgoing,
                              emptyMessage: 'Chiquvchi transfer yo‘q',
                              header: _warehouseFilter(),
                              busyKeys: _busyKeys,
                              actionsFor: (_) => const [],
                              onTransferTap: _showTransferDetails,
                              onRefresh: _loadAll,
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetsTab() {
    if (_warehouseLocations.isEmpty) {
      return const _InventoryEmptyState(
        icon: Icons.warehouse_outlined,
        message: 'Sizga biriktirilgan ombor topilmadi',
      );
    }
    final bottomPadding =
        MediaQuery.viewPaddingOf(context).bottom + (_materialScoped ? 116 : 28);
    return AppRefreshIndicator(
      onRefresh: _loadAll,
      allowRefreshOnShortContent: true,
      child: CustomScrollView(
        physics: const TopRefreshScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _warehouseFilter(),
          ),
          if (_assetsLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: AppLoadingIndicator()),
            )
          else if (_assets.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _InventoryEmptyState(
                icon: Icons.inventory_2_outlined,
                message: 'Omborda harakatlantiriladigan mahsulot yo‘q',
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, bottomPadding),
              sliver: SliverList.builder(
                itemCount: _assets.length,
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final key = '${asset.kind.apiValue}:${asset.assetRef}';
                  final busy = _busyKeys.any((item) => item.contains(key));
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
                    ),
                    child: _InventoryAssetListRow(
                      key: ValueKey('inventory-asset-${asset.assetRef}'),
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index,
                        _assets.length,
                      ),
                      asset: asset,
                      busy: busy,
                      onTap: () => _showAssetDetails(asset),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<InventoryLocation> _visibleWarehouseLocations() {
    if (_isAdmin) {
      return _warehouseLocations;
    }
    final assigned = _assignedWarehouseNames;
    return _warehouseLocations
        .where((location) => assigned.contains(location.name.toLowerCase()))
        .toList(growable: false);
  }

  Widget _warehouseFilter() {
    final selected = _selectedWarehouseId.trim();
    return AdminExpandableFilterChip<String>(
      key: const ValueKey('inventory-warehouse-filter'),
      chipKey: const ValueKey('inventory-warehouse-filter-chip'),
      label: 'Ombor',
      emptyLabel: 'Tanlanmagan',
      icon: Icons.warehouse_outlined,
      selectedValue: selected.isEmpty ? null : selected,
      expanded: _warehouseFilterExpanded,
      onToggle: () {
        setState(() {
          _warehouseFilterExpanded = !_warehouseFilterExpanded;
        });
      },
      onSelect: _selectWarehouse,
      optionKeyPrefix: 'inventory-warehouse-option-chip',
      options: [
        for (final location in _visibleWarehouseLocations())
          AdminFilterChipOption<String>(
            value: location.warehouseId,
            label: location.name,
            key: ValueKey('inventory-warehouse-option-${location.warehouseId}'),
          ),
      ],
    );
  }

  void _selectWarehouse(String warehouseId) {
    final selected = warehouseId.trim();
    final location = _warehouseLocations.where(
      (item) => item.warehouseId == selected,
    );
    if (selected.isEmpty || location.isEmpty) {
      return;
    }
    final warehouseName = location.first.name;
    setState(() {
      _selectedWarehouseId = selected;
      _warehouseFilterExpanded = false;
      _incoming = _filterTransfersByWarehouse(
        _allIncoming,
        warehouseName: warehouseName,
        incoming: true,
      );
      _outgoing = _filterTransfersByWarehouse(
        _allOutgoing,
        warehouseName: warehouseName,
        incoming: false,
      );
    });
    unawaited(_loadAssets());
  }

  List<InventoryTransfer> _filterTransfersByWarehouse(
    List<InventoryTransfer> transfers, {
    required String warehouseName,
    required bool incoming,
  }) {
    final normalizedWarehouse = warehouseName.trim().toLowerCase();
    final query = _searchController.text.trim().toLowerCase();
    return transfers.where(
      (transfer) {
        final matchesWarehouse = (incoming
                    ? transfer.destinationWarehouse
                    : transfer.sourceWarehouse)
                .trim()
                .toLowerCase() ==
            normalizedWarehouse;
        if (!matchesWarehouse || query.isEmpty) {
          return matchesWarehouse;
        }
        return [
          transfer.sourceWarehouse,
          transfer.destinationWarehouse,
          transfer.note,
          for (final line in transfer.lines) ...[
            line.itemName,
            line.itemCode,
            line.identifier,
            line.assetRef,
          ],
        ].any((value) => value.toLowerCase().contains(query));
      },
    ).toList(growable: false);
  }

  bool _managesTransferInternally(InventoryTransfer transfer) {
    final assigned = _assignedWarehouseNames;
    return assigned.contains(transfer.sourceWarehouse.trim().toLowerCase()) &&
        assigned.contains(
          transfer.destinationWarehouse.trim().toLowerCase(),
        );
  }

  String _transferActionLabel(InventoryTransfer transfer, String action) {
    if (_managesTransferInternally(transfer) &&
        (action == 'approve' || action == 'dispatch')) {
      return 'Ko‘chirishni yakunlash';
    }
    return _actionLabel(action);
  }

  Future<void> _showTransferDetails(
    InventoryTransfer transfer,
    List<String> actions,
  ) async {
    final busy = _busyKeys.any((key) => key.startsWith(transfer.id));
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => _InventoryTransferDetailsSheet(
        transfer: transfer,
        actions: actions,
        busy: busy,
        actionLabelFor: (action) => _transferActionLabel(transfer, action),
        onAction: (action) async {
          Navigator.of(sheetContext).pop();
          await _transferAction(transfer, action);
        },
      ),
    );
  }
}

class _InventoryAssetListRow extends StatelessWidget {
  const _InventoryAssetListRow({
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
      '${_qty(asset.qty)} ${asset.uom}',
      _statusLabel(asset.status),
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
            _assetIcon(asset.kind),
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
            height: 1.05,
          ),
      elevation: 1,
    );
  }
}

class _InventoryAssetDetailsSheet extends StatelessWidget {
  const _InventoryAssetDetailsSheet({
    required this.asset,
    required this.busy,
    required this.transferRequiresWarehouseLocation,
    required this.onRelocate,
    required this.onTransfer,
  });

  final InventoryAsset asset;
  final bool busy;
  final bool transferRequiresWarehouseLocation;
  final Future<void> Function()? onRelocate;
  final Future<void> Function()? onTransfer;

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
                SizedBox.square(
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _assetIcon(asset.kind),
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                _StatusBadge(status: asset.status),
              ],
            ),
            const SizedBox(height: 18),
            _AssetSheetDetail(
              icon: Icons.qr_code_rounded,
              label: 'Identifikator',
              value: asset.identifier,
            ),
            _AssetSheetDetail(
              icon: Icons.scale_outlined,
              label: 'Miqdor',
              value: '${_qty(asset.qty)} ${asset.uom}',
            ),
            _AssetSheetDetail(
              icon: Icons.location_on_outlined,
              label: 'Fizik joy',
              value: asset.physicalLocation.name,
            ),
            if (transferRequiresWarehouseLocation) ...[
              const SizedBox(height: 8),
              Text(
                'Transfer qilishdan oldin mahsulotni omborga qaytaring.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (busy)
              const Center(child: AppLoadingIndicator())
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRelocate == null
                          ? null
                          : () => unawaited(onRelocate!()),
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Text('Joylashtirish'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onTransfer == null
                          ? null
                          : () => unawaited(onTransfer!()),
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Transfer'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AssetSheetDetail extends StatelessWidget {
  const _AssetSheetDetail({
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

class _TransferList extends StatelessWidget {
  const _TransferList({
    required this.transfers,
    required this.emptyMessage,
    required this.header,
    required this.busyKeys,
    required this.actionsFor,
    required this.onTransferTap,
    required this.onRefresh,
  });

  final List<InventoryTransfer> transfers;
  final String emptyMessage;
  final Widget header;
  final Set<String> busyKeys;
  final List<String> Function(InventoryTransfer) actionsFor;
  final Future<void> Function(InventoryTransfer, List<String>) onTransferTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      allowRefreshOnShortContent: true,
      child: transfers.isEmpty
          ? ListView(
              physics: const TopRefreshScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 116),
              children: [
                header,
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55,
                  child: _InventoryEmptyState(
                    icon: Icons.swap_horiz_rounded,
                    message: emptyMessage,
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const TopRefreshScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 116),
              itemCount: transfers.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return header;
                }
                final transfer = transfers[index - 1];
                final actions = actionsFor(transfer);
                return _InventoryTransferListRow(
                  key: ValueKey('inventory-transfer-${transfer.id}'),
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index - 1,
                    transfers.length,
                  ),
                  transfer: transfer,
                  busy: busyKeys.any((key) => key.startsWith(transfer.id)),
                  onTap: () => unawaited(onTransferTap(transfer, actions)),
                );
              },
            ),
    );
  }
}

class _InventoryTransferListRow extends StatelessWidget {
  const _InventoryTransferListRow({
    super.key,
    required this.slot,
    required this.transfer,
    required this.busy,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final InventoryTransfer transfer;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            Icons.swap_horiz_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      trailing: busy
          ? const AppLoadingIndicator(size: 30, glyphSize: 18)
          : _StatusBadge(status: transfer.status.apiValue),
      title: '${transfer.sourceWarehouse} → ${transfer.destinationWarehouse}',
      subtitle: _transferSummary(transfer),
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
      elevation: 1,
    );
  }
}

class _InventoryTransferDetailsSheet extends StatelessWidget {
  const _InventoryTransferDetailsSheet({
    required this.transfer,
    required this.actions,
    required this.busy,
    required this.actionLabelFor,
    required this.onAction,
  });

  final InventoryTransfer transfer;
  final List<String> actions;
  final bool busy;
  final String Function(String) actionLabelFor;
  final Future<void> Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
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
                SizedBox.square(
                  dimension: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.swap_horiz_rounded,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${transfer.sourceWarehouse} → '
                    '${transfer.destinationWarehouse}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusBadge(status: transfer.status.apiValue),
              ],
            ),
            const SizedBox(height: 18),
            for (final line in transfer.lines)
              _AssetSheetDetail(
                icon: Icons.category_outlined,
                label: line.itemName.trim().isEmpty
                    ? line.itemCode
                    : line.itemName,
                value: '${_qty(line.qty)} ${line.uom}',
              ),
            if (transfer.lines.isEmpty)
              const _AssetSheetDetail(
                icon: Icons.category_outlined,
                label: 'Mahsulot',
                value: '—',
              ),
            _AssetSheetDetail(
              icon: Icons.schedule_rounded,
              label: 'Sana',
              value: _transferTimestamp(transfer),
            ),
            if (transfer.note.trim().isNotEmpty)
              _AssetSheetDetail(
                icon: Icons.notes_rounded,
                label: 'Izoh',
                value: transfer.note,
              ),
            const SizedBox(height: 18),
            if (busy)
              const Center(child: AppLoadingIndicator())
            else if (actions.isNotEmpty)
              Row(
                children: [
                  for (int index = 0; index < actions.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    Expanded(
                      child: actions[index] == 'reject' ||
                              actions[index] == 'cancel'
                          ? OutlinedButton(
                              onPressed: () => unawaited(
                                onAction(actions[index]),
                              ),
                              child: Text(actionLabelFor(actions[index])),
                            )
                          : FilledButton(
                              onPressed: () => unawaited(
                                onAction(actions[index]),
                              ),
                              child: Text(actionLabelFor(actions[index])),
                            ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final scheme = Theme.of(context).colorScheme;
    final color = switch (normalized) {
      'available' || 'received' => scheme.primaryContainer,
      'rejected' || 'cancelled' => scheme.errorContainer,
      _ => scheme.tertiaryContainer,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(normalized),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _InventoryEmptyState extends StatelessWidget {
  const _InventoryEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InventoryErrorState extends StatelessWidget {
  const _InventoryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _assetIcon(InventoryAssetKind kind) => switch (kind) {
      InventoryAssetKind.rawMaterial => Icons.category_outlined,
      InventoryAssetKind.finishedGoods => Icons.inventory_2_outlined,
      InventoryAssetKind.qolip => Icons.view_in_ar_outlined,
    };

String _statusLabel(String status) => switch (status) {
      'available' => 'Mavjud',
      'requested' => 'So‘ralgan',
      'approved' => 'Tasdiqlangan',
      'in_transit' => 'Yo‘lda',
      'received' => 'Qabul qilingan',
      'rejected' => 'Rad etilgan',
      'cancelled' => 'Bekor qilingan',
      'reserved' || 'transfer_reserved' => 'Band',
      _ => status.isEmpty ? '—' : status,
    };

String _actionLabel(String action) => switch (action) {
      'approve' => 'Tasdiqlash',
      'reject' => 'Rad etish',
      'dispatch' => 'Jo‘natish',
      'receive' => 'Qabul qilish',
      'cancel' => 'Bekor qilish',
      _ => action,
    };

String _transferTimestamp(InventoryTransfer transfer) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    transfer.createdAtUnix * 1000,
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _transferSummary(InventoryTransfer transfer) {
  if (transfer.lines.isEmpty) {
    return _transferTimestamp(transfer);
  }
  final line = transfer.lines.first;
  final item = line.itemName.trim().isEmpty ? line.itemCode : line.itemName;
  final extra =
      transfer.lines.length > 1 ? ' +${transfer.lines.length - 1} ta' : '';
  return '$item$extra • ${_qty(line.qty)} ${line.uom} • '
      '${_transferTimestamp(transfer)}';
}

String _qty(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}

String _idempotencyKey(String action) {
  return 'mobile:$action:${DateTime.now().microsecondsSinceEpoch}';
}

String _message(Object error) {
  if (error is MobileApiException) {
    return error.message;
  }
  return 'Amal bajarilmadi. Qayta urinib ko‘ring.';
}
