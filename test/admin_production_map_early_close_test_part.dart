part of 'admin_production_map_test_screen_test.dart';

void _registerEarlyCloseMenuTests() {
  for (final scenario in [
    (tab: 'Buyurtmalar', archiveReadFails: false),
    (tab: 'Ketma-ketlik', archiveReadFails: false),
    (tab: 'Ketma-ketlik', archiveReadFails: true),
  ]) {
  final tab = scenario.tab;
  testWidgets('early close from $tab handles immutable API sequences and preserves closed history (archive read fails: ${scenario.archiveReadFails})', (tester) async {
    await TestModeController.instance.setEnabled(true);
    const id = 'zakaz-0009';
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: id, orderNumber: '0009', title: 'Erta yopish testi',
      productCode: 'EARLY', product: 'EARLY', apparatusId: _print8Id,
    ));
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    final initial = await MobileApi.instance.adminProductionMapQueueSnapshot();
    final maps = await MobileApi.instance.adminProductionMaps();
    var closed = false;
    var archiveReadFails = scenario.archiveReadFails;
    final posts = <http.Request>[];
    final archived = AdminClosedProductionOrder.fromJson({
      'order_id': id, 'order_number': '0009', 'title': 'Erta yopish testi',
      'closed_by_role': 'admin', 'closed_by_display_name': 'Admin',
      'completed_at_unix': 123, 'logs': [], 'progress_batches': [],
      'early_close': {'comment': 'Mijoz rad etdi', 'closed_at_unix': 123},
    });
    AdminApparatusQueueSnapshot snapshot() => AdminApparatusQueueSnapshot(
      maps: List.unmodifiable(maps), revision: closed ? 2 : 1,
      sequences: MobileApi.instance.parseApparatusSequenceMap({
        for (final entry in initial.sequences.entries)
          entry.key: [for (final value in entry.value) if (!closed || value != id) value],
        _print9Id: <String>[],
      }),
      visibleOrderIds: {for (final entry in initial.visibleOrderIds.entries)
        entry.key: [for (final value in entry.value) if (!closed || value != id) value]},
      queueStates: initial.queueStates, queuePolicies: initial.queuePolicies,
      queueActionControls: initial.queueActionControls,
      stageStates: initial.stageStates,
      orderControls: {...initial.orderControls, if (closed) id: AdminOrderControlState.frozen},
      earlyClosingOrderIds: {if (closed) id},
      orderStatuses: {id: AdminProductionOrderStatusDetail(
        lifecycleStatus: closed ? 'cancelled' : 'released', orderStatus: 'not_started')},
    );
    await _usePhoneViewport(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
          apparatusLoader: () async => catalog.where((item) => item.id == _print8Id).toList(),
          queueSnapshotLoader: () async => snapshot(),
          closedOrdersLoader: () async {
            if (closed && archiveReadFails) throw TimeoutException('offline');
            return [if (closed) archived];
          },
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final order = find.byKey(ValueKey(tab == 'Buyurtmalar'
          ? 'opened-order-$id' : 'sequence-row-$_print8Id-$id'));
      await tester.ensureVisible(order);
      await tester.longPress(order);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orderni muammo bilan erta yopish'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('early-close-comment')), 'Mijoz rad etdi');
      await tester.pump();
      await TestModeController.instance.setEnabled(false);
      await tester.tap(find.text('Yopish'));
      await tester.pumpAndSettle();
      expect(posts, hasLength(1));
      expect(jsonDecode(posts.single.body), {'order_id': id, 'action': 'close_early', 'comment': 'Mijoz rad etdi'});
      expect(find.text('Buyurtma yopilmadi'), findsNothing);
      expect(find.text('Buyurtma erta yopildi. Tarix Yopilganlar bo‘limida saqlandi.'), findsOneWidget);
      if (archiveReadFails) {
        expect(find.text('Yopilgan orderlar yuklanmadi'), findsOneWidget);
        archiveReadFails = false;
      }
      expect(order, findsNothing);
      expect(find.textContaining('muzlatib bo‘lmaydi'), findsNothing);
      await tester.tap(find.text('Ketma-ketlik'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sequence-row-$_print8Id-$id')), findsNothing);
      await tester.tap(find.text('Yopilgan'));
      await tester.pumpAndSettle();
      expect(find.text('Yopilgan orderlar yuklanmadi'), findsNothing);
      expect(posts, hasLength(1)); // Retrying a read must not repeat closure.
      expect(find.textContaining('Erta yopish testi'), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Order muammo bilan erta yopildi'), findsOneWidget);
      expect(find.textContaining('Sabab: Mijoz rad etdi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6)); // dismiss the success notice
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/order-control')) {
        posts.add(request);
        closed = true;
        return http.Response(jsonEncode({'ok': true, 'control': {
          'state': 'frozen', 'early_close': {'comment': 'Mijoz rad etdi', 'closed_at_unix': 123},
        }}), 200);
      }
      return http.Response('{"completion_requests":[]}', 200);
    }));
  });
  }

  for (final tab in ['Buyurtmalar', 'Ketma-ketlik']) {
    testWidgets('early close long press is available in $tab', (tester) async {
      await TestModeController.instance.setEnabled(true);
      const id = 'zakaz-0001';
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: id, orderNumber: '0001', title: 'Erta yopish testi',
        productCode: 'EARLY', product: 'EARLY', apparatusId: _print8Id,
      ));
      final catalog = await MobileApi.instance.adminApparatus(limit: 200);
      final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
          apparatusLoader: () async => catalog.where((item) => item.id == _print8Id).toList(),
          queueSnapshotLoader: () async => snapshot,
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final order = find.byKey(ValueKey(tab == 'Buyurtmalar'
          ? 'opened-order-$id' : 'sequence-row-$_print8Id-$id'));
      expect(order, findsOneWidget);
      await tester.longPress(order);
      await tester.pumpAndSettle();
      expect(find.text('Orderni muammo bilan erta yopish'), findsOneWidget);
      await tester.tap(find.text('Orderni muammo bilan erta yopish'));
      await tester.pumpAndSettle();
      expect(find.text('Qanday sabab bilan yopyapsiz?'), findsOneWidget);
      expect(find.byKey(const ValueKey('early-close-comment')), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(order, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
