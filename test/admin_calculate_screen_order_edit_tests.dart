part of 'admin_calculate_screen_test.dart';

void _registerOpenedOrderEditTests() {
  testWidgets(
      'opened order edit preloads KG and exposes only update after fresh calculation',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    final template = _flexoTemplate()
        .copyWith(kg: 500, orderNumber: '1234', sourceMapId: 'zakaz-1234');
    final source = OpenedOrderEditSource.fromJson({
      'map': {'id': 'zakaz-1234'},
      'revision': 0,
      'template': template.toJson(),
    });
    await _pumpCalculateScreen(tester, openedOrder: source);
    tester.view.physicalSize = const Size(430, 3000);
    await tester.pumpAndSettle();
    final kg = find.widgetWithText(TextFormField, 'KG');
    expect(tester.widget<TextFormField>(kg).controller!.text, '500');
    expect(find.text('O‘zgarishlarni saqlash'), findsNothing);
    await _calculateFlexo(tester);
    expect(find.text('O‘zgarishlarni saqlash'), findsOneWidget);
    expect(find.text('Mapni ulash'), findsNothing);
    expect(find.text('Order ochish'), findsNothing);
    await tester.enterText(kg, '600');
    await tester.pumpAndSettle();
    expect(find.text('O‘zgarishlarni saqlash'), findsNothing);
    await _calculateFlexo(tester);
    final submittedKg = tester.widget<TextFormField>(kg).controller!.text;
    await tester.ensureVisible(find.text('O‘zgarishlarni saqlash'));
    await tester.tap(find.text('O‘zgarishlarni saqlash'));
    await tester.pumpAndSettle();
    // Test mode cannot bypass the authoritative server gate.
    expect(
        find.text('Order tahriri uchun server tekshiruvi kerak'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Saqlash tasdiqlanmadi'), findsOneWidget);
    expect(find.text('Buyurtma №1234'), findsOneWidget);
    await tester.tap(find.text('Tushunarli'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(kg).controller!.text, submittedKg);
    expect(find.byType(AdminCalculateScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
