import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/qolip_batch.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_color_picker.dart';
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
    for (final checkout in await MobileApi.instance.qolipCheckouts(
      status: 'open',
    )) {
      await MobileApi.instance.qolipReturnCheckout(checkout.id);
    }
    await MobileApi.instance.qolipDeleteProductSpecs([
      'Q-LOCKED',
      'Q-FREE',
      'Q-PRODUCT',
      'Q-COLOR',
      'Q-TILLA',
      'Q-MATLAK',
      'Z-TEMPLATE-7',
      'A-TEMPLATE-2',
      ...[
        for (var index = 1; index <= 8; index++) 'BATCH-TEST-$index',
      ],
    ]);
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
    expect(find.byTooltip('Qolip qo‘shish'), findsOneWidget);
    await tester.tap(find.byTooltip('Qolip qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('Qolipni omborga biriktirish'), findsOneWidget);
    expect(find.text('Hotlunch'), findsWidgets);
    Navigator.of(
      tester.element(find.text('Qolipni omborga biriktirish')),
    ).pop();
    await tester.pumpAndSettle();

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
      tester
          .element(find.byKey(const ValueKey('qolip-code-qr-preview-Q-FREE'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Q-FREE'));
    await tester.pumpAndSettle();
    expect(find.text('3/1 ta tanlandi'), findsOneWidget);
    await tester.tap(find.byTooltip('Tanlanganlarni o‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Qoliplarni o‘chirasizmi?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'O‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Q-FREE'), findsNothing);
    expect(find.text('Hotlunch'), findsOneWidget);

    await tester.longPress(find.text('Salat set'));
    await tester.pumpAndSettle();
    expect(find.text('2/1 ta tanlandi'), findsOneWidget);
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

  testWidgets('qolip FAB opens qolip actions and manual batch code entry', (
    tester,
  ) async {
    const product = QolipProduct(
      code: 'DEMO-PREFIX',
      name: 'Prefix mahsulot',
      itemGroup: 'Demo tayyor mahsulotlar',
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'Z-TEMPLATE-7',
      size: 42,
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'A-TEMPLATE-2',
      size: 42,
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

    await tester.tap(
      find.byKey(const ValueKey('app-primary-navigation-button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Qolip qo‘shish'), findsOneWidget);
    expect(find.text('Qarz daftari'), findsOneWidget);
    await tester.tap(find.text('Qolip qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulot nomi bilan qidirish'), findsOneWidget);
    await tester.tap(find.text('Mahsulot nomi bilan qidirish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotlunch').last);
    await tester.pumpAndSettle();
    final batchCodeField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Qolip code',
    );
    await tester.enterText(batchCodeField, '23-34-24-6');
    await tester.pump();
    expect(find.byKey(const ValueKey('qolip-batch-preview')), findsOneWidget);
    expect(find.text('6 ta qolip'), findsOneWidget);
    expect(find.text('23-34-24-1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('qolip-batch-preview')));
    await tester.pump();
    expect(find.text('23-34-24-1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('qolip-batch-preview-codes')),
      findsOneWidget,
    );
    Navigator.of(tester.element(find.text('Qolipni omborga biriktirish')))
        .pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prefix mahsulot'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Qolip qo‘shish'));
    await tester.pumpAndSettle();

    final codeField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Qolip code',
      ),
    );
    expect(codeField.controller?.text, isEmpty);
    Navigator.of(tester.element(find.text('Qolipni omborga biriktirish')))
        .pop();
    await tester.pumpAndSettle();
  });

  test('qolip batch code uses the final number as the count', () {
    final draft = parseQolipBatchCode('58907-543-453-8');

    expect(draft, isNotNull);
    expect(draft!.count, 8);
    expect(draft.codes, [
      '58907-543-453-1',
      '58907-543-453-2',
      '58907-543-453-3',
      '58907-543-453-4',
      '58907-543-453-5',
      '58907-543-453-6',
      '58907-543-453-7',
      '58907-543-453-8',
    ]);
    expect(parseQolipBatchCode('ABC-X')!.codes, ['ABC-X']);
    expect(parseQolipBatchCode('ABC-0'), isNull);
  });

  test('qolip batch save returns every generated qolip', () async {
    const product = QolipProduct(
      code: 'DEMO-BATCH',
      name: 'Batch mahsulot',
      itemGroup: 'Demo tayyor mahsulotlar',
    );
    final saved = await MobileApi.instance.qolipSaveProductSpecsBatch(
      product: product,
      specs: [
        for (var index = 1; index <= 8; index++)
          QolipProductSpecBatchItem(
            qolipCode: 'BATCH-TEST-$index',
            size: 42,
            qolipColor: qolipDefaultColors[index - 1].value,
          ),
      ],
    );

    expect(saved, hasLength(8));
    expect(saved.map((item) => item.qolipCode), [
      for (var index = 1; index <= 8; index++) 'BATCH-TEST-$index',
    ]);
  });

  test('qolip color is saved and returned with the product', () async {
    const product = QolipProduct(
      code: 'DEMO-COLOR',
      name: 'Rangli qolip',
      itemGroup: 'Demo tayyor mahsulotlar',
    );
    final saved = await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'Q-COLOR',
      size: 42,
      qolipColor: '#E53935',
    );

    expect(saved.qolipColor, '#E53935');
    final products = await MobileApi.instance.qolipProducts(
      query: 'Q-COLOR',
      withQolipOnly: true,
    );
    expect(products.single.qolipColor, '#E53935');
  });

  test('qolip added palette colors are saved and returned in a batch',
      () async {
    const product = QolipProduct(
      code: 'DEMO-EXTENDED-COLORS',
      name: 'Qo‘shimcha rangli qolip',
      itemGroup: 'Demo tayyor mahsulotlar',
    );
    final tilla = qolipDefaultColors
        .singleWhere((option) => option.name == 'Tilla')
        .value;
    final matlak = qolipDefaultColors
        .singleWhere((option) => option.name == 'Matlak')
        .value;

    final saved = await MobileApi.instance.qolipSaveProductSpecsBatch(
      product: product,
      specs: [
        QolipProductSpecBatchItem(
          qolipCode: 'Q-TILLA',
          size: 42,
          qolipColor: tilla,
        ),
        QolipProductSpecBatchItem(
          qolipCode: 'Q-MATLAK',
          size: 42,
          qolipColor: matlak,
        ),
      ],
    );

    expect(saved.map((item) => item.qolipColor), [tilla, matlak]);
    final products = await MobileApi.instance.qolipProducts(
      query: 'Q-',
      withQolipOnly: true,
    );
    expect(
      products
          .where((item) =>
              item.qolipCode == 'Q-TILLA' || item.qolipCode == 'Q-MATLAK')
          .map((item) => item.qolipColor),
      [tilla, matlak],
    );
  });

  test('duplicate qolip code create is rejected without overwriting', () async {
    const duplicateProduct = QolipProduct(
      code: 'DEMO-DUPLICATE',
      name: 'Boshqa mahsulot',
      itemGroup: 'Demo tayyor mahsulotlar',
    );

    await expectLater(
      MobileApi.instance.qolipSaveProductSpec(
        product: duplicateProduct,
        qolipCode: 'q-free',
        size: 58,
        qolipColor: '#43A047',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'qolip_code_conflict',
        ),
      ),
    );

    final original = (await MobileApi.instance.qolipProducts(
      query: 'Q-FREE',
      withQolipOnly: true,
    ))
        .single;
    expect(original.code, 'DEMO-HOTLUNCH');
    expect(original.qolipSize, 41);
    expect(original.qolipColor, isEmpty);
  });
}
