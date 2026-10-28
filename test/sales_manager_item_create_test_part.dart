part of 'admin_item_create_screen_test.dart';

void _registerSalesManagerItemCreateTests() {
  testWidgets(
      'sales manager item form offers only finished goods and descendants',
      (tester) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.salesManager,
      displayName: 'Sales',
      legalName: 'Sales',
      ref: 'sales_manager_test',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'sales.access',
        'catalog.item.read',
        'catalog.item.create'
      ],
    );
    final client = _AdminItemCreateHttpClient(<String>[], autoCodeOnPost: true);
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminItemCreateScreen(
            initialItemGroup: 'Homashyo', openCreateDialog: true),
      ));
      await tester.pumpAndSettle();
      expect(_createTabTextFieldAt(0), findsNothing);
      expect(find.byKey(const ValueKey('admin-item-create-customer-picker')),
          findsOneWidget);
      final picker =
          find.byKey(const ValueKey('admin-item-create-group-picker'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.text('Tayyor mahsulot'), findsWidgets);
      expect(find.text('Paketlar'), findsOneWidget);
      expect(find.text('Homashyo'), findsNothing);
      expect(find.text('All Item Groups'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, createHttpClient: (_) => client);
  });
}
