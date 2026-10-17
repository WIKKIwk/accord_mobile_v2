part of 'admin_production_map_test_screen_test.dart';

/// Unlike test-mode queue reads, this fixture really omits the scanned order
/// from the parent window while retaining its authoritative scoped controls.
class _WorkerQrWindowFixture extends _InlineWipFixture {
  _WorkerQrWindowFixture(this.scenario) : super('start') {
    useOpening = scenario == 'opening WIP';
    if (scenario == 'frozen') phase = 'frozen';
    if (scenario.startsWith('handoff return')) phase = 'busy';
  }

  final String scenario;
  final windowReads = <http.Request>[];
  int scopedControlReads = 0;
  int mapReads = 0;
  final mapReadOrderIds = <String>[];

  bool get hideCurrent => scenario == 'handoff return with hidden current';

  Map<String, dynamic> windowSequence() {
    final body = sequence();
    body['scope'] = 'worker-window-10';
    body['maps'] = [
      {
        'map': maps.last.map.toJson(),
        'program': {'map_id': maps.last.map.id, 'operations': []},
      },
    ];
    body['sequences'] = {
      station: [_inlineOtherOrderId],
    };
    body['visible_order_ids'] = {
      station: [_inlineOtherOrderId],
    };
    body['queue_states'] = {
      station: {_inlineOtherOrderId: control(other: true)['state']},
    };
    body['queue_action_controls'] = {
      station: {_inlineOtherOrderId: control(other: true)},
    };
    body['order_controls'] = {};
    if (hideCurrent) {
      body['maps'] = [];
      body['sequences'] = {station: <String>[]};
      body['visible_order_ids'] = {station: <String>[]};
      body['queue_states'] = {station: <String, String>{}};
      body['queue_action_controls'] = {station: <String, dynamic>{}};
    }
    return body;
  }

  @override
  AdminProductionMapLiveSnapshot snapshot() => AdminProductionMapLiveSnapshot(
        maps: [maps.last],
        sequences: {
          station: [_inlineOtherOrderId],
        },
        visibleOrderIds: {
          station: [_inlineOtherOrderId],
        },
        queueStates: {
          station: {
            _inlineOtherOrderId: control(other: true)['state'] as String
          },
        },
        queuePolicies: const {},
        queueActionControls: {
          station: {
            _inlineOtherOrderId: AdminApparatusQueueOrderActionControl.fromJson(
                control(other: true)),
          },
        },
        orderControls: const {},
        completedOrders: const [],
        completionRequests: const [],
        completionRequestDecisions: const [],
        revision: revision,
        epoch: 'inline-server',
        scope: 'worker-window-10',
      );

