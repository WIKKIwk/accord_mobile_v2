part of 'admin_production_map_test_screen_test.dart';

void _registerScanBootstrapTests() {
  for (final outcome in [
    'complete',
    'materials missing',
    'qolips malformed',
    'old server',
    'domain denied',
  ]) {
    testWidgets('scan bootstrap detail startup: $outcome', (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      final requests = <http.Request>[];
      var bytes = 0;
      await http.runWithClient(
        () async {
          await _openScanBootstrapFixture(tester, fixture);
          await tester.pumpAndSettle();
          final detailRequests = requests.where(_scanDetailRequest).toList();
          if (outcome == 'complete') {
            expect(detailRequests, hasLength(1));
            expect(
              detailRequests.single.url.path,
              endsWith('/order-scan-bootstrap'),
            );
            _expectScanBootstrapLoaded(tester);
            debugPrint(
              'scan bootstrap complete fixture requests=${detailRequests.length} response_body_bytes=$bytes',
            );
          } else if (outcome == 'materials missing') {
            expect(detailRequests.map((r) => r.url.path), [
              '/v1/mobile/admin/production-maps/order-scan-bootstrap',
              '/v1/mobile/admin/raw-material-start-requirements',
            ]);
          } else if (outcome == 'qolips malformed') {
            expect(detailRequests.map((r) => r.url.path), [
              '/v1/mobile/admin/production-maps/order-scan-bootstrap',
              '/v1/mobile/admin/production-maps/qolip-validate',
            ]);
            expect(jsonDecode(detailRequests.last.body)['qolip_code'], '');
          } else if (outcome == 'old server') {
            expect(
              detailRequests,
              hasLength(4),
            ); // one unsupported probe + old three
            expect(
              detailRequests.where((r) => r.method == 'POST'),
              hasLength(1),
            );
          } else {
            expect(detailRequests, hasLength(1));
            _expectNoScanBootstrapData(tester);
            expect(
              find.byKey(
                const ValueKey('production-order-print-preflight-outcome'),
              ),
              findsNothing,
            );
            final dynamic content = tester.widget(find.byWidgetPredicate((w) =>
                w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
            content.onMaterialsLinked();
            await tester.pumpAndSettle();
            expect(requests.where(_scanDetailRequest), hasLength(2));
            expect(
                requests.where(_scanDetailRequest).every((request) =>
                    request.url.path.endsWith('/order-scan-bootstrap')),
                isTrue);
          }
          expect(
            requests.where((r) => r.url.path.endsWith('/queue-action')),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(const Duration(seconds: 11));
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests.add(request);
          http.Response response;
          if (request.url.path.endsWith('/order-scan-bootstrap')) {
            final body = scanBootstrap();
            if (outcome == 'materials missing') {
              (body['sections'] as Map).remove('materials');
            }
            if (outcome == 'qolips malformed') {
              body['sections']['qolips']['data'] = {};
            }
            response = outcome == 'old server'
                ? http.Response('', 404)
                : outcome == 'domain denied'
                    ? http.Response('{"error":"order_not_available"}', 404)
                    : http.Response(jsonEncode(body), 200);
          } else if (request.url.path.endsWith('/sequence')) {
            response = http.Response(jsonEncode(scanSequence()), 200);
          } else if (request.url.path.endsWith(
            '/raw-material-start-requirements',
          )) {
            response = http.Response(jsonEncode(scanMaterials()), 200);
          } else if (request.url.path.endsWith('/qolip-validate')) {
            response = http.Response(jsonEncode(scanQolips()), 200);
          } else {
            response = http.Response('{}', 200);
          }
          if (_scanDetailRequest(request)) bytes += response.bodyBytes.length;
          return response;
        }),
      );
    });
  }
  testWidgets(
    'scan bootstrap settled detail survives unrelated live revision',
    (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await _openScanBootstrapFixture(tester, fixture);
          await tester.pumpAndSettle();
          _expectScanBootstrapLoaded(tester);
          fixture.live.add(_scanLiveSnapshot(fixture.order, revision: 8));
          await tester.pumpAndSettle();
          _expectScanBootstrapLoaded(tester);
          expect(
            find.text(
              'Ish holati server bilan sinxron emas. Sahifani yangilang.',
            ),
            findsNothing,
          );
          expect(requests.where(_scanDetailRequest), hasLength(1));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(const Duration(seconds: 11));
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/order-scan-bootstrap')
                  ? scanBootstrap()
                  : {},
            ),
            200,
          );
        }),
      );
    },
  );
  for (final change in ['account', 'permissions', 'token', 'closed', 'live']) {
    testWidgets(
      'scan bootstrap ignores delayed response after $change change',
      (tester) async {
        final fixture = await _prepareScanBootstrapFixture(tester);
        final pending = Completer<http.Response>();
        final requests = <http.Request>[];
        await http.runWithClient(
          () async {
            await _openScanBootstrapFixture(tester, fixture);
            await tester.pump();
            expect(requests.where(_scanDetailRequest), hasLength(1));
            final dynamic oldContent = tester.widget(
              find.byWidgetPredicate(
                (w) =>
                    w.runtimeType.toString() == '_ReadOnlyOrderDetailContent',
              ),
            );
            final oldScan =
                oldContent.onQuickScan as Future<void> Function(String);
            final oldStart = oldContent.onStart as VoidCallback;
            if (change == 'closed') {
              final sheet = find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailSheet',
              );
              Navigator.of(tester.element(sheet)).pop();
            } else if (change == 'live') {
              fixture.live.add(_scanLiveSnapshot(fixture.order, revision: 8));
            } else {
              final profile = change == 'token'
                  ? AppSession.instance.profile!
                  : SessionProfile(
                      role: UserRole.aparatchi,
                      displayName: 'Scan worker',
                      legalName: '',
                      ref: change == 'account' ? 'other-worker' : 'scan-worker',
                      phone: '',
                      avatarUrl: '',
                      capabilities: change == 'permissions'
                          ? const ['apparatus.queue.read']
                          : const [
                              'apparatus.queue.read',
                              'apparatus.queue.manage',
                            ],
                      assignedApparatus: const [scanApparatus],
                    );
              await AppSession.instance.setSession(
                token: 'new-token',
                profile: profile,
              );
            }
            await tester.pump();
            if (change == 'account' || change == 'permissions') {
              await oldScan('MOLD1');
              oldStart();
              await tester.pump();
              expect(requests.where((r) => r.method == 'POST'), isEmpty);
            }
            pending.complete(http.Response(jsonEncode(scanBootstrap()), 200));
            await tester.pumpAndSettle();
            expect(requests.where(_scanDetailRequest), hasLength(1));
            expect(requests.where((r) => r.method == 'POST'), isEmpty);
            if (change != 'token' && change != 'live') {
              _expectNoScanBootstrapData(tester);
            }
            if (change == 'token' || change == 'live') {
              _expectScanBootstrapLoaded(tester);
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await tester.pump(const Duration(seconds: 11));
            expect(tester.takeException(), isNull);
          },
          () => MockClient((request) {
            requests.add(request);
            return request.url.path.endsWith('/order-scan-bootstrap')
                ? pending.future
                : Future.value(http.Response('{}', 200));
          }),
        );
      },
    );
  }
  testWidgets(
    'scan bootstrap late fallback survives unchanged target at newer live revision',
    (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      final pending = Completer<http.Response>();
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await _openScanBootstrapFixture(tester, fixture);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(requests.where(_scanDetailRequest), hasLength(2));
          fixture.live.add(_scanLiveSnapshot(fixture.order, revision: 8));
          await tester.pump();
          pending.complete(http.Response(jsonEncode(scanMaterials()), 200));
          await tester.pumpAndSettle();
          _expectScanBootstrapLoaded(tester);
          expect(requests.where((r) => r.method == 'POST'), isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await tester.pump(const Duration(seconds: 11));
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) {
          requests.add(request);
          if (request.url.path.endsWith('/order-scan-bootstrap')) {
            final body = scanBootstrap();
            (body['sections'] as Map).remove('materials');
            return Future.value(http.Response(jsonEncode(body), 200));
          }
          if (request.url.path.endsWith('/raw-material-start-requirements')) {
            return pending.future;
          }
          return Future.value(http.Response('{}', 200));
        }),
      );
    },
  );
}

