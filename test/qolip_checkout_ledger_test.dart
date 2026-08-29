import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_checkouts_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: 'Qolipchi',
      ref: 'QOLIPCHI-CHECKOUT-TEST',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('qarz daftari only lists and returns a physical checkout', (
    tester,
  ) async {
    const product = QolipProduct(
      code: 'LEDGER-ITEM',
      name: 'Ledger mahsulot',
      itemGroup: 'Tayyor mahsulotlar',
    );
    final spec = await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'LEDGER-Q-1',
      size: 40,
    );
    final location = await MobileApi.instance.qolipSaveLocation(
      block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
      product: spec,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
    await MobileApi.instance.qolipIssueCheckout(
      locationId: location.id,
      quantity: 1,
      workerId: 'worker-1',
    );

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
        home: const QolipCheckoutsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ledger mahsulot'), findsOneWidget);
    expect(find.textContaining('Test ishchi'), findsOneWidget);
    expect(find.textContaining('LEDGER-Q-1'), findsOneWidget);
    expect(find.textContaining('Draft'), findsNothing);

    await tester.tap(find.text('Ledger mahsulot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qaytar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('yacheyka tanlang'), findsNothing);
    expect(find.text('Qarzda qolip yo‘q'), findsOneWidget);
    expect(
      await MobileApi.instance.qolipCheckouts(status: 'open'),
      isEmpty,
    );
  });

  testWidgets(
    'long press selects debts and bulk return asks only for unknown cell',
    (tester) async {
      const knownProduct = QolipProduct(
        code: 'KNOWN-ITEM',
        name: 'Known mahsulot',
        itemGroup: 'Tayyor mahsulotlar',
      );
      const unknownProduct = QolipProduct(
        code: 'UNKNOWN-ITEM',
        name: 'Unknown mahsulot',
        itemGroup: 'Tayyor mahsulotlar',
      );
      final knownSpec = await MobileApi.instance.qolipSaveProductSpec(
        product: knownProduct,
        qolipCode: 'KNOWN-Q',
        size: 40,
      );
      final unknownSpec = await MobileApi.instance.qolipSaveProductSpec(
        product: unknownProduct,
        qolipCode: 'UNKNOWN-Q',
        size: 41,
      );
      final knownLocation = await MobileApi.instance.qolipSaveLocation(
        block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
        product: knownSpec,
        quantity: 1,
        rowLetter: 'A',
        columnNumber: 1,
      );
      final unknownLocation = await MobileApi.instance.qolipSaveLocation(
        block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
        product: unknownSpec,
        quantity: 1,
      );
      await MobileApi.instance.qolipIssueCheckout(
        locationId: knownLocation.id,
        quantity: 1,
        workerId: 'worker-1',
      );
      await MobileApi.instance.qolipIssueCheckout(
        locationId: unknownLocation.id,
        quantity: 1,
        workerId: 'worker-2',
      );

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
          home: const QolipCheckoutsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Known mahsulot'));
      await tester.pumpAndSettle();
      expect(find.text('1 ta tanlandi'), findsOneWidget);

      await tester.tap(find.text('Unknown mahsulot'));
      await tester.pumpAndSettle();
      expect(find.text('2 ta tanlandi'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('qolip-checkouts-return-selection')),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNKNOWN-Q uchun yacheyka tanlang'), findsOneWidget);
      await tester.tap(find.text('A2').last);
      await tester.pumpAndSettle();

      expect(find.text('Qarzda qolip yo‘q'), findsOneWidget);
      expect(
        await MobileApi.instance.qolipCheckouts(status: 'open'),
        isEmpty,
      );
      final returned = await MobileApi.instance.qolipLocations('A');
      expect(
        returned
            .singleWhere((item) => item.qolipCode == 'KNOWN-Q')
            .locationLabel,
        'A1',
      );
      expect(
        returned
            .singleWhere((item) => item.qolipCode == 'UNKNOWN-Q')
            .locationLabel,
        'A2',
      );
    },
  );
}
