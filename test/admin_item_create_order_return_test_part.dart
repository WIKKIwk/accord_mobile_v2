part of 'admin_item_create_screen_test.dart';

void _registerAdminItemOrderReturnTests() {
  for (final succeeds in [true, false]) {
    testWidgets(
      succeeds
          ? 'created product is selected when returning to the order'
          : 'failed product creation keeps the item card open',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(600, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final client = _AdminItemCreateHttpClient(
          <String>[],
          autoCodeOnPost: true,
          duplicateOnPost: !succeeds,
        );
        await HttpOverrides.runZoned(() async {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(useMaterial3: true),
            locale: const Locale('uz'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AdminCalculateScreen(),
          ));
          await tester.pumpAndSettle();
          final productField = find.byWidgetPredicate(
            (widget) =>
                widget is InputDecorator &&
                widget.decoration.labelText == 'Mahsulot tanlang',
          );
          await tester.tap(productField);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Item qo‘shish'));
          await _pumpAdminItemCreateScreen(tester, waitForItems: true);
          await tester.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(find.text('Tayyor mahsulot'), findsOneWidget);
          await tester.enterText(_createTabTextFieldAt(1), 'Finished item');
          final customerPicker = find.byKey(
            const ValueKey('admin-item-create-customer-picker'),
          );
          await tester.ensureVisible(customerPicker);
          await tester.tap(customerPicker);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Customer One').last);
          await tester.pumpAndSettle();
          final submit = find.byKey(
            const ValueKey('admin-item-create-submit'),
          );
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await _pumpAdminItemCreateScreen(tester);
          await tester.pumpAndSettle();
          if (succeeds) {
            expect(find.byType(AdminItemCreateScreen), findsNothing);
            expect(find.byType(Dialog), findsNothing);
            expect(
              find.descendant(
                of: productField,
                matching: find.text('Finished item'),
              ),
              findsOneWidget,
            );
          } else {
            expect(find.byType(AdminItemCreateScreen), findsOneWidget);
            expect(find.byType(Dialog), findsOneWidget);
            expect(
              tester
                  .widget<TextField>(_createTabTextFieldAt(1))
                  .controller!
                  .text,
              'Finished item',
            );
            expect(find.text('Bu item code allaqachon mavjud'), findsOneWidget);
          }
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }, createHttpClient: (_) => client);
      },
    );
  }
}
