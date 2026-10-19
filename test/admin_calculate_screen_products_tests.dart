part of 'admin_calculate_screen_test.dart';

const _mixedProducts = [
  OrderProduct(
      id: 'p1',
      itemCode: 'SKU-1',
      product: 'Normavitus',
      frameProductSizeMm: 115,
      frameCount: 1),
  OrderProduct(
      id: 'p2',
      itemCode: 'SKU-2',
      product: 'Baktronorm',
      frameProductSizeMm: 115,
      frameCount: 1),
  OrderProduct(
      id: 'p3',
      itemCode: 'SKU-3',
      product: 'Collagen',
      frameProductSizeMm: 80,
      frameCount: 2),
  OrderProduct(
      id: 'p4',
      itemCode: 'SKU-4',
      product: 'Minavitos',
      frameProductSizeMm: 85,
      frameCount: 2),
];

CalculateOrderTemplate _mixedTemplate() =>
    _template(itemCode: 'SKU-1').copyWith(
      products: _mixedProducts,
      frameProductSizeMm: 0,
      frameCount: 6,
      widthMm: 575,
      product: 'Normavitus + Baktronorm + Collagen + Minavitos',
    );

void _registerProductTests() {
  test(
      'multi-product template and map preserve ordered products through copies',
      () {
    final template = CalculateOrderTemplate.fromJson(_mixedTemplate().toJson())
        .copyWith(kg: 300);
    expect(template.products.map((p) => p.toJson()).toList(),
        _mixedProducts.map((p) => p.toJson()).toList());
    final map = _map(id: 'zakaz-multi', code: '1001', orderNumber: '1001')
        .copyWith(products: template.products, widthMm: 575);
    final restored =
        ProductionMapDefinition.fromJson(map.toJson()).copyWith(title: 'Mixed');
    expect(restored.layoutWidths, [115, 115, 80, 80, 85, 85]);
    final request = CalculateRequest(
        kg: 300,
        frameProductSizeMm: 0,
        frameCount: 6,
        products: template.products);
    expect(request.widthMm, 575);
    expect((request.toJson()['products'] as List).length, 4);
  });

  testWidgets('multi-product form restores products and keeps one common KG',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _pumpCalculateScreen(tester, template: _mixedTemplate());
    tester.view.physicalSize = const Size(430, 5000);
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('calculate-multiple-products'));
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(find.widgetWithText(TextFormField, 'Umumiy KG'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1 ta kadrning eni'),
        findsNWidgets(4));
    expect(find.text('Jami: 6 kadr · foydali en 560 mm'), findsOneWidget);
    await tester.tap(find.text('Mahsulot qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('5-mahsulot'), findsOneWidget);
    await tester.tap(find.byTooltip('Mahsulotni olib tashlash').last);
    await tester.pumpAndSettle();
    expect(find.text('5-mahsulot'), findsNothing);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'KG'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '1 ta kadrning eni'),
        findsNWidgets(4));
    expect(find.text('Jami: 6 kadr · foydali en 560 mm'), findsOneWidget);
  });

  testWidgets(
      'multi-product calculation uses rows when legacy product fields are empty',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _pumpCalculateScreen(tester,
        template: _mixedTemplate().copyWith(product: '', itemCode: ''));
    tester.view.physicalSize = const Size(430, 5000);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Umumiy KG'), '300');
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsOneWidget);
    await tester.tap(find.text('Mahsulot qo‘shish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'multi-product calculation becomes stale when any product changes',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _pumpCalculateScreen(tester, template: _mixedTemplate());
    tester.view.physicalSize = const Size(430, 5000);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Umumiy KG'), '300');
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, '1 ta kadrning eni').at(2), '90');
    await tester.pumpAndSettle();
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsNothing);
    expect(find.text('Jami: 6 kadr · foydali en 580 mm'), findsOneWidget);
  });
}
