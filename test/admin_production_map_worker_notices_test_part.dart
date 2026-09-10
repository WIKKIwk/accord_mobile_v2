part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerNoticeTests() {
  final l10n = AppLocalizations(const Locale('uz'));

  for (final scenario in ['missing', 'reported', 'upstream-open']) {
    testWidgets('stage astatka notification: $scenario', (tester) async {
      await TestModeController.instance.setEnabled(true);
      const orderId = 'zakaz-stage-report';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi, displayName: 'Bosmachi', legalName: '',
        ref: 'stage-worker', phone: '', avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print7Id],
      );
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId, title: 'Shared order', productCode: 'SHARED',
        apparatusId: _print7Id, product: 'Shared product',
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(apparatus: _print7Id, orderIds: const [orderId]);
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _print7Id, orderId: orderId,
        control: AdminApparatusQueueOrderActionControl(
          state: 'pending', allowedActions: const {}, hasOnlyKnownActions: true,
          interaction: _requeuedQueueControl(ready: false).interaction,
          stageWork: AdminStageWorkControl(
            upstreamClosed: scenario != 'upstream-open',
            astatkaAvailable: true, astatkaRequired: scenario == 'missing',
            reportSessionId: 'finished-run', upstreamTitle: 'Extruder 1',
          ),
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(readOnly: true, workerMode: true),
      ));
      await tester.pumpAndSettle();
      final title = l10n.productionText('worker.stage.astatka.title');
      expect(find.text(title), scenario == 'missing' ? findsOneWidget : findsNothing);
      if (scenario == 'missing') {
        expect(find.textContaining('Extruder 1'), findsOneWidget);
        expect(find.textContaining('7 ta rangli bosma aparat'), findsWidgets);
        await tester.tap(find.text(l10n.productionText('worker.stage.astatka.later')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('7 ta rangli bosma aparat'));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('worker-order-$orderId')));
      await tester.pumpAndSettle();
      // A finished local execution can report while its scheduling state is
      // pending, including when upstream has not closed yet.
      expect(find.text('Astatka hisobotini topshirish'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Jami chiqindi'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  AdminApparatusQueueOrderActionControl control({
    String state = 'pending',
    AdminQueueInteractionMode mode =
        AdminQueueInteractionMode.freshStartBlocked,
    Set<String> actions = const {},
    String reason = '',
    String closingBatch = '',
    bool previousWaiting = false,
    bool openingWaiting = false,
  }) =>
      AdminApparatusQueueOrderActionControl(
        state: state,
        allowedActions: actions,
        hasOnlyKnownActions: true,
        closingOutputBatchId: closingBatch,
        previousStage: previousWaiting ? _print8Id : '',
        interaction: AdminQueueWorkerInteraction(
          mode: mode,
          startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
          materialScanRequired: false,
          assignedMaterialsDisplayOnly: true,
          materialIntakeAllowed: false,
          previousWipMode: previousWaiting
              ? AdminQueuePreviousWipMode.waiting
              : AdminQueuePreviousWipMode.notRequired,
          openingWipMode: openingWaiting
              ? AdminQueuePreviousWipMode.waiting
              : AdminQueuePreviousWipMode.notRequired,
          qolipMode: AdminQueueQolipMode.notRequired,
          blockingReasonCode: reason,
        ),
      );

  void register(
    String name,
    AdminApparatusQueueOrderActionControl fixture, {
    String? messageKey,
    String? expectedText,
    bool syncWarning = false,
    bool omitControl = false,
  }) {
    testWidgets('worker notices: $name', (tester) async {
      await TestModeController.instance.setEnabled(true);
      const orderId = 'zakaz-worker-notice';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'worker-notice',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print7Id],
      );
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        title: 'Worker notice',
        productCode: 'NOTICE',
        apparatusId: _print7Id,
        product: 'Notice product',
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _print7Id,
        orderIds: const [orderId],
      );
      final state = fixture.state;
      if (state == 'paused' || state == 'in_progress') {
        await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print7Id,
          orderId: orderId,
          action: 'start',
        );
      }
      if (state == 'paused') {
        await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print7Id,
          orderId: orderId,
          action: 'pause',
          producedQty: 80,
          finishedGoodsMeter: 80,
          finishedGoodsKg: 12,
          bobinaKg: 1,
          uom: 'm',
        );
      }
      if (!omitControl) {
        setMobileApiTestModeQueueActionControlFixture(
          apparatus: _print7Id,
          orderId: orderId,
          control: fixture,
        );
      }
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 ta rangli bosma aparat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      await tester.pumpAndSettle();

      final card = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OrderStartUnifiedCard',
      );
      expect(card, findsOneWidget);
      Finder textInCard(String text) =>
          find.descendant(of: card, matching: find.text(text));
      expect(
        textInCard(l10n.productionText('worker.error.sync')),
        syncWarning ? findsOneWidget : findsNothing,
      );
      if (messageKey != null || expectedText != null) {
        expect(
          textInCard(expectedText ?? l10n.productionText(messageKey!)),
          findsOneWidget,
        );
      }
      for (final action in ['start', 'resume', 'complete']) {
        final button = find.descendant(
          of: card,
          matching: find.widgetWithText(
            FilledButton,
            l10n.productionText('worker.action.$action'),
          ),
        );
        final allowed = !syncWarning && fixture.allows(action);
        expect(button, allowed ? findsOneWidget : findsNothing);
        if (allowed) {
          expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        }
      }
      if (messageKey == null && expectedText == null && !syncWarning) {
        expect(
          textInCard(l10n.productionText('worker.queue.action_unavailable')),
          findsNothing,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  register('ready to start has no warning', _freshStartQueueControl());
  register('requeued ready has no warning', _requeuedQueueControl(ready: true));
  register('running has no warning', _inProgressQueueControl());
  register(
    'paused resume has no warning',
    control(
        state: 'paused',
        mode: AdminQueueInteractionMode.paused,
        actions: const {'resume'}),
  );
  register(
    'paused closing keeps complete and resume without warning',
    control(
        state: 'paused',
        mode: AdminQueueInteractionMode.paused,
        actions: const {'resume', 'complete'},
        closingBatch: 'closing-output'),
  );
  register(
    'busy paused order keeps closing but cannot resume',
    control(
        state: 'paused',
        mode: AdminQueueInteractionMode.paused,
        actions: const {'complete'},
        closingBatch: 'closing-output',
        reason: 'apparatus_busy'),
    messageKey: 'worker.waiting.apparatus_busy',
  );
  for (final mode in [
    AdminQueueInteractionMode.freshStartBlocked,
    AdminQueueInteractionMode.requeuedWaiting
  ]) {
    register('$mode explains busy machine',
        control(mode: mode, reason: 'apparatus_busy'),
        messageKey: 'worker.waiting.apparatus_busy');
  }
  register('missing previous stage explains configuration problem',
      control(reason: 'previous_stage_not_configured'),
      messageKey: 'worker.error.previous_stage_not_configured');
  register('missing materials explains material requirement',
      control(reason: 'raw_material_assignment_required'),
      messageKey: 'worker.error.incomplete_material_groups');
  register('unknown blocking code does not invent a sync error',
      control(reason: 'future_server_blocking_reason'),
      messageKey: 'worker.queue.action_unavailable');
  register('queue wait shows one accurate notice',
      _requeuedQueueControl(ready: false),
      messageKey: 'worker.waiting.sequence');
  register(
      'previous stage wait shows one accurate notice',
      control(
          mode: AdminQueueInteractionMode.waitingPreviousStage,
          reason: 'waiting_previous_stage',
          previousWaiting: true),
      expectedText:
          'Oldingi bosqich tugallanguncha kutilmoqda: 8 ta rangli bosma aparat');
  register(
      'opening WIP wait is explained without a previous stage',
      control(
          mode: AdminQueueInteractionMode.waitingPreviousStage,
          reason: 'waiting_opening_wip',
          openingWaiting: true),
      messageKey: 'worker.waiting.opening_wip');
  // Malformed snapshots are rejected before the order can open. A missing
  // per-order contract can reach this card and must still fail closed.
  register(
      'missing contract still blocks actions with sync warning',
      _freshStartQueueControl(),
      omitControl: true,
      syncWarning: true);
}
