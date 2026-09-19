part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerMapWipTests() {
  const orderId = 'zakaz-worker-map-wip';
  final l10n = AppLocalizations(const Locale('uz'));

  for (final scenario in ['own', 'lamination', 'denied', 'retry']) {
    testWidgets('worker map WIP read-only history: $scenario', (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Print worker',
        legalName: '',
        ref: 'map-wip-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print7Id],
      );
      await MobileApi.instance
          .adminSaveProductionMap(_twoStageProductionOrderMap(
        id: orderId,
        title: 'Map WIP order',
        productCode: 'MAP-WIP',
        product: 'Map WIP product',
        firstApparatusId: _print7Id,
        secondApparatusId: _lamination1Id,
      ).copyWith(orderNumber: '0004', baseLength: 1000, orderKg: 90));
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _print7Id,
        orderIds: const [orderId],
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _print7Id,
        orderId: orderId,
        action: 'start',
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _print7Id,
        orderId: orderId,
        action: 'complete',
        producedQty: 15,
        grossQty: 9,
        uom: 'm',
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _print7Id,
        orderId: orderId,
        control: _completedQueueControl(),
      );
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
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tugallangan'));
      await tester.tap(find.text('Tugallangan'));
      await tester.pumpAndSettle();
      await tester.tap(find
          .ancestor(
            of: find.textContaining('Map WIP order'),
            matching: find.byType(InkWell),
          )
          .first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kutilayotgan natija'));
      await tester.pumpAndSettle();

      final source = scenario == 'own' ? _print7Id : _lamination1Id;
      final node = find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.text(_fixtureApparatusName(source)),
          )
          .last;
      await tester.ensureVisible(node);
      await tester.pumpAndSettle();
      await TestModeController.instance.setEnabled(false);
      final requests = <http.Request>[];
      var attempts = 0;
      await http.runWithClient(() async {
        await tester.tap(node);
        await tester.pumpAndSettle();
        if (scenario == 'retry') {
          expect(find.text(l10n.productionText('worker.wip.history.error')),
              findsOneWidget);
          await tester.tap(find.text('Qayta urinish').last);
          await tester.pumpAndSettle();
        }
        if (scenario == 'denied') {
          expect(find.text(l10n.productionText('worker.wip.access_denied')),
              findsOneWidget);
          expect(find.text(l10n.productionText('worker.wip.history.empty')),
              findsNothing);
        } else {
          expect(find.text('1 ta WIP yaratilgan'), findsOneWidget);
          expect(
              find.text(scenario == 'own' ? '15 m' : '12 m'), findsOneWidget);
          await tester.tap(find.byKey(const ValueKey('worker-wip-item-0')));
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('worker-wip-history-preview-$source')),
              findsOneWidget);
          expect(find.text('Qayta chop etish'), findsNothing);
          expect(find.byKey(ValueKey('worker-wip-history-reprint-$source')),
              findsNothing);
        }
        expect(requests, hasLength(scenario == 'retry' ? 4 : 2));
        expect(requests.every((r) => r.method == 'GET'), isTrue);
        expect(
            requests.every((r) => r.url.queryParameters['order_id'] == orderId),
            isTrue);
        expect(requests.every((r) => r.url.queryParameters['status'] == 'all'),
            isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
          () => MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('/opening-wip')) {
                  return http.Response('{"records":[]}', 200);
                }
                if (!request.url.path.endsWith('/wip-batches')) {
                  return http.Response('{"error":"forbidden"}', 403);
                }
                attempts++;
                if (scenario == 'denied') {
                  return http.Response('{"error":"forbidden"}', 403);
                }
                if (scenario == 'retry' && attempts == 1) {
                  return http.Response('{"error":"store_failed"}', 503);
                }
                return http.Response(
                    jsonEncode({
                      'batches': [
                        for (final station in [_print7Id, _lamination1Id])
                          {
                            'batch_id': station,
                            'order_id': orderId,
                            'apparatus': station,
                            'current_apparatus': _lamination1Id,
                            'worker_ref': station == _print7Id
                                ? 'map-wip-worker'
                                : 'other-worker',
                            'action': 'complete',
                            'status': 'completed',
                            'wip_status':
                                station == _print7Id ? 'processed' : 'waiting',
                            'produced_qty': station == _print7Id ? 15 : 12,
                            'uom': 'm',
                            'qr_payload': station == _print7Id
                                ? '400000000000000000000001'
                                : '400000000000000000000002',
                          },
                      ]
                    }),
                    200);
              }));
    });
  }
}
