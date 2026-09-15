part of 'admin_calculate_screen_test.dart';

void _registerPendingOrderTests() {
  for (final form in ['rulon', 'paket']) {
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
      expect(find.text('№9011 · Order ochishni tugallash'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'KG'), findsNothing);
      expect(find.text('Ma’lumotlarni tahrirlash'), findsNothing);
      final fields =
          tester.widgetList<TextFormField>(find.byType(TextFormField));
      expect(
          fields.any((field) => ['500', '300', '2', 'Mahsulot', 'Mijoz']
              .contains(field.controller?.text)),
          isFalse);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Rang (ixtiyoriy)'), 'Qizil');
      await tester.ensureVisible(find.text('Davom etish'));
      await tester.tap(find.text('Davom etish'));
      await tester.pumpAndSettle();
      expect(find.text('MAP OPENED'), findsOneWidget);
      final context = arguments is ProductionMapTestArgs
          ? (arguments as ProductionMapTestArgs).orderContext!
          : arguments as ProductionMapOrderContext;
      expect(context.pendingOrderId, 'zakaz-9011');
      expect(context.templateDraft!.orderNumber, '9011');
      expect(context.templateDraft!.kg, 500);
      expect(context.templateDraft!.frameProductSizeMm, 300);
      expect(context.templateDraft!.frameCount, 2);
      expect(context.templateDraft!.status, form);
      expect(context.templateDraft!.color, 'Qizil');
      expect(context.templateDraft!.effectiveLayers.single.material, 'pet');
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
