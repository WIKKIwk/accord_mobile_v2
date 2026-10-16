part of 'inventory_movements_test.dart';

void _registerInventoryMaterialSheetLayoutTests() {
  const ids = ['apparatus:default:asset-005', 'apparatus:default:asset-007'];

  Future<List<AdminApparatus>> seedOrder() async {
    final catalog = await MobileApi.instance.adminApparatus(limit: 10000);
    for (final id in ids) {
      final apparatus = catalog.firstWhere((item) => item.id == id);
      await MobileApi.instance.adminSaveRawMaterialRule(
        apparatus: apparatus,
        currentRule: _testRawMaterialRule(apparatus),
        requiresMaterial: true,
        itemGroups: const ['Kraska'],
      );
    }
    await MobileApi.instance
        .adminSaveProductionMap(const ProductionMapDefinition(
      id: 'zakaz-sheet',
      code: 'Z-300',
      title: 'Tanlash',
      productCode: 'P-3',
      nodes: [
        ProductionMapNode(
            id: 'print',
            kind: 'apparatus',
            title: 'Bosma',
            apparatusId: 'apparatus:default:asset-005'),
        ProductionMapNode(
            id: 'laminate',
            kind: 'apparatus',
            title: 'Laminatsiya',
            apparatusId: 'apparatus:default:asset-007'),
      ],
      edges: [],
    ));
    return catalog;
  }

  Widget app({
    Widget home = const InventoryMovementsScreen(),
    double textScale = 1,
  }) =>
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.kalmar),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      );

  Future<void> openAsset(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.reset();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inventory-asset-card-raw:1')));
    await tester.pumpAndSettle();
  }

  testWidgets('material sheet actions are rounded, compact and evenly spaced',
      (tester) async {
    await seedOrder();
    await openAsset(tester);
    final assign =
        find.byKey(const ValueKey('raw-material-assign-order-button'));
    final relocate = find.widgetWithText(OutlinedButton, 'Joylashtirish');
    final transfer = find.widgetWithText(FilledButton, 'Transfer');
    final delete =
        find.byKey(const ValueKey('inventory-asset-delete-button-raw:1'));
    const shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)));
    for (final finder in [assign, relocate, transfer, delete]) {
      final button = tester.widget<ButtonStyleButton>(finder);
      expect(button.style?.shape?.resolve({}), shape);
      expect(tester.getSize(finder).height, 48);
    }
    expect(tester.getTopLeft(relocate).dy - tester.getBottomLeft(assign).dy, 8);
    expect(tester.getTopLeft(delete).dy - tester.getBottomLeft(relocate).dy, 8);
    expect(tester.getTopLeft(transfer).dx - tester.getTopRight(relocate).dx, 8);
    final deleteButton = tester.widget<OutlinedButton>(delete);
    final errorColor = Theme.of(tester.element(delete)).colorScheme.error;
    expect(deleteButton.style?.foregroundColor?.resolve({}), errorColor);
    expect(deleteButton.style?.side?.resolve({})?.color, errorColor);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'material sheet remains scrollable on a small screen with large text',
      (tester) async {
    await openAsset(tester, size: const Size(320, 640));
    final sheet = tester.widget(find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_InventoryAssetDetailsSheet'));
    // Exercise the sheet independently of the warehouse list's fixed rows.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(home: Scaffold(body: sheet), textScale: 1.5));
    await tester.pumpAndSettle();
    final delete =
        find.byKey(const ValueKey('inventory-asset-delete-button-raw:1'));
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    expect(tester.getSize(delete).height, greaterThanOrEqualTo(48));
    expect(delete.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final cancel in [true, false]) {
    testWidgets(
        'material apparatus picker is wide and searchable, cancel=$cancel',
        (tester) async {
      final catalog = await seedOrder();
      await openAsset(tester);
      await tester
          .tap(find.byKey(const ValueKey('raw-material-assign-order-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Z-300 · Tanlash'));
      await tester.pumpAndSettle();
      final picker =
          find.byKey(const ValueKey('raw-material-apparatus-picker'));
      expect(picker, findsOneWidget);
      expect(find.byType(SimpleDialog), findsNothing);
      expect(tester.getSize(picker).width, 390);
      for (final id in ids) {
        final label = find.text(canonicalApparatusDisplayLabel(id, catalog));
        expect(label, findsOneWidget);
        final row = find.ancestor(
            of: label, matching: find.byType(M3SegmentFilledSurface));
        expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
        expect(tester.getSize(row).width, greaterThanOrEqualTo(350));
      }
      if (cancel) {
        Navigator.of(tester.element(picker)).pop();
        await tester.pumpAndSettle();
        expect(
            (await MobileApi.instance.adminRawMaterialLookup(barcode: '30AA'))
                .assignment,
            isNull);
        expect(find.byKey(const ValueKey('raw-material-confirm-assignment')),
            findsNothing);
      } else {
        final selectedLabel = canonicalApparatusDisplayLabel(ids.last, catalog);
        await tester.enterText(
            find.descendant(of: picker, matching: find.byType(TextField)),
            selectedLabel);
        await tester.pumpAndSettle();
        expect(find.text(canonicalApparatusDisplayLabel(ids.first, catalog)),
            findsNothing);
        await tester
            .tap(find.widgetWithText(M3SegmentFilledSurface, selectedLabel));
        await tester.pumpAndSettle();
        expect(
            (await MobileApi.instance.adminRawMaterialLookup(barcode: '30AA'))
                .assignment,
            isNull);
        await tester
            .tap(find.byKey(const ValueKey('raw-material-confirm-assignment')));
        await tester.pumpAndSettle();
        final assignment =
            (await MobileApi.instance.adminRawMaterialLookup(barcode: '30AA'))
                .assignment;
        expect(assignment?.orderId, 'zakaz-sheet');
        expect(assignment?.apparatus, ids.last);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
