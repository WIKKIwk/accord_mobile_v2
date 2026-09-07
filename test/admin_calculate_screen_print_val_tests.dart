part of 'admin_calculate_screen_test.dart';

CalculateOrderTemplate _valTemplate() =>
    _template(itemCode: 'ITEM-VAL').copyWith(
      frameProductSizeMm: 320,
      frameCount: 2,
      widthMm: 655,
      printValSizeMm: 850,
    );

void _registerPrintValTests() {
  const nineColor = AdminApparatus(
    id: 'apparatus:default:bosma_9',
    name: '9 ta rangli bosma',
    operation: 'print',
    technology: 'rotogravure',
    colorStations: 9,
    minWebWidthMm: 800,
    maxWebWidthMm: 1350,
  );

  ProductionMapOrderContext contextFor(CalculateOrderTemplate template) =>
      ProductionMapOrderContext(
        orderName: template.name,
        productName: template.product,
        itemCode: template.itemCode,
        widthMm: template.widthMm,
        rollCount: template.rollCount,
        printValSizeMm: template.printValSizeMm,
        templateDraft: template,
      );

  test('print val survives JSON and can be cleared without changing frames',
      () {
    final template = CalculateOrderTemplate.fromJson(_valTemplate().toJson());
    expect(template.printValSizeMm, 850);
    expect(template.frameProductSizeMm, 320);
    expect(template.frameCount, 2);
    expect(template.widthMm, 655);
    expect(template.copyWith(name: 'Renamed').printValSizeMm, 850);
    final off = template.copyWith(clearPrintValSize: true);
    expect(off.toJson().containsKey('print_val_size_mm'), isFalse);
    expect(off.frameProductSizeMm, 320);
    expect(off.frameCount, 2);
    expect(off.widthMm, 655);

    final map = ProductionMapDefinition.fromJson(
      _map(id: 'zakaz-val', code: '8500', orderNumber: '8500')
          .copyWith(widthMm: 655, printValSizeMm: 850)
          .toJson(),
    );
    expect(map.widthMm, 655);
    expect(map.printCompatibilityWidthMm, 850);
    expect(map.copyWith(title: 'Renamed').printValSizeMm, 850);
    final cleared = map.copyWith(clearPrintValSize: true);
    expect(cleared.printCompatibilityWidthMm, 655);
    expect(cleared.toJson().containsKey('print_val_size_mm'), isFalse);
    expect(ProductionMapDefinition.fromJson(cleared.toJson()).printValSizeMm,
        isNull);
  });

  test('850 val enables nine-color print for 320 x 2 without bypassing limits',
      () {
    expect(
        productionMapApparatusMatchesOrder(
            nineColor, contextFor(_valTemplate())),
        isTrue);
    expect(
        productionMapApparatusMatchesOrder(
          nineColor,
          contextFor(_valTemplate().copyWith(clearPrintValSize: true)),
        ),
        isFalse);
    for (final invalid in [
      _valTemplate().copyWith(printValSizeMm: 700),
      _valTemplate().copyWith(printValSizeMm: 1400),
      _valTemplate().copyWith(rollCount: 10),
    ]) {
      expect(productionMapApparatusMatchesOrder(nineColor, contextFor(invalid)),
          isFalse);
    }
  });

  test('print val does not change lamination width or Rezka frames', () {
    const laminate = AdminApparatus(
        id: 'apparatus:test:laminate',
        name: 'Laminatsiya',
        operation: 'laminate');
    const rezka = AdminApparatus(
        id: 'apparatus:test:cut', name: 'Rezka', operation: 'cut');
    expect(
        productionMapApparatusMatchesOrder(
          laminate,
          contextFor(_valTemplate().copyWith(printValSizeMm: 1300)),
        ),
        isTrue);
    expect(
        productionMapApparatusMatchesOrder(
          laminate,
          contextFor(_valTemplate().copyWith(widthMm: 1200)),
        ),
        isFalse);
    expect(
        productionMapApparatusMatchesOrder(rezka, contextFor(_valTemplate())),
        isTrue);
  });

  test(
      'test-mode save persists val and clearing it preserves the two Rezka frames',
      () async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    final source = _map(id: 'zakaz-val', code: '8500', orderNumber: '8500');
    final map = source.copyWith(widthMm: 655, nodes: [
      source.nodes.first,
      const ProductionMapNode(
          id: 'rezka',
          kind: 'apparatus',
          apparatusId: 'apparatus:default:asset-010',
          title: 'Rezka',
          rezkaKadrCount: 4),
      ...source.nodes.skip(1),
    ]);
    final saved = await MobileApi.instance
        .adminSaveProductionMapWithOrder(map: map, template: _valTemplate());
    expect(saved.saved.map.printValSizeMm, 850);
    expect(saved.saved.map.widthMm, 655);
    expect(
        saved.saved.map.nodes
            .firstWhere((node) => node.id == 'rezka')
            .rezkaKadrCount,
        2);
    expect(saved.template?.frameProductSizeMm, 320);
    expect(saved.template?.frameCount, 2);
    expect(saved.template?.printValSizeMm, 850);
    final off = await MobileApi.instance.adminSaveProductionMapWithOrder(
      map: saved.saved.map,
      template: _valTemplate().copyWith(clearPrintValSize: true),
    );
    expect(off.saved.map.printValSizeMm, isNull);
    expect(off.saved.map.widthMm, 655);
    expect(
        off.saved.map.nodes
            .firstWhere((node) => node.id == 'rezka')
            .rezkaKadrCount,
        2);
  });

  testWidgets('val switch shows required field and restores saved value',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _pumpCalculateScreen(tester, template: _valTemplate());
    final toggle = find.byKey(const ValueKey('calculate-by-val'));
    await tester.scrollUntilVisible(toggle, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    final field = find.widgetWithText(TextFormField, 'Val razmeri');
    expect(tester.widget<TextFormField>(field).controller!.text, '850');
    final validate = tester.widget<TextFormField>(field).validator!;
    expect(validate(''), isNotNull);
    expect(validate('0'), isNotNull);
    expect(validate('NaN'), isNotNull);
    expect(validate('Infinity'), isNotNull);
    expect(validate('850'), isNull);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(field, findsNothing);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).controller!.text, '850');
  });

  for (final byVal in [true, false]) {
    testWidgets('map receives original frames with val switch $byVal',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      Object? openedArgs;
      await _pumpCalculateScreen(tester,
          template: _valTemplate(),
          onProductionMapArguments: (arguments) => openedArgs = arguments);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('calculate-by-val'));
      await tester.scrollUntilVisible(toggle, 200,
          scrollable: find.byType(Scrollable).first);
      if (!byVal) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.widgetWithText(TextFormField, 'KG'), '120');
      await tester.scrollUntilVisible(find.text('Hisoblash'), 240,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Hisoblash'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Mapni ulash'), 240,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Mapni ulash'));
      await tester.pumpAndSettle();
      expect(openedArgs, isA<ProductionMapTestArgs>());
      final context = (openedArgs as ProductionMapTestArgs).orderContext!;
      expect(context.widthMm, 655);
      expect(context.printValSizeMm, byVal ? 850 : isNull);
      expect(context.templateDraft!.printValSizeMm, byVal ? 850 : isNull);
      expect(context.templateDraft!.frameProductSizeMm, 320);
      expect(context.templateDraft!.frameCount, 2);
      expect(productionMapApparatusMatchesOrder(nineColor, context), byVal);
    });
  }
}