void _expectScanBootstrapLoaded(WidgetTester tester) {
  final dynamic content = tester.widget(find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
  expect(content.materialsLoading, isFalse);
  expect(
      (content.uiState.materialAssignments as List<AdminRawMaterialAssignment>)
          .map((row) => row.barcode),
      ['ROLL1']);
  expect(
      (content.requiredQolips as List<AdminProductionMapRequiredQolip>)
          .map((row) => row.qolipCode),
      ['MOLD1']);
  expect(content.qolipRequirementsLoaded, isTrue);
  expect(content.showQuickScanner, isTrue);
}

void _expectNoScanBootstrapData(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent');
  if (finder.evaluate().isEmpty) return;
  final dynamic content = tester.widget(finder);
  expect(content.uiState.materialAssignments, isEmpty);
  expect(content.requiredQolips, isEmpty);
  expect(content.showQuickScanner, isFalse);
}

bool _scanDetailRequest(http.Request request) => [
      '/order-scan-bootstrap',
      '/sequence',
      '/raw-material-start-requirements',
      '/qolip-validate',
      '/wip-batches',
      '/opening-wip',
    ].any(request.url.path.endsWith);

typedef _ScanBootstrapFixture = ({
  ProductionMapSaved order,
  List<AdminApparatus> apparatus,
  StreamController<AdminProductionMapLiveSnapshot> live,
});
Future<_ScanBootstrapFixture> _prepareScanBootstrapFixture(
  WidgetTester tester,
) async {
  final testModeWasEnabled = await TestModeController.instance.isEnabled();
  addTearDown(() => TestModeController.instance.setEnabled(testModeWasEnabled));
  await TestModeController.instance.setEnabled(true);
  AppSession.instance.profile = const SessionProfile(
    role: UserRole.aparatchi,
    displayName: 'Scan worker',
    legalName: '',
    ref: 'scan-worker',
    phone: '',
    avatarUrl: '',
    capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
    assignedApparatus: [scanApparatus],
  );
  final order = await MobileApi.instance.adminSaveProductionMap(
    _productionOrderMap(
      id: scanOrder,
      title: 'Scan startup fixture',
      productCode: 'SCAN',
      apparatusId: scanApparatus,
      product: 'Scan film',
    ),
  );
  final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
  final live = StreamController<AdminProductionMapLiveSnapshot>.broadcast();
  addTearDown(live.close);
  await _usePhoneViewport(tester);
  return (order: order, apparatus: apparatus, live: live);
}

AdminProductionMapLiveSnapshot _scanLiveSnapshot(
  ProductionMapSaved order, {
  int revision = 7,
}) =>
    AdminProductionMapLiveSnapshot.fromJson({
      ...scanSequence(),
      'scope': 'worker-live-scope',
      'rev': revision,
      'maps': [
        {'map': order.map.toJson(), 'program': <String, dynamic>{}},
      ],
    });
Future<void> _openScanBootstrapFixture(
  WidgetTester tester,
  _ScanBootstrapFixture fixture,
) async {
  final snapshot = _scanLiveSnapshot(fixture.order);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
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
        queueSnapshotLoader: () async => snapshot,
        apparatusLoader: () async => fixture.apparatus,
        liveEventsLoader: () => fixture.live.stream,
      ),
    ),
  );
  await tester.pumpAndSettle();
  fixture.live.add(snapshot);
  await tester.pump();
  await tester.tap(find.text('7 ta rangli bosma aparat'));
  await tester.pumpAndSettle();
  await TestModeController.instance.setEnabled(false);
  await tester.tap(find.textContaining('scan-bootstrap').first);
  await tester.pump();
}
