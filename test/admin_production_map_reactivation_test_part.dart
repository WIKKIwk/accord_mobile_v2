part of 'admin_production_map_test_screen_test.dart';

class _ReactivationFixture {
  _ReactivationFixture(this.station, {this.denial});
  final String station;
  final String? denial;
  final requests = <http.Request>[];
  final writes = <http.Request>[];
  static const orderId = 'zakaz-reactivation-exact-order';
  static const workerRef = 'reactivation-worker';
  static const batchId = 'reactivation-output';
  bool get isPrint => station == _print8Id;
  String get stage => isPrint ? 'first-apparatus' : 'second-apparatus';

  Future<void> open(
    WidgetTester tester, {
    Future<String?> Function(BuildContext context)? progressDriverUrlPicker,
  }) async {
    await TestModeController.instance.setEnabled(true);
    var map = _twoStageProductionOrderMap(
        id: orderId,
        title: 'Reactivation order',
        productCode: 'REOPEN',
        product: 'Reactivation product',
        firstApparatusId: isPrint ? station : _print9Id,
        secondApparatusId: isPrint ? _lamination1Id : station);
    if (station == _rezkaId) {
      map = map.copyWith(nodes: [
        for (final node in map.nodes)
          if (node.apparatusId == _rezkaId)
            node.copyWith(rezkaKadrCount: 1)
          else
            node
      ]);
    }
    await MobileApi.instance
        .adminSaveProductionMap(map.copyWith(orderNumber: '0099'));
    for (final id in [
      isPrint ? station : _print9Id,
      isPrint ? _lamination1Id : station
    ]) {
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: id, orderIds: const [orderId]);
    }
    AdminProgressBatch? input;
    if (!isPrint) {
      await MobileApi.instance.adminApparatusQueueActionResult(
          apparatus: _print9Id, orderId: orderId, action: 'start');
      input = (await MobileApi.instance.adminApparatusQueueActionResult(
              apparatus: _print9Id,
              orderId: orderId,
              action: 'complete',
              producedQty: 100,
              grossQty: 20,
              uom: 'm'))
          .progressBatch;
    }
    AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: workerRef,
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [station]);
    await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: station,
        orderId: orderId,
        action: 'start',
        qrPayload: input?.qrPayload ?? '');
    await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: station,
        orderId: orderId,
        action: 'complete',
        producedQty: 100,
        grossQty: 20,
        finishedGoodsMeter: 100,
        finishedGoodsKg: 20,
        laminationFilmLeftoverRolls: 1,
        diameter: 100,
        bobinaKg: 1,
        totalWaste: 1,
        uom: 'm');
    await _usePhoneViewport(tester);
    addTearDown(() async {
      dismissAdminTopNotice();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
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
            progressDriverUrlPicker: progressDriverUrlPicker,
            liveEventsLoader: () => const Stream.empty())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tugallangan'));
    await tester.tap(find.text('Tugallangan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reactivation order'), findsWidgets);
    await TestModeController.instance.setEnabled(false);
  }

  Future<void> longPressTarget(WidgetTester tester) async {
    final row = find
        .ancestor(
            of: find.textContaining('Reactivation order'),
            matching: find.byType(InkWell))
        .first;
    if (isPrint) {
      await tester.longPress(row);
    } else {
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('worker-wip-item-0')));
    }
    await tester.pumpAndSettle();
  }

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    if (request.url.path.endsWith('/reactivation/preview')) {
      return http.Response(
          jsonEncode(denial == null
              ? {
                  'available': true,
                  'target': {
                    'apparatus': station,
                    'order_id': orderId,
                    'batch_id': isPrint ? '' : batchId,
                    'session_id': 'finished-session',
                    'stage_node_id': stage,
                    'token': 'fingerprint'
                  }
                }
              : {'available': false, 'denial_reason': denial}),
          200);
    }
    if (request.url.path.endsWith('/reactivation')) {
      writes.add(request);
      return http.Response('{"ok":true,"rev":2,"epoch":"server"}', 200);
    }
    if (request.url.path.endsWith('/wip-batches')) {
      return http.Response(
          jsonEncode({
            'batches': [
              {
                'batch_id': batchId,
                'session_id': 'finished-session',
                'order_id': orderId,
                'apparatus': station,
                'current_apparatus': station,
                'worker_role': 'aparatchi',
                'worker_ref': workerRef,
                'action': 'complete',
                'status': 'completed',
                'wip_status': 'waiting',
                'produced_qty': 100,
                'uom': 'm',
                'qr_payload': '400118D5A225166D31898C1F',
                'completed_at_unix': 100,
              }
            ]
          }),
          200);
    }
    return http.Response('{"error":"forbidden"}', 403);
  }
}

