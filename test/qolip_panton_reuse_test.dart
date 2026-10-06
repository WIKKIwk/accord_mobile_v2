import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
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
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'panton-test-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Clerk',
      legalName: 'Clerk',
      ref: 'panton-clerk',
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

  for (final siblingHasPanton in [false, true]) {
    testWidgets(
        'Panton edit ignores all 100 numbers in another set, sibling=$siblingHasPanton',
        (tester) async {
      const product = QolipProduct(
        code: 'DEMO-HOTLUNCH',
        name: 'Hotlunch',
        itemGroup: 'Demo tayyor mahsulotlar',
        warehouse: 'Qolip ombori',
      );
      await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: [
          for (var number = 1; number <= 100; number++)
            QolipProductSpecBatchItem(
              qolipCode: 'OTHER-$number',
              size: 40,
              qolipColor: 'PANTON $number',
            ),
        ],
      );
      await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: [
          const QolipProductSpecBatchItem(qolipCode: 'TARGET-1', size: 40),
          if (siblingHasPanton)
            const QolipProductSpecBatchItem(
              qolipCode: 'TARGET-2',
              size: 40,
              qolipColor: 'PANTON 1',
            ),
        ],
      );
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QolipProductsScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hotlunch'));
      await tester.pumpAndSettle();
      final row = find.ancestor(
        of: find.text('TARGET-1'),
        matching: find.byType(QolipCodeRow),
      );
      // The large sibling set may put this row below the screen viewport.
      tester.widget<QolipCodeRow>(row).onEdit();
      await tester.pumpAndSettle();
      final number = siblingHasPanton ? 2 : 1;
      expect(find.text('Panton $number'), findsOneWidget);
      await tester.ensureVisible(find.text('Panton $number'));
      await tester.tap(find.text('Panton $number'));
      await tester.pump();
      expect(
        tester
            .widget<QolipColorPicker>(find.byType(QolipColorPicker))
            .selectedColor,
        'PANTON $number',
      );
    });
  }
}
