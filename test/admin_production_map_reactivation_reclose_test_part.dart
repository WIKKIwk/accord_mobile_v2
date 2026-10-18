part of 'admin_production_map_test_screen_test.dart';

class _RecloseFixture extends _RePauseFixture {
  _RecloseFixture({super.station}) {
    phase = 'paused';
    astatka = true;
  }
  final token = List.filled(64, 'a').join();

  @override
  Map<String, dynamic> control({bool other = false}) {
    final result = super.control(other: other)..remove('re_pause');
    if (!other && phase == 'paused' && owner != null) {
      result['reclose'] = {
        'session_id': 'unstarted-continuation',
        'stage_node_id': result['stage_node_id'],
        'token': token,
        'worker_role': 'aparatchi',
        'worker_ref': owner
      };
    }
    if (!other && phase == 'completed') {
      result['state'] = 'completed';
      result['allowed_actions'] = <String>[];
      result['interaction'] = {
        ...result['interaction'] as Map,
        'mode': 'completed'
      };
    }
    return result;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (!request.url.path.endsWith('/reactivation/reclose'))
      return super.respond(request);
    requests.add(request);
    mutations.add(request);
    if (mutationGate != null) await mutationGate!.future;
    owner = null;
    if (reject) {
      revision++;
      return http.Response('{"error":"queue_action_not_allowed"}', 409);
    }
    changePhase('completed');
    if (loseResponse) throw http.ClientException('response lost after commit');
    return http.Response(
        jsonEncode({'ok': true, 'rev': revision, 'epoch': 'inline-server'}),
        200);
  }
}

void _registerRecloseTests() {
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final lost in [false, true]) {
      testWidgets(
          'unstarted reclose uses no output or waste form on $station, lost=$lost',
          (tester) async {
        final fixture = _RecloseFixture(station: station)
          ..loseResponse = lost
          ..wipStatus = 'in_use';
        await http.runWithClient(() async {
          await fixture.open(tester);
          expect(find.byKey(const ValueKey('worker-reclose')), findsOneWidget);
          expect(find.byKey(const ValueKey('worker-re-pause')), findsNothing);
          expect(find.textContaining('Astatka'), findsWidgets);
          await tester.tap(find.byKey(const ValueKey('worker-reclose')));
          await tester.pumpAndSettle();
          expect(fixture.phase, 'completed');
          expect(fixture.mutations, hasLength(1));
          expect(jsonDecode(fixture.mutations.single.body), {
            'apparatus': station,
            'order_id': _inlineOrderId,
            'session_id': 'unstarted-continuation',
            'stage_node_id': 'second-apparatus',
            'token': fixture.token
          });
          expect(
              fixture.requests
                  .where((r) => r.url.path.endsWith('/queue-action')),
              isEmpty);
          expect(
              find.byWidgetPredicate((w) =>
                  w.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
              findsNothing);
          expect(tester.takeException(), isNull);
        }, () => MockClient(fixture.respond));
      });
    }
  }
  for (final owner in <String?>[null, 'other-worker']) {
    testWidgets('reclose hidden for missing or other worker permission: $owner',
        (tester) async {
      final fixture = _RecloseFixture()
        ..owner = owner
        ..astatka = false;
      await http.runWithClient(() async {
        await fixture.open(tester);
        expect(find.byKey(const ValueKey('worker-reclose')), findsNothing);
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }
  testWidgets('stale reclose is refreshed without write replay',
      (tester) async {
    final fixture = _RecloseFixture()..reject = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-reclose')));
      await tester.pumpAndSettle();
      expect(fixture.phase, 'paused');
      expect(fixture.mutations, hasLength(1));
      await tester.longPress(
          find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('worker-reclose')), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });
}
