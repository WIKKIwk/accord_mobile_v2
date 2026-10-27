part of 'admin_production_map_test_screen_test.dart';

void _registerAdminPersistentPageCacheTests() {
  Future<void> flush(WidgetTester tester) async {
    var done = false;
    final pending =
        AdminOrderPageCache.instance.flush().then((_) => done = true);
    // Native compute completes outside FakeAsync. Pump its queued continuation
    // while giving the real isolate time to encode a large cached prefix.
    for (var turn = 0; !done && turn < 200; turn++) {
      await tester.pump();
      if (!done) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
    }
    expect(done, isTrue, reason: 'Durable page write must finish');
    await pending;
  }

  AdminOrderPageCache install(MemoryProductionSnapshotBackend backend) {
    final store = ProductionSnapshotStore(backend: backend);
    ProductionSnapshotStore.debugOverride = store;
    final cache = AdminOrderPageCache(persistence: store);
    AdminOrderPageCache.debugOverride = cache;
    return cache;
  }

  Future<_AdminPageCacheNavigationHarness> prepare(
      WidgetTester tester, MemoryProductionSnapshotBackend backend,
      {int count = 3}) async {
    install(backend);
    addTearDown(() {
      AdminOrderPageCache.instance.clear();
      AdminOrderPageCache.debugOverride = null;
      ProductionSnapshotStore.debugOverride = null;
    });
    final rawFixture = await _prepareScanBootstrapFixture(tester);
    // The offline demo's constructor-only catalog omits the source provenance
    // required by real canonical HTTP catalogs and durable decoding.
    final fixture = (
      order: rawFixture.order,
      live: rawFixture.live,
      apparatus: [
        for (final item in rawFixture.apparatus)
          item.copyWith(
            sourceRevision: item.sourceRevision > 0 ? item.sourceRevision : 1,
            sourceAasxSha256: item.sourceAasxSha256.isEmpty
                ? 'a' * 64
                : item.sourceAasxSha256,
            operation: item.operation.isEmpty ? 'other' : item.operation,
            technology: item.technology.isEmpty ? 'other' : item.technology,
          )
      ]
    );
    final harness = _AdminPageCacheNavigationHarness(fixture, count: count);
    await harness.host(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await harness.open(tester);
    await harness.ready(tester);
    await flush(tester);
    expect(backend.values, isNotEmpty,
        reason: 'Confirmed active-route pages must be durable before disposal');
    return harness;
  }

  Future<void> restart(
      WidgetTester tester,
      _AdminPageCacheNavigationHarness harness,
      MemoryProductionSnapshotBackend backend) async {
    await harness.leave(tester);
    await flush(tester);
    // Recreate both objects so no in-memory page or store queue can restore it.
    install(backend);
    await harness.open(tester);
  }

  testWidgets(
      'admin durable pages: process restart shows rows with zero page GETs',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend);
    final reads = harness.reads.length;
    await restart(tester, harness, backend);
    harness.expectRows(tester, harness.ids);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(find.byIcon(Icons.drag_handle_rounded),
        findsNWidgets(harness.ids.length));
    expect(harness.activeWindow(tester).cacheNeedsValidation, isTrue);
    harness.expectQuiet(tester, reads);
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    harness.expectQuiet(tester, reads);
    await harness.leave(tester);
  });

  testWidgets(
      'admin durable pages: sparse replay restores changed order and colours',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend);
    final before = List.of(harness.ids);
    final colour = harness.cardColor(tester, before.last);
    final reads = harness.reads.length;
    await harness.leave(tester);
    await flush(tester);
    harness.installCanonical(before.reversed.toList(),
        revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
    install(backend);
    await harness.open(tester);
    harness.expectRows(tester, before);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(harness.activeWindow(tester).cacheNeedsValidation, isTrue);
    harness.sendCanonicalDelta(states: {before.last: 'in_progress'});
    await tester.pumpAndSettle();
    harness.expectRows(tester, harness.ids);
    expect(harness.cardColor(tester, before.last), isNot(colour));
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    harness.expectQuiet(tester, reads);
    await flush(tester);
    // The replay result, not the older disk snapshot, survives another restart.
    await restart(tester, harness, backend);
    harness.expectRows(tester, harness.ids);
    expect(harness.cardColor(tester, before.last), isNot(colour));
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(harness.activeWindow(tester).cacheNeedsValidation, isTrue);
    await harness.ready(tester);
    harness.expectQuiet(tester, reads);
    await harness.leave(tester);
  });

  testWidgets(
      'admin durable pages: restoration exposes cached version before validation',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend);
    await harness.leave(tester);
    await flush(tester);
    install(backend);
    harness.catalogWait = Completer<List<AdminApparatus>>();
    await harness.open(tester);
    harness.expectRows(tester, harness.ids);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(harness.activeWindow(tester).cacheNeedsValidation, isTrue);
    await harness.leave(tester);
    harness.catalogWait!.complete(harness.fixture.apparatus);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'admin durable pages: missing history loads only active cached prefix',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend, count: 45);
    final dynamic viewport = tester.widget(find
        .byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_AdminOrderPageViewport')
        .hitTestable()
        .first);
    viewport.onMore();
    await tester.pumpAndSettle();
    await harness.ready(tester);
    final reads = harness.reads.length;
    await restart(tester, harness, backend);
    expect(harness.activeWindow(tester).length, 40);
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_resync',
      'window': harness.activeWindow(tester).liveId,
      'epoch': harness.serverEpoch,
      'rev': harness.revision,
      'version': 'v${harness.revision}',
    }));
    await tester.pumpAndSettle();
    expect(
        harness.reads.skip(reads).map((r) => r.view), ['sequence', 'sequence']);
    expect(harness.activeWindow(tester).length, 40);
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    await harness.leave(tester);
  });

  testWidgets(
      'admin durable pages: legacy live fallback validates with ifVersion',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend);
    final reads = harness.reads.length;
    await restart(tester, harness, backend);
    harness.events.addError(const MobileApiException(
        code: 'paged_live_required', message: 'Window protocol unsupported'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final extra = harness.reads.skip(reads).toList();
    expect(extra, hasLength(1));
    expect(extra.single.view, 'sequence');
    expect(extra.single.ifVersion, 'v7');
    harness.expectRows(tester, harness.ids);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    await harness.leave(tester);
  });

  testWidgets(
      'admin durable pages: terminal authorization rejection removes disk authority',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend);
    await restart(tester, harness, backend);
    harness.events.addError(const MobileApiException(
        code: 'forbidden', statusCode: 403, message: 'Access removed'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => ProductionSnapshotStore.instance.flush());
    expect(backend.values, isEmpty);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    // A later unsolicited ready frame cannot restore authority after rejection.
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    await harness.leave(tester);
  });

  testWidgets(
      'admin durable pages: new server epoch replaces persisted baseline',
      (tester) async {
    final backend = MemoryProductionSnapshotBackend();
    final harness = await prepare(tester, backend);
    await harness.leave(tester);
    await flush(tester);
    install(backend);
    harness.serverEpoch = 'new-server-epoch';
    harness.revision = 1;
    await harness.open(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    expect(harness.activeWindow(tester).cacheNeedsValidation, isTrue);
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_resync',
      'window': harness.activeWindow(tester).liveId,
      'epoch': harness.serverEpoch,
      'rev': 1,
      'version': 'v1',
    }));
    await tester.pumpAndSettle();
    expect(harness.activeWindow(tester).pages.first.epoch, harness.serverEpoch);
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    await harness.leave(tester);
  });
}
