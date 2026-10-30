part of 'admin_production_map_test_screen_test.dart';

class _ScannedWipFixture extends _TemporaryPauseFixture {
  _ScannedWipFixture({super.station});
  int reads = 0;
  int writes = 0;
  bool returned = false;
  bool failRead = false;
  bool loseReturnResponse = false;
  Completer<void>? historyGate;
  http.Request? returnRequest;

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/scanned-wips')) {
      reads++;
      expect(request.method, 'GET');
      expect(request.url.queryParameters, {
        'apparatus': station,
        'order_id': _inlineOrderId,
        'stage_node_id': 'second-apparatus',
      });
      if (historyGate != null) await historyGate!.future;
      if (failRead) return http.Response('{"error":"unavailable"}', 503);
      return http.Response(
          jsonEncode({
            'items': [
              {
                'session_id': 'input-session',
                'batch_id': 'untouched-input',
                'qr_payload': 'QR-UNTOUCHED',
                'source_apparatus': _print9Id,
                'linked_at_unix': 1000,
                'worker_display_name': 'Worker',
                'state': returned ? 'returned' : 'unprocessed',
                'consume_state': 'unused',
                'return_token': returned ? null : pauseToken,
                'blocked_reason': ''
              },
              {
                'session_id': 'input-session',
                'batch_id': 'consumed-input',
                'qr_payload': 'QR-CONSUMED',
                'source_apparatus': _print9Id,
                'linked_at_unix': 900,
                'worker_display_name': 'Worker',
                'state': 'consumed',
                'consume_state': 'consumed',
                'return_token': null,
                'blocked_reason': 'work_recorded'
              },
            ]
          }),
          200);
    }
    if (request.url.path.endsWith('/scanned-wips/return')) {
      writes++;
      returnRequest = request;
      returned = true;
      if (loseReturnResponse)
        throw http.ClientException('Response lost after commit');
      return http.Response('{"ok":true}', 200);
    }
    return super.respond(request);
  }

  Future<void> openDetail(WidgetTester tester) async {
    await open(tester);
    Navigator.of(tester
            .element(find.byKey(const ValueKey('worker-temporary-pause'))))
        .pop();
    await _pumpTemporaryPauseUi(tester);
    await tester
        .tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
    await _pumpTemporaryPauseUi(tester);
  }
}

