import 'dart:async';

import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_stock.dart';
import 'package:accord_mobile_v2/src/features/admin/models/admin_item_group_tree_entry.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter_test/flutter_test.dart';

const machine = AdminApparatus(
    id: 'apparatus:test:a', name: 'Bosma', factoryMapObjectId: 'node:7');
const locations = [
  InventoryLocation(
      id: 'state-a',
      kind: InventoryLocationKind.state,
      name: 'Bosma oldi',
      apparatus: [
        InventoryLocationApparatus(id: 'apparatus:test:a', name: 'Bosma')
      ])
];
const items = [
  SupplierItem(
      code: 'foil',
      name: 'PET',
      uom: 'Kg',
      warehouse: '',
      itemGroup: 'PET child'),
  SupplierItem(
      code: 'glue',
      name: 'Rulon named glue',
      uom: 'Kg',
      warehouse: '',
      itemGroup: 'Kley'),
];
const groups = [
  AdminItemGroupTreeEntry(
      name: 'PET child',
      itemGroupName: 'PET child',
      parentItemGroup: ' RULON ',
      isGroup: false),
];
InventoryAsset roll(String id,
        {String status = 'available',
        String item = 'foil',
        double qty = 200,
        String state = 'state-a',
        InventoryLocationKind placeKind = InventoryLocationKind.state}) =>
    InventoryAsset(
        kind: InventoryAssetKind.rawMaterial,
        assetRef: id,
        custodyWarehouseId: 'warehouse-1',
        custodyWarehouse: 'Ombor',
        itemCode: item,
        itemName: '',
        identifier: 'QR-$id',
        qty: qty,
        uom: 'Kg',
        status: status,
        physicalLocation: InventoryLocationReference(
            id: state, kind: placeKind, name: state));
Future<void> flush() => Future<void>.delayed(Duration.zero);
Map<String, dynamic> payload(FactoryMapStock stock) =>
    stock.payload([machine], (key) => key);
FactoryMapStock fixture(
        {FactoryStockPage? page,
        Stream<Map<String, dynamic>> Function()? events,
        DateTime Function()? clock}) =>
    FactoryMapStock(
        loadPage: page ?? (_) async => [roll('one')],
        loadLocations: () async => locations,
        loadItems: () async => items,
        loadGroups: () async => groups,
        events: events ?? () => const Stream.empty(),
        clock: clock);

