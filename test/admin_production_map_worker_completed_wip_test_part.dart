part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerCompletedWipTests() {
  const orderId = 'zakaz-worker-completed-wip';
  const workerRef = 'worker-completed-wip';
  final l10n = AppLocalizations(const Locale('uz'));

  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    testWidgets(
        'completed history retains downstream WIP and only reprints on $station',
        (tester) async {
      final fixture = _ReactivationFixture(station);
      final requests = <http.Request>[];
      Map<String, dynamic>? output;
      await http.runWithClient(() async {
        await fixture.open(tester,
            progressDriverUrlPicker: (_) async => 'http://printer.test');
        await tester.tap(find
            .ancestor(
              of: find.textContaining('Reactivation order'),
              matching: find.byType(InkWell),
            )
            .first);
        await tester.pumpAndSettle();

        expect(find.text('2 ta WIP yaratilgan'), findsOneWidget);
        expect(find.text('5 m'), findsOneWidget);
        expect(find.text('121 m'), findsOneWidget);
        expect(
            find.descendant(
                of: find.byKey(const ValueKey('worker-wip-item-0')),
                matching: find.text('5 m')),
            findsOneWidget);
        expect(find.text('999 m'), findsNothing);
        expect(find.text('Rulonni yechish'), findsNothing);
        expect(find.text('Tugatish'), findsNothing);
        expect(find.text('Boshlash'), findsNothing);
        expect(find.text('Davom ettirish'), findsNothing);
        expect(
            find.byKey(
                const ValueKey('production-order-pause-complete-visible')),
            findsNothing);
        expect(requests.every((request) => request.method == 'GET'), isTrue);

        // A short tap keeps details/reprint separate from reactivation actions.
        await tester.tap(find.byKey(const ValueKey('worker-wip-item-0')));
        await tester.pumpAndSettle();
        expect(find.text('Qayta chop etish'), findsOneWidget);
        expect(find.byKey(const ValueKey('worker-reactivate-completed-work')),
            findsNothing);
        expect(requests.every((request) => request.method == 'GET'), isTrue);
        await tester.tap(find.text('Qayta chop etish'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        final writes = requests.where((request) => request.method != 'GET');
        expect(writes, hasLength(1));
        expect(find.text('WIP QR qayta chop etildi'), findsOneWidget);
        final reprint = writes.single;
        expect(reprint.url.path.endsWith('/progress-qr/reprint'), isTrue);
        final body = jsonDecode(reprint.body) as Map;
        expect(body['progress_batch_id'], _ReactivationFixture.batchId);
        expect(body['qr_payload'], output!['qr_payload']);
        expect(body['print_count'], 1);
        expect(fixture.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('/progress-qr/reprint')) {
                  return http.Response(
                      jsonEncode({'ok': true, 'batch': output}), 200);
                }
                final response = await fixture.respond(request);
                if (!request.url.path.endsWith('/wip-batches')) return response;
                expect(request.url.queryParameters['order_id'],
                    _ReactivationFixture.orderId);
                expect(request.url.queryParameters['status'], 'all');
                output = ((jsonDecode(response.body) as Map)['batches'] as List)
                    .single
                    .cast<String, dynamic>();
                // Its location has changed; the output must remain in producer history.
                output!['current_apparatus'] = _lamination2Id;
                output!['wip_status'] = 'processed';
                output!['produced_qty'] = 5;
                final batches = <Map<String, dynamic>>[
                  {
                    ...output!,
                    'batch_id': 'earlier-output',
                    'produced_qty': 121,
                    'completed_at_unix': 90,
                    'qr_payload': '400000000000000000000002',
                  },
                  output!,
                  {
                    ...output!,
                    'batch_id': 'other-worker',
                    'worker_ref': 'another-worker',
                    'produced_qty': 999,
                  },
                  {
                    ...output!,
                    'batch_id': 'other-stage',
                    'apparatus': _lamination2Id,
                    'produced_qty': 999,
                  },
                  {
                    ...output!,
                    'batch_id': 'other-order',
                    'order_id': 'another-order',
                    'produced_qty': 999,
                  },
                ];
                final currentApparatus =
                    request.url.queryParameters['apparatus'] ?? '';
                return http.Response(
                    jsonEncode({
                      // Match PostgreSQL: `apparatus` filters the current
                      // location, even when status=all includes processed WIP.
                      'batches': batches
                          .where((batch) =>
                              batch['order_id'] ==
                                  request.url.queryParameters['order_id'] &&
                              (currentApparatus.isEmpty ||
                                  batch['current_apparatus'] ==
                                      currentApparatus))
                          .toList(),
                    }),
                    200);
              }));
    });
  }

  testWidgets(
      'completed WIP reprint stops after account changes in printer picker',
      (tester) async {
    final fixture = _ReactivationFixture(_lamination1Id);
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await fixture.open(tester, progressDriverUrlPicker: (_) async {
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Other worker',
          legalName: '',
          ref: 'another-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_lamination1Id],
        );
        return 'http://printer.test';
      });
      await tester.tap(find
          .ancestor(
            of: find.textContaining('Reactivation order'),
            matching: find.byType(InkWell),
          )
          .first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-wip-item-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qayta chop etish'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(find.text('WIP QR qayta chop etildi'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              requests.add(request);
              return fixture.respond(request);
            }));
  });

  Future<void> openCompletedTab(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(_twoStageProductionOrderMap(
      id: orderId,
      title: 'Worker completed WIP',
      productCode: 'COMPLETED-WIP',
      product: 'completed WIP product',
      firstApparatusId: _print7Id,
      secondApparatusId: _lamination1Id,
    ).copyWith(orderNumber: '0004'));
    for (final apparatus in [_print7Id, _lamination1Id]) {
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: apparatus,
        orderIds: const [orderId],
      );
    }
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _print7Id,
      orderId: orderId,
      action: 'start',
    );
    final firstInput =
        (await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _print7Id,
      orderId: orderId,
      action: 'detach_roll',
      producedQty: 12,
      uom: 'm',
    ))
            .progressBatch!;
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _print7Id,
      orderId: orderId,
      action: 'resume',
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _print7Id,
      orderId: orderId,
      action: 'complete',
      producedQty: 15,
      grossQty: 9,
      uom: 'm',
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: workerRef,
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_lamination1Id],
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _lamination1Id,
      orderId: orderId,
      action: 'start',
      qrPayload: firstInput.qrPayload,
    );
    await MobileApi.instance.adminApparatusQueueActionResult(
      apparatus: _lamination1Id,
      orderId: orderId,
      action: 'complete',
      producedQty: 12,
      grossQty: 8,
      finishedGoodsMeter: 12,
      finishedGoodsKg: 8,
      totalWaste: 1,
      laminationFilmLeftoverRolls: 1,
      uom: 'm',
    );
    // The worker finished a batch, but another upstream roll is still waiting.
    final completed =
        await MobileApi.instance.adminCompletedProductionMapOrders();
    expect(completed.single.orderId, orderId);
    expect(completed.single.status, 'in_progress');

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
    expect(find.text('Tugallanmoqda'), findsOneWidget);
    // Exercise the real HTTP loader, not the authorization-free TestMode API.
    await TestModeController.instance.setEnabled(false);
  }

  for (final scenario in ['success', 'empty', 'retry', 'qr-search']) {
    testWidgets(
        'worker completed WIP loads exact order and producer without admin access: $scenario',
        (tester) async {
      if (scenario == 'qr-search') {
        final scannerPlatform = MobileScannerPlatform.instance;
        MobileScannerPlatform.instance = _WorkerWipQrScannerPlatform();
        addTearDown(() {
          MobileScannerPlatform.instance = scannerPlatform;
        });
      }
      final requests = <http.Request>[];
      var historyAttempts = 0;
      await http.runWithClient(() async {
        await openCompletedTab(tester);
        await tester.tap(find
            .ancestor(
              of: find.textContaining('Worker completed WIP'),
              matching: find.byType(InkWell),
            )
            .first);
        await tester.pumpAndSettle();

        final error =
            find.text(l10n.productionText('worker.wip.history.error'));
        final empty =
            find.text(l10n.productionText('worker.wip.history.empty'));
        if (scenario == 'retry') {
          expect(error, findsOneWidget);
          expect(empty, findsNothing);
          await tester.tap(find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Qayta urinish'),
          ));
          await tester.pumpAndSettle();
        }
        expect(error, findsNothing);
        final searchButton = find.byKey(const ValueKey('worker-wip-search-qr'));
        expect(searchButton, findsOneWidget);
        if (scenario == 'empty') {
          expect(empty, findsOneWidget);
          expect(tester.widget<FilledButton>(searchButton).onPressed, isNull);
        } else {
          expect(empty, findsNothing);
          expect(
              find.text('${scenario == 'qr-search' ? 2 : 1} ta WIP yaratilgan'),
              findsOneWidget);
          expect(find.text('12 m'), findsOneWidget);
          expect(find.text('999 m'), findsNothing);
          expect(find.text('Qayta chop etish'), findsNothing);
          if (scenario == 'qr-search') {
            Future<void> scan(String qr) async {
              await tester.tap(searchButton);
              await tester.pumpAndSettle();
              expect(find.byType(RawMaterialScanDialog), findsOneWidget);
              final scanner =
                  tester.widget<MobileScanner>(find.byType(MobileScanner));
              scanner.onDetect!(BarcodeCapture(
                barcodes: [Barcode(rawValue: qr, format: BarcodeFormat.qrCode)],
              ));
              await tester.pumpAndSettle();
              expect(find.byType(RawMaterialScanDialog), findsNothing);
            }

            expect(find.text('34 m'), findsOneWidget);
            await scan('https://accord.test/wip?qr=40000000000000000000000a');
            expect(find.text('34 m'), findsOneWidget);
            expect(find.text('12 m'), findsNothing);
            expect(find.byKey(const ValueKey('worker-wip-item-1')),
                findsOneWidget);
            await tester.tap(find.byKey(const ValueKey('worker-wip-show-all')));
            await tester.pumpAndSettle();
            expect(find.text('12 m'), findsOneWidget);
            expect(find.text('34 m'), findsOneWidget);

            // A QR for another order must never escape this sheet's scope.
            await scan('400000000000000000000003');
            expect(
                find.text(
                    l10n.productionText('worker.wip.history.qr_not_found')),
                findsOneWidget);
            expect(find.text('12 m'), findsOneWidget);
            expect(find.text('34 m'), findsOneWidget);
            expect(find.byKey(const ValueKey('worker-wip-show-all')),
                findsNothing);

            await tester.tap(searchButton);
            await tester.pumpAndSettle();
            Navigator.of(tester.element(find.byType(RawMaterialScanDialog)))
                .pop();
            await tester.pumpAndSettle();
            expect(find.text('12 m'), findsOneWidget);
            expect(find.text('34 m'), findsOneWidget);
            expect(
                tester.widget<FilledButton>(searchButton).onPressed, isNotNull);
          }
          await tester.tap(find.byKey(const ValueKey('worker-wip-item-0')));
          await tester.pumpAndSettle();
          expect(
              find.byKey(
                  ValueKey('worker-wip-history-reprint-output-$orderId')),
              findsOneWidget);
          expect(
              find.descendant(
                  of: find.byType(BottomSheet).last,
                  matching: find.text('WIP ID')),
              findsNothing);
        }
        expect(historyAttempts, scenario == 'retry' ? 2 : 1);
        expect(
          requests.where((r) => r.url.path.endsWith('/wip-batches')),
          hasLength(historyAttempts),
        );
        expect(
          requests.where((r) =>
              r.url.path.endsWith('/opening-wip') ||
              r.url.path.endsWith('/progress-qr/history')),
          isEmpty,
        );
        expect(requests.every((r) => r.method == 'GET'), isTrue);
        expect(
            requests.every((r) => r.headers['authorization'] == 'Bearer token'),
            isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
          () => MockClient((request) async {
                requests.add(request);
                if (!request.url.path.endsWith('/wip-batches')) {
                  // This personal view uses the exact order and producer.
                  return http.Response('{"error":"forbidden"}', 403);
                }
                expect(request.url.queryParameters['order_id'], orderId);
                expect(request.url.queryParameters.containsKey('apparatus'),
                    isFalse);
                historyAttempts++;
                if (scenario == 'retry' && historyAttempts == 1) {
                  return http.Response('{"error":"store_failed"}', 503);
                }
                return http.Response(
                    jsonEncode({
                      'batches': [
                        if (scenario != 'empty')
                          for (final id in [orderId, 'zakaz-another-order'])
                            {
                              'batch_id': 'output-$id',
                              'order_id': id,
                              'apparatus': _lamination1Id,
                              'current_apparatus': _lamination1Id,
                              'worker_ref': workerRef,
                              'action': 'complete',
                              'status': 'completed',
                              'wip_status': 'waiting',
                              'produced_qty': id == orderId ? 12 : 999,
                              'uom': 'm',
                              'completed_at_unix': 100,
                              'qr_payload': id == orderId
                                  ? '400000000000000000000001'
                                  : '400000000000000000000003',
                            },
                        if (scenario == 'qr-search')
                          {
                            'batch_id': 'second-output-$orderId',
                            'order_id': orderId,
                            'apparatus': _lamination1Id,
                            'current_apparatus': _lamination1Id,
                            'worker_ref': workerRef,
                            'action': 'complete',
                            'status': 'completed',
                            'wip_status': 'waiting',
                            'produced_qty': 34,
                            'uom': 'm',
                            'completed_at_unix': 90,
                            'qr_payload': '40000000000000000000000A',
                          },
                      ],
                    }),
                    200);
              }));
    });
  }
}

class _WorkerWipQrScannerPlatform extends _TestMobileScannerPlatform {
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}
