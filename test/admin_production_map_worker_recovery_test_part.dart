part of 'admin_production_map_test_screen_test.dart';

const _recoveryProgressKey = ValueKey('production-orders-connection-progress');
const _recoveryOrderId = 'zakaz-worker-recovery';

Future<void> _pumpRecoveryFrames(WidgetTester tester) async {
  // Indeterminate progress deliberately never settles during an outage.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

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

  Future<void> mount(WidgetTester tester, {
    bool workerMode = true,
    Future<List<AdminClosedProductionOrder>> Function()? closedOrdersLoader,
    Future<List<AdminCompletionRequestNotification>> Function()? completionRequestsLoader,
  }) async {
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
        readOnly: workerMode,
        workerMode: workerMode,
        queueSnapshotLoader: () {
          snapshotReads++;
          return readSnapshot?.call() ?? Future.value(snapshot());
        },
        apparatusLoader: () {
          apparatusReads++;
          return readApparatus?.call() ?? Future.value(apparatus);
        },
        liveEventsLoader: liveEvents,
        closedOrdersLoader: closedOrdersLoader,
        completionRequestsLoader: completionRequestsLoader,
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
  void useAdminProfile() {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin-recovery',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
  }
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
      expect(find.byKey(_recoveryProgressKey), findsOneWidget);
      expect(order(), findsNothing);
      offline = false;
      await tester.pump(const Duration(seconds: 2));
      await _pumpRecoveryFrames(tester);
      expect(order(), findsOneWidget);
      expect(find.byKey(_recoveryProgressKey), findsNothing);
      expect(h.snapshotReads, 2);
      expect(h.apparatusReads, 2);
      await dispose(tester);
    });
  }

  for (final failedCatalog in [false, true]) {
    testWidgets(
        'admin connection progress: cold ${failedCatalog ? 'catalog' : 'queue'} failure recovers automatically',
        (tester) async {
      final h = await prepare();
      useAdminProfile();
      var offline = true;
      h.readSnapshot = () async {
        if (offline && !failedCatalog) throw TimeoutException('offline');
        return h.snapshot();
      };
      h.readApparatus = () async {
        if (offline && failedCatalog) throw http.ClientException('offline');
        return h.apparatus.where((item) => item.id == _print7Id).toList();
      };
      await h.mount(tester, workerMode: false);
      await _pumpRecoveryFrames(tester);
      final progress = find.byKey(_recoveryProgressKey);
      expect(progress, findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(progress).value, isNull);
      expect(find.text('Reja menu yuklanmadi'), findsNothing);
      expect(find.text('Qayta urinish'), findsNothing);
      offline = false;
      await tester.pump(const Duration(seconds: 2));
      await _pumpRecoveryFrames(tester);
      expect(progress, findsNothing);
      expect(find.textContaining('Worker recovery'), findsOneWidget);
      expect(h.snapshotReads, 2);
      expect(h.apparatusReads, 2);
      await dispose(tester);
    });
  }

  testWidgets('admin connection progress: warm outage retains rows and clears on same revision',
      (tester) async {
    final h = await prepare();
    useAdminProfile();
    h.readApparatus = () async =>
        h.apparatus.where((item) => item.id == _print7Id).toList();
    await h.mount(tester, workerMode: false);
    await _pumpRecoveryFrames(tester);
    h.readSnapshot = () async => throw http.ClientException('offline');
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    expect(find.textContaining('Worker recovery'), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
    expect(find.text('Qayta urinish'), findsNothing);
    h.readSnapshot = () async => h.snapshot();
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
    expect(find.textContaining('Worker recovery'), findsOneWidget);
    expect(h.apparatusReads, 1);
    await dispose(tester);
  });

  testWidgets('admin connection progress: permission rejection stays visible',
      (tester) async {
    final h = await prepare();
    useAdminProfile();
    h.readSnapshot = () async => throw const MobileApiException(
        code: 'forbidden', statusCode: 403, message: 'Permission denied');
    await h.mount(tester, workerMode: false);
    await _pumpRecoveryFrames(tester);
    expect(find.text('Permission denied'), findsOneWidget);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
    await tester.pump(const Duration(seconds: 20));
    expect(h.snapshotReads, 1);
    await dispose(tester);
  });

  testWidgets('admin connection progress: section outages share one indicator and retry without overlap',
      (tester) async {
    final h = await prepare();
    useAdminProfile();
    var closedReads = 0;
    var requestReads = 0;
    final closedRecovery = Completer<List<AdminClosedProductionOrder>>();
    await h.mount(tester, workerMode: false,
      closedOrdersLoader: () {
        closedReads++;
        if (closedReads == 1) throw TimeoutException('offline archive');
        return closedRecovery.future;
      },
      completionRequestsLoader: () async {
        requestReads++;
        if (requestReads == 1) {
          throw const MobileApiException(code: 'store_failed',
            statusCode: 503, message: 'Server unavailable');
        }
        return [];
      },
    );
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    expect(find.text('Server unavailable'), findsNothing);
    expect(find.text('Yopilgan orderlar yuklanmadi'), findsNothing);
    expect(find.text('Qayta urinish'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(closedReads, 2);
    expect(requestReads, 2);
    await tester.pump(const Duration(seconds: 4));
    await _pumpRecoveryFrames(tester);
    expect(closedReads, 2, reason: 'an outstanding recovery read is not duplicated');
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    closedRecovery.complete([]);
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
    await dispose(tester);
  });

  testWidgets(
      'worker recovery: failed resume keeps rows and same revision clears error',
      (tester) async {
    final h = await prepare();
    await h.mount(tester);
    expect(order(), findsOneWidget);
    h.readSnapshot = () async => throw TimeoutException('old provider');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpRecoveryFrames(tester);
    expect(order(), findsOneWidget);
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    h.readSnapshot = () async => h.snapshot();
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(order(), findsOneWidget);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
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
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    h.readSnapshot = () async => h.snapshot(empty: true);
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
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
    await _pumpRecoveryFrames(tester);
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
    await _pumpRecoveryFrames(tester);
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
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    h.readSnapshot = () async => h.snapshot(revision: 9);
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(order(), findsOneWidget);
    old.complete(h.snapshot(revision: 1, empty: true));
    await _pumpRecoveryFrames(tester);
    expect(order(), findsOneWidget);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
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
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    h.readSnapshot = () async => h.snapshot();
    h.readApparatus = () async => h.apparatus;
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
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
    await _pumpRecoveryFrames(tester);
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
    await _pumpRecoveryFrames(tester);
    expect(order(), findsNothing);
    h.readApparatus = () async => h.apparatus;
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(order(), findsOneWidget);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
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
    await _pumpRecoveryFrames(tester);
    expect(find.byKey(_recoveryProgressKey), findsOneWidget);
    h.readSnapshot = () async => throw const MobileApiException(
        code: 'forbidden', statusCode: 403, message: 'Permission denied');
    await tester.pump(const Duration(seconds: 2));
    await _pumpRecoveryFrames(tester);
    expect(order(), findsOneWidget);
    expect(find.text('Permission denied'), findsOneWidget);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
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
      expect(find.byKey(_recoveryProgressKey), findsNothing);
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
      expect(find.byKey(_recoveryProgressKey), findsNothing);
      expect(h.snapshotReads, 2, reason: 'HTTPS confirms the state during WS outage');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(connections, 2);
      second.add(h.live());
      await _pumpRecoveryFrames(tester);
      expect(find.byKey(_recoveryProgressKey), findsNothing);
      expect(order(), findsOneWidget);
      await dispose(tester);
      stuckCancel.complete();
      unawaited(first.close());
      unawaited(second.close());
      await tester.pump();
    });
  }

  testWidgets('worker recovery: HTTP fallback is bounded and stops on healthy live',
      (tester) async {
    final h = await prepare();
    final first = StreamController<AdminProductionMapLiveSnapshot>();
    final second = StreamController<AdminProductionMapLiveSnapshot>();
    var connections = 0;
    h.liveEvents = () => ++connections == 1 ? first.stream : second.stream;
    await h.mount(tester);
    first.addError(TimeoutException('WS blocked'));
    await tester.pump();
    await tester.pump();
    expect(h.snapshotReads, 2);
    expect(h.apparatusReads, 1);
    expect(find.byKey(_recoveryProgressKey), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(h.snapshotReads, 2, reason: 'fallback does not spin on immediate replies');
    second.add(h.live());
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(h.snapshotReads, 2, reason: 'healthy WS stops HTTP fallback');
    await dispose(tester);
    unawaited(first.close());
    unawaited(second.close());
    await tester.pump();
  });
}
