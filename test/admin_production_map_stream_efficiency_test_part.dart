part of 'admin_production_map_test_screen_test.dart';

void _registerStreamEfficiencyTests() {
  Future<void> disposeStream(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }

  for (final mode in ['readOnly', 'supply', 'qolip', 'material']) {
    testWidgets('stream efficiency: healthy $mode does not poll and pauses',
        (tester) async {
      final fixture = await _prepareScanBootstrapFixture(tester);
      final events = StreamController<Object>.broadcast();
      addTearDown(events.close);
      var reads = 0;
      var connects = 0;
      final snapshot = _syncLive(fixture.order, 7, 'pending');
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
          readOnly: mode == 'readOnly',
          supplyViewerMode: mode == 'supply',
          qolipTasksMode: mode == 'qolip',
          materialTasksMode: mode == 'material',
          queueSnapshotLoader: () async { reads++; return snapshot; },
          apparatusLoader: () async => fixture.apparatus,
          completionRequestsLoader: () async => [],
          closedOrdersLoader: () async => [],
          liveEventsLoader: () { connects++; return events.stream; },
        ),
      ));
      await tester.pumpAndSettle();
      expect(connects, 1);
      events.add(snapshot);
      await tester.pump();
      final initialReads = reads;
      for (var n = 0; n < 5; n++) {
        await tester.pump(const Duration(seconds: 2));
      }
      expect(reads, initialReads, reason: 'Healthy stream supplies all updates');
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(seconds: 20));
      expect(reads, initialReads, reason: 'Background lists must not poll');
      expect(connects, 1);
      for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(connects, 2);
      events.add(snapshot);
      await tester.pump();
      final resumedReads = reads;
      await tester.pump(const Duration(seconds: 6));
      expect(reads, resumedReads);
      await disposeStream(tester);
    });
  }

  testWidgets('stream efficiency: worker resumes negotiated cursor without GET',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final events = StreamController<Object>.broadcast();
    addTearDown(events.close);
    var reads = 0;
    var catalogs = 0;
    var connects = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        workerMode: true,
        readOnly: true,
        queueSnapshotLoader: () async {
          reads++;
          return _syncLive(fixture.order, 7, 'pending');
        },
        apparatusLoader: () async { catalogs++; return fixture.apparatus; },
        liveEventsLoader: () { connects++; return events.stream; },
      ),
    ));
    await tester.pumpAndSettle();
    const ready = AdminProductionMapLiveStateReady(
      epoch: 'scan-server', revision: 7, scope: 'worker-live-scope',
      resync: false, recovered: true,
    );
    events.add(ready);
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(catalogs, 1);
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    await tester.pump();
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    await tester.pump();
    expect(connects, 2);
    expect(reads, 1);
    expect(catalogs, 1);
    events.add(ready);
    await tester.pumpAndSettle();
    expect(find.byKey(_recoveryProgressKey), findsNothing);
    events.add(const AdminProductionMapLiveStateDelta(
      epoch: 'scan-server', baseRevision: 7, revision: 9,
      scope: 'worker-live-scope', patch: {},
    ));
    await tester.pump();
    expect(reads, 1, reason: 'Empty checkpoints advance without resync');
    events.add(const AdminProductionMapLiveStateReady(
      epoch: 'scan-server', revision: 9, scope: 'worker-live-scope',
      resync: false, recovered: true,
    ));
    await tester.pump();
    expect(reads, 1, reason: 'Ready observes advanced checkpoint cursor');
    await disposeStream(tester);
  });

  testWidgets('stream efficiency: failed recovery obtains canonical snapshot',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final events = StreamController<Object>.broadcast();
    addTearDown(events.close);
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        workerMode: true, readOnly: true,
        queueSnapshotLoader: () async {
          reads++;
          return _syncLive(fixture.order, 7, 'pending');
        },
        apparatusLoader: () async => fixture.apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    events.add(const AdminProductionMapLiveStateReady(
      epoch: 'scan-server', revision: 7, scope: 'worker-live-scope',
      resync: false, recovered: true,
    ));
    await tester.pump();
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    await tester.pump();
    for (final state in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
    await tester.pump();
    events.add(const AdminProductionMapLiveStateReady(
      epoch: 'scan-server', revision: 8, scope: 'worker-live-scope',
      resync: true,
    ));
    await tester.pumpAndSettle();
    expect(reads, 2);
    await disposeStream(tester);
  });
}
