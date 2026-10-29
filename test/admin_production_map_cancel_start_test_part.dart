part of 'admin_production_map_test_screen_test.dart';

class _CancelStartFixture extends _TemporaryPauseFixture {
  _CancelStartFixture({super.station});
  bool canCancel = true;
  String cancelOwner = 'inline-new-shift';
  @override
  Future<void> open(WidgetTester tester) async {
    if (station == _extruderId || station == _coldGlueId) {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminCreateApparatus(
          _fixtureApparatusName(station),
          id: station,
          family: station == _extruderId ? 'laminatsiya' : 'kley',
          kind:
              station == _extruderId ? 'extruder_laminatsiya' : 'holodniy_kley',
          capabilities: [station == _extruderId ? 'laminate' : 'glue']);
    }
    await super.open(tester);
  }

  @override
  Map<String, dynamic> control({bool other = false}) => {
        ...super.control(other: other),
        if (!other && canCancel && phase == 'active')
          'cancel_start': {
            'session_id': 'fresh-wip-session',
            'token': pauseToken,
            'worker_ref': cancelOwner,
            'previous_state': 'pending',
          },
      };
  @override
  Future<http.Response> respond(http.Request request) async {
    if (!request.url.path.endsWith('/cancel-start')) {
      return super.respond(request);
    }
    requests.add(request);
    mutations.add(request);
    if (mutationGate != null) await mutationGate!.future;
    if (reject) {
      canCancel = false;
      revision++;
      return http.Response('{"error":"queue_action_not_allowed"}', 400);
    }
    wipStatus = 'waiting';
    changePhase('start');
    if (loseResponse) throw http.ClientException('Response lost after commit');
    return http.Response('{"ok":true}', 200);
  }
}

void _registerCancelStartTests() {
  for (final station in [_rezkaId, _lamination1Id, _extruderId, _coldGlueId]) {
    testWidgets('cancel start returns WIP through long press on $station',
        (tester) async {
      final f = _CancelStartFixture(station: station)..wipStatus = 'in_use';
      await http.runWithClient(() async {
        await f.open(tester);
        final button = find.byKey(const ValueKey('worker-cancel-start'));
        expect(button, findsOneWidget);
        expect(find.text('Boshlashni bekor qilish'), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('Boshlash bekor qilinsinmi?'), findsOneWidget);
        expect(f.mutations, isEmpty);
        await tester
            .tap(find.byKey(const ValueKey('worker-cancel-start-back')));
        await tester.pumpAndSettle();
        expect(f.mutations, isEmpty);
        await tester.longPress(
            find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
        await _pumpTemporaryPauseUi(tester);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('worker-cancel-start-confirm')));
        await _pumpTemporaryPauseUi(tester);
        expect(f.phase, 'start');
        expect(f.wipStatus, 'waiting');
        expect(f.mutations, hasLength(1));
        expect(jsonDecode(f.mutations.single.body), {
          'apparatus': station,
          'order_id': _inlineOrderId,
          'session_id': 'fresh-wip-session',
          'token': f.pauseToken
        });
        expect(f.requests.where((r) => r.url.path.endsWith('/queue-action')),
            isEmpty);
        expect(tester.takeException(), isNull);
        dismissAdminTopNotice();
        await _pumpTemporaryPauseUi(tester);
      }, () => MockClient(f.respond));
    });
  }
  for (final scenario in ['print', 'flexo', 'other-worker', 'used']) {
    testWidgets('cancel start is hidden for $scenario', (tester) async {
      final f = _CancelStartFixture(
          station: scenario == 'print'
              ? _print8Id
              : scenario == 'flexo'
                  ? _flexoId
                  : _rezkaId)
        ..wipStatus = 'in_use';
      if (scenario == 'other-worker') f.cancelOwner = 'another-worker';
      if (scenario == 'used') f.canCancel = false;
      await http.runWithClient(() async {
        await f.open(tester);
        expect(find.byKey(const ValueKey('worker-cancel-start')), findsNothing);
        expect(f.mutations, isEmpty);
      }, () => MockClient(f.respond));
    });
  }
  for (final lost in [false, true]) {
    testWidgets(
        'cancel start reconciles rejection or a lost response: lost=$lost',
        (tester) async {
      final f = _CancelStartFixture(station: _rezkaId)
        ..wipStatus = 'in_use'
        ..reject = !lost
        ..loseResponse = lost;
      await http.runWithClient(() async {
        await f.open(tester);
        await tester.tap(find.byKey(const ValueKey('worker-cancel-start')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('worker-cancel-start-confirm')));
        await _pumpTemporaryPauseUi(tester);
        expect(f.mutations, hasLength(1));
        expect(f.phase, lost ? 'start' : 'active');
        expect(f.wipStatus, lost ? 'waiting' : 'in_use');
        expect(find.byKey(const ValueKey('worker-cancel-start')), findsNothing);
        expect(tester.takeException(), isNull);
        dismissAdminTopNotice();
        await _pumpTemporaryPauseUi(tester);
      }, () => MockClient(f.respond));
    });
  }
}
