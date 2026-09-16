part of 'admin_calculate_screen_test.dart';

void _registerPendingOrderTests() {
  testWidgets(
      'Telegram Paket Flexo keeps product form, allowance and routing through normal editor',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    final template = _flexoTemplate().copyWith(
      status: 'paket',
      orderNumber: '9011',
      kg: 500,
      productionOptions: const CalculateOrderProductionOptions(
          printMethod: 'flexo', coldGlue: true, diameterMm: 45.5),
    );
    Object? args;
    await _pumpCalculateScreen(tester,
        template: template,
        pendingOrderId: 'zakaz-9011',
        onProductionMapArguments: (value) => args = value);
    tester.view.physicalSize = const Size(430, 3000);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_flexoField()).controller!.text, '40');
    await _calculateFlexo(tester);
    await tester.ensureVisible(find.text('Mapni ulash'));
    await tester.tap(find.text('Mapni ulash'));
    await tester.pumpAndSettle();
    final draft = (args as ProductionMapTestArgs).orderContext!.templateDraft!;
    expect(draft.status, 'paket');
    expect(draft.edgeAllowanceMm, 40);
    expect(draft.productionOptions!.toJson(),
        template.productionOptions!.toJson());
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final form in ['rulon', 'paket', 'flexo']) {
    testWidgets(
        'pending $form completion preserves Telegram fields and order number',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      resetMobileApiTestModeData();
      final template = CalculateOrderTemplate.fromJson({
        'order_number': '9011',
        'customer_ref': 'CUST-1',
        'customer': 'Mijoz',
        'item_code': 'ITEM-1',
        'product': 'Mahsulot',
        'status': form,
        'kg': 500,
        'frame_product_size_mm': 300,
        'frame_count': 2,
        'edge_allowance_mm': form == 'flexo' ? 40 : 15,
        'waste_percent': 5,
        'layers': [
          {'material': 'pet', 'micron': '12'}
        ],
      });
      Object? arguments;
      await _pumpCalculateScreen(tester,
          template: template,
          pendingOrderId: 'zakaz-9011',
          onProductionMapArguments: (value) => arguments = value);
      tester.view.physicalSize = const Size(430, 3000);
      await tester.pumpAndSettle();
      expect(find.text('№9011 · Order ochishni tugallash'), findsNothing);
      expect(find.text('Buyurtma turi'), findsOneWidget);
      expect(find.text('Mijoz'), findsWidgets);
      expect(find.text('Mahsulot'), findsWidgets);
      expect(find.text('Davom etish'), findsNothing);
      expect(find.text('Rang (ixtiyoriy)'), findsNothing);
      final kgField = find.widgetWithText(TextFormField, 'KG');
      expect(tester.widget<TextFormField>(kgField).controller!.text, '500');
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
      for (final value in ['300', '2', '12']) {
        expect(fields.any((field) => field.controller?.text == value), isTrue);
      }
      if (form == 'flexo') {
        expect(tester.widget<TextFormField>(_flexoField()).controller!.text, '40');
        await tester.enterText(_flexoField(), '');
        await tester.tap(find.text('Hisoblash'));
        await tester.pumpAndSettle();
        expect(find.text('Majburiy'), findsWidgets);
        expect(find.text('Mapni ulash'), findsNothing);
        expect(arguments, isNull);
        await tester.enterText(_flexoField(), '55');
      } else {
        expect(_flexoField(), findsNothing);
      }
      await tester.enterText(kgField, '600');
      expect(find.text('Mapni ulash'), findsNothing);
      await tester.ensureVisible(find.text('Hisoblash'));
      await tester.tap(find.text('Hisoblash'));
      await tester.pumpAndSettle();
      expect(arguments, isNull,
          reason: 'calculation must show the normal result first');
      expect(find.text('Tayyor mahsulot GSM'), findsOneWidget);
      await tester.ensureVisible(find.text('Mapni ulash'));
      await tester.tap(find.text('Mapni ulash'));
      await tester.pumpAndSettle();
      expect(find.text('MAP OPENED'), findsOneWidget);
      final context = arguments is ProductionMapTestArgs
          ? (arguments as ProductionMapTestArgs).orderContext!
          : arguments as ProductionMapOrderContext;
      expect(context.pendingOrderId, 'zakaz-9011');
      expect(context.templateDraft!.orderNumber, '9011');
      expect(context.templateDraft!.kg, 600);
      expect(context.templateDraft!.frameProductSizeMm, 300);
      expect(context.templateDraft!.frameCount, 2);
      expect(context.templateDraft!.status, form == 'flexo' ? 'Rulon' : form);
      expect(context.templateDraft!.productionOptions!.printMethod,
          form == 'flexo' ? 'flexo' : 'metal');
      expect(context.templateDraft!.color, isEmpty);
      expect(context.templateDraft!.edgeAllowanceMm, form == 'flexo' ? 55 : 15);
      expect(context.widthMm, form == 'flexo' ? 655 : 615);
      expect(context.templateDraft!.effectiveLayers.single.material, 'pet');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
