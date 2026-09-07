part of 'admin_calculate_screen_test.dart';

CalculateOrderTemplate _flexoTemplate({String sourceMapId = ''}) =>
    _template(itemCode: 'ITEM-FLEXO', sourceMapId: sourceMapId).copyWith(
      status: 'Flexo',
      frameProductSizeMm: 250,
      frameCount: 3,
      edgeAllowanceMm: 40,
      widthMm: 790,
    );

Finder _flexoField() =>
    find.widgetWithText(TextFormField, 'Qo‘shimcha uzunlik');

Future<void> _pumpFlexoScreen(
  WidgetTester tester, {
  CalculateOrderTemplate? template,
  bool edit = false,
  ValueChanged<Object?>? onProductionMapArguments,
}) async {
  await TestModeController.instance.setEnabled(true);
  resetMobileApiTestModeData();
  await _pumpCalculateScreen(tester,
      template: template ?? _flexoTemplate(),
      onProductionMapArguments: onProductionMapArguments);
  tester.view.physicalSize = const Size(430, 3000);
  await tester.pumpAndSettle();
  if (edit) {
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
  }
}

Future<void> _pickFlexoOrderType(WidgetTester tester, String value) async {
  final picker = find.text('Buyurtma turi');
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, value));
  await tester.pumpAndSettle();
}

Future<void> _calculateFlexo(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'KG'), '120');
  await tester.ensureVisible(find.text('Hisoblash'));
  await tester.tap(find.text('Hisoblash'));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void _registerFlexoTests() {
  testWidgets('Flexo option shows a required nonnegative additional length',
      (tester) async {
    await _pumpFlexoScreen(tester,
        template: _flexoTemplate().copyWith(status: 'Paket'), edit: true);
    expect(_flexoField(), findsNothing);
    await _pickFlexoOrderType(tester, 'Flexo');
    final field = tester.widget<TextFormField>(_flexoField());
    expect(field.controller!.text, isEmpty);
    for (final invalid in ['', '-1', 'NaN', 'Infinity', 'abc']) {
      expect(field.validator!(invalid), isNotNull, reason: invalid);
    }
    for (final valid in ['0', '40', '40,5', '125.75']) {
      expect(field.validator!(valid), isNull, reason: valid);
    }
    await _calculateFlexo(tester);
    expect(find.text('Mapni ulash'), findsNothing);
    expect(find.text('Majburiy'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  for (final allowance in ['0', '40', '40,5']) {
    testWidgets('Flexo $allowance mm reaches calculation and map draft',
        (tester) async {
      Object? openedArgs;
      await _pumpFlexoScreen(tester,
          edit: true, onProductionMapArguments: (args) => openedArgs = args);
      await tester.enterText(_flexoField(), allowance);
      await _calculateFlexo(tester);
      final extra = double.parse(allowance.replaceAll(',', '.'));
      final width = 750 + extra;
      expect(find.text('Mapni ulash'), findsOneWidget);
      await tester.ensureVisible(find.text('Mapni ulash'));
      await tester.tap(find.text('Mapni ulash'));
      await tester.pumpAndSettle();
      final context = (openedArgs as ProductionMapTestArgs).orderContext!;
      expect(context.widthMm, width);
      final template =
          CalculateOrderTemplate.fromJson(context.templateDraft!.toJson());
      expect(template.status, 'Flexo');
      expect(template.edgeAllowanceMm, extra);
      expect(template.widthMm, width);
      expect(template.frameProductSizeMm, 250);
      expect(template.frameCount, 3);
    });
  }

  for (final regularType in ['Paket', 'Rulon']) {
    testWidgets(
        'Flexo switching to $regularType restores 15 mm and recalculates',
        (tester) async {
      Object? openedArgs;
      await _pumpFlexoScreen(tester,
          edit: true, onProductionMapArguments: (args) => openedArgs = args);
      await _calculateFlexo(tester);
      expect(find.text('Mapni ulash'), findsOneWidget);
      await _pickFlexoOrderType(tester, regularType);
      expect(_flexoField(), findsNothing);
      expect(find.text('Mapni ulash'), findsNothing);
      await _calculateFlexo(tester);
      await tester.ensureVisible(find.text('Mapni ulash'));
      await tester.tap(find.text('Mapni ulash'));
      await tester.pumpAndSettle();
      final context = (openedArgs as ProductionMapTestArgs).orderContext!;
      expect(context.widthMm, 765);
      expect(context.templateDraft!.status, regularType);
      expect(context.templateDraft!.edgeAllowanceMm, 15);
    });
  }

  testWidgets('Flexo restored value invalidates old calculation on edits',
      (tester) async {
    await _pumpFlexoScreen(tester);
    expect(tester.widget<TextFormField>(_flexoField()).controller!.text, '40');
    await _calculateFlexo(tester);
    expect(find.text('Tayyor mahsulot GSM'), findsOneWidget);
    await tester.enterText(_flexoField(), '55');
    await tester.pumpAndSettle();
    expect(find.text('Tayyor mahsulot GSM'), findsNothing);
    await tester.enterText(_flexoField(), '');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _calculateFlexo(tester);
    expect(find.text('Tayyor mahsulot GSM'), findsNothing);
    await tester.enterText(_flexoField(), '0');
    await _calculateFlexo(tester);
    expect(find.text('Tayyor mahsulot GSM'), findsOneWidget);
    expect(find.text('750 mm'), findsWidgets);
  });

  testWidgets('Flexo saved order and quick template retain custom allowance',
      (tester) async {
    const sourceMapId = 'zakaz-flexo-template';
    final template = _flexoTemplate(sourceMapId: sourceMapId);
    await _pumpFlexoScreen(tester, template: template);
    await MobileApi.instance.adminSaveProductionMap(
        _map(id: sourceMapId, code: '4400', orderNumber: '4400'));
    await tester.enterText(_flexoField(), '55');
    await _calculateFlexo(tester);
    await tester.ensureVisible(find.text('Zakaz ochish'));
    await tester.tap(find.text('Zakaz ochish'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('production-map-order-confirm')));
    await tester.pumpAndSettle();

    final maps = await MobileApi.instance.adminProductionMaps();
    final opened = maps.singleWhere((item) => item.map.id != sourceMapId).map;
    expect(opened.widthMm, 805);
    expect(opened.baseLength, 3500);
    final templates = await MobileApi.instance.calculateOrderTemplates();
    final quick = templates.singleWhere((t) => t.orderNumber.isEmpty);
    expect(quick.status, 'Flexo');
    expect(quick.edgeAllowanceMm, 55);
    expect(quick.widthMm, 805);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpCalculateScreen(tester,
        template: CalculateOrderTemplate.fromJson(quick.toJson()));
    await tester.scrollUntilVisible(_flexoField(), 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextFormField>(_flexoField()).controller!.text, '55');
  });
}
