part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerLatencyTests() {
  for (final action in ['start', 'resume']) {
    for (final outcome in ['success', 'failure', 'invalid', 'timeout']) {
      testWidgets(
          'worker $action sends one POST without preflight and releases UI before refresh: $outcome',
          (tester) async {
        await TestModeController.instance.setEnabled(true);
        const orderId = 'zakaz-worker-fast-start';
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Worker',
          legalName: '',
          ref: 'worker-fast',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_print7Id],
        );
        await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
          id: orderId,
          title: 'Fast start',
          productCode: 'FAST',
          apparatusId: _print7Id,
          product: 'Fast product',
        ));
        await MobileApi.instance.adminSaveProductionMapSequence(
            apparatus: _print7Id, orderIds: const [orderId]);
        setMobileApiTestModeQueueActionControlFixture(
            apparatus: _print7Id,
            orderId: orderId,
            control: action == 'start'
                ? _freshStartQueueControl()
                : _requeuedQueueControl(ready: true));
        await _usePhoneViewport(tester);
        final requests = <http.Request>[];
        final post = Completer<http.Response>();
        final refresh = Completer<http.Response>();
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
            home: const AdminProductionMapOrdersScreen(
                readOnly: true, workerMode: true),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.text('7 ta rangli bosma aparat'));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('worker-fast-start').first);
          await tester.pumpAndSettle();
          final start = action == 'start'
              ? find.widgetWithText(FilledButton, 'Boshlash')
              : find.descendant(
                  of: find
                      .byKey(const ValueKey('production-order-resume-visible')),
                  matching: find.byType(FilledButton));
          expect(start, findsOneWidget);
          final syncWarning = find.descendant(
            of: find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_OrderStartUnifiedCard'),
            matching: find.text(
                'Ish holati server bilan sinxron emas. Sahifani yangilang.'),
          );
          expect(syncWarning, findsNothing);
          await TestModeController.instance.setEnabled(false);
          // Two callbacks in the same frame must not send two mutations.
          final onPressed = tester.widget<FilledButton>(start).onPressed!;
          onPressed();
          onPressed();
          await tester.pump();
          expect(requests, hasLength(1));
          expect(requests.single.method, 'POST');
          expect(requests.single.url.path, endsWith('/queue-action'));
          expect(jsonDecode(requests.single.body)['action'], action);
          post.complete(http.Response(
              jsonEncode({
                'ok': true,
                'states': {orderId: 'in_progress'},
                'order_status': {
                  'order_status': 'in_progress',
                  'lifecycle_status': 'in_progress'
                },
                'order_control': {'state': 'active'},
                'work_activity': {
                  'worker_role': 'aparatchi',
                  'worker_ref': 'worker-fast',
                  'state': 'in_progress',
                },
              }),
              200));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          // An acknowledged Start must stop showing its old button even while
          // both canonical background refreshes remain deliberately unresolved.
          expect(start, findsNothing);
          expect(syncWarning, findsNothing,
              reason:
                  'a successful write stays silent while its controls refresh');
          await tester.pump(const Duration(seconds: 1));
          expect(syncWarning, findsNothing);
          final row = find.byKey(const ValueKey('worker-order-$orderId'));
          final card = tester.widget<Material>(
              find.descendant(of: row, matching: find.byType(Material)).first);
          expect(
              card.color,
              Color.alphaBlend(
                const Color(0xFF2E7D32).withValues(alpha: 0.16),
                ThemeData(useMaterial3: true)
                    .colorScheme
                    .surfaceContainerLowest,
              ),
              reason:
                  'the authoritative POST colors the card before any refresh returns');
          expect(requests.where((r) => r.method == 'POST'), hasLength(1));
          expect(refresh.isCompleted, isFalse);
          expect(requests.where((r) => r.method == 'GET'), isNotEmpty);
          if (outcome == 'timeout') {
            await tester.pump(const Duration(seconds: 5));
            await tester.pump();
          } else {
            refresh.complete(outcome == 'failure'
                ? http.Response('{"error":"store_failed"}', 503)
                : _workerLatencyRefresh(orderId, valid: outcome == 'success'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
              syncWarning,
              outcome == 'success' || outcome == 'timeout'
                  ? findsNothing : findsOneWidget,
              reason: 'a timed out read retries automatically; failed or invalid settled reads show a sync warning');
          if (outcome == 'timeout') {
            expect(requests.where((r) => r.method == 'GET').length, greaterThan(1));
            expect(start, findsNothing);
          }
          if (outcome == 'success') {
            expect(
                find.widgetWithText(
                    FilledButton,
                    AppLocalizations(const Locale('uz'))
                        .productionText('worker.action.complete')),
                findsOneWidget,
                reason: 'fresh authoritative controls restore the next action');
          }
          expect(requests.where((r) => r.method == 'POST'), hasLength(1));
          await tester.pumpWidget(const SizedBox.shrink());
          if (!refresh.isCompleted) {
            refresh.complete(http.Response('{"error":"store_failed"}', 503));
          }
          await tester.pump();
          await tester.pump(const Duration(seconds: 11));
          expect(tester.takeException(), isNull);
        },
            () => MockClient((request) {
                  requests.add(request);
                  if (request.url.path.endsWith('/order-scan-bootstrap')) {
                    return Future.value(http.Response('', 404));
                  }
                  return request.method == 'POST'
                      ? post.future
                      : refresh.future;
                }));
      });
    }
  }
}

