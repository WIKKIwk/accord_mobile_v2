import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';
import '../../shared/models/inventory_movement_models.dart';
import '../models/admin_item_group_tree_entry.dart';
import 'factory_map_mapping.dart';

typedef FactoryStockPage = Future<List<InventoryAsset>> Function(int offset);

/// A stock row is one physical roll; qty is kg/metres, NEVER the roll count.
/// No queue, order assignment, WIP origin, or current-user owner is consulted.
class FactoryMapStock extends ChangeNotifier {
  FactoryMapStock({
    Future<List<InventoryLocation>> Function()? loadLocations,
    FactoryStockPage? loadPage,
    Future<List<SupplierItem>> Function()? loadItems,
    Future<List<AdminItemGroupTreeEntry>> Function()? loadGroups,
    Stream<Map<String, dynamic>> Function()? events,
    DateTime Function()? clock,
  })  : _loadLocations = loadLocations ?? MobileApi.instance.inventoryLocations,
        _loadPage = loadPage ??
            ((offset) => MobileApi.instance.inventoryAssets(
                assetKind: InventoryAssetKind.rawMaterial,
                limit: pageSize,
                offset: offset)),
        _loadItems = loadItems ?? MobileApi.instance.adminItems,
        _loadGroups = loadGroups ?? MobileApi.instance.adminItemGroupTree,
        _events = events ?? MobileApi.instance.adminWarehouseLiveEvents,
        _clock = clock ?? DateTime.now;

  static const pageSize = 500;
  static const freshness = Duration(seconds: 30);
  final Future<List<InventoryLocation>> Function() _loadLocations;
  final FactoryStockPage _loadPage;
  final Future<List<SupplierItem>> Function() _loadItems;
  final Future<List<AdminItemGroupTreeEntry>> Function() _loadGroups;
  final Stream<Map<String, dynamic>> Function() _events;
  final DateTime Function() _clock;
  List<InventoryLocation> _locations = const [];
  Map<String, List<String>> _rolls = const {};
  List<SupplierItem>? _items;
  List<AdminItemGroupTreeEntry> _groups = const [];
  DateTime? _catalogAt;
  DateTime? receivedAt;
  bool failed = false;
  bool _active = false, _disposed = false, _again = false;
  int _generation = 0, _eventRevision = 0;
  int? _request;
  Timer? _poll, _expiry, _debounce, _reconnect;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  bool get fresh =>
      _active &&
      !failed &&
      receivedAt != null &&
      _clock().difference(receivedAt!) < freshness;

  void start() {
    if (_active || _disposed) return;
    _active = true;
    _connect();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    unawaited(refresh());
  }

