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
        final live = StreamController<Object>.broadcast();
        addTearDown(live.close);
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
              liveEventsLoader: () => live.stream,
            ),
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
          // Hold revisions belong to print-preflight; queue actions validate
          // the current production state when committing the command.
          expect(jsonDecode(requests.single.body),
              isNot(contains('expected_revision')));
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
          expect(syncWarning, findsNothing,
              reason: 'read recovery must not revive the preceding action card');
          if (outcome != 'success') {
            await tester.pump(const Duration(seconds: 2));
            await tester.pump();
            expect(requests.where((r) => r.method == 'GET').length, greaterThan(1));
            expect(start, findsNothing);
            final dynamic content = tester.widget(find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() ==
                    '_ReadOnlyOrderDetailContent'));
            expect(content.uiState.contractSynchronized, isFalse);
            expect(content.actionInFlight, isFalse);
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
  _registerWorkerColourSectionTransitionTests();
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

void _registerWorkerColourSectionTransitionTests() {
  const manualQolipOutcomes = {
    'ready',
    'read failure',
    'old assignment',
    'live before ACK',
    'live after ACK',
  };
  for (final action in ['failed', 'passed']) {
    for (final outcome in [
      'ready',
      'read failure',
      'old assignment',
      'live before ACK',
      'live after ACK',
      'transient parse failure',
      'old failed assignment',
      'transient server failure',
      'permanent server failure',
      'repeated parse failures',
      'background retry',
      'dispose retry',
    ]) {
      if (action != 'passed' && !manualQolipOutcomes.contains(outcome)) {
        continue;
      }
      testWidgets('worker colour $action refreshes required sections: $outcome',
          (tester) async {
        final automatic = !manualQolipOutcomes.contains(outcome);
        final recoverableReadFailure = const {
          'transient parse failure',
          'transient server failure',
          'repeated parse failures',
          'background retry',
          'dispose retry',
        }.contains(outcome);
        await TestModeController.instance.setEnabled(true);
        const orderId = 'zakaz-colour-sections';
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Colour sections worker',
          legalName: '',
          ref: 'colour-sections-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_print7Id],
        );
        final saved = await MobileApi.instance.adminSaveProductionMap(
          _productionOrderMap(
            id: orderId,
            title: 'Colour',
            productCode: 'CSEC',
            apparatusId: _print7Id,
            product: 'Colour',
          ),
        );
        final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
        Map<String, dynamic> hold(String status) => {
              'hold_id': 'colour-sections-hold',
              'idempotency_key': 'colour-sections-hold',
              'order_id': orderId,
              'apparatus': _print7Id,
              'status': status,
            };
        Map<String, dynamic> control(String status) => {
              'state': status == 'failed' ? 'pending' : 'print_preflight',
              'allowed_actions': status == 'running' ? [] : ['start'],
              'previous_stage_ready': true,
              'complete_requires_full_report': false,
              'print_preflight_allowed': status == 'failed',
              if (status != 'failed') 'print_preflight': hold(status),
              'interaction': {
                'mode': status == 'running'
                    ? 'fresh_start_blocked'
                    : 'fresh_start',
                'start_materials_mode':
                    status == 'running' ? 'hidden' : 'scan_required',
                'material_scan_required': status != 'running',
                'assigned_materials_display_only': true,
                'material_intake_allowed': false,
                'previous_wip_mode': 'not_required',
                'opening_wip_mode': 'not_required',
                'qolip_mode':
                    status == 'running' ? 'not_required' : 'scan_required',
                'blocking_reason_code':
                    status == 'running' ? 'print_preflight_active' : '',
                if (automatic && status != 'running') ...{
                  'qolip_automatic_confirmation': true,
                  'qolip_policy_revision': 1,
                },
              },
            };
        final live = StreamController<Object>.broadcast();
        addTearDown(live.close);
        AdminProductionMapLiveSnapshot snapshot(String status, int revision) =>
            AdminProductionMapLiveSnapshot.fromJson({
              ...scanSequence(),
              'epoch': 'colour-sections-server',
              'rev': revision,
              'scope': 'colour-sections-live',
              'maps': [
                {'map': saved.map.toJson(), 'program': <String, dynamic>{}},
              ],
              'sequences': {_print7Id: [orderId]},
              'visible_order_ids': {_print7Id: [orderId]},
              'queue_states': {
                _print7Id: {
                  orderId: status == 'failed' ? 'pending' : 'print_preflight',
                },
              },
              'queue_action_controls': {
                _print7Id: {orderId: control(status)},
              },
              'stage_states': {},
              'order_controls': {},
              'queue_policies': [],
            });
        setMobileApiTestModeQueueActionControlFixture(
          apparatus: _print7Id,
          orderId: orderId,
          control: AdminApparatusQueueOrderActionControl.fromJson(
            control('running'),
          ),
        );
        await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _print7Id,
          orderIds: const [orderId],
        );
        final requests = <http.Request>[];
        final materialReadTimes = <DateTime>[];
        var sectionRevision = 2;
        final post = Completer<http.Response>();
        final materials = Completer<http.Response>();
        final oldAssignments = Completer<http.Response>();
        final requirements = {
          ...scanMaterials(),
          'assignments': [
            {...scanAssignment(), 'order_id': orderId},
          ],
          'start_assignments': [
            {...scanAssignment(), 'order_id': orderId},
          ],
        };
        Finder detail() => find.byWidgetPredicate((widget) =>
            widget.runtimeType.toString() == '_ReadOnlyOrderDetailContent');
        await _usePhoneViewport(tester);
        await http.runWithClient(() async {
          await tester.pumpWidget(MaterialApp(
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
              queueSnapshotLoader: () async => snapshot('running', 1),
              apparatusLoader: () async => apparatus,
              liveEventsLoader: () => live.stream,
            ),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.text('7 ta rangli bosma aparat'));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          dynamic content = tester.widget(detail());
          expect(content.uiState.contractSynchronized, isTrue,
              reason: 'the running colour fixture must load before the action');
          expect(content.uiState.showStartMaterials, isFalse);
          await TestModeController.instance.setEnabled(false);
          if (const {'old assignment', 'old failed assignment'}.contains(outcome)) {
            content.onToggleMaterialsExpanded();
            await tester.pump();
            expect(requests.where((request) => request.url.path
                .endsWith('/raw-material-assignments')), hasLength(1));
          }
          final VoidCallback onPressed = action == 'failed'
              ? content.onPrintPreflightFailed
              : content.onPrintPreflightPassed;
          onPressed();
          await tester.pump();
          expect(requests.where((request) => request.method == 'POST' &&
              request.url.path.endsWith('/print-preflight')), hasLength(1));
          if (outcome == 'live before ACK') {
            live.add(snapshot(action, 2));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          post.complete(http.Response(jsonEncode({
            'ok': true,
            'hold': hold(action),
            'control_state': {
              'apparatus': _print7Id,
              'order_id': orderId,
              'epoch': 'colour-sections-server',
              'rev': 2,
              'control': control(action),
              'queue_state': action == 'failed' ? 'pending' : 'print_preflight',
              'stage_states': {},
              'order_control': 'active',
            },
          }), 200));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          if (outcome == 'live after ACK') {
            live.add(snapshot(action, 2));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          content = tester.widget(detail());
          expect(content.actionInFlight, isFalse,
              reason: 'accepted controls release the mutation immediately');
          expect(content.uiState.contractSynchronized, isTrue);
          expect(content.uiState.showStartMaterials, isTrue);
          expect(content.materialStartReady, isFalse);
          expect(content.materialStartBlockingText, isEmpty,
              reason: 'a pending requirements read is not a failed rule');
          expect(find.text('Homashyo qoidasi yuklanmadi'), findsNothing);
          expect(requests.where((request) => request.url.path
              .endsWith('/raw-material-start-requirements')), hasLength(1));
          expect(requests.where((request) => request.url.path
              .endsWith('/qolip-validate')), hasLength(1));
          expect(requests.where((request) => request.url.path
              .endsWith('/order-scan-bootstrap')), isEmpty,
              reason: 'an authoritative ACK needs sections, not another control read');
          if (outcome == 'background retry') {
            tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.paused);
            await tester.pump();
          }
          final http.Response firstMaterialRead;
          if (outcome == 'permanent server failure') {
            firstMaterialRead = http.Response(
                '{"error":"raw_material_rule_missing"}', 400);
          } else if (const {'read failure', 'transient server failure'}
              .contains(outcome)) {
            firstMaterialRead = http.Response(jsonEncode({
              'error': 'raw_material_rule_load_failed',
              'message': 'Colour requirement read failed',
            }), 503);
          } else if (recoverableReadFailure) {
            firstMaterialRead = http.Response(
                '<html>Temporary preview failure</html>', 200);
          } else {
            firstMaterialRead = http.Response(jsonEncode(requirements), 200);
          }
          materials.complete(firstMaterialRead);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          content = tester.widget(detail());
          if (recoverableReadFailure) {
            expect(content.materialStartReady, isFalse);
            if (outcome != 'transient server failure') {
              if (outcome != 'background retry') {
                expect(content.materialsError,
                    'Homashyo ma’lumotlarini yuklab bo‘lmadi. Qayta tekshirilmoqda.');
              }
              expect(find.text('Amal bajarilmadi'), findsNothing,
                  reason: 'a failed read must not imply the colour write failed');
            }
            if (outcome == 'dispose retry') {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(seconds: 3));
              expect(
                  requests.where((r) => r.url.path
                      .endsWith('/raw-material-start-requirements')),
                  hasLength(1));
              expect(
                  requests.where((r) => r.url.path
                      .endsWith('/order-scan-bootstrap')),
                  isEmpty,
                  reason: 'disposing the sheet cancels its pending recovery');
            } else {
              if (outcome == 'background retry') {
                await tester.pump(const Duration(seconds: 3));
                expect(
                    requests.where((r) => r.url.path
                        .endsWith('/raw-material-start-requirements')),
                    hasLength(1));
                expect(
                    requests.where((r) => r.url.path
                        .endsWith('/order-scan-bootstrap')),
                    isEmpty,
                    reason: 'backgrounded sheets do not retry material reads');
                tester.binding.handleAppLifecycleStateChanged(
                    AppLifecycleState.hidden);
                tester.binding.handleAppLifecycleStateChanged(
                    AppLifecycleState.inactive);
                tester.binding.handleAppLifecycleStateChanged(
                    AppLifecycleState.resumed);
                await tester.pump();
              }
              if (outcome == 'repeated parse failures') {
                sectionRevision = 3;
                live.add(snapshot(action, sectionRevision));
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 100));
              }
              // Keep this same sheet open. Read-side recovery must retire a
              // temporary section failure without replaying the colour write.
              for (var tick = 0; tick < 30; tick++) {
                content = tester.widget(detail());
                if ((content.materialsError as String).isEmpty &&
                    content.uiState.materialRequiredCount == 1) break;
                await tester.pump(const Duration(milliseconds: 100));
              }
              content = tester.widget(detail());
              expect(content.materialsError, isEmpty,
                  reason: 'a temporary section read failure must recover without reopening');
              expect(content.uiState.materialRequiredCount, 1);
              expect(content.qolipScanned, isTrue);
              expect(
                  find.byKey(const ValueKey('production-qolip-auto-status')),
                  findsOneWidget);
              expect(find.byType(ProductionQuickScannerPanel), findsOneWidget,
                  reason: 'recovered requirements retain the real material QR gate');
              expect(
                  requests.where((r) => r.url.path
                      .endsWith('/raw-material-start-requirements')).length +
                      requests.where((r) => r.url.path
                          .endsWith('/order-scan-bootstrap')).length,
                  greaterThan(1));
              if (outcome == 'repeated parse failures') {
                expect(materialReadTimes, hasLength(4),
                    reason: 'valid controls cannot clear a failed material section');
                expect(materialReadTimes.last.difference(materialReadTimes[2]),
                    greaterThanOrEqualTo(const Duration(milliseconds: 200)),
                    reason: 'repeated failures use delayed recovery rather than a read loop');
              }
            }
            expect(
                requests.where((r) => r.method == 'POST' &&
                    r.url.path.endsWith('/print-preflight')),
                hasLength(1));
            expect(
                requests.where((r) => r.method == 'POST' &&
                    r.url.path.endsWith('/queue-action')),
                isEmpty,
                reason: 'read recovery cannot start production or replay the colour decision');
          } else if (outcome == 'permanent server failure') {
            expect(content.materialsError, isNotEmpty);
            await tester.pump(const Duration(seconds: 3));
            content = tester.widget(detail());
            expect(content.materialsError, isNotEmpty);
            expect(content.materialStartReady, isFalse);
            expect(
                requests.where((r) => r.url.path
                    .endsWith('/raw-material-start-requirements')),
                hasLength(1));
            expect(
                requests.where((r) => r.url.path
                    .endsWith('/order-scan-bootstrap')),
                isEmpty,
                reason: 'a permanent validation failure requires changed input, not automatic retries');
          } else if (outcome == 'read failure') {
            expect(content.materialsError, 'Homashyo qoidasi yuklanmadi',
                reason: 'a settled server failure keeps the existing error');
            expect(content.materialStartReady, isFalse);
          } else {
            expect(content.materialsError, isEmpty);
            expect(content.uiState.materialRequiredCount, 1);
            expect(content.requiredQolips, hasLength(automatic ? 2 : 1));
            expect(content.materialStartReady, isFalse,
                reason: 'loading requirements does not bypass QR validation');
            if (const {'old assignment', 'old failed assignment'}
                .contains(outcome)) {
              oldAssignments.complete(outcome == 'old failed assignment'
                  ? http.Response('<html>Obsolete failed read</html>', 200)
                  : http.Response('{"items":[]}', 200));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
              content = tester.widget(detail());
              expect(content.uiState.materialRequiredCount, 1,
                  reason: 'a preceding hidden read cannot erase start requirements');
              expect(content.materialStartBlockingText, isEmpty);
              expect(content.materialsError, isEmpty);
              if (automatic) {
                expect(content.qolipScanned, isTrue);
                expect(
                    find.byKey(const ValueKey('production-qolip-auto-status')),
                    findsOneWidget);
              }
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          if (!oldAssignments.isCompleted) {
            oldAssignments.complete(http.Response('{"items":[]}', 200));
          }
          await tester.pump();
          await tester.pump(const Duration(seconds: 11));
          expect(tester.takeException(), isNull);
        }, () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/print-preflight')) return post.future;
          if (request.url.path.endsWith('/raw-material-start-requirements')) {
            materialReadTimes.add(tester.binding.clock.now());
            final reads = materialReadTimes.length;
            if (reads == 1) return materials.future;
            if (outcome == 'repeated parse failures' && reads < 4) {
              return http.Response(
                  '<html>Repeated temporary preview failure</html>', 200);
            }
            return http.Response(jsonEncode(requirements), 200);
          }
          if (request.url.path.endsWith('/raw-material-assignments')) {
            return oldAssignments.future;
          }
          if (request.url.path.endsWith('/qolip-validate')) {
            return http.Response(
                jsonEncode(automatic ? _autoQolipData() : scanQolips()), 200);
          }
          if (request.url.path.endsWith('/order-scan-bootstrap')) {
            return http.Response(jsonEncode({
              'ok': true,
              'control_state': {
                'apparatus': _print7Id, 'order_id': orderId,
                'epoch': 'colour-sections-server', 'rev': sectionRevision,
                'scope': 'colour-sections-worker', 'control': control(action),
                'queue_state': action == 'failed' ? 'pending' : 'print_preflight',
                'stage_states': {}, 'order_control': 'active',
              },
              'sections': {
                'materials': outcome == 'repeated parse failures'
                    ? {'status': 'failed'}
                    : {'status': 'ready', 'data': requirements},
                'qolips': {'status': 'ready', 'data': automatic ? _autoQolipData() : scanQolips()},
              },
            }), 200);
          }
          return http.Response('{}', 200);
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
