import 'dart:async';

import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
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
  Timer? _searchDebounce;
  List<InventoryLocation> _locations = const [];
  List<InventoryAsset> _assets = const [];
  List<InventoryTransfer> _incoming = const [];
  List<InventoryTransfer> _outgoing = const [];
  String _selectedWarehouseId = '';
  bool _loading = true;
  bool _assetsLoading = false;
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
      setState(() {
        _locations = locations;
        _selectedWarehouseId = selected;
        _incoming = results[0] as List<InventoryTransfer>;
        _outgoing = results[1] as List<InventoryTransfer>;
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
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadAssets);
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
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Transfer so‘rovi'),
            content: Text(
              '${asset.itemName} (${_qty(asset.qty)} ${asset.uom})\n'
              '${asset.custodyWarehouse} → ${selected.name}\n\n'
              'Qabul qiluvchi tasdiqlamaguncha mahsulot manba omborda '
              'band holatda qoladi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Bekor qilish'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('So‘rov yuborish'),
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
      await MobileApi.instance.inventoryCreateTransfer(
        sourceWarehouseId: asset.custodyWarehouseId,
        destinationWarehouseId: selected.warehouseId,
        assets: [asset],
        idempotencyKey: _idempotencyKey('transfer'),
      );
      _showMessage('Transfer so‘rovi yuborildi');
      await _loadAll();
    });
  }

  Future<void> _transferAction(
    InventoryTransfer transfer,
    String action,
  ) async {
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
            title: Text(labels[action] ?? 'Transfer'),
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
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory harakatlari'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mahsulotlar'),
              Tab(text: 'Kiruvchi'),
              Tab(text: 'Chiquvchi'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Yangilash',
              onPressed: _loading ? null : _loadAll,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error.isNotEmpty
                ? _InventoryErrorState(message: _error, onRetry: _loadAll)
                : TabBarView(
                    children: [
                      _buildAssetsTab(),
                      _TransferList(
                        transfers: _incoming,
                        emptyMessage: 'Kiruvchi transfer yo‘q',
                        busyKeys: _busyKeys,
                        actionsFor: _incomingActions,
                        onAction: _transferAction,
                        onRefresh: _loadAll,
                      ),
                      _TransferList(
                        transfers: _outgoing,
                        emptyMessage: 'Chiquvchi transfer yo‘q',
                        busyKeys: _busyKeys,
                        actionsFor: _outgoingActions,
                        onAction: _transferAction,
                        onRefresh: _loadAll,
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
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: const ValueKey('inventory-warehouse-picker'),
                    initialValue: _selectedWarehouseId.isEmpty
                        ? null
                        : _selectedWarehouseId,
                    decoration: const InputDecoration(
                      labelText: 'Ombor',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                    ),
                    items: [
                      for (final location in _visibleWarehouseLocations())
                        DropdownMenuItem(
                          value: location.warehouseId,
                          child: Text(location.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedWarehouseId = value ?? '');
                      _loadAssets();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Nomi, kodi yoki QR bo‘yicha qidirish',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_assetsLoading)
            const SliverToBoxAdapter(child: LinearProgressIndicator())
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
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
              sliver: SliverList.separated(
                itemCount: _assets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final key = '${asset.kind.apiValue}:${asset.assetRef}';
                  final busy = _busyKeys.any((item) => item.contains(key));
                  return _InventoryAssetCard(
                    asset: asset,
                    busy: busy,
                    onRelocate:
                        asset.isAvailable ? () => _relocate(asset) : null,
                    onTransfer: asset.isAvailable
                        ? () => _requestTransfer(asset)
                        : null,
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

  List<String> _incomingActions(InventoryTransfer transfer) {
    final canReceive = _isAdmin ||
        _assignedWarehouseNames
            .contains(transfer.destinationWarehouse.trim().toLowerCase());
    if (!canReceive) {
      return const [];
    }
    return switch (transfer.status) {
      InventoryTransferStatus.requested => const ['approve', 'reject'],
      InventoryTransferStatus.inTransit => const ['receive'],
      _ => const [],
    };
  }

  List<String> _outgoingActions(InventoryTransfer transfer) {
    final canSend = _isAdmin ||
        _assignedWarehouseNames
            .contains(transfer.sourceWarehouse.trim().toLowerCase());
    if (!canSend) {
      return const [];
    }
    return switch (transfer.status) {
      InventoryTransferStatus.requested => const ['cancel'],
      InventoryTransferStatus.approved => const ['dispatch', 'cancel'],
      _ => const [],
    };
  }
}

class _InventoryAssetCard extends StatelessWidget {
  const _InventoryAssetCard({
    required this.asset,
    required this.busy,
    required this.onRelocate,
    required this.onTransfer,
  });

  final InventoryAsset asset;
  final bool busy;
  final VoidCallback? onRelocate;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(_assetIcon(asset.kind)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.itemName.isEmpty
                            ? asset.itemCode
                            : asset.itemName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (asset.identifier.isNotEmpty) asset.identifier,
                          '${_qty(asset.qty)} ${asset.uom}',
                        ].join(' • '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: asset.status),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.account_balance_outlined,
              label: 'Javobgar ombor',
              value: asset.custodyWarehouse,
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Fizik joy',
              value: asset.physicalLocation.name,
            ),
            const SizedBox(height: 12),
            if (busy)
              const LinearProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRelocate,
                      icon: const Icon(Icons.pin_drop_outlined),
                      label: const Text('Joylashtirish'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onTransfer,
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

class _TransferList extends StatelessWidget {
  const _TransferList({
    required this.transfers,
    required this.emptyMessage,
    required this.busyKeys,
    required this.actionsFor,
    required this.onAction,
    required this.onRefresh,
  });

  final List<InventoryTransfer> transfers;
  final String emptyMessage;
  final Set<String> busyKeys;
  final List<String> Function(InventoryTransfer) actionsFor;
  final Future<void> Function(InventoryTransfer, String) onAction;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: transfers.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
              itemCount: transfers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final transfer = transfers[index];
                final actions = actionsFor(transfer);
                return _TransferCard(
                  transfer: transfer,
                  actions: actions,
                  busy: busyKeys.any((key) => key.startsWith(transfer.id)),
                  onAction: (action) => onAction(transfer, action),
                );
              },
            ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.actions,
    required this.busy,
    required this.onAction,
  });

  final InventoryTransfer transfer;
  final List<String> actions;
  final bool busy;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${transfer.sourceWarehouse} → '
                    '${transfer.destinationWarehouse}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusBadge(status: transfer.status.apiValue),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in transfer.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '• ${line.itemName.isEmpty ? line.itemCode : line.itemName}'
                  ' — ${_qty(line.qty)} ${line.uom}',
                ),
              ),
            if (transfer.note.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                transfer.note,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _transferTimestamp(transfer),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (busy) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ] else if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  for (final action in actions)
                    action == 'reject' || action == 'cancel'
                        ? OutlinedButton(
                            onPressed: () => onAction(action),
                            child: Text(_actionLabel(action)),
                          )
                        : FilledButton(
                            onPressed: () => onAction(action),
                            child: Text(_actionLabel(action)),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text('$label: '),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
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
