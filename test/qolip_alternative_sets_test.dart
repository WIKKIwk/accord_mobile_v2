import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sets = <String, List<String>>{
  'set-a': ['A1', 'A2'],
  'set-b': ['B1', 'B2', 'B3'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in <List<String>, bool>{
    ['A1', 'a2', ' A1 ']: true,
    ['B3', 'B1', 'B2']: true,
    ['A1']: false,
    ['B1', 'B2']: false,
    ['A1', 'B2']: false,
    ['A1', 'A2', 'B1', 'B2', 'B3']: false,
    ['A1', 'A2', 'UNKNOWN']: false,
    []: false,
  }.entries) {
    test('alternative set scan ${entry.key} accepted=${entry.value}', () {
      expect(
        productionMapAllRequiredQolipSetsScanned(
          requiredQolipSets: _sets,
          scannedQolipCodes: entry.key,
        ),
        entry.value,
      );
    });
  }

  test('wire models retain set identity and legacy owners stay distinct', () {
    final spec = QolipProduct.fromJson({
      'code': 'ITEM',
      'name': 'Same name',
      'item_group': 'Products',
      'warehouse': 'Molds A',
      'qolip_code': 'A1',
      'qolip_set_id': 'set-a',
    });
    expect(spec.setId, 'set-a');
    expect(
        AdminProductionMapRequiredQolip.fromJson({
          'qolip_code': 'A1',
          'color': 'Red',
          'qolip_set_id': 'set-a',
        }).setId,
        'set-a');
    const a = QolipProduct(
        code: ' ITEM ',
        name: 'Same name',
        itemGroup: 'Products',
        warehouse: 'Molds A');
    const b = QolipProduct(
        code: 'ITEM',
        name: 'Same name',
        itemGroup: 'Products',
        warehouse: 'Molds B');
    expect(a.setId, 'legacy:4:item:molds a');
    expect(a.setId, isNot(b.setId));
  });

  group('clerk alternatives', () {
    const product = QolipProduct(
        code: 'DEMO-HOTLUNCH',
        name: 'Hotlunch',
        itemGroup: 'Demo tayyor mahsulotlar',
        warehouse: 'Qolip ombori');
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      resetMobileApiTestModeData();
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.token = 'alternative-test-token';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Clerk',
        legalName: 'Clerk',
        ref: 'alternative-clerk',
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

    test('batches create peer sets and editing keeps membership', () async {
      final first = await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'ALT-A1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'ALT-A2', size: 40)
        ],
      );
      final second = await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'ALT-B1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'ALT-B2', size: 40)
        ],
      );
      expect(first[0].setId, first[1].setId);
      expect(second[0].setId, second[1].setId);
      expect(first[0].setId, isNot(second[0].setId));
      final edited = await MobileApi.instance.qolipSaveProductSpec(
        product: first[0],
        qolipCode: 'ALT-A1-EDITED',
        previousQolipCode: 'ALT-A1',
        size: 41,
      );
      expect(edited.setId, first[0].setId);
      final groups =
          groupQolipProductsByContainer([...first.skip(1), edited, ...second]);
      expect(groups.single.qolipSets.keys,
          unorderedEquals([first[0].setId, second[0].setId]));
    });

    test('custom product catalog preserves distinct alternative sets',
        () async {
      const custom = QolipProduct(
          code: 'ALT-CUSTOM-PRODUCT',
          name: 'Muqobil mahsulot',
          itemGroup: 'Products',
          warehouse: 'Qolip ombori');
      for (final codes in [
        ['CUSTOM-A1', 'CUSTOM-A2'],
        ['CUSTOM-B1', 'CUSTOM-B2']
      ]) {
        await MobileApi.instance.qolipSaveProductSpecsBatch(
          product: custom,
          warehouse: custom.warehouse,
          specs: [
            for (final code in codes)
              QolipProductSpecBatchItem(qolipCode: code, size: 40)
          ],
        );
      }
      final catalog = await MobileApi.instance
          .qolipProducts(query: custom.code, withQolipOnly: true);
      expect(catalog.map((mold) => mold.setId).toSet().length, 2);
      expect(
          catalog.every((mold) => mold.warehouse == custom.warehouse), isTrue);
    });

    testWidgets('long press exposes alternative FAB and locks product',
        (tester) async {
      await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'ALT-A1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'ALT-A2', size: 40)
        ],
      );
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        home: QolipProductsScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Hotlunch'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      expect(find.text('Muqobil qo‘shish'), findsOneWidget);
      await tester.tap(find.text('Muqobil qo‘shish'));
      await tester.pumpAndSettle();
      expect(find.text('Qolipni omborga biriktirish'), findsOneWidget);
      expect(find.text('Mahsulot nomi bilan qidirish'), findsNothing);
      expect(find.text('Hotlunch'), findsWidgets);
    });
  });
}