void main() {
  test(
      'counts physical available Rulon descendants, not kg, item name or order',
      () {
    final result = stateRollInventory([
      roll('one', qty: 850),
      roll('two', qty: .01),
      roll('mounted', status: 'in_use'),
      roll('used', status: 'consumed'),
      roll('deleted', status: 'deleted'),
      roll('zero', qty: 0),
      roll('warehouse', placeKind: InventoryLocationKind.warehouse),
      roll('transit', placeKind: InventoryLocationKind.transit),
      roll('other-state', state: 'unknown'),
      roll('glue', item: 'glue'),
      roll('transfer').copyWith(transferId: 'transfer'),
    ], locations, items, groups);
    expect(result, {
      'state-a': ['one', 'two']
    });
  });

  test(
      'relocation adds, mounting and consumption subtract; return to state restores',
      () {
    var asset = roll('one', placeKind: InventoryLocationKind.warehouse);
    Map<String, List<String>> count() =>
        stateRollInventory([asset], locations, items, groups);
    expect(count(), isEmpty);
    asset = roll('one');
    expect(count()['state-a'], ['one']);
    asset = asset.copyWith(status: 'in_use');
    expect(count(), isEmpty);
    asset = asset.copyWith(status: 'consumed');
    expect(count(), isEmpty);
    asset = asset.copyWith(status: 'available');
    expect(count()['state-a'], ['one']);
  });

  test(
      'inactive states, other asset kinds and cyclic non-Rulon groups are excluded',
      () {
    expect(
        stateRollInventory([
          roll('one')
        ], const [
          InventoryLocation(
              id: 'state-a',
              kind: InventoryLocationKind.state,
              name: '',
              active: false)
        ], items, groups),
        isEmpty);
    const cyclic = [
      AdminItemGroupTreeEntry(
          name: 'PET child',
          itemGroupName: 'PET child',
          parentItemGroup: 'PET child',
          isGroup: true)
    ];
    expect(
        stateRollInventory([roll('one')], locations, items, cyclic), isEmpty);
    final finished = InventoryAsset.fromJson({
      'kind': 'finished_goods',
      'asset_ref': 'fg',
      'item_code': 'foil',
      'qty': 3,
      'status': 'available',
      'physical_location': {'id': 'state-a', 'kind': 'state'}
    });
    expect(stateRollInventory([finished], locations, items, groups), isEmpty);
  });

  test(
      'missing catalog and duplicate physical IDs fail closed instead of inventing a count',
      () {
    expect(() => stateRollInventory([roll('one')], locations, [], groups),
        throwsStateError);
    expect(
        () => stateRollInventory(
            [roll('one'), roll('one')], locations, items, groups),
        throwsStateError);
  });

  test(
      'paginates past 500 and publishes complete counts; a shared state is not duplicated',
      () async {
    final offsets = <int>[];
    final stock = fixture(page: (offset) async {
      offsets.add(offset);
      return offset == 0
          ? List.generate(500, (i) => roll('$i'))
          : [roll('last')];
    });
    addTearDown(stock.dispose);
    stock.start();
    await flush();
    expect(offsets, [0, 500]);
    expect((payload(stock)['piles'] as List).single['count'], 501);
    final shared = FactoryMapStock(
        loadPage: (_) async => [roll('one')],
        loadLocations: () async => [
              InventoryLocation(
                  id: 'state-a',
                  kind: InventoryLocationKind.state,
                  name: '',
                  apparatus: [
                    locations.single.apparatus.single,
                    const InventoryLocationApparatus(
                        id: 'apparatus:test:b', name: 'Second')
                  ])
            ],
        loadItems: () async => items,
        loadGroups: () async => groups,
        events: () => const Stream.empty());
    addTearDown(shared.dispose);
    shared.start();
    await flush();
    final result = shared.payload([
      machine,
      machine.copyWith(id: 'apparatus:test:b', factoryMapObjectId: 'node:20')
    ], (s) => s);
    expect(result['piles'], hasLength(1));
    expect((result['piles'] as List).single['objectIds'], hasLength(2));
    expect((result['piles'] as List).single['count'], 1);
    // Ambiguous map binding cannot create a pile attached to the wrong machine.
    expect(
        shared.payload([machine, machine.copyWith(id: 'apparatus:test:b')],
            (s) => s)['piles'],
        isEmpty);
  });

  test(
      'events refresh mounted rolls without queue/order data; bursts are coalesced',
      () async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    var assets = [roll('one'), roll('two')], loads = 0;
    final stock = fixture(
        page: (_) async {
          loads++;
          return assets;
        },
        events: () => events.stream);
    addTearDown(() async {
      stock.dispose();
      await events.close();
    });
    stock.start();
    await flush();
    expect((payload(stock)['piles'] as List).single['count'], 2);
    assets = [roll('one', status: 'in_use'), roll('two')];
    for (var i = 0; i < 5; i++) {
      events.add({'event': 'warehouse.updated'});
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(loads, 2);
    expect((payload(stock)['piles'] as List).single['rollIds'], ['two']);
    assets = [];
    await stock.refresh();
    expect((payload(stock)['piles'] as List).single['count'], 0);
  });

  test(
      'partial/failed reads and stale timestamps cannot claim an empty or current pile',
      () async {
    var fail = false;
    var now = DateTime(2026);
    final stock = fixture(
        clock: () => now,
        page: (_) async {
          if (fail) throw StateError('offline');
          return [roll('one')];
        });
    addTearDown(stock.dispose);
    stock.start();
    await flush();
    expect(payload(stock)['fresh'], isTrue);
    now = now.add(FactoryMapStock.freshness);
    expect(payload(stock)['validUntil'], 0);
    await stock.refresh();
    expect(stock.fresh, isTrue);
    fail = true;
    await stock.refresh();
    expect(stock.fresh, isFalse);
    expect((payload(stock)['piles'] as List).single['count'], 1,
        reason: 'Last known inventory is retained, but explicitly stale');
    stock.stop();
    expect(payload(stock)['fresh'], isFalse);
  });

  test(
      'event during read discards that snapshot and follows up; stop rejects late completion',
      () async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    final pending = Completer<List<InventoryAsset>>();
    var loads = 0;
    final stock = fixture(
        events: () => events.stream,
        page: (_) {
          loads++;
          return loads == 1 ? pending.future : Future.value([roll('two')]);
        });
    addTearDown(() async {
      stock.dispose();
      await events.close();
    });
    stock.start();
    await flush();
    events.add({'event': 'warehouse.updated'});
    await flush();
    pending.complete([roll('old')]);
    await flush();
    expect(loads, 2);
    expect((payload(stock)['piles'] as List).single['rollIds'], ['two']);
    final late = Completer<List<InventoryAsset>>();
    final stopped = fixture(page: (_) => late.future);
    stopped.start();
    await flush();
    stopped.stop();
    late.complete([roll('late')]);
    await flush();
    expect(stopped.receivedAt, isNull);
    stopped.dispose();
  });
}
