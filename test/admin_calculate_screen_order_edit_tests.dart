part of 'admin_calculate_screen_test.dart';

void _registerOpenedOrderEditTests() {
  for (final unresolved in [false, true]) {
    testWidgets('opened order material locks protect assigned layers (unresolved=$unresolved)',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      resetMobileApiTestModeData();
      final template = _flexoTemplate().copyWith(
          kg: 500, product: 'Product', orderNumber: '1234', sourceMapId: 'zakaz-1234');
      final source = OpenedOrderEditSource.fromJson({
        'map': {'id': 'zakaz-1234'},
        'revision': 0,
        'template': template.toJson(),
        'restrictions': {
          'locked_layer_indices': unresolved ? [0, 1] : [0],
          'dimensions_locked': true,
          'layer_structure_locked': true,
          'unresolved_materials': unresolved,
        },
      });
      await _pumpCalculateScreen(tester, openedOrder: source);
      tester.view.physicalSize = const Size(430, 3000);
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('calculate-layer-micron-0'));
      final second = find.byKey(const ValueKey('calculate-layer-micron-1'));
      expect(tester.widget<TextFormField>(first).enabled, isFalse);
      expect(tester.widget<TextFormField>(second).enabled, !unresolved);
      final lockedPicker = find.ancestor(of: find.text('pet'), matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(lockedPicker).onTap, isNull);
      final edge = find.descendant(
          of: find.byKey(const ValueKey('calculate-edge-allowance')),
          matching: find.byType(TextFormField));
      expect(tester.widget<TextFormField>(edge).enabled, isFalse);
      for (final value in ['250', '3']) {
        final field = find.byWidgetPredicate((widget) =>
            widget is TextFormField && widget.controller?.text == value);
        expect(tester.widget<TextFormField>(field).enabled, isFalse);
      }
      final multiple = find.byKey(const ValueKey('calculate-multiple-products'));
      expect(tester.widget<SwitchListTile>(multiple).onChanged, isNull);
      final addLayer = find.widgetWithIcon(FilledButton, Icons.add_rounded);
      expect(tester.widget<FilledButton>(addLayer).onPressed, isNull);
      expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
      if (!unresolved) {
        await tester.enterText(second, '45');
        expect(tester.widget<TextFormField>(second).controller!.text, '45');
      }
      final kg = find.widgetWithText(TextFormField, 'KG');
      expect(tester.widget<TextFormField>(kg).enabled, isTrue);
      await tester.enterText(kg, '600');
      expect(tester.widget<TextFormField>(kg).controller!.text, '600');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('opened order material locks preserve multi-product dimensions',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    final template = _mixedTemplate().copyWith(
        kg: 500, orderNumber: '1234', sourceMapId: 'zakaz-1234');
    final source = OpenedOrderEditSource.fromJson({
      'map': {'id': 'zakaz-1234'},
      'revision': 0,
      'template': template.toJson(),
      'restrictions': {
        'locked_layer_indices': [0],
        'dimensions_locked': true,
        'layer_structure_locked': true,
        'unresolved_materials': false,
      },
    });
    await _pumpCalculateScreen(tester, openedOrder: source);
    tester.view.physicalSize = const Size(430, 5000);
    await tester.pumpAndSettle();
    final widths = find.widgetWithText(TextFormField, '1 ta kadrning eni');
    expect(widths, findsNWidgets(4));
    for (final field in tester.widgetList<TextFormField>(widths)) {
      expect(field.enabled, isFalse);
    }
    final add = find.widgetWithText(OutlinedButton, 'Mahsulot qo‘shish');
    expect(tester.widget<OutlinedButton>(add).onPressed, isNull);
    for (final field in tester.widgetList<IconButton>(
        find.byWidgetPredicate((widget) => widget is IconButton &&
            widget.tooltip == 'Mahsulotni olib tashlash'))) {
      expect(field.onPressed, isNull);
    }
    expect(tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Umumiy KG')).enabled, isTrue);
    expect(tester.widget<TextFormField>(
        find.byKey(const ValueKey('calculate-layer-micron-1'))).enabled, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
