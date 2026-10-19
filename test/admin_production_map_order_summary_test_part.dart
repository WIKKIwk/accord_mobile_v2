part of 'admin_production_map_test_screen_test.dart';

CalculateOrderTemplate _summaryCalculation({bool multipleProducts = false}) =>
    CalculateOrderTemplate.fromJson({
      'id': 'summary-calculation',
      'source_map_id': 'zakaz-summary',
      'order_number': '0309',
      'code': '0309',
      'item_code': 'SUMMARY-1',
      'product': 'Summary product',
      'frame_product_size_mm': 200,
      'frame_count': 2,
      'width_mm': 415,
      'kg': 400,
      'waste_percent': 5,
      'note': 'Qatlamlar tartibi saqlansin',
      'layers': [
        {'material': 'PET', 'micron': '12'},
        {'material': 'BOPP', 'micron': '20'},
        {'material': 'PE', 'micron': '40'},
        {'material': 'CPP', 'micron': '25'},
      ],
      if (multipleProducts)
        'products': [
          {
            'id': 'p1',
            'item_code': 'SKU-A',
            'product': 'First product',
            'frame_product_size_mm': 80,
            'frame_count': 2
          },
          {
            'id': 'p2',
            'item_code': 'SKU-B',
            'product': 'Second product',
            'frame_product_size_mm': 120,
            'frame_count': 2
          },
        ],
    });

Future<void> _openExpectedOrderSummary(WidgetTester tester) async {
  await MobileApi.instance.adminSaveProductionMap(
    _productionOrderMap(
      id: 'zakaz-summary',
      title: 'Summary product',
      productCode: 'SUMMARY-1',
      apparatusId: _godexId,
      apparatusName: 'Paynet',
      product: 'Summary product',
      orderNumber: '0309',
      rollCount: 5,
      widthMm: 415,
    ).copyWith(orderKg: 400, baseLength: 18000),
  );
  await _usePhoneViewport(tester);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AdminProductionMapOrdersScreen(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(
    const ValueKey('sequence-row-apparatus:test:godex-demo-zakaz-summary'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kutilayotgan buyurtma ko‘rsatkichlari'));
  await tester.pumpAndSettle();
}

void _registerOrderSummaryTests() {
  testWidgets(
      'admin expected summary shows all material layers and frame dimensions',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance
        .upsertCalculateOrderTemplate(_summaryCalculation());
    await _openExpectedOrderSummary(tester);
    expect(find.text('18000 metr'), findsOneWidget);
    expect(find.text('400 kg'), findsOneWidget);
    final details =
        find.byKey(const ValueKey('production-order-calculation-details'));
    for (final value in [
      '415 mm',
      '2 ta',
      '200 mm',
      '5 %',
      'PET · 12 mikron',
      'BOPP · 20 mikron',
      'PE · 40 mikron',
      'CPP · 25 mikron',
      '4-qatlam',
      'Qatlamlar tartibi saqlansin'
    ]) {
      expect(find.descendant(of: details, matching: find.text(value)),
          findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'admin expected summary preserves different frame widths per product',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _summaryCalculation(multipleProducts: true),
    );
    await _openExpectedOrderSummary(tester);
    expect(find.text('4 ta'), findsOneWidget);
    expect(find.text('First product'), findsOneWidget);
    expect(find.text('SKU-A · 2 ta kadr × 80 mm'), findsOneWidget);
    expect(find.text('Second product'), findsOneWidget);
    expect(find.text('SKU-B · 2 ta kadr × 120 mm'), findsOneWidget);
    expect(find.text('Bitta kadr eni'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'admin expected summary retries missing saved calculation without guessing materials',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    // Another order's recipe for this product must not be shown.
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _summaryCalculation()
          .copyWith(sourceMapId: 'zakaz-other', orderNumber: '9999'),
    );
    await _openExpectedOrderSummary(tester);
    expect(find.text('18000 metr'), findsOneWidget);
    expect(find.text('PET · 12 mikron'), findsNothing);
    final retry = find.widgetWithText(TextButton, 'Qayta yuklash');
    expect(retry, findsOneWidget);
    await MobileApi.instance
        .upsertCalculateOrderTemplate(_summaryCalculation());
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('PET · 12 mikron'), findsOneWidget);
    expect(retry, findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
