import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/inventory/presentation/inventory_movements_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';
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

  testWidgets('movement center shows stock and opens state bottom sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: InventoryMovementsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polietilen'), findsOneWidget);
    expect(find.text('Material ombor'), findsWidgets);
    expect(find.text('Joylashtirish'), findsOneWidget);

    await tester.tap(find.text('Joylashtirish'));
    await tester.pumpAndSettle();

    expect(find.text('Fizik joylashuv'), findsOneWidget);
    expect(find.text('Bosma oldi'), findsOneWidget);
  });
}
