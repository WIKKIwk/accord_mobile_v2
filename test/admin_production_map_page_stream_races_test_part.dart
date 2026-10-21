part of 'admin_production_map_test_screen_test.dart';

/// Raw wire pages exercise the production reducer and subscription descriptors.
/// Typed-only pages deliberately fall back to the legacy invalidation stream.
class _PageStreamRaceHarness {
  _PageStreamRaceHarness(this.fixture, int count, {this.twoPanes = false})
      : ids = List.generate(count, (index) => 'stream-race-$index');

  final _ScanBootstrapFixture fixture;
  final bool twoPanes;
  final List<String> ids;
  final events = StreamController<Object>.broadcast();
  final reads = <AdminProductionOrderPageRequest>[];
  int revision = 7;
  int sequenceRevision = 5;
  String sequenceVersion = '0' * 64;
  Completer<AdminProductionOrderPage?>? delayedAppend;
  Completer<AdminProductionOrderPage?>? delayedReconcile;

  Map<String, dynamic> payload({int offset = 0}) {
    final slice = ids.skip(offset).take(20).toList();
    return {
      ...scanSequence(),
      'version': 'v$revision',
      'rev': revision,
      'offset': offset,
      'total': ids.length,
      'next_cursor': offset + slice.length < ids.length
          ? '${offset + slice.length}'
          : null,
      'order_ids': slice,
      'maps': [
        for (final id in slice)
          {
            'map': fixture.order.map.copyWith(id: id, title: id).toJson(),
            'program': <String, dynamic>{},
          },
      ],
      'sequences': {scanApparatus: slice},
      'sequence_versions': {scanApparatus: sequenceVersion},
      'sequence_revisions': {scanApparatus: sequenceRevision},
      'visible_order_ids': {scanApparatus: slice},
      'queue_states': {
        scanApparatus: {for (final id in slice) id: 'pending'},
      },
      'queue_action_controls': {
        scanApparatus: {for (final id in slice) id: _syncControl('pending')},
      },
    };
  }

  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    reads.add(request);
    if (twoPanes && request.view == 'move') {
      return AdminProductionOrderPage.fromJson(payload());
    }
    if (request.view != 'sequence') {
      return AdminProductionOrderPage.fromJson({
        'version': 'empty$revision',
        'epoch': 'scan-server',
        'rev': revision,
        'offset': 0,
        'total': 0,
        'next_cursor': null,
        'closed_orders': [],
      });
    }
    if (request.cursor != null && delayedAppend != null) {
      return delayedAppend!.future;
    }
    if (request.cursor == null && delayedReconcile != null) {
      return delayedReconcile!.future;
    }
    return AdminProductionOrderPage.fromJson(
        payload(offset: int.tryParse(request.cursor ?? '') ?? 0));
  }

  AdminProductionMapPageWindowMessage delta({required String order}) =>
      AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_delta',
        'window': 'w1',
        'epoch': 'scan-server',
        'rev': 8,
        'base_version': 'v7',
        'version': 'v8',
        'page_count': 1,
        'changes': [
          {
            'index': 0,
            'ops': [
              {'op': 'set', 'path': ['version'], 'value': 'v8'},
              {'op': 'set', 'path': ['rev'], 'value': 8},
              {
                'op': 'set',
                'path': ['sequence_revisions', scanApparatus],
                'value': 6,
              },
              {
                'op': 'set',
                'path': ['queue_states', scanApparatus, order],
                'value': 'in_progress',
              },
              {
                'op': 'set',
                'path': ['queue_action_controls', scanApparatus, order],
                'value': _syncControl('in_progress'),
              },
            ],
          },
        ],
      });

  Future<void> mount(WidgetTester tester) async {
    addTearDown(events.close);
    final apparatus =
        fixture.apparatus.firstWhere((a) => a.id == scanApparatus);
    await AdminSequenceApparatusStore.instance.saveApparatus(apparatus);
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
        apparatusLoader: () async => [
          if (twoPanes) ...[
            fixture.apparatus.firstWhere((a) => a.id == _print8Id),
            fixture.apparatus.firstWhere((a) => a.id == _print7Id),
          ],
          apparatus,
        ],
        completionRequestsLoader: () async => [],
        queueSnapshotLoader: () => throw StateError('full snapshot requested'),
        orderPageLoader: read,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_ready',
      'window': 'w1',
      'epoch': 'scan-server',
      'rev': 7,
      'version': 'v7',
      'resync': false,
    }));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }
}

