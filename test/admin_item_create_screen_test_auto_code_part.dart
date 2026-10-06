part of 'admin_item_create_screen_test.dart';

void _registerAdminItemAutoCodeTests() {
  for (final group in ['Tayyor mahsulot', 'Paketlar']) {
    testWidgets('$group hides manual code and creates an item without it',
        (tester) async {
      final seenRequests = <String>[];
      final client =
          _AdminItemCreateHttpClient(seenRequests, autoCodeOnPost: true);
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
          home: const AdminItemCreateScreen(),
        ));
        await _pumpAdminItemCreateScreen(tester, waitForItems: true);
        await _openCreateItemTab(tester);
        await tester.enterText(_createTabTextFieldAt(0), 'STALE-MANUAL-CODE');

        Future<void> selectGroup(String value) async {
          final picker =
              find.byKey(const ValueKey('admin-item-create-group-picker'));
          await tester.ensureVisible(picker);
          await tester.tap(picker);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(value).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text(value).last);
          await tester.pumpAndSettle();
        }

        await selectGroup(group);
        expect(_createTabTextFieldAt(0), findsNothing);
        expect(find.byKey(const ValueKey('admin-item-create-customer-picker')),
            findsOneWidget);
        await selectGroup('Homashyo');
        expect(_createTabTextFieldAt(0), findsOneWidget);
        await selectGroup(group);
        expect(_createTabTextFieldAt(0), findsNothing);

        final submit = find.byKey(const ValueKey('admin-item-create-submit'));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Mahsulot nomini kiriting'), findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        await tester.enterText(_createTabTextFieldAt(1), 'Finished item');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Tayyor mahsulot uchun customer tanlang'),
            findsOneWidget);
        expect(client.itemCreateBodies, isEmpty);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();

        final customerPicker =
            find.byKey(const ValueKey('admin-item-create-customer-picker'));
        await tester.ensureVisible(customerPicker);
        await tester.tap(customerPicker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Customer One').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        for (var i = 0; i < 30 && client.itemCreateBodies.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();

        expect(client.itemCreateBodies, hasLength(1));
        expect(client.itemCreateBodies.single, {
          'name': 'Finished item',
          'uom': 'Kg',
          'item_group': group,
          'customer_ref': 'CUST-001',
        });
        expect(
            seenRequests
                .any((request) => request.contains('q=STALE-MANUAL-CODE')),
            isFalse);
        expect(find.text('Mahsulot qo‘shildi: Finished item'),
            findsOneWidget);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, createHttpClient: (_) => client);
    });
  }
}
