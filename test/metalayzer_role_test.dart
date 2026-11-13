import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'metalayzer',
      'display_name': 'Metalayzer',
      'ref': 'metalayzer-test',
      'capabilities': ['metalayzer.access'],
    });
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('native role survives session storage and directory decoding', () async {
    final session = AppSession.instance;
    await session.setSession(token: 'token', profile: session.profile!);
    session.token = null;
    session.profile = null;
    await session.load();
    final profile = session.profile!;
    expect(profile.role, UserRole.metalayzer);
    expect(profile.accessRole, UserRole.metalayzer);
    expect(profile.toJson()['role'], 'metalayzer');
    expect(profile.isCapabilityOnlyProfile, isFalse);
    expect(profile.hasWorkspaceAccess, isTrue);
    expect(session.homeRoute, '/metalayzer');
    expect(session.canUseAdminComponents, isFalse);
    final entry = AdminUserListEntry.fromJson({
      'source': 'system_user',
      'principal_role': 'metalayzer',
      'entity_ref': 'metalayzer-test',
      'name': 'Metalayzer',
    });
    expect(entry.kind, AdminUserKind.metalayzer);
    expect(entry.roleLabel, 'Metalayzer');
  });

  test('workspace access requires its dedicated capability', () {
    AppSession.instance.profile =
        AppSession.instance.profile!.copyWith(capabilities: []);
    expect(AppSession.instance.profile!.accessRole, isNull);
    expect(AppSession.instance.homeRoute, '/');
  });

  test('system-user demo create, code and directory preserve the new role',
      () async {
    await TestModeController.instance.setEnabled(true);
    addTearDown(() async {
      await TestModeController.instance.setEnabled(false);
      resetMobileApiTestModeWorkerSettingsData();
    });
    final api = MobileApi.instance;
    final user = await api.adminCreateSystemUser(
      role: UserRole.metalayzer,
      name: 'Metalchi',
      phone: '901234567',
    );
    final detail = await api.adminRegenerateSystemUserCode(user.id);
    final page = await api.adminUserList(role: 'metalayzer');
    expect(detail.role, UserRole.metalayzer);
    expect(detail.code, startsWith('95'));
    expect(page.items.single.kind, AdminUserKind.metalayzer);
    expect(page.items.single.principalRole, UserRole.metalayzer);
  });

  testWidgets('existing admin form creates a Metalayzer system user',
      (tester) async {
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'admin',
      'ref': 'admin',
      'display_name': 'Admin',
      'capabilities': ['admin.access'],
    });
    final writes = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      final Object body;
      if (path == '/v1/mobile/admin/roles') {
        body = [
          {
            'id': 'metalayzer',
            'label': 'Metalayzer',
            'base_role': 'metalayzer',
            'capability_codes': ['metalayzer.access'],
            'system': true,
          },
        ];
      } else if (path == '/v1/mobile/admin/system-users') {
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {
          'role': 'metalayzer',
          'name': 'Metalchi',
          'phone': '901234567',
        });
        writes.add(path);
        body = {
          'id': 'metalayzer-test',
          'role': 'metalayzer',
          'name': 'Metalchi',
          'phone': '901234567',
        };
      } else if (path == '/v1/mobile/admin/system-users/code/regenerate') {
        expect(request.method, 'POST');
        expect(request.url.queryParameters['id'], 'metalayzer-test');
        writes.add(path);
        body = {
          'id': 'metalayzer-test',
          'role': 'metalayzer',
          'name': 'Metalchi',
          'phone': '901234567',
          'code': '951234567890',
        };
      } else {
        throw StateError('Unexpected ${request.method} $path');
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdminUserCreateScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Role tanlang').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Metalayzer').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Metalchi');
      await tester.enterText(find.byType(TextField).at(1), '901234567');
      await tester
          .tap(find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'));
      await tester.pumpAndSettle();
      expect(writes, [
        '/v1/mobile/admin/system-users',
        '/v1/mobile/admin/system-users/code/regenerate',
      ]);
      expect(find.text('951234567890'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
