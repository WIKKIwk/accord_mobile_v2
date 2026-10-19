part of 'admin_production_map_test_screen_test.dart';

void _registerLaminationAstatkaScopeTests() {
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
        await tester.pumpAndSettle();
        if (find.text('Laminatsiya 1').evaluate().isNotEmpty) {
          await tester.tap(find.text('Laminatsiya 1'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
        await tester.pumpAndSettle();
        await TestModeController.instance.setEnabled(false);
        await tester.ensureVisible(find.text('Tugatish'));
        await tester.tap(find.text('Tugatish'));
        final countField =
            find.widgetWithText(TextFormField, 'Bosmadan ortgan rulon');
        await waitForSnapshotUi(
            tester,
            scenario.optional
                ? countField
                : find.text(AppLocalizations(const Locale('uz'))
                    .productionText('worker.lamination_astatka.sources_missing')));
        await tester.pumpAndSettle();
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
          await tester.pumpAndSettle();
          expect(submissions, hasLength(1));
          expect(submissions.single['action'], 'complete');
          expect(submissions.single['layer_remainders'], isEmpty);
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
        await tester.pumpAndSettle();
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
                        }),
                        200);
                  }
                  submissions.add((jsonDecode(request.body) as Map)
                      .cast<String, dynamic>());
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
      astatka: false,
      full: false,
      paused: false
    ),
    (
      name: 'general order completion',
      astatka: false,
      full: true,
      paused: false
    ),
    (
      name: 'active order long press Astatka',
      astatka: true,
      full: false,
      paused: false
    ),
    (
      name: 'paused order long press Astatka',
      astatka: true,
      full: false,
      paused: true
    ),
  ]) {
    testWidgets('lamination layer fields scope: ${scenario.name}',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
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
      final apparatusCatalog =
          await MobileApi.instance.adminApparatus(limit: 200);
      final printedRollName = 'Bosmadan kelgan PET, apparat: '
          '${apparatusCatalog.singleWhere((item) => item.id == _print8Id).name}, ish tugatildi';
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
        await tester.pumpAndSettle();
        if (find.text('Laminatsiya 1').evaluate().isNotEmpty) {
          await tester.tap(find.text('Laminatsiya 1'));
        }
        await tester.pumpAndSettle();
        final order = find.byKey(const ValueKey('worker-order-$id'));
        if (scenario.astatka) {
          await tester.longPress(order);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(
              FilledButton, 'Astatka hisobotini topshirish'));
        } else {
          await tester.tap(order);
          await tester.pumpAndSettle();
          await TestModeController.instance.setEnabled(false);
          final finish = find.text('Tugatish');
          await tester.ensureVisible(finish);
          await tester.tap(finish);
          if (scenario.full) {
            await waitForSnapshotUi(tester, find.text('Qavat astatkasi'));
          }
        }
        await tester.pumpAndSettle();
        final hasLayers = scenario.astatka || scenario.full;
        if (hasLayers) {
          for (var index = 0;
              index < 30 && find.text('Qavat astatkasi').evaluate().isEmpty;
              index++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        expect(snapshotReads, hasLayers ? 1 : 0);
        expect(find.text('Qavat astatkasi'),
            hasLayers ? findsOneWidget : findsNothing);
        expect(find.text(printedRollName),
            hasLayers ? findsOneWidget : findsNothing);
        expect(find.text('Ulangan CPP'),
            hasLayers ? findsOneWidget : findsNothing);
        expect(find.textContaining('Oxirgi tayyor rulon'), findsNothing);
        expect(find.textContaining('Buyurtmani umumiy tugatish hisoboti'),
            findsNothing);
        expect(find.textContaining('apparatus:'), findsNothing);
        if (hasLayers) {
          expect(find.text('Qoldiqning sof og‘irligi'), findsNWidgets(2));
          final kg = find.descendant(
              of: find.ancestor(
                  of: find.text(printedRollName), matching: find.byType(Card)),
              matching: find.byType(TextFormField));
          await tester.ensureVisible(kg);
          await tester.enterText(kg, '20');
          await tester.pump();
          expect(find.text('Taxminiy metraj: ≈ 600 m'), findsOneWidget);
        }
        expect(writes, isEmpty);
        await tester.tap(find.text('Bekor qilish'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.method != 'GET') writes.add(request);
                if (request.url.path.endsWith('/laminatsiya-astatka')) {
                  snapshotReads++;
                  return http.Response(
                      jsonEncode({
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
