part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerQueueOrderingTests() {
  for (final scenario in [
    'free',
    'strict',
    'missing-policy',
    'legacy',
    'admin'
  ]) {
    testWidgets('worker queue display priority: $scenario', (tester) async {
      await TestModeController.instance.setEnabled(true);
      final workerMode = scenario != 'admin';
      AppSession.instance.profile = SessionProfile(
        role: workerMode ? UserRole.aparatchi : UserRole.admin,
        displayName: 'Worker',
        legalName: '',
        ref: 'worker',
        phone: '',
        avatarUrl: '',
        capabilities: const [
          'admin.access',
          'apparatus.queue.read',
          'apparatus.queue.manage'
        ],
        assignedApparatus: const [_lamination1Id],
      );
      final maps = <ProductionMapSaved>[];
      final ids = List.generate(100, (index) => 'zakaz-${index + 1}');
      for (final id in ids) {
        maps.add(
            await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
          id: id,
          title: id,
          productCode: id,
          product: id,
          apparatusId: _lamination1Id,
        )));
      }
      final catalog = await MobileApi.instance.adminApparatus(limit: 200);
      final events =
          StreamController<AdminProductionMapLiveSnapshot>.broadcast();
      addTearDown(events.close);
      final states = <String, String>{
        for (final id in ids) id: 'pending',
        ids[96]: 'completed',
        ids[97]: 'paused',
        ids[99]: 'in_progress',
      };
      final times = {ids[97]: 300, ids[98]: 200, ids[99]: 100};
      var policy = scenario == 'strict'
          ? ApparatusQueuePolicy.strictSequence
          : ApparatusQueuePolicy.freePick;
      AdminProductionMapLiveSnapshot snapshot() =>
          AdminProductionMapLiveSnapshot(
            maps: maps,
            sequences: {_lamination1Id: List.of(ids)},
            visibleOrderIds: {_lamination1Id: List.of(ids)},
            queueStates: {
              _lamination1Id: Map.of(states),
              _lamination2Id: {ids.first: 'in_progress'},
            },
            queuePolicies: {
              if (scenario != 'missing-policy')
                _lamination1Id: AdminApparatusQueuePolicy(
                    apparatus: _lamination1Id, policy: policy),
            },
            orderControls: const {},
            queueActionControls: {
              _lamination1Id: {
                for (final id in ids)
                  id: AdminApparatusQueueOrderActionControl.fromJson({
                    'state': states[id],
                    if (scenario != 'legacy')
                      'last_worked_at_unix': times[id] ?? 0,
                  }),
              },
              _lamination2Id: {
                ids.first: const AdminApparatusQueueOrderActionControl(
                    lastWorkedAtUnix: 9999),
              },
            },
            // Global activity on another apparatus must not promote this order.
            orderStatuses: {
              ids.first: const AdminProductionOrderStatusDetail(
                  orderStatus: 'in_progress')
            },
            completedOrders: const [], completionRequests: const [],
            completionRequestDecisions: const [],
            // Exercise field equality as well as canonical revisioned refreshes.
            revision: null,
          );
      var current = snapshot();
      Future<void> mount() async {
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
            readOnly: workerMode,
            workerMode: workerMode,
            apparatusLoader: () async =>
                catalog.where((item) => item.id == _lamination1Id).toList(),
            queueSnapshotLoader: () async => current,
            liveEventsLoader: () => events.stream,
          ),
        ));
        await tester.pumpAndSettle();
      }

      final prefix =
          workerMode ? 'worker-order-' : 'sequence-row-$_lamination1Id-';
      List<String> displayedIds() => tester
          .widgetList(find.byWidgetPredicate((widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(prefix)))
          .map((widget) =>
              (widget.key! as ValueKey<String>).value.substring(prefix.length))
          .toList();
      final unchanged = ids.where((id) => id != ids[96]).toList();
      final expected = switch (scenario) {
        'free' => [ids[99], ids[97], ids[98], ...ids.take(96)],
        'legacy' => [ids[99], ids[97], ...ids.take(96), ids[98]],
        _ => unchanged,
      };
      await _usePhoneViewport(tester);
      await mount();
      void expectInitialOrder() {
        final displayed = displayedIds();
        expect(displayed, isNotEmpty);
        // Admin uses a lazy list; worker rows are built in one segmented group.
        expect(
            displayed, workerMode ? expected : expected.take(displayed.length));
        if (scenario == 'free' || scenario == 'legacy') {
          expect(find.byKey(ValueKey('worker-order-${ids.last}')).hitTestable(),
              findsOneWidget);
        }
      }

      expectInitialOrder();
      expect(current.sequences[_lamination1Id], ids,
          reason: 'display sorting must not mutate the admin sequence');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await mount();
      expectInitialOrder();
      if (scenario == 'free') {
        // Only recency changes: no local action or queue-state change.
        times[ids[98]] = 400;
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(displayedIds().take(4), [ids[99], ids[98], ids[97], ids.first]);
        // Start/resume of an order deep in the queue moves it to the top live.
        states[ids[99]] = 'paused';
        states[ids[98]] = 'in_progress';
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(displayedIds().take(4), [ids[98], ids[97], ids[99], ids.first]);
        policy = ApparatusQueuePolicy.strictSequence;
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(displayedIds(), unchanged,
            reason: 'switching to strict restores the exact queue order');
      }
      dismissAdminTopNotice();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('queue recency is optional nonnegative server metadata', () {
    for (final raw in [null, -1, 0, 'bad', {}, 1.5]) {
      expect(
          AdminApparatusQueueOrderActionControl.fromJson(
              {'last_worked_at_unix': raw}).lastWorkedAtUnix,
          0);
    }
    expect(
        AdminApparatusQueueOrderActionControl.fromJson(
            {'last_worked_at_unix': 123}).lastWorkedAtUnix,
        123);
  });
}
