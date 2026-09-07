part of 'admin_calculate_screen_test.dart';

void _registerWasteTests() {
  for (final scenario in [(0.0, 17000.0), (11.0, 19500.0)]) {
    final (wastePercent, expectedMeters) = scenario;
    testWidgets(
      'opened order info retains calculated meters with $wastePercent percent waste',
      (tester) async {
        await TestModeController.instance.setEnabled(true);
        resetMobileApiTestModeData();
        const sourceMapId = 'template-waste-order';
        final template = _template(
          itemCode: 'ITEM-1',
          sourceMapId: sourceMapId,
        ).copyWith(wastePercent: wastePercent);
        await MobileApi.instance.adminSaveProductionMap(
          _map(id: sourceMapId, code: '', orderNumber: ''),
        );
        await _pumpCalculateScreen(tester, template: template);
        tester.view.physicalSize = const Size(430, 3000);
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'KG'), '500');
        await tester.ensureVisible(find.text('Hisoblash'));
        await tester.tap(find.text('Hisoblash'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(find.text(expectedMeters.toInt().toString()), findsOneWidget);
        await tester.ensureVisible(find.text('Zakaz ochish'));
        await tester.tap(find.text('Zakaz ochish'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('production-map-order-confirm')),
        );
        await tester.pumpAndSettle();

        final maps = await MobileApi.instance.adminProductionMaps();
        final opened = maps.singleWhere((item) => item.map.id != sourceMapId);
        expect(opened.map.baseLength, expectedMeters);
        final reloaded =
            await MobileApi.instance.adminProductionMap(opened.map.id);
        expect(reloaded.map.baseLength, expectedMeters);
        expect(reloaded.map.orderKg, 500);

        await tester.pump(const Duration(seconds: 6));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
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
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Buyurtma ma’lumotlari').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kutilayotgan buyurtma ko‘rsatkichlari'));
        await tester.pumpAndSettle();
        expect(find.text('${expectedMeters.toInt()} metr'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
