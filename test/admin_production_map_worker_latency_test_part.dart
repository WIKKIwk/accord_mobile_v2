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
          } else {
            refresh.complete(outcome == 'failure'
                ? http.Response('{"error":"store_failed"}', 503)
                : _workerLatencyRefresh(orderId, valid: outcome == 'success'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(
              syncWarning, outcome == 'success' ? findsNothing : findsOneWidget,
              reason: 'only failed or invalid refreshes show a sync warning');
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
                  return request.method == 'POST'
                      ? post.future
                      : refresh.future;
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
