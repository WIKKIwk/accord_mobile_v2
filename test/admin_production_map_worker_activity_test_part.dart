part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerActivityTests() {
  for (final (view, dark) in [
    ('worker', false),
    ('sequence', false),
    ('orders', false),
    ('worker', true),
    ('sequence', true),
    ('orders', true),
  ]) {
    testWidgets(
      'print status uses ordinary snapshot and stream across re-entry: $view dark=$dark',
      (tester) async {
        final workerMode = view == 'worker';
        await TestModeController.instance.setEnabled(true);
        AppSession.instance.profile = SessionProfile(
          role: workerMode ? UserRole.aparatchi : UserRole.admin,
          displayName: 'Worker',
          legalName: '',
          ref: 'worker-me',
          phone: '',
          avatarUrl: '',
          capabilities: const [
            'apparatus.queue.read',
            'apparatus.queue.manage',
          ],
          assignedApparatus: const [_print7Id],
        );
        const orderId = 'zakaz-print-status';
        final saved = await MobileApi.instance.adminSaveProductionMap(
          _productionOrderMap(
            id: orderId,
            title: 'Colour status',
            productCode: 'COLOUR',
            apparatusId: _print7Id,
            product: 'Colour status',
          ),
        );
        final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
        final events =
            StreamController<AdminProductionMapLiveSnapshot>.broadcast();
        addTearDown(events.close);
        var reads = 0;
        AdminProductionMapLiveSnapshot snapshot(
          String state,
          int revision, {
          String? trialStatus,
          String holdApparatus = _print7Id,
          String holdOrder = orderId,
        }) =>
            AdminProductionMapLiveSnapshot(
              maps: [saved],
              sequences: {
                _print7Id: [orderId],
              },
              visibleOrderIds: {
                _print7Id: [orderId],
              },
              queueStates: {
                _print7Id: {orderId: state},
              },
              queuePolicies: const {},
              orderControls: const {},
              // Running still works without a hold; green requires the current
              // server-confirmed result for exactly this order and apparatus.
              queueActionControls: {
                if (trialStatus != null)
                  _print7Id: {
                    orderId: AdminApparatusQueueOrderActionControl(
                      state: state,
                      stageNodeId: saved.map.nodes
                          .firstWhere((node) => node.kind == 'apparatus')
                          .id,
                      printPreflight: AdminPrintPreflightHold(
                        holdId: 'trial',
                        idempotencyKey: 'trial',
                        orderId: holdOrder,
                        apparatus: holdApparatus,
                        status: trialStatus,
                      ),
                    ),
                  },
              },
              orderStatuses: {
                orderId: AdminProductionOrderStatusDetail(orderStatus: state),
              },
              completedOrders: const [],
              completionRequests: const [],
              completionRequestDecisions: const [],
              revision: revision,
              epoch: 'server',
            );
        var current = snapshot('pending', 1);
        await TestModeController.instance.setEnabled(workerMode);
        await http.runWithClient(
          () async {
            Future<void> mount() async {
              await tester.pumpWidget(
                MaterialApp(
                  theme: ThemeData(
                      useMaterial3: true,
                      brightness: dark ? Brightness.dark : Brightness.light),
                  locale: const Locale('uz'),
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                  ],
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: AdminProductionMapOrdersScreen(
                    readOnly: workerMode,
                    workerMode: workerMode,
                    apparatusLoader: () async =>
                        apparatus.where((a) => a.id == _print7Id).toList(),
                    queueSnapshotLoader: () async {
                      reads++;
                      return current;
                    },
                    liveEventsLoader: () => events.stream,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              if (view == 'orders') {
                await tester.tap(find.text('Buyurtmalar'));
                await tester.pumpAndSettle();
              }
            }

            final row = find.byKey(
              ValueKey(switch (view) {
                'worker' => 'worker-order-$orderId',
                'sequence' => 'sequence-row-$_print7Id-$orderId',
                _ => 'opened-order-$orderId',
              }),
            );
            LinearGradient? cardGradient(Widget widget) {
              final decoration = switch (widget) {
                DecoratedBox() => widget.decoration,
                Ink() => widget.decoration,
                _ => null,
              };
              return decoration is BoxDecoration &&
                      decoration.gradient is LinearGradient
                  ? decoration.gradient as LinearGradient
                  : null;
            }

            final gradient = find.descendant(
              of: row,
              matching: find.byWidgetPredicate(
                (widget) => cardGradient(widget) != null,
              ),
            );
            await _usePhoneViewport(tester);
            await mount();
            expect(row, findsOneWidget);
            expect(gradient, findsNothing);
            current = snapshot('print_preflight', 2);
            events.add(current);
            await tester.pumpAndSettle();
            expect(gradient, findsOneWidget);
            final actual = cardGradient(tester.widget(gradient))!;
            expect(actual.colors, const [
              Color(0xFF7E86A8),
              Color(0xFFE5BFC4),
              Color(0xFFF4FAFC),
            ]);
            expect(actual.stops, [0.0, 0.52, 1.0]);
            expect(actual.begin, Alignment.topLeft);
            expect(actual.end, Alignment.bottomRight);
            if (workerMode)
              expect(
                reads,
                1,
                reason: 'the existing stream alone updates the card',
              );
            events.add(snapshot('pending', 1));
            await tester.pumpAndSettle();
            expect(
              gradient,
              findsOneWidget,
              reason: 'older stream frame cannot clear the status',
            );
            current = snapshot('print_preflight', 3, trialStatus: 'passed');
            events.add(current);
            await tester.pumpAndSettle();
            void expectPassed() {
              final ready = cardGradient(tester.widget(gradient))!;
              expect(ready.colors, const [
                Color(0xFF4B8F2F),
                Color(0xFF9BD34B),
                Color(0xFFD9F294),
                Colors.white,
              ]);
              expect(ready.stops, [0.0, 0.38, 0.70, 1.0]);
              expect(ready.begin, Alignment.topLeft);
              expect(ready.end, Alignment.bottomRight);
              expect(tester.takeException(), isNull);
            }

            expectPassed();
            events.add(snapshot('print_preflight', 2, trialStatus: 'running'));
            await tester.pumpAndSettle();
            expectPassed();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            await mount();
            if (workerMode) expect(reads, 2);
            expect(
              gradient,
              findsOneWidget,
              reason:
                  're-entry restores server status without local persistence',
            );
            expectPassed();
            // Historical/foreign successes must not paint this queue green.
            if (view == 'orders') {
              await tester.tap(find.descendant(
                  of: row, matching: find.byTooltip('Buyurtma ma’lumotlari')));
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Mahsulot ishlab chiqarish xaritasi'));
              await tester.tap(find.text('Mahsulot ishlab chiqarish xaritasi'));
              await tester.pumpAndSettle();
              expect(
                  find.descendant(
                      of: find.byType(BottomSheet),
                      matching: find.text('Rang chiqarildi')),
                  findsOneWidget);
              expect(
                  find.descendant(
                      of: find.byType(BottomSheet),
                      matching: find.text('Rang chiqaryapti')),
                  findsNothing);
              await tester.tap(
                  find.byKey(const ValueKey('production-order-detail-close')));
              await tester.pumpAndSettle();
            }
            for (final invalid in [
              snapshot('print_preflight', 4,
                  trialStatus: 'passed', holdApparatus: _print8Id),
              snapshot('print_preflight', 5,
                  trialStatus: 'passed', holdOrder: 'another-order'),
              snapshot('print_preflight', 6, trialStatus: 'consumed'),
            ]) {
              events.add(invalid);
              await tester.pumpAndSettle();
              expect(
                  cardGradient(tester.widget(gradient))!.colors, actual.colors);
            }
            current = snapshot('pending', 7, trialStatus: 'failed');
            events.add(current);
            await tester.pumpAndSettle();
            expect(
              gradient,
              findsNothing,
              reason: 'failed trial returns to the ordinary queue status',
            );
            if (workerMode) expect(reads, 2);
            events.add(snapshot('print_preflight', 8, trialStatus: 'passed'));
            await tester.pumpAndSettle();
            expectPassed();
            events.add(snapshot('in_progress', 9, trialStatus: 'consumed'));
            await tester.pumpAndSettle();
            expect(gradient, findsNothing,
                reason: 'Start uses the ordinary work colour');
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
          () => MockClient(
            (request) async => http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
      },
    );
  }
  for (final (apparatusId, legacy) in [
    (_print7Id, false), (_lamination1Id, false), (_rezkaId, false),
    (_godexId, false), (_print7Id, true),
  ]) {
    testWidgets(
        'worker activity: $apparatusId legacy=$legacy isolates owners and updates live',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Same name',
        legalName: '',
        ref: 'worker-me',
        phone: '',
        avatarUrl: '',
        capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [apparatusId],
      );
      const orderId = 'zakaz-worker-activity';
      final saved = await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
            id: orderId,
            title: 'Worker activity',
            productCode: 'ACT',
            apparatusId: apparatusId,
            product: 'Activity product'),
      );
      final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
      final events = StreamController<AdminProductionMapLiveSnapshot>();
      addTearDown(events.close);
      var reads = 0;
      AdminProductionMapLiveSnapshot snapshot({
        int? revision = 1,
        String epoch = 'activity-server',
        String owner = 'worker-other',
        String role = 'aparatchi',
        String state = 'in_progress',
        String globalState = 'in_progress',
        String? activityApparatus,
        bool includeActivity = true,
      }) =>
          AdminProductionMapLiveSnapshot(
            maps: [saved],
            sequences: {
              apparatusId: [orderId]
            },
            visibleOrderIds: {
              apparatusId: [orderId]
            },
            queueStates: {
              apparatusId: {orderId: state}
            },
            queuePolicies: const {},
            orderControls: const {},
            orderStatuses: {
              orderId:
                  AdminProductionOrderStatusDetail(orderStatus: globalState)
            },
            queueActionControls: {
              activityApparatus ?? apparatusId: {
                orderId: AdminApparatusQueueOrderActionControl(
                    state: state,
                    workActivity: includeActivity
                        ? AdminQueueWorkActivity(
                            workerRole: role, workerRef: owner, state: state)
                        : null),
              },
            },
            completedOrders: const [],
            completionRequests: const [],
            completionRequestDecisions: const [],
            revision: legacy ? null : revision,
            epoch: epoch,
          );
      await _usePhoneViewport(tester);
      final theme = ThemeData(useMaterial3: true);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
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
            apparatusLoader: () async => apparatus,
            queueSnapshotLoader: () async {
              reads++;
              return snapshot();
            },
            liveEventsLoader: () => events.stream),
      ));
      await tester.pumpAndSettle();
      Color cardColor() {
        final row = find.byKey(const ValueKey('worker-order-$orderId'));
        expect(row, findsOneWidget);
        return tester
            .widget<Material>(
                find.descendant(of: row, matching: find.byType(Material)).first)
            .color!;
      }

      final neutral = cardColor();
      Color tint(Color color) => Color.alphaBlend(color.withValues(alpha: .16),
          theme.colorScheme.surfaceContainerLowest);
      final green = tint(const Color(0xFF2E7D32));
      final yellow = tint(const Color(0xFFF9A825));
      expect(neutral, isNot(green),
          reason: 'another worker active must not be green');
      expect(neutral, isNot(yellow));
      Future<void> emit(
          AdminProductionMapLiveSnapshot next, Color expected) async {
        events.add(next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(cardColor(), expected);
      }

      // Owner-only change; queue/global status stays in_progress.
      await emit(snapshot(revision: 2, owner: 'worker-me'), green);
      await emit(
          snapshot(revision: 3, owner: 'worker-me', state: 'paused'), yellow);
      await emit(snapshot(revision: 4, state: 'paused'), neutral);
      await emit(
          snapshot(revision: 5, owner: 'worker-me', globalState: 'paused'),
          green);
      // Delayed and duplicate frames cannot restore old ownership/color.
      if (!legacy) {
        await emit(snapshot(revision: 3, state: 'paused'), green);
        await emit(snapshot(revision: 5), green);
      }
      await emit(
          snapshot(revision: 6, owner: 'worker-me', role: 'admin'), neutral);
      await emit(
          snapshot(
              revision: 7,
              owner: 'worker-me',
              activityApparatus: 'apparatus:test:other'),
          neutral);
      await emit(
          snapshot(revision: 8, owner: 'worker-me', includeActivity: false),
          neutral);
      events.add(snapshot(
          revision: 9,
          owner: 'worker-me',
          state: 'completed',
          globalState: 'completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('worker-order-$orderId')), findsNothing,
          reason: 'completed apparatus work leaves the active queue');
      await emit(snapshot(revision: 10, globalState: 'frozen'),
          tint(const Color(0xFFC62828)));
      await emit(snapshot(revision: 11, globalState: 'completed_with_issue'),
          tint(const Color(0xFFC62828)));
      // A restarted server can reset revisions; the retired epoch cannot return.
      await emit(
          snapshot(revision: 1, epoch: 'restarted-server', owner: 'worker-me'),
          green);
      if (!legacy) await emit(snapshot(revision: 99), green);
      expect(reads, 1,
          reason: 'live colors need no per-order fetch or polling');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('worker activity model fails closed and compares exact identities', () {
    const valid = {
      'worker_role': 'aparatchi',
      'worker_ref': 'worker-1',
      'state': 'in_progress'
    };
    final activity = AdminQueueWorkActivity.tryFromJson(valid)!;
    expect(activity, AdminQueueWorkActivity.tryFromJson(valid));
    expect(
        activity.hashCode, AdminQueueWorkActivity.tryFromJson(valid)!.hashCode);
    expect(activity.belongsTo(role: 'aparatchi', ref: 'worker-1'), isTrue);
    expect(activity.belongsTo(role: 'aparatchi', ref: 'Worker-1'), isFalse);
    expect(activity.belongsTo(role: 'admin', ref: 'worker-1'), isFalse);
    for (final malformed in [
      null,
      {},
      'active',
      {...valid, 'worker_ref': ''},
      {...valid, 'worker_role': 1},
      {...valid, 'state': 'completed'}
    ]) {
      expect(AdminQueueWorkActivity.tryFromJson(malformed), isNull);
    }
    expect(
        AdminApparatusQueueOrderActionControl.fromJson({
          'state': 'in_progress',
          'work_activity': valid,
        }).workActivity,
        activity);
    expect(
        AdminApparatusQueueOrderActionControl.fromJson({
          'state': 'in_progress',
        }).workActivity,
        isNull);
  });
}