void _registerPageStreamRaceTests() {
  testWidgets('page stream race: move panes require one coherent revision',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final harness = _PageStreamRaceHarness(fixture, 3, twoPanes: true);
    await harness.mount(tester);
    await tester.tap(find.text('Ko‘chirish').hitTestable());
    await tester.pumpAndSettle();
    final windows = tester.widgetList(find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_AdminOrderPageViewport')).map(
            (widget) => (widget as dynamic).window).where(
                (dynamic window) => window.request.view == 'move').toList();
    expect(windows, hasLength(2));
    for (final dynamic window in windows) {
      harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_ready', 'window': window.liveId, 'epoch': 'scan-server',
        'rev': 7, 'version': 'v7', 'resync': false,
      }));
    }
    await tester.pumpAndSettle();
    dynamic module() => tester.widget(find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MoveModulePage'));
    final order = ProductionMapSaved(
      map: _productionOrderMap(id: 'move-authority', title: 'Move authority',
          productCode: 'MOVE', product: 'Film', apparatusId: _print8Id,
          widthMm: 300, rollCount: 1),
      program: fixture.order.program,
    );
    bool canMove() => module().canMoveTo(
        order, module().bottomApparatus, module().topApparatus) as bool;
    expect(canMove(), isTrue, reason: 'initial panes '
        '${module().topApparatus.id}/${module().bottomApparatus.id}; '
        'compatible=${productionMapCanMoveOrderToApparatus(nodes: order.map.nodes,
          fromApparatus: module().topApparatus, toApparatus: module().bottomApparatus,
          rollCount: order.map.rollCount, widthMm: order.map.printCompatibilityWidthMm)}; '
        'reads=${harness.reads.map((r) => '${r.view}:${r.apparatus}').toList()}');
    final beforeReads = harness.reads.length;
    void checkpoint(String id) => harness.events.add(
        AdminProductionMapPageWindowMessage.fromJson({
          'type': 'page_window_checkpoint', 'window': id, 'epoch': 'scan-server',
          'rev': 8, 'base_version': 'v7', 'version': 'v8', 'next_cursors': [null],
        }));
    checkpoint(windows.first.liveId as String);
    await tester.pumpAndSettle();
    expect(canMove(), isFalse,
        reason: 'One newer pane cannot authorize an action using another old pane');
    unawaited(module().onMove(orders: [order], from: module().topApparatus,
        to: module().bottomApparatus) as Future<void>);
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing,
        reason: 'A retained callback must obey the same authority barrier');
    await tester.pump(const Duration(seconds: 3));
    expect(canMove(), isFalse, reason: 'A missing second frame must fail closed');
    checkpoint(windows.last.liveId as String);
    await tester.pumpAndSettle();
    expect(canMove(), isTrue);
    expect(harness.reads.length, beforeReads,
        reason: 'Matching checkpoints restore authority without HTTP');
    await harness.dispose(tester);
  });

  testWidgets('page stream race: stale delta cannot certify a reorder ACK',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final harness = _PageStreamRaceHarness(fixture, 3);
    final response = Completer<http.Response>();
    final writes = <http.Request>[];
    await http.runWithClient(() async {
      await harness.mount(tester);
      await TestModeController.instance.setEnabled(false);
      await tester.pumpAndSettle();
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(2, 0);
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));

      // A newer global revision can still precede this move. Keep its wire
      // baseline for the following patch without exposing old action controls.
      final moved = harness.ids.removeLast();
      harness.ids.insert(0, moved);
      response.complete(http.Response(
          jsonEncode({
            'ok': true,
            'order_ids': harness.ids,
            'version': '1' * 64,
            'revision': 7,
            'epoch': 'scan-server',
            'adjusted': false,
          }),
          200));
      await tester.pump();
      await tester.pump();
      expect(harness.reads.where((r) => r.view == 'sequence').length, 1);
      Material card() => tester.widget<Material>(find
          .descendant(
              of: find.byWidgetPredicate((widget) =>
                  widget.runtimeType.toString() == '_SequenceOrderRow' &&
                  (widget as dynamic).order.map.id == moved),
              matching: find.byType(Material))
          .first);
      final acknowledgedCard = card();
      harness.events.add(harness.delta(order: moved));
      await tester.pump();
      await tester.pump();
      expect(identical(card(), acknowledgedCard), isTrue,
          reason: 'A delayed queue revision must not install stale colors or controls');
      expect(tester.widgetList(find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString() == '_SequenceOrderRow')).map((widget) =>
              (widget as dynamic).order.map.id), harness.ids);

      harness
        ..revision = 9
        ..sequenceRevision = 7
        ..sequenceVersion = '1' * 64;
      final next = harness.payload();
      harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_delta', 'window': 'w1', 'epoch': 'scan-server',
        'rev': 9, 'base_version': 'v8', 'version': 'v9', 'page_count': 1,
        'changes': [{
          'index': 0,
          'ops': [
            for (final key in ['version', 'rev', 'order_ids', 'sequences',
              'sequence_versions', 'sequence_revisions', 'queue_states',
              'queue_action_controls'])
              {'op': 'set', 'path': [key], 'value': next[key]},
          ],
        }],
      }));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(harness.reads.where((r) => r.view == 'sequence').length, 1,
          reason: 'Consuming an intermediate wire patch must preserve the chain');
      await harness.dispose(tester);
    }, () => MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/production-maps/sequence')) {
            writes.add(request);
            return response.future;
          }
          return http.Response('{}', 200);
        }));
  });

  testWidgets('page stream race: shorter subscription cannot erase HTTP append',
      (tester) async {
    final fixture = await _prepareScanBootstrapFixture(tester);
    final harness = _PageStreamRaceHarness(fixture, 45);
    await harness.mount(tester);
    expect(_adminSequenceRowCount(tester), 20);
    final append = Completer<AdminProductionOrderPage?>();
    harness.delayedAppend = append;
    await _scrollAdminPage(tester);
    await tester.pump();
    expect(harness.reads.where((r) => r.cursor == '20'), hasLength(1));
    append.complete(await AdminProductionOrderPage.fromJson(
        harness.payload(offset: 20)));
    await tester.pump();
    await tester.pump();
    expect(_adminSequenceRowCount(tester), 40);
    final beforeReads = harness.reads.length;

    // No elapsed fake time: the socket still owns its original 20-row
    // descriptor; the debounced 40-row subscription has not started.
    harness.events.add(harness.delta(order: harness.ids.first));
    await tester.pump();
    await tester.pump();
    expect(_adminSequenceRowCount(tester), 40,
        reason: 'The old prefix must not replace the newly appended second page');
    expect(harness.reads.length, beforeReads,
        reason: 'Changing the subscription needs no duplicate HTTP append');
    await tester.pump(const Duration(milliseconds: 31));
    expect(_adminSequenceRowCount(tester), 40);
    await harness.dispose(tester);
  });
}
