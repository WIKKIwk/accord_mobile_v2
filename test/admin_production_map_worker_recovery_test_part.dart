part of 'admin_production_map_test_screen_test.dart';

const _recoveryNotice = 'Aloqa vaqtincha uzildi. Avtomatik qayta ulanmoqda…';
const _recoveryOrderId = 'zakaz-worker-recovery';

class _WorkerRecoveryHarness {
  _WorkerRecoveryHarness(this.saved, this.apparatus);

  final ProductionMapSaved saved;
  final List<AdminApparatus> apparatus;
  int snapshotReads = 0;
  int apparatusReads = 0;
  Future<AdminApparatusQueueSnapshot> Function()? readSnapshot;
  Future<List<AdminApparatus>> Function()? readApparatus;
  Stream<AdminProductionMapLiveSnapshot> Function()? liveEvents;

  AdminApparatusQueueSnapshot snapshot(
          {int revision = 7, bool empty = false}) =>
      AdminApparatusQueueSnapshot(
        maps: empty ? [] : [saved],
        sequences: {
          _print7Id: empty ? [] : [_recoveryOrderId]
        },
        visibleOrderIds: {
          _print7Id: empty ? [] : [_recoveryOrderId]
        },
        queueStates: {
          _print7Id: {if (!empty) _recoveryOrderId: 'pending'}
        },
        queuePolicies: const {},
        queueActionControls: {
          _print7Id: {if (!empty) _recoveryOrderId: _freshStartQueueControl()},
        },
        orderControls: const {},
        revision: revision,
        epoch: 'recovery-test-server',
      );

  AdminProductionMapLiveSnapshot live({int revision = 7, bool empty = false}) {
    final source = snapshot(revision: revision, empty: empty);
    return AdminProductionMapLiveSnapshot(
      maps: source.maps,
      sequences: source.sequences,
      visibleOrderIds: source.visibleOrderIds,
      queueStates: source.queueStates,
      queuePolicies: source.queuePolicies,
      queueActionControls: source.queueActionControls,
      orderControls: source.orderControls,
      revision: source.revision,
      epoch: source.epoch,
      completedOrders: const [],
      completionRequests: const [],
      completionRequestDecisions: const [],
    );
  }

