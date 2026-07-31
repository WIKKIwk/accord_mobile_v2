import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_server_monitor_screen.dart';
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
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'admin',
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

  testWidgets('backup day cells expose ready and empty day actions', (
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
        home: const AdminServerMonitorScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final today = DateTime.now();
    final todayKey = ValueKey(
      'server-backup-day-${today.year}-${today.month}-${today.day}',
    );
    expect(find.byKey(todayKey), findsOneWidget);

    tester.widget<InkWell>(find.byKey(todayKey)).onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Backupni yuklab olish'), findsOneWidget);
    expect(find.text('Bugun yana backup olish'), findsOneWidget);
    Navigator.of(tester.element(find.text('Backupni yuklab olish'))).pop();
    await tester.pump(const Duration(milliseconds: 300));

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayKey = ValueKey(
      'server-backup-day-${yesterday.year}-${yesterday.month}-${yesterday.day}',
    );
    tester.widget<InkWell>(find.byKey(yesterdayKey)).onTap?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bu kun uchun backup yo‘q'), findsOneWidget);
    expect(find.byKey(const ValueKey('server-backup-start-confirm')),
        findsNothing);
  });
}
