part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerWipAccuracyTests() {
  final l10n = AppLocalizations(const Locale('uz'));
  const orderId = 'zakaz-wip-accuracy';
  final emptyText = l10n.productionText('worker.progress.none', values: {
    'stage': _fixtureApparatusName(_print7Id),
  });
  final summaryText =
      l10n.productionText('worker.progress.summary.empty', values: {
    'stage': _fixtureApparatusName(_print7Id),
  });

  Future<void> open(WidgetTester tester, {bool printer = false}) async {
    await TestModeController.instance.setEnabled(true);
    final station = printer ? _print7Id : _lamination1Id;
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'worker-wip-accuracy',
      phone: '',
      avatarUrl: '',
      capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [station],
    );
    await MobileApi.instance.adminSaveProductionMap(_twoStageProductionOrderMap(
      id: orderId,
      title: 'WIP accuracy',
      productCode: 'WIP-ACCURACY',
      product: 'WIP accuracy product',
      firstApparatusId: _print7Id,
      secondApparatusId: _lamination1Id,
    ));
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: station,
      orderIds: const [orderId],
    );
    setMobileApiTestModeQueueActionControlFixture(
      apparatus: station,
      orderId: orderId,
      control: printer
          ? _freshStartQueueControl(qolipMode: AdminQueueQolipMode.scanRequired)
          : const AdminApparatusQueueOrderActionControl(
              state: 'pending',
              allowedActions: {'start'},
              hasOnlyKnownActions: true,
              previousStage: _print7Id,
              previousStageReady: true,
              interaction: AdminQueueWorkerInteraction(
                mode: AdminQueueInteractionMode.freshStart,
                startMaterialsMode: AdminQueueStartMaterialsMode.hidden,
                materialScanRequired: false,
                assignedMaterialsDisplayOnly: true,
                materialIntakeAllowed: false,
                previousWipMode: AdminQueuePreviousWipMode.scanRequired,
                qolipMode: AdminQueueQolipMode.notRequired,
              ),
            ),
    );
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
    await tester.tap(find.text(_fixtureApparatusName(station)));
    await tester.pumpAndSettle();
    await TestModeController.instance.setEnabled(false);
    await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  http.Response supportingResponse(http.Request request) {
    if (request.url.path.endsWith('/raw-material-assignments')) {
      return http.Response('{"assignments":[]}', 200);
    }
    if (request.url.path.endsWith('/qolip-validate')) {
      final body = jsonDecode(request.body) as Map;
      return http.Response(
          jsonEncode({
            'ok': true,
            'qolip': {
              'qolip_code': body['qolip_code'] ?? '',
              'required_qolip_codes': ['mold-1', 'mold-2', 'mold-3'],
              'required_qolip_count': 3,
              'required_qolips': [
                for (var n = 1; n <= 3; n++)
                  {'qolip_code': 'mold-$n', 'color': 'Color $n'},
              ],
            },
          }),
          200);
    }
    return http.Response('{"error":"not_found"}', 404);
  }

  for (final scenario in [
    'empty',
    'server',
    'forbidden',
    'malformed',
    'network',
    'loading',
    'available'
  ]) {
    testWidgets('worker WIP accuracy: $scenario has one truthful state',
        (tester) async {
      final requests = <http.Request>[];
      final pending = Completer<http.Response>();
      await http.runWithClient(() async {
        await open(tester);
        if (scenario != 'loading') {
          await tester.pumpAndSettle();
        }
        expect(requests.where((r) => r.url.path.endsWith('/wip-batches')),
            hasLength(1));
        expect(requests.where((r) => r.url.path.endsWith('/qolip/products')),
            isEmpty);
        expect(
            find.byKey(const ValueKey('production-attached-qolips-expansion')),
            findsNothing);
        expect(find.byKey(const ValueKey('production-qolips-expansion')),
            findsNothing);
        expect(find.textContaining('hali bu order uchun mahsulot chiqarmagan'),
            findsNothing);
        expect(find.text(summaryText), findsNothing);
        expect(find.text(emptyText),
            scenario == 'empty' ? findsOneWidget : findsNothing);
        final expectedError = switch (scenario) {
          'server' || 'malformed' => 'worker.wip.load_failed',
          'forbidden' => 'worker.wip.access_denied',
          'network' => 'worker.error.network_timeout',
          _ => null,
        };
        if (expectedError != null) {
          expect(find.text(l10n.productionText(expectedError)), findsOneWidget);
        }
        expect(find.text('store_failed'), findsNothing);
        expect(
            find.text(l10n.productionText('worker.error.sync')), findsNothing);
        final start = find.widgetWithText(FilledButton, 'Boshlash');
        expect(start, findsOneWidget);
        expect(tester.widget<FilledButton>(start).onPressed, isNull);
        expect(find.byType(ProductionQuickScannerPanel),
            scenario == 'available' ? findsOneWidget : findsNothing);
        if (scenario == 'loading') {
          expect(find.byType(LinearProgressIndicator), findsWidgets);
          pending.complete(http.Response('{"batches":[]}', 200));
          await tester.pumpAndSettle();
          expect(find.text(emptyText), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
          () => MockClient((request) async {
                requests.add(request);
                if (!request.url.path.endsWith('/wip-batches')) {
                  return supportingResponse(request);
                }
                switch (scenario) {
                  case 'loading':
                    return pending.future;
                  case 'network':
                    throw http.ClientException('network switch');
                  case 'server':
                    return http.Response('{"error":"store_failed"}', 503);
                  case 'forbidden':
                    return http.Response('{"error":"forbidden"}', 403);
                  case 'malformed':
                    return http.Response('{"ok":true}', 200);
                  case 'available':
                    return http.Response(
                        jsonEncode({
                          'batches': [
                            {
                              'batch_id': 'existing-roll',
                              'order_id': orderId,
                              'apparatus': _print7Id,
                              'current_apparatus': _print7Id,
                              'next_apparatus': _lamination1Id,
                              'wip_status': 'waiting',
                              'status': 'roll_detached',
                              'action': 'detach_roll',
                              'produced_qty': 454,
                              'uom': 'm',
                              'qr_payload': 'existing-roll-qr',
                            }
                          ]
                        }),
                        200);
                  default:
                    return http.Response('{"batches":[]}', 200);
                }
              }));
    });
  }

  testWidgets(
      'worker WIP accuracy: printer retains required molds without warehouse section',
      (tester) async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await open(tester, printer: true);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-attached-qolips-expansion')),
          findsNothing);
      expect(requests.where((r) => r.url.path.endsWith('/qolip/products')),
          isEmpty);
      expect(find.byKey(const ValueKey('production-qolips-expansion')),
          findsOneWidget);
      expect(find.text('0/3 ta'), findsOneWidget);
      for (var n = 1; n <= 3; n++) {
        tester
            .widget<ProductionQuickScannerPanel>(
                find.byType(ProductionQuickScannerPanel))
            .onCodeDetected('mold-$n');
        await tester.pumpAndSettle();
      }
      expect(find.text('3/3 ta'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Boshlash'))
              .onPressed,
          isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
        () => MockClient((request) async {
              requests.add(request);
              return supportingResponse(request);
            }));
  });
}
