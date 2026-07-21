import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
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
      ref: 'QOLIPCHI-GLOBAL-SEARCH',
      phone: '',
      avatarUrl: '',
    );
    await MobileApi.instance.qolipSaveLocation(
      block: const QolipBlock(name: 'B', warehouse: 'Qolip ombori'),
      product: const QolipProduct(
        code: 'ITEM-UNOPENED-BLOCK',
        name: 'Unopened block target',
        itemGroup: 'Tayyor mahsulot',
      ),
      qolipCode: 'Q-UNOPENED-BLOCK',
      size: 45,
      quantity: 1,
      rowLetter: 'B',
      columnNumber: 13,
    );
  });

  tearDown(() async {
    await MobileApi.instance.qolipDeleteProductSpecs(
      const ['Q-UNOPENED-BLOCK'],
    );
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('search marks an unopened matching block tab green', (
    tester,
  ) async {
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
        home: const QolipHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(EditableText).first,
      'Unopened block target',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final blockTab = find.byKey(const ValueKey('qolip-tab-b'));
    final blockLabel = find.descendant(of: blockTab, matching: find.text('B'));
    expect(blockTab, findsOneWidget);
    expect(blockLabel, findsOneWidget);
    expect(
      tester.widget<Text>(blockLabel).style?.color,
      const Color(0xFF2E7D32),
    );
    expect(
      find.descendant(of: blockTab, matching: find.text('1')),
      findsOneWidget,
    );
  });

  testWidgets('row 13 can scroll above actions and open its cell', (
    tester,
  ) async {
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
        home: const QolipHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
    await tester.pumpAndSettle();
    final target = find.text('Unopened block target');
    expect(target, findsOneWidget);

    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();

    expect(find.text('Joy B13'), findsOneWidget);
  });
}