  Future<void> mount(WidgetTester tester) async {
    await _usePhoneViewport(tester);
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
        queueSnapshotLoader: () {
          snapshotReads++;
          return readSnapshot?.call() ?? Future.value(snapshot());
        },
        apparatusLoader: () {
          apparatusReads++;
          return readApparatus?.call() ?? Future.value(apparatus);
        },
        liveEventsLoader: liveEvents,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _registerWorkerRecoveryTests() {
  Future<_WorkerRecoveryHarness> prepare() async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'worker-recovery',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_print7Id],
    );
    final saved = await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: _recoveryOrderId,
        title: 'Worker recovery',
        productCode: 'RECOVERY',
        apparatusId: _print7Id,
        product: 'Recovery product',
      ),
    );
    return _WorkerRecoveryHarness(
      saved,
      await MobileApi.instance.adminApparatus(limit: 200),
    );
  }

  Finder order() =>
      find.byKey(const ValueKey('worker-order-$_recoveryOrderId'));
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    expect(tester.takeException(), isNull);
  }

  for (final failedCatalog in [false, true]) {
    testWidgets(
        'worker recovery: cold ${failedCatalog ? 'catalog' : 'queue'} failure retries automatically in 2 seconds',
        (tester) async {
      final h = await prepare();
      var offline = true;
      h.readSnapshot = () async {
        if (offline && !failedCatalog) throw TimeoutException('offline');
        return h.snapshot();
      };
      h.readApparatus = () async {
        if (offline && failedCatalog) throw TimeoutException('offline');
        return h.apparatus;
      };
      await h.mount(tester);
      expect(find.text(_recoveryNotice), findsOneWidget);
      expect(order(), findsNothing);
      offline = false;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(order(), findsOneWidget);
      expect(find.text(_recoveryNotice), findsNothing);
      expect(h.snapshotReads, 2);
      expect(h.apparatusReads, 2);
      await dispose(tester);
    });
  }

  testWidgets(
      'worker recovery: failed resume keeps rows and same revision clears error',
      (tester) async {
    final h = await prepare();
    await h.mount(tester);
    expect(order(), findsOneWidget);
    h.readSnapshot = () async => throw TimeoutException('old provider');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    expect(find.text(_recoveryNotice), findsOneWidget);
    h.readSnapshot = () async => h.snapshot();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    expect(find.text(_recoveryNotice), findsNothing);
    await dispose(tester);
  });

  testWidgets('worker recovery: empty queue also recovers from same revision',
      (tester) async {
    final h = await prepare();
    h.readSnapshot = () async => h.snapshot(empty: true);
    await h.mount(tester);
    h.readSnapshot = () async => throw TimeoutException('offline');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(_recoveryNotice), findsOneWidget);
    h.readSnapshot = () async => h.snapshot(empty: true);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(_recoveryNotice), findsNothing);
    expect(order(), findsNothing);
    await dispose(tester);
  });

  testWidgets(
      'worker recovery: background stops retries and resume retries immediately',
      (tester) async {
    final h = await prepare();
    h.readSnapshot = () async => throw TimeoutException('offline');
    await h.mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 20));
    expect(h.snapshotReads, 1);
    h.readSnapshot = () async => h.snapshot();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(h.snapshotReads, 2);
    expect(order(), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('worker recovery: repeated resume does not overlap initial reads',
      (tester) async {
    final h = await prepare();
    final pending = Completer<AdminApparatusQueueSnapshot>();
    h.readSnapshot = () => pending.future;
    await h.mount(tester);
    for (var i = 0; i < 4; i++) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }
    expect(h.snapshotReads, 1);
    expect(h.apparatusReads, 1);
    pending.complete(h.snapshot());
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    await dispose(tester);
  });

  testWidgets(
      'worker recovery: hung old provider cannot block retry or overwrite recovery',
      (tester) async {
    final h = await prepare();
    final old = Completer<AdminApparatusQueueSnapshot>();
    h.readSnapshot = () => old.future;
    await h.mount(tester);
    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text(_recoveryNotice), findsOneWidget);
    h.readSnapshot = () async => h.snapshot(revision: 9);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    old.complete(h.snapshot(revision: 1, empty: true));
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    expect(find.text(_recoveryNotice), findsNothing);
    await dispose(tester);
  });

  testWidgets(
      'worker recovery: one failed read does not wait for a hung sibling',
      (tester) async {
    final h = await prepare();
    final old = Completer<List<AdminApparatus>>();
    h.readSnapshot = () async => throw TimeoutException('offline');
    h.readApparatus = () => old.future;
    await h.mount(tester);
    expect(find.text(_recoveryNotice), findsOneWidget);
    h.readSnapshot = () async => h.snapshot();
    h.readApparatus = () async => h.apparatus;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    old.complete(h.apparatus);
    await dispose(tester);
  });

  testWidgets('worker recovery: healthy worker does not poll full snapshots',
      (tester) async {
    final h = await prepare();
    await h.mount(tester);
    await tester.pump(const Duration(minutes: 1));
    expect(h.snapshotReads, 1);
    expect(h.apparatusReads, 1);
    await dispose(tester);
  });

  testWidgets('worker recovery: quiet healthy live stream is not reconnected',
      (tester) async {
    final h = await prepare();
    final stream = StreamController<AdminProductionMapLiveSnapshot>();
    var connections = 0;
    h.liveEvents = () {
      connections++;
      return stream.stream;
    };
    await h.mount(tester);
    stream.add(h.live());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    expect(h.snapshotReads, 1);
    expect(connections, 1);
    expect(order(), findsOneWidget);
    await dispose(tester);
    unawaited(stream.close());
    await tester.pump();
  });

  testWidgets(
      'worker recovery: live snapshot cannot mask missing apparatus catalog',
      (tester) async {
    final h = await prepare();
    final stream = StreamController<AdminProductionMapLiveSnapshot>.broadcast();
    h.liveEvents = () => stream.stream;
    h.readApparatus = () async => throw TimeoutException('offline catalog');
    await h.mount(tester);
    stream.add(h.live());
    await tester.pumpAndSettle();
    expect(order(), findsNothing);
    h.readApparatus = () async => h.apparatus;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    expect(find.text(_recoveryNotice), findsNothing);
    expect(h.apparatusReads, 2);
    await dispose(tester);
    unawaited(stream.close());
    await tester.pump();
  });

  testWidgets(
      'worker recovery: permission rejection replaces retry notice and stops retrying',
      (tester) async {
    final h = await prepare();
    await h.mount(tester);
    h.readSnapshot = () async => throw TimeoutException('offline');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text(_recoveryNotice), findsOneWidget);
    h.readSnapshot = () async => throw const MobileApiException(
        code: 'forbidden', statusCode: 403, message: 'Permission denied');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(order(), findsOneWidget);
    expect(find.text('Permission denied'), findsOneWidget);
    expect(find.text(_recoveryNotice), findsNothing);
    final reads = h.snapshotReads;
    await tester.pump(const Duration(seconds: 20));
    expect(h.snapshotReads, reads);
    await dispose(tester);
  });

  for (final code in [
    'forbidden',
    'production_map_snapshot_contract_invalid'
  ]) {
    testWidgets('worker recovery: $code is not treated as a transient outage',
        (tester) async {
      final h = await prepare();
      h.readSnapshot = () async =>
          throw MobileApiException(code: code, message: 'Actual error');
      await h.mount(tester);
      expect(find.text('Actual error'), findsOneWidget);
      expect(find.text(_recoveryNotice), findsNothing);
      await tester.pump(const Duration(seconds: 20));
      expect(h.snapshotReads, 1);
      await dispose(tester);
    });
  }

  testWidgets('worker recovery: dispose cancels scheduled retry',
      (tester) async {
    final h = await prepare();
    h.readSnapshot = () async => throw TimeoutException('offline');
    await h.mount(tester);
    await dispose(tester);
    expect(h.snapshotReads, 1);
  });

  for (final cleanClose in [true, false]) {
    testWidgets(
        'worker recovery: live ${cleanClose ? 'close' : 'error'} reconnects without waiting for old cancellation',
        (tester) async {
      final h = await prepare();
      final stuckCancel = Completer<void>();
      final first = StreamController<AdminProductionMapLiveSnapshot>(
        onCancel: cleanClose ? null : () => stuckCancel.future,
      );
      final second = StreamController<AdminProductionMapLiveSnapshot>();
      var connections = 0;
      h.liveEvents = () => ++connections == 1 ? first.stream : second.stream;
      await h.mount(tester);
      first.add(h.live());
      await tester.pump();
      if (cleanClose) {
        unawaited(first.close());
      } else {
        first.addError(TimeoutException('old wifi socket'));
      }
      await tester.pump();
      await tester.pump();
      expect(order(), findsOneWidget);
      expect(find.text(_recoveryNotice), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(connections, 2);
      second.add(h.live());
      await tester.pumpAndSettle();
      expect(find.text(_recoveryNotice), findsNothing);
      expect(order(), findsOneWidget);
      await dispose(tester);
      stuckCancel.complete();
      unawaited(first.close());
      unawaited(second.close());
      await tester.pump();
    });
  }
}