  @override
  Map<String, dynamic> batch({bool other = false}) => {
        ...super.batch(other: other),
        if (scenario == 'wrong route') 'next_apparatus': _rezkaId,
      };

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/sequence')) {
      requests.add(request);
      if ((request.url.queryParameters['apparatus'] ?? '').isEmpty) {
        windowReads.add(request);
        return http.Response(jsonEncode(windowSequence()), 200);
      }
      scopedControlReads++;
      // Modern scoped queue reads return controls without global map bodies.
      final body = sequence()..['maps'] = <Object>[];
      return http.Response(jsonEncode(body), 200);
    }
    if (path.endsWith('/order-scan-bootstrap')) {
      requests.add(request);
      scopedControlReads++;
      if (scenario == 'bootstrap forbidden') {
        return http.Response('{"error":"forbidden"}', 403);
      }
      final orderId = request.url.queryParameters['order_id']!;
      final current = control(other: orderId == _inlineOtherOrderId);
      return http.Response(
        jsonEncode({
          'ok': true,
          'control_state': {
            'apparatus': station,
            'order_id': orderId,
            'rev': scenario == 'stale bootstrap' ? revision - 1 : revision,
            'epoch': 'inline-server',
            'scope': 'scanned-order-scope',
            'control': current,
            'queue_state': current['state'],
            'stage_states': {},
            'order_control': phase == 'frozen' ? 'frozen' : 'active',
          },
          'sections': {},
        }),
        200,
      );
    }
    if (path.endsWith('/production-maps') &&
        const [_inlineOrderId, _inlineOtherOrderId]
            .contains(request.url.queryParameters['id'])) {
      requests.add(request);
      mapReads++;
      final orderId = request.url.queryParameters['id']!;
      mapReadOrderIds.add(orderId);
      return http.Response(
        jsonEncode({
          'map':
              maps.firstWhere((order) => order.map.id == orderId).map.toJson(),
          'program': {},
        }),
        200,
      );
    }
    if (path.endsWith('/completed-orders')) {
      requests.add(request);
      return http.Response('{"completed_orders":[]}', 200);
    }
    if (path.endsWith('/completion-request-decisions')) {
      requests.add(request);
      return http.Response('{"decisions":[]}', 200);
    }
    return super.respond(request);
  }

  Future<void> openWindow(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Window worker',
      legalName: '',
      ref: 'qr-window-worker',
      phone: '',
      avatarUrl: '',
      capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [station],
    );
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    maps = [
      for (final other in [false, true])
        ProductionMapSaved.fromJson({
          'map': _twoStageProductionOrderMap(
            id: other ? _inlineOtherOrderId : _inlineOrderId,
            title: other ? 'Other visible order' : 'Order outside window',
            productCode: other ? 'VISIBLE' : 'OUTSIDE',
            product: 'Window product',
            firstApparatusId: _print9Id,
            secondApparatusId:
                !other && scenario == 'wrong route' ? _rezkaId : station,
          ).copyWith(orderNumber: other ? '0001' : '0062').toJson(),
          'program': <String, dynamic>{},
        }),
    ];
    await TestModeController.instance.setEnabled(false);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      onGenerateRoute: (_) => MaterialPageRoute<String>(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('return-window-qr'),
            onPressed: () => Navigator.of(context).pop(_inlineWipQr),
            child: const Text('Scan window WIP'),
          ),
        ),
      ),
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        apparatusLoader: () async => apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ko‘rsatish: 10 ta'), findsOneWidget);
    expect(find.byKey(const ValueKey('worker-order-$_inlineOrderId')),
        findsNothing);
    if (scenario == 'search') {
      await tester.enterText(find.byType(EditableText).first, 'Other visible');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(windowReads.last.url.queryParameters['queue_search'],
          'Other visible');
    }
  }

  Future<void> scanFab(WidgetTester tester) async {
    final scan = tester
        .widget<AparatchiDock>(find.byType(AparatchiDock))
        .onQrScanRequested!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('return-window-qr')));
    await tester.pumpAndSettle();
    await scan;
    await tester.pumpAndSettle();
  }
}

