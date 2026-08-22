import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_settings_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    dismissAdminTopNotice();
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
      capabilities: ['admin.access'],
    );
  });

  tearDown(() async {
    dismissAdminTopNotice();
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

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-hub-custom-Ishchi qo‘shish')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ali ishchi');
    await tester.tap(find.text('Brigader').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Master').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ishchi qo‘shish'));
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

  testWidgets('worker name can be edited from worker settings', (tester) async {
    await MobileApi.instance.adminCreateWorker(
      name: 'Eski ism',
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
    await tester.tap(find.text('Eski ism'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ismni o‘zgartirish'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('worker-name-field')),
      'Yangi ism',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Ishchi ismi saqlandi'), findsOneWidget);
    expect(find.text('Yangi ism'), findsWidgets);
    expect(find.text('Eski ism'), findsNothing);
    expect((await MobileApi.instance.adminWorkers()).single.name, 'Yangi ism');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker group is owned by the selected canonical apparatus', (
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

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('admin-hub-custom-Guruh qo‘shish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laminatsiya 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('worker-group-code-dialog-input')), 'ab');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AB guruh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Laminatsiya 1'), findsWidgets);
    await tester.tap(find.byKey(const Key('worker-group-save')));
    await tester.pumpAndSettle();

    final assigned = await MobileApi.instance.adminWorkerGroups(
      apparatusId: 'apparatus:default:asset-007',
    );
    expect(assigned.map((group) => group.groupCode), contains('AB'));
    expect(
      (await MobileApi.instance.adminRoleAssignments()).where(
        (assignment) => assignment.principalRole == UserRole.aparatchi,
      ),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker apparatus can be assigned from the workers tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final worker = await MobileApi.instance.adminCreateWorker(
      name: 'Aparat ishchisi',
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
    await tester.tap(find.text('Aparat ishchisi'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('worker-apparatus-picker-${worker.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aparatchi aparatlari'), findsWidgets);
    await tester.tap(find.text('Laminatsiya 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-apparatus-save')));
    await tester.pumpAndSettle();

    final assignments = await MobileApi.instance.adminRoleAssignments();
    final assignment = assignments.firstWhere(
      (item) => item.principalRef == worker.id,
    );
    expect(assignment.principalRole, UserRole.aparatchi);
    expect(assignment.assignedApparatus, ['apparatus:default:asset-007']);
    expect(find.text('Laminatsiya 1'), findsWidgets);
    expect(find.text('apparatus:default:asset-007'), findsNothing);

    await tester.tap(
      find.byKey(ValueKey('worker-apparatus-picker-${worker.id}')),
    );
    await tester.pumpAndSettle();
    final selectedTile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Laminatsiya 1'),
    );
    expect(selectedTile.value, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker apparatus duplicate assignment is reported clearly', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final worker = await MobileApi.instance.adminCreateWorker(
      name: 'Aparati allaqachon biriktirilgan ishchi',
      level: 'Master',
    );
    await MobileApi.instance.adminUpsertRoleAssignment(
      AdminRoleAssignment(
        principalRole: UserRole.aparatchi,
        principalRef: worker.id,
        roleId: 'aparatchi',
        assignedApparatus: const ['apparatus:default:asset-007'],
        assignedItemGroups: const [],
      ),
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
    await tester.tap(find.text('Aparati allaqachon biriktirilgan ishchi'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('worker-apparatus-picker-${worker.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-apparatus-save')));
    await tester.pumpAndSettle();

    expect(
      find.text('Laminatsiya 1 bu foydalanuvchi uchun allaqachon saqlangan'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker group name can be renamed from edit mode',
      (tester) async {
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
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-hub-custom-Guruh qo‘shish')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('worker-group-code-dialog-input')),
      'ab',
    );
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    dismissAdminTopNotice();
    await tester.pumpAndSettle();

    await tester.tap(find.text('AB guruh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('worker-group-name-field')),
      'A laminatsiya',
    );
    await tester.tap(find.byKey(const Key('worker-group-save')));
    await tester.pumpAndSettle();

    final groups = await MobileApi.instance.adminWorkerGroups();
    expect(groups.map((group) => group.groupCode), contains('A LAMINATSIYA'));
    expect(groups.map((group) => group.groupCode), isNot(contains('AB')));
    expect(find.text('A LAMINATSIYA guruh'), findsOneWidget);
    dismissAdminTopNotice();
    await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('admin-hub-custom-Guruh qo‘shish')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('worker-group-code-dialog-input')), 'b guruh');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    dismissAdminTopNotice();
    await tester.pumpAndSettle();

    expect(find.text('B GURUH guruh'), findsOneWidget);
    await tester.tap(find.text('B GURUH guruh'));
    await tester.pumpAndSettle();
    expect(find.text('B GURUH guruh ma’lumoti'), findsOneWidget);
    expect(find.text('Biriktirilmagan'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('B GURUH guruh sozlamalari'), findsOneWidget);
    expect(find.text('Ish vaqti'), findsOneWidget);
    expect(find.text('Haftalik ish kuni'), findsOneWidget);
    expect(find.text('Schot hisoblanadi'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('worker-group-worker-picker')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vali guruhchi'), findsOneWidget);
    await tester.tap(find.text('Vali guruhchi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ishchilarni tasdiqlash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('worker-group-save')));
    await tester.pumpAndSettle();

    expect(find.text('B GURUH guruh sozlamalari'), findsNothing);
    expect(find.text('B GURUH guruh ma’lumoti'), findsOneWidget);
    expect(find.text('Bekor qilish'), findsNothing);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('admin-hub-custom-Guruh qo‘shish')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('worker-group-code-dialog-input')), 'dd');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DD guruh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('worker-group-worker-picker')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vali guruhchi'), findsNothing);
    expect(find.text('Soli guruhchi'), findsOneWidget);
    await tester.tap(find.text('Soli guruhchi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ishchilarni tasdiqlash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('worker-group-save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('admin-hub-custom-Guruh qo‘shish')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('worker-group-code-dialog-input')), 'ee');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EE guruh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('worker-group-worker-picker')), findsOneWidget);
    expect(find.text('Vali guruhchi'), findsNothing);
    expect(find.text('Soli guruhchi'), findsNothing);
    expect(
      find.text('Ishchilar boshqa guruhlarga biriktirilgan'),
      findsOneWidget,
    );
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

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-hub-custom-Guruh qo‘shish')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('worker-group-code-dialog-input')), 'ab');
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Ishchilar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-hub-custom-Ishchi qo‘shish')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Yangi ishchi');
    await tester.tap(find.widgetWithText(FilledButton, 'Ishchi qo‘shish'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Guruhlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AB guruh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('worker-group-worker-picker')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yangi ishchi'), findsOneWidget);
  });

  testWidgets('worker without dependencies is deactivated after confirmation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await MobileApi.instance.adminCreateWorker(
      name: 'O‘chiriladigan ishchi',
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
    await tester.tap(find.text('O‘chiriladigan ishchi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_off_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Ishchini faolsizlantirish'), findsOneWidget);
    expect(
      find.text(
        '“O‘chiriladigan ishchi” ishchisi faolsizlantiriladi. U tizimga kira olmaydi, ammo oldingi ish tarixi saqlanadi. Tasdiqlaysizmi?',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Bekor qilish'), findsOneWidget);
    final cancelRect = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Bekor qilish'),
    );
    final deactivateRect = tester.getRect(
      find.widgetWithText(FilledButton, 'Faolsizlantirish'),
    );
    expect(cancelRect.width, closeTo(deactivateRect.width, 0.1));
    expect(cancelRect.bottom, lessThan(deactivateRect.top));
    await tester.tap(find.widgetWithText(FilledButton, 'Faolsizlantirish'));
    await tester.pumpAndSettle();

    expect(find.text('Ishchi faolsizlantirildi'), findsOneWidget);
    expect(find.text('O‘chiriladigan ishchi'), findsNothing);
    expect(await MobileApi.instance.adminWorkers(), isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('worker connections are listed before deactivation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final worker = await MobileApi.instance.adminCreateWorker(
      name: 'Guruhdagi ishchi',
      level: 'Brigader',
    );
    await MobileApi.instance.adminSaveWorkerGroup(
      AdminWorkerGroup(
        apparatus: 'Laminatsiya 1',
        apparatusId: 'apparatus:default:asset-007',
        groupCode: 'AB',
        shift: 'kunduz',
        workerIds: [worker.id],
      ),
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
    await tester.tap(find.text('Guruhdagi ishchi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_off_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Guruh: AB • Laminatsiya 1'), findsOneWidget);
    expect(find.text('Apparat: Laminatsiya 1'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Faolsizlantirish'));
    await tester.pumpAndSettle();

    expect(find.text('Guruhdagi ishchi'), findsNothing);
    final groups = await MobileApi.instance.adminWorkerGroups(
      apparatusId: 'apparatus:default:asset-007',
    );
    expect(groups.single.workerIds, isEmpty);
    await tester.pump(const Duration(seconds: 2));
  });
}
