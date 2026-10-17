part of 'admin_production_map_test_screen_test.dart';

void _registerRepeatedStageToneTests() {
  for (final peerAlternative in [false, true]) {
    testWidgets(
      'repeated Rezka queue scopes tone to unfinished occurrence peer=$peerAlternative',
      (tester) async {
        await TestModeController.instance.setEnabled(true);
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Rezka worker',
          legalName: '',
          ref: 'repeated-rezka-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_rezkaId],
        );
        const orderId = 'zakaz-0062';
        const peerId = 'apparatus:default:asset-011';
        final saved = await MobileApi.instance.adminSaveProductionMap(
          ProductionMapDefinition.fromJson({
            'id': orderId,
            'order_number': '0062',
            'title': 'Repeated Rezka tone',
            'product_code': 'REPEAT',
            'nodes': [
              {'id': 'start', 'kind': 'start', 'title': 'Start'},
              {
                'id': 'print',
                'kind': 'apparatus',
                'title': 'Print',
                'apparatus_id': _print7Id,
              },
              {
                'id': 'first-rezka',
                'kind': 'apparatus',
                'title': 'Intermediate Rezka',
                'apparatus_id': _rezkaId,
              },
              {
                'id': 'lamination',
                'kind': 'apparatus',
                'title': 'Lamination',
                'apparatus_id': _lamination1Id,
              },
              {
                'id': 'later-rezka',
                'kind': 'apparatus',
                'title': 'Final Rezka',
                'apparatus_id': _rezkaId,
                if (peerAlternative) 'alternative_group_id': 'final-rezka',
              },
              if (peerAlternative)
                {
                  'id': 'peer-rezka',
                  'kind': 'apparatus',
                  'title': 'Alternative final Rezka',
                  'apparatus_id': peerId,
                  'alternative_group_id': 'final-rezka',
                },
              {'id': 'end', 'kind': 'end', 'title': 'End'},
            ],
            'edges': [
              {'from': 'start', 'to': 'print'},
              {'from': 'print', 'to': 'first-rezka'},
              {'from': 'first-rezka', 'to': 'lamination'},
              {'from': 'lamination', 'to': 'later-rezka'},
              {'from': 'later-rezka', 'to': 'end'},
              if (peerAlternative) ...[
                {'from': 'lamination', 'to': 'peer-rezka'},
                {'from': 'peer-rezka', 'to': 'end'},
              ],
            ],
          }),
        );
        final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
        final events = StreamController<AdminProductionMapLiveSnapshot>();
        addTearDown(events.close);
        var reads = 0;
        AdminProductionMapLiveSnapshot snapshot(
          int revision, {
          String queueState = 'completed',
          String laterState = 'pending',
          String controlNode = 'first-rezka',
          bool localCompleted = true,
          String globalState = 'in_progress',
          bool includeStageMetadata = true,
        }) =>
            AdminProductionMapLiveSnapshot(
              maps: [saved],
              sequences: const {
                _rezkaId: [orderId],
              },
              visibleOrderIds: const {
                _rezkaId: [orderId],
              },
              queueStates: {
                _rezkaId: {orderId: queueState},
                if (peerAlternative) peerId: {orderId: 'in_progress'},
              },
              stageStates: {
                if (includeStageMetadata)
                  orderId: {
                    'print': 'completed',
                    'first-rezka': 'completed',
                    'lamination': 'pending',
                    'later-rezka': laterState,
                    if (peerAlternative) 'peer-rezka': 'in_progress',
                  },
              },
              queueActionControls: {
                _rezkaId: {
                  orderId: AdminApparatusQueueOrderActionControl(
                    state: queueState,
                    stageNodeId: includeStageMetadata ? controlNode : '',
                    stageWork: includeStageMetadata
                        ? AdminStageWorkControl(
                            completed: localCompleted,
                            localCompleted: localCompleted,
                            upstreamClosed: true,
                          )
                        : null,
                    workActivity: AdminQueueWorkActivity(
                      workerRole: 'aparatchi',
                      workerRef: 'another-shift',
                      state: queueState,
                    ),
                  ),
                },
                if (peerAlternative)
                  peerId: {
                    orderId: const AdminApparatusQueueOrderActionControl(
                      state: 'in_progress',
                      stageNodeId: 'peer-rezka',
                    ),
                  },
              },
              orderStatuses: {
                orderId: AdminProductionOrderStatusDetail(
                  lifecycleStatus: 'in_progress',
                  orderStatus: globalState,
                ),
              },
              queuePolicies: const {},
              orderControls: const {},
              completedOrders: const [
                AdminCompletedQueueOrder(
                  apparatus: _rezkaId,
                  orderId: orderId,
                  completedAtUnix: 10,
                ),
              ],
              completionRequests: const [],
              completionRequestDecisions: const [],
              epoch: 'repeated-rezka-tone',
              revision: revision,
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
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            apparatusLoader: () async => apparatus,
            queueSnapshotLoader: () async {
              reads++;
              return snapshot(1);
            },
            liveEventsLoader: () => events.stream,
          ),
        ));
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('worker-order-$orderId'));
        Color cardColor() {
          expect(row, findsOneWidget);
          return tester
              .widget<Material>(
                find.descendant(of: row, matching: find.byType(Material)).first,
              )
              .color!;
        }

        final neutral = theme.colorScheme.surfaceContainerLowest;
        Color tint(Color color) => Color.alphaBlend(
              color.withValues(alpha: .16),
              neutral,
            );
        final green = tint(const Color(0xFF2E7D32));
        final yellow = tint(const Color(0xFFF9A825));
        final red = tint(const Color(0xFFC62828));
        Future<void> emit(AdminProductionMapLiveSnapshot next) async {
          events.add(next);
          await tester.pumpAndSettle();
        }

        expect(cardColor(), neutral,
            reason:
                'finished intermediate work cannot color the waiting final occurrence');
        await tester.tap(find.text('Tugallangan'));
        await tester.pumpAndSettle();
        final historyRow = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_SequenceOrderRow',
        );
        expect(find.textContaining('Repeated Rezka tone'), findsOneWidget);
        expect(
          tester
              .widget<Material>(find
                  .descendant(of: historyRow, matching: find.byType(Material))
                  .first)
              .color,
          const Color(0xFFC8E6C9),
          reason: 'the first occurrence remains completed in actual history',
        );
        await tester.tap(find.text(_fixtureApparatusName(_rezkaId)));
        await tester.pumpAndSettle();
        expect(cardColor(), neutral);

        await emit(snapshot(2, globalState: 'completed_with_issue'));
        expect(cardColor(), red,
            reason:
                'neutralizing historical completion must preserve order issues');
        await emit(snapshot(3, globalState: 'frozen'));
        expect(row, findsNothing, reason: 'frozen orders remain hidden');
        await emit(snapshot(4));
        expect(cardColor(), neutral);

        // Genuine physical machine activity wins even with stale stage metadata.
        await emit(snapshot(5, queueState: 'in_progress'));
        expect(cardColor(), green);
        await emit(snapshot(6, queueState: 'paused'));
        expect(cardColor(), yellow);
        await emit(snapshot(7,
            queueState: 'in_progress',
            laterState: 'in_progress',
            controlNode: 'later-rezka',
            localCompleted: false));
        expect(cardColor(), green);
        await emit(snapshot(8,
            queueState: 'paused',
            laterState: 'paused',
            controlNode: 'later-rezka',
            localCompleted: false));
        expect(cardColor(), yellow);
        await emit(snapshot(7,
            queueState: 'in_progress',
            laterState: 'in_progress',
            controlNode: 'later-rezka',
            localCompleted: false));
        await emit(snapshot(8));
        expect(cardColor(), yellow,
            reason:
                'out-of-order and duplicate frames cannot restore an older occurrence');

        await emit(snapshot(9,
            queueState: 'in_progress', includeStageMetadata: false));
        expect(cardColor(), green,
            reason:
                'legacy snapshots without stage metadata retain real machine status');
        await emit(
            snapshot(10, laterState: 'completed', controlNode: 'later-rezka'));
        expect(row, findsNothing,
            reason:
                'the order leaves this queue after both own occurrences finish');
        await emit(snapshot(9,
            queueState: 'in_progress', includeStageMetadata: false));
        expect(row, findsNothing,
            reason: 'delayed running frames cannot reopen completed work');
        expect(reads, 1, reason: 'stream updates require no per-order polling');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