  void _connect() {
    final generation = _generation;
    void reconnect() {
      if (!_active || _disposed || generation != _generation) return;
      _reconnect?.cancel();
      _reconnect = Timer(const Duration(seconds: 10), () {
        unawaited(_subscription?.cancel());
        _connect();
      });
    }

    try {
      _subscription = _events().listen((event) {
        if (generation != _generation ||
            event['event'] != 'warehouse.updated') {
          return;
        }
        // Invalidate in-flight pagination: a move/consume may change offsets.
        _eventRevision++;
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () => refresh());
      }, onError: (_) => reconnect(), onDone: reconnect);
    } catch (_) {
      reconnect();
    } // Polling remains the fallback, not fake stock.
  }

  void stop() {
    _active = false;
    _generation++;
    _request = null;
    _again = false;
    for (final timer in [_poll, _expiry, _debounce, _reconnect]) {
      timer?.cancel();
    }
    unawaited(_subscription?.cancel());
    _subscription = null;
    receivedAt = null;
    if (!_disposed) notifyListeners();
  }

  Future<List<InventoryAsset>> _allAssets(int generation) async {
    final result = <InventoryAsset>[];
    final seen = <String>{};
    // Bound a broken/repeating server without ever publishing a partial count.
    for (var offset = 0; offset < 250000; offset += pageSize) {
      if (generation != _generation || _disposed) throw StateError('Cancelled');
      final page = await _loadPage(offset).timeout(const Duration(seconds: 10));
      for (final asset in page) {
        if (!seen.add(asset.assetRef.trim().toLowerCase())) {
          throw StateError('Inventory changed during pagination');
        }
      }
      result.addAll(page);
      if (page.length < pageSize) return result;
    }
    throw StateError('Incomplete inventory');
  }

  Future<void> refresh() async {
    if (!_active || _disposed) return;
    if (_request != null) {
      _again = true;
      return;
    }
    final generation = _generation;
    final revision = _eventRevision;
    final startedAt = _clock();
    _request = generation;
    try {
      final locations =
          await _loadLocations().timeout(const Duration(seconds: 10));
      final assets = await _allAssets(generation);
      var items = _items;
      var groups = _groups;
      final known =
          items?.map((e) => e.code.trim().toLowerCase()).toSet() ?? <String>{};
      final missing = assets.any((e) =>
          e.physicalLocation.kind == InventoryLocationKind.state &&
          e.isAvailable &&
          !known.contains(e.itemCode.trim().toLowerCase()));
      if (items == null ||
          missing ||
          _catalogAt == null ||
          _clock().difference(_catalogAt!) >= const Duration(minutes: 1)) {
        items = await _loadItems().timeout(const Duration(seconds: 15));
        groups = await _loadGroups().timeout(const Duration(seconds: 10));
      }
      final rolls = stateRollInventory(assets, locations, items, groups);
      if (_disposed || generation != _generation) return;
      if (revision != _eventRevision) {
        _again = true;
        return;
      }
      if (!identical(_items, items)) _catalogAt = _clock();
      _items = items;
      _groups = groups;
      _locations = locations;
      _rolls = rolls;
      receivedAt = startedAt;
      failed = false;
      _expiry?.cancel();
      _expiry = Timer(freshness - _clock().difference(startedAt), () {
        if (!_disposed) notifyListeners();
      });
      notifyListeners();
    } catch (_) {
      if (!_disposed && generation == _generation) {
        failed = true;
        notifyListeners();
      }
    } finally {
      if (_request == generation) {
        _request = null;
        if (_again && _active && !_disposed) {
          _again = false;
          unawaited(refresh());
        }
      }
    }
  }

  Map<String, dynamic> payload(
      List<AdminApparatus> apparatus, String Function(String) text) {
    final objects = <String, String>{};
    for (final machine in apparatus) {
      final id = canonicalFactoryMapObjectId(machine.factoryMapObjectId);
      if (id.isNotEmpty && factoryMapObjectOwners(apparatus, id).length == 1) {
        objects[machine.id] = id;
      }
    }
    final piles = <Map<String, dynamic>>[];
    final states = [..._locations]..sort((a, b) => a.id.compareTo(b.id));
    for (final state in states) {
      if (!state.active || !state.isState) continue;
      final objectIds = state.apparatus
          .map((a) => objects[a.id])
          .whereType<String>()
          .toSet()
          .toList()
        ..sort();
      if (objectIds.isEmpty) continue;
      final ids = _rolls[state.id] ?? const <String>[];
      // Exactly one pile per physical state, even if several machines share it.
      piles.add({
        'stateId': state.id,
        'name': state.name,
        'objectIds': objectIds,
        'rollIds': ids,
        'count': ids.length
      });
    }
    return {
      'fresh': fresh,
      'validUntil':
          fresh ? receivedAt!.add(freshness).millisecondsSinceEpoch : 0,
      'piles': piles,
      'rollLabel': text('factory_map.stock.rolls'),
      'unknownLabel': text('factory_map.stock.unknown'),
      'noSpaceLabel': text('factory_map.stock.no_space')
    };
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

Map<String, List<String>> stateRollInventory(
    List<InventoryAsset> assets,
    List<InventoryLocation> locations,
    List<SupplierItem> items,
    List<AdminItemGroupTreeEntry> groups) {
  String key(String value) => value.trim().toLowerCase();
  final tree = {
    for (final group in groups) ...{
      key(group.name): group,
      key(group.itemGroupName): group
    }
  };
  bool isRoll(String current) {
    final seen = <String>{};
    while (current.isNotEmpty && seen.add(key(current))) {
      if (key(current) == 'rulon') return true;
      final group = tree[key(current)];
      if (group == null) return false;
      if (key(group.name) == 'rulon' || key(group.itemGroupName) == 'rulon') {
        return true;
      }
      current = group.parentItemGroup;
    }
    return false;
  }

  final catalog = {for (final item in items) key(item.code): item};
  final states = {
    for (final state in locations)
      if (state.isState && state.active) state.id
  };
  final rolls = <String, List<String>>{};
  final seen = <String>{};
  for (final asset in assets) {
    if (asset.kind != InventoryAssetKind.rawMaterial ||
        !asset.isAvailable ||
        !asset.qty.isFinite ||
        asset.qty <= 0 ||
        asset.physicalLocation.kind != InventoryLocationKind.state ||
        !states.contains(asset.physicalLocation.id)) {
      continue;
    }
    final item = catalog[key(asset.itemCode)];
    if (item == null) throw StateError('Stock item missing from catalog');
    if (!isRoll(item.itemGroup)) continue;
    if (asset.assetRef.trim().isEmpty || !seen.add(key(asset.assetRef))) {
      throw StateError('Ambiguous physical roll');
    }
    (rolls[asset.physicalLocation.id] ??= []).add(asset.assetRef);
  }
  for (final ids in rolls.values) {
    ids.sort();
  }
  return rolls;
}
