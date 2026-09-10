part of 'admin_production_map_test_screen_test.dart';

void _registerAlternativeVisibilityTests() {
  for (final (mine, peer, repeated) in [
    (_lamination2Id, _lamination1Id, false),
    (_print8Id, _print7Id, false),
    (_lamination2Id, _lamination1Id, true),
  ]) {
    for (final ownHistory in [false, true]) {
      testWidgets(
          'alternative visibility $mine ownHistory=$ownHistory repeated=$repeated',
          (tester) async {
        await TestModeController.instance.setEnabled(true);
        AppSession.instance.profile = SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Worker',
          legalName: '',
          ref: 'worker-me',
          phone: '',
          avatarUrl: '',
          capabilities: const [
            'apparatus.queue.read',
            'apparatus.queue.manage'
          ],
          assignedApparatus: [mine],
        );
        const orderId = 'zakaz-alternative-visibility';
        final saved = await MobileApi.instance.adminSaveProductionMap(
          ProductionMapDefinition.fromJson({
            'id': orderId,
            'title': 'Alternative visibility',
            'product_code': 'VIS',
            'nodes': [
              {'id': 'start', 'kind': 'start', 'title': 'Start'},
              {
                'id': 'mine',
                'kind': 'apparatus',
                'title': 'Mine',
                'apparatus_id': mine,
                'alternative_group_id': 'shared'
              },
              {
                'id': 'peer',
                'kind': 'apparatus',
                'title': 'Peer',
                'apparatus_id': peer,
                'alternative_group_id': 'shared'
              },
              {
                'id': 'later',
                'kind': 'apparatus',
                'title': 'Later',
                'apparatus_id': repeated ? mine : _rezkaId
              },
              {'id': 'end', 'kind': 'end', 'title': 'End'},
            ],
            'edges': [
              {'from': 'start', 'to': 'mine'},
              {'from': 'mine', 'to': 'later'},
              {'from': 'later', 'to': 'end'}
            ],
          }),
        );
        final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
        final events = StreamController<AdminProductionMapLiveSnapshot>();
        addTearDown(events.close);
        AdminProductionMapLiveSnapshot snapshot(int revision,
                {bool stageDone = false, bool localDone = false,
                String localNode = 'mine', String lifecycle = 'in_progress'}) =>
            AdminProductionMapLiveSnapshot(
              maps: [saved],
              sequences: {
                mine: [orderId]
              },
              // Also exercise compatibility with older servers returning all candidates.
              visibleOrderIds: {
                mine: [orderId]
              },
              queueStates: {
                peer: {orderId: 'completed'}
              },
              stageStates: {
                orderId: {
                  'mine': stageDone ? 'completed' : 'pending',
                  'peer': 'completed',
                  'later': 'pending'
                }
              },
              queueActionControls: {
                mine: {orderId: AdminApparatusQueueOrderActionControl(
                  state: 'pending', stageNodeId: localNode,
                  stageWork: AdminStageWorkControl.fromJson({
                    'completed': stageDone, 'local_completed': localDone,
                    'upstream_closed': true,
                  }),
                )},
                peer: {orderId: AdminApparatusQueueOrderActionControl(
                  state: 'pending', stageNodeId: 'peer',
                  stageWork: AdminStageWorkControl.fromJson({'local_completed': true}),
                )},
              },
              orderStatuses: {
                orderId:
                    AdminProductionOrderStatusDetail(lifecycleStatus: lifecycle)
              },
              queuePolicies: const {}, orderControls: const {},
              completedOrders: [
                AdminCompletedQueueOrder(
                    apparatus: peer, orderId: orderId, completedAtUnix: 20),
                if (ownHistory)
                  AdminCompletedQueueOrder(
                      apparatus: mine, orderId: orderId, completedAtUnix: 10),
              ],
              completionRequests: const [],
              completionRequestDecisions: const [],
              epoch: 'visibility', revision: revision,
            );
        await _usePhoneViewport(tester);
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
              apparatusLoader: () async => apparatus,
              queueSnapshotLoader: () async => snapshot(1),
              liveEventsLoader: () => events.stream),
        ));
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('worker-order-$orderId'));
        expect(row, findsOneWidget,
            reason: 'a peer report alone does not close the shared operation');
        events.add(snapshot(2, localDone: true));
        await tester.pumpAndSettle();
        expect(row, repeated ? findsOneWidget : findsNothing,
            reason: 'own accepted report hides own finished occurrence without waiting for shared closure');
        events.add(snapshot(3));
        await tester.pumpAndSettle();
        expect(row, findsOneWidget, reason: 'new waiting input makes this operation available again');
        events.add(snapshot(4, localDone: true, localNode: 'unrelated-occurrence'));
        await tester.pumpAndSettle();
        expect(row, findsOneWidget, reason: 'another occurrence must not hide this work');
        events.add(snapshot(5, stageDone: true));
        await tester.pumpAndSettle();
        expect(row, repeated ? findsOneWidget : findsNothing,
            reason:
                'closed operation leaves the active queue unless this machine has a later occurrence');
        // Historical 0002: terminal lifecycle, missing local queue/stage rows.
        events.add(snapshot(6, lifecycle: 'production_completed'));
        await tester.pumpAndSettle();
        expect(row, findsNothing,
            reason: 'global completion also hides unused legacy candidates');
        await tester.ensureVisible(find.text('Tugallangan'));
        await tester.tap(find.text('Tugallangan'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Alternative visibility'),
            ownHistory ? findsOneWidget : findsNothing,
            reason:
                'only own actual history; a newer peer record must not mask the older own record');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
}
