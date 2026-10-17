part of 'admin_production_map_test_screen_test.dart';

class _RezkaAstatkaSafetyFixture extends _RePauseFixture {
  _RezkaAstatkaSafetyFixture() : super(station: _rezkaId);
  String sessionId = 'astatka-session-original';
  bool commitBeforeLoss = true;
  bool malformedSnapshot = false;
  bool failSnapshot = false;
  bool denyRetry = false;
  final reports = <String, Map<String, dynamic>>{};
  final submissions = <Map<String, dynamic>>[];

  @override
  Map<String, dynamic> control({bool other = false}) => {
        ...super.control(other: other),
        'stage_node_id': 'second-apparatus',
        'rezka_total_waste_only': true,
      };

  @override
  Future<http.Response> respond(http.Request request) async {
    if (!request.url.path.endsWith('/rezka-astatka')) {
      return super.respond(request);
    }
    requests.add(request);
    if (request.method == 'GET') {
      if (failSnapshot) return http.Response('{}', 503);
      final report = reports[request.url.queryParameters['request_id']];
      return http.Response(
          jsonEncode(malformedSnapshot
              ? {'ok': true}
              : report != null
                  ? {
                      'ok': true,
                      'request_result': {'ok': true, 'report': report}
                    }
                  : {
                      'ok': true,
                      'session_id': sessionId,
                      'stage_node_id': 'second-apparatus',
                      'request_result': null
                    }),
          200);
    }
    mutations.add(request);
    final body = (jsonDecode(request.body) as Map).cast<String, dynamic>();
    submissions.add(body);
    if (denyRetry) return http.Response('{"error":"forbidden"}', 403);
    if (body['session_id'] != sessionId) {
      return http.Response('{"error":"queue_action_not_allowed"}', 409);
    }
    if (!loseResponse || commitBeforeLoss) {
      reports.putIfAbsent(
          body['request_id'] as String,
          () => {
                ...body,
                'report_id': 'saved-${reports.length}',
                'rezka_bosma_waste': 0,
                'rezka_lamination_waste': 0,
                'rezka_edge_waste': 0,
              });
    }
    if (loseResponse) {
      loseResponse = false;
      throw http.ClientException('Response lost');
    }
    return http.Response(
        jsonEncode({'ok': true, 'report': reports[body['request_id']]}), 200);
  }

  Future<void> reportForm(WidgetTester tester, {bool reopen = false}) async {
    if (reopen) {
      // A failed POST leaves its owning detail open; closing it must also release
      // the shared mutation lock before a new sheet reconciles the saved request.
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        await tester
            .tap(find.byKey(const ValueKey('production-order-detail-close')));
        await tester.pumpAndSettle();
      }
      await tester.longPress(
          find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await tester.pumpAndSettle();
    }
    await tester.tap(
        find.widgetWithText(FilledButton, 'Astatka hisobotini topshirish'));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String waste) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Chiqindi'), waste);
    await tester.tap(find.text('Tasdiqlash'));
    await tester.pumpAndSettle();
  }
}

