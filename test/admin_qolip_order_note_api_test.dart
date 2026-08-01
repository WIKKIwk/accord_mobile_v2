import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
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
      ref: 'QOLIPCHI-NOTE-TEST',
      phone: '',
      avatarUrl: '',
    );

    const product = QolipProduct(
      code: 'NOTE-ITEM',
      name: 'Note mahsulot',
      itemGroup: 'Tayyor mahsulotlar',
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'NOTE-Q-1',
      size: 40,
    );
    await MobileApi.instance.qolipSaveProductSpec(
      product: product,
      qolipCode: 'NOTE-Q-2',
      size: 41,
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: 'NOTE-ORDER-1',
        productCode: 'NOTE-ITEM',
        title: 'Note mahsulot',
        orderNumber: 'NOTE-0001',
        nodes: [],
        edges: [],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      const ProductionMapDefinition(
        id: 'NOTE-ORDER-2',
        productCode: 'NOTE-ITEM',
        title: 'Note mahsulot 2',
        orderNumber: 'NOTE-0002',
        nodes: [],
        edges: [],
      ),
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  test('qolip note switches given to returned without deleting codes',
      () async {
    final details = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: 'NOTE-ORDER-1');
    expect(
      details.requiredQolips.map((item) => item.qolipCode),
      ['NOTE-Q-1', 'NOTE-Q-2'],
    );

    final given = await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
      orderId: 'NOTE-ORDER-1',
      status: 'given',
      qolipCodes: const ['NOTE-Q-2'],
    );
    expect(given.status, 'given');
    expect(given.qolipCodes, ['NOTE-Q-2']);

    final secondDetails = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: 'NOTE-ORDER-2');
    expect(
      secondDetails.requiredQolips
          .firstWhere((item) => item.qolipCode == 'NOTE-Q-2')
          .isInUse,
      isTrue,
    );
    await expectLater(
      MobileApi.instance.adminSaveProductionMapQolipOrderNote(
        orderId: 'NOTE-ORDER-2',
        status: 'given',
        qolipCodes: const ['NOTE-Q-2'],
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.code,
          'code',
          'qolip_order_note_in_use',
        ),
      ),
    );

    final returned =
        await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
      orderId: 'NOTE-ORDER-1',
      status: 'returned',
    );
    expect(returned.status, 'returned');
    expect(returned.qolipCodes, ['NOTE-Q-2']);

    final availableAfterReturn = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: 'NOTE-ORDER-2');
    expect(
      availableAfterReturn.requiredQolips
          .firstWhere((item) => item.qolipCode == 'NOTE-Q-2')
          .isInUse,
      isFalse,
    );
    final secondGiven =
        await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
      orderId: 'NOTE-ORDER-2',
      status: 'given',
      qolipCodes: const ['NOTE-Q-2'],
    );
    expect(secondGiven.isGiven, isTrue);

    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
    expect(snapshot.qolipOrderNotes['NOTE-ORDER-1']?.isReturned, isTrue);
  });

  testWidgets('qolip qarz daftari lists and returns order draft', (
    tester,
  ) async {
    await MobileApi.instance.adminSaveProductionMapQolipOrderNote(
      orderId: 'NOTE-ORDER-1',
      status: 'given',
      qolipCodes: const ['NOTE-Q-2'],
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

    expect(find.text('Note mahsulot'), findsOneWidget);
    expect(find.textContaining('Order: NOTE-ORDER-1'), findsOneWidget);
    expect(find.textContaining('Draft'), findsOneWidget);

    await tester.tap(find.text('Note mahsulot'));
    await tester.pumpAndSettle();
    expect(find.text('Qoliplarni qaytarib oldim'), findsOneWidget);
    await tester.tap(find.text('Qoliplarni qaytarib oldim'));
    await tester.pumpAndSettle();

    expect(find.text('Qarzda qolip yo‘q'), findsOneWidget);
    final details = await MobileApi.instance
        .adminProductionMapQolipOrderNoteDetails(orderId: 'NOTE-ORDER-1');
    expect(details.note?.isReturned, isTrue);
  });
}
