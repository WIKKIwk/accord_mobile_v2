part of 'admin_production_map_test_screen_test.dart';

void _registerSequenceReorderTests() {
  for (final scenario in [
    'nearest',
    'first',
    'locked',
    'down',
    'paused-down',
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
            sequenceRevisions: {_print8Id: revision},
            visibleOrderIds: {
              _print8Id: scenario == 'hidden' ? [ids[0], ids[2]] : ids
            },
            queueStates: scenario == 'paused-down'
                ? {
                    ...initial.queueStates,
                    _print8Id: {
                      ...?initial.queueStates[_print8Id],
                      ids.first: 'paused',
                    },
                  }
                : initial.queueStates,
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
      final live = StreamController<AdminProductionMapLiveSnapshot>.broadcast();
      addTearDown(live.close);
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
              queueSnapshotLoader: () async => snapshot(),
              apparatusLoader: () async =>
                  catalog.where((item) => item.id == _print8Id).toList(),
              liveEventsLoader: () => live.stream),
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
        final down = scenario == 'down' || scenario == 'paused-down';
        final hidden = scenario == 'hidden';
        expect(list.itemCount, hidden ? 2 : 3);
        final frozenRow = find.byKey(
            ValueKey('sequence-row-$_print8Id-${ids[1]}'));
        const rowPrefix = 'sequence-row-$_print8Id-';
        List<String> displayedOrderIds() => tester
            .widgetList(find.byWidgetPredicate((widget) =>
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith(rowPrefix)))
            .map((widget) => (widget.key as ValueKey<String>)
                .value.substring(rowPrefix.length))
            .toList();
        if (scenario == 'frozen') {
          expect(frozenRow, findsOneWidget);
          list.onReorderItem!(displayedOrderIds().indexOf(ids[1]), 0);
          await tester.pump();
          expect(requests, isEmpty, reason: 'The frozen row is not movable');
        }
        final requested =
            down ? [ids[1], ids[2], ids[0]] : [ids[2], ids[0], ids[1]];
        final saved = switch (scenario) {
          'nearest' => [ids[0], ids[2], ids[1]],
          'first' => requested,
          'down' => [ids[1], ids[0], ids[2]],
          'paused-down' => requested,
          'frozen' => [ids[2], ids[0]],
          'hidden' || 'lost-reply' || 'newer-success' || 'search-readonly' => [
              ids[2],
              ids[0],
              ids[1]
            ],
          _ => ids,
        };
        final moved = down ? ids.first : ids.last;
        list.onReorderItem!(displayedOrderIds().indexOf(moved), down ? 2 : 0);
        if (scenario == 'no-version') {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(requests, isEmpty);
          expect(find.textContaining('Server navbat versiyasini bermadi'),
              findsOneWidget);
          expect(displayedOrderIds(), ids);
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
        authoritative = List<String>.from(saved);
        revision = 2;
        final newer = scenario.startsWith('newer-');
        if (newer) {
          authoritative = [ids[1], ids[0], ids[2]];
          revision = 3;
          final fresh = snapshot();
          live.add(AdminProductionMapLiveSnapshot(
            maps: fresh.maps,
            sequences: fresh.sequences,
            sequenceVersions: fresh.sequenceVersions,
            sequenceRevisions: fresh.sequenceRevisions,
            visibleOrderIds: fresh.visibleOrderIds,
            queueStates: fresh.queueStates,
            queuePolicies: fresh.queuePolicies,
            orderControls: fresh.orderControls,
            completedOrders: const [],
            completionRequests: const [],
            completionRequestDecisions: const [],
            epoch: fresh.epoch,
            revision: fresh.revision,
          ));
          await tester.pumpAndSettle();
        }
        final rejected = scenario == 'rejected' || scenario == 'newer-rejected';
        if (scenario == 'lost-reply') {
          response.completeError(TimeoutException('reply lost after commit'));
        } else {
          response.complete(http.Response(
              jsonEncode({
                'ok': !rejected,
                if (rejected)
                  'error': newer ? 'queue_reorder_conflict' : 'forbidden',
                'revision': 2,
                if (scenario != 'missing-result') 'order_ids': saved,
                'version': '1' * 64,
                'adjusted': scenario == 'nearest' ||
                    scenario == 'locked' ||
                    scenario == 'down',
              }),
              rejected ? (newer ? 409 : 403) : 200));
        }
        await tester.pumpAndSettle();
        if (scenario == 'lost-reply') {
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
          expect(requests, hasLength(2));
          expect(requests.last.body, requests.first.body);
        } else if (scenario == 'newer-rejected') {
          expect(requests, hasLength(2));
          final rebased = jsonDecode(requests.last.body) as Map;
          expect(rebased['order_id'], ids.last);
          expect(rebased['before_order_id'], ids.first);
          expect(rebased['expected_version'], '2' * 64);
          expect(rebased['idempotency_key'],
              isNot((jsonDecode(requests.first.body) as Map)['idempotency_key']));
        } else {
          expect(requests, hasLength(1));
        }
        final displayed = displayedOrderIds();
        expect(
          scenario == 'frozen'
              ? displayed.where((id) => id != ids[1]).toList()
              : displayed,
          scenario == 'newer-rejected'
              ? [ids[1], ids[2], ids[0]]
              : newer
                  ? authoritative
                  : hidden
                      ? [ids[2], ids[0]]
                      : saved,
        );
        if (scenario == 'frozen') {
          expect(frozenRow, findsOneWidget);
          await tester.tap(find.text('Buyurtmalar'));
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('opened-order-${ids[1]}')), findsOneWidget);
        }
        if (scenario == 'nearest' ||
            scenario == 'locked' ||
            scenario == 'down') {
          final position = saved.indexOf(down ? ids.first : ids.last) + 1;
          final notice = AppLocalizations(const Locale('uz')).adminText(
              'sequence.nearest_position', values: {'position': position});
          expect(find.text(notice), findsOneWidget,
              reason: tester.widgetList<Text>(
                  find.textContaining('eng yaqin ruxsat etilgan'))
                  .map((widget) => widget.data).join(', '));
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
                  if (requests.length == 1) return response.future;
                  if (scenario == 'newer-rejected') {
                    authoritative = [ids[1], ids[2], ids[0]];
                    revision = 4;
                  }
                  return http.Response(jsonEncode({
                    'ok': true,
                    'order_ids': authoritative,
                    'version': (revision == 2 ? '1' : '3') * 64,
                    'revision': revision,
                  }), 200);
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
