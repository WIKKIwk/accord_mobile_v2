part of 'admin_production_map_test_screen_test.dart';

class _AdminPagingHarness {
  _AdminPagingHarness(this.orders, this.snapshot, this.apparatus);
  final List<ProductionMapSaved> orders;
  final AdminApparatusQueueSnapshot snapshot;
  final List<AdminApparatus> apparatus;
  final calls = <AdminProductionOrderPageRequest>[];
  int revision = 1;
  String epoch = 'page-server';
  bool conflictOnAppend = false;
  bool reverseOnRevision = true;
  Completer<AdminProductionOrderPage?>? delayed;
  Completer<AdminProductionOrderPage?>? nextRead;
  Object? readError;

  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    calls.add(request);
    if (nextRead != null) {
      final read = nextRead!;
      nextRead = null;
      return read.future;
    }
    if (readError != null) throw readError!;
    if (request.search == 'delayed' && delayed != null) return delayed!.future;
    if (request.cursor != null && conflictOnAppend) {
      conflictOnAppend = false;
      revision++;
      throw const MobileApiException(
          code: 'order_page_changed', message: 'Navbat yangilandi');
    }
    final version =
        '$epoch-$revision-${request.view}-${request.apparatus}-${request.search}';
    if (request.ifVersion == version) return null;
    final source =
        revision == 1 || !reverseOnRevision ? orders : orders.reversed.toList();
    final matching = source
        .where((o) =>
            o.map.title.contains(request.search) &&
            request.view != 'closed' &&
            request.view != 'audit' &&
            (request.view != 'move' || request.apparatus == _print8Id))
        .toList();
    final offset = int.tryParse(request.cursor ?? '') ?? 0;
    final slice = matching.skip(offset).take(20).toList();
    final ids = slice.map((o) => o.map.id).toList();
    return AdminProductionOrderPage(
      version: version,
      total: matching.length,
      offset: offset,
      epoch: epoch,
      revision: revision,
      nextCursor: offset + slice.length < matching.length
          ? '${offset + slice.length}'
          : null,
      orderIds: ids,
      workflowAudit: request.view == 'audit'
          ? const AdminProductionWorkflowAuditReport(
              ok: true,
              checkedOrderCount: 65,
              checkedBatchCount: 0,
              checkedSessionCount: 0,
              violations: [])
          : null,
      snapshot: request.view == 'closed' || request.view == 'audit'
          ? null
          : AdminApparatusQueueSnapshot(
              epoch: epoch,
              revision: revision,
              maps: slice,
              sequences: {_print8Id: ids},
              sequenceVersions: {_print8Id: '${revision - 1}' * 64},
              sequenceRevisions: {_print8Id: revision},
              visibleOrderIds: {_print8Id: ids},
              queueStates: {
                for (final entry in snapshot.queueStates.entries)
                  entry.key: {
                    for (final id in ids)
                      if (entry.value[id] != null) id: entry.value[id]!
                  },
              },
              queuePolicies: snapshot.queuePolicies,
              orderControls: const {},
              stageStates: {
                for (final id in ids)
                  if (snapshot.stageStates[id] != null)
                    id: snapshot.stageStates[id]!
              },
              queueActionControls: {
                for (final entry in snapshot.queueActionControls.entries)
                  entry.key: {
                    for (final id in ids)
                      if (entry.value[id] != null) id: entry.value[id]!
                  },
              },
            ),
    );
  }

  Future<void> mount(WidgetTester tester,
      {Stream<AdminProductionMapLiveMessage> Function()? liveEventsLoader}) async {
    await _usePhoneViewport(tester);
    await AdminSequenceApparatusStore.instance.saveApparatus(apparatus.first);
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
        apparatusLoader: () async => apparatus, orderPageLoader: read,
        completionRequestsLoader: () async => [],
        // Paged HTTP reads must not fetch a full snapshot.
        queueSnapshotLoader: () => throw StateError('full snapshot requested'),
        liveEventsLoader: liveEventsLoader ??
            () => throw StateError('test-mode socket opened'),
      ),
    ));
    await tester.pumpAndSettle();
  }
}

int _adminSequenceRowCount(WidgetTester tester) => tester
    .widget<ReorderableListView>(find.byType(ReorderableListView).first)
    .itemCount;

Finder _adminPageScroll() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .hitTestable()
    .first;

