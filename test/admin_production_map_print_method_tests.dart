part of 'admin_production_map_test_screen_test.dart';

void _registerPrintMethodRoutingTests() {
  for (final form in ['rulon', 'paket']) {
    for (final method in ['flexo', 'metal']) {
      testWidgets(
          'print method $form $method filters picker and Skip candidates',
          (tester) async {
        await TestModeController.instance.setEnabled(true);
        await _usePhoneViewport(tester);
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapTestScreen(
            orderContext: ProductionMapOrderContext(
              orderName: 'Routing',
              productName: 'Display only',
              itemCode: 'ROUTING',
              rollCount: 7,
              widthMm: 650,
              templateDraft: CalculateOrderTemplate.fromJson({
                'status': form,
                'production_options': {
                  'print_method': method,
                  'cold_glue': false
                },
              }),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('admin-fab-menu-Laminatsiya')),
            findsOneWidget);
        expect(
            find.byKey(const ValueKey('admin-fab-menu-Rezka')), findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('admin-fab-menu-Bosma aparat')));
        await tester.pumpAndSettle();
        void expectCandidates() {
          expect(find.text('Flexo pechat'),
              method == 'flexo' ? findsOneWidget : findsNothing);
          for (final count in [7, 8]) {
            expect(find.text('$count ta rangli bosma aparat'),
                method == 'metal' ? findsOneWidget : findsNothing);
          }
          expect(find.text('9 ta rangli bosma aparat'), findsNothing,
              reason: 'existing width compatibility remains in force');
        }

        expectCandidates();
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expectCandidates();
        expect(tester.takeException(), isNull);
      });
    }
  }

  test('print method uses canonical technology and legacy status fallback', () {
    ProductionMapOrderContext context(String status, [String? method]) =>
        ProductionMapOrderContext(
          orderName: 'Flexo name is not routing',
          productName: 'Rulon display',
          itemCode: 'ROUTING',
          rollCount: 7,
          widthMm: 650,
          templateDraft: CalculateOrderTemplate.fromJson({
            'status': status,
            if (method != null)
              'production_options': {
                'print_method': method,
                'cold_glue': false
              },
          }),
        );
    const flexo = AdminApparatus(
        id: 'apparatus:test:opaque-a',
        name: 'Temir',
        operation: 'print',
        technology: 'flexographic',
        colorStations: 8);
    const metal = AdminApparatus(
        id: 'apparatus:test:opaque-b',
        name: 'Flexo',
        operation: 'print',
        technology: 'rotogravure',
        colorStations: 7);
    const wrongColors = AdminApparatus(
        id: 'apparatus:test:opaque-c',
        name: 'Bosma',
        operation: 'print',
        technology: 'rotogravure',
        colorStations: 6);
    for (final order in [context('Flexo'), context('paket', 'flexo')]) {
      expect(productionMapApparatusMatchesOrder(flexo, order), isTrue);
      expect(productionMapApparatusMatchesOrder(metal, order), isFalse);
    }
    for (final order in [
      context('Rulon'),
      context('paket'),
      context('Flexo', 'metal')
    ]) {
      expect(productionMapApparatusMatchesOrder(flexo, order), isFalse);
      expect(productionMapApparatusMatchesOrder(metal, order), isTrue);
      expect(productionMapApparatusMatchesOrder(wrongColors, order), isFalse);
    }
  });
}
