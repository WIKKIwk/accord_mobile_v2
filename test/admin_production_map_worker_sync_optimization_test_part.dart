part of 'admin_production_map_test_screen_test.dart';

Map<String, dynamic> _syncControl(String state) => {
      ...scanControl(),
      'state': state,
      'allowed_actions': state == 'pending'
          ? ['start']
          : state == 'frozen'
              ? <String>[]
              : ['pause', 'complete'],
      'interaction': {
        'mode': state == 'pending' ? 'fresh_start' : state,
        'start_materials_mode': 'hidden',
        'material_scan_required': false,
        'assigned_materials_display_only': true,
        'material_intake_allowed': false,
        'previous_wip_mode': 'not_required',
        'opening_wip_mode': 'not_required',
        'qolip_mode': 'not_required',
      },
    };

Map<String, dynamic> _syncBootstrap(int revision, String state) {
  final result = scanBootstrap(revision: revision);
  result['control_state']['control'] = _syncControl(state);
  result['control_state']['queue_state'] = state;
  result['control_state']['order_control'] =
      state == 'frozen' ? 'frozen' : 'active';
  result['sections'] = {
    'materials': {'status': 'not_required'},
    'qolips': {'status': 'not_required'},
  };
  return result;
}

AdminProductionMapLiveSnapshot _syncLive(
        ProductionMapSaved order, int revision, String state) =>
    AdminProductionMapLiveSnapshot.fromJson({
      ...scanSequence(),
      'rev': revision,
      'scope': 'worker-live-scope',
      'maps': [
        {'map': order.map.toJson(), 'program': <String, dynamic>{}}
      ],
      'queue_states': {
        scanApparatus: {scanOrder: state}
      },
      'queue_action_controls': {
        scanApparatus: {scanOrder: _syncControl(state)}
      },
      'order_controls': {
        scanOrder: {'state': state == 'frozen' ? 'frozen' : 'active'}
      },
    });

