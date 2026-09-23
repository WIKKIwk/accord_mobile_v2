part of 'admin_production_map_test_screen_test.dart';

void _registerOrderDeleteTests() {
  for (final tab in ['Buyurtmalar', 'Ketma-ketlik']) {
    for (final outcome in [
      'success',
      'pending refresh',
      'rejected',
      'cancelled'
    ]) {
      testWidgets('order delete from $tab: $outcome with immutable sequences',
          (tester) async {
        await TestModeController.instance.setEnabled(true);
        const id = 'zakaz-0015';
        const beforeId = 'zakaz-0014';
        const afterId = 'zakaz-0016';
        const ids = [beforeId, id, afterId];
        for (final orderId in ids) {
          await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
            id: orderId,
            orderNumber: orderId.substring(6),
            title: 'Delete test $orderId',
            productCode: 'DELETE',
            product: 'DELETE',
            apparatusId: _print8Id,
          ));
        }
        final catalog = await MobileApi.instance.adminApparatus(limit: 200);
        final initial =
            await MobileApi.instance.adminProductionMapQueueSnapshot();
        final maps = await MobileApi.instance.adminProductionMaps();
        final originalSequences = MobileApi.instance.parseApparatusSequenceMap({
          _print8Id: ids,
          _print9Id: <String>[],
        });
        var deleted = false;
        final posts = <http.Request>[];
        final pendingRefresh = Completer<AdminApparatusQueueSnapshot>();
        AdminApparatusQueueSnapshot snapshot() => AdminApparatusQueueSnapshot(
              maps: List.unmodifiable(maps.where((order) =>
                  ids.contains(order.map.id) &&
                  (!deleted || order.map.id != id))),
              revision: deleted ? 2 : 1,
              sequences: deleted
                  ? MobileApi.instance.parseApparatusSequenceMap({
                      _print8Id: [beforeId, afterId],
                      _print9Id: <String>[],
                    })
                  : originalSequences,
              visibleOrderIds: {
                _print8Id: [
                  for (final value in ids)
                    if (!deleted || value != id) value
                ],
              },
              queueStates: initial.queueStates,
              queuePolicies: initial.queuePolicies,
              queueActionControls: initial.queueActionControls,
              stageStates: initial.stageStates,
              orderControls: initial.orderControls,
            );
        await _usePhoneViewport(tester);
        await http.runWithClient(() async {
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
              apparatusLoader: () async =>
                  catalog.where((item) => item.id == _print8Id).toList(),
              queueSnapshotLoader: () async =>
                  deleted && outcome == 'pending refresh'
                      ? pendingRefresh.future
                      : snapshot(),
              closedOrdersLoader: () async => [],
              liveEventsLoader: () => const Stream.empty(),
            ),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          Finder orderInTab(String value, String currentTab) =>
              find.byKey(ValueKey(currentTab == 'Buyurtmalar'
                  ? 'opened-order-$value'
                  : 'sequence-row-$_print8Id-$value'));
          final order = orderInTab(id, tab);
          expect(order, findsOneWidget);
          await tester.ensureVisible(order);
          await tester.longPress(order);
          await tester.pumpAndSettle();
          await tester.tap(find.text('O‘chirish'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(posts, isEmpty, reason: 'Deletion needs confirmation');
          await TestModeController.instance.setEnabled(false);
          await tester.tap(find.descendant(
            of: find.byType(AlertDialog),
            matching: find
                .byType(outcome == 'cancelled' ? OutlinedButton : FilledButton),
          ));
          await tester.pumpAndSettle();

          final accepted = outcome == 'success' || outcome == 'pending refresh';
          expect(posts, hasLength(outcome == 'cancelled' ? 0 : 1));
          if (posts.isNotEmpty) {
            expect(jsonDecode(posts.single.body),
                {'order_id': id, 'action': 'delete'});
          }
          expect(find.text('Buyurtma amali bajarilmadi'), findsNothing);
          expect(find.text('Buyurtma o‘chirildi'),
              accepted ? findsOneWidget : findsNothing);
          expect(order, accepted ? findsNothing : findsOneWidget);
          if (outcome == 'rejected') {
            expect(find.text('Buyurtmani o‘chirib bo‘lmaydi'), findsOneWidget);
          }
          // A pending refresh must not be needed for local deletion to succeed.
          // The shared API snapshot and the remaining queue order stay intact.
          expect(originalSequences[_print8Id], ids);
          expect(originalSequences[_print9Id], isEmpty);
          await tester.tap(find.text('Ketma-ketlik'));
          await tester.pumpAndSettle();
          expect(orderInTab(id, 'Ketma-ketlik'),
              accepted ? findsNothing : findsOneWidget);
          final before = orderInTab(beforeId, 'Ketma-ketlik');
          final after = orderInTab(afterId, 'Ketma-ketlik');
          expect(before, findsOneWidget);
          expect(after, findsOneWidget);
          expect(tester.getTopLeft(before).dy,
              lessThan(tester.getTopLeft(after).dy));
          if (outcome == 'pending refresh') {
            pendingRefresh.complete(snapshot());
            await tester.pumpAndSettle();
            expect(orderInTab(id, 'Ketma-ketlik'), findsNothing);
            expect(posts, hasLength(1),
                reason: 'Refresh must not repeat deletion');
          }
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
            () => MockClient((request) async {
                  if (request.method == 'POST' &&
                      request.url.path.endsWith('/order-control')) {
                    posts.add(request);
                    if (outcome == 'rejected') {
                      return http.Response(
                          jsonEncode({
                            'error': 'order_delete_blocked',
                          }),
                          409);
                    }
                    deleted = true;
                    return http.Response('{"ok":true}', 200);
                  }
                  return http.Response('{"completion_requests":[]}', 200);
                }));
      });
    }
  }
}
