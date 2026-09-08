part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerActivityTests() {
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
