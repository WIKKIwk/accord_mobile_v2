part of 'admin_production_map_test_screen_test.dart';

void _registerMixedWipTests() {
  for (final useOpening in [false, true]) {
    testWidgets(
        'mixed WIP lists all four rolls and accepts ${useOpening ? 'opening' : 'production'} input',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      const order = 'zakaz-mixed-wip';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezkachi',
        legalName: '',
        ref: 'mixed-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_rezkaId],
      );
      await MobileApi.instance
          .adminSaveProductionMap(_twoStageProductionOrderMap(
        id: order,
        title: 'Elitex mixed',
        productCode: 'MIXED',
        product: 'Elitex mixed',
        firstApparatusId: _lamination1Id,
        secondApparatusId: _rezkaId,
      ));
      final opening = await MobileApi.instance
          .adminCreateOpeningWip(const AdminOpeningWipCreateInput(
        idempotencyKey: 'mixed-wip-opening',
        orderId: order,
        sourceApparatus: _lamination1Id,
        sourceStageNodeId: 'first-apparatus',
        batches: [
          AdminOpeningWipBatchInput(
              quantityBasis: AdminOpeningWipQuantityBasis.measured,
              finishedGoodsMeter: 12,
              finishedGoodsKg: 12,
              bobinaKg: 1)
        ],
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _rezkaId, orderIds: const [order]);
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _lamination1Id, orderIds: const [order]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _lamination1Id, orderId: order, action: 'start');
      for (var i = 0; i < 3; i++) {
        if (i > 0) {
          await MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: _lamination1Id, orderId: order, action: 'resume');
        }
        await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _lamination1Id,
          orderId: order,
          action: 'detach_roll',
          producedQty: 100 + i.toDouble(),
          grossQty: 20,
          uom: 'm',
          finishedGoodsMeter: 100 + i.toDouble(),
          finishedGoodsKg: 20,
          bobinaKg: 1,
        );
      }
      final produced = await MobileApi.instance
          .adminWipBatches(orderId: order, status: 'waiting');
      expect(produced, hasLength(3));
      setMobileApiTestModeQueueActionControlFixture(
          apparatus: _rezkaId,
          orderId: order,
          control: const AdminApparatusQueueOrderActionControl(
            state: 'pending',
            allowedActions: {'start'},
            hasOnlyKnownActions: true,
            previousStage: _lamination1Id,
            previousStageReady: true,
            interaction: AdminQueueWorkerInteraction(
              mode: AdminQueueInteractionMode.freshStart,
              startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
              materialScanRequired: false,
              assignedMaterialsDisplayOnly: true,
              materialIntakeAllowed: false,
              previousWipMode: AdminQueuePreviousWipMode.scanRequired,
              openingWipMode: AdminQueuePreviousWipMode.scanRequired,
              qolipMode: AdminQueueQolipMode.notRequired,
            ),
          ));
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            liveEventsLoader: () => const Stream.empty()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_fixtureApparatusName(_rezkaId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$order')));
      await tester.pumpAndSettle();
      expect(find.textContaining('4 ta mahsulot bor'), findsOneWidget);
      for (final qr in [
        opening.batches.single.qrPayload,
        ...produced.map((b) => b.qrPayload)
      ]) {
        expect(find.text('QR: $qr'), findsOneWidget);
      }
      final start = find.widgetWithText(FilledButton, 'Boshlash');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      await tester
          .widget<ProductionQuickScannerPanel>(
              find.byType(ProductionQuickScannerPanel))
          .onCodeDetected('UNKNOWN-MIXED-QR');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      final qr =
          useOpening ? opening.batches.single.qrPayload : produced[1].qrPayload;
      await tester
          .widget<ProductionQuickScannerPanel>(
              find.byType(ProductionQuickScannerPanel))
          .onCodeDetected(qr);
      await tester.pumpAndSettle();
      await _waitForQuickScannerFeedback(tester);
      expect(find.text('Oldingi bosqich tasdiqlandi'), findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      if (!useOpening) {
        await tester.ensureVisible(start);
        await tester.tap(start);
        await tester.pumpAndSettle();
        final records = await MobileApi.instance
            .adminOpeningWipRecords(orderId: order, status: 'all');
        expect(records.single.batches.single.wipStatus, 'waiting');
        final after = await MobileApi.instance
            .adminWipBatches(orderId: order, status: 'all');
        expect(after.where((b) => b.wipStatus == 'in_use'), hasLength(1));
        expect(after.singleWhere((b) => b.wipStatus == 'in_use').batchId,
            produced[1].batchId);
      }
      dismissAdminTopNotice();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
