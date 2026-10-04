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
                catalog.where((item) => item.id == _lamination1Id ||
                    (scenario == 'free' && item.id == _lamination2Id)).toList(),
            queueSnapshotLoader: () async => current,
            liveEventsLoader: () => events.stream,
          ),
        ));
        await tester.pumpAndSettle();
      }

      final prefix = workerMode
          ? 'worker-order-'
          : 'sequence-row-$_lamination1Id-';
      List<String> displayedIds() => tester
          .widgetList(
            find.byWidgetPredicate(
              (widget) =>
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(prefix),
            ),
          )
          .map(
            (widget) => (widget.key! as ValueKey<String>).value.substring(
              prefix.length,
            ),
          )
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
        // Both views build only viewport/cache rows, preserving display ordering.
        expect(displayed, expected.take(displayed.length));
        if (scenario == 'free' || scenario == 'legacy') {
          expect(
            find.byKey(ValueKey('worker-order-${ids.last}')).hitTestable(),
            findsOneWidget,
          );
        }
      }

      expectInitialOrder();
      if (workerMode) {
        expect(
          displayedIds().length,
          lessThan(30),
          reason: 'a phone viewport must not build all 99 queue rows',
        );
        expect(
          find.byKey(ValueKey('worker-order-${expected.last}')),
          findsNothing,
        );
      }
      expect(
        current.sequences[_lamination1Id],
        ids,
        reason: 'display sorting must not mutate the admin sequence',
      );
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
        expect(
          displayedIds(),
          unchanged.take(displayedIds().length),
          reason: 'switching to strict restores the exact queue order',
        );
        final movedId = ids.removeLast();
        ids.insert(0, movedId);
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(
          displayedIds().first,
          movedId,
          reason: 'keyed lazy rows must follow a live sequence reorder',
        );
        ids.remove(movedId);
        maps.removeWhere((item) => item.map.id == movedId);
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('worker-order-$movedId')), findsNothing);
        expect(displayedIds().first, ids.first);

        final inserted = await MobileApi.instance.adminSaveProductionMap(
          _productionOrderMap(
            id: 'zakaz-inserted-order',
            title: 'zakaz-inserted-order',
            productCode: 'zakaz-inserted-order',
            product: 'zakaz-inserted-order',
            apparatusId: _lamination1Id,
          ),
        );
        maps.add(inserted);
        ids.insert(1, inserted.map.id);
        states[inserted.map.id] = 'pending';
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(
          displayedIds().take(3),
          ids.take(3),
          reason: 'inserting a row must keep neighboring row identities',
        );
        final lastRow = find.byKey(ValueKey('worker-order-${ids.last}'));
        final scrollable = find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          lastRow,
          300,
          scrollable: scrollable,
          maxScrolls: 100,
        );
        await tester.pumpAndSettle();
        expect(lastRow.hitTestable(), findsOneWidget);
        expect(
          displayedIds().length,
          lessThan(30),
          reason: 'scrolling must recycle rows instead of retaining the queue',
        );
        final removedAtEnd = ids.removeLast();
        maps.removeWhere((item) => item.map.id == removedAtEnd);
        final movedToEnd = ids.removeAt(1);
        ids.add(movedToEnd);
        current = snapshot();
        events.add(current);
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('worker-order-$removedAtEnd')), findsNothing);
        final movedRow = find.byKey(ValueKey('worker-order-$movedToEnd'));
        await tester.scrollUntilVisible(movedRow, 100,
            scrollable: scrollable, maxScrolls: 10);
        await tester.pumpAndSettle();
        expect(movedRow.hitTestable(), findsOneWidget,
            reason: 'live changes while scrolled must keep valid row mapping');
        final tabs = tester.widget<TabBar>(find.byType(TabBar).first);
        expect(tabs.tabs.length, 3);
        tabs.controller!.animateTo(2);
        await tester.pumpAndSettle();
        expect(movedRow.hitTestable(), findsNothing,
            reason: 'another apparatus must not reuse the current list rows');
        tabs.controller!.animateTo(0);
        await tester.pumpAndSettle();
        expect(movedRow.hitTestable(), findsOneWidget,
            reason: 'returning to an apparatus keeps its queue scroll position');

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
