part of 'admin_production_map_test_screen_test.dart';

const _closedSyncId = 'zakaz-closed-sync';
const _closedSyncTitle = 'Arxiv sinxronlash testi';

class _ClosedOrdersSyncHarness {
  _ClosedOrdersSyncHarness(this.saved, this.apparatus);

  final ProductionMapSaved saved;
  final List<AdminApparatus> apparatus;
  String lifecycle = 'in_progress';
  int? revision = 1;
  int archiveReads = 0;
  Future<List<AdminClosedProductionOrder>> Function()? readArchive;

  bool get closed =>
      const {'cancelled', 'production_completed', 'closed'}.contains(lifecycle);

  AdminClosedProductionOrder get archived =>
      AdminClosedProductionOrder.fromJson({
        'order_id': _closedSyncId,
        'order_number': '0009',
        'title': _closedSyncTitle,
        'completed_at_unix': 123,
        'logs': [],
        'progress_batches': [],
        if (lifecycle == 'cancelled')
          'early_close': {'comment': 'Mijoz rad etdi', 'closed_at_unix': 123},
      });

  AdminProductionMapLiveSnapshot snapshot() => AdminProductionMapLiveSnapshot(
        maps: [saved],
        sequences: {
          _print8Id: [if (!closed) _closedSyncId]
        },
        visibleOrderIds: {
          _print8Id: [if (!closed) _closedSyncId]
        },
        queueStates: const {},
        queuePolicies: const {},
        orderControls: const {},
        orderStatuses: {
          _closedSyncId: AdminProductionOrderStatusDetail(
            lifecycleStatus: lifecycle,
            orderStatus: 'in_progress',
          ),
        },
        completedOrders: const [],
        completionRequests: const [],
        completionRequestDecisions: const [],
        revision: revision,
        epoch: revision == null ? '' : 'closed-sync-server',
      );

  Future<void> mount(WidgetTester tester,
      {Stream<AdminProductionMapLiveSnapshot>? events}) async {
    await _usePhoneViewport(tester);
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
        apparatusLoader: () async => apparatus,
        queueSnapshotLoader: () async => snapshot(),
        closedOrdersLoader: () {
          archiveReads++;
          return readArchive?.call() ?? Future.value([if (closed) archived]);
        },
        completionRequestsLoader: () async => [],
        liveEventsLoader: () => events ?? const Stream.empty(),
      ),
    ));
    await tester.pumpAndSettle();
  }
}

void _registerClosedOrdersSyncTests() {
  Future<_ClosedOrdersSyncHarness> prepare() async {
    await TestModeController.instance.setEnabled(true);
    final saved = await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: _closedSyncId,
        orderNumber: '0009',
        title: _closedSyncTitle,
        productCode: 'CLOSED-SYNC',
        product: 'CLOSED-SYNC',
        apparatusId: _print8Id,
      ),
    );
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    return _ClosedOrdersSyncHarness(
        saved, catalog.where((item) => item.id == _print8Id).toList());
  }

  Future<void> showArchive(WidgetTester tester) async {
    await tester.tap(find.text('Yopilgan'));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  for (final terminal in ['cancelled', 'production_completed', 'closed']) {
    testWidgets(
        'closed archive sync: polling shows $terminal without reopening',
        (tester) async {
      final h = await prepare();
      await h.mount(tester);
      await showArchive(tester);
      expect(find.textContaining(_closedSyncTitle), findsNothing);
      final reads = h.archiveReads;
      h.lifecycle = terminal;
      h.revision = 2;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(h.archiveReads, reads + 1);
      expect(find.textContaining(_closedSyncTitle), findsOneWidget);
      // New revisions for unrelated work must not reload the archive.
      h.revision = 3;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(h.archiveReads, reads + 1);
      await dispose(tester);
    });
  }

  testWidgets('closed archive sync: lifecycle-only legacy update is observed',
      (tester) async {
    final h = await prepare();
    h.revision = null;
    // Both states are already out of active queues; only lifecycle changes.
    h.lifecycle = 'production_completed';
    await h.mount(tester);
    await showArchive(tester);
    final reads = h.archiveReads;
    h.lifecycle = 'closed';
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(h.archiveReads, reads + 1);
    expect(find.textContaining(_closedSyncTitle), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('closed archive sync: live closure refreshes before opening tab',
      (tester) async {
    final h = await prepare();
    final events = StreamController<AdminProductionMapLiveSnapshot>();
    await TestModeController.instance.setEnabled(false);
    await http.runWithClient(() async {
      await h.mount(tester, events: events.stream);
      final reads = h.archiveReads;
      h.lifecycle = 'cancelled';
      h.revision = 2;
      events.add(h.snapshot());
      await tester.pumpAndSettle();
      expect(h.archiveReads, reads + 1);
      expect(
          find.byKey(const ValueKey('sequence-row-$_print8Id-$_closedSyncId')),
          findsNothing);
      // Duplicate/stale live events must not invalidate a fresh archive.
      events.add(h.snapshot());
      h.revision = 1;
      events.add(h.snapshot());
      await tester.pumpAndSettle();
      expect(h.archiveReads, reads + 1);
      await showArchive(tester);
      expect(find.textContaining(_closedSyncTitle), findsOneWidget);
      await dispose(tester);
    }, () => MockClient((_) async => http.Response('{}', 200)));
    unawaited(events.close());
    await tester.pump();
  });

  testWidgets('closed archive sync: closure during slow read queues fresh read',
      (tester) async {
    final h = await prepare();
    await h.mount(tester);
    final oldRead = Completer<List<AdminClosedProductionOrder>>();
    h.readArchive = () => oldRead.future;
    await showArchive(tester);
    final reads = h.archiveReads;
    h.lifecycle = 'cancelled';
    h.revision = 2;
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(h.archiveReads, reads); // No concurrent request.
    h.readArchive = () async => [h.archived];
    oldRead.complete([]);
    await tester.pumpAndSettle();
    expect(h.archiveReads, reads + 1);
    expect(find.textContaining(_closedSyncTitle), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('closed archive sync: entering tab retries failed archive read',
      (tester) async {
    final h = await prepare();
    h.lifecycle = 'cancelled';
    h.readArchive = () async => throw TimeoutException('offline');
    await h.mount(tester);
    expect(find.text('Yopilgan orderlar yuklanmadi'), findsOneWidget);
    h.readArchive = () async => [h.archived];
    await showArchive(tester);
    expect(find.textContaining(_closedSyncTitle), findsOneWidget);
    expect(find.text('Yopilgan orderlar yuklanmadi'), findsNothing);
    await dispose(tester);
  });
}