void _registerScannedWipTests() {
  testWidgets(
      'scanned WIP pending read cannot display another account\'s history',
      (tester) async {
    final f = _ScannedWipFixture()..historyGate = Completer<void>();
    await http.runWithClient(() async {
      await f.openDetail(tester);
      await tester
          .tap(find.byKey(const ValueKey('production-order-scanned-wips')));
      await _pumpTemporaryPauseUi(tester);
      expect(f.reads, 1);
      AppSession.instance.profile = SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Other worker',
          legalName: '',
          ref: 'other-account',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [f.station]);
      AppSession.instance.revision.value++;
      f.historyGate!.complete();
      await _pumpTemporaryPauseUi(tester);
      expect(find.text('QR-UNTOUCHED'), findsNothing);
      expect(find.text('QR-CONSUMED'), findsNothing);
      expect(f.writes, 0);
      expect(tester.takeException(), isNull);
    }, () => MockClient(f.respond));
  });

  for (final station in [_lamination1Id, _rezkaId]) {
    testWidgets('scanned WIP history loads only from header button on $station',
        (tester) async {
      final f = _ScannedWipFixture(station: station)..wipStatus = 'in_use';
      await http.runWithClient(() async {
        await f.openDetail(tester);
        final button =
            find.byKey(const ValueKey('production-order-scanned-wips'));
        expect(button, findsOneWidget);
        expect(f.reads, 0);
        f.events.add(f.snapshot());
        await _pumpTemporaryPauseUi(tester);
        expect(f.reads, 0,
            reason: 'Live/detail synchronization must not fetch input history');
        await tester.tap(button);
        await _pumpTemporaryPauseUi(tester);
        expect(f.reads, 1);
        expect(find.text('QR-UNTOUCHED'), findsOneWidget);
        expect(find.text('QR-CONSUMED'), findsOneWidget);
        expect(find.textContaining('Sarfga o‘tgan'), findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('scanned-wip-history-close')));
        await _pumpTemporaryPauseUi(tester);
        expect(f.reads, 1);
        await tester.tap(button);
        await _pumpTemporaryPauseUi(tester);
        expect(f.reads, 2,
            reason: 'Each explicit opening obtains current server state');
        expect(f.writes, 0);
        expect(tester.takeException(), isNull);
      }, () => MockClient(f.respond));
    });

    for (final lost in [false, true]) {
      testWidgets(
          'scanned WIP long press returns only untouched input on $station lost=$lost',
          (tester) async {
        final f = _ScannedWipFixture(station: station)
          ..wipStatus = 'in_use'
          ..loseReturnResponse = lost;
        await http.runWithClient(() async {
          await f.openDetail(tester);
          await tester
              .tap(find.byKey(const ValueKey('production-order-scanned-wips')));
          await _pumpTemporaryPauseUi(tester);
          await tester.longPress(find.text('QR-CONSUMED'));
          await _pumpTemporaryPauseUi(tester);
          expect(find.byKey(const ValueKey('scanned-wip-return-confirm')),
              findsNothing);
          expect(f.writes, 0);
          await tester.longPress(find.text('QR-UNTOUCHED'));
          await _pumpTemporaryPauseUi(tester);
          expect(f.writes, 0,
              reason: 'Holding a WIP requires confirmation before writing');
          await tester
              .tap(find.byKey(const ValueKey('scanned-wip-return-cancel')));
          await _pumpTemporaryPauseUi(tester);
          expect(f.writes, 0);
          await tester.longPress(find.text('QR-UNTOUCHED'));
          await _pumpTemporaryPauseUi(tester);
          await tester
              .tap(find.byKey(const ValueKey('scanned-wip-return-confirm')));
          await _pumpTemporaryPauseUi(tester);
          expect(f.writes, 1);
          expect(jsonDecode(f.returnRequest!.body), {
            'apparatus': station,
            'order_id': _inlineOrderId,
            'stage_node_id': 'second-apparatus',
            'session_id': 'input-session',
            'batch_id': 'untouched-input',
            'token': f.pauseToken,
          });
          expect(f.reads, 2,
              reason:
                  'A lost response reconciles history without replaying the mutation');
          expect(find.textContaining('Qaytarilgan'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }, () => MockClient(f.respond));
      });
    }
  }

  testWidgets(
      'scanned WIP read failure retries independently of the order sheet',
      (tester) async {
    final f = _ScannedWipFixture()..failRead = true;
    await http.runWithClient(() async {
      await f.openDetail(tester);
      await tester
          .tap(find.byKey(const ValueKey('production-order-scanned-wips')));
      await _pumpTemporaryPauseUi(tester);
      expect(find.text('WIP ro‘yxatini yuklab bo‘lmadi'), findsOneWidget);
      expect(f.reads, 1);
      expect(f.writes, 0);
      f.failRead = false;
      await tester
          .tap(find.byKey(const ValueKey('scanned-wip-history-refresh')));
      await _pumpTemporaryPauseUi(tester);
      expect(f.reads, 2);
      expect(find.text('QR-UNTOUCHED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient(f.respond));
  });

  testWidgets('scanned WIP button is absent for printing', (tester) async {
    final f = _ScannedWipFixture(station: _print8Id);
    await http.runWithClient(() async {
      await f.openDetail(tester);
      expect(find.byKey(const ValueKey('production-order-scanned-wips')),
          findsNothing);
      expect(f.reads, 0);
    }, () => MockClient(f.respond));
  });
}
