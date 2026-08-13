import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/widgets/m3_picker_sheet.dart';
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
    const block = QolipBlock(name: 'A', warehouse: 'Qolip ombori');
    await MobileApi.instance.qolipSaveLocation(
      block: block,
      qolipCode: 'BULK-Q-1',
      size: 41,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
    await MobileApi.instance.qolipSaveLocation(
      block: block,
      qolipCode: 'BULK-Q-2',
      size: 42,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 2,
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('qolipchi issues multiple selected qolips to one worker', (
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

    await tester.tap(
      find.byKey(const ValueKey('app-primary-navigation-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qolip berish'));
    await tester.pumpAndSettle();

    final picker = find.byType(M3AsyncPickerSheet<QolipLocationEntry>);
    final firstQolip = find
        .descendant(
          of: picker,
          matching: find.text('BULK-Q-1'),
        )
        .first;
    final secondQolip = find
        .descendant(
          of: picker,
          matching: find.text('BULK-Q-2'),
        )
        .first;
    await tester.longPress(firstQolip);
    await tester.pumpAndSettle();
    await tester.tap(secondQolip);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Tanlangan qoliplarni tasdiqlash'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ishchini tanlang'), findsOneWidget);
    await tester.tap(find.text('Test ishchi'));
    await tester.pumpAndSettle();

    expect(find.text('Qoliplarni berasizmi?'), findsOneWidget);
    expect(find.textContaining('2 ta tanlangan qolipni'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Berish'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 ta qolip Test ishchiga berildi'),
        findsOneWidget);
    expect(await MobileApi.instance.qolipLocations('A'), isEmpty);
  });
}
