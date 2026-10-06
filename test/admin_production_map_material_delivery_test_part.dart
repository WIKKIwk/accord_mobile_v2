part of 'admin_production_map_test_screen_test.dart';

void _registerMaterialDeliveryTests() {
  test('material delivery: history preserves deliverer and receiving operator',
      () {
    final event = AdminRawMaterialEvent.fromJson({
      'event_type': 'delivery_received',
      'actor_display_name': 'Qabul qilgan operator',
      'payload_json': {
        'delivered_by': {'ref': 'mover-1', 'name': 'Olib kelgan Ali'},
        'received_by': {'ref': 'worker-1', 'name': 'Qabul qilgan operator'},
      },
    });
    expect(event.payloadJson['delivered_by']['name'], 'Olib kelgan Ali');
    expect(event.payloadJson['received_by']['ref'], 'worker-1');
    expect(event.actorDisplayName, 'Qabul qilgan operator');
  });
  for (final scenario in [
    (cancel: false, qolipFirst: false),
    (cancel: false, qolipFirst: true),
    (cancel: true, qolipFirst: false),
  ]) {
    testWidgets(
        'material delivery: ${scenario.cancel ? "cancel leaves material and order unchanged" : scenario.qolipFirst ? "final material receipt starts automatically" : "receive then final qolip scan starts automatically"}',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      const orderId = 'zakaz-material-delivery';
      const barcode = 'RM-DELIVERY';
      const product = 'DELIVERY-PRODUCT';
      const qolip = 'DELIVERY-QOLIP';
      const machine = AdminApparatus(
          id: _godexId, name: 'Godex aparat - DEMO', sourceRevision: 1);
      const warehouse = InventoryLocation(
          id: 'delivery-warehouse',
          kind: InventoryLocationKind.warehouse,
          name: 'Material ombor',
          warehouseId: 'warehouse:material');
      const state = InventoryLocation(
          id: 'delivery-machine',
          kind: InventoryLocationKind.state,
          name: 'Apparat oldi',
          factoryLocationId: 'state:delivery',
          apparatus: [
            InventoryLocationApparatus(
                id: _godexId, name: 'Godex aparat - DEMO')
          ]);
      seedMobileApiInventoryMovementTestData(locations: const [
        warehouse,
        state
      ], assets: const [
        InventoryAsset(
            kind: InventoryAssetKind.rawMaterial,
            assetRef: 'raw:delivery',
            custodyWarehouseId: 'warehouse:material',
            custodyWarehouse: 'Material ombor',
            itemCode: 'RM-DELIVERY',
            itemName: 'Yetkazilgan rulon',
            identifier: barcode,
            qty: 10,
            uom: 'kg',
            status: 'available',
            physicalLocation: InventoryLocationReference(
                id: 'delivery-warehouse',
                kind: InventoryLocationKind.warehouse,
                name: 'Material ombor')),
      ]);
      await MobileApi.instance.adminAssignWarehouse(
          warehouse: 'Material ombor',
          principalRole: UserRole.materialTaminotchi,
          principalRef: 'mover-1',
          displayName: 'Olib kelgan Ali');
      await MobileApi.instance.adminAssignWarehouse(
          warehouse: 'Boshqa ombor',
          principalRole: UserRole.materialTaminotchi,
          principalRef: 'mover-2',
          displayName: 'Boshqa ombordagi Vali');
      await MobileApi.instance.qolipSaveProductSpec(
          product: const QolipProduct(
              code: product,
              name: 'Delivery product',
              itemGroup: 'Tayyor mahsulotlar'),
          qolipCode: qolip,
          size: 42);
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
          id: orderId,
          title: 'Delivery order',
          productCode: product,
          apparatusId: _godexId,
          product: 'Delivery product',
          orderNumber: '0052'));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _godexId, orderIds: const [orderId]);
      await MobileApi.instance.adminSaveRawMaterialRule(
          apparatus: machine,
          currentRule: _testRawMaterialRule(machine),
          requiresMaterial: true,
          startPolicy: AdminRawMaterialStartPolicy.stateAll,
          itemGroups: const ['Kraska']);
      await MobileApi.instance.adminAssignRawMaterialToOrder(
          orderId: orderId, apparatus: _godexId, barcode: barcode);
      setMobileApiTestModeQueueActionControlFixture(
          apparatus: _godexId,
          orderId: orderId,
          control: _freshStartQueueControl(
              materialScanRequired: true,
              qolipMode: AdminQueueQolipMode.scanRequired));
      await AppSession.instance.setSession(
          token: 'delivery-worker',
          profile: const SessionProfile(
              role: UserRole.aparatchi,
              displayName: 'Qabul qilgan operator',
              legalName: '',
              ref: 'worker-delivery',
              phone: '',
              avatarUrl: '',
              capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
              assignedApparatus: [_godexId]));
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminProductionMapOrdersScreen(
              readOnly: true, workerMode: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Godex aparat - DEMO'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      await tester.pumpAndSettle();
      expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
      Future<void> scan(String value) async {
        if (find
            .byKey(const ValueKey('production-quick-scanner-manual'))
            .evaluate()
            .isEmpty) {
          await tester.tap(find
              .byKey(const ValueKey('production-quick-scanner-manual-toggle')));
          await tester.pumpAndSettle();
        }
        await tester.enterText(
            find.byKey(const ValueKey('production-quick-scanner-manual')),
            value);
        await tester.tap(find.byTooltip('Qabul qilish'));
        await tester.pumpAndSettle();
      }

      if (scenario.qolipFirst) await scan(qolip);
      await scan(barcode);
      expect(find.text('Bu homashyoni kim olib keldi?'), findsOneWidget);
      expect(find.text('Olib kelgan Ali'), findsOneWidget);
      expect(find.text('Boshqa ombordagi Vali'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('material-delivery-confirm')))
              .onPressed,
          isNull);
      if (scenario.cancel) {
        await tester.tap(find.text('Bekor qilish'));
        await tester.pumpAndSettle();
        final assets = await MobileApi.instance
            .inventoryAssets(assetKind: InventoryAssetKind.rawMaterial);
        expect(assets.single.physicalLocation.id, warehouse.id);
        expect(assets.single.status, 'available');
      } else {
        await tester.tap(find.text('Olib kelgan Ali'));
        await tester.pump();
        await tester
            .tap(find.byKey(const ValueKey('material-delivery-confirm')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('material-delivery-dialog')),
            findsNothing);
        final assets = await MobileApi.instance
            .inventoryAssets(assetKind: InventoryAssetKind.rawMaterial);
        expect(assets.single.physicalLocation.id, state.id);
        if (!scenario.qolipFirst) {
          final beforeQolip = await MobileApi.instance
              .adminRawMaterialAssignments(
                  orderId: orderId, apparatus: _godexId);
          expect(beforeQolip.single.stockStatus, 'available');
          await scan(qolip);
        }
        final startedMaterials = await MobileApi.instance
            .adminRawMaterialAssignments(orderId: orderId, apparatus: _godexId);
        expect(startedMaterials.single.stockStatus, 'in_use');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
