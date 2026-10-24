part of 'admin_production_map_test_screen_test.dart';

void _registerAdminWarmNavigationTests() {
  Future<
          (
            _AdminPageCacheNavigationHarness,
            AdminSequenceWarmStore,
            StreamController<AdminProductionMapLiveMessage>
          )>
      prepare(WidgetTester tester,
          {Completer<AdminProductionOrderPage?>? pending}) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final harness = _AdminPageCacheNavigationHarness(fixture);
    await harness.host(tester);
    final events = StreamController<AdminProductionMapLiveMessage>.broadcast();
    final store = AdminSequenceWarmStore(
      apparatusLoader: () async => [
        fixture.apparatus.firstWhere((a) => a.id == scanApparatus),
      ],
      selectedApparatusLoader: (_) async => scanApparatus,
      pageLoader: (request) async {
        if (request.view == 'orders') {
          harness.reads.add(request);
          return AdminProductionOrderPage.fromJson({
            'projection': 'orders_list_v1',
            'version': 'orders-v${harness.revision}',
            'epoch': harness.serverEpoch,
            'scope': 'warm-navigation-orders',
            'rev': harness.revision,
            'offset': 0,
            'total': 0,
            'next_cursor': null,
            'order_ids': <String>[],
            'rows': <String, dynamic>{},
            'pending_ids': <String>[],
            'pending_rows': <String, dynamic>{},
          });
        }
        if (pending != null && request.view == 'sequence') {
          harness.reads.add(request);
          return pending.future;
        }
        return harness.read(request);
      },
      liveLoader: (_) => events.stream,
      scopeReader: currentAdminSequenceWarmScope,
    );
    addTearDown(() async {
      store.configure(scope: null, foreground: false);
      await events.close();
    });
    store.configure(
      scope: currentAdminSequenceWarmScope(),
      foreground: true,
    );
    return (harness, store, events);
  }

  testWidgets('warm navigation: first frame has real rows without page GET',
      (tester) async {
    final (harness, store, _) = await prepare(tester);
    await store.prepare(currentAdminSequenceWarmScope());
    await tester.pumpAndSettle();
    final reads = harness.reads.length;
    expect(reads, 4);
    expect(harness.reads.where((r) => r.view == 'sequence'), hasLength(1));
    expect(harness.reads.where((r) => r.view == 'orders'), hasLength(1));
    await harness.open(tester, sequenceWarmStore: store, settle: false);
    harness.expectRows(tester, harness.ids);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    expect(harness.reads.length, reads);
    expect(harness.catalogReads, 0);
    await tester.pumpAndSettle();
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(harness.reads.length, reads);
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });

  testWidgets('warm navigation: opening during preload joins the same GET',
      (tester) async {
    final pending = Completer<AdminProductionOrderPage?>();
    final (harness, store, _) = await prepare(tester, pending: pending);
    await tester.pump();
    expect(harness.reads.length, 1);
    await harness.open(tester, sequenceWarmStore: store, settle: false);
    await tester.pump(const Duration(milliseconds: 50));
    expect(harness.reads.length, 1);
    pending
        .complete(await AdminProductionOrderPage.fromJson(harness.payload()));
    await tester.pumpAndSettle();
    harness.expectRows(tester, harness.ids);
    expect(harness.reads.where((r) => r.view == 'sequence'), hasLength(1));
    expect(harness.reads.where((r) => r.view == 'orders'), hasLength(1));
    expect(harness.catalogReads, 0);
    await harness.ready(tester);
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });

  testWidgets('warm navigation: background delta is visible on first frame',
      (tester) async {
    final (harness, store, events) = await prepare(tester);
    await store.prepare(currentAdminSequenceWarmScope());
    harness.ids.setAll(0, harness.ids.reversed.toList());
    harness.revision++;
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': AdminSequenceWarmStore.windowId,
      'epoch': 'scan-server',
      'rev': harness.revision,
      'base_version': 'v7',
      'version': 'v${harness.revision}',
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {'op': 'set', 'path': [], 'value': harness.payload()},
          ],
        },
      ],
    }));
    await tester.pumpAndSettle();
    expect(store.peek(currentAdminSequenceWarmScope())!.page.revision,
        harness.revision);
    final reads = harness.reads.length;
    await harness.open(tester, sequenceWarmStore: store, settle: false);
    harness.expectRows(tester, harness.ids);
    expect(harness.reads.length, reads);
    await tester.pumpAndSettle();
    await harness.ready(tester);
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });

  testWidgets('warm navigation: late preload never becomes a searched page',
      (tester) async {
    final pending = Completer<AdminProductionOrderPage?>();
    final (harness, store, _) = await prepare(tester, pending: pending);
    await harness.open(tester, sequenceWarmStore: store, settle: false);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.enterText(find.byType(EditableText).first, 'search-after-open');
    await tester.pump(const Duration(milliseconds: 400));
    pending
        .complete(await AdminProductionOrderPage.fromJson(harness.payload()));
    await tester.pumpAndSettle();
    expect(harness.reads.where((r) => r.view == 'sequence' &&
        r.search == 'search-after-open'),
        hasLength(1));
    expect(harness.reads.where((r) => r.view == 'sequence'), hasLength(2));
    expect(harness.activeWindow(tester).request.search, 'search-after-open');
    await harness.ready(tester);
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });

  testWidgets('warm navigation: new epoch resets old sequence authority',
      (tester) async {
    final (harness, store, events) = await prepare(tester);
    await store.prepare(currentAdminSequenceWarmScope());
    await harness.open(tester, sequenceWarmStore: store);
    await harness.ready(tester);
    harness.installCanonical(harness.ids.toList(),
        revision: 100, sequenceRevision: 100, sequenceVersion: '1' * 64);
    harness.sendCanonicalDelta();
    await tester.pumpAndSettle();
    await harness.leave(tester);

    harness.serverEpoch = 'replacement-server';
    harness.revision = 3;
    harness.sequenceRevision = 3;
    harness.sequenceVersion = '3' * 64;
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_resync',
      'window': AdminSequenceWarmStore.windowId,
      'epoch': harness.serverEpoch,
      'rev': 3,
      'version': 'v3',
    }));
    await tester.pumpAndSettle();
    expect(store.peek(currentAdminSequenceWarmScope())!.page.epoch,
        harness.serverEpoch);
    final reads = harness.reads.length;
    await harness.open(tester, sequenceWarmStore: store, settle: false);
    harness.expectRows(tester, harness.ids);
    await tester.pumpAndSettle();
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(harness.reads, hasLength(reads));
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });
}
