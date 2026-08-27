import 'dart:async';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session.dart';
import '../../../core/widgets/feedback/m3_confirm_dialog.dart';
import '../../../core/widgets/lists/m3_animated_list_entry.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../admin/models/production_map_models.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../admin/presentation/widgets/admin_summary_card.dart';
import '../../material_taminotchi/presentation/widgets/material_state_locations_tab.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../material_taminotchi/presentation/widgets/raw_material_list_assignment.dart';
import '../../material_taminotchi/presentation/widgets/raw_material_order_assignment_section.dart';
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
  Map<String, RawMaterialListAssignment> _rawMaterialOrderAssignments =
      const {};
  String _selectedWarehouseId = '';
  bool _loading = true;
  bool _assetsLoading = false;
  bool _warehouseFilterExpanded = false;
  String _error = '';
  final Set<String> _busyKeys = {};
  final Set<String> _selectedAssetKeys = {};
  final Set<String> _exitingAssetKeys = {};
  final Set<String> _enteringAssetKeys = {};
  final Set<String> _enteringTransferIds = {};
  int _selectedStateAssetCount = 0;
  final GlobalKey<MaterialStateLocationsTabState> _materialStateLocationsKey =
      GlobalKey<MaterialStateLocationsTabState>();

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

  bool get _stateSelectionMode => _selectedStateAssetCount > 0;

  bool get _selectionMode =>
      _selectedAssetKeys.isNotEmpty || _stateSelectionMode;

  int get _selectionCount => _stateSelectionMode
      ? _selectedStateAssetCount
      : _selectedAssetKeys.length;

  String _selectionKey(InventoryAsset asset) =>
      '${asset.kind.apiValue}:${asset.assetRef.toLowerCase()}';

  bool _canBulkRelocate(InventoryAsset asset) =>
      asset.isAvailable &&
      asset.physicalLocation.kind == InventoryLocationKind.warehouse &&
      asset.custodyWarehouseId == _selectedWarehouseId;

  List<InventoryAsset> get _selectedAssets => _assets
      .where((asset) => _selectedAssetKeys.contains(_selectionKey(asset)))
      .toList(growable: false);

  List<InventoryAsset> get _selectedLinkedRawMaterialAssets => _selectedAssets
      .where(
        (asset) =>
            asset.kind == InventoryAssetKind.rawMaterial &&
            _rawMaterialOrderAssignments.containsKey(
              rawMaterialAssetBarcode(asset),
            ),
      )
      .toList(growable: false);

  bool get _selectionActionBusy =>
      _busyKeys.contains('relocate-batch') ||
      _busyKeys.contains('unlink-raw-material-batch');

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
      final results = await Future.wait<Object>([
        MobileApi.instance.inventoryTransfers(direction: 'incoming'),
        MobileApi.instance.inventoryTransfers(direction: 'outgoing'),
        if (selected.isNotEmpty)
          MobileApi.instance.inventoryAssets(
            warehouseId: selected,
            query: _searchController.text,
          )
        else
          Future.value(const <InventoryAsset>[]),
        if (_materialScoped)
          _loadRawMaterialOrderAssignments()
        else
          Future.value(const <String, RawMaterialListAssignment>{}),
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
        final visibleKeys = _assets.map(_selectionKey).toSet();
        _selectedAssetKeys.removeWhere((key) => !visibleKeys.contains(key));
        _rawMaterialOrderAssignments =
            results[3] as Map<String, RawMaterialListAssignment>;
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
      final results = await Future.wait<Object>([
        MobileApi.instance.inventoryAssets(
          warehouseId: _selectedWarehouseId,
          query: _searchController.text,
        ),
        if (_materialScoped)
          _loadRawMaterialOrderAssignments()
        else
          Future.value(const <String, RawMaterialListAssignment>{}),
      ]);
      if (mounted) {
        setState(() {
          _assets = results[0] as List<InventoryAsset>;
          final visibleKeys = _assets.map(_selectionKey).toSet();
          _selectedAssetKeys.removeWhere((key) => !visibleKeys.contains(key));
          _rawMaterialOrderAssignments =
              results[1] as Map<String, RawMaterialListAssignment>;
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

  Future<Map<String, RawMaterialListAssignment>>
      _loadRawMaterialOrderAssignments() async {
    final results = await Future.wait<Object>([
      MobileApi.instance.adminRawMaterialAssignments(),
      MobileApi.instance.adminRawMaterialAssignmentOrders(),
      MobileApi.instance.adminProductionMapQueueSnapshot(),
    ]);
    return rawMaterialListAssignmentsByBarcode(
      assignments: results[0] as List<AdminRawMaterialAssignment>,
      orders: results[1] as List<ProductionMapSaved>,
      orderControlsByOrderId:
          (results[2] as AdminApparatusQueueSnapshot).orderControls,
    );
  }

  bool _assetMatchesSearch(InventoryAsset asset) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return [
      asset.itemCode,
      asset.itemName,
      asset.identifier,
      asset.assetRef,
    ].any((value) => value.toLowerCase().contains(query));
  }

  bool _assetBelongsToSelectedWarehouse(InventoryAsset asset) {
    if (asset.status.trim().toLowerCase() == 'deleted' ||
        asset.physicalLocation.kind != InventoryLocationKind.warehouse ||
        !_assetMatchesSearch(asset)) {
      return false;
    }
    return _warehouseLocations.any(
      (location) =>
          location.warehouseId == _selectedWarehouseId &&
          location.id == asset.physicalLocation.id,
    );
  }

  Future<void> _applyWarehouseAssetMutations(
    List<InventoryAsset> mutations,
  ) async {
    final unique = <String, InventoryAsset>{
      for (final asset in mutations) _selectionKey(asset): asset,
    };
    if (unique.isEmpty || !mounted) {
      return;
    }
    final currentKeys = _assets.map(_selectionKey).toSet();
    final exitingKeys = unique.entries
        .where(
          (entry) =>
              currentKeys.contains(entry.key) &&
              !_assetBelongsToSelectedWarehouse(entry.value),
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
      final next = List<InventoryAsset>.of(_assets);
      for (final entry in unique.entries) {
        final index = next.indexWhere(
          (asset) => _selectionKey(asset) == entry.key,
        );
        if (!_assetBelongsToSelectedWarehouse(entry.value)) {
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
      _assets = List<InventoryAsset>.unmodifiable(next);
      _exitingAssetKeys.removeAll(unique.keys);
      _enteringAssetKeys.addAll(enteringKeys);
      final visibleKeys = _assets.map(_selectionKey).toSet();
      _selectedAssetKeys.removeWhere((key) => !visibleKeys.contains(key));
    });
    if (enteringKeys.isNotEmpty) {
      unawaited(
        Future<void>.delayed(m3ListMutationAnimationDuration).then((_) {
          _enteringAssetKeys.removeAll(enteringKeys);
        }),
      );
    }
  }

  Future<void> _applyAssetMutations(List<InventoryAsset> mutations) async {
    final stateTab = _materialStateLocationsKey.currentState;
    await Future.wait<void>([
      _applyWarehouseAssetMutations(mutations),
      if (stateTab != null) stateTab.applyAssetMutations(mutations),
    ]);
  }

  Future<void> _reloadOrderAssignments() async {
    try {
      final assignments = await _loadRawMaterialOrderAssignments();
      if (mounted) {
        setState(() => _rawMaterialOrderAssignments = assignments);
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_message(error));
      }
    }
  }

  InventoryLocation? _warehouseLocationFor(String warehouseId) {
    for (final location in _warehouseLocations) {
      if (location.warehouseId == warehouseId) {
        return location;
      }
    }
    return null;
  }

  void _upsertTransfer(InventoryTransfer transfer) {
    final assignedWarehouses = _assignedWarehouseNames;
    final wasKnown = _allIncoming.any((item) => item.id == transfer.id) ||
        _allOutgoing.any((item) => item.id == transfer.id);

    List<InventoryTransfer> reconcile(
      List<InventoryTransfer> current, {
      required bool belongs,
    }) {
      final next = List<InventoryTransfer>.of(current);
      final index = next.indexWhere((item) => item.id == transfer.id);
      if (!belongs) {
        if (index >= 0) {
          next.removeAt(index);
        }
      } else if (index >= 0) {
        next[index] = transfer;
      } else {
        next.insert(0, transfer);
      }
      return List<InventoryTransfer>.unmodifiable(next);
    }

    final incoming = reconcile(
      _allIncoming,
      belongs: _isAdmin ||
          assignedWarehouses
              .contains(transfer.destinationWarehouse.trim().toLowerCase()),
    );
    final outgoing = reconcile(
      _allOutgoing,
      belongs: _isAdmin ||
          assignedWarehouses
              .contains(transfer.sourceWarehouse.trim().toLowerCase()),
    );
    final selected = _warehouseLocationFor(_selectedWarehouseId);
    setState(() {
      _allIncoming = incoming;
      _allOutgoing = outgoing;
      _incoming = selected == null
          ? const []
          : _filterTransfersByWarehouse(
              incoming,
              warehouseName: selected.name,
              incoming: true,
            );
      _outgoing = selected == null
          ? const []
          : _filterTransfersByWarehouse(
              outgoing,
              warehouseName: selected.name,
              incoming: false,
            );
      if (!wasKnown) {
        _enteringTransferIds.add(transfer.id);
      }
    });
    if (!wasKnown) {
      unawaited(
        Future<void>.delayed(m3ListMutationAnimationDuration).then((_) {
          _enteringTransferIds.remove(transfer.id);
        }),
      );
    }
  }

  List<InventoryAsset> _assetMutationsForTransfer(
    InventoryTransfer transfer,
  ) {
    final terminal = transfer.status == InventoryTransferStatus.received ||
        transfer.status == InventoryTransferStatus.rejected ||
        transfer.status == InventoryTransferStatus.cancelled;
    final received = transfer.status == InventoryTransferStatus.received;
    final sourceLocation = _warehouseLocationFor(transfer.sourceWarehouseId);
    final destinationLocation =
        _warehouseLocationFor(transfer.destinationWarehouseId);
    final mutations = <InventoryAsset>[];
    for (final line in transfer.lines) {
      final key = '${line.assetKind.apiValue}:${line.assetRef.toLowerCase()}';
      InventoryAsset? current;
      for (final asset in _assets) {
        if (_selectionKey(asset) == key) {
          current = asset;
          break;
        }
      }
      InventoryLocationReference? physicalLocation;
      if (received && destinationLocation != null) {
        physicalLocation = InventoryLocationReference(
          id: destinationLocation.id,
          kind: destinationLocation.kind,
          name: destinationLocation.name,
        );
      } else if (!received &&
          current?.physicalLocation.kind == InventoryLocationKind.warehouse) {
        physicalLocation = current!.physicalLocation;
      } else if (!received && sourceLocation != null) {
        physicalLocation = InventoryLocationReference(
          id: sourceLocation.id,
          kind: sourceLocation.kind,
          name: sourceLocation.name,
        );
      }
      if (physicalLocation == null) {
        continue;
      }
      final status = switch (transfer.status) {
        InventoryTransferStatus.inTransit => 'in_transit',
        InventoryTransferStatus.received ||
        InventoryTransferStatus.rejected ||
        InventoryTransferStatus.cancelled =>
          'available',
        _ => 'transfer_reserved',
      };
      mutations.add(
        InventoryAsset(
          kind: line.assetKind,
          assetRef: line.assetRef,
          custodyWarehouseId: received
              ? transfer.destinationWarehouseId
              : transfer.sourceWarehouseId,
          custodyWarehouse: received
              ? transfer.destinationWarehouse
              : transfer.sourceWarehouse,
          itemCode: current?.itemCode ?? line.itemCode,
          itemName: current?.itemName ?? line.itemName,
          identifier: current?.identifier ?? line.identifier,
          qty: current?.qty ?? line.qty,
          uom: current?.uom ?? line.uom,
          status: status,
          physicalLocation: physicalLocation,
          transferId: terminal ? '' : transfer.id,
          placementVersion:
              (current?.placementVersion ?? 1) + (received ? 1 : 0),
        ),
      );
    }
    return mutations;
  }

  void _onSearchChanged(String _) {
    _refreshTransferFilters();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadAssets);
  }

  void _toggleAssetSelection(InventoryAsset asset) {
    if (!_canBulkRelocate(asset)) {
      return;
    }
    if (_stateSelectionMode) {
      _materialStateLocationsKey.currentState?.clearSelection();
    }
    _searchFocusNode.unfocus();
    final key = _selectionKey(asset);
    setState(() {
      if (!_selectedAssetKeys.add(key)) {
        _selectedAssetKeys.remove(key);
      }
    });
  }

  void _clearAssetSelection() {
    if (_selectedAssetKeys.isEmpty) {
      return;
    }
    setState(_selectedAssetKeys.clear);
  }

  void _clearSelection() {
    if (_stateSelectionMode) {
      _materialStateLocationsKey.currentState?.clearSelection();
      return;
    }
    _clearAssetSelection();
  }

  void _handleStateSelectionChanged(int count) {
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedStateAssetCount = count;
      if (count > 0) {
        _selectedAssetKeys.clear();
      }
    });
  }

  Future<void> _runSelectionAction() async {
    if (_stateSelectionMode) {
      await _materialStateLocationsKey.currentState?.returnSelectedAssets();
      return;
    }
    await _relocateSelectedAssets();
  }

  Future<void> _unlinkSelectedRawMaterials() async {
    final assets = _selectedLinkedRawMaterialAssets;
    if (!_materialScoped || _stateSelectionMode || assets.isEmpty) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Ulangan homashyolarni uzish',
          message: '${assets.length} ta ulangan homashyo orderdan uzilsinmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Uzish',
          destructive: true,
          verticalActions: true,
          confirmButtonKey: const ValueKey(
            'inventory-selection-unlink-confirm',
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _runBusy('unlink-raw-material-batch', () async {
      var unlinkedCount = 0;
      final unlinkedBarcodes = <String>{};
      for (final asset in assets) {
        final barcode = rawMaterialAssetBarcode(asset);
        final assignment = _rawMaterialOrderAssignments[barcode];
        if (assignment == null) {
          continue;
        }
        await MobileApi.instance.adminUnlinkRawMaterialAssignment(
          orderId: assignment.orderId,
          barcode: barcode,
        );
        unlinkedCount += 1;
        unlinkedBarcodes.add(barcode);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedAssetKeys.clear();
        _rawMaterialOrderAssignments = {
          for (final entry in _rawMaterialOrderAssignments.entries)
            if (!unlinkedBarcodes.contains(entry.key)) entry.key: entry.value,
        };
      });
      _showMessage('$unlinkedCount ta homashyo orderdan uzildi');
    });
  }

  Future<void> _relocateSelectedAssets() async {
    final assets = _selectedAssets;
    if (assets.isEmpty) {
      _clearAssetSelection();
      return;
    }
    final selected = await _pickLocation(
      title: 'Qaysi State’ga ko‘chirasiz?',
      locations: _stateLocations,
      emptyMessage: 'Faol State topilmadi',
    );
    if (selected == null || !mounted) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'State’ga ko‘chirish',
          message: '${assets.length} ta mahsulot ${selected.name} State’ga '
              'ko‘chirilsinmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Ko‘chirish',
          verticalActions: true,
          confirmButtonKey: const ValueKey(
            'inventory-selection-relocate-confirm',
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _runBusy('relocate-batch', () async {
      final updatedAssets = await MobileApi.instance.inventoryRelocateBatch(
        assets: assets,
        physicalLocationId: selected.id,
        idempotencyKey: _idempotencyKey('relocate-batch'),
      );
      if (mounted) {
        setState(_selectedAssetKeys.clear);
      }
      _showMessage('${assets.length} ta mahsulot — ${selected.name}');
      await _applyAssetMutations(updatedAssets);
    });
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
      final updated = await MobileApi.instance.inventoryRelocate(
        assetKind: asset.kind,
        assetRef: asset.assetRef,
        physicalLocationId: selected.id,
        idempotencyKey: _idempotencyKey('relocate'),
      );
      _showMessage('${asset.itemName} — ${selected.name}');
      await _applyAssetMutations([updated]);
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
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: internalTransfer ? 'Ichki ko‘chirish' : 'Transfer so‘rovi',
          message: '${asset.itemName} (${_qty(asset.qty)} ${asset.uom})\n'
              '${asset.custodyWarehouse} → ${selected.name}\n\n'
              '$transferExplanation',
          cancelLabel: 'Bekor qilish',
          confirmLabel: internalTransfer ? 'Ko‘chirish' : 'So‘rov yuborish',
          verticalActions: true,
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
      _upsertTransfer(transfer);
      final updatedAsset = transfer.status == InventoryTransferStatus.received
          ? asset.copyWith(
              custodyWarehouseId: selected.warehouseId,
              custodyWarehouse: selected.name,
              status: 'available',
              physicalLocation: InventoryLocationReference(
                id: selected.id,
                kind: selected.kind,
                name: selected.name,
              ),
              transferId: '',
              placementVersion: asset.placementVersion + 1,
            )
          : asset.copyWith(
              status: 'transfer_reserved',
              transferId: transfer.id,
            );
      await _applyAssetMutations([updatedAsset]);
    });
  }

  Future<void> _deleteRawMaterial(InventoryAsset asset) async {
    final barcode = _rawMaterialAssetBarcode(asset).trim();
    if (asset.kind != InventoryAssetKind.rawMaterial || barcode.isEmpty) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Homashyoni o‘chirish',
          message: '${asset.itemName} • $barcode\n'
              '${_qty(asset.qty)} ${asset.uom}\n\n'
              'Homashyo faol ombor ro‘yxatidan o‘chadi. Audit tarixi saqlanadi.',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'O‘chirish',
          destructive: true,
          verticalActions: true,
          confirmButtonKey: ValueKey(
            'inventory-asset-delete-confirm-${asset.assetRef}',
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final busyKey = 'delete:${asset.kind.apiValue}:${asset.assetRef}';
    await _runBusy(busyKey, () async {
      await MobileApi.instance.adminDeleteRawMaterialStock(barcode: barcode);
      _showMessage('${asset.itemName} o‘chirildi');
      await _applyAssetMutations([asset.copyWith(status: 'deleted')]);
    });
  }

  Future<void> _showAssetDetails(InventoryAsset asset) async {
    final key = '${asset.kind.apiValue}:${asset.assetRef}';
    final busy = _busyKeys.any((item) => item.contains(key));
    final physicallyInWarehouse =
        asset.physicalLocation.kind == InventoryLocationKind.warehouse;
    final barcode = _rawMaterialAssetBarcode(asset).trim();
    final hasOrderAssignment =
        _rawMaterialOrderAssignments.containsKey(barcode);
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
        showOrderAssignment:
            _materialScoped && asset.kind == InventoryAssetKind.rawMaterial,
        allowOrderAssignment: _materialScoped &&
            asset.kind == InventoryAssetKind.rawMaterial &&
            asset.isAvailable &&
            physicallyInWarehouse &&
            !busy,
        onOrderAssignmentChanged: _reloadOrderAssignments,
        onQrRequested: barcode.isEmpty
            ? null
            : () async {
                await Navigator.of(sheetContext).maybePop();
                if (mounted) {
                  await _showAssetQr(asset);
                }
              },
        onDelete: _materialScoped &&
                asset.kind == InventoryAssetKind.rawMaterial &&
                asset.isAvailable &&
                physicallyInWarehouse &&
                !hasOrderAssignment &&
                barcode.isNotEmpty &&
                !busy
            ? () async {
                Navigator.of(sheetContext).pop();
                await _deleteRawMaterial(asset);
              }
            : null,
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

  Future<void> _showAssetQr(InventoryAsset asset) async {
    if (asset.kind != InventoryAssetKind.rawMaterial) {
      return;
    }
    final barcode = _rawMaterialAssetBarcode(asset).trim();
    if (barcode.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => _InventoryAssetQrSheet(
        asset: asset,
        barcode: barcode,
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
      final updated = await MobileApi.instance.inventoryTransferAction(
        transferId: transfer.id,
        action: action,
        idempotencyKey: _idempotencyKey(action),
      );
      _upsertTransfer(updated);
      await _applyAssetMutations(_assetMutationsForTransfer(updated));
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
    final selectedLinkedRawMaterials = _selectedLinkedRawMaterialAssets;
    final selectionActionBusy = _selectionActionBusy;
    final tabs = <Tab>[
      const Tab(text: 'Mahsulotlar'),
      if (_materialScoped) const Tab(text: 'State’lar'),
      const Tab(text: 'Kiruvchi'),
      const Tab(text: 'Chiquvchi'),
    ];
    final tabViews = <Widget>[
      _buildAssetsTab(),
      if (_materialScoped)
        MaterialStateLocationsTab(
          key: _materialStateLocationsKey,
          bottomPadding: MediaQuery.viewPaddingOf(context).bottom + 128,
          onAssetsChanged: _applyAssetMutations,
          orderAssignments: _rawMaterialOrderAssignments,
          onOrderAssignmentChanged: _reloadOrderAssignments,
          onSelectionChanged: _handleStateSelectionChanged,
        ),
      _TransferList(
        transfers: _incoming,
        emptyMessage: 'Kiruvchi transfer yo‘q',
        header: _warehouseFilter(),
        busyKeys: _busyKeys,
        enteringTransferIds: _enteringTransferIds,
        actionsFor: (_) => const [],
        onTransferTap: _showTransferDetails,
        onRefresh: _loadAll,
      ),
      _TransferList(
        transfers: _outgoing,
        emptyMessage: 'Chiquvchi transfer yo‘q',
        header: _warehouseFilter(),
        busyKeys: _busyKeys,
        enteringTransferIds: _enteringTransferIds,
        actionsFor: (_) => const [],
        onTransferTap: _showTransferDetails,
        onRefresh: _loadAll,
      ),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: AppShell(
        animateOnEnter: false,
        title: '',
        subtitle: '',
        nativeTopBar: true,
        automaticallyImplyNativeLeading: false,
        showProfileAction: !_selectionMode,
        profileActionListenable: _searchFocusNode,
        showProfileActionResolver: () => !_searchFocusNode.hasFocus,
        actions: _selectionMode
            ? [
                if (selectedLinkedRawMaterials.isNotEmpty)
                  IconButton(
                    key: const ValueKey('inventory-selection-unlink'),
                    tooltip: 'Ulangan homashyolarni uzish '
                        '(${selectedLinkedRawMaterials.length} ta)',
                    onPressed: selectionActionBusy
                        ? null
                        : _unlinkSelectedRawMaterials,
                    icon: _busyKeys.contains('unlink-raw-material-batch')
                        ? const AppLoadingIndicator(size: 24, glyphSize: 16)
                        : const Icon(Icons.link_off_rounded),
                  ),
                IconButton(
                  key: ValueKey(
                    _stateSelectionMode
                        ? 'material-state-selection-return'
                        : 'inventory-selection-relocate',
                  ),
                  tooltip: _stateSelectionMode
                      ? 'Omborga qaytarish'
                      : 'State’ga ko‘chirish',
                  onPressed: selectionActionBusy ? null : _runSelectionAction,
                  icon: _busyKeys.contains('relocate-batch')
                      ? const AppLoadingIndicator(size: 24, glyphSize: 16)
                      : Icon(
                          _stateSelectionMode
                              ? Icons.keyboard_return_rounded
                              : Icons.swap_horiz_rounded,
                        ),
                ),
              ]
            : null,
        titleWidget: _selectionMode
            ? Row(
                children: [
                  IconButton(
                    key: const ValueKey('inventory-selection-close'),
                    tooltip: 'Tanlashni bekor qilish',
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_selectionCount ta tanlandi',
                    key: const ValueKey('inventory-selection-count'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              )
            : AdminCatalogSearchField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                hintText: 'Mahsulot, kod yoki QR qidirish',
                onChanged: (value) {
                  _onSearchChanged(value);
                  _materialStateLocationsKey.currentState
                      ?.handleItemsSearchChanged(value);
                },
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  _materialStateLocationsKey.currentState
                      ?.handleItemsSearchChanged('');
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
            TabBar(tabs: tabs),
            Expanded(
              child: _loading
                  ? const Center(child: AppLoadingIndicator())
                  : _error.isNotEmpty
                      ? _InventoryErrorState(
                          message: _error,
                          onRetry: _loadAll,
                        )
                      : TabBarView(children: tabViews),
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
                  final orderAssignment = _rawMaterialOrderAssignments[
                      rawMaterialAssetBarcode(asset)];
                  final selected = _selectedAssetKeys.contains(
                    _selectionKey(asset),
                  );
                  final selectable = _canBulkRelocate(asset) && !busy;
                  final selectionKey = _selectionKey(asset);
                  final exiting = _exitingAssetKeys.contains(selectionKey);
                  return M3AnimatedListEntry(
                    key: ValueKey('inventory-asset-animation-$selectionKey'),
                    visible: !exiting,
                    animateIn: _enteringAssetKeys.contains(selectionKey),
                    transitionKey: ValueKey<String>(
                      exiting
                          ? 'inventory-asset-exiting-${asset.assetRef}'
                          : 'inventory-asset-transition-${asset.assetRef}',
                    ),
                    revision: '${asset.status}:${asset.transferId}:'
                        '${asset.placementVersion}:'
                        '${asset.physicalLocation.id}:'
                        '${orderAssignment?.orderId ?? ''}:'
                        '${orderAssignment?.orderControl.name ?? ''}',
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : M3SegmentedListGeometry.gap,
                      ),
                      child: _InventoryAssetListRow(
                        key: ValueKey('inventory-asset-${asset.assetRef}'),
                        slot:
                            M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index,
                          _assets.length,
                        ),
                        asset: asset,
                        orderAssignment: orderAssignment,
                        busy: busy,
                        selected: selected,
                        onTap: _selectionMode
                            ? (selectable
                                ? () => _toggleAssetSelection(asset)
                                : null)
                            : () => _showAssetDetails(asset),
                        onLongPress: selectable
                            ? () => _toggleAssetSelection(asset)
                            : null,
                      ),
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
      _selectedAssetKeys.clear();
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
  final VoidCallback? onTap;
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
      '${_qty(asset.qty)} ${asset.uom}',
      _statusLabel(asset.status),
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
      key: ValueKey('inventory-asset-card-${asset.assetRef}'),
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
            ? ValueKey('inventory-asset-selected-${asset.assetRef}')
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
            selected ? Icons.check_rounded : _assetIcon(asset.kind),
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
    required this.showOrderAssignment,
    required this.allowOrderAssignment,
    required this.onOrderAssignmentChanged,
    required this.onQrRequested,
    required this.onDelete,
    required this.onRelocate,
    required this.onTransfer,
  });

  final InventoryAsset asset;
  final bool busy;
  final bool transferRequiresWarehouseLocation;
  final bool showOrderAssignment;
  final bool allowOrderAssignment;
  final Future<void> Function() onOrderAssignmentChanged;
  final Future<void> Function()? onQrRequested;
  final Future<void> Function()? onDelete;
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StatusBadge(status: asset.status),
                    if (onQrRequested != null)
                      IconButton(
                        key: ValueKey(
                          'inventory-asset-qr-button-${asset.assetRef}',
                        ),
                        onPressed: () => unawaited(onQrRequested!()),
                        tooltip: 'QR kodni ko‘rish',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.qr_code_2_rounded),
                      ),
                  ],
                ),
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
            if (showOrderAssignment) ...[
              const SizedBox(height: 10),
              RawMaterialOrderAssignmentSection(
                key: ValueKey(
                  'inventory-raw-material-assignment-${asset.assetRef}',
                ),
                barcode: _rawMaterialAssetBarcode(asset),
                allowAssignment: allowOrderAssignment,
                onAssignmentChanged: onOrderAssignmentChanged,
              ),
            ],
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
            if (onDelete != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: ValueKey(
                  'inventory-asset-delete-button-${asset.assetRef}',
                ),
                onPressed: () => unawaited(onDelete!()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Homashyoni o‘chirish'),
              ),
            ],
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
    required this.enteringTransferIds,
    required this.actionsFor,
    required this.onTransferTap,
    required this.onRefresh,
  });

  final List<InventoryTransfer> transfers;
  final String emptyMessage;
  final Widget header;
  final Set<String> busyKeys;
  final Set<String> enteringTransferIds;
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
                return M3AnimatedListEntry(
                  key: ValueKey('inventory-transfer-animation-${transfer.id}'),
                  visible: true,
                  animateIn: enteringTransferIds.contains(transfer.id),
                  transitionKey: ValueKey(
                    'inventory-transfer-transition-${transfer.id}',
                  ),
                  revision: '${transfer.status.apiValue}:'
                      '${transfer.approvedAtUnix}:'
                      '${transfer.dispatchedAtUnix}:'
                      '${transfer.receivedAtUnix}:'
                      '${transfer.rejectedAtUnix}:'
                      '${transfer.cancelledAtUnix}',
                  child: _InventoryTransferListRow(
                    key: ValueKey('inventory-transfer-${transfer.id}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index - 1,
                      transfers.length,
                    ),
                    transfer: transfer,
                    busy: busyKeys.any((key) => key.startsWith(transfer.id)),
                    onTap: () => unawaited(onTransferTap(transfer, actions)),
                  ),
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

class _InventoryAssetQrSheet extends StatefulWidget {
  const _InventoryAssetQrSheet({
    required this.asset,
    required this.barcode,
  });

  final InventoryAsset asset;
  final String barcode;

  @override
  State<_InventoryAssetQrSheet> createState() => _InventoryAssetQrSheetState();
}

class _InventoryAssetQrSheetState extends State<_InventoryAssetQrSheet> {
  Future<String?> _reprint() async {
    final prepared = await MobileApi.instance
        .adminPrepareRawMaterialStockReprint(barcode: widget.barcode);
    final expectedBarcode = widget.barcode.trim().toUpperCase();
    if (prepared.reprintId.trim().isEmpty ||
        prepared.stock.barcode.trim().toUpperCase() != expectedBarcode ||
        prepared.printRequest.epc.trim().toUpperCase() != expectedBarcode) {
      throw const MobileApiException(
        code: 'raw_material_stock_reprint_identity_mismatch',
        message: 'Serverdagi QR identifikatori mos kelmadi',
      );
    }
    final result = await PrintService.printRps(prepared.printRequest);
    if (!result.ok) {
      throw StateError('Printer QR kodini chop etmadi');
    }
    try {
      await MobileApi.instance.adminConfirmRawMaterialStockReprint(
        barcode: prepared.stock.barcode,
        reprintId: prepared.reprintId,
      );
      return null;
    } catch (_) {
      return 'QR chop etildi, lekin server tasdig‘i saqlanmadi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final itemName = asset.itemName.trim().isEmpty
        ? asset.itemCode.trim()
        : asset.itemName.trim();
    return RpsQrReprintSheet(
      title: 'Homashyo QR',
      payload: widget.barcode,
      itemName: itemName,
      previewKey: ValueKey(
        'inventory-asset-qr-preview-${asset.assetRef}',
      ),
      reprintButtonKey: ValueKey(
        'inventory-asset-qr-reprint-${asset.assetRef}',
      ),
      details: [
        if (asset.itemCode.trim().isNotEmpty)
          RpsQrDetail('Mahsulot kodi', asset.itemCode),
        RpsQrDetail('Identifikator', widget.barcode),
        RpsQrDetail('Miqdor', '${_qty(asset.qty)} ${asset.uom}'.trim()),
        if (asset.custodyWarehouse.trim().isNotEmpty)
          RpsQrDetail('Ombor', asset.custodyWarehouse),
        if (asset.physicalLocation.name.trim().isNotEmpty)
          RpsQrDetail('Fizik joy', asset.physicalLocation.name),
        RpsQrDetail('Holati', _statusLabel(asset.status)),
      ],
      onReprint: _reprint,
      errorMessage: (error) => error is MobileApiException
          ? error.message
          : 'QR kodini qayta chop etib bo‘lmadi',
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

String _rawMaterialAssetBarcode(InventoryAsset asset) {
  final identifier = asset.identifier.trim();
  if (identifier.isNotEmpty) {
    return identifier;
  }
  final assetRef = asset.assetRef.trim();
  final separator = assetRef.indexOf(':');
  return separator < 0 ? assetRef : assetRef.substring(separator + 1).trim();
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