void _registerWorkerSyncOptimizationTests() {
  for (final ordering in [
    'live before ACK',
    'live after ACK',
    'newer freeze before ACK',
    'missing live',
    'history-only delta',
    'lost ACK',
    'account change'
  ]) {
    testWidgets('worker sync optimization: $ordering', (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      final events = StreamController<Object>.broadcast();
      addTearDown(events.close);
      var snapshotReads = 0;
      var state = 'pending';
      var revision = 7;
      final requests = <http.Request>[];
      final post = Completer<http.Response>();
      await http.runWithClient(() async {
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
              queueSnapshotLoader: () async {
                snapshotReads++;
                return _syncLive(fixture.order, revision, state);
              },
              apparatusLoader: () async => fixture.apparatus,
              liveEventsLoader: () => events.stream),
        ));
        await tester.pumpAndSettle();
        events.add(_syncLive(fixture.order, 7, 'pending'));
        await tester.pump();
        await tester.tap(find.text('7 ta rangli bosma aparat'));
        await tester.pumpAndSettle();
        await TestModeController.instance.setEnabled(false);
        await tester.tap(find.textContaining('scan-bootstrap').first);
        await tester.pumpAndSettle();
        final baselineReads = snapshotReads;
        requests.clear();
        final button = find.widgetWithText(FilledButton, 'Boshlash');
        expect(button, findsOneWidget);
        final callback = tester.widget<FilledButton>(button).onPressed!;
        callback();
        callback();
        await tester.pump();
        expect(requests.where((r) => r.url.path.endsWith('/queue-action')),
            hasLength(1));
        state = ordering == 'newer freeze before ACK'
            ? 'frozen'
            : ordering == 'history-only delta'
                ? 'pending'
                : 'in_progress';
        revision = ordering == 'newer freeze before ACK' ? 9 : 8;
        if (ordering == 'live before ACK' ||
            ordering == 'newer freeze before ACK') {
          events.add(_syncLive(fixture.order, revision, state));
          await tester.pump();
        }
        if (ordering == 'account change') {
          await AppSession.instance.setSession(
              token: 'other-token',
              profile: const SessionProfile(
                  role: UserRole.aparatchi,
                  displayName: 'Other worker',
                  legalName: '',
                  ref: 'other-worker',
                  phone: '',
                  avatarUrl: '',
                  capabilities: ['apparatus.queue.read'],
                  assignedApparatus: [scanApparatus]));
        }
        post.complete(http.Response(
            jsonEncode({
              'ok': true,
              'rev': 8,
              'epoch': 'scan-server',
              'states': {
                scanOrder:
                    ordering == 'history-only delta' ? 'pending' : 'in_progress'
              },
              'order_control': {'state': 'active'},
            }),
            ordering == 'lost ACK' ? 503 : 200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        if (ordering == 'live after ACK') {
          events.add(_syncLive(fixture.order, 8, 'in_progress'));
          await tester.pump();
        }
        if (ordering == 'history-only delta') {
          events.add(AdminProductionMapLiveStateDelta.fromJson({
            'epoch': 'scan-server',
            'scope': 'worker-live-scope',
            'base_rev': 7,
            'rev': 8,
            'patch': <String, dynamic>{},
          }));
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(
            snapshotReads,
            baselineReads +
                (ordering == 'missing live' || ordering == 'lost ACK' ? 1 : 0));
        expect(requests.where((r) => r.url.path.endsWith('/queue-action')),
            hasLength(1));
        expect(
            requests.where((r) =>
                r.url.path.endsWith('/completed-orders') ||
                r.url.path.endsWith('/completion-request-decisions') ||
                r.url.path.endsWith('/sequence')),
            isEmpty);
        if (ordering == 'live before ACK' ||
            ordering == 'live after ACK' ||
            ordering == 'newer freeze before ACK') {
          expect(requests.where((r) => r.method == 'GET'), hasLength(1));
        }
        final dynamic content = tester.widget(find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
        if (ordering == 'account change') {
          expect(content.uiState.contractSynchronized, isFalse);
        } else {
          expect(content.queueStates[scanOrder], state);
          expect(content.uiState.contractSynchronized, isTrue);
          expect(content.uiState.showStart, state == 'pending');
          expect(content.uiState.showComplete, state == 'in_progress');
          if (ordering == 'history-only delta') {
            expect(
                content.queueActionControlsByApparatus[scanApparatus][scanOrder]
                    .state,
                'pending');
          }
          expect(
              find.text(
                  'Ish holati server bilan sinxron emas. Sahifani yangilang.'),
              findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 12));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) {
                requests.add(request);
                if (request.url.path.endsWith('/queue-action'))
                  return post.future;
                if (request.url.path.endsWith('/order-scan-bootstrap')) {
                  return Future.value(http.Response(
                      jsonEncode(_syncBootstrap(revision, state)), 200));
                }
                return Future.value(http.Response('{}', 200));
              }));
    });
  }

  for (final failure in ['503', 'timeout']) {
    testWidgets(
        'worker sync optimization: detail automatically recovers from $failure',
        (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      var reads = 0;
      final pending = Completer<http.Response>();
      await http.runWithClient(() async {
        await _openScanBootstrapFixture(tester, fixture);
        await tester.pumpAndSettle();
        if (failure == 'timeout') await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(reads, 2);
        _expectScanBootstrapLoaded(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        if (!pending.isCompleted) pending.complete(http.Response('{}', 503));
        await tester.pump(const Duration(seconds: 12));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) {
                if (request.url.path.endsWith('/order-scan-bootstrap')) {
                  reads++;
                  if (reads == 1)
                    return failure == 'timeout'
                        ? pending.future
                        : Future.value(
                            http.Response('{"error":"store_failed"}', 503));
                  return Future.value(
                      http.Response(jsonEncode(scanBootstrap()), 200));
                }
                return Future.value(http.Response('{}', 200));
              }));
    });
  }

  testWidgets(
      'worker sync optimization: open sheet observes freeze and rejects old bootstrap',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await _openScanBootstrapFixture(tester, fixture);
      await tester.pump();
      fixture.live.add(_syncLive(fixture.order, 8, 'frozen'));
      await tester.pump();
      pending.complete(http.Response(jsonEncode(scanBootstrap()), 200));
      await tester.pumpAndSettle();
      final dynamic content = tester.widget(find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
      expect(content.queueStates[scanOrder], 'frozen');
      expect(content.uiState.contractSynchronized, isTrue);
      expect(content.showQuickScanner, isFalse);
      expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 12));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) =>
            request.url.path.endsWith('/order-scan-bootstrap')
                ? pending.future
                : Future.value(http.Response('{}', 200))));
  });
}
