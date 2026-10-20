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
      events.add(AdminProductionMapLiveStateReady.fromJson({
        'epoch': snapshot.epoch, 'rev': snapshot.revision, 'scope': snapshot.scope,
        'resync': false, 'recovered': true,
      }));
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
      expect(resumedReads, initialReads,
          reason: 'Negotiated resume reuses the canonical cursor');
      await tester.pump(const Duration(seconds: 6));
      expect(reads, resumedReads);
      await disposeStream(tester);
    });
  }

  testWidgets('stream efficiency: old global ready retains full snapshot fallback',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final events = StreamController<Object>.broadcast();
    addTearDown(events.close);
    final snapshot = _syncLive(fixture.order, 7, 'pending');
    var reads = 0;
    var connects = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        queueSnapshotLoader: () async { reads++; return snapshot; },
        apparatusLoader: () async => fixture.apparatus,
        closedOrdersLoader: () async => [],
        completionRequestsLoader: () async => [],
        liveEventsLoader: () { connects++; return events.stream; },
      ),
    ));
    await tester.pumpAndSettle();
    events.add(AdminProductionMapLiveStateReady(
      epoch: snapshot.epoch, revision: snapshot.revision!, scope: snapshot.scope,
      resync: false,
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(connects, 2,
        reason: 'An old global cursor cannot certify omitted request/history sections');
    events.add(snapshot);
    await tester.pumpAndSettle();
    final beforePoll = reads;
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(reads, greaterThan(beforePoll),
        reason: 'Legacy snapshots retain compatibility polling');
    await disposeStream(tester);
  });

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

  testWidgets('stream efficiency: paged color delta avoids HTTP and preserves unchanged cards',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final apparatus = fixture.apparatus.firstWhere((a) => a.id == scanApparatus);
    await AdminSequenceApparatusStore.instance.saveApparatus(apparatus);
    final events = StreamController<Object>.broadcast();
    addTearDown(events.close);
    var reads = 0;
    var revision = 7;
    var state = 'pending';
    const other = 'other-window-order';
    final second = fixture.order.map.copyWith(id: other, title: 'Other unchanged card');
    Map<String, dynamic> payload() => {
      ...scanSequence(), 'version': 'v$revision', 'epoch': 'scan-server', 'rev': revision,
      'offset': 0, 'total': 2, 'next_cursor': null,
      'order_ids': [scanOrder, other],
      'maps': [
        {'map': fixture.order.map.toJson(), 'program': <String, dynamic>{}},
        {'map': second.toJson(), 'program': <String, dynamic>{}},
      ],
      'sequences': {scanApparatus: [scanOrder, other]},
      'visible_order_ids': {scanApparatus: [scanOrder, other]},
      'queue_states': {scanApparatus: {scanOrder: state, other: 'pending'}},
      'queue_action_controls': {scanApparatus: {
        scanOrder: _syncControl(state), other: _syncControl('pending')}},
    };
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        apparatusLoader: () async => [apparatus],
        completionRequestsLoader: () async => [],
        queueSnapshotLoader: () => throw StateError('full snapshot requested'),
        orderPageLoader: (request) async {
          reads++;
          if (request.view == 'sequence') return AdminProductionOrderPage.fromJson(payload());
          return AdminProductionOrderPage.fromJson({
            'version': 'empty$revision', 'epoch': 'scan-server', 'rev': revision,
            'offset': 0, 'total': 0, 'next_cursor': null, 'closed_orders': [],
          });
        },
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_ready', 'window': 'w1', 'epoch': 'scan-server',
      'rev': 7, 'version': 'v7', 'resync': false,
    }));
    await tester.pumpAndSettle();
    Material material(String id) => tester.widget<Material>(find.descendant(
      of: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_SequenceOrderRow' &&
          (widget as dynamic).order.map.id == id), matching: find.byType(Material)).first);
    final untouched = material(other);
    final changed = material(scanOrder);
    final beforeReads = reads;
    revision = 8;
    state = 'in_progress';
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta', 'window': 'w1', 'epoch': 'scan-server',
      'rev': 8, 'base_version': 'v7', 'version': 'v8', 'page_count': 1,
      'changes': [{'index': 0, 'ops': [
        {'op': 'set', 'path': ['version'], 'value': 'v8'},
        {'op': 'set', 'path': ['rev'], 'value': 8},
        {'op': 'set', 'path': ['queue_states', scanApparatus, scanOrder], 'value': state},
        {'op': 'set', 'path': ['queue_action_controls', scanApparatus, scanOrder], 'value': _syncControl(state)},
      ]}],
    }));
    await tester.pumpAndSettle();
    expect(reads, beforeReads, reason: 'A color update must not reload the prefix');
    expect(identical(material(other), untouched), isTrue,
        reason: 'Unchanged image/title/marquee subtree must be reused');
    expect(identical(material(scanOrder), changed), isFalse);
    final after = material(scanOrder);
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_checkpoint', 'window': 'w1', 'epoch': 'scan-server',
      'rev': 9, 'base_version': 'v8', 'version': 'v9', 'next_cursors': [null],
    }));
    await tester.pumpAndSettle();
    expect(identical(material(scanOrder), after), isTrue);
    expect(reads, beforeReads);
    // A gap disables controls and repairs only the affected prefix.
    revision = 10;
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_checkpoint', 'window': 'w1', 'epoch': 'scan-server',
      'rev': 10, 'base_version': 'missing', 'version': 'v10', 'next_cursors': [null],
    }));
    await tester.pumpAndSettle();
    expect(reads, beforeReads + 1);
    await disposeStream(tester);
  });

}
