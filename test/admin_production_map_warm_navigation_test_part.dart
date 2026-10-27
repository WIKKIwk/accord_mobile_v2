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
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(harness.reads.length, reads);
    expect(harness.catalogReads, 0);
    await tester.pumpAndSettle();
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(find.byIcon(Icons.drag_handle_rounded),
        findsNWidgets(harness.ids.length));
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
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

  for (final source in ['warm', 'cache']) {
    testWidgets(
        'warm navigation: $source checkpoint enables actual handles without GET',
        (tester) async {
      late final _AdminPageCacheNavigationHarness harness;
      AdminSequenceWarmStore? store;
      if (source == 'warm') {
        final prepared = await prepare(tester);
        harness = prepared.$1;
        store = prepared.$2;
        await store.prepare(currentAdminSequenceWarmScope());
        await tester.pumpAndSettle();
      } else {
        harness = _AdminPageCacheNavigationHarness(
            await _prepareScanBootstrapFixture(tester));
        await harness.host(tester);
        await harness.open(tester);
        await harness.ready(tester);
        await harness.leave(tester);
      }
      final reads = harness.reads.length;
      await harness.open(tester, sequenceWarmStore: store);
      harness.expectRows(tester, harness.ids);
      expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      final AdminProductionOrderPage page =
          harness.activeWindow(tester).pages.first;
      harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_checkpoint',
        'window': harness.activeWindow(tester).liveId,
        'epoch': page.epoch,
        'rev': page.revision,
        'base_version': page.version,
        'version': page.version,
        'next_cursors': [page.nextCursor],
      }));
      await tester.pumpAndSettle();
      expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
      expect(find.byIcon(Icons.drag_handle_rounded),
          findsNWidgets(harness.ids.length));
      harness.expectRows(tester, harness.ids);
      expect(harness.reads, hasLength(reads));

      final reordered = harness.ids.reversed.toList();
      harness.installCanonical(reordered,
          revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
      harness.sendCanonicalDelta();
      await tester.pumpAndSettle();
      harness.expectRows(tester, reordered);
      expect(find.byIcon(Icons.drag_handle_rounded),
          findsNWidgets(reordered.length));
      await tester.pump(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      harness.expectQuiet(tester, reads);
      await harness.leave(tester);
      store?.configure(scope: null, foreground: false);
    });
  }

  testWidgets(
      'warm navigation: generic ready validates once after startup deadline',
      (tester) async {
    final (harness, store, _) = await prepare(tester);
    await store.prepare(currentAdminSequenceWarmScope());
    await tester.pumpAndSettle();
    final reads = harness.reads.length;
    await harness.open(tester, sequenceWarmStore: store);
    harness.events.add(AdminProductionMapPageChange(
        epoch: harness.serverEpoch, revision: harness.revision, ready: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 9));
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    expect(harness.reads, hasLength(reads));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    final extra = harness.reads.skip(reads).toList();
    expect(extra, hasLength(1));
    expect(extra.single.view, 'sequence');
    expect(extra.single.apparatus, scanApparatus);
    expect(extra.single.ifVersion, isNull,
        reason: 'Startup timeout retains the existing dirty-window recovery');
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(find.byIcon(Icons.drag_handle_rounded),
        findsNWidgets(harness.ids.length));
    harness.expectRows(tester, harness.ids);
    // Timeout recovery reopens the existing stream. The server still sends
    // its generic greeting, which must be sufficient once HTTP proved rows.
    await tester.pump(const Duration(seconds: 2));
    harness.events.add(AdminProductionMapPageChange(
        epoch: harness.serverEpoch, revision: harness.revision, ready: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(harness.reads, hasLength(reads + 1),
        reason: 'Initial validation must not become HTTP polling');
    final reordered = harness.ids.reversed.toList();
    harness.installCanonical(reordered,
        revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
    harness.sendCanonicalDelta();
    await tester.pumpAndSettle();
    harness.expectRows(tester, reordered);
    expect(harness.reads, hasLength(reads + 1));
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });

  for (final mismatch in [
    'epoch',
    'version',
    'revision',
    'window',
    'base version',
    'cursor',
  ]) {
    testWidgets(
        'warm navigation: mismatched checkpoint $mismatch cannot authorize rows',
        (tester) async {
      final (harness, store, _) = await prepare(tester);
      await store.prepare(currentAdminSequenceWarmScope());
      await tester.pumpAndSettle();
      await harness.open(tester, sequenceWarmStore: store);
      final recovery = Completer<AdminProductionOrderPage?>();
      harness.delayedReconcile = recovery;
      final AdminProductionOrderPage page =
          harness.activeWindow(tester).pages.first;
      harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_checkpoint',
        'window': mismatch == 'window'
            ? 'unsubscribed-window'
            : harness.activeWindow(tester).liveId,
        'epoch': mismatch == 'epoch' ? 'other-server' : page.epoch,
        'rev': mismatch == 'revision' ? page.revision! - 1 : page.revision,
        'base_version': mismatch == 'base version' ? 'other-base' : page.version,
        'version': mismatch == 'version' ? 'another-version' : page.version,
        'next_cursors': [
          mismatch == 'cursor' ? 'unconfirmed-next' : page.nextCursor,
        ],
      }));
      await _flushSequenceStreamSync(tester);
      expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
      expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
      harness.expectRows(tester, harness.ids);
      harness.delayedReconcile = null;
      recovery.complete(
          await AdminProductionOrderPage.fromJson(harness.payload()));
      await tester.pumpAndSettle();
      await harness.ready(tester);
      expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
      expect(find.byIcon(Icons.drag_handle_rounded),
          findsNWidgets(harness.ids.length));
      await harness.leave(tester);
      store.configure(scope: null, foreground: false);
    });
  }

  testWidgets(
      'warm navigation: old checkpoint cannot certify a dirty window',
      (tester) async {
    final (harness, store, _) = await prepare(tester);
    await store.prepare(currentAdminSequenceWarmScope());
    await tester.pumpAndSettle();
    final reads = harness.reads.length;
    await harness.open(tester, sequenceWarmStore: store);
    final original = harness.ids.toList();
    final AdminProductionOrderPage page =
        harness.activeWindow(tester).pages.first;
    final recovery = Completer<AdminProductionOrderPage?>();
    harness.delayedReconcile = recovery;
    final reordered = original.reversed.toList();
    harness.installCanonical(reordered,
        revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
    harness.events.add(AdminProductionMapPageChange(
        epoch: harness.serverEpoch, revision: harness.revision, ready: false));
    await _flushSequenceStreamSync(tester);
    expect(harness.activeWindow(tester).dirty, isTrue);
    expect(harness.reads, hasLength(reads + 1));
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_checkpoint',
      'window': harness.activeWindow(tester).liveId,
      'epoch': page.epoch,
      'rev': page.revision,
      'base_version': page.version,
      'version': page.version,
      'next_cursors': [page.nextCursor],
    }));
    await _flushSequenceStreamSync(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    harness.expectRows(tester, original);
    harness.delayedReconcile = null;
    recovery.complete(
        await AdminProductionOrderPage.fromJson(harness.payload()));
    await tester.pumpAndSettle();
    harness.expectRows(tester, reordered);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(find.byIcon(Icons.drag_handle_rounded),
        findsNWidgets(reordered.length));
    expect(harness.reads, hasLength(reads + 1));
    await harness.leave(tester);
    store.configure(scope: null, foreground: false);
  });

  testWidgets(
      'warm navigation: initial socket error validates rows once',
      (tester) async {
    final (harness, store, _) = await prepare(tester);
    await store.prepare(currentAdminSequenceWarmScope());
    await tester.pumpAndSettle();
    final reads = harness.reads.length;
    await harness.open(tester, sequenceWarmStore: store);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    harness.events.addError(http.ClientException('initial socket failure'));
    await tester.pumpAndSettle();
    final extra = harness.reads.skip(reads).toList();
    expect(extra, hasLength(1));
    expect(extra.single.view, 'sequence');
    expect(extra.single.apparatus, scanApparatus);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(find.byIcon(Icons.drag_handle_rounded),
        findsNWidgets(harness.ids.length));
    harness.expectRows(tester, harness.ids);
    await tester.pump(const Duration(seconds: 2));
    harness.events.add(AdminProductionMapPageChange(
        epoch: harness.serverEpoch,
        revision: harness.revision,
        ready: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(harness.reads, hasLength(reads + 1),
        reason: 'Socket retries must not repeat initial HTTP validation');
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
