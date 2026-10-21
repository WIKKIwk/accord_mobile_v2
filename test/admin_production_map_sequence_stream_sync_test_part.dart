part of 'admin_production_map_test_screen_test.dart';

class _SequenceStreamSyncHarness extends _PageStreamRaceHarness {
  _SequenceStreamSyncHarness(_ScanBootstrapFixture fixture) : super(fixture, 3);

  final writes = <http.Request>[];
  final replies = <Completer<http.Response>>[];

  Future<http.Response> respond(http.Request request) async {
    if (request.method == 'POST' &&
        request.url.path.endsWith('/production-maps/sequence')) {
      writes.add(request);
      final reply = Completer<http.Response>();
      replies.add(reply);
      return reply.future;
    }
    return http.Response('{}', 200);
  }

  void acknowledge(int index, List<String> orderIds,
      {required int sequenceRevision, required String sequenceVersion}) {
    replies[index].complete(http.Response(
      jsonEncode({
        'ok': true,
        'order_ids': orderIds,
        'version': sequenceVersion,
        'revision': sequenceRevision,
        'epoch': 'scan-server',
        'adjusted': false,
      }),
      200,
    ));
  }

  void installCanonical(List<String> orderIds,
      {required int revision,
      required int sequenceRevision,
      required String sequenceVersion}) {
    ids
      ..clear()
      ..addAll(orderIds);
    this.revision = revision;
    this.sequenceRevision = sequenceRevision;
    this.sequenceVersion = sequenceVersion;
  }

  void sendCanonicalDelta({
    String baseVersion = 'v7',
    Map<String, String> states = const {},
  }) {
    final next = payload();
    for (final entry in states.entries) {
      (next['queue_states'][scanApparatus] as Map)[entry.key] = entry.value;
      (next['queue_action_controls'][scanApparatus] as Map)[entry.key] =
          _syncControl(entry.value);
    }
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': 'w1',
      'epoch': 'scan-server',
      'rev': revision,
      'base_version': baseVersion,
      'version': 'v$revision',
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            for (final key in [
              'version',
              'rev',
              'order_ids',
              'maps',
              'sequences',
              'sequence_versions',
              'sequence_revisions',
              'visible_order_ids',
              'queue_states',
              'queue_action_controls',
            ])
              {
                'op': 'set',
                'path': [key],
                'value': next[key]
              },
          ],
        },
      ],
    }));
  }

  Future<void> mountForWrites(WidgetTester tester) async {
    await mount(tester);
    await TestModeController.instance.setEnabled(false);
    await tester.pumpAndSettle();
  }

  void reorder(WidgetTester tester, int from, int to) {
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(from, to);
  }

  void expectRows(WidgetTester tester, List<String> expected) {
    expect(
      tester
          .widgetList(find.byWidgetPredicate(
              (widget) => widget.runtimeType.toString() == '_SequenceOrderRow'))
          .map((widget) => (widget as dynamic).order.map.id),
      expected,
    );
  }

  Color? cardColor(WidgetTester tester, String orderId) => tester
      .widget<Material>(find
          .descendant(
            of: find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_SequenceOrderRow' &&
                (widget as dynamic).order.map.id == orderId),
            matching: find.byType(Material),
          )
          .first)
      .color;

  void expectQuiet(WidgetTester tester, int initialReads) {
    expect(reads, hasLength(initialReads),
        reason: 'A healthy matching page stream must not trigger a reload GET');
    expect(find.byKey(_recoveryProgressKey), findsNothing);
    expect(find.byType(LinearProgressIndicator).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
  }
}

