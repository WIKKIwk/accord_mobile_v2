part of 'admin_production_map_test_screen_test.dart';

class _AdminPagingHarness {
  _AdminPagingHarness(this.orders, this.snapshot, this.apparatus);
  final List<ProductionMapSaved> orders;
  final AdminApparatusQueueSnapshot snapshot;
  final List<AdminApparatus> apparatus;
  final calls = <AdminProductionOrderPageRequest>[];
  int revision = 1;
  bool conflictOnAppend = false;
  bool reverseOnRevision = true;
  Completer<AdminProductionOrderPage?>? delayed;

  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    calls.add(request);
    if (request.search == 'delayed' && delayed != null) return delayed!.future;
    if (request.cursor != null && conflictOnAppend) {
      conflictOnAppend = false;
      revision++;
      throw const MobileApiException(
          code: 'order_page_changed', message: 'Navbat yangilandi');
    }
    final version =
        '$revision-${request.view}-${request.apparatus}-${request.search}';
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
      epoch: 'page-server',
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
              epoch: 'page-server',
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

  Future<void> mount(WidgetTester tester) async {
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
        // Any accidental legacy snapshot/live read fails this test.
        queueSnapshotLoader: () => throw StateError('full snapshot requested'),
        liveEventsLoader: () => throw StateError('legacy socket opened'),
      ),
    ));
    await tester.pumpAndSettle();
  }
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
    expect(find.text('20 / 65 · Yana 20 ta').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
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
    expect(find.text('40 / 65 · Yana 20 ta').hitTestable(), findsOneWidget);
    expect(tester.state<ScrollableState>(vertical).position.pixels,
        greaterThan(0));
    await tester.tap(find.text('Buyurtmalar').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('20 / 65 · Yana 20 ta').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Ketma-ketlik').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('40 / 65 · Yana 20 ta').hitTestable(), findsOneWidget);
    expect(tester.state<ScrollableState>(vertical).position.pixels,
        greaterThan(0));
    await tester.tap(find.text('40 / 65 · Yana 20 ta').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 / 65 · Yana 20 ta').hitTestable());
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

  testWidgets(
      'admin paging rebases a changed cursor without mixing order versions',
      (tester) async {
    final harness = await prepare();
    await harness.mount(tester);
    harness.conflictOnAppend = true;
    await tester.tap(find.text('20 / 65 · Yana 20 ta').hitTestable());
    await tester.pumpAndSettle();
    final reads = harness.calls
        .where((r) => r.view == 'sequence' && r.ifVersion == null)
        .toList();
    expect(reads.map((r) => r.cursor), [null, '20', null, '20']);
    expect(reads.last.ifVersion, isNull);
    expect(find.text('40 / 65 · Yana 20 ta').hitTestable(), findsOneWidget);
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

  testWidgets('admin paging suspends polling while the app is backgrounded',
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
