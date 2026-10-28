part of 'admin_user_create_screen_test.dart';

void _registerSalesManagerCustomerCreateTests() {
  testWidgets('sales manager reused user form creates customers only',
      (tester) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.salesManager,
      displayName: 'Sales',
      legalName: 'Sales',
      ref: 'sales_manager_test',
      phone: '',
      avatarUrl: '',
      capabilities: ['sales.access', 'party.customer.manage'],
    );
    final requests = <String>[];
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
        home: const AdminUserCreateScreen(),
      ));
      await _pumpUi(tester);
      expect(find.text('Haridor'), findsOneWidget);
      expect(find.text('Omborchi'), findsNothing);
      expect(find.text('Ta’minotchi'), findsNothing);
      expect(requests, isEmpty,
          reason: 'Customer creation needs no role catalog or settings access');
      await tester.enterText(find.byType(TextField).at(0), 'Sales Customer');
      await tester.enterText(find.byType(TextField).at(1), '+998900001111');
      await tester
          .tap(find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'));
      await tester.pump();
      await _pumpUi(tester);
      expect(requests.where((request) => !request.startsWith('BODY ')),
          ['POST /v1/mobile/admin/customers']);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => _AdminUserCreateHttpClient(requests));
  });
}
