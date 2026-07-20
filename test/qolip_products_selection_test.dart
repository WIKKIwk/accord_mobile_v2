import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: 'Qolipchi',
      ref: 'QOLIPCHI-001',
      phone: '',
      avatarUrl: '',
    );

    const hotlunch = QolipProduct(
      code: 'DEMO-HOTLUNCH',
      name: 'Hotlunch',
      itemGroup: 'Demo tayyor mahsulotlar',
      customerNames: ['Demo haridor'],
    );
    const salad = QolipProduct(
      code: 'DEMO-SALAD',
      name: 'Salat set',
      itemGroup: 'Demo tayyor mahsulotlar',
      customerNames: ['Demo filial'],
    );
    final locked = await MobileApi.instance.qolipSaveProductSpec(
      product: hotlunch,
      qolipCode: 'Q-LOCKED',
      size: 40,
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: hotlunch,
      qolipCode: 'Q-FREE',
      size: 41,
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: salad,
      qolipCode: 'Q-PRODUCT',
      size: 42,
    );
    final location = await MobileApi.instance.qolipSaveLocation(
      block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
      product: locked,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
    await MobileApi.instance.qolipIssueCheckout(
      locationId: location.id,
      quantity: 1,
      workerId: 'worker-1',
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('qolipchi safely selects, prints and deletes qolip specs', (
    tester,
  ) async {
    final initialProducts = await MobileApi.instance.qolipProducts(
      withQolipOnly: true,
    );
    expect(
      initialProducts
          .singleWhere((product) => product.qolipCode == 'Q-LOCKED')
          .isInUse,
      isTrue,
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
        home: const QolipProductsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    expect(find.text('1 ta tanlandi'), findsNothing);

    await tester.tap(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    expect(find.text('Ishchiga berilgan'), findsOneWidget);

    await tester.longPress(find.text('Q-LOCKED'));
    await tester.pumpAndSettle();
    expect(find.text('1 ta tanlandi'), findsNothing);

    await tester.tap(find.text('Q-FREE'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('qolip-code-qr-preview-Q-FREE')),
      findsOneWidget,
    );
    Navigator.of(
      tester.element(find.byKey(const ValueKey('qolip-code-qr-preview-Q-FREE'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Q-FREE'));
    await tester.pumpAndSettle();
    expect(find.text('1 ta tanlandi'), findsOneWidget);
    await tester.tap(find.byTooltip('Tanlanganlarni o‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Qoliplarni o‘chirasizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Q-FREE'), findsNothing);
    expect(find.text('Hotlunch'), findsOneWidget);

    await tester.longPress(find.text('Salat set'));
    await tester.pumpAndSettle();
    expect(find.text('1 ta tanlandi'), findsOneWidget);
    await tester.tap(find.byTooltip('Tanlanganlarni o‘chirish'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('1 ta mahsulotga biriktirilgan'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Salat set'), findsNothing);
  });

  test('qolip product search matches customer name', () async {
    final products = await MobileApi.instance.qolipProducts(
      query: 'Demo haridor',
      withQolipOnly: true,
    );

    expect(products, isNotEmpty);
    expect(products.every((product) => product.name == 'Hotlunch'), isTrue);
  });
}
