import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/inventory/presentation/inventory_movements_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inventory state rejects display-name apparatus identity', () {
    expect(
      () => InventoryLocation.fromJson(const {
        'id': 'inventory_location:state:legacy',
        'kind': 'state',
        'name': 'Legacy state',
        'apparatus': [
          {'id': 'Flexo pechat', 'name': 'Flexo pechat'},
        ],
      }),
      throwsFormatException,
    );
  });

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
    identifier: '30AA',
    qty: 10,
    uom: 'kg',
    status: 'available',
    physicalLocation: InventoryLocationReference(
      id: 'inventory_location:warehouse:a',
      kind: InventoryLocationKind.warehouse,
      name: 'Material ombor',
    ),
  );
  const secondAsset = InventoryAsset(
    kind: InventoryAssetKind.rawMaterial,
    assetRef: 'raw:2',
    custodyWarehouseId: 'warehouse:a',
    custodyWarehouse: 'Material ombor',
    itemCode: 'PE-2',
    itemName: 'Polietilen 2',
    identifier: '30BB',
    qty: 8,
    uom: 'kg',
    status: 'available',
    physicalLocation: InventoryLocationReference(
      id: 'inventory_location:warehouse:a',
      kind: InventoryLocationKind.warehouse,
      name: 'Material ombor',
    ),
  );
  const otherWarehouseAsset = InventoryAsset(
    kind: InventoryAssetKind.rawMaterial,
    assetRef: 'raw:b',
    custodyWarehouseId: 'warehouse:b',
    custodyWarehouse: 'Qolip ombor',
    itemCode: 'PP-B',
    itemName: 'Polipropilen',
    identifier: '30CC',
    qty: 6,
    uom: 'kg',
    status: 'available',
    physicalLocation: InventoryLocationReference(
      id: 'inventory_location:warehouse:b',
      kind: InventoryLocationKind.warehouse,
      name: 'Qolip ombor',
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
    resetMobileApiTestModeData();
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
      assignedApparatus: [
        'apparatus:default:asset-005',
        'apparatus:default:asset-007',
      ],
    );
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset],
      transfers: const [transfer],
    );
  });

  tearDown(() async {
    resetMobileApiTestModeData();
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
    final unassignedCardFinder =
        find.byKey(const ValueKey('inventory-asset-card-raw:1'));
    final unassignedCard =
        tester.widget<AdminSummaryCard>(unassignedCardFinder);
    expect(unassignedCard.title, 'Polietilen');
    expect(unassignedCard.subtitle, '30AA • 10 kg • Mavjud');
    expect(
      unassignedCard.backgroundColor,
      Theme.of(
        tester.element(unassignedCardFinder),
      ).colorScheme.surfaceContainerLowest,
    );

    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    expect(find.text('Hisobdagi ombor'), findsNothing);
    expect(find.text('Material ombor'), findsWidgets);
    expect(find.text('Joylashtirish'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);

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
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('inventory-location-inventory_location:warehouse:b'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ichki ko‘chirish'), findsOneWidget);
    final transferConfirm = find.text('Ko‘chirish');
    expect(
      tester.getCenter(transferConfirm).dy,
      lessThan(tester.getCenter(find.text('Bekor qilish')).dy),
    );
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Joylashtirish'));
    await tester.pumpAndSettle();

    expect(find.text('Fizik joylashuv'), findsOneWidget);
    expect(find.text('Bosma oldi'), findsOneWidget);
  });

  testWidgets('asset details sheet opens QR details from its corner action', (
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

    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    final qrAction = find.byKey(
      const ValueKey('inventory-asset-qr-button-raw:1'),
    );
    expect(qrAction, findsOneWidget);

    await tester.tap(qrAction);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inventory-asset-qr-preview-raw:1')),
      findsOneWidget,
    );
    expect(find.text('Homashyo QR'), findsOneWidget);
    expect(find.text('Polietilen'), findsWidgets);
    expect(
      find.byKey(const ValueKey('inventory-asset-qr-reprint-raw:1')),
      findsOneWidget,
    );
  });

  testWidgets(
      'available warehouse raw material requires confirmation to delete', (
    tester,
  ) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, secondAsset],
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

    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    final deleteAction = find.byKey(
      const ValueKey('inventory-asset-delete-button-raw:1'),
    );
    expect(deleteAction, findsOneWidget);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Homashyoni o‘chirish'), findsOneWidget);
    expect(find.textContaining('30AA'), findsWidgets);
    expect(
      find.byKey(const ValueKey('inventory-asset-delete-confirm-raw:1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('inventory-asset-card-raw:1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('inventory-asset-delete-confirm-raw:1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('inventory-asset-card-raw:1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('inventory-asset-card-raw:2')),
      findsOneWidget,
    );
  });

  testWidgets('warehouse assets can be selected and moved to a state in bulk', (
    tester,
  ) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, secondAsset],
      transfers: const [transfer],
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

    final firstCardFinder =
        find.byKey(const ValueKey('inventory-asset-card-raw:1'));
    final initialBackground =
        tester.widget<AdminSummaryCard>(firstCardFinder).backgroundColor;
    await tester.longPress(
      find.byKey(const ValueKey('inventory-asset-raw:1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mahsulot, kod yoki QR qidirish'), findsNothing);
    expect(find.text('1 ta tanlandi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('inventory-asset-selected-raw:1')),
      findsOneWidget,
    );
    expect(
      tester.widget<AdminSummaryCard>(firstCardFinder).backgroundColor,
      initialBackground,
    );

    await tester.tap(find.byKey(const ValueKey('inventory-asset-raw:2')));
    await tester.pumpAndSettle();
    expect(find.text('2 ta tanlandi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('inventory-asset-selected-raw:2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('inventory-selection-relocate')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Qaysi State’ga ko‘chirasiz?'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey(
          'inventory-location-inventory_location:state:bosma',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('2 ta mahsulot Bosma oldi State’ga ko‘chirilsinmi?'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('inventory-selection-relocate-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mahsulot, kod yoki QR qidirish'), findsOneWidget);
    expect(find.text('2 ta tanlandi'), findsNothing);
    expect(find.text('Omborda harakatlantiriladigan mahsulot yo‘q'),
        findsOneWidget);
    final stateAssets = await MobileApi.instance.inventoryAssets(
      currentUserStatesOnly: true,
    );
    expect(stateAssets.map((item) => item.assetRef),
        containsAll(['raw:1', 'raw:2']));
  });

  testWidgets('single relocation keeps sibling mounted while changed row exits',
      (
    tester,
  ) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, secondAsset],
      transfers: const [],
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

    const movedTransition =
        ValueKey<String>('inventory-asset-transition-raw:1');
    const siblingRow = ValueKey<String>('inventory-asset-raw:2');
    expect(find.byKey(movedTransition), findsOneWidget);
    expect(find.byKey(siblingRow), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('inventory-asset-raw:1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Joylashtirish'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey(
          'inventory-location-inventory_location:state:bosma',
        ),
      ),
    );

    var tabStayedMounted = true;
    var siblingStayedMounted = true;
    var sawExitTransition = false;
    var sawPartialExitFrame = false;
    for (var frame = 0; frame < 150; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      tabStayedMounted =
          tabStayedMounted && find.byType(TabBarView).evaluate().isNotEmpty;
      siblingStayedMounted =
          siblingStayedMounted && find.byKey(siblingRow).evaluate().isNotEmpty;
      final exitTransition = find.byKey(
        const ValueKey<String>('inventory-asset-exiting-raw:1'),
        skipOffstage: false,
      );
      sawExitTransition =
          sawExitTransition || exitTransition.evaluate().isNotEmpty;
      if (exitTransition.evaluate().isNotEmpty) {
        final animatedAligns = find.ancestor(
          of: exitTransition,
          matching: find.byType(Align, skipOffstage: false),
        );
        sawPartialExitFrame = sawPartialExitFrame ||
            tester.widgetList<Align>(animatedAligns).any(
                  (align) =>
                      align.heightFactor != null &&
                      align.heightFactor! > 0 &&
                      align.heightFactor! < 1,
                );
      }
    }
    await tester.pumpAndSettle();

    expect(tabStayedMounted, isTrue);
    expect(siblingStayedMounted, isTrue);
    expect(sawExitTransition, isTrue);
    expect(sawPartialExitFrame, isTrue);
    expect(find.byKey(movedTransition), findsNothing);
    expect(find.byKey(siblingRow), findsOneWidget);
  });

  testWidgets('state return keeps sibling mounted while changed row exits', (
    tester,
  ) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, secondAsset],
      transfers: const [],
    );
    await MobileApi.instance.inventoryRelocateBatch(
      assets: const [asset, secondAsset],
      physicalLocationId: factoryState.id,
      idempotencyKey: 'state-animation-placement',
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
    await tester.tap(find.text('State’lar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-state-filter-chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bosma oldi'));
    await tester.pumpAndSettle();

    const movedTransition =
        ValueKey<String>('material-state-asset-transition-raw:1');
    const siblingRow = ValueKey<String>('material-state-asset-raw:2');
    expect(find.byKey(movedTransition), findsOneWidget);
    expect(find.byKey(siblingRow), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('material-state-asset-raw:1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-state-return-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ha'));

    var siblingStayedMounted = true;
    var sawExitTransition = false;
    for (var frame = 0; frame < 150; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      siblingStayedMounted =
          siblingStayedMounted && find.byKey(siblingRow).evaluate().isNotEmpty;
      sawExitTransition = sawExitTransition ||
          find
              .byKey(
                const ValueKey<String>(
                  'material-state-asset-exiting-raw:1',
                ),
                skipOffstage: false,
              )
              .evaluate()
              .isNotEmpty;
    }
    await tester.pumpAndSettle();

    expect(siblingStayedMounted, isTrue);
    expect(sawExitTransition, isTrue);
    expect(find.byKey(movedTransition), findsNothing);
    expect(find.byKey(siblingRow), findsOneWidget);
  });

  testWidgets('transfer request updates its asset without replacing the tab', (
    tester,
  ) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, secondAsset],
      transfers: const [],
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

    const changedTransition =
        ValueKey<String>('inventory-asset-transition-raw:1');
    const siblingRow = ValueKey<String>('inventory-asset-raw:2');
    expect(find.byKey(changedTransition), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('inventory-asset-raw:1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('inventory-location-inventory_location:warehouse:b'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('So‘rov yuborish'));

    var tabStayedMounted = true;
    var siblingStayedMounted = true;
    for (var frame = 0; frame < 150; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      tabStayedMounted =
          tabStayedMounted && find.byType(TabBarView).evaluate().isNotEmpty;
      siblingStayedMounted =
          siblingStayedMounted && find.byKey(siblingRow).evaluate().isNotEmpty;
    }
    await tester.pumpAndSettle();

    expect(tabStayedMounted, isTrue);
    expect(siblingStayedMounted, isTrue);
    final changedCard = tester.widget<AdminSummaryCard>(
      find.byKey(const ValueKey('inventory-asset-card-raw:1')),
    );
    expect(changedCard.subtitle, contains('Band'));
    await tester.tap(find.text('Chiquvchi'));
    await tester.pumpAndSettle();
    expect(find.text('Material ombor → Qolip ombor'), findsOneWidget);
  });

  testWidgets('warehouse raw material links only to an eligible order', (
    tester,
  ) async {
    const pechatApparatus = AdminApparatus(
      id: 'apparatus:default:asset-005',
      name: 'Flexo pechat',
      operation: 'print',
      technology: 'flexographic',
      sourceRevision: 1,
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: 'zakaz-attach',
        productCode: 'P-1',
        title: 'Test zakaz',
        code: 'Z-100',
        nodes: [
          ProductionMapNode(
            id: 'apparatus',
            kind: 'apparatus',
            title: 'Flexo pechat',
            apparatusId: 'apparatus:default:asset-005',
          ),
        ],
        edges: [],
      ),
    );
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: pechatApparatus,
      currentRule: _testRawMaterialRule(pechatApparatus),
      requiresMaterial: true,
      itemGroups: const ['Kraska'],
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
    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    expect(find.text('Ulanmagan'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('raw-material-assign-order-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('raw-material-assign-order-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zakaz tanlang'), findsOneWidget);
    await tester.tap(find.text('Z-100 · Test zakaz'));
    await tester.pumpAndSettle();
    final confirmAssignment = find.byKey(
      const ValueKey('raw-material-confirm-assignment'),
    );
    expect(
      tester.getCenter(confirmAssignment).dy,
      lessThan(tester.getCenter(find.text('Bekor qilish')).dy),
    );
    expect(tester.getSize(confirmAssignment).width, greaterThan(250));
    await tester.tap(confirmAssignment);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('raw-material-current-assignment')),
      findsOneWidget,
    );
    expect(find.text('Z-100 · Test zakaz'), findsWidgets);
    expect(find.text('Flexo pechat'), findsOneWidget);

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey('raw-material-current-assignment')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    final assignedWarehouseCardFinder =
        find.byKey(const ValueKey('inventory-asset-card-raw:1'));
    final assignedWarehouseCard =
        tester.widget<AdminSummaryCard>(assignedWarehouseCardFinder);
    expect(assignedWarehouseCard.title, 'Z-100 · Test zakaz');
    expect(assignedWarehouseCard.subtitle, 'Polietilen • 10 kg • Mavjud');
    expect(assignedWarehouseCard.subtitle, isNot(contains('30AA')));
    expect(
      assignedWarehouseCard.backgroundColor,
      isNot(
        Theme.of(
          tester.element(assignedWarehouseCardFinder),
        ).colorScheme.surfaceContainerLowest,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('inventory-asset-raw:1')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('raw-material-unlink-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bu homashyoni zakazdan uzasizmi?'), findsOneWidget);
    final confirmUnlink = find.byKey(
      const ValueKey('raw-material-confirm-unlink'),
    );
    expect(
      tester.getCenter(confirmUnlink).dy,
      lessThan(tester.getCenter(find.text('Bekor qilish')).dy),
    );
    expect(tester.getSize(confirmUnlink).width, greaterThan(250));
    await tester.tap(confirmUnlink);
    await tester.pumpAndSettle();

    expect(find.text('Ulanmagan'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('raw-material-unlink-button')),
      findsNothing,
    );
  });

  testWidgets('selected linked warehouse raw materials can be unlinked in bulk',
      (tester) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, secondAsset],
      transfers: const [transfer],
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: 'zakaz-bulk-unlink',
        productCode: 'P-BULK',
        title: 'Bulk unlink zakaz',
        code: 'Z-BULK',
        nodes: [],
        edges: [],
      ),
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: 'zakaz-bulk-unlink',
      barcode: '30AA',
      apparatus: 'apparatus:test:asset-001',
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: 'zakaz-bulk-unlink',
      barcode: '30BB',
      apparatus: 'apparatus:test:asset-001',
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

    await tester.longPress(
      find.byKey(const ValueKey('inventory-asset-raw:1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('inventory-asset-raw:2')),
    );
    await tester.pumpAndSettle();

    final unlinkButton = find.byKey(
      const ValueKey('inventory-selection-unlink'),
    );
    expect(unlinkButton, findsOneWidget);
    await tester.tap(unlinkButton);
    await tester.pumpAndSettle();
    expect(
      find.text('2 ta ulangan homashyo orderdan uzilsinmi?'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('inventory-selection-unlink-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 ta homashyo orderdan uzildi'), findsOneWidget);
    expect(
      await MobileApi.instance.adminRawMaterialAssignments(),
      isEmpty,
    );
    expect(find.text('2 ta tanlandi'), findsNothing);
  });

  testWidgets('selected state assets return to their own warehouses', (
    tester,
  ) async {
    seedMobileApiInventoryMovementTestData(
      locations: const [source, destination, factoryState],
      assets: const [asset, otherWarehouseAsset],
      transfers: const [],
    );
    await MobileApi.instance.inventoryRelocate(
      assetKind: asset.kind,
      assetRef: asset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'state-multi-return-a',
    );
    await MobileApi.instance.inventoryRelocate(
      assetKind: otherWarehouseAsset.kind,
      assetRef: otherWarehouseAsset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'state-multi-return-b',
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
    await tester.tap(find.text('State’lar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-state-filter-chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bosma oldi'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.byKey(const ValueKey('material-state-asset-raw:1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mahsulot, kod yoki QR qidirish'), findsNothing);
    expect(find.text('1 ta tanlandi'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('material-state-asset-selected-raw:1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('material-state-asset-raw:b')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 ta tanlandi'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('material-state-selection-return')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('2 ta mahsulot o‘z omborlariga qaytarilsinmi?'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('material-state-selection-return-confirm'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Siz joylashtirgan State’dagi mahsulot topilmadi'),
      findsOneWidget,
    );
    final sourceAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: source.warehouseId,
    );
    final destinationAssets = await MobileApi.instance.inventoryAssets(
      warehouseId: destination.warehouseId,
    );
    expect(sourceAssets.single.assetRef, asset.assetRef);
    expect(destinationAssets.single.assetRef, otherWarehouseAsset.assetRef);
  });

  testWidgets('state raw material can be unlinked and linked to an order', (
    tester,
  ) async {
    const laminatsiyaApparatus = AdminApparatus(
      id: 'apparatus:default:asset-007',
      name: 'Laminatsiya 1',
      operation: 'laminate',
      technology: 'adhesive_lamination',
      sourceRevision: 1,
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: 'zakaz-state',
        productCode: 'P-2',
        title: 'State zakaz',
        code: 'Z-200',
        nodes: [
          ProductionMapNode(
            id: 'apparatus',
            kind: 'apparatus',
            title: 'Laminatsiya 1',
            apparatusId: 'apparatus:default:asset-007',
          ),
        ],
        edges: [],
      ),
    );
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: laminatsiyaApparatus,
      currentRule: _testRawMaterialRule(laminatsiyaApparatus),
      requiresMaterial: true,
      itemGroups: const ['Kraska'],
    );
    await MobileApi.instance.adminAssignRawMaterialToOrder(
      orderId: 'zakaz-state',
      barcode: '30AA',
      apparatus: 'apparatus:default:asset-007',
    );
    await MobileApi.instance.inventoryRelocate(
      assetKind: InventoryAssetKind.rawMaterial,
      assetRef: asset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'assigned-state-placement',
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
    await tester.tap(find.text('State’lar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-state-filter-chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bosma oldi'));
    await tester.pumpAndSettle();
    final assignedStateCardFinder =
        find.byKey(const ValueKey('material-state-asset-card-raw:1'));
    final assignedStateCard =
        tester.widget<AdminSummaryCard>(assignedStateCardFinder);
    expect(assignedStateCard.title, 'Z-200 · State zakaz');
    expect(assignedStateCard.subtitle, 'Polietilen • 10 kg • Mavjud');
    expect(assignedStateCard.subtitle, isNot(contains('30AA')));
    expect(
      assignedStateCard.backgroundColor,
      isNot(
        Theme.of(
          tester.element(assignedStateCardFinder),
        ).colorScheme.surfaceContainerLowest,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('material-state-asset-raw:1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('raw-material-current-assignment')),
      findsOneWidget,
    );
    expect(find.text('Z-200 · State zakaz'), findsWidgets);
    expect(find.text('Laminatsiya 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('raw-material-assign-order-button')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('raw-material-unlink-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('raw-material-confirm-unlink')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ulanmagan'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('raw-material-assign-order-button')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(
      find.byKey(const ValueKey('raw-material-assign-order-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Z-200 · State zakaz'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('raw-material-confirm-assignment')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('raw-material-current-assignment')),
      findsOneWidget,
    );
    expect(find.text('Z-200 · State zakaz'), findsWidgets);
  });

  testWidgets('material movement page keeps the existing state return flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await MobileApi.instance.inventoryRelocate(
      assetKind: InventoryAssetKind.rawMaterial,
      assetRef: asset.assetRef,
      physicalLocationId: factoryState.id,
      idempotencyKey: 'movement-state-placement',
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

    final tabLabels = tester
        .widgetList<Tab>(find.byType(Tab))
        .map((tab) => tab.text)
        .whereType<String>()
        .toList(growable: false);
    expect(
      tabLabels,
      containsAllInOrder(['Mahsulotlar', 'State’lar', 'Kiruvchi', 'Chiquvchi']),
    );

    await tester.tap(find.text('State’lar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('material-state-filter-chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bosma oldi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Polietilen'));
    await tester.pumpAndSettle();

    expect(find.text('Omborga qaytarish'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('material-state-return-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ha'));
    await tester.pumpAndSettle();

    expect(
      find.text('Siz joylashtirgan State’dagi mahsulot topilmadi'),
      findsOneWidget,
    );
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
    expect(find.text('Ko‘chirishni yakunlash'), findsNothing);
  });
}

AdminRawMaterialRule _testRawMaterialRule(AdminApparatus apparatus) {
  return AdminRawMaterialRule(
    apparatusId: apparatus.id,
    sourceRevision: apparatus.sourceRevision,
    sourceAasxSha256: '',
    apparatus: apparatus.name,
    requiresMaterial: false,
    itemGroups: const [],
  );
}