Future<void> _scrollAdminPage(WidgetTester tester) async {
  final scroll = _adminPageScroll();
  final position = tester.state<ScrollableState>(scroll).position;
  position.jumpTo(
    (position.maxScrollExtent - 200)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble(),
  );
  await tester.pump();
  await tester.drag(scroll, const Offset(0, -300));
}

Future<void> _scrollAdminPageToTop(WidgetTester tester) async {
  tester.state<ScrollableState>(_adminPageScroll()).position.jumpTo(0);
  await tester.pump();
}

void _registerAdminPagingTests() {
  Future<_AdminPagingHarness> prepare() async {
    await TestModeController.instance.setEnabled(true);
    for (var index = 0; index < 65; index++) {
      final number = index.toString().padLeft(4, '0');
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: 'zakaz-page-$number',
        orderNumber: number,
        title: 'Page product $number',
        productCode: 'PAGE-$number',
        product: 'Page product $number',
        apparatusId: _print8Id,
      ).copyWith(baseLength: 100, orderKg: 50));
    }
    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    return _AdminPagingHarness(
      snapshot.maps.toList()..sort((a, b) => a.map.id.compareTo(b.map.id)),
      snapshot,
      [
        catalog.firstWhere((a) => a.id == _print8Id),
        catalog.firstWhere((a) => a.id == _print7Id),
      ],
    );
  }

  testWidgets(
      'admin paging preloads first windows and only scroll loads another twenty',
      (tester) async {
    final harness = await prepare();
    await harness.mount(tester);
    expect(harness.calls.map((r) => r.view).toList(),
        ['sequence', 'orders', 'move', 'move', 'closed', 'audit']);
    expect(harness.calls.every((r) => r.cursor == null), isTrue);
    expect(_adminSequenceRowCount(tester), 20);
    expect(find.textContaining('Yana 20 ta'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(harness.calls, hasLength(6), reason: 'No periodic admin page reads');
    expect(harness.calls.where((r) => r.cursor != null), isEmpty);
    expect(
        harness.calls
            .skip(6)
            .every((r) => r.view == 'sequence' && r.ifVersion != null),
        isTrue);
    final vertical = find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .hitTestable()
        .first;
    await tester.drag(vertical, const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(harness.calls.where((r) => r.cursor != null).map((r) => r.cursor),
        ['20']);
    expect(_adminSequenceRowCount(tester), 40);
    expect(tester.state<ScrollableState>(vertical).position.pixels,
        greaterThan(0));
    final savedOffset = tester.state<ScrollableState>(vertical).position.pixels;
    final readsBeforeTabs = harness.calls.length;
    await tester.tap(find.text('Buyurtmalar').hitTestable());
    await tester.pumpAndSettle();
    final orderList = find.descendant(
        of: find.byKey(const PageStorageKey('admin-opened-orders')),
        matching: find.byType(SliverList));
    expect(tester.widget<SliverList>(orderList).delegate.estimatedChildCount, 20);
    await tester.tap(find.text('Ketma-ketlik').hitTestable());
    await tester.pumpAndSettle();
    expect(_adminSequenceRowCount(tester), 40);
    expect(tester.state<ScrollableState>(vertical).position.pixels,
        closeTo(savedOffset, 0.01));
    expect(harness.calls.length, readsBeforeTabs);
    await _scrollAdminPage(tester);
    await tester.pumpAndSettle();
    await _scrollAdminPage(tester);
    await tester.pumpAndSettle();
    expect(harness.calls.where((r) => r.cursor != null).map((r) => r.cursor),
        ['20', '40', '60']);
    expect(
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .itemCount,
        65);
    expect(find.textContaining('Yana 20 ta').hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging reuses clean tabs for taps and swipes', (
    tester,
  ) async {
    final harness = await prepare();
    await harness.mount(tester);
    final reads = harness.calls.length;
    for (var round = 0; round < 2; round++) {
      for (final label in [
        'Buyurtmalar',
        'Ko‘chirish',
        'Yopilgan',
        'Tekshiruv',
        'Ketma-ketlik',
      ]) {
        await tester.tap(find.text(label).hitTestable());
        await tester.pumpAndSettle();
        expect(
          harness.calls.length,
          reads,
          reason: 'Cached $label must be reused',
        );
        expect(find.byKey(_recoveryProgressKey), findsNothing);
        expect(
          find.byType(CircularProgressIndicator).hitTestable(),
          findsNothing,
        );
        expect(find.textContaining('Yana 20 ta'), findsNothing);
      }
    }
    final width = tester.getSize(find.byType(TabBarView)).width;
    await tester.drag(find.byType(TabBarView), Offset(-width * 0.8, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await tester.drag(find.byType(TabBarView), Offset(width * 0.8, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(harness.calls.length, reads);
    expect(_adminSequenceRowCount(tester), 20);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final label in ['Buyurtmalar', 'Ko‘chirish', 'Yopilgan', 'Tekshiruv']) {
    testWidgets(
      'admin paging reuses the top progress line for an unloaded $label tab',
      (tester) async {
        final harness = await prepare();
        await harness.mount(tester);
        // A new search has no cached hidden windows or background prefetch.
        await tester.enterText(find.byType(EditableText).first, 'Page product');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        final blocked = Completer<AdminProductionOrderPage?>();
        harness.nextRead = blocked;
        await tester.tap(find.text(label).hitTestable());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        final progress = find.byKey(_recoveryProgressKey);
        expect(progress, findsOneWidget);
        expect(tester.widget<LinearProgressIndicator>(progress).value, isNull);
        expect(
          tester.getTopLeft(progress).dy,
          closeTo(tester.getBottomLeft(find.byType(TabBar)).dy, 0.01),
        );
        expect(
          find.byType(CircularProgressIndicator).hitTestable(),
          findsNothing,
        );
        expect(find.textContaining('Yana 20 ta'), findsNothing);
        blocked.complete(await harness.read(harness.calls.last));
        await tester.pumpAndSettle();
        expect(progress, findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('admin paging keeps cached rows while a dirty tab refreshes', (
    tester,
  ) async {
    final harness = await prepare();
    final events = StreamController<AdminProductionMapLiveMessage>();
    events.add(
      AdminProductionMapPageChange(
        epoch: harness.epoch,
        revision: harness.revision,
        ready: true,
      ),
    );
    addTearDown(events.close);
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () => events.stream);
    harness.revision = 2;
    final fresh = await harness.read(
      const AdminProductionOrderPageRequest(view: 'orders'),
    );
    events.add(
      AdminProductionMapPageChange(
        epoch: harness.epoch,
        revision: harness.revision,
      ),
    );
    await tester.pumpAndSettle();
    final before = harness.calls.length;
    final blocked = Completer<AdminProductionOrderPage?>();
    harness.nextRead = blocked;
    await tester.tap(find.text('Buyurtmalar').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(harness.calls.length, before + 1);
    expect(harness.calls.last.view, 'orders');
    expect(
      find.byKey(const ValueKey('opened-order-zakaz-page-0000')).hitTestable(),
      findsOneWidget,
    );
    final progress = find.byKey(_recoveryProgressKey);
    expect(progress, findsOneWidget);
    expect(
      tester.getTopLeft(progress).dy,
      closeTo(tester.getBottomLeft(find.byType(TabBar)).dy, 0.01),
    );
    expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing);
    await tester.tap(find.text('Ketma-ketlik').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(
      progress,
      findsNothing,
      reason: 'Hidden reads do not animate the active tab',
    );
    await tester.tap(find.text('Buyurtmalar').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(harness.calls.length, before + 1, reason: 'Reuse the pending read');
    expect(
      find.byKey(const ValueKey('opened-order-zakaz-page-0000')).hitTestable(),
      findsOneWidget,
    );
    blocked.complete(fresh);
    await tester.pumpAndSettle();
    expect(progress, findsNothing);
    expect(
      find.byKey(const ValueKey('opened-order-zakaz-page-0064')).hitTestable(),
      findsOneWidget,
    );
    expect(harness.calls.length, before + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'admin paging rebases a changed cursor without mixing order versions',
      (tester) async {
    final harness = await prepare();
    await harness.mount(tester);
    harness.conflictOnAppend = true;
    await _scrollAdminPage(tester);
    await tester.pumpAndSettle();
    final reads = harness.calls
        .where((r) => r.view == 'sequence' && r.ifVersion == null)
        .toList();
    expect(reads.map((r) => r.cursor), [null, '20', null, '20']);
    expect(reads.last.ifVersion, isNull);
    expect(_adminSequenceRowCount(tester), 40);
    await _scrollAdminPageToTop(tester);
    expect(
        find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging ignores a late response for the previous search',
      (tester) async {
    final harness = await prepare();
    await harness.mount(tester);
    harness.delayed = Completer<AdminProductionOrderPage?>();
    await tester.enterText(find.byType(EditableText).first, 'delayed');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(EditableText).first, '0064');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    harness.delayed!.complete(const AdminProductionOrderPage(
      version: 'old-search',
      epoch: 'page-server',
      revision: 1,
      total: 0,
      offset: 0,
    ));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging only refreshes on resume while backgrounded',
      (tester) async {
    final harness = await prepare();
    await harness.mount(tester);
    final reads = harness.calls.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 8));
    expect(harness.calls.length, reads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(harness.calls.length, greaterThan(reads));
    expect(harness.calls.where((r) => r.cursor != null), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging uses the original delta socket without polling',
      (tester) async {
    final harness = await prepare();
    harness.reverseOnRevision = false;
    final events = StreamController<AdminProductionMapLiveMessage>();
    events.add(AdminProductionMapPageChange(
        epoch: harness.epoch, revision: harness.revision, ready: true));
    addTearDown(events.close);
    var connections = 0;
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () {
      connections++;
      return events.stream;
    });
    expect(connections, 1);
    expect(harness.calls, hasLength(6));
    events.add(const AdminProductionMapPageChange(
        epoch: 'page-server', revision: 1, ready: true));
    await tester.pumpAndSettle();
    expect(harness.calls, hasLength(6));
    final ids = harness.orders.map((order) => order.map.id).toList();
    harness.orders.insert(1, harness.orders.removeAt(0));
    harness.revision = 2;
    final delta = AdminProductionMapLiveDelta(
      epoch: 'page-server',
      apparatus: _print8Id,
      baseRevision: 1,
      revision: 2,
      snapshotRevision: 2,
      baseVersion: '0' * 64,
      version: '1' * 64,
      ops: [
        AdminProductionMapDeltaOp(
            type: 'move', id: ids[0], afterId: ids[1], beforeId: ids[2]),
      ],
    );
    events.add(delta);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.textContaining('Page product 0001').first).dy,
      lessThan(tester.getTopLeft(find.textContaining('Page product 0000').first).dy),
    );
    // A duplicate delta must not move the row a second time.
    events.add(delta);
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(connections, 1);
    expect(harness.calls, hasLength(7),
        reason: 'Socket events must not start periodic HTTP reads');
    expect(_adminSequenceRowCount(tester), 20);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging delta brings an unseen order into only the loaded prefix',
      (tester) async {
    final harness = await prepare();
    harness.reverseOnRevision = false;
    final events = StreamController<AdminProductionMapLiveMessage>();
    events.add(AdminProductionMapPageChange(
        epoch: harness.epoch, revision: harness.revision, ready: true));
    addTearDown(events.close);
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () => events.stream);
    final first = harness.orders.first.map.id;
    final last = harness.orders.removeLast();
    harness.orders.insert(0, last);
    harness.revision = 2;
    events.add(AdminProductionMapLiveDelta(
      epoch: harness.epoch, apparatus: _print8Id,
      baseRevision: 1, revision: 2, snapshotRevision: 2,
      baseVersion: '0' * 64, version: '1' * 64,
      ops: [AdminProductionMapDeltaOp(type: 'move', id: last.map.id, beforeId: first)],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    expect(_adminSequenceRowCount(tester), 20);
    expect(harness.calls.skip(6).map((r) => r.view), ['sequence']);
    expect(harness.calls.every((r) => r.cursor == null), isTrue);
    await tester.tap(find.text('Buyurtmalar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ketma-ketlik').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging applies an in-window delta before its HTTP reconciliation',
      (tester) async {
    final harness = await prepare();
    harness.reverseOnRevision = false;
    final events = StreamController<AdminProductionMapLiveMessage>();
    events.add(AdminProductionMapPageChange(
        epoch: harness.epoch, revision: harness.revision, ready: true));
    addTearDown(events.close);
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () => events.stream);
    final ids = harness.orders.map((o) => o.map.id).toList();
    harness.orders.insert(1, harness.orders.removeAt(0));
    harness.revision = 2;
    final fresh = await harness.read(const AdminProductionOrderPageRequest(
        view: 'sequence', apparatus: _print8Id));
    final blocked = Completer<AdminProductionOrderPage?>();
    harness.nextRead = blocked;
    events.add(AdminProductionMapLiveDelta(
        epoch: harness.epoch, apparatus: _print8Id,
        baseRevision: 1, revision: 2, snapshotRevision: 2,
        baseVersion: '0' * 64, version: '1' * 64,
        ops: [AdminProductionMapDeltaOp(
            type: 'move', id: ids[0], afterId: ids[1], beforeId: ids[2])]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(blocked.isCompleted, isFalse);
    expect(tester.getTopLeft(find.textContaining('Page product 0001').first).dy,
        lessThan(tester.getTopLeft(find.textContaining('Page product 0000').first).dy));
    blocked.complete(fresh);
    await tester.pumpAndSettle();
    expect(_adminSequenceRowCount(tester), 20);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging delta gap repairs only twenty rows and ignores stale deltas',
      (tester) async {
    final harness = await prepare();
    final events = StreamController<AdminProductionMapLiveMessage>();
    events.add(AdminProductionMapPageChange(
        epoch: harness.epoch, revision: harness.revision, ready: true));
    addTearDown(events.close);
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () => events.stream);
    harness.revision = 5;
    events.add(AdminProductionMapLiveDelta(
        epoch: harness.epoch, apparatus: _print8Id,
        baseRevision: 4, revision: 5, snapshotRevision: 5,
        baseVersion: '3' * 64, version: '4' * 64,
        ops: [AdminProductionMapDeltaOp(type: 'move',
            id: harness.orders.last.map.id, beforeId: harness.orders.first.map.id)]));
    await tester.pumpAndSettle();
    expect(harness.calls, hasLength(7));
    expect(harness.calls.every((r) => r.cursor == null), isTrue);
    expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    events.add(AdminProductionMapLiveDelta(
        epoch: harness.epoch, apparatus: _print8Id,
        baseRevision: 1, revision: 2, snapshotRevision: 2,
        baseVersion: '0' * 64, version: '1' * 64, ops: const []));
    await tester.pumpAndSettle();
    expect(harness.calls, hasLength(7));
    expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging live invalidation refreshes forty requested rows and no hidden tabs',
      (tester) async {
    final harness = await prepare();
    final events = StreamController<AdminProductionMapLiveMessage>();
    events.add(AdminProductionMapPageChange(
        epoch: harness.epoch, revision: harness.revision, ready: true));
    addTearDown(events.close);
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () => events.stream);
    await _scrollAdminPage(tester);
    await tester.pumpAndSettle();
    await _scrollAdminPageToTop(tester);
    final before = harness.calls.length;
    harness.revision = 2;
    events.add(AdminProductionMapPageChange(epoch: harness.epoch, revision: 2));
    await tester.pumpAndSettle();
    expect(harness.calls.skip(before).map((r) => r.cursor), [null, '20']);
    expect(harness.calls.skip(before).every((r) => r.view == 'sequence'), isTrue);
    expect(_adminSequenceRowCount(tester), 40);
    expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    final settled = harness.calls.length;
    await tester.pump(const Duration(seconds: 30));
    expect(harness.calls.length, settled);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final staleResponses in [3, 6]) {
    testWidgets(
      'admin paging drains socket changes after $staleResponses stale responses',
      (tester) async {
        final harness = await prepare();
        harness.reverseOnRevision = false;
        final events = StreamController<AdminProductionMapLiveMessage>();
        events.add(
          AdminProductionMapPageChange(
            epoch: harness.epoch,
            revision: harness.revision,
            ready: true,
          ),
        );
        addTearDown(events.close);
        await TestModeController.instance.setEnabled(false);
        await harness.mount(tester, liveEventsLoader: () => events.stream);
        final replies = <AdminProductionOrderPage?>[];
        final changes = <AdminProductionMapLiveMessage>[];
        final finalRevision = staleResponses + 2;
        for (var revision = 2; revision <= finalRevision; revision++) {
          harness.revision = revision;
          final moved = harness.orders.removeLast();
          final beforeId = harness.orders.first.map.id;
          harness.orders.insert(0, moved);
          changes.add(
            staleResponses == 3
                ? AdminProductionMapLiveDelta(
                    epoch: harness.epoch,
                    apparatus: _print8Id,
                    baseRevision: revision - 1,
                    revision: revision,
                    snapshotRevision: revision,
                    baseVersion: '${revision - 2}' * 64,
                    version: '${revision - 1}' * 64,
                    ops: [
                      AdminProductionMapDeltaOp(
                        type: 'move',
                        id: moved.map.id,
                        beforeId: beforeId,
                      ),
                    ],
                  )
                : AdminProductionMapPageChange(
                    epoch: harness.epoch,
                    revision: revision,
                  ),
          );
          if (revision < finalRevision) {
            replies.add(
              await harness.read(
                const AdminProductionOrderPageRequest(
                  view: 'sequence',
                  apparatus: _print8Id,
                ),
              ),
            );
          }
        }
        final expectedFirst = harness.orders.first.map.title;
        final before = harness.calls.length;
        var blocked = Completer<AdminProductionOrderPage?>();
        harness.nextRead = blocked;
        harness.revision = 2;
        events.add(changes.first);
        await tester.pump();
        for (var revision = 3; revision <= finalRevision; revision++) {
          final previous = blocked;
          if (revision < finalRevision) {
            blocked = Completer<AdminProductionOrderPage?>();
            harness.nextRead = blocked;
          }
          harness.revision = revision;
          events.add(changes[revision - 2]);
          await tester.pump();
          previous.complete(replies[revision - 3]);
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.textContaining(expectedFirst).hitTestable(), findsWidgets);
        expect(find.text('Navbat yangilandi').hitTestable(), findsNothing);
        expect(_adminSequenceRowCount(tester), 20);
        final reads = harness.calls.skip(before).toList();
        expect(reads, hasLength(staleResponses + 1));
        expect(
          reads.every((r) => r.view == 'sequence' && r.cursor == null),
          isTrue,
        );
        final settled = harness.calls.length;
        await tester.pump(const Duration(seconds: 30));
        expect(
          harness.calls.length,
          settled,
          reason: 'No polling after the burst',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'admin paging coalesces a burst and preserves a requested scroll page',
    (tester) async {
      final harness = await prepare();
      final events = StreamController<AdminProductionMapLiveMessage>();
      events.add(
        AdminProductionMapPageChange(
          epoch: harness.epoch,
          revision: harness.revision,
          ready: true,
        ),
      );
      addTearDown(events.close);
      await TestModeController.instance.setEnabled(false);
      await harness.mount(tester, liveEventsLoader: () => events.stream);
      final stale = await harness.read(
        const AdminProductionOrderPageRequest(
          view: 'sequence',
          apparatus: _print8Id,
          cursor: '20',
        ),
      );
      final blocked = Completer<AdminProductionOrderPage?>();
      harness.nextRead = blocked;
      final before = harness.calls.length;
      await _scrollAdminPage(tester);
      await tester.pump();
      await _scrollAdminPageToTop(tester);
      final progress = find.byKey(_recoveryProgressKey);
      expect(progress, findsOneWidget);
      expect(tester.getTopLeft(progress).dy,
          closeTo(tester.getBottomLeft(find.byType(TabBar)).dy, 0.01));
      expect(_adminSequenceRowCount(tester), 20);
      expect(find.byType(CircularProgressIndicator).hitTestable(), findsNothing);
      for (var revision = 2; revision <= 20; revision++) {
        harness.revision = revision;
        events.add(
          AdminProductionMapPageChange(
            epoch: harness.epoch,
            revision: revision,
          ),
        );
      }
      await tester.pump();
      expect(
        harness.calls.length,
        before + 1,
        reason: 'All socket events share the one pending read',
      );
      blocked.complete(stale);
      await tester.pumpAndSettle();
      expect(harness.calls.skip(before).map((r) => r.cursor), [
        '20',
        null,
        '20',
      ]);
      expect(
        harness.calls.skip(before).every((r) => r.view == 'sequence'),
        isTrue,
      );
      expect(_adminSequenceRowCount(tester), 40);
      expect(
        find.textContaining('Page product 0064').hitTestable(),
        findsWidgets,
      );
      final settled = harness.calls.length;
      await tester.pump(const Duration(seconds: 30));
      expect(harness.calls.length, settled);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final eventAtCompletion in [false, true]) {
    testWidgets(
      'admin paging keeps a socket change ${eventAtCompletion ? 'at completion of' : 'queued during'} a failed read',
      (tester) async {
        final harness = await prepare();
        final events = StreamController<AdminProductionMapLiveMessage>();
        events.add(
          AdminProductionMapPageChange(
            epoch: harness.epoch,
            revision: harness.revision,
            ready: true,
          ),
        );
        addTearDown(events.close);
        await TestModeController.instance.setEnabled(false);
        await harness.mount(tester, liveEventsLoader: () => events.stream);
        final before = harness.calls.length;
        final blocked = Completer<AdminProductionOrderPage?>();
        harness.nextRead = blocked;
        harness.revision = 2;
        events.add(
          AdminProductionMapPageChange(epoch: harness.epoch, revision: 2),
        );
        await tester.pump();
        harness.revision = 3;
        const failure = MobileApiException(
          code: 'server_error',
          message: 'Server xatosi',
          statusCode: 500,
        );
        if (eventAtCompletion) blocked.completeError(failure);
        events.add(
          AdminProductionMapPageChange(epoch: harness.epoch, revision: 3),
        );
        if (!eventAtCompletion) {
          await tester.pump();
          blocked.completeError(failure);
        }
        await tester.pumpAndSettle();
        expect(harness.calls.length, before + 2);
        expect(
          find.textContaining('Page product 0064').hitTestable(),
          findsWidgets,
        );
        expect(find.text('Server xatosi').hitTestable(), findsNothing);
        final settled = harness.calls.length;
        await tester.pump(const Duration(seconds: 30));
        expect(harness.calls.length, settled);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'admin paging stops failed reads when no newer socket change arrives',
    (tester) async {
      final harness = await prepare();
      final events = StreamController<AdminProductionMapLiveMessage>();
      events.add(
        AdminProductionMapPageChange(
          epoch: harness.epoch,
          revision: harness.revision,
          ready: true,
        ),
      );
      addTearDown(events.close);
      await TestModeController.instance.setEnabled(false);
      await harness.mount(tester, liveEventsLoader: () => events.stream);
      harness.readError = const MobileApiException(
        code: 'order_page_changed',
        message: 'Navbat yangilandi',
      );
      final before = harness.calls.length;
      events.add(
        AdminProductionMapPageChange(epoch: harness.epoch, revision: 2),
      );
      await tester.pumpAndSettle();
      expect(harness.calls.length, before + 3);
      expect(find.text('Navbat yangilandi').hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(
        harness.calls.length,
        before + 3,
        reason: 'A dirty window alone must never start repeated HTTP reads',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final background in [false, true]) {
    testWidgets(
      'admin paging defers queued socket reads after ${background ? 'backgrounding' : 'a tab switch'}',
      (tester) async {
        final harness = await prepare();
        final events =
            StreamController<AdminProductionMapLiveMessage>.broadcast();
        addTearDown(events.close);
        await TestModeController.instance.setEnabled(false);
        await harness.mount(
          tester,
          liveEventsLoader: () async* {
            yield AdminProductionMapPageChange(
              epoch: harness.epoch,
              revision: harness.revision,
              ready: true,
            );
            yield* events.stream;
          },
        );
        harness.revision = 2;
        final stale = await harness.read(
          const AdminProductionOrderPageRequest(
            view: 'sequence',
            apparatus: _print8Id,
          ),
        );
        final before = harness.calls.length;
        final blocked = Completer<AdminProductionOrderPage?>();
        harness.nextRead = blocked;
        events.add(
          AdminProductionMapPageChange(epoch: harness.epoch, revision: 2),
        );
        await tester.pump();
        harness.revision = 3;
        events.add(
          AdminProductionMapPageChange(epoch: harness.epoch, revision: 3),
        );
        await tester.pump();
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
        } else {
          await tester.tap(find.text('Buyurtmalar').hitTestable());
          await tester.pump(const Duration(milliseconds: 300));
        }
        blocked.complete(stale);
        await tester.pumpAndSettle();
        expect(
          harness.calls.skip(before).where((r) => r.view == 'sequence'),
          hasLength(1),
        );
        final settled = harness.calls.length;
        await tester.pump(const Duration(seconds: 30));
        expect(harness.calls.length, settled);
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else {
          await tester.tap(find.text('Ketma-ketlik').hitTestable());
        }
        await tester.pumpAndSettle();
        expect(
          harness.calls.skip(before).where((r) => r.view == 'sequence'),
          hasLength(2),
        );
        expect(
          find.textContaining('Page product 0064').hitTestable(),
          findsWidgets,
        );
        expect(_adminSequenceRowCount(tester), 20);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'admin paging does not retry forbidden reads for queued socket changes',
    (tester) async {
      final harness = await prepare();
      final events = StreamController<AdminProductionMapLiveMessage>();
      events.add(
        AdminProductionMapPageChange(
          epoch: harness.epoch,
          revision: harness.revision,
          ready: true,
        ),
      );
      addTearDown(events.close);
      await TestModeController.instance.setEnabled(false);
      await harness.mount(tester, liveEventsLoader: () => events.stream);
      final before = harness.calls.length;
      final blocked = Completer<AdminProductionOrderPage?>();
      harness.nextRead = blocked;
      events.add(
        AdminProductionMapPageChange(epoch: harness.epoch, revision: 2),
      );
      await tester.pump();
      events.add(
        AdminProductionMapPageChange(epoch: harness.epoch, revision: 3),
      );
      await tester.pump();
      blocked.completeError(
        const MobileApiException(
          code: 'forbidden',
          message: 'Ruxsat yo‘q',
          statusCode: 403,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ruxsat yo‘q').hitTestable(), findsOneWidget);
      expect(harness.calls.length, before + 1);
      await tester.pump(const Duration(seconds: 30));
      expect(harness.calls.length, before + 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('admin paging rejects a pre-delta 304 and an old server response',
      (tester) async {
    final harness = await prepare();
    final events = StreamController<AdminProductionMapLiveMessage>.broadcast();
    addTearDown(events.close);
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () async* {
      yield AdminProductionMapPageChange(
          epoch: harness.epoch, revision: harness.revision, ready: true);
      yield* events.stream;
    });
    for (final restart in [false, true]) {
      final oldPage = await harness.read(const AdminProductionOrderPageRequest(
          view: 'sequence', apparatus: _print8Id));
      final blocked = Completer<AdminProductionOrderPage?>();
      harness.nextRead = blocked;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(harness.calls.last.ifVersion, oldPage!.version);
      harness.revision++;
      if (restart) harness.epoch = 'restarted-server';
      events.add(AdminProductionMapPageChange(
          epoch: harness.epoch, revision: harness.revision, ready: restart));
      await tester.pump();
      blocked.complete(restart ? oldPage : null);
      await tester.pumpAndSettle();
      expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
      expect(_adminSequenceRowCount(tester), 20);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin paging socket reconnect reconciles missed changes without HTTP polling',
      (tester) async {
    final harness = await prepare();
    final connections = <StreamController<AdminProductionMapLiveMessage>>[];
    await TestModeController.instance.setEnabled(false);
    await harness.mount(tester, liveEventsLoader: () {
      final events = StreamController<AdminProductionMapLiveMessage>();
      connections.add(events);
      scheduleMicrotask(() => events.add(AdminProductionMapPageChange(
          epoch: harness.epoch, revision: harness.revision, ready: true)));
      return events.stream;
    });
    expect(connections, hasLength(1));
    final before = harness.calls.length;
    harness.revision = 2;
    unawaited(connections.first.close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(connections, hasLength(2));
    expect(harness.calls.length, before + 1);
    expect(find.textContaining('Page product 0064').hitTestable(), findsWidgets);
    final settled = harness.calls.length;
    await tester.pump(const Duration(seconds: 30));
    expect(harness.calls.length, settled);
    await tester.pumpWidget(const SizedBox());
    for (final connection in connections.skip(1)) {
      unawaited(connection.close());
    }
  });

  testWidgets('admin paging reorder at row twenty keeps unseen orders in place',
      (tester) async {
    final harness = await prepare();
    harness.reverseOnRevision = false;
    final original = harness.orders.map((o) => o.map.id).toList();
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await harness.mount(tester);
      await TestModeController.instance.setEnabled(false);
      await tester.pump();
      final list =
          tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      expect(list.itemCount, 20);
      list.onReorderItem!(0, 19);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    },
        () => MockClient((request) async {
              expectSync(request.url.path,
                  '/v1/mobile/admin/production-maps/sequence');
              final body =
                  (jsonDecode(request.body) as Map).cast<String, dynamic>();
              requests.add(body);
              expectSync(body['order_id'], original.first);
              expectSync(body['after_order_id'], original[19]);
              expectSync(body.containsKey('before_order_id'), isFalse);
              expectSync(body.containsKey('order_ids'), isFalse,
                  reason: 'a page must never replace the full queue');
              final moved = harness.orders.removeAt(0);
              harness.orders.insert(19, moved);
              harness.revision++;
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'order_ids': harness.orders.map((o) => o.map.id).toList(),
                    'version': '1' * 64,
                    'revision': 2,
                    'epoch': 'page-server',
                    'adjusted': false,
                  }),
                  200);
            }));
    expect(requests, hasLength(1));
    expect(harness.orders.skip(20).map((o) => o.map.id), original.skip(20));
    expect(
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .itemCount,
        20);
    expect(harness.calls.where((r) => r.cursor != null), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
