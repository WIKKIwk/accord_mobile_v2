part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerFabQrTests() {
  _registerWorkerFabQrStateGuidanceTests();

  const targetId = 'zakaz-0003';
  const currentId = 'zakaz-0001';
  final l10n = AppLocalizations(const Locale('uz'));

  for (final scenario in [
    'idle',
    'upstream-requeued',
    'mixed-input',
    'duplicate-scan',
    'other-order',
    'busy-other-order',
    'reported-handoff',
    'paused-reported',
    'report-required',
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
      ).copyWith(orderNumber: '0003',
        baseLength: scenario == 'upstream-requeued' ? 1000 : null));
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
      if (scenario == 'upstream-requeued') {
        final frozen = await MobileApi.instance.adminProductionMapOrderControl(
          orderId: targetId, action: AdminOrderControlAction.freeze);
        if (frozen == AdminOrderControlState.freezeRequested) {
          await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: _print9Id, orderId: targetId, action: 'pause',
            completionRequestNote: 'Requeue regression');
        }
        await MobileApi.instance.adminProductionMapOrderControl(
          orderId: targetId, action: AdminOrderControlAction.unfreeze);
        setMobileApiTestModeQueueActionControlFixture(
          apparatus: _print9Id, orderId: targetId,
          control: const AdminApparatusQueueOrderActionControl(
            state: 'pending', stageNodeId: 'first-apparatus',
            allowedActions: {'resume'}, hasOnlyKnownActions: true,
            interaction: AdminQueueWorkerInteraction(
              mode: AdminQueueInteractionMode.requeuedReady,
              startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
              materialScanRequired: false, assignedMaterialsDisplayOnly: true,
              materialIntakeAllowed: false,
              previousWipMode: AdminQueuePreviousWipMode.notRequired,
              qolipMode: AdminQueueQolipMode.notRequired,
            ),
          ),
        );
      }
      if (scenario == 'mixed-input') {
        await MobileApi.instance
            .adminCreateOpeningWip(const AdminOpeningWipCreateInput(
          idempotencyKey: 'fab-opening',
          orderId: targetId,
          sourceApparatus: _print9Id,
          sourceStageNodeId: 'first-apparatus',
          batches: [
            AdminOpeningWipBatchInput(
                quantityBasis: AdminOpeningWipQuantityBasis.measured,
                finishedGoodsMeter: 12,
                finishedGoodsKg: 12,
                bobinaKg: 1)
          ],
        ));
      }

      final hasCurrent = scenario == 'other-order' ||
          scenario == 'busy-other-order' ||
          scenario == 'reported-handoff' ||
          scenario == 'paused-reported' ||
          scenario == 'report-required';
      if (hasCurrent) {
        await MobileApi.instance.adminSaveProductionMap([
          'reported-handoff',
          'paused-reported',
          'report-required'
        ].contains(scenario)
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
        if (['reported-handoff', 'paused-reported', 'report-required']
            .contains(scenario)) {
          await MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: _lamination1Id,
              orderId: currentId,
              action:
                  scenario == 'paused-reported' ? 'detach_roll' : 'complete',
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
            control: ['reported-handoff', 'paused-reported', 'report-required']
                    .contains(scenario)
                ? AdminApparatusQueueOrderActionControl(
                    state:
                        scenario == 'paused-reported' ? 'paused' : 'completed',
                    allowedActions: scenario == 'paused-reported'
                        ? const {'resume'}
                        : const {},
                    hasOnlyKnownActions: true,
                    stageWork: AdminStageWorkControl(
                      upstreamClosed: true,
                      astatkaAvailable: true,
                      astatkaRequired: scenario == 'report-required',
                      reportSessionId: 'previous-session',
                    ),
                    interaction: AdminQueueWorkerInteraction(
                      mode: scenario == 'paused-reported'
                          ? AdminQueueInteractionMode.paused
                          : AdminQueueInteractionMode.completed,
                      startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
                      materialScanRequired: false,
                      assignedMaterialsDisplayOnly: true,
                      materialIntakeAllowed: false,
                      previousWipMode: AdminQueuePreviousWipMode.notRequired,
                      qolipMode: AdminQueueQolipMode.notRequired,
                    ),
                  )
                : _inProgressQueueControl());
        if (scenario == 'paused-reported') {
          await MobileApi.instance.adminLaminatsiyaAstatkaReport(
            apparatus: _lamination1Id,
            orderId: currentId,
            laminationPrintLeftoverRolls: 0,
            laminationFilmLeftoverRolls: 0,
            totalWaste: 0,
          );
        }
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
          previousStageReady: scenario != 'upstream-requeued',
          interaction: AdminQueueWorkerInteraction(
            mode: blocked
                ? AdminQueueInteractionMode.freshStartBlocked
                : AdminQueueInteractionMode.freshStart,
            startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
            materialScanRequired: false,
            assignedMaterialsDisplayOnly: true,
            materialIntakeAllowed: false,
            previousWipMode: AdminQueuePreviousWipMode.scanRequired,
            openingWipMode: scenario == 'mixed-input'
                ? AdminQueuePreviousWipMode.scanRequired
                : AdminQueuePreviousWipMode.notRequired,
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
      if (scenario == 'upstream-requeued') {
        await tester.tap(find.text(_fixtureApparatusName(_lamination1Id)));
        await tester.pumpAndSettle();
        expect(find.text('WIP tayyor · skanerlang'), findsNothing);
        final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
        expect(snapshot.queueStates[_print9Id]?[targetId], 'pending');
      }
      if (scenario == 'report-required') {
        await tester
            .tap(find.text(l10n.productionText('worker.stage.astatka.later')));
        await tester.pumpAndSettle();
      }
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
      await tester.pump();
      if (scenario == 'idle') {
        expect(
            find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
            findsOneWidget);
        expect(find.byType(ProductionQuickScannerPanel), findsNothing,
            reason: 'FAB QR validation must not briefly mount the camera');
        final pendingStart = find.widgetWithText(FilledButton, 'Boshlash');
        expect(pendingStart, findsOneWidget);
        expect(tester.widget<FilledButton>(pendingStart).onPressed, isNull,
            reason: 'start must wait for the FAB QR validation');
      }
      await tester.pumpAndSettle();
      await scanFuture;

      expect(
          find.text(l10n.productionText('worker.error.current_order_missing')),
          findsNothing);
      if (scenario == 'report-required') {
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
          scenario == 'upstream-requeued' ||
          scenario == 'mixed-input' ||
          scenario == 'duplicate-scan' ||
          scenario == 'reported-handoff' ||
          scenario == 'paused-reported' ||
          scenario == 'report-required') {
        expect(find.text('0003'), findsWidgets);
        expect(
            find.text(
                l10n.productionText('worker.progress.previous.confirmed')),
            findsOneWidget);
        expect(find.byType(ProductionQuickScannerPanel), findsNothing);
        final start = find.widgetWithText(FilledButton, 'Boshlash');
        expect(start, findsOneWidget);
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        if (scenario == 'upstream-requeued') {
          final summary = find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_OrderSummaryCard');
          final toggle = find.descendant(of: summary, matching: find.byType(InkWell)).first;
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(find.text('Qayta navbatda · davom ettirish mumkin'), findsOneWidget);
          expect(find.text('WIP tayyor · skanerlang'), findsWidgets);
        }
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
      if (scenario == 'reported-handoff' || scenario == 'paused-reported') {
        expect(find.byKey(const ValueKey('production-switch-order-confirm')),
            findsNothing);
        Navigator.of(
                tester.element(find.widgetWithText(FilledButton, 'Boshlash')))
            .pop(false);
        await tester.pumpAndSettle();
        final retry = tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('return-fab-qr')));
        await tester.pumpAndSettle();
        await retry;
        expect(find.byKey(const ValueKey('production-switch-order-confirm')),
            findsNothing);
        expect(
            find.text(
                l10n.productionText('worker.progress.previous.confirmed')),
            findsOneWidget);
      }
      if (scenario == 'unknown-retry') {
        await _closeInlineWipGuidance(tester);
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

void _registerWorkerFabQrStateGuidanceTests() {
  const orderId = 'zakaz-fab-shift';
  const busyId = 'zakaz-fab-busy';
  const previousWorkerRef = 'previous-shift-worker';
  final l10n = AppLocalizations(const Locale('uz'));
  for (final scenario in [
    'active-merge',
    'active-no-merge',
    'active-report',
    'paused-ready',
    'paused-busy',
    'paused-closing',
    'in-use-roll',
    'in-use-paused-ready',
    'in-use-paused-busy',
    'processed-roll',
    'requeued-ready',
    'requeued-waiting',
    'completed',
    'completed-report',
    'unknown-blocker',
  ]) {
    testWidgets('worker FAB WIP QR state guidance: $scenario', (tester) async {
      addTearDown(() async {
        dismissAdminTopNotice();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
      final consumerId =
          scenario == 'active-report' ? _rezkaId : _lamination1Id;
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Previous shift',
        legalName: '',
        ref: previousWorkerRef,
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [consumerId],
      );
      final map = _twoStageProductionOrderMap(
        id: orderId,
        title: 'Shift work',
        productCode: 'SHIFT',
        product: 'Shift product',
        firstApparatusId: _print9Id,
        secondApparatusId: consumerId,
      ).copyWith(orderNumber: '0091');
      await MobileApi.instance.adminSaveProductionMap(map.copyWith(nodes: [
        for (final node in map.nodes)
          node.apparatusId == _rezkaId
              ? node.copyWith(rezkaKadrCount: 1)
              : node,
      ]));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _print9Id, orderIds: const [orderId]);
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: consumerId, orderIds: const [orderId, busyId]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print9Id, orderId: orderId, action: 'start');
      final firstOutput =
          await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _print9Id,
        orderId: orderId,
        action: 'detach_roll',
        producedQty: 100,
        grossQty: 20,
        finishedGoodsMeter: 100,
        finishedGoodsKg: 20,
        bobinaKg: 1,
        uom: 'm',
      );
      final firstInput = firstOutput.progressBatch!;
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: consumerId,
        orderId: orderId,
        action: 'start',
        qrPayload: firstInput.qrPayload,
        progressBatchId: firstInput.batchId,
      );
      final completed = scenario.startsWith('completed');
      if (completed) {
        await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: consumerId,
          orderId: orderId,
          action: 'complete',
          producedQty: 100,
          grossQty: 20,
          finishedGoodsMeter: 100,
          finishedGoodsKg: 20,
          bobinaKg: 1,
          uom: 'm',
          laminationPrintLeftoverRolls: 1,
          laminationFilmLeftoverRolls: 1,
          totalWaste: 1,
        );
      }
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print9Id, orderId: orderId, action: 'resume');
      final secondOutput =
          await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _print9Id,
        orderId: orderId,
        action: 'detach_roll',
        producedQty: 200,
        grossQty: 40,
        finishedGoodsMeter: 200,
        finishedGoodsKg: 40,
        bobinaKg: 1,
        uom: 'm',
      );
      final freshInput = secondOutput.progressBatch!;
      if (scenario == 'processed-roll') {
        await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: consumerId,
          orderId: orderId,
          action: 'merge',
          qrPayload: freshInput.qrPayload,
          progressBatchId: freshInput.batchId,
        );
      }
      final paused = scenario.startsWith('paused-') ||
          scenario == 'in-use-paused-ready' ||
          scenario == 'in-use-paused-busy';
      if (paused) {
        await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: consumerId,
          orderId: orderId,
          action: 'pause',
          producedQty: 10,
          grossQty: 2,
          finishedGoodsMeter: 10,
          finishedGoodsKg: 2,
          bobinaKg: 1,
          uom: 'm',
        );
      }
      final busy =
          scenario == 'paused-busy' || scenario == 'in-use-paused-busy';
      if (busy) {
        await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
          id: busyId,
          orderNumber: '0092',
          title: 'Other active work',
          productCode: 'BUSY',
          product: 'Other product',
          apparatusId: consumerId,
        ));
        await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: consumerId, orderId: busyId, action: 'start');
        setMobileApiTestModeQueueActionControlFixture(
            apparatus: consumerId,
            orderId: busyId,
            control: _inProgressQueueControl());
      }
      final requeued =
          scenario.startsWith('requeued-') || scenario == 'unknown-blocker';
      if (requeued) {
        final frozen = await MobileApi.instance.adminProductionMapOrderControl(
            orderId: orderId, action: AdminOrderControlAction.freeze);
        if (frozen == AdminOrderControlState.freezeRequested) {
          await MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: consumerId,
              orderId: orderId,
              action: 'pause',
              freezeRequestId: 'test-freeze-$orderId',
              completionRequestNote: 'Shift queue regression');
        }
        await MobileApi.instance.adminProductionMapOrderControl(
            orderId: orderId, action: AdminOrderControlAction.unfreeze);
      }
      final state = completed
          ? 'completed'
          : requeued
              ? 'pending'
              : paused
                  ? 'paused'
                  : 'in_progress';
      final activity = requeued || completed
          ? null
          : AdminQueueWorkActivity(
              workerRole: 'aparatchi',
              workerRef: previousWorkerRef,
              state: state);
      final actions = completed
          ? const <String>{}
          : requeued
              ? scenario == 'requeued-ready'
                  ? const {'resume'}
                  : const <String>{}
              : paused
                  ? {
                      if (scenario == 'paused-ready' ||
                          scenario == 'in-use-paused-ready')
                        'resume',
                      if (scenario == 'paused-closing') 'complete',
                    }
                  : {
                      'pause',
                      'complete',
                      if (scenario != 'active-no-merge' &&
                          scenario != 'active-report')
                        'merge',
                      if (scenario == 'active-report') 'roll_complete'
                    };
      final mode = completed
          ? AdminQueueInteractionMode.completed
          : requeued
              ? scenario == 'requeued-ready'
                  ? AdminQueueInteractionMode.requeuedReady
                  : scenario == 'unknown-blocker'
                      ? AdminQueueInteractionMode.freshStartBlocked
                      : AdminQueueInteractionMode.requeuedWaiting
              : paused
                  ? AdminQueueInteractionMode.paused
                  : AdminQueueInteractionMode.inProgress;
      final targetControl = AdminApparatusQueueOrderActionControl(
        state: state,
        stageNodeId: 'second-apparatus',
        workActivity: activity,
        allowedActions: actions,
        hasOnlyKnownActions: true,
        closingOutputBatchId:
            scenario == 'paused-closing' ? 'closing-output' : '',
        stageWork: completed
            ? AdminStageWorkControl(
                completed: true,
                localCompleted: true,
                astatkaAvailable: true,
                astatkaRequired: scenario == 'completed-report',
                reportSessionId: 'previous-shift-session',
              )
            : null,
        rezkaOutputKadrCounts:
            scenario == 'active-report' ? const [1] : const [],
        rezkaOutputReport: scenario == 'active-report'
            ? const AdminRezkaOutputReport(cycleId: 'current-cycle', frames: [
                AdminRecordedRezkaFrame(
                    index: 1,
                    batchId: 'reported-output',
                    qrPayload: 'reported-output-qr',
                    input: {
                      'finished_goods_meter': 100,
                      'finished_goods_kg': 20,
                      'bobina_kg': 1,
                    }),
              ])
            : null,
        previousStage: _print9Id,
        previousStageReady: true,
        interaction: AdminQueueWorkerInteraction(
          mode: mode,
          startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
          materialScanRequired: false,
          assignedMaterialsDisplayOnly: true,
          materialIntakeAllowed: false,
          previousWipMode: AdminQueuePreviousWipMode.notRequired,
          qolipMode: AdminQueueQolipMode.notRequired,
          blockingReasonCode: busy
              ? 'apparatus_busy'
              : scenario == 'unknown-blocker'
                  ? 'future_server_blocking_reason'
                  : scenario == 'requeued-waiting'
                      ? 'waiting_sequence'
                      : '',
        ),
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: consumerId,
        orderId: orderId,
        control: completed ? _freshStartQueueControl() : targetControl,
      );
      Future<AdminApparatusQueueSnapshot> loadQueue() async {
        final snapshot =
            await MobileApi.instance.adminProductionMapQueueSnapshot();
        if (!completed) return snapshot;
        // Exercise the completed server projection independently of TestMode's
        // rule that keeps downstream work pending while upstream is open.
        return AdminApparatusQueueSnapshot(
          sequences: snapshot.sequences,
          sequenceVersions: snapshot.sequenceVersions,
          visibleOrderIds: snapshot.visibleOrderIds,
          queueStates: {
            ...snapshot.queueStates,
            consumerId: {...?snapshot.queueStates[consumerId], orderId: state},
          },
          queuePolicies: snapshot.queuePolicies,
          orderControls: snapshot.orderControls,
          queueActionControls: {
            ...snapshot.queueActionControls,
            consumerId: {
              ...?snapshot.queueActionControls[consumerId],
              orderId: targetControl,
            },
          },
          stageStates: snapshot.stageStates,
          maps: snapshot.maps,
          revision: snapshot.revision,
          epoch: snapshot.epoch,
        );
      }

      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'New shift',
        legalName: '',
        ref: 'new-shift-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [consumerId],
      );
      final scanInput =
          scenario.startsWith('in-use-') || scenario == 'processed-roll'
              ? firstInput
              : freshInput;
      final beforeInput =
          await MobileApi.instance.adminProgressQrLookup(scanInput.qrPayload);
      final beforeQueue =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(
          beforeInput.wipStatus,
          scenario.startsWith('in-use-')
              ? 'in_use'
              : scenario == 'processed-roll'
                  ? 'processed'
                  : 'waiting');
      expect(beforeQueue.queueStates[consumerId]?[orderId],
          completed ? 'pending' : state);
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        onGenerateRoute: (settings) {
          expect(settings.name, AppRoutes.adminProgressQrScan);
          return MaterialPageRoute<String>(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('return-guidance-qr'),
                onPressed: () => Navigator.of(context).pop(scanInput.qrPayload),
                child: const Text('Scan WIP'),
              ),
            ),
          );
        },
        home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: loadQueue,
            liveEventsLoader: () => const Stream.empty()),
      ));
      await tester.pumpAndSettle();
      final scan = tester
          .widget<AparatchiDock>(find.byType(AparatchiDock))
          .onQrScanRequested!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('return-guidance-qr')));
      await tester.pumpAndSettle();
      await scan;

      final noticeKey = switch (scenario) {
        'active-merge' => 'worker.qr.active_merge',
        'active-no-merge' => 'worker.qr.active',
        'active-report' => 'worker.qr.finish_roll_first',
        'paused-ready' => 'worker.qr.paused_resume',
        'paused-busy' => 'worker.qr.paused_waiting',
        'paused-closing' => 'worker.qr.closing_roll',
        'in-use-roll' ||
        'in-use-paused-ready' ||
        'in-use-paused-busy' =>
          'worker.qr.roll_in_use',
        'processed-roll' => 'worker.error.wip_used',
        'requeued-ready' => 'worker.qr.requeued_resume',
        'requeued-waiting' => 'worker.qr.requeued_waiting',
        'completed' => 'worker.qr.completed',
        'completed-report' => 'worker.qr.completed_report',
        'unknown-blocker' => 'worker.qr.start_unavailable',
        _ => throw StateError('Unknown state-guidance scenario: $scenario'),
      };
      expect(
        find.textContaining(l10n.productionText(noticeKey, values: {
          'apparatus': _fixtureApparatusName(consumerId),
          'order': 'Shift work',
          'action': l10n.productionText(
              scenario == 'paused-ready' || scenario == 'requeued-ready'
                  ? 'worker.action.resume'
                  : scenario == 'active-report'
                      ? 'worker.action.roll_complete'
                      : scenario == 'paused-closing'
                          ? 'worker.action.complete'
                          : 'worker.action.merge'),
        })),
        findsOneWidget,
      );
      if (scenario == 'paused-ready' || scenario == 'requeued-ready') {
        expect(
          find.textContaining(l10n.productionText('worker.qr.join_after_resume',
              values: {'action': l10n.productionText('worker.action.merge')})),
          findsOneWidget,
        );
      }
      if (scenario == 'in-use-paused-ready') {
        expect(
          find.textContaining(l10n.productionText(
              'worker.qr.resume_loaded_roll',
              values: {'action': l10n.productionText('worker.action.resume')})),
          findsOneWidget,
        );
      }
      if (scenario == 'in-use-roll') {
        expect(
          find.textContaining(l10n.productionText('worker.qr.loaded_active')),
          findsOneWidget,
        );
      }
      if (scenario == 'requeued-waiting') {
        expect(
          find.textContaining(l10n.productionText('worker.waiting.sequence')),
          findsOneWidget,
        );
      }
      if (busy) {
        expect(
          find.textContaining(l10n
              .productionText('worker.waiting.apparatus_busy_detail', values: {
            'apparatus': _fixtureApparatusName(consumerId),
            'order': 'Other active work',
          })),
          findsOneWidget,
        );
      }
      if (scenario.startsWith('in-use-') || scenario == 'active-no-merge') {
        expect(find.textContaining(l10n.productionText('worker.action.merge')),
            findsNothing,
            reason: scenario.startsWith('in-use-')
                ? 'An already mounted roll must not be advised to join again'
                : 'Join guidance must follow the server merge permission');
      }
      expect(find.text(l10n.productionText('worker.queue.action_unavailable')),
          findsNothing);
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      expect(find.byKey(const ValueKey('production-switch-order-confirm')),
          findsNothing);
      expect(
          find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
          findsNothing);

      final afterInput =
          await MobileApi.instance.adminProgressQrLookup(scanInput.qrPayload);
      final afterQueue =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
      expect(afterInput.wipStatus, beforeInput.wipStatus,
          reason:
              'A guidance notice must not consume, merge, or restart a roll');
      expect(afterInput.usedBySessionId, beforeInput.usedBySessionId);
      expect(afterQueue.queueStates, beforeQueue.queueStates,
          reason: 'A scan must not start, resume, pause, or finish any order');
      expect(afterQueue.queueActionControls[consumerId]?[orderId]?.workActivity,
          activity,
          reason:
              'A new shift scan must not change the previous shift session owner');
      dismissAdminTopNotice();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