void _registerRezkaAstatkaSafetyTests() {
  testWidgets('rezka astatka account switch cancels the previous actor form',
      (tester) async {
    final fixture = _RezkaAstatkaSafetyFixture();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.reportForm(tester);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Chiqindi'), '7');
      await AppSession.instance.setSession(
          token: 'other-account',
          profile: const SessionProfile(
              role: UserRole.aparatchi,
              displayName: 'Other worker',
              legalName: '',
              ref: 'other-worker',
              phone: '',
              avatarUrl: '',
              capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
              assignedApparatus: [_rezkaId]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasdiqlash'));
      await tester.pumpAndSettle();
      expect(fixture.submissions, isEmpty);
      expect(fixture.reports, isEmpty);
      expect(
          (await SharedPreferences.getInstance())
              .getKeys()
              .where((key) => key.startsWith('rezka_astatka_pending:')),
          isEmpty);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'rezka astatka rejects stale session then opens a new session report',
      (tester) async {
    final fixture = _RezkaAstatkaSafetyFixture();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.reportForm(tester);
      fixture.sessionId = 'reactivated-session';
      await fixture.submit(tester, '2.5');
      expect(
          fixture.submissions.single['session_id'], 'astatka-session-original');
      expect(fixture.reports, isEmpty);
      expect(
          (await SharedPreferences.getInstance())
              .getKeys()
              .where((key) => key.startsWith('rezka_astatka_pending:')),
          isEmpty);
      await fixture.reportForm(tester, reopen: true);
      await fixture.submit(tester, '1');
      expect(fixture.submissions.last['session_id'], 'reactivated-session');
      expect(fixture.submissions.last['request_id'],
          isNot(fixture.submissions.first['request_id']));
      expect(fixture.reports, hasLength(1));
    }, () => MockClient(fixture.respond));
  });

  for (final committed in [true, false]) {
    testWidgets(
        'rezka astatka lost response committed=$committed retains one request identity',
        (tester) async {
      final fixture = _RezkaAstatkaSafetyFixture()
        ..loseResponse = true
        ..commitBeforeLoss = committed;
      await http.runWithClient(() async {
        await fixture.open(tester);
        await fixture.reportForm(tester);
        await fixture.submit(tester, '2.5');
        final preferences = await SharedPreferences.getInstance();
        final key = preferences
            .getKeys()
            .singleWhere((key) => key.startsWith('rezka_astatka_pending:'));
        final saved = preferences.getString(key);
        expect(saved, isNotNull);
        expect(fixture.submissions, hasLength(1));
        fixture.failSnapshot = true;
        await fixture.reportForm(tester, reopen: true);
        expect(preferences.getString(key), saved,
            reason:
                'A failed reconciliation read must preserve the exact request');
        expect(find.widgetWithText(TextFormField, 'Chiqindi'), findsNothing);
        expect(fixture.submissions, hasLength(1));
        fixture.failSnapshot = false;
        await fixture.reportForm(tester, reopen: true);
        if (!committed) {
          expect(find.widgetWithText(TextFormField, 'Chiqindi'), findsNothing);
          await tester.tap(find.text('Bekor qilish'));
          await tester.pumpAndSettle();
          expect(preferences.getString(key), saved,
              reason: 'Cancelling retry cannot discard an uncertain write');
          await fixture.reportForm(tester, reopen: true);
          await tester.tap(find.text('Qayta urinish'));
          await tester.pumpAndSettle();
          expect(fixture.submissions, hasLength(2));
          expect(fixture.submissions.last, fixture.submissions.first);
        } else {
          expect(fixture.submissions, hasLength(1),
              reason: 'GET reconciliation recognizes the committed receipt');
        }
        expect(fixture.reports, hasLength(1));
        expect(preferences.getString(key), isNull);
        // A genuinely additional report must obtain a fresh request identity,
        // even if the operator enters the same amount again.
        await fixture.reportForm(tester, reopen: true);
        await fixture.submit(tester, '2.5');
        expect(fixture.reports, hasLength(2));
        expect(fixture.submissions.last['request_id'],
            isNot(fixture.submissions.first['request_id']));
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('rezka astatka denied retry retains the uncertain request',
      (tester) async {
    final fixture = _RezkaAstatkaSafetyFixture()
      ..loseResponse = true
      ..commitBeforeLoss = false;
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.reportForm(tester);
      await fixture.submit(tester, '2.5');
      final preferences = await SharedPreferences.getInstance();
      final key = preferences
          .getKeys()
          .singleWhere((key) => key.startsWith('rezka_astatka_pending:'));
      final saved = preferences.getString(key);
      fixture.denyRetry = true;
      await fixture.reportForm(tester, reopen: true);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(fixture.submissions, hasLength(2));
      expect(preferences.getString(key), saved,
          reason:
              'Access denial cannot prove an earlier request did not commit');
      fixture.denyRetry = false;
      await fixture.reportForm(tester, reopen: true);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(fixture.submissions, hasLength(3));
      expect(
          fixture.submissions.every((body) =>
              body['request_id'] == fixture.submissions.first['request_id']),
          isTrue);
      expect(fixture.reports, hasLength(1));
      expect(preferences.getString(key), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'rezka astatka missing session snapshot cannot open an unbound form',
      (tester) async {
    final fixture = _RezkaAstatkaSafetyFixture()..malformedSnapshot = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.reportForm(tester);
      expect(find.widgetWithText(TextFormField, 'Chiqindi'), findsNothing);
      expect(fixture.submissions, isEmpty);
    }, () => MockClient(fixture.respond));
  });
}