void _registerWorkerColourLatencyTests() {
  for (final action in ['hold', 'passed']) {
    for (final outcome in ['controls', 'legacy', 'timeout', 'reopened', 'live during recovery']) {
      if (action != 'hold' && outcome == 'live during recovery') continue;
      testWidgets('worker colour $action releases UI after one POST: $outcome', (tester) async {
        await TestModeController.instance.setEnabled(true);
        const orderId = 'zakaz-worker-colour';
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi, displayName: 'Worker', legalName: '',
          ref: 'worker-colour', phone: '', avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_print7Id],
        );
        final saved = await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
          id: orderId, title: 'Colour', productCode: 'COLOUR',
          apparatusId: _print7Id, product: 'Colour',
        ));
        final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
        Map<String, dynamic> hold(String status) => {
          'hold_id': 'colour-hold', 'idempotency_key': 'colour-hold',
          'order_id': orderId, 'apparatus': _print7Id, 'status': status,
        };
        Map<String, dynamic> control(String status) => {
          'state': status == 'pending' ? 'pending' : 'print_preflight',
          'allowed_actions': status == 'running' ? [] : ['start'],
          'previous_stage_ready': true, 'complete_requires_full_report': false,
          'print_preflight_allowed': status == 'pending',
          if (status != 'pending') 'print_preflight': hold(status),
          'interaction': {
            'mode': status == 'running' ? 'fresh_start_blocked' : 'fresh_start',
            'start_materials_mode': 'hidden', 'material_scan_required': false,
            'assigned_materials_display_only': true, 'material_intake_allowed': false,
            'previous_wip_mode': 'not_required', 'qolip_mode': 'not_required',
            'blocking_reason_code': status == 'running' ? 'print_preflight_active' : '',
          },
        };
        final initialStatus = action == 'hold' ? 'pending' : 'running';
        var serverStatus = initialStatus;
        var serverRevision = 1;
        setMobileApiTestModeQueueActionControlFixture(apparatus: _print7Id,
          orderId: orderId, control: AdminApparatusQueueOrderActionControl.fromJson(control(initialStatus)));
        await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _print7Id, orderIds: const [orderId]);
        final initial = AdminApparatusQueueSnapshot(
          maps: [saved], sequences: {_print7Id: [orderId]},
          visibleOrderIds: {_print7Id: [orderId]},
          queueStates: {_print7Id: {orderId: initialStatus == 'pending' ? 'pending' : 'print_preflight'}},
          queuePolicies: const {}, orderControls: const {},
          queueActionControls: {_print7Id: {orderId:
            AdminApparatusQueueOrderActionControl.fromJson(control(initialStatus))}},
          epoch: 'colour-server', revision: 1,
        );
        final requests = <http.Request>[];
        final post = Completer<http.Response>();
        final nextPost = Completer<http.Response>();
        final refresh = Completer<http.Response>();
        final live = StreamController<Object>.broadcast();
        addTearDown(live.close);
        var thinReads = 0;
        Map<String, dynamic> bootstrap(String status, int revision) => {
          'ok': true,
          'control_state': {
            'apparatus': _print7Id, 'order_id': orderId,
            'epoch': 'colour-server', 'rev': revision,
            'scope': 'colour-worker-scope', 'control': control(status),
            'queue_state': status == 'pending' ? 'pending' : 'print_preflight',
            'stage_states': {}, 'order_control': 'active',
          },
          'sections': {
            'materials': {'status': 'not_required'},
            'qolips': {'status': 'not_required'},
          },
        };
        AdminProductionMapLiveSnapshot snapshot(String status, int revision) =>
            AdminProductionMapLiveSnapshot.fromJson({
              ...scanSequence(),
              'rev': revision, 'epoch': 'colour-server', 'scope': 'colour-worker-live',
              'maps': [{'map': saved.map.toJson(), 'program': <String, dynamic>{}}],
              'sequences': {_print7Id: [orderId]},
              'visible_order_ids': {_print7Id: [orderId]},
              'queue_states': {_print7Id: {orderId: status == 'pending' ? 'pending' : 'print_preflight'}},
              'queue_action_controls': {_print7Id: {orderId: control(status)}},
              'stage_states': {}, 'order_controls': {}, 'queue_policies': [],
            });
        await _usePhoneViewport(tester);
        await http.runWithClient(() async {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(useMaterial3: true), locale: const Locale('uz'),
            localizationsDelegates: const [AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
            home: AdminProductionMapOrdersScreen(readOnly: true, workerMode: true,
              queueSnapshotLoader: () async => outcome == 'live during recovery'
                  ? snapshot(initialStatus, 1) : initial,
              liveEventsLoader: outcome == 'live during recovery' ? () => live.stream : null,
              apparatusLoader: () async => apparatus),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.text('7 ta rangli bosma aparat'));
          await tester.pumpAndSettle();
          await tester.tap(find.textContaining('worker-colour').first);
          await tester.pumpAndSettle();
          final button = find.widgetWithText(FilledButton,
            AppLocalizations(const Locale('uz')).productionText(action == 'hold'
              ? 'worker.action.print_preflight' : 'worker.action.print_preflight_passed'));
          expect(button, findsOneWidget);
          await TestModeController.instance.setEnabled(false);
          final onPressed = tester.widget<FilledButton>(button).onPressed!;
          onPressed(); onPressed();
          await tester.pump();
          expect(requests, hasLength(1));
          expect(requests.single.method, 'POST');
          expect(requests.single.url.path, endsWith('/print-preflight'));
          expect(jsonDecode(requests.single.body)['action'], action);
          if (outcome == 'reopened') {
            final dynamic open = tester.widget(find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
            open.onClose();
            await tester.pumpAndSettle();
            await tester.tap(find.textContaining('worker-colour').first);
            await tester.pumpAndSettle();
            final dynamic reopened = tester.widget(find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
            expect(reopened.actionInFlight, isTrue);
            expect(tester.widget<FilledButton>(button).onPressed, isNull);
          }
          if (outcome == 'timeout') {
            await tester.pump(const Duration(seconds: 21));
          } else {
            final status = action == 'hold' ? 'running' : 'passed';
            serverStatus = status;
            serverRevision = 2;
            post.complete(http.Response(jsonEncode({
              'ok': true, 'hold': hold(status),
              if (outcome == 'controls' || outcome == 'reopened') 'control_state': {
                'apparatus': _print7Id, 'order_id': orderId, 'epoch': 'colour-server',
                'rev': 2, 'control': control(status), 'queue_state': 'print_preflight',
                'stage_states': {}, 'order_control': 'active',
              },
            }), 200));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(requests.where((r) => r.method == 'POST'), hasLength(1));
          if (outcome == 'controls' || outcome == 'reopened') {
            if (outcome == 'controls') {
              expect(requests.where((r) => r.method == 'GET'), isEmpty);
            }
            final dynamic content = tester.widget(find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
            expect(content.actionInFlight, isFalse);
            expect(content.uiState.contractSynchronized, isTrue);
            if (action == 'hold') {
              final passed = find.widgetWithText(FilledButton,
                AppLocalizations(const Locale('uz')).productionText('worker.action.print_preflight_passed'));
              expect(passed, findsOneWidget);
              expect(tester.widget<FilledButton>(passed).onPressed, isNotNull);
            }
          } else {
            expect(requests.where((r) => r.method == 'GET'), isNotEmpty);
            expect(find.byKey(const ValueKey('production-order-print-preflight-outcome')), findsNothing,
              reason: 'uncertain or missing controls cannot reuse old colour permissions');
          }
          if (outcome == 'live during recovery') {
            expect(thinReads, 1);
            live.add(snapshot('running', 2));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final passed = find.widgetWithText(FilledButton,
                AppLocalizations(const Locale('uz')).productionText('worker.action.print_preflight_passed'));
            final callback = tester.widget<FilledButton>(passed).onPressed!;
            callback(); callback();
            await tester.pump();
            expect(requests.where((r) => r.method == 'POST'), hasLength(2));
            serverStatus = 'passed';
            serverRevision = 3;
            nextPost.complete(http.Response(jsonEncode({'ok': true, 'hold': hold('passed')}), 200));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final dynamic content = tester.widget(find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
            expect(thinReads, 2, reason: 'a new ACK must bypass an obsolete pending read');
            expect(refresh.isCompleted, isFalse);
            expect(content.uiState.contractSynchronized, isTrue);
            expect(content.uiState.printPreflight.isPassed, isTrue);
            refresh.complete(http.Response(jsonEncode(bootstrap('running', 2)), 200));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            final dynamic settled = tester.widget(find.byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
            expect(settled.uiState.printPreflight.isPassed, isTrue);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          if (!post.isCompleted) post.complete(http.Response('{"error":"store_failed"}', 503));
          if (!refresh.isCompleted) refresh.complete(http.Response('{"error":"store_failed"}', 503));
          await tester.pump();
          await tester.pump(const Duration(seconds: 12));
          expect(tester.takeException(), isNull);
        }, () => MockClient((request) {
          requests.add(request);
          if (outcome == 'live during recovery') {
            if (request.method == 'POST' && requests.where((r) => r.method == 'POST').length > 1) {
              return nextPost.future;
            }
            if (request.url.path.endsWith('/order-scan-bootstrap')) {
              thinReads++;
              return thinReads == 1 ? refresh.future : Future.value(
                  http.Response(jsonEncode(bootstrap(serverStatus, serverRevision)), 200));
            }
          }
          if (outcome == 'reopened' && request.method == 'GET') {
            return Future.value(http.Response(jsonEncode(
                request.url.path.endsWith('/order-scan-bootstrap')
                    ? bootstrap(serverStatus, serverRevision) : {}), 200));
          }
          return request.method == 'POST' ? post.future : refresh.future;
        }));
      });
    }
  }
}

http.Response _workerLatencyRefresh(String orderId, {required bool valid}) =>
    http.Response(
        jsonEncode({
          'sequences': {
            _print7Id: [orderId]
          },
          'visible_order_ids': {
            _print7Id: [orderId]
          },
          'queue_states': {
            _print7Id: {orderId: 'in_progress'}
          },
          'stage_states': {},
          'queue_policies': [],
          'queue_action_controls': {
            _print7Id: {
              orderId: {
                'state': 'in_progress',
                'allowed_actions': ['pause', 'complete'],
                'previous_stage_ready': true,
                'complete_requires_full_report': false,
                if (valid)
                  'interaction': {
                    'mode': 'in_progress',
                    'start_materials_mode': 'hidden',
                    'material_scan_required': false,
                    'assigned_materials_display_only': true,
                    'material_intake_allowed': false,
                    'previous_wip_mode': 'not_required',
                    'opening_wip_mode': 'not_required',
                    'qolip_mode': 'not_required',
                    'blocking_reason_code': '',
                  },
              }
            },
          },
          'order_controls': {
            orderId: {'state': 'active'}
          },
          'order_statuses': {},
          'frozen_orders_by_apparatus': {},
        }),
        200);
