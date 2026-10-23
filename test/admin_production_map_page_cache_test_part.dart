part of 'admin_production_map_test_screen_test.dart';

class _AdminPageCacheNavigationHarness extends _SequenceStreamSyncHarness {
  _AdminPageCacheNavigationHarness(super.fixture, {int count = 3}) {
    ids
      ..clear()
      ..addAll(List.generate(count, (i) => 'stream-race-$i'));
  }

  final navigator = GlobalKey<NavigatorState>();
  int catalogReads = 0;
  int connections = 0;
  bool typedOnly = false;
  String serverEpoch = 'scan-server';
  Completer<List<AdminApparatus>>? catalogWait;

  @override
  Map<String, dynamic> payload({int offset = 0}) =>
      {...super.payload(offset: offset), 'epoch': serverEpoch};

  @override
  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    final page = await super.read(request);
    if (page == null || request.ifVersion == page.version) return null;
    if (!typedOnly) return page;
    return AdminProductionOrderPage(
      version: page.version,
      epoch: page.epoch,
      revision: page.revision,
      total: page.total,
      offset: page.offset,
      nextCursor: page.nextCursor,
      snapshot: page.snapshot,
      orderIds: page.orderIds,
      pendingOrders: page.pendingOrders,
      closedOrders: page.closedOrders,
      calculationTemplates: page.calculationTemplates,
      workflowAudit: page.workflowAudit,
    );
  }

  Future<void> host(WidgetTester tester) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'cache-admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
    await AdminSequenceApparatusStore.instance.saveApparatus(
        fixture.apparatus.firstWhere((a) => a.id == scanApparatus));
    addTearDown(events.close);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.shrink()),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester,
      {AdminSequenceWarmStore? sequenceWarmStore, bool settle = true}) async {
    unawaited(navigator.currentState!.push<void>(PageRouteBuilder<void>(
      settings: const RouteSettings(name: AppRoutes.adminProductionMapOrders),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, animation, secondaryAnimation) =>
          AdminProductionMapOrdersScreen(
        sequenceWarmStore: sequenceWarmStore,
        apparatusLoader: () async {
          catalogReads++;
          return catalogWait?.future ??
              [fixture.apparatus.firstWhere((a) => a.id == scanApparatus)];
        },
        orderPageLoader: read,
        completionRequestsLoader: () async => [],
        queueSnapshotLoader: () => throw StateError('full snapshot requested'),
        liveEventsLoader: () {
          connections++;
          return events.stream;
        },
      ),
    )));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  dynamic activeWindow(WidgetTester tester) => (tester.widget(find
          .byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_AdminOrderPageViewport')
          .hitTestable()
          .first) as dynamic)
      .window;

  dynamic modules(WidgetTester tester) => tester.widget(find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_AdminModulesBody'));

  Future<void> ready(WidgetTester tester) async {
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_ready',
      'window': activeWindow(tester).liveId,
      'epoch': serverEpoch,
      'rev': revision,
      'version': 'v$revision',
      'resync': false,
    }));
    await tester.pumpAndSettle();
  }

  Future<void> leave(WidgetTester tester) async {
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AdminProductionMapOrdersScreen), findsNothing);
    expect(events.hasListener, isFalse,
        reason: 'Closed pages must not retain a live socket');
    expect(tester.takeException(), isNull);
  }
}

