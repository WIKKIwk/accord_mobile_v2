import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_user_create_screen_test_helpers_part_01.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('admin user create screen picks role from bottom sheet', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);

      expect(find.text('Role tanlash'), findsOneWidget);
      expect(find.text('Role tanlang'), findsOneWidget);
      expect(find.text('Omborchi'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(seenRequests, contains('GET /v1/mobile/admin/roles'));

      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      expect(find.text('Role tanlang'), findsWidgets);
      expect(find.text('Item yaratuvchi'), findsOneWidget);
      await _selectPickerItem(tester, 'Item yaratuvchi');
      expect(find.text('Code'), findsNothing);
      expect(find.text('Omborchi saqlash'), findsNothing);
      expect(find.text('Foydalanuvchi saqlash'), findsOneWidget);

      await tester.tap(find.text('Item yaratuvchi').first);
      await _pumpUi(tester);
      expect(find.text('Role tanlang'), findsWidgets);
      await _selectPickerItem(tester, 'Haridor');

      await tester.enterText(find.byType(TextField).at(0), 'Ali Market');
      await tester.enterText(find.byType(TextField).at(1), '+998900001111');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('POST /v1/mobile/admin/customers'));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen assigns aparatchi role', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Aparatchi');

      expect(find.text('Foydalanuvchi saqlash'), findsOneWidget);
      for (var i = 0;
          i < 20 && find.text('7 ta rangli pechat').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('7 ta rangli pechat'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Aparatchi');
      await tester.enterText(find.byType(TextField).at(1), '110000011');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('POST /v1/mobile/admin/customers'));
      expect(seenRequests, contains('PUT /v1/mobile/admin/role-assignments'));
      expect(
        seenRequests.any(
          (request) => request.contains('"role_id":"aparatchi"'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen creates qolipchi as system user', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Qolipchi');

      await tester.enterText(find.byType(TextField).at(0), 'Qolipchi');
      await tester.enterText(find.byType(TextField).at(1), '110000050');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('POST /v1/mobile/admin/system-users'));
      expect(
        seenRequests,
        contains(
          'POST /v1/mobile/admin/system-users/code/regenerate?id=qolipchi-q',
        ),
      );
      expect(seenRequests, isNot(contains('POST /v1/mobile/admin/customers')));
      expect(
        seenRequests.any((request) => request.contains('/admin/workers')),
        isFalse,
      );
      expect(
        seenRequests.any(
          (request) => request.contains('"role":"qolipchi"'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen adds standard boyoqchi role', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(
      seenRequests,
      boyoqchiSystemUser: true,
    );

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Bo‘yoqchi');

      await tester.enterText(find.byType(TextField).at(0), 'Bo‘yoqchi');
      await tester.enterText(find.byType(TextField).at(1), '110000080');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        seenRequests,
        contains(
          'POST /v1/mobile/admin/system-users/code/regenerate?id=boyoqchi-q',
        ),
      );
      expect(
        seenRequests.any((request) => request.contains('"role":"boyoqchi"')),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen assigns material taminotchi role', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);

      expect(find.text('Material taminotchisi'), findsOneWidget);

      await _selectPickerItem(tester, 'Material taminotchisi');
      await _selectMaterialItemGroups(tester, const ['Kraska']);
      await tester.enterText(find.byType(TextField).at(0), 'Materialchi');
      await tester.enterText(find.byType(TextField).at(1), '110000060');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        seenRequests,
        contains('POST /v1/mobile/admin/material-taminotchilar'),
      );
      expect(
        seenRequests,
        isNot(contains('PUT /v1/mobile/admin/role-assignments')),
      );
      expect(
        seenRequests,
        isNot(
          contains('POST /v1/mobile/admin/customers/code/regenerate?ref=CUS-1'),
        ),
      );
      expect(seenRequests, isNot(contains('POST /v1/mobile/admin/customers')));
      expect(seenRequests, isNot(contains('POST /v1/mobile/admin/workers')));
      expect(
        seenRequests.any(
          (request) => request.contains('"role_id":"material_taminotchi"'),
        ),
        isFalse,
      );
      expect(
        seenRequests.any(
          (request) =>
              request.contains('"principal_role":"material_taminotchi"'),
        ),
        isFalse,
      );
      expect(
        seenRequests.any(
          (request) => request.contains('"assigned_item_groups":["Kraska"]'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen requires material item groups', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Material taminotchisi');
      await _waitForMaterialItemGroupSelector(tester);

      expect(find.text('Mahsulot guruhlari'), findsOneWidget);
      expect(find.text('Guruh tanlang'), findsOneWidget);
      var saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      expect(saveButton.onPressed, isNull);

      await tester.tap(find.text('Guruh tanlang').first);
      await _pumpUi(tester);
      expect(find.text('Mahsulot guruhlarini tanlang'), findsOneWidget);
      await tester.tap(find.text('Kraska').last);
      await tester.pump();
      await tester.tap(find.text('Kley').last);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Tanlash'));
      await _pumpUi(tester);

      expect(find.text('Kley, Kraska'), findsOneWidget);
      saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      expect(saveButton.onPressed, isNotNull);

      await tester.enterText(find.byType(TextField).at(0), 'Materialchi');
      await tester.enterText(find.byType(TextField).at(1), '110000060');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('GET /v1/mobile/admin/item-groups'));
      expect(
        seenRequests.any(
          (request) => request.contains(
            '"assigned_item_groups":["Kley","Kraska"]',
          ),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen shows backend role assignment error', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(
      seenRequests,
      roleAssignmentStatusCode: HttpStatus.badRequest,
      roleAssignmentBody: const {'error': 'forbidden'},
    );

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Material taminotchisi');
      await _selectMaterialItemGroups(tester, const ['Kraska']);
      await tester.enterText(find.byType(TextField).at(0), 'Materialchi');
      await tester.enterText(find.byType(TextField).at(1), '110000060');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        seenRequests,
        contains('POST /v1/mobile/admin/material-taminotchilar'),
      );
      expect(
        seenRequests,
        isNot(contains('PUT /v1/mobile/admin/role-assignments')),
      );
      expect(find.text('forbidden'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen falls back to material role', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(
      seenRequests,
      includeMaterialRole: false,
    );

    await HttpOverrides.runZoned(() async {
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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);

      expect(find.text('Material taminotchisi'), findsOneWidget);

      await _selectPickerItem(tester, 'Material taminotchisi');
      await _selectMaterialItemGroups(tester, const ['Kraska']);
      await tester.enterText(find.byType(TextField).at(0), 'Materialchi');
      await tester.enterText(find.byType(TextField).at(1), '110000060');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        seenRequests,
        contains('POST /v1/mobile/admin/material-taminotchilar'),
      );
      expect(
        seenRequests,
        isNot(contains('PUT /v1/mobile/admin/role-assignments')),
      );
      expect(
        seenRequests.any(
          (request) => request.contains('"role_id":"material_taminotchi"'),
        ),
        isFalse,
      );
      expect(
        seenRequests.any(
          (request) =>
              request.contains('"principal_role":"material_taminotchi"'),
        ),
        isFalse,
      );
      expect(
        seenRequests.any(
          (request) => request.contains('"assigned_item_groups":["Kraska"]'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });
}
