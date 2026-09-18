part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerFabQrTests() {
  const targetId = 'zakaz-0003';
  const currentId = 'zakaz-0001';
  final l10n = AppLocalizations(const Locale('uz'));

  for (final scenario in [
    'idle',
    'duplicate-scan',
    'other-order',
    'busy-other-order',
    'reported-handoff',
    'queue-blocked',
    'unassigned',
    'unknown',
    'unknown-retry',
    'used-roll'
  ]) {
    testWidgets('worker FAB WIP QR: $scenario', (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Laminatsiya worker',
        legalName: '',
        ref: 'fab-worker',
        phone: '',
        avatarUrl: '',
        capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [
          scenario == 'unassigned' ? _lamination2Id : _lamination1Id
        ],
      );
      await MobileApi.instance
          .adminSaveProductionMap(_twoStageProductionOrderMap(
        id: targetId,
        title: 'Apachi 900 gr',
        productCode: 'APACHI',
        product: 'Apachi',
        firstApparatusId: _print9Id,
        secondApparatusId: _lamination1Id,
      ).copyWith(orderNumber: '0003'));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _print9Id, orderIds: const [targetId]);
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _lamination1Id, orderIds: const [currentId, targetId]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print9Id, orderId: targetId, action: 'start');
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print9Id,
          orderId: targetId,
          action: 'detach_roll',
          producedQty: 4544,
          grossQty: 454,
          finishedGoodsMeter: 4544,
          finishedGoodsKg: 454,
          bobinaKg: 1,
          uom: 'm');
      final input = (await MobileApi.instance.adminProgressQrHistory())
          .firstWhere((batch) => batch.orderId == targetId);
      var qr = scenario.startsWith('unknown') ? 'UNKNOWN-WIP' : input.qrPayload;

      final hasCurrent = scenario == 'other-order' ||
          scenario == 'busy-other-order' ||
          scenario == 'reported-handoff';
      if (hasCurrent) {
        await MobileApi.instance.adminSaveProductionMap(
            scenario == 'reported-handoff'
                ? _twoStageProductionOrderMap(
                        id: currentId,
                        title: 'Current work',
                        productCode: 'CURRENT',
                        product: 'Current product',
                        firstApparatusId: _lamination1Id,
                        secondApparatusId: _rezkaId)
                    .copyWith(orderNumber: '0001')
                : _productionOrderMap(
                    id: currentId,
                    title: 'Current work',
                    productCode: 'CURRENT',
                    apparatusId: _lamination1Id,
                    product: 'Current product',
                    orderNumber: '0001'));
        await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: _lamination1Id, orderId: currentId, action: 'start');
        if (scenario == 'reported-handoff') {
          await MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: _lamination1Id,
              orderId: currentId,
              action: 'complete',
              producedQty: 100,
              grossQty: 20,
              uom: 'm',
              finishedGoodsMeter: 100,
              finishedGoodsKg: 20,
              bobinaKg: 1,
              laminationPrintLeftoverRolls: 1,
              totalWaste: 1);
        }
        setMobileApiTestModeQueueActionControlFixture(
            apparatus: _lamination1Id,
            orderId: currentId,
            control: scenario == 'reported-handoff'
                ? _completedQueueControl()
                : _inProgressQueueControl());
      }
      final blocked =
          scenario == 'queue-blocked' || scenario == 'busy-other-order';
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _lamination1Id,
        orderId: targetId,
        control: AdminApparatusQueueOrderActionControl(
          state: 'pending',
          allowedActions: blocked ? const {} : const {'start'},
          hasOnlyKnownActions: true,
          previousStage: _print9Id,
          previousStageReady: true,
          interaction: AdminQueueWorkerInteraction(
            mode: blocked
                ? AdminQueueInteractionMode.freshStartBlocked
                : AdminQueueInteractionMode.freshStart,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: true,
            materialIntakeAllowed: false,
            previousWipMode: AdminQueuePreviousWipMode.scanRequired,
            qolipMode: AdminQueueQolipMode.notRequired,
            blockingReasonCode: blocked
                ? (scenario == 'busy-other-order'
                    ? 'apparatus_busy'
                    : 'waiting_sequence')
                : '',
          ),
        ),
      );
      if (scenario == 'used-roll') {
        await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: _lamination1Id,
            orderId: targetId,
            action: 'start',
            qrPayload: input.qrPayload,
            progressBatchId: input.batchId);
        setMobileApiTestModeQueueActionControlFixture(
            apparatus: _lamination1Id,
            orderId: targetId,
            control: _inProgressQueueControl());
      }
      await _usePhoneViewport(tester);
      var scannerRoutes = 0;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          expect(settings.name, AppRoutes.adminProgressQrScan);
          scannerRoutes++;
          return MaterialPageRoute<String>(
              builder: (context) => Scaffold(
                    body: TextButton(
                      key: const ValueKey('return-fab-qr'),
                      onPressed: () => Navigator.of(context).pop(qr),
                      child: const Text('Scan WIP'),
                    ),
                  ));
        },
        home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            liveEventsLoader: () => const Stream.empty()),
      ));
      await tester.pumpAndSettle();
      final scanFuture = tester
          .widget<AparatchiDock>(find.byType(AparatchiDock))
          .onQrScanRequested!();
      if (scenario == 'duplicate-scan') {
        await tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
      }
      await tester.pumpAndSettle();
      expect(scannerRoutes, 1);
      await tester.tap(find.byKey(const ValueKey('return-fab-qr')));
      await tester.pumpAndSettle();
      await scanFuture;

      expect(
          find.text(l10n.productionText('worker.error.current_order_missing')),
          findsNothing);
      if (scenario == 'reported-handoff') {
        await tester
            .tap(find.byKey(const ValueKey('production-switch-order-confirm')));
        await tester.pumpAndSettle();
        for (final field in [
          'worker.daily.field.print_leftover',
          'worker.daily.field.film_leftover',
          'worker.daily.field.total_waste'
        ]) {
          final input =
              find.widgetWithText(TextFormField, l10n.productionText(field));
          await tester.ensureVisible(input);
          await tester.enterText(input, '1');
        }
        await tester.ensureVisible(find.text('Tasdiqlash'));
        await tester.tap(find.text('Tasdiqlash'));
        await tester.pumpAndSettle();
      }
      if (scenario == 'idle' ||
          scenario == 'duplicate-scan' ||
          scenario == 'reported-handoff') {
        expect(find.text('0003'), findsWidgets);
        expect(
            find.text(
                l10n.productionText('worker.progress.previous.confirmed')),
            findsOneWidget);
        expect(find.byType(ProductionQuickScannerPanel), findsNothing);
        final start = find.widgetWithText(FilledButton, 'Boshlash');
        expect(start, findsOneWidget);
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      } else if (hasCurrent) {
        expect(find.byKey(const ValueKey('production-switch-order-confirm')),
            findsOneWidget);
        await tester.tap(find.text(l10n.productionText('worker.action.no')));
        await tester.pumpAndSettle();
        expect(
            find.text(
                l10n.productionText('worker.progress.previous.confirmed')),
            findsNothing);
      } else {
        expect(
            find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
            findsNothing);
      }
      if (scenario == 'unknown-retry') {
        dismissAdminTopNotice();
        qr = input.qrPayload;
        final retry = tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('return-fab-qr')));
        await tester.pumpAndSettle();
        await retry;
        expect(scannerRoutes, 2);
        expect(
            find.text(
                l10n.productionText('worker.progress.previous.confirmed')),
            findsOneWidget);
      }
      final after =
          await MobileApi.instance.adminProgressQrLookup(input.qrPayload);
      expect(after.wipStatus, scenario == 'used-roll' ? 'in_use' : 'waiting',
          reason: 'Routing and scan acceptance must not start or consume work');
      dismissAdminTopNotice();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
