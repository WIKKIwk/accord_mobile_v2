part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerMapWipTests() {
  const orderId = 'zakaz-worker-map-wip';
  final l10n = AppLocalizations(const Locale('uz'));

  for (final scenario in [
    'own',
    'own-print-error',
    'same-apparatus-other-worker',
    'missing-owner',
    'opening',
    'lamination',
    'denied',
    'retry',
  ]) {
    testWidgets('worker map WIP details and reprint: $scenario',
        (tester) async {
      final ownSource = !['lamination', 'denied', 'retry'].contains(scenario);
      final canReprint = scenario == 'own' || scenario == 'own-print-error';
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
          progressDriverUrlPicker: (_) async => 'http://printer.test',
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

      final source = ownSource ? _print7Id : _lamination1Id;
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
          expect(find.text(ownSource ? '15 m' : '12 m'), findsOneWidget);
          await tester
              .longPress(find.byKey(const ValueKey('worker-wip-item-0')));
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('worker-wip-history-preview-$source')),
              findsOneWidget);
          final details = find.byType(BottomSheet).last;
          expect(
              find.descendant(
                  of: details, matching: find.text('0004 • Map WIP order')),
              findsOneWidget);
          for (final hidden in [
            'WIP ID',
            'Order',
            'Boshlangan',
            'Amali',
            'Ishchi'
          ]) {
            expect(find.descendant(of: details, matching: find.text(hidden)),
                findsNothing);
          }
          expect(
              find.descendant(
                  of: details, matching: find.textContaining('apparatus:')),
              findsNothing);
          expect(
              find.descendant(
                  of: details,
                  matching: find.textContaining('zakaz-worker-map-wip')),
              findsNothing);
          expect(
              find.descendant(
                  of: details, matching: find.text('400000000000000000000001')),
              findsNothing);
          final reprint =
              find.byKey(ValueKey('worker-wip-history-reprint-$source'));
          expect(reprint, canReprint ? findsOneWidget : findsNothing);
          if (canReprint) {
            await tester.ensureVisible(reprint);
            await tester.tap(reprint);
            await tester.pumpAndSettle();
            if (scenario == 'own-print-error') {
              expect(find.text('Printer ulanmagan'), findsOneWidget);
              expect(find.text('Qayta chop etish'), findsOneWidget);
            } else {
              expect(find.byKey(ValueKey('worker-wip-history-preview-$source')),
                  findsOneWidget);
            }
            final request = requests.singleWhere((r) => r.method == 'POST');
            expect(request.url.path, endsWith('/progress-qr/reprint'));
            final body = jsonDecode(request.body) as Map;
            expect(body['progress_batch_id'], source);
            expect(body['qr_payload'], '400000000000000000000001');
            expect(body['print_count'], 1);
            expect(body['driver_url'], 'http://printer.test');
          }
        }
        final reads = requests.where((r) => r.method == 'GET');
        expect(reads, hasLength(scenario == 'retry' ? 4 : 2));
        expect(requests.where((r) => r.method == 'POST'),
            hasLength(canReprint ? 1 : 0));
        expect(reads.every((r) => r.url.queryParameters['order_id'] == orderId),
            isTrue);
        expect(reads.every((r) => r.url.queryParameters['status'] == 'all'),
            isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
          () => MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('/progress-qr/reprint')) {
                  if (scenario == 'own-print-error') {
                    return http.Response(
                        '{"error":"scale_driver_not_configured"}',
                        503);
                  }
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'batch': {
                          'batch_id': source,
                          'qr_payload': '400000000000000000000001'
                        },
                        'print': {'status': 'printed'},
                      }),
                      200);
                }
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
                                ? (scenario == 'missing-owner'
                                    ? ''
                                    : scenario == 'same-apparatus-other-worker'
                                        ? 'other-worker'
                                        : 'map-wip-worker')
                                : 'other-worker',
                            'label_item_name':
                                'Output apparatus:$station complete',
                            'payload_json': scenario == 'opening'
                                ? {'input_wip_source_kind': 'opening_wip'}
                                : {},
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
