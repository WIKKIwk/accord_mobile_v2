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
      ref: 'QOLIPCHI-STICKY-TEST',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('row headers remain pinned on left when grid is scrolled horizontally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    // Verify row 1 header is initially visible
    final row1Finder = find.byKey(const ValueKey('qolip-row-header-1'));
    expect(row1Finder, findsOneWidget);
    final row1InitialPos = tester.getTopLeft(row1Finder);

    // Verify column A is initially visible
    final colAFinder = find.byKey(const ValueKey('qolip-col-header-A'));
    expect(colAFinder, findsOneWidget);
    final colAInitialPos = tester.getTopLeft(colAFinder);

    // Find the horizontal SingleChildScrollView inside the grid table
    final horizontalScrollFinder = find.byKey(
      const ValueKey('qolip-grid-horizontal-scroll'),
    );
    expect(horizontalScrollFinder, findsOneWidget);

    // Scroll horizontally to the right by 250 pixels
    await tester.drag(horizontalScrollFinder, const Offset(-250, 0));
    await tester.pumpAndSettle();

    // Column A should have moved left
    final colAPostPos = tester.getTopLeft(colAFinder);
    expect(colAPostPos.dx, lessThan(colAInitialPos.dx));

    // Crucial requirement: Row header 1 position MUST NOT change horizontally!
    final row1PostPos = tester.getTopLeft(row1Finder);
    expect(row1PostPos.dx, equals(row1InitialPos.dx));
  });

  testWidgets('dragging horizontally on sticky row headers column scrolls the grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    final colAFinder = find.byKey(const ValueKey('qolip-col-header-A'));
    expect(colAFinder, findsOneWidget);
    final colAInitialPos = tester.getTopLeft(colAFinder);

    // Drag horizontally directly on row header '1'
    final row1Finder = find.byKey(const ValueKey('qolip-row-header-1'));
    expect(row1Finder, findsOneWidget);
    await tester.drag(row1Finder, const Offset(-150, 0));
    await tester.pumpAndSettle();

    // The grid should have scrolled horizontally
    final colAPostPos = tester.getTopLeft(colAFinder);
    expect(colAPostPos.dx, lessThan(colAInitialPos.dx));
  });
}
