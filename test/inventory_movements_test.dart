import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/inventory/presentation/inventory_movements_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const source = InventoryLocation(
    id: 'inventory_location:warehouse:a',
    kind: InventoryLocationKind.warehouse,
    name: 'Material ombor',
    warehouseId: 'warehouse:a',
  );
  const destination = InventoryLocation(
    id: 'inventory_location:warehouse:b',
    kind: InventoryLocationKind.warehouse,
    name: 'Qolip ombor',
    warehouseId: 'warehouse:b',
  );
  const factoryState = InventoryLocation(
    id: 'inventory_location:state:bosma',
    kind: InventoryLocationKind.state,
    name: 'Bosma oldi',
    factoryLocationId: 'state_bosma',
  );
  const asset = InventoryAsset(
    kind: InventoryAssetKind.rawMaterial,
    assetRef: 'raw:1',
    custodyWarehouseId: 'warehouse:a',
    custodyWarehouse: 'Material ombor',
    itemCode: 'PE-1',
    itemName: 'Polietilen',
    identifier: 'QR-001',
    qty: 10,
    uom: 'kg',
    status: 'available',
    physicalLocation: InventoryLocationReference(
      id: 'inventory_location:warehouse:a',
      kind: InventoryLocationKind.warehouse,
      name: 'Material ombor',
    ),
  );
  const transfer = InventoryTransfer(
    id: 'transfer:test',
    sourceWarehouseId: 'warehouse:a',
    sourceWarehouse: 'Material ombor',
    destinationWarehouseId: 'warehouse:b',
    destinationWarehouse: 'Qolip ombor',
    status: InventoryTransferStatus.requested,
    note: 'Sinov transferi',
    requestedByName: 'Materialchi',
    approvedByName: '',
    dispatchedByName: '',
    receivedByName: '',
    rejectedByName: '',
    cancelledByName: '',
    createdAtUnix: 0,
    lines: [
      InventoryTransferLine(
        assetKind: InventoryAssetKind.rawMaterial,
        assetRef: 'raw:1',
        itemCode: 'PE-1',
        itemName: 'Polietilen',
        identifier: 'QR-001',
        qty: 10,
        uom: 'kg',
        sourcePhysicalLocationId: 'inventory_location:warehouse:a',
      ),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'test-mode-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage'],
      assignedWarehouses: ['Material ombor'],
    );
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset],
      transfers: const [transfer],
    );
  });

  tearDown(() async {
    resetMobileApiInventoryMovementTestData();
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('state relocation preserves quantity and custody', () async {
    final moved = await MobileApi.instance.inventoryRelocate(
      assetKind: InventoryAssetKind.rawMaterial,
      assetRef: asset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'relocate-1',
    );

    expect(moved.qty, 10);
    expect(moved.custodyWarehouse, 'Material ombor');
    expect(moved.physicalLocation.name, 'Bosma oldi');

    final sourceAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: source.warehouseId,
    );
    expect(sourceAssets, isEmpty);
  });

  test('state assets only include placements made by the current user',
      () async {
    await MobileApi.instance.inventoryRelocate(
      assetKind: InventoryAssetKind.rawMaterial,
      assetRef: asset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'relocate-owned-state',
    );

    final ownStateAssets = await MobileApi.instance.inventoryAssets(
      currentUserStatesOnly: true,
    );
    expect(ownStateAssets.single.assetRef, asset.assetRef);

    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Boshqa materialchi',
      legalName: '',
      ref: 'material-2',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage'],
      assignedWarehouses: ['Material ombor'],
    );

    final otherStateAssets = await MobileApi.instance.inventoryAssets(
      currentUserStatesOnly: true,
    );
    expect(otherStateAssets, isEmpty);
  });

  test('state-located asset cannot be transferred from a warehouse', () async {
    await MobileApi.instance.inventoryRelocate(
      assetKind: InventoryAssetKind.rawMaterial,
      assetRef: asset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'relocate-before-transfer',
    );

    await expectLater(
      MobileApi.instance.inventoryCreateTransfer(
        sourceWarehouseId: source.warehouseId,
        destinationWarehouseId: destination.warehouseId,
        assets: const [asset],
        idempotencyKey: 'state-transfer',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'inventory_asset_not_in_source_warehouse',
        ),
      ),
    );
  });

  test('bilateral transfer reaches received without changing quantity',
      () async {
    final requested = await MobileApi.instance.inventoryCreateTransfer(
      sourceWarehouseId: source.warehouseId,
      destinationWarehouseId: destination.warehouseId,
      assets: const [asset],
      idempotencyKey: 'transfer-1',
    );
    expect(requested.status, InventoryTransferStatus.requested);

    final approved = await MobileApi.instance.inventoryTransferAction(
      transferId: requested.id,
      action: 'approve',
      idempotencyKey: 'approve-1',
    );
    expect(approved.status, InventoryTransferStatus.approved);

    final dispatched = await MobileApi.instance.inventoryTransferAction(
      transferId: requested.id,
      action: 'dispatch',
      idempotencyKey: 'dispatch-1',
    );
    expect(dispatched.status, InventoryTransferStatus.inTransit);

    final received = await MobileApi.instance.inventoryTransferAction(
      transferId: requested.id,
      action: 'receive',
      idempotencyKey: 'receive-1',
    );
    expect(received.status, InventoryTransferStatus.received);

    final destinationAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: destination.warehouseId,
    );
    expect(destinationAssets.single.qty, 10);
    expect(destinationAssets.single.custodyWarehouse, 'Qolip ombor');
  });

  test('transfer between assigned warehouses completes immediately', () async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage'],
      assignedWarehouses: ['Material ombor', 'Qolip ombor'],
    );

    final transferred = await MobileApi.instance.inventoryCreateTransfer(
      sourceWarehouseId: source.warehouseId,
      destinationWarehouseId: destination.warehouseId,
      assets: const [asset],
      idempotencyKey: 'internal-transfer-1',
    );

    expect(transferred.status, InventoryTransferStatus.received);
    expect(transferred.approvedByName, 'Materialchi');
    expect(transferred.dispatchedByName, 'Materialchi');
    expect(transferred.receivedByName, 'Materialchi');

    final sourceAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: source.warehouseId,
    );
    expect(sourceAssets, isEmpty);

    final destinationAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: destination.warehouseId,
    );
    expect(destinationAssets.single.status, 'available');
    expect(destinationAssets.single.transferId, isEmpty);
    expect(destinationAssets.single.physicalLocation.id, destination.id);
  });

  test('legacy self-transfer completes with one action', () async {
    final requested = await MobileApi.instance.inventoryCreateTransfer(
      sourceWarehouseId: source.warehouseId,
      destinationWarehouseId: destination.warehouseId,
      assets: const [asset],
      idempotencyKey: 'legacy-internal-transfer-1',
    );
    expect(requested.status, InventoryTransferStatus.requested);

    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage'],
      assignedWarehouses: ['Material ombor', 'Qolip ombor'],
    );

    final completed = await MobileApi.instance.inventoryTransferAction(
      transferId: requested.id,
      action: 'approve',
      idempotencyKey: 'complete-legacy-internal-transfer-1',
    );

    expect(completed.status, InventoryTransferStatus.received);
    final destinationAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: destination.warehouseId,
    );
    expect(destinationAssets.single.status, 'available');
    expect(destinationAssets.single.transferId, isEmpty);
  });

  testWidgets('movement center shows stock and opens state bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InventoryMovementsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polietilen'), findsOneWidget);
    expect(find.text('Mahsulot, kod yoki QR qidirish'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(find.text('Joylashtirish'), findsNothing);
    expect(find.text('Transfer'), findsNothing);

    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    expect(find.text('Hisobdagi ombor'), findsNothing);
    expect(find.text('Material ombor'), findsWidgets);
    expect(find.text('Joylashtirish'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);

    await tester.tap(find.text('Joylashtirish'));
    await tester.pumpAndSettle();

    expect(find.text('Fizik joylashuv'), findsOneWidget);
    expect(find.text('Bosma oldi'), findsOneWidget);
  });

  testWidgets('warehouse filter is available on all movement tabs', (
    tester,
  ) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage'],
      assignedWarehouses: ['Material ombor', 'Qolip ombor'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InventoryMovementsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final filterKey = const ValueKey('inventory-warehouse-filter-chip');
    expect(find.byKey(filterKey), findsOneWidget);

    await tester.tap(find.text('Kiruvchi'));
    await tester.pumpAndSettle();
    expect(find.byKey(filterKey), findsOneWidget);

    await tester.tap(find.text('Chiquvchi'));
    await tester.pumpAndSettle();
    expect(find.byKey(filterKey), findsOneWidget);

    await tester.tap(find.byKey(filterKey).first);
    await tester.pumpAndSettle();
    expect(find.text('Qolip ombor'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('inventory-warehouse-option-warehouse:b')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ombor: Qolip ombor'), findsOneWidget);
  });

  testWidgets('transfer tabs show compact rows and open details on tap', (
    tester,
  ) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['inventory.movement.manage'],
      assignedWarehouses: ['Material ombor', 'Qolip ombor'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InventoryMovementsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final filterKey = const ValueKey('inventory-warehouse-filter-chip');
    await tester.tap(find.text('Kiruvchi'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(filterKey).first);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('inventory-warehouse-option-warehouse:b')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Material ombor → Qolip ombor'), findsOneWidget);
    expect(find.text('Ko‘chirishni yakunlash'), findsNothing);

    await tester.tap(find.text('Material ombor → Qolip ombor'));
    await tester.pumpAndSettle();

    expect(find.text('Sinov transferi'), findsOneWidget);
    expect(find.text('Ko‘chirishni yakunlash'), findsOneWidget);
  });
}
