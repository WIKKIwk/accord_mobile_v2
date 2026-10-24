import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_reworks_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const product = QolipProduct(
    code: 'DEMO-HOTLUNCH',
    name: 'Hotlunch',
    itemGroup: 'Demo tayyor mahsulotlar',
    warehouse: 'Qolip ombori');

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: page,
  ));
  await tester.pumpAndSettle();
}

Future<void> openFab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
  await tester.pumpAndSettle();
}

Future<void> sendFromFab(WidgetTester tester, String label) async {
  await openFab(tester);
  expect(find.text(label), findsOneWidget);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Berish'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'rework-widget-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'rework-clerk',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
    await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'RW-A1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'RW-A2', size: 40),
        ]);
  });
  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets(
      'mold long press exposes individual send and marks only that code away',
      (tester) async {
    await pumpPage(tester, const QolipProductsScreen());
    await tester.tap(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(QolipCodeRow, 'RW-A1');
    await tester.longPressAt(tester.getTopLeft(row) + const Offset(16, 16));
    await tester.pumpAndSettle();
    await sendFromFab(tester, 'Qolipni peredelkaga berish');
    expect((await MobileApi.instance.qolipReworks()).single.qolipCode, 'RW-A1');
    await tester.tap(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    expect(find.text('Peredelkada'), findsOneWidget);
    expect(find.text('Peredelkada: 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'product long press sends every alternative and extension with shared codes once',
      (tester) async {
    await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'RW-B1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'RW-B2', size: 40),
        ]);
    const second = QolipProduct(
        code: 'DEMO-SALAD',
        name: 'Salat set',
        itemGroup: 'Demo tayyor mahsulotlar',
        warehouse: 'Qolip ombori');
    final firstSet = await MobileApi.instance.qolipResolveSet('RW-A1');
    await MobileApi.instance.qolipReuseSet(set: firstSet!, product: second);
    await MobileApi.instance.qolipAddProductMold(product,
        const QolipMoldDraft(code: 'RW-EXTRA', size: 40, color: 'Panton 9'));
    await pumpPage(tester, const QolipProductsScreen());
    await tester.longPress(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Salat set'));
    await tester.pumpAndSettle();
    await sendFromFab(tester, 'Komplektni peredelkaga berish');
    final away = await MobileApi.instance.qolipReworks();
    expect(away.map((row) => row.qolipCode).toSet(),
        {'RW-A1', 'RW-A2', 'RW-B1', 'RW-B2', 'RW-EXTRA'});
    expect(away, hasLength(5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'rework page returns selected subset and exposes its mileage history',
      (tester) async {
    await MobileApi.instance.qolipSendToRework(
        requestId: 'whole-set', qolipCodes: ['RW-A1', 'RW-A2']);
    await pumpPage(tester, const QolipReworksScreen());
    expect(find.text('Hotlunch'), findsOneWidget);
    expect(find.text('RW-A1'), findsOneWidget);
    expect(find.text('RW-A2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qolip-rework-select-RW-A1')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('qolip-rework-return-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Qaytdi'));
    await tester.pumpAndSettle();
    expect((await MobileApi.instance.qolipReworks()).single.qolipCode, 'RW-A2');
    expect(find.text('RW-A1'), findsNothing);
    expect((await MobileApi.instance.qolipMileage('RW-A1')).currentMeter, 0);
    expect((await MobileApi.instance.qolipMileage('RW-A2')).trackingEnabled,
        isFalse);
    await tester.tap(find.text('Qaytganlar'));
    await tester.pumpAndSettle();
    expect(find.text('RW-A1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qolip-mileage-RW-A1')));
    await tester.pumpAndSettle();
    expect(find.text('Joriy probeg: 0 m'), findsOneWidget);
    expect(find.text('0 m'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final returning in [false, true]) {
    testWidgets(
        'changing account during ${returning ? 'return' : 'send'} confirmation cancels the mutation',
        (tester) async {
      if (returning) {
        await MobileApi.instance.qolipSendToRework(
            requestId: 'before-switch', qolipCodes: ['RW-A1']);
        await pumpPage(tester, const QolipReworksScreen());
        await tester
            .tap(find.byKey(const ValueKey('qolip-rework-select-RW-A1')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('qolip-rework-return-selected')));
      } else {
        await pumpPage(tester, const QolipProductsScreen());
        await tester.longPress(find.text('Hotlunch'));
        await tester.pumpAndSettle();
        await openFab(tester);
        await tester.tap(find.text('Komplektni peredelkaga berish'));
      }
      await tester.pumpAndSettle();
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.qolipchi,
          displayName: 'Other',
          legalName: '',
          ref: 'other-clerk',
          phone: '',
          avatarUrl: '',
          capabilities: ['qolip.manage']);
      AppSession.instance.revision.value++;
      await tester.tap(
          find.widgetWithText(FilledButton, returning ? 'Qaytdi' : 'Berish'));
      await tester.pumpAndSettle();
      expect(
          find.text('Sessiya o‘zgardi. Sahifani yangilang.'), findsOneWidget);
      final rows = await MobileApi.instance.qolipReworks();
      expect(rows, hasLength(returning ? 1 : 0));
      expect((await MobileApi.instance.qolipMileage('RW-A1')).trackingEnabled,
          isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('qolip drawer opens the new page through its guarded route',
      (tester) async {
    await pumpPage(tester, const QolipProductsScreen());
    await tester.tap(find.byIcon(Icons.menu_rounded).first);
    await tester.pumpAndSettle();
    final destination = find.text('Peredelkadagi qoliplar');
    await tester.drag(
        find.descendant(
            of: find.byType(NavigationDrawer), matching: find.byType(ListView)),
        const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(destination);
    await tester.pumpAndSettle();
    expect(find.byType(QolipReworksScreen), findsOneWidget);
    expect(find.text('Peredelkada qolip yo‘q'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
