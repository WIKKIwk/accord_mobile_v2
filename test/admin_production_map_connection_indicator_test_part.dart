part of 'admin_production_map_test_screen_test.dart';

Future<_AdminPagingHarness> _prepareConnectionIndicatorHarness() async {
  await TestModeController.instance.setEnabled(true);
  for (var index = 0; index < 45; index++) {
    final number = index.toString().padLeft(4, '0');
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: 'zakaz-indicator-$number',
      orderNumber: number,
      title: 'Indicator product $number',
      productCode: 'INDICATOR-$number',
      product: 'Indicator product $number',
      apparatusId: _print8Id,
    ));
  }
  final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
  final catalog = await MobileApi.instance.adminApparatus(limit: 200);
  return _AdminPagingHarness(
    snapshot.maps.toList()..sort((a, b) => a.map.id.compareTo(b.map.id)),
    snapshot,
    [catalog.firstWhere((a) => a.id == _print8Id)],
  );
}

Future<Completer<AdminProductionOrderPage?>> _startIndicatorPageRead(
  WidgetTester tester,
  _AdminPagingHarness harness,
) async {
  final pending = Completer<AdminProductionOrderPage?>();
  harness.nextRead = pending;
  final dynamic viewport = tester.widget(find
      .byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_AdminOrderPageViewport',
      )
      .hitTestable()
      .first);
  viewport.onMore();
  await tester.pump();
  expect(harness.nextRead, isNull, reason: 'The real page read has started');
  return pending;
}

Future<void> _finishIndicatorPageRead(
  WidgetTester tester,
  _AdminPagingHarness harness,
  Completer<AdminProductionOrderPage?> pending,
) async {
  pending.complete(await harness.read(harness.calls.last));
  await tester.pump();
  await tester.pump();
}

void _registerConnectionIndicatorTests() {
  final progress = find.byKey(
    const ValueKey('production-orders-connection-progress'),
  );

  testWidgets('connection indicator: fast page read never flashes',
      (tester) async {
    final harness = await _prepareConnectionIndicatorHarness();
    await harness.mount(tester);
    final pending = await _startIndicatorPageRead(tester, harness);
    expect(progress, findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(progress, findsNothing);
    await _finishIndicatorPageRead(tester, harness, pending);
    expect(_adminSequenceRowCount(tester), 40);
    await tester.pump(const Duration(milliseconds: 300));
    expect(progress, findsNothing, reason: 'Completed reads cancel the timer');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'connection indicator: slow read survives rebuild and hides immediately',
      (tester) async {
    final harness = await _prepareConnectionIndicatorHarness();
    await harness.mount(tester);
    final pending = await _startIndicatorPageRead(tester, harness);
    await tester.pump(const Duration(milliseconds: 150));
    tester
        .element(find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_AdminModulesBody',
        ))
        .markNeedsBuild();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 149));
    expect(progress, findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(progress, findsOneWidget,
        reason: 'A rebuild must not restart a continuous wait');
    expect(tester.widget<LinearProgressIndicator>(progress).value, isNull);
    expect(tester.widget<LinearProgressIndicator>(progress).semanticsLabel,
        isNotEmpty);
    await _finishIndicatorPageRead(tester, harness, pending);
    expect(progress, findsNothing,
        reason: 'There is no artificial minimum-visible loading interval');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection indicator: each new read receives its own delay',
      (tester) async {
    final harness = await _prepareConnectionIndicatorHarness();
    await harness.mount(tester);
    final first = await _startIndicatorPageRead(tester, harness);
    await tester.pump(const Duration(milliseconds: 300));
    expect(progress, findsOneWidget);
    await _finishIndicatorPageRead(tester, harness, first);
    expect(progress, findsNothing);
    final second = await _startIndicatorPageRead(tester, harness);
    await tester.pump(const Duration(milliseconds: 299));
    expect(progress, findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(progress, findsOneWidget);
    await _finishIndicatorPageRead(tester, harness, second);
    expect(_adminSequenceRowCount(tester), 45);
    expect(progress, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection indicator: disposal cancels a pending reveal',
      (tester) async {
    final harness = await _prepareConnectionIndicatorHarness();
    await harness.mount(tester);
    final pending = await _startIndicatorPageRead(tester, harness);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    expect(progress, findsNothing);
    expect(tester.takeException(), isNull);
    await _finishIndicatorPageRead(tester, harness, pending);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection indicator: initial loading uses the same delay',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
    final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    final pending = Completer<AdminApparatusQueueSnapshot>();
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
        apparatusLoader: () async => apparatus,
        queueSnapshotLoader: () => pending.future,
        completionRequestsLoader: () async => [],
        closedOrdersLoader: () async => [],
      ),
    ));
    await tester.pump();
    expect(progress, findsNothing);
    await tester.pump(const Duration(milliseconds: 299));
    expect(progress, findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(progress, findsOneWidget);
    pending.complete(snapshot);
    await tester.pumpAndSettle();
    expect(progress, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