void _registerReactivationTests() {
  // Print reopens an order; downstream stages reopen the selected output WIP.
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    testWidgets(
        'completed reactivation requires exact confirmation on $station',
        (tester) async {
      final fixture = _ReactivationFixture(station);
      await http.runWithClient(() async {
        await fixture.open(tester);
        await fixture.longPressTarget(tester);
        final action =
            find.byKey(const ValueKey('worker-reactivate-completed-work'));
        expect(action, findsOneWidget);
        expect(fixture.writes, isEmpty);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
            find.textContaining('faqat qo‘shimcha ishlab chiqarilgan miqdorni'),
            findsOneWidget);
        expect(find.textContaining('first-apparatus'), findsNothing);
        expect(find.textContaining('second-apparatus'), findsNothing);
        expect(fixture.writes, isEmpty);
        await tester
            .tap(find.byKey(const ValueKey('worker-reactivate-confirm')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(fixture.writes, hasLength(1));
        expect(jsonDecode(fixture.writes.single.body), {
          'apparatus': station,
          'order_id': _ReactivationFixture.orderId,
          if (!fixture.isPrint) 'batch_id': _ReactivationFixture.batchId,
          'session_id': 'finished-session',
          'stage_node_id': fixture.stage,
          'token': 'fingerprint'
        });
        if (!fixture.isPrint) {
          final request = fixture.requests
              .firstWhere((r) => r.url.path.endsWith('/wip-batches'));
          expect(request.url.queryParameters['order_id'],
              _ReactivationFixture.orderId);
          expect(request.url.queryParameters.containsKey('apparatus'), isFalse);
        }
        dismissAdminTopNotice();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => MockClient(fixture.respond));
    });
  }
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final switchAccount in [false, true]) {
      testWidgets(
          'completed reactivation does not write after ${switchAccount ? 'account switch' : 'cancel'} on $station',
          (tester) async {
        final fixture = _ReactivationFixture(station);
        await http.runWithClient(() async {
          await fixture.open(tester);
          await fixture.longPressTarget(tester);
          await tester.tap(
              find.byKey(const ValueKey('worker-reactivate-completed-work')));
          await tester.pumpAndSettle();
          if (switchAccount) {
            AppSession.instance.profile = SessionProfile(
                role: UserRole.aparatchi,
                displayName: 'Other worker',
                legalName: '',
                ref: 'different-worker',
                phone: '',
                avatarUrl: '',
                capabilities: [
                  'apparatus.queue.read',
                  'apparatus.queue.manage'
                ],
                assignedApparatus: [
                  station
                ]);
            await tester
                .tap(find.byKey(const ValueKey('worker-reactivate-confirm')));
          } else {
            await tester.tap(find.text('Bekor qilish'));
          }
          await tester.pumpAndSettle();
          expect(fixture.writes, isEmpty);
        }, () => MockClient(fixture.respond));
      });
    }
  }
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final denial in [
      'apparatus_busy',
      'source_not_free',
      'final_stage_closed',
      'order_closed'
    ]) {
      testWidgets(
          'completed reactivation explains and blocks $denial on $station',
          (tester) async {
        final fixture = _ReactivationFixture(station, denial: denial);
        await http.runWithClient(() async {
          await fixture.open(tester);
          await fixture.longPressTarget(tester);
          final action =
              find.byKey(const ValueKey('worker-reactivate-completed-work'));
          expect(tester.widget<FilledButton>(action).onPressed, isNull);
          expect(
              find.text(AppLocalizations(const Locale('uz'))
                  .productionText('worker.reactivate.reason.$denial')),
              findsOneWidget);
          expect(fixture.writes, isEmpty);
          if (denial == 'final_stage_closed' || denial == 'order_closed') {
            await tester.tap(
                find.byKey(const ValueKey('worker-reactivate-denial-details')));
            await tester.pumpAndSettle();
            expect(find.byType(AlertDialog), findsOneWidget);
            expect(
                find.descendant(
                    of: find.byType(AlertDialog),
                    matching: find.text(AppLocalizations(const Locale('uz'))
                        .productionText('worker.reactivate.reason.$denial'))),
                findsOneWidget);
            expect(fixture.writes, isEmpty);
            expect(find.byKey(const ValueKey('worker-reactivate-confirm')),
                findsNothing);
          }
        }, () => MockClient(fixture.respond));
      });
    }
  }
  for (final station in [_lamination1Id, _rezkaId]) {
    testWidgets(
        'completed WIP short tap opens details and long press previews reactivation on $station',
        (tester) async {
      final fixture = _ReactivationFixture(station);
      await http.runWithClient(() async {
        await fixture.open(tester);
        final row = find
            .ancestor(
                of: find.textContaining('Reactivation order'),
                matching: find.byType(InkWell))
            .first;
        await tester.longPress(row);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('worker-reactivate-completed-work')),
            findsNothing);
        expect(fixture.requests.where((r) => r.url.path.endsWith('/preview')),
            isEmpty);
        if (find.byType(BottomSheet).evaluate().isNotEmpty) {
          Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
          await tester.pumpAndSettle();
        }
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('worker-wip-item-0')));
        await tester.pumpAndSettle();
        expect(
            find.byKey(const ValueKey(
                'worker-wip-history-preview-reactivation-output')),
            findsOneWidget);
        expect(fixture.requests.where((r) => r.url.path.endsWith('/preview')),
            isEmpty);
        Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
        await tester.pumpAndSettle();
        await tester.longPress(find.byKey(const ValueKey('worker-wip-item-0')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('worker-reactivate-completed-work')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey(
                'worker-wip-history-preview-reactivation-output')),
            findsNothing);
        final previewRequests = fixture.requests
            .where((r) => r.url.path.endsWith('/reactivation/preview'));
        expect(previewRequests, hasLength(1));
        expect(jsonDecode(previewRequests.single.body), {
          'apparatus': station,
          'order_id': _ReactivationFixture.orderId,
          'batch_id': _ReactivationFixture.batchId,
        });
        expect(fixture.writes, isEmpty);
      }, () => MockClient(fixture.respond));
    });
    testWidgets(
        'completed WIP duplicate long press requests one pending preview on $station',
        (tester) async {
      final fixture = _ReactivationFixture(station);
      final pendingPreview = Completer<http.Response>();
      final previewRequests = <http.Request>[];
      await http.runWithClient(() async {
        await fixture.open(tester);
        await tester.tap(find
            .ancestor(
                of: find.textContaining('Reactivation order'),
                matching: find.byType(InkWell))
            .first);
        await tester.pumpAndSettle();
        final wip = find.byKey(const ValueKey('worker-wip-item-0'));
        await tester.longPress(wip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(previewRequests, hasLength(1));
        await tester.longPress(wip);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(previewRequests, hasLength(1),
            reason: 'a second gesture cannot start an overlapping preview');
        expect(find.byKey(const ValueKey('worker-reactivate-completed-work')),
            findsNothing);
        pendingPreview.complete(await fixture.respond(previewRequests.single));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('worker-reactivate-completed-work')),
            findsOneWidget);
        expect(fixture.writes, isEmpty);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/reactivation/preview')) {
                  previewRequests.add(request);
                  return pendingPreview.future;
                }
                return fixture.respond(request);
              }));
    });
  }
}