void _registerWorkerQrWindowTests() {
  for (final scenario in [
    'handoff return',
    'handoff return with hidden current'
  ]) {
    testWidgets('worker FAB QR outside queue window: $scenario',
        (tester) async {
      final fixture = _WorkerQrWindowFixture(scenario);
      await http.runWithClient(() async {
        try {
          await fixture.openWindow(tester);
          await fixture.scanFab(tester);
          expect(find.byKey(const ValueKey('production-switch-order-confirm')),
              findsOneWidget);
          await tester.tap(find.text(AppLocalizations(const Locale('uz'))
              .productionText('worker.action.no')));
          await tester.pumpAndSettle();
          final sheet = find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');
          expect(sheet, findsOneWidget);
          expect(find.text('0001'), findsOneWidget);
          if (fixture.hideCurrent) {
            expect(fixture.mapReadOrderIds, contains(_inlineOtherOrderId),
                reason:
                    'Current work hidden by search must be read individually');
          }
          // Exercise the parent's successful-handoff return boundary directly;
          // the existing completion-report suite owns the transaction itself.
          fixture.phase = 'start';
          fixture.revision++;
          Navigator.of(tester.element(sheet)).pop(true);
          await tester.pumpAndSettle();
          expect(sheet, findsOneWidget);
          expect(find.text('0062'), findsOneWidget);
          final start = find.widgetWithText(FilledButton, 'Boshlash');
          expect(start, findsOneWidget);
          expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
          expect(fixture.mutations, isEmpty);
          expect(
              fixture.windowReads.every(
                  (read) => read.url.queryParameters['queue_limit'] == '10'),
              isTrue);
          expect(find.text('Ko‘rsatish: 10 ta'), findsOneWidget);
        } finally {
          dismissAdminTopNotice();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await fixture.events.close();
        }
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final scenario in [
    'limit 10',
    'search',
    'opening WIP',
    'same revision omitted live snapshot',
    'newer omitted live snapshot',
    'frozen after omitted live snapshot',
    'frozen',
    'wrong route',
    'bootstrap forbidden',
    'stale bootstrap',
  ]) {
    testWidgets('worker FAB QR outside queue window: $scenario',
        (tester) async {
      final fixture = _WorkerQrWindowFixture(scenario);
      await http.runWithClient(() async {
        try {
          await fixture.openWindow(tester);
          await fixture.scanFab(tester);
          expect(fixture.mapReads, greaterThan(0));
          final sheet = find.byWidgetPredicate(
            (widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet',
          );
          final start = find.widgetWithText(FilledButton, 'Boshlash');
          if (const [
            'frozen',
            'wrong route',
            'bootstrap forbidden',
            'stale bootstrap'
          ].contains(scenario)) {
            expect(sheet, findsNothing);
            expect(start, findsNothing);
            expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
                findsOneWidget);
            if (scenario == 'bootstrap forbidden') {
              expect(
                  fixture.requests.where((request) =>
                      request.url.path.endsWith('/order-scan-bootstrap')),
                  hasLength(1));
              expect(
                  fixture.requests.where((request) =>
                      request.url.path.endsWith('/sequence') &&
                      request.url.queryParameters.containsKey('apparatus')),
                  hasLength(0),
                  reason:
                      'Permission denial must not retry through a legacy fallback');
            }
            if (scenario == 'stale bootstrap') {
              expect(
                  fixture.requests.where((request) =>
                      request.url.path.endsWith('/order-scan-bootstrap')),
                  hasLength(2),
                  reason: 'Revision disagreement gets only the bounded retry');
            }
          } else {
            expect(sheet, findsOneWidget);
            expect(find.text('0062'), findsOneWidget);
            expect(start, findsOneWidget,
                reason: tester
                    .widgetList<Text>(find.byType(Text))
                    .map((text) => text.data)
                    .toList()
                    .toString());
            expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
            expect(find.byType(ProductionQuickScannerPanel), findsNothing);
            if (scenario == 'same revision omitted live snapshot' ||
                scenario == 'newer omitted live snapshot' ||
                scenario == 'frozen after omitted live snapshot') {
              if (scenario == 'frozen after omitted live snapshot') {
                fixture.phase = 'frozen';
              }
              final readsBeforeLive = fixture.scopedControlReads;
              if (scenario != 'same revision omitted live snapshot') {
                fixture.revision++;
              }
              fixture.events.add(fixture.snapshot());
              await tester.pumpAndSettle();
              await tester.pump(const Duration(seconds: 2));
              await tester.pumpAndSettle();
              if (scenario == 'frozen after omitted live snapshot') {
                expect(
                    tester
                        .widgetList<FilledButton>(start)
                        .every((button) => button.onPressed == null),
                    isTrue,
                    reason:
                        'A projected omission cannot preserve a stale Start '
                        'after the authoritative order becomes frozen');
              } else {
                expect(start, findsOneWidget);
                expect(tester.widget<FilledButton>(start).onPressed, isNotNull,
                    reason:
                        'An unrelated projected snapshot must trigger a scoped '
                        'refresh rather than permanently losing this order');
                if (scenario == 'same revision omitted live snapshot') {
                  expect(fixture.scopedControlReads, readsBeforeLive,
                      reason: 'Same-revision projection omission does not '
                          'invalidate the accepted scoped contract');
                }
              }
            }
            expect(fixture.scopedControlReads, greaterThan(0));
          }
          expect(fixture.mutations, isEmpty,
              reason: 'Scanning only prepares the explicit start action');
          expect(fixture.windowReads, isNotEmpty);
          expect(
              fixture.windowReads.every(
                  (read) => read.url.queryParameters['queue_limit'] == '10'),
              isTrue,
              reason: 'QR resolution must not widen the main queue');
          expect(find.text('Ko‘rsatish: 10 ta'), findsOneWidget);
          if (scenario == 'search') {
            expect(fixture.windowReads.last.url.queryParameters['queue_search'],
                'Other visible',
                reason:
                    'Opening a QR outside search must keep the chosen query');
          }
          for (final request in fixture.requests.where(
              (request) => request.url.path.endsWith('/progress-qr/lookup'))) {
            final payload = jsonDecode(request.body) as Map;
            expect(payload['require_active_order'], isTrue);
            if (payload.containsKey('apparatus')) {
              expect(payload['apparatus'], _lamination1Id);
              expect(payload['order_id'], _inlineOrderId);
            }
          }
        } finally {
          dismissAdminTopNotice();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await fixture.events.close();
        }
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }
}
