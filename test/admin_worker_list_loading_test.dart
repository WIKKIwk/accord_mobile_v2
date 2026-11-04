import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_suppliers_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_users_role_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _admin = SessionProfile(
  role: UserRole.admin,
  displayName: 'Admin',
  legalName: 'Admin',
  ref: 'admin-test',
  phone: '998900000000',
  avatarUrl: '',
  capabilities: ['admin.access'],
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    await SavedAccountRuntime.instance.initialize(
      baseUrl: MobileApi.baseUrl,
      secretStore: _MemoryAccountSecrets(),
    );
    await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: MobileApi.baseUrl,
      profile: _admin,
      token: 'original-token',
      phone: _admin.phone,
      code: '123456',
      makeActive: true,
    );
    await AppSession.instance
        .setSession(token: 'original-token', profile: _admin);
    await AdminUsersRoleStore.instance.saveRole(AdminUserKind.worker);
    AdminSuppliersScreen.invalidateCache();
  });

  tearDown(() {
    AdminUsersRoleStore.instance.clearCache();
  });

  testWidgets('renders the worker list after automatic reauthentication', (
    tester,
  ) async {
    final workerRequests = <String?>[];
    var loginRequests = 0;
    await _pumpUsers(tester, (request) async {
      if (request.url.path == '/v1/mobile/auth/login') {
        loginRequests++;
        return http.Response(
            jsonEncode({
              'token': 'refreshed-token',
              'profile': _admin.toJson(),
              'capabilities': _admin.capabilities,
            }),
            200);
      }
      if (request.url.path == '/v1/mobile/admin/role-assignments') {
        return http.Response('[]', 200);
      }
      _expectWorkerListRequest(request);
      final token = request.headers['Authorization'];
      workerRequests.add(token);
      if (token == 'Bearer original-token') {
        return http.Response('{}', 401);
      }
      return _workerPage();
    });

    expect(loginRequests, 1);
    expect(workerRequests, ['Bearer original-token', 'Bearer refreshed-token']);
    expect(find.text('Test worker'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('loads workers independently of the role assignments API', (
    tester,
  ) async {
    var roleRequests = 0;
    await _pumpUsers(tester, (request) async {
      if (request.url.path == '/v1/mobile/admin/role-assignments') {
        roleRequests++;
        return http.Response('{}', 500);
      }
      _expectWorkerListRequest(request);
      return _workerPage();
    });

    expect(roleRequests, 0);
    expect(find.text('Test worker'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpUsers(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) respond,
) {
  final client = MockClient(respond);
  addTearDown(client.close);
  return http.runWithClient(() async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminSuppliersScreen(),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  }, () => client);
}

void _expectWorkerListRequest(http.Request request) {
  expect(request.method, 'GET');
  expect(request.url.path, '/v1/mobile/admin/users/list');
  expect(request.url.queryParameters['role'], 'worker');
}

http.Response _workerPage() => http.Response(
    jsonEncode({
      'items': [
        {
          'id': 'worker:test',
          'source': 'worker',
          'entity_ref': 'test',
          'principal_role': 'aparatchi',
          'name': 'Test worker',
          'role_label': 'Master',
        }
      ],
      'has_more': false,
    }),
    200);

class _MemoryAccountSecrets implements AccountSecretStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
