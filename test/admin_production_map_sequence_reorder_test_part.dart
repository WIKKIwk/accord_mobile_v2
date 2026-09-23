part of 'admin_production_map_test_screen_test.dart';

void _registerSequenceReorderTests() {
  for (final scenario in [
    'nearest',
    'first',
    'locked',
    'down',
    'rejected',
    'missing-result',
    'lost-reply',
    'frozen',
    'search-readonly',
    'hidden',
    'no-version',
    'newer-success',
    'newer-rejected',
  ]) {
    testWidgets('admin reorder uses server placement: $scenario',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      const ids = ['zakaz-0001', 'zakaz-0007', 'zakaz-0009'];
      for (final id in ids) {
        await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
          id: id,
          orderNumber: id.substring(6),
          title: id,
          productCode: id,
          product: id,
          apparatusId: _print8Id,
        ));
      }
      await MobileApi.instance
          .adminSaveProductionMapSequence(apparatus: _print8Id, orderIds: ids);
      final catalog = await MobileApi.instance.adminApparatus(limit: 200);
      final initial =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
      var authoritative = List<String>.from(ids);
      var revision = 1;
      AdminApparatusQueueSnapshot snapshot() => AdminApparatusQueueSnapshot(
            maps: initial.maps,
            sequences: {
              _print8Id: authoritative
                  .where((id) => scenario != 'frozen' || id != ids[1])
                  .toList()
            },
            sequenceVersions: {
              if (scenario != 'no-version')
                _print8Id: (revision == 1
                        ? '0'
                        : revision == 2
                            ? '1'
                            : '2') *
                    64
            },
            visibleOrderIds: {
              _print8Id: scenario == 'hidden' ? [ids[0], ids[2]] : ids
            },
            queueStates: initial.queueStates,
            queuePolicies: initial.queuePolicies,
            orderControls: {
              ...initial.orderControls,
              if (scenario == 'frozen') ids[1]: AdminOrderControlState.frozen,
            },
            queueActionControls: initial.queueActionControls,
            stageStates: initial.stageStates,
            revision: revision,
            epoch: 'reorder-test',
          );
      await _usePhoneViewport(tester);
      final requests = <http.Request>[];
      final response = Completer<http.Response>();
      Completer<AdminApparatusQueueSnapshot>? reconcile;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapOrdersScreen(
              queueSnapshotLoader: () =>
                  reconcile?.future ?? Future.value(snapshot()),
              apparatusLoader: () async =>
                  catalog.where((item) => item.id == _print8Id).toList(),
              liveEventsLoader: () => const Stream.empty()),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ketma-ketlik'));
        await tester.pumpAndSettle();
        if (scenario == 'search-readonly') {
          await tester.enterText(find.byType(EditableText).first, '0009');
          await tester.pumpAndSettle();
          expect(find.byType(ReorderableListView), findsNothing);
          expect(requests, isEmpty);
          await tester.enterText(find.byType(EditableText).first, '');
          await tester.pumpAndSettle();
        }
        await TestModeController.instance.setEnabled(false);
        await tester.pumpAndSettle();

        final list = tester
            .widget<ReorderableListView>(find.byType(ReorderableListView));
        final down = scenario == 'down';
        final reduced = scenario == 'frozen' || scenario == 'hidden';
        if (reduced) expect(list.itemCount, 2);
        final requested =
            down ? [ids[1], ids[2], ids[0]] : [ids[2], ids[0], ids[1]];
        final saved = switch (scenario) {
          'nearest' => [ids[0], ids[2], ids[1]],
          'first' => requested,
          'down' => [ids[1], ids[0], ids[2]],
          'frozen' => [ids[2], ids[0]],
          'hidden' || 'lost-reply' || 'newer-success' || 'search-readonly' => [
              ids[2],
              ids[0],
              ids[1]
            ],
          _ => ids,
        };
        list.onReorderItem!(
            down
                ? 0
                : reduced
                    ? 1
                    : 2,
            down ? 2 : 0);
        if (scenario == 'no-version') {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(requests, isEmpty);
          expect(
              find.textContaining('Navbatni xavfsiz surish'), findsOneWidget);
          expect(
              tester
                  .widget<ReorderableListView>(find.byType(ReorderableListView))
                  .key,
              ValueKey('sequence-list-$_print8Id-${ids.join(',')}'));
          dismissAdminTopNotice();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          return;
        }
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(sent['idempotency_key'], matches(RegExp(r'^[a-f0-9]{32}$')));
        sent.remove('idempotency_key');
        expect(sent, {
          'apparatus': _print8Id,
          'order_id': down ? ids.first : ids.last,
          if (down)
            'after_order_id': ids.last
          else
            'before_order_id': ids.first,
          'expected_version': '0' * 64,
        });
        // No overlapping writes may undo the server-adjusted result.
        list.onReorderItem!(1, 0);
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        authoritative = List<String>.from(saved);
        revision = 2;
        final newer = scenario.startsWith('newer-');
        if (newer) {
          authoritative = [ids[1], ids[0], ids[2]];
          revision = 3;
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          reconcile = Completer<AdminApparatusQueueSnapshot>();
        }
        final rejected = scenario == 'rejected' || scenario == 'newer-rejected';
        if (scenario == 'lost-reply') {
          response.completeError(TimeoutException('reply lost after commit'));
        } else {
          response.complete(http.Response(
              jsonEncode({
                'ok': !rejected,
                if (rejected) 'error': 'queue_reorder_conflict',
                if (scenario != 'missing-result') 'order_ids': saved,
                'version': '1' * 64,
                'adjusted': scenario == 'nearest' ||
                    scenario == 'locked' ||
                    scenario == 'down',
              }),
              rejected ? 409 : 200));
        }
        await tester.pumpAndSettle();
        final displayed = tester
            .widgetList(find.byWidgetPredicate((widget) =>
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>)
                    .value
                    .startsWith('sequence-row-$_print8Id-')))
            .map((widget) => (widget.key as ValueKey<String>)
                .value
                .substring('sequence-row-$_print8Id-'.length))
            .toList();
        expect(
            displayed,
            newer
                ? authoritative
                : scenario == 'hidden'
                    ? [ids[2], ids[0]]
                    : saved);
        if (newer) {
          reconcile!.complete(snapshot());
          await tester.pumpAndSettle();
        }
        if (scenario == 'frozen') {
          expect(find.byKey(ValueKey('sequence-row-$_print8Id-${ids[1]}')),
              findsNothing);
          // Only the draggable queue hides it, not the order itself.
          await tester.tap(find.text('Buyurtmalar'));
          await tester.pumpAndSettle();
          expect(
              find.byKey(ValueKey('opened-order-${ids[1]}')), findsOneWidget);
        }
        if (scenario == 'nearest' ||
            scenario == 'locked' ||
            scenario == 'down') {
          expect(
              find.textContaining('eng yaqin ruxsat etilgan'), findsOneWidget);
          final position = saved.indexOf(down ? ids.first : ids.last) + 1;
          expect(find.textContaining('$position-o‘ringa'), findsOneWidget);
        } else {
          expect(find.textContaining('eng yaqin ruxsat etilgan'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
          () => MockClient((request) async {
                if (request.method == 'POST' &&
                    request.url.path.endsWith('/production-maps/sequence')) {
                  requests.add(request);
                  return response.future;
                }
                return http.Response('{}', 200);
              }));
    });
  }

  test('sequence move validates replies and sends only an idempotent operation',
      () async {
    await TestModeController.instance.setEnabled(false);
    final valid = <String, Object>{
      'ok': true,
      'order_ids': ['c', 'a', 'hidden', 'b'],
      'version': '1' * 64,
      'adjusted': false,
    };
    for (final payload in [
      valid,
      {
        ...valid,
        'order_ids': ['c', 'c', 'a']
      },
      {
        ...valid,
        'order_ids': ['a', 'b']
      },
      {
        ...valid,
        'order_ids': ['c', 7]
      },
      {...valid, 'version': ''},
      {...valid, 'adjusted': 'false'},
      {...valid, 'ok': false},
    ]) {
      final bodies = <String>[];
      await http.runWithClient(() async {
        Future<AdminSequenceMoveResult> send() =>
            MobileApi.instance.adminMoveProductionMapSequence(
                apparatus: _print8Id,
                orderId: 'c',
                beforeOrderId: 'a',
                expectedVersion: '0' * 64,
                idempotencyKey: 'same-operation');
        if (identical(payload, valid)) {
          expect((await send()).orderIds, ['c', 'a', 'hidden', 'b']);
          await send();
          expect(bodies[0], bodies[1]);
        } else {
          await expectLater(send(), throwsA(isA<MobileApiException>()));
        }
        final body = jsonDecode(bodies.first) as Map;
        expect(body.containsKey('order_ids'), isFalse);
        expect(body['idempotency_key'], 'same-operation');
      },
          () => MockClient((request) async {
                expect(request.method, 'POST');
                bodies.add(request.body);
                return http.Response(jsonEncode(payload), 200);
              }));
    }
    await http.runWithClient(() async {
      for (final version in ['', 'invalid']) {
        await expectLater(
            MobileApi.instance.adminMoveProductionMapSequence(
                apparatus: _print8Id,
                orderId: 'c',
                beforeOrderId: 'a',
                expectedVersion: version,
                idempotencyKey: 'no-write'),
            throwsA(isA<MobileApiException>()
                .having((e) => e.code, 'code', 'queue_reorder_unavailable')));
      }
    },
        () => MockClient((_) async =>
            throw StateError('must not write without a valid version')));
  });

  test(
      'sequence save accepts server-added hidden orders and validates the result',
      () async {
    await TestModeController.instance.setEnabled(false);
    for (final saved in [
      ['a', 'hidden', 'c', 'b'],
      ['a', 'c', 'c', 'b'],
      ['a', 'b'],
      ['a', 7, 'c', 'b'],
    ]) {
      await http.runWithClient(() async {
        final result = MobileApi.instance.adminSaveProductionMapSequence(
            apparatus: _print8Id, orderIds: ['c', 'a', 'b'], movedOrderId: 'c');
        if (saved.contains('hidden')) {
          expect(await result, saved);
        } else {
          await expectLater(result, throwsA(isA<MobileApiException>()));
        }
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({'ok': true, 'order_ids': saved}), 200)));
    }
  });
}
