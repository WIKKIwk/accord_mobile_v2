part of 'admin_production_map_test_screen_test.dart';

void _registerSequenceReorderTests() {
  for (final scenario in [
    'nearest',
    'first',
    'locked',
    'down',
    'rejected',
    'missing-result'
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
      await _usePhoneViewport(tester);
      final requests = <http.Request>[];
      final response = Completer<http.Response>();
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
              apparatusLoader: () async =>
                  catalog.where((item) => item.id == _print8Id).toList(),
              liveEventsLoader: () => const Stream.empty()),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ketma-ketlik'));
        await tester.pumpAndSettle();
        await TestModeController.instance.setEnabled(false);

        final list = tester
            .widget<ReorderableListView>(find.byType(ReorderableListView));
        final down = scenario == 'down';
        final requested =
            down ? [ids[1], ids[2], ids[0]] : [ids[2], ids[0], ids[1]];
        final saved = switch (scenario) {
          'nearest' => [ids[0], ids[2], ids[1]],
          'first' => requested,
          'down' => [ids[1], ids[0], ids[2]],
          _ => ids,
        };
        list.onReorderItem!(down ? 0 : 2, down ? 2 : 0);
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(jsonDecode(requests.single.body), {
          'apparatus': _print8Id,
          'order_ids': requested,
          'moved_order_id': down ? ids.first : ids.last,
        });
        // No overlapping writes may undo the server-adjusted result.
        list.onReorderItem!(1, 0);
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        response.complete(http.Response(
            jsonEncode({
              'ok': scenario != 'rejected',
              if (scenario == 'rejected') 'error': 'queue_action_not_allowed',
              if (scenario != 'missing-result') 'order_ids': saved,
            }),
            scenario == 'rejected' ? 409 : 200));
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
        expect(displayed, saved);
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
                if (request.method == 'PUT' &&
                    request.url.path.endsWith('/production-maps/sequence')) {
                  requests.add(request);
                  return response.future;
                }
                return http.Response('{}', 200);
              }));
    });
  }

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
