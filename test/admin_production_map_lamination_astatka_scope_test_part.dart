part of 'admin_production_map_test_screen_test.dart';

void _registerLaminationAstatkaScopeTests() {
  _registerLaminationLabelPolicyTests();
  Future<void> pumpUi(WidgetTester tester) async {
    // The disconnected-live indicator animates continuously in this fixture.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> waitForSnapshotUi(WidgetTester tester, Finder target) async {
    for (var attempt = 0;
        attempt < 100 && target.evaluate().isEmpty;
        attempt++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(target, findsOneWidget);
  }

  for (final scenario in [
    (optional: true, quantity: '0'),
    (optional: true, quantity: '2'),
    (optional: false, quantity: '0'),
  ]) {
    testWidgets('lamination empty layers follows material policy: $scenario',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      // This fixture has no previous account whose runtime state needs flushing.
      AppSession.instance.profile = null;
      await AppSession.instance.setSession(
        token: 'optional-lamination-worker',
        profile: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Laminator',
          legalName: '',
          ref: 'optional-lamination-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_lamination1Id],
        ),
      );
      const orderId = 'zakaz-optional-material-lamination';
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        title: 'Optional materials',
        productCode: 'FILM',
        product: 'FILM',
        orderNumber: '0335',
        apparatusId: _lamination1Id,
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _lamination1Id, orderIds: [orderId]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _lamination1Id, orderId: orderId, action: 'start');
      setMobileApiTestModeQueueActionControlFixture(
          apparatus: _lamination1Id,
          orderId: orderId,
          control: _inProgressQueueControl(completeRequiresFullReport: true));
      final queueSnapshot =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
      final submissions = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
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
          home: AdminProductionMapOrdersScreen(
              readOnly: true,
              workerMode: true,
              queueSnapshotLoader: () async => queueSnapshot,
              progressDriverUrlPicker: (_) async => 'http://printer.test',
              liveEventsLoader: () => const Stream.empty()),
        ));
        await pumpUi(tester);
        if (find.text('Laminatsiya 1').evaluate().isNotEmpty) {
          await tester.tap(find.text('Laminatsiya 1'));
          await pumpUi(tester);
        }
        await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
        await pumpUi(tester);
        await TestModeController.instance.setEnabled(false);
        await tester.ensureVisible(find.text('Tugatish'));
        await tester.tap(find.text('Tugatish'));
        final countField =
            find.widgetWithText(TextFormField, 'Bosmadan ortgan rulon');
        await waitForSnapshotUi(
            tester,
            scenario.optional
                ? countField
                : find.text(AppLocalizations(const Locale('uz')).productionText(
                    'worker.lamination_astatka.sources_missing')));
        await pumpUi(tester);
        expect(find.text('Qavat astatkasi'), findsNothing);
        if (scenario.optional) {
          expect(countField, findsOneWidget);
          final l10n = AppLocalizations(const Locale('uz'));
          for (final entry in {
            'worker.daily.field.roll': '1',
            'worker.daily.field.print_leftover': scenario.quantity,
            'worker.daily.field.film_leftover': scenario.quantity,
            'worker.daily.field.total_waste': scenario.quantity,
            'worker.daily.field.length': '100',
            'worker.daily.field.weight': '10',
          }.entries) {
            final field = find.widgetWithText(
                TextFormField, l10n.productionText(entry.key));
            await tester.ensureVisible(field);
            await tester.enterText(field, entry.value);
          }
          await tester.ensureVisible(find.text('Tasdiqlash'));
          await tester.tap(find.text('Tasdiqlash'));
          await pumpUi(tester);
          expect(submissions, hasLength(1));
          expect(submissions.single['action'], 'complete');
          expect(submissions.single, isNot(contains('layer_remainders')));
          expect(submissions.single['layer_remainder_weights'], {
            'wip_net_kg': double.parse(scenario.quantity),
            'film_net_kg': double.parse(scenario.quantity),
            'expected_sources': [],
          });
          expect(submissions.single['lamination_print_leftover_rolls'],
              double.parse(scenario.quantity));
          expect(submissions.single['lamination_film_leftover_rolls'],
              double.parse(scenario.quantity));
          expect(submissions.single['total_waste'],
              double.parse(scenario.quantity));
          expect(submissions.single['session_id'], 'existing-0335-session');
          expect(submissions.single['request_id'], isNotEmpty);
        } else {
          expect(countField, findsNothing);
          expect(submissions, isEmpty);
          expect(
              find.text(AppLocalizations(const Locale('uz'))
                  .productionText('worker.lamination_astatka.sources_missing')),
              findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUi(tester);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/laminatsiya-astatka')) {
                  if (request.method == 'GET') {
                    return http.Response(
                        jsonEncode({
                          'session': {
                            'session_id': 'existing-0335-session',
                            'status': 'active'
                          },
                          'sources': [],
                          'allow_empty_sources': scenario.optional,
                          'remainder_weights_supported': true,
                        }),
                        200);
                  }
                  submissions.add((jsonDecode(request.body) as Map)
                      .cast<String, dynamic>());
                  if (scenario.quantity != '0') {
                    return http.Response(
                        jsonEncode({
                          'error': 'lamination_remainder_source_missing',
                        }),
                        409);
                  }
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'action': 'complete',
                        'session': {
                          'session_id': 'existing-0335-session',
                          'status': 'completed'
                        },
                        'progress_batches': [],
                        'remainders': [],
                        'prints': [],
                      }),
                      200);
                }
                return http.Response('{}', 200);
              }));
    });
  }
  for (final scenario in [
    (
      name: 'individual WIP completion',
      required: true,
      astatka: false,
      full: false,
      paused: false
    ),
    (
      name: 'general order completion',
      required: true,
      astatka: false,
      full: true,
      paused: false
    ),
    (
      name: 'active order long press Astatka',
      required: true,
      astatka: true,
      full: false,
      paused: false
    ),
    (
      name: 'paused order long press Astatka',
      required: true,
      astatka: true,
      full: false,
      paused: true
    ),
    (
      name: 'QR disabled general order completion',
      required: false,
      astatka: false,
      full: true,
      paused: false
    ),
    (
      name: 'QR disabled active order Astatka',
      required: false,
      astatka: true,
      full: false,
      paused: false
    ),
    (
      name: 'QR disabled paused order Astatka',
      required: false,
      astatka: true,
      full: false,
      paused: true
    ),
  ]) {
    testWidgets('lamination layer fields scope: ${scenario.name}',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = null;
      await AppSession.instance.setSession(
        token: 'lamination-scope-worker',
        profile: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Laminator',
          legalName: '',
          ref: 'lamination-scope-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_lamination1Id],
        ),
      );
      const id = 'zakaz-lamination-astatka-scope';
      final saved =
          await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: id,
        title: 'Lamination scope',
        productCode: 'SCOPE',
        product: 'SCOPE',
        orderNumber: '0054',
        apparatusId: _lamination1Id,
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _lamination1Id, orderIds: const [id]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _lamination1Id, orderId: id, action: 'start');
      if (scenario.paused) {
        await MobileApi.instance.adminApparatusQueueActionResult(
            apparatus: _lamination1Id,
            orderId: id,
            action: 'pause',
            producedQty: 50,
            grossQty: 10,
            uom: 'm');
      }
      final control = scenario.paused
          ? const AdminApparatusQueueOrderActionControl(
              state: 'paused',
              stageWork: AdminStageWorkControl(
                  astatkaAvailable: true, astatkaRequired: true),
              allowedActions: {'resume'},
              hasOnlyKnownActions: true,
              interaction: AdminQueueWorkerInteraction(
                mode: AdminQueueInteractionMode.paused,
                startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
                materialScanRequired: false,
                assignedMaterialsDisplayOnly: true,
                materialIntakeAllowed: false,
                previousWipMode: AdminQueuePreviousWipMode.notRequired,
                qolipMode: AdminQueueQolipMode.notRequired,
              ),
            )
          : _inProgressQueueControl(completeRequiresFullReport: scenario.full);
      setMobileApiTestModeQueueActionControlFixture(
          apparatus: _lamination1Id, orderId: id, control: control);
      final snapshot =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
      final pausedSnapshot = AdminApparatusQueueSnapshot(
        maps: [saved],
        sequences: {
          _lamination1Id: [id]
        },
        visibleOrderIds: {
          _lamination1Id: [id]
        },
        queueStates: {
          _lamination1Id: {id: 'paused'}
        },
        queuePolicies: snapshot.queuePolicies,
        orderControls: snapshot.orderControls,
        queueActionControls: {
          _lamination1Id: {id: control}
        },
      );
      var snapshotReads = 0;
      final writes = <http.Request>[];
      await http.runWithClient(() async {
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
          home: AdminProductionMapOrdersScreen(
              readOnly: true,
              workerMode: true,
              queueSnapshotLoader: () async =>
                  scenario.paused ? pausedSnapshot : snapshot,
              liveEventsLoader: () => const Stream.empty()),
        ));
        await pumpUi(tester);
        if (find.text('Laminatsiya 1').evaluate().isNotEmpty) {
          await tester.tap(find.text('Laminatsiya 1'));
        }
        await pumpUi(tester);
        final order = find.byKey(const ValueKey('worker-order-$id'));
        if (scenario.astatka) {
          await tester.longPress(order);
          await pumpUi(tester);
          await tester.tap(find.widgetWithText(
              FilledButton, 'Astatka hisobotini topshirish'));
        } else {
          await tester.tap(order);
          await pumpUi(tester);
          await TestModeController.instance.setEnabled(false);
          final finish = find.text('Tugatish');
          await tester.ensureVisible(finish);
          await tester.tap(finish);
          if (scenario.full) {
            await waitForSnapshotUi(tester,
                find.widgetWithText(TextFormField, 'Bosmadan ortgan rulon'));
          }
        }
        await pumpUi(tester);
        final needsSnapshot = scenario.astatka || scenario.full;
        if (needsSnapshot) {
          await waitForSnapshotUi(tester,
              find.widgetWithText(TextFormField, 'Bosmadan ortgan rulon'));
          expect(find.widgetWithText(TextFormField, 'Plyonkadan ortgan rulon'),
              findsOneWidget);
          expect(find.text('Qoldiqning sof og‘irligi'), findsNothing);
          expect(
              find.widgetWithText(
                  TextFormField,
                  AppLocalizations(const Locale('uz'))
                      .productionText('worker.daily.field.total_waste')),
              findsOneWidget);
        }
        expect(snapshotReads, needsSnapshot ? 1 : 0);
        expect(find.text('Qavat astatkasi'), findsNothing);
        expect(find.text('Ulangan CPP'), findsNothing);
        expect(find.textContaining('Oxirgi tayyor rulon'), findsNothing);
        expect(find.textContaining('Buyurtmani umumiy tugatish hisoboti'),
            findsNothing);
        expect(find.textContaining('apparatus:'), findsNothing);
        expect(find.text('Qoldiqning sof og‘irligi'), findsNothing);
        if (needsSnapshot) {
          for (final label in [
            'Bosmadan ortgan rulon',
            'Plyonkadan ortgan rulon'
          ]) {
            expect(
                find.descendant(
                  of: find.widgetWithText(TextFormField, label),
                  matching: find.text('kg'),
                ),
                findsOneWidget);
          }
        }
        expect(writes, isEmpty);
        await tester.tap(find.text('Bekor qilish'));
        await pumpUi(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUi(tester);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.method != 'GET') writes.add(request);
                if (request.url.path.endsWith('/laminatsiya-astatka')) {
                  snapshotReads++;
                  return http.Response(
                      jsonEncode({
                        'layer_remainders_required': scenario.required,
                        'remainder_weights_supported': true,
                        'label_settings': {
                          'print_wip_remainder_labels': scenario.required,
                          'print_film_remainder_labels': !scenario.required,
                        },
                        'session': {
                          'session_id': 'lamination-current',
                          'status': scenario.paused ? 'paused' : 'active'
                        },
                        'sources': [
                          for (final kind in ['progress_batch', 'raw_material'])
                            {
                              'source_kind': kind,
                              'source_id': kind,
                              'session_id': 'lamination-current',
                              'revision': 1,
                              'qr_payload': '$kind-qr',
                              'item_code': kind,
                              'item_name': kind == 'progress_batch'
                                  ? 'Bosmadan kelgan PET, apparat: $_print8Id, ish tugatildi'
                                  : 'Ulangan CPP',
                              'source_net_kg': 50,
                              'source_meter': 1500,
                              'tare_kg': 2,
                              'producer_name': kind == 'progress_batch'
                                  ? 'Bosmachi'
                                  : 'Ta’minotchi',
                            },
                        ],
                      }),
                      200,
                      headers: {
                        'content-type': 'application/json; charset=utf-8'
                      });
                }
                return http.Response('{}', 200);
              }));
    });
  }
}