void _registerAdminPageCacheTests() {
  Future<_AdminPageCacheNavigationHarness> prepare(WidgetTester tester,
      {int count = 3}) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final harness = _AdminPageCacheNavigationHarness(fixture, count: count);
    await harness.host(tester);
    await harness.open(tester);
    await harness.ready(tester);
    return harness;
  }

  testWidgets(
      'admin page cache: route reentry shows cached rows with no page GET',
      (tester) async {
    final harness = await prepare(tester);
    final reads = harness.reads.length;
    await harness.leave(tester);
    harness.catalogWait = Completer<List<AdminApparatus>>();
    await harness.open(tester);
    harness.expectRows(tester, harness.ids);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    harness.modules(tester).onReorder(0, 1);
    await tester.pump();
    harness.expectRows(tester, harness.ids);
    harness.expectQuiet(tester, reads);
    expect(harness.connections, 2);
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    harness.expectQuiet(tester, reads);
    await harness.leave(tester);
    harness.catalogWait!.complete(harness.fixture.apparatus);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'admin page cache: missed sequence and colour changes arrive through delta',
      (tester) async {
    final harness = await prepare(tester);
    final reads = harness.reads.length;
    final oldIds = List.of(harness.ids);
    final oldColour = harness.cardColor(tester, oldIds.last);
    await harness.leave(tester);
    harness.installCanonical(oldIds.reversed.toList(),
        revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
    await harness.open(tester);
    harness.expectRows(tester, oldIds);
    harness.sendCanonicalDelta(states: {oldIds.last: 'in_progress'});
    await tester.pumpAndSettle();
    harness.expectRows(tester, harness.ids);
    expect(harness.cardColor(tester, oldIds.last), isNot(oldColour));
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    harness.expectQuiet(tester, reads);
    await harness.leave(tester);
  });

  testWidgets('admin page cache: quick revisits retain the immutable baseline',
      (tester) async {
    final harness = await prepare(tester);
    final reads = harness.reads.length;
    await harness.leave(tester);
    for (var visit = 0; visit < 3; visit++) {
      await harness.open(tester);
      harness.expectRows(tester, harness.ids);
      expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
      harness.expectQuiet(tester, reads);
      await harness.leave(tester);
    }
    await harness.open(tester);
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    harness.expectQuiet(tester, reads);
    await harness.leave(tester);
  });

  testWidgets('admin page cache: previously loaded prefix survives navigation',
      (tester) async {
    final harness = await prepare(tester, count: 45);
    final dynamic viewport = tester.widget(find
        .byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_AdminOrderPageViewport')
        .hitTestable()
        .first);
    viewport.onMore();
    await tester.pumpAndSettle();
    await harness.ready(tester);
    expect(_adminSequenceRowCount(tester), 40);
    final reads = harness.reads.length;
    await harness.leave(tester);
    await harness.open(tester);
    expect(harness.activeWindow(tester).length, 40);
    await harness.ready(tester);
    expect(_adminSequenceRowCount(tester), 40);
    harness.expectQuiet(tester, reads);
    await harness.leave(tester);
  });

  testWidgets(
      'admin page cache: missing delta history reconciles only the active prefix',
      (tester) async {
    final harness = await prepare(tester);
    final reads = harness.reads.length;
    await harness.leave(tester);
    harness.installCanonical(harness.ids.reversed.toList(),
        revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
    await harness.open(tester);
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_resync',
      'window': harness.activeWindow(tester).liveId,
      'epoch': 'scan-server',
      'rev': 8,
      'version': 'v8',
    }));
    await tester.pumpAndSettle();
    expect(harness.reads.skip(reads).map((r) => r.view), ['sequence']);
    harness.expectRows(tester, harness.ids);
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    await harness.leave(tester);
  });

  testWidgets('admin page cache: typed pages validate once with ifVersion',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final harness = _AdminPageCacheNavigationHarness(fixture)..typedOnly = true;
    await harness.host(tester);
    await harness.open(tester);
    final reads = harness.reads.length;
    await harness.leave(tester);
    await harness.open(tester);
    final extra = harness.reads.skip(reads).toList();
    expect(extra, hasLength(1));
    expect(extra.single.view, 'sequence');
    expect(extra.single.ifVersion, 'v7');
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    harness.expectRows(tester, harness.ids);
    await harness.leave(tester);
  });

  for (final change in [
    'token',
    'principal',
    'permissions',
    'role',
    'assignment',
    'session revision'
  ]) {
    testWidgets(
        'admin page cache: $change change cannot reuse the old account data',
        (tester) async {
      final harness = await prepare(tester);
      await harness.leave(tester);
      if (change == 'token') {
        AppSession.instance.token = 'new-token';
      } else if (change == 'session revision') {
        AppSession.instance.revision.value++;
      } else {
        AppSession.instance.profile = SessionProfile(
          role: change == 'role' ? UserRole.aparatchi : UserRole.admin,
          displayName: 'Admin',
          legalName: '',
          ref: change == 'principal' ? 'another-admin' : 'cache-admin',
          phone: '',
          avatarUrl: '',
          capabilities: change == 'permissions'
              ? ['production.map.manage']
              : ['admin.access'],
          assignedApparatus:
              change == 'assignment' ? [scanApparatus] : const [],
        );
      }
      final before = harness.reads.where((r) => r.view == 'sequence').length;
      await harness.open(tester);
      expect(
          harness.reads.where((r) => r.view == 'sequence').length, before + 1);
      expect(harness.reads.lastWhere((r) => r.view == 'sequence').ifVersion,
          isNull);
      await harness.ready(tester);
      await harness.leave(tester);
    });
  }

  testWidgets('admin page cache: logout clears even a same-token login',
      (tester) async {
    final harness = await prepare(tester);
    final profile = AppSession.instance.profile;
    final token = AppSession.instance.token;
    await harness.leave(tester);
    await tester.runAsync(() => AppSession.instance.clear());
    AppSession.instance.token = token;
    AppSession.instance.profile = profile;
    final reads = harness.reads.where((r) => r.view == 'sequence').length;
    await harness.open(tester);
    expect(harness.reads.where((r) => r.view == 'sequence').length, reads + 1);
    await harness.ready(tester);
    await harness.leave(tester);
  });

  testWidgets('admin page cache: a new server epoch replaces the old baseline',
      (tester) async {
    final harness = await prepare(tester);
    await harness.leave(tester);
    harness.serverEpoch = 'restarted-server';
    harness.revision = 1;
    await harness.open(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isFalse);
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_resync',
      'window': harness.activeWindow(tester).liveId,
      'epoch': harness.serverEpoch,
      'rev': 1,
      'version': 'v1',
    }));
    await tester.pumpAndSettle();
    expect(harness.activeWindow(tester).pages.first.epoch, 'restarted-server');
    await harness.ready(tester);
    expect(harness.modules(tester).sequenceReorderEnabled, isTrue);
    await harness.leave(tester);
  });

  testWidgets(
      'admin page cache: pending reads are never transferred to a new route',
      (tester) async {
    final harness = await prepare(tester, count: 45);
    final pending = Completer<AdminProductionOrderPage?>();
    harness.delayedAppend = pending;
    final dynamic viewport = tester.widget(find
        .byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_AdminOrderPageViewport')
        .hitTestable()
        .first);
    viewport.onMore();
    await tester.pump();
    await harness.leave(tester);
    final reads = harness.reads.length;
    await harness.open(tester);
    expect(harness.reads.skip(reads).where((r) => r.view == 'sequence'),
        hasLength(1));
    expect(_adminSequenceRowCount(tester), 20);
    pending.complete(
        await AdminProductionOrderPage.fromJson(harness.payload(offset: 20)));
    await tester.pumpAndSettle();
    expect(_adminSequenceRowCount(tester), 20);
    await harness.ready(tester);
    await harness.leave(tester);
  });
}
