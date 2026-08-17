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
    resetMobileApiQolipTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: 'Qolipchi',
      ref: 'QOLIPCHI-BULK-MOVE',
      phone: '',
      avatarUrl: '',
    );
    const block = QolipBlock(name: 'A', warehouse: 'Qolip ombori');
    await MobileApi.instance.qolipSaveLocation(
      block: block,
      qolipCode: 'BULK-MOVE-1',
      size: 41,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
    await MobileApi.instance.qolipSaveLocation(
      block: block,
      qolipCode: 'BULK-MOVE-2',
      size: 42,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
  });

  tearDown(() async {
    resetMobileApiQolipTestModeData();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('qolipchi moves multiple molds from a cell', (tester) async {
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

    await tester.tap(
      find.byKey(const ValueKey<String>('qolip-grid-cell-A1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('BULK-MOVE-1'), findsAtLeastNWidgets(1));
    expect(find.text('BULK-MOVE-2'), findsOneWidget);

    await tester.longPress(find.text('BULK-MOVE-1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('BULK-MOVE-2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qolip-bulk-move-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('B2').last);
    await tester.pumpAndSettle();

    expect(await MobileApi.instance.qolipLocations('A'), isEmpty);
    final moved = await MobileApi.instance.qolipLocations('B');
    expect(moved, hasLength(2));
    expect(
      moved.map((item) => item.qolipCode),
      containsAll(<String>['BULK-MOVE-1', 'BULK-MOVE-2']),
    );
    expect(moved.every((item) => item.locationLabel == 'B2'), isTrue);
  });
}