Future<void> _flushSequenceStreamSync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void _registerSequenceStreamSyncTests() {
  testWidgets('sequence stream sync: ACK waits quietly for matching page delta',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final moved = [harness.ids[2], harness.ids[0], harness.ids[1]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(1));
      harness.acknowledge(0, moved,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      harness.expectRows(tester, moved);
      harness.expectQuiet(tester, initialReads);

      await tester.pump(const Duration(milliseconds: 1200));
      harness.expectQuiet(tester, initialReads);
      harness.installCanonical(moved,
          revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
      harness.sendCanonicalDelta();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      harness.expectRows(tester, moved);
      harness.expectQuiet(tester, initialReads);
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('sequence stream sync: page delta before ACK needs no reload',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final moved = [harness.ids[2], harness.ids[0], harness.ids[1]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(1));
      harness.installCanonical(moved,
          revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
      harness.sendCanonicalDelta();
      await tester.pumpAndSettle();
      harness.expectRows(tester, moved);
      harness.expectQuiet(tester, initialReads);

      harness.acknowledge(0, moved,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      await tester.pump(const Duration(seconds: 3));
      harness.expectRows(tester, moved);
      harness.expectQuiet(tester, initialReads);
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'sequence stream sync: newer page preserves order and colour after an old ACK',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final original = List<String>.of(harness.ids);
      final requested = [original[2], original[0], original[1]];
      final newer = [original[1], original[2], original[0]];
      final pendingColor = harness.cardColor(tester, original[1]);
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(1));

      // Another administrator's move and a status update are already newer
      // than this request's eventual ACK. The queued local intention is still
      // represented in this order, so it cannot conceal the newer projection.
      harness.installCanonical(newer,
          revision: 9, sequenceRevision: 7, sequenceVersion: '2' * 64);
      harness.sendCanonicalDelta(states: {original[1]: 'in_progress'});
      await tester.pumpAndSettle();
      harness.expectRows(tester, newer);
      final newerColor = harness.cardColor(tester, original[1]);
      expect(newerColor, isNot(pendingColor),
          reason: 'The stream must really install the newer status colour');
      harness.expectQuiet(tester, initialReads);

      harness.acknowledge(0, requested,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      await tester.pump(const Duration(seconds: 3));
      harness.expectRows(tester, newer);
      expect(harness.cardColor(tester, original[1]), newerColor,
          reason: 'An older ACK cannot replace the live status colour');
      harness.expectQuiet(tester, initialReads);
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'sequence stream sync: roundtrip hash still waits for its newer revision',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final original = List<String>.of(harness.ids);
      final moved = [original[2], original[0], original[1]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      harness.reorder(tester, 0, 2);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(1));
      harness.acknowledge(0, moved,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(2));
      expect(jsonDecode(harness.writes[1].body)['expected_version'], '1' * 64);
      final reconcile = Completer<AdminProductionOrderPage?>();
      harness.delayedReconcile = reconcile;
      harness.acknowledge(1, original,
          sequenceRevision: 7, sequenceVersion: '0' * 64);
      await _flushSequenceStreamSync(tester);
      harness.expectRows(tester, original);
      harness.expectQuiet(tester, initialReads);

      // Returning to the original order restores its hash, but the only
      // published page is still sequence revision5. It cannot certify ACK7.
      await tester.pump(const Duration(milliseconds: 1999));
      harness.expectQuiet(tester, initialReads);
      await tester.pump(const Duration(milliseconds: 2));
      await _flushSequenceStreamSync(tester);
      expect(harness.reads, hasLength(initialReads + 1),
          reason:
              'An equal hash must not cancel recovery for an older revision');
      expect(harness.reads.last.view, 'sequence');
      expect(harness.reads.last.apparatus, scanApparatus);
      expect(harness.reads.last.ifVersion, isNull);

      harness.installCanonical(original,
          revision: 9, sequenceRevision: 7, sequenceVersion: '0' * 64);
      harness.delayedReconcile = null;
      reconcile
          .complete(await AdminProductionOrderPage.fromJson(harness.payload()));
      await tester.pumpAndSettle();
      harness.expectRows(tester, original);
      expect(harness.reads, hasLength(initialReads + 1));
      expect(find.byKey(_recoveryProgressKey), findsNothing);
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'sequence stream sync: missing delta uses one scoped GET after 2s',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final moved = [harness.ids[2], harness.ids[0], harness.ids[1]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(1));
      final reconcile = Completer<AdminProductionOrderPage?>();
      harness.delayedReconcile = reconcile;
      harness.acknowledge(0, moved,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      await tester.pump(const Duration(milliseconds: 1999));
      harness.expectQuiet(tester, initialReads);
      await tester.pump(const Duration(milliseconds: 2));
      await _flushSequenceStreamSync(tester);
      expect(harness.reads, hasLength(initialReads + 1));
      final fallback = harness.reads.last;
      expect(fallback.view, 'sequence');
      expect(fallback.apparatus, scanApparatus);
      expect(fallback.cursor, isNull);
      expect(fallback.ifVersion, isNull,
          reason: 'Missing action controls require an authoritative response');
      await tester.pump(const Duration(seconds: 5));
      expect(harness.reads, hasLength(initialReads + 1),
          reason: 'A pending fallback must not start overlapping reloads');

      harness.installCanonical(moved,
          revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
      harness.delayedReconcile = null;
      reconcile
          .complete(await AdminProductionOrderPage.fromJson(harness.payload()));
      await tester.pumpAndSettle();
      harness.expectRows(tester, moved);
      expect(harness.reads, hasLength(initialReads + 1));
      expect(find.byKey(_recoveryProgressKey), findsNothing);
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'sequence stream sync: reconnect drops the staged pre-ACK wire baseline',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    var connections = 0;
    harness.events.onListen = () => connections++;
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      expect(connections, 1);
      final initialReads = harness.reads.length;
      final original = List<String>.of(harness.ids);
      final moved = [original[2], original[0], original[1]];
      final pendingColor = harness.cardColor(tester, original[1]);
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      harness.acknowledge(0, moved,
          sequenceRevision: 7, sequenceVersion: '2' * 64);
      await _flushSequenceStreamSync(tester);

      harness.installCanonical(original,
          revision: 8, sequenceRevision: 6, sequenceVersion: '1' * 64);
      harness.sendCanonicalDelta(states: {original[1]: 'in_progress'});
      await tester.pumpAndSettle();
      harness.expectRows(tester, moved);
      expect(harness.cardColor(tester, original[1]), pendingColor,
          reason: 'The intermediate wire page must not publish pre-ACK colors');
      harness.expectQuiet(tester, initialReads);

      final reconcile = Completer<AdminProductionOrderPage?>();
      harness.delayedReconcile = reconcile;
      harness.events.addError(http.ClientException('test socket disconnected'));
      await _flushSequenceStreamSync(tester);
      expect(harness.reads, hasLength(initialReads + 1));
      await tester.pump(const Duration(milliseconds: 1100));
      await _flushSequenceStreamSync(tester);
      expect(connections, 2,
          reason:
              'The test must exercise a new socket within the same generation');

      // A reconnect subscribes from the published v7, never staged v8.
      // Using v8 as its baseline would reject this valid patch and keep the
      // old color until HTTP completes (or start another recovery request).
      harness.installCanonical(moved,
          revision: 9, sequenceRevision: 7, sequenceVersion: '2' * 64);
      harness.sendCanonicalDelta(
          baseVersion: 'v7', states: {original[1]: 'in_progress'});
      await _flushSequenceStreamSync(tester);
      harness.expectRows(tester, moved);
      final liveColor = harness.cardColor(tester, original[1]);
      expect(liveColor, isNot(pendingColor),
          reason: 'The new socket must apply its canonical delta before HTTP');
      expect(harness.reads, hasLength(initialReads + 1),
          reason: 'Reconnect must share the existing recovery GET');

      final recovered = harness.payload();
      recovered['queue_states'][scanApparatus][original[1]] = 'in_progress';
      recovered['queue_action_controls'][scanApparatus][original[1]] =
          _syncControl('in_progress');
      harness.delayedReconcile = null;
      reconcile.complete(await AdminProductionOrderPage.fromJson(recovered));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      harness.expectRows(tester, moved);
      expect(harness.cardColor(tester, original[1]), liveColor);
      expect(harness.reads, hasLength(initialReads + 1));
      expect(find.byKey(_recoveryProgressKey), findsNothing);
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets(
      'sequence stream sync: two queued drags accept one later page state',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final original = List<String>.of(harness.ids);
      final first = [original[2], original[0], original[1]];
      final second = [original[1], original[2], original[0]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      harness.expectRows(tester, second);
      expect(harness.writes, hasLength(1),
          reason: 'The second drag must wait for the first versioned ACK');

      harness.acknowledge(0, first,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(2));
      final nextWrite = jsonDecode(harness.writes[1].body) as Map;
      expect(nextWrite['expected_version'], '1' * 64);
      expect(nextWrite['order_id'], original[1]);
      expect(nextWrite['before_order_id'], original[2]);
      harness.expectRows(tester, second);
      harness.expectQuiet(tester, initialReads);
      harness.acknowledge(1, second,
          sequenceRevision: 7, sequenceVersion: '2' * 64);
      await _flushSequenceStreamSync(tester);

      // The stream may coalesce the intermediate move. The latest revision
      // certifies both ACKs without requiring the first patch to arrive.
      harness.installCanonical(second,
          revision: 9, sequenceRevision: 7, sequenceVersion: '2' * 64);
      harness.sendCanonicalDelta();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      harness.expectRows(tester, second);
      harness.expectQuiet(tester, initialReads);
      expect(harness.writes, hasLength(2));
      await harness.dispose(tester);
    }, () => MockClient(harness.respond));
  });

  testWidgets('sequence stream sync: an old session ACK cannot start recovery',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final original = List<String>.of(harness.ids);
      final moved = [original[2], original[0], original[1]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      final token = AppSession.instance.token!;
      final profile = AppSession.instance.profile!;
      await AppSession.instance
          .setSession(token: 'replacement-admin-token', profile: profile);
      harness.acknowledge(0, moved,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      await tester.pump(const Duration(seconds: 3));
      // Cached rows belong to the previous token and cannot populate the new
      // account window, even when its role and principal reference are equal.
      harness.expectRows(tester, const []);
      harness.expectQuiet(tester, initialReads);
      await harness.dispose(tester);
      await AppSession.instance.setSession(token: token, profile: profile);
    }, () => MockClient(harness.respond));
  });

  testWidgets('sequence stream sync: dispose cancels the ACK watchdog',
      (tester) async {
    final harness =
        _SequenceStreamSyncHarness(await _prepareScanBootstrapFixture(tester));
    await http.runWithClient(() async {
      await harness.mountForWrites(tester);
      final initialReads = harness.reads.length;
      final moved = [harness.ids[2], harness.ids[0], harness.ids[1]];
      harness.reorder(tester, 2, 0);
      await _flushSequenceStreamSync(tester);
      expect(harness.writes, hasLength(1));
      harness.acknowledge(0, moved,
          sequenceRevision: 6, sequenceVersion: '1' * 64);
      await _flushSequenceStreamSync(tester);
      harness.expectQuiet(tester, initialReads);
      await harness.dispose(tester);
      expect(harness.reads, hasLength(initialReads),
          reason: 'The disposed screen must not start the fallback GET');
      expect(harness.writes, hasLength(1));
    }, () => MockClient(harness.respond));
  });
}