void _registerLaminationLabelPolicyTests() {
  for (final scenario in [
    (
      wip: false,
      film: false,
      cancel: false,
      zero: false,
      fail: false,
      recovered: false
    ),
    (
      wip: true,
      film: false,
      cancel: false,
      zero: false,
      fail: false,
      recovered: false
    ),
    (
      wip: false,
      film: true,
      cancel: false,
      zero: false,
      fail: false,
      recovered: false
    ),
    (
      wip: true,
      film: true,
      cancel: false,
      zero: false,
      fail: false,
      recovered: false
    ),
    (
      wip: true,
      film: true,
      cancel: true,
      zero: false,
      fail: false,
      recovered: false
    ),
    (
      wip: true,
      film: true,
      cancel: false,
      zero: true,
      fail: false,
      recovered: false
    ),
    (
      wip: true,
      film: true,
      cancel: false,
      zero: false,
      fail: true,
      recovered: false
    ),
    (
      wip: true,
      film: true,
      cancel: false,
      zero: false,
      fail: false,
      recovered: true
    ),
  ]) {
    testWidgets('lamination label policy saves before printing: $scenario',
        (tester) async {
      Future<void> pumpUi() async {
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = null;
      await AppSession.instance.setSession(
        token: 'lamination-label-worker',
        profile: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Laminator',
          legalName: '',
          ref: 'lamination-label-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_lamination1Id],
        ),
      );
      const orderId = 'zakaz-lamination-label-policy';
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        title: 'Label policy',
        productCode: 'PET',
        product: 'PET',
        orderNumber: '0088',
        apparatusId: _lamination1Id,
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _lamination1Id, orderIds: [orderId]);
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _lamination1Id, orderId: orderId, action: 'start');
      setMobileApiTestModeQueueActionControlFixture(
          apparatus: _lamination1Id,
          orderId: orderId,
          control: _inProgressQueueControl(completeRequiresFullReport: true));
      final queue = await MobileApi.instance.adminProductionMapQueueSnapshot();
      final settings = {
        'print_wip_remainder_labels': scenario.wip,
        'print_film_remainder_labels': scenario.film,
      };
      final remainders = [
        for (final kind in ['progress_batch', 'raw_material'])
          {
            'operation_id': 'saved-$kind',
            'source_kind': kind,
            'source_id': 'original-$kind',
            'qr_payload': 'saved-$kind-qr',
            'remaining_net_kg': scenario.zero ? 0 : 20.125,
            'remaining_meter': scenario.zero ? 0 : 603.75,
            'producer_name': 'Original $kind',
          },
      ];
      final printable = [
        for (final r in remainders)
          if (!scenario.zero &&
              (r['source_kind'] == 'progress_batch'
                  ? scenario.wip
                  : scenario.film))
            r,
      ];
      final submissions = <Map<String, dynamic>>[];
      final reprints = <String>[];
      var printerPicks = 0;
      await http.runWithClient(() async {
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
          home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: () async => queue,
            liveEventsLoader: () => const Stream.empty(),
            progressDriverUrlPicker: (_) async {
              expect(submissions, hasLength(1));
              printerPicks++;
              return scenario.cancel ? null : 'http://printer.test';
            },
          ),
        ));
        await pumpUi();
        if (find.text('Laminatsiya 1').evaluate().isNotEmpty) {
          await tester.tap(find.text('Laminatsiya 1'));
          await pumpUi();
        }
        await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
        await pumpUi();
        await TestModeController.instance.setEnabled(false);
        final preferences = await SharedPreferences.getInstance();
        final pendingKey =
            'lamination_complete_pending:lamination-label-worker:$_lamination1Id:$orderId';
        if (scenario.recovered) {
          await preferences.setString(
              pendingKey, jsonEncode({'request_id': 'lost-response'}));
        }
        await tester.ensureVisible(find.text('Tugatish'));
        await tester.tap(find.text('Tugatish'));
        if (scenario.recovered) {
          for (var i = 0;
              i < 20 &&
                  find.byType(LaminationLayerRemainderSheet).evaluate().isEmpty;
              i++) {
            await pumpUi();
          }
          final receipt = tester.widget<LaminationLayerRemainderSheet>(
              find.byType(LaminationLayerRemainderSheet));
          expect(receipt.initialResult!.remainders, hasLength(2));
          expect(receipt.printPending, isTrue);
          expect(submissions, isEmpty);
          expect(reprints, isEmpty);
          expect(printerPicks, 0);
          expect(preferences.containsKey(pendingKey), isFalse);
          await tester.pumpWidget(const SizedBox.shrink());
          await pumpUi();
          expect(tester.takeException(), isNull);
          return;
        }
        final first =
            find.widgetWithText(TextFormField, 'Bosmadan ortgan rulon');
        for (var i = 0; i < 50 && first.evaluate().isEmpty; i++) {
          await pumpUi();
        }
        expect(first, findsOneWidget);
        expect(find.text('Qavat astatkasi'), findsNothing);
        final l10n = AppLocalizations(const Locale('uz'));
        for (final entry in {
          'worker.daily.field.roll': '1',
          'worker.daily.field.print_leftover': scenario.zero ? '0' : '20.125',
          'worker.daily.field.film_leftover': scenario.zero ? '0' : '20.125',
          'worker.daily.field.total_waste': '0',
          'worker.daily.field.length': '100',
          'worker.daily.field.weight': '10',
        }.entries) {
          final field = find.widgetWithText(
              TextFormField, l10n.productionText(entry.key));
          await tester.ensureVisible(field);
          await tester.enterText(field, entry.value);
        }
        await tester.ensureVisible(find.text('Tasdiqlash'));
        await tester.tap(find.text('Tasdiqlash'));
        for (var i = 0;
            i < 20 &&
                find.byType(LaminationLayerRemainderSheet).evaluate().isEmpty;
            i++) {
          await pumpUi();
        }
        expect(find.byType(LaminationLayerRemainderSheet), findsOneWidget);
        expect(submissions, hasLength(1));
        expect(submissions.single['print_transport'], 'offline');
        expect(submissions.single['layer_remainder_weights'], {
          'wip_net_kg': scenario.zero ? 0 : 20.125,
          'film_net_kg': scenario.zero ? 0 : 20.125,
          'wip_source_id': 'original-progress_batch',
          'film_source_id': 'original-raw_material',
          'expected_sources': [
            for (final kind in ['progress_batch', 'raw_material'])
              {
                'source_kind': kind,
                'source_id': 'original-$kind',
                'expected_revision': 7,
              },
            {
              'source_kind': 'raw_material',
              'source_id': 'z-previous-film',
              'expected_revision': 3,
            },
          ],
        });
        expect(printerPicks, printable.isEmpty ? 0 : 1);
        expect(
            reprints,
            scenario.cancel
                ? isEmpty
                : printable.map((r) => r['operation_id']).toList());
        final receipt = tester.widget<LaminationLayerRemainderSheet>(
            find.byType(LaminationLayerRemainderSheet));
        expect(receipt.initialResult!.remainders, hasLength(2));
        expect(receipt.printPending, scenario.cancel && printable.isNotEmpty);
        expect(receipt.printFailed, scenario.fail && printable.isNotEmpty);
        expect(
            preferences
                .getKeys()
                .where((key) => key.startsWith('lamination_complete_pending:')),
            isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUi();
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/laminatsiya-astatka')) {
                  if (request.method == 'GET') {
                    if (scenario.recovered) {
                      expect(request.url.queryParameters['request_id'],
                          'lost-response');
                      return http.Response(
                          jsonEncode({
                            'remainder_weights_supported': true,
                            'sources': [],
                            'request_result': {
                              'ok': true,
                              'action': 'complete',
                              'label_settings': settings,
                              'session': {
                                'session_id': 'label-policy-session',
                                'status': 'completed'
                              },
                              'remainders': remainders,
                              'progress_batches': [],
                            },
                          }),
                          200);
                    }
                    return http.Response(
                        jsonEncode({
                          'remainder_weights_supported': true,
                          'label_settings': settings,
                          'session': {
                            'session_id': 'label-policy-session',
                            'status': 'active'
                          },
                          'sources': [
                            for (final kind in [
                              'progress_batch',
                              'raw_material'
                            ])
                              {
                                'source_kind': kind,
                                'source_id': 'original-$kind',
                                'is_current_roll': true,
                                'session_id': 'label-policy-session',
                                'revision': 7,
                                'source_net_kg': 50,
                                'source_meter': 1500,
                                'tare_kg': 2,
                              },
                            {
                              'source_kind': 'raw_material',
                              'source_id': 'z-previous-film',
                              'session_id': 'label-policy-session',
                              'revision': 3,
                              'source_net_kg': 25,
                              'source_meter': 750,
                            },
                          ],
                        }),
                        200);
                  }
                  submissions.add((jsonDecode(request.body) as Map)
                      .cast<String, dynamic>());
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'action': 'complete',
                        'label_settings': settings,
                        'session': {
                          'session_id': 'label-policy-session',
                          'status': 'completed'
                        },
                        'remainders': remainders,
                        'progress_batches': [],
                        'prints': [
                          for (final r in printable)
                            {'ok': true, 'qr_payload': r['qr_payload']}
                        ],
                      }),
                      200);
                }
                if (request.url.path.endsWith('/layer-remainders/reprint')) {
                  final operationId = (jsonDecode(request.body)
                      as Map)['operation_id'] as String;
                  reprints.add(operationId);
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'remainder': remainders.singleWhere(
                            (r) => r['operation_id'] == operationId),
                        'print': {
                          'ok': !scenario.fail,
                          'status': scenario.fail ? 'print_failed' : 'printed'
                        },
                      }),
                      200);
                }
                if (request.url.path.endsWith('/layer-remainders')) {
                  return http.Response(
                      jsonEncode({'sources': [], 'remainders': remainders}),
                      200);
                }
                return http.Response('{}', 200);
              }));
    });
  }
}
