part of 'admin_production_map_test_screen_test.dart';

class _SequencePositionsHarness extends _PageStreamRaceHarness {
  _SequencePositionsHarness(_ScanBootstrapFixture fixture) : super(fixture, 45);

  @override
  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    if (request.view != 'sequence') return super.read(request);
    reads.add(request);
    final matches = request.search == '0093'
        ? [ids[3]]
        : request.search == 'far'
            ? [ids[27]]
            : request.search == 'matches'
                ? [ids[3], ids[27], ids[42]]
                : ids;
    final offset = int.tryParse(request.cursor ?? '') ?? 0;
    final slice = matches.skip(offset).take(20).toList();
    final raw = payload(offset: offset);
    return AdminProductionOrderPage.fromJson({
      ...raw,
      'total': matches.length,
      'next_cursor': offset + slice.length < matches.length
          ? '${offset + slice.length}'
          : null,
      'order_ids': slice,
      'sequence_positions': {for (final id in slice) id: ids.indexOf(id) + 1},
      'maps': [
        for (final id in slice)
          {
            'map': fixture.order.map
                .copyWith(
                    id: id, title: id, code: id == ids[3] ? '0093' : 'other')
                .toJson(),
            'program': <String, dynamic>{},
          }
      ],
      'sequences': {scanApparatus: slice},
      'visible_order_ids': {scanApparatus: slice},
      'queue_states': {
        scanApparatus: {for (final id in slice) id: 'pending'}
      },
      'queue_action_controls': {
        scanApparatus: {
          for (final id in slice) id: _syncControl('pending'),
        }
      },
    });
  }

  dynamic window(WidgetTester tester) => (tester.widget(find
          .byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_AdminOrderPageViewport')
          .hitTestable()
          .first) as dynamic)
      .window;

  Finder row(String id) => find.byWidgetPredicate((w) =>
      w.runtimeType.toString() == '_SequenceOrderRow' &&
      (w as dynamic).order.map.id == id);

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(EditableText), query);
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();
    expect(window(tester).request.search, query);
  }
}

void _registerSequencePositionsTests() {
  testWidgets('sequence ranks: server search keeps 4 and cold unloaded rank 28',
      (tester) async {
    final harness =
        _SequencePositionsHarness(await _prepareScanBootstrapFixture(tester));
    await harness.mount(tester);
    expect(harness.window(tester).length, 20);
    await harness.search(tester, '0093');
    expect(
        find.descendant(
            of: harness.row(harness.ids[3]), matching: find.text('4')),
        findsOneWidget);
    expect((tester.widget(harness.row(harness.ids[3])) as dynamic).index, 0,
        reason: 'The displayed rank must not become a drag/list index');
    await harness.search(tester, 'far');
    expect(
        find.descendant(
            of: harness.row(harness.ids[27]), matching: find.text('28')),
        findsOneWidget);
    expect(harness.reads.where((r) => r.cursor != null), isEmpty,
        reason:
            'Rank 28 must come from the searched page, not a loaded prefix');
    await harness.search(tester, 'matches');
    for (final index in [3, 27, 42]) {
      expect(
          find.descendant(
              of: harness.row(harness.ids[index]),
              matching: find.text('${index + 1}')),
          findsOneWidget);
    }
    expect(find.byType(ReorderableListView), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('sequence ranks: rank-only live delta updates 4 to 5 without GET',
      (tester) async {
    final harness =
        _SequencePositionsHarness(await _prepareScanBootstrapFixture(tester));
    await harness.mount(tester);
    await harness.search(tester, '0093');
    final dynamic window = harness.window(tester);
    final reads = harness.reads.length;
    final before = window.pages.single;
    final element = tester.element(harness.row(harness.ids[3]));
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': window.liveId,
      'epoch': 'scan-server',
      'base_version': 'v7',
      'version': 'v8',
      'rev': 8,
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {
              'op': 'set',
              'path': ['version'],
              'value': 'v8'
            },
            {
              'op': 'set',
              'path': ['rev'],
              'value': 8
            },
            {
              'op': 'set',
              'path': ['sequence_positions', harness.ids[3]],
              'value': 5
            },
          ]
        }
      ],
    }));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: harness.row(harness.ids[3]), matching: find.text('5')),
        findsOneWidget);
    expect(
        find.descendant(
            of: harness.row(harness.ids[3]), matching: find.text('4')),
        findsNothing);
    expect(identical(tester.element(harness.row(harness.ids[3])), element),
        isTrue);
    expect(identical(window.pages.single.snapshot.maps, before.snapshot.maps),
        isTrue);
    expect(harness.reads, hasLength(reads));
    await tester.pump(const Duration(seconds: 5));
    expect(harness.reads, hasLength(reads));
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });
}
