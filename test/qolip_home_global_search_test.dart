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
    await MobileApi.instance.qolipSaveLocation(
      block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
      product: const QolipProduct(
        code: 'ITEM-CROSS-BLOCK',
        name: 'Cross-block move target',
        itemGroup: 'Tayyor mahsulot',
      ),
      qolipCode: 'Q-CROSS-BLOCK',
      size: 44,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
  });

  tearDown(() async {
    await MobileApi.instance.qolipDeleteProductSpecs(
      const ['Q-UNOPENED-BLOCK', 'Q-CROSS-BLOCK'],
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

  testWidgets('a qolip moves to row 13 of another existing block', (
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

    await tester.tap(find.text('Cross-block move target'));
    await tester.pumpAndSettle();
    expect(find.text('Joy A1'), findsOneWidget);

    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();
    expect(find.text('Blokni tanlang'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'B'));
    await tester.pumpAndSettle();
    expect(find.text('B: yacheykani tanlang'), findsOneWidget);

    final targetCell = find.text('A13');
    await tester.ensureVisible(targetCell);
    await tester.pumpAndSettle();
    await tester.tap(targetCell);
    await tester.pumpAndSettle();

    final sourceLocations = await MobileApi.instance.qolipLocations('A');
    final targetLocations = await MobileApi.instance.qolipLocations('B');
    expect(
      sourceLocations.any((item) => item.qolipCode == 'Q-CROSS-BLOCK'),
      isFalse,
    );
    final moved = targetLocations.singleWhere(
      (item) => item.qolipCode == 'Q-CROSS-BLOCK',
    );
    expect(moved.block, 'B');
    expect(moved.warehouse, 'Qolip ombori');
    expect(moved.locationLabel, 'A13');
    expect(
      (await MobileApi.instance.qolipBlocks()).map((block) => block.name),
      orderedEquals(const ['A', 'B']),
    );
  });
}
