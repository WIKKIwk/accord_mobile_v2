import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_settings_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeWorkerSettingsData();
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
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('worker settings creates worker with selected level', (
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
        home: const AdminWorkerSettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Ishchi sozlamalari'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ali ishchi');
    await tester.tap(find.text('Brigader').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Master').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ishchi qo‘shish'));
    await tester.pumpAndSettle();

    expect(find.text('Ishchi saqlandi'), findsOneWidget);
    expect(find.text('Ali ishchi'), findsOneWidget);
    expect(find.text('Master'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker settings menu button opens drawer', (tester) async {
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
        home: const AdminWorkerSettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Ishchilar'), findsWidgets);
  });

  testWidgets('worker group can be assigned to an apparatus from edit mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: const AdminWorkerSettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Guruhlar'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('worker-group-code-input')), 'ab');
    await tester.tap(find.text('Saqlash').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('worker-group-apparatus-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laminatsiya 1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saqlash').last);
    await tester.pumpAndSettle();

    final assigned = await MobileApi.instance.adminWorkerGroups(
      apparatus: 'Laminatsiya 1',
    );
    expect(assigned.map((group) => group.groupCode), contains('AB'));
    expect(find.text('Laminatsiya 1'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker groups allow custom codes and hide assigned workers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await MobileApi.instance.adminCreateWorker(
      name: 'Vali guruhchi',
      level: 'Brigader',
    );
    await MobileApi.instance.adminCreateWorker(
      name: 'Soli guruhchi',
      level: 'Master',
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
        home: const AdminWorkerSettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Guruhlar'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('worker-group-code-input')), 'b guruh');
    await tester.tap(find.text('Saqlash').first);
    await tester.pumpAndSettle();

    expect(find.text('B GURUH guruh'), findsOneWidget);
    expect(find.text('B GURUH guruh ma’lumoti'), findsOneWidget);
    expect(find.text('Biriktirilmagan'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('B GURUH guruh sozlamalari'), findsOneWidget);
    expect(find.text('Ish vaqti'), findsOneWidget);
    expect(find.text('Haftalik ish kuni'), findsOneWidget);
    expect(find.text('Schot hisoblanadi'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Vali guruhchi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saqlash').last);
    await tester.pumpAndSettle();

    expect(find.text('B GURUH guruh sozlamalari'), findsNothing);
    expect(find.text('B GURUH guruh ma’lumoti'), findsOneWidget);
    expect(find.text('Bekor qilish'), findsNothing);

    await tester.enterText(
        find.byKey(const Key('worker-group-code-input')), 'dd');
    await tester.tap(find.text('Saqlash').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(CheckboxListTile, 'Vali guruhchi'), findsNothing);
    expect(
        find.widgetWithText(CheckboxListTile, 'Soli guruhchi'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Soli guruhchi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saqlash').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('worker-group-code-input')), 'ee');
    await tester.tap(find.text('Saqlash').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(CheckboxListTile, 'Vali guruhchi'), findsNothing);
    expect(
        find.widgetWithText(CheckboxListTile, 'Soli guruhchi'), findsNothing);
    expect(find.text('ishchilar guruhlarga taqsimlanib bo‘lingan'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('new worker appears in group editor without reopening screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: const AdminWorkerSettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Guruhlar'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('worker-group-code-input')), 'ab');
    await tester.tap(find.text('Saqlash').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Ishchilar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Yangi ishchi');
    await tester.tap(find.text('Ishchi qo‘shish'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Guruhlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    expect(
        find.widgetWithText(CheckboxListTile, 'Yangi ishchi'), findsOneWidget);
  });
}
