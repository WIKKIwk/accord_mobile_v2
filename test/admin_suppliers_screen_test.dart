import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_suppliers_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_profile_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _selectUserRole(WidgetTester tester, String role) async {
  await tester.tap(find.byKey(const ValueKey('admin-users-role-picker')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(role).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
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
    AdminSuppliersScreen.invalidateCache();
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    AdminSuppliersScreen.invalidateCache();
  });

  testWidgets('admin users list refreshes after custom role user create', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final client = _AdminUsersHttpClient();

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routes: {
            AppRoutes.adminSuppliers: (_) => const AdminSuppliersScreen(),
            AppRoutes.adminUserCreate: (_) => const AdminUserCreateScreen(),
          },
          home: const AdminSuppliersScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rollar tanlanmagan'), findsOneWidget);

      navigatorKey.currentState!.pushNamed(AppRoutes.adminUserCreate);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Role tanlang').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Item yaratuvchi'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'chichqoq');
      await tester.enterText(find.byType(TextField).at(1), '998901234567');
      final saveButton = find.widgetWithText(
        FilledButton,
        'Foydalanuvchi saqlash',
      );
      tester.widget<FilledButton>(saveButton).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await _selectUserRole(tester, 'Haridor');
      await tester.enterText(find.byType(TextField).first, 'chichqoq');
      for (var i = 0; i < 20 && client.requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text('chichqoq'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Item yaratuvchi'), findsOneWidget);
      expect(find.textContaining('Customer'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin users list does not eagerly load every page on open', (
    tester,
  ) async {
    final client = _AdminUsersHttpClient(
      users: List<Object>.generate(
        50,
        (index) => {
          'id': 'supplier:SUP-$index',
          'source': 'supplier',
          'entity_ref': 'SUP-$index',
          'name': 'Supplier $index',
          'phone': '99890000$index',
          'role_label': 'Supplier',
          'blocked': false,
        },
      ),
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
          routes: {
            AppRoutes.adminWorkerDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerDetailScreen(entry: entry);
            },
            AppRoutes.adminWorkerProfileDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerProfileDetailScreen(entry: entry);
            },
          },
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0; i < 20 && client.requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50'),
      );
      expect(
        client.requests,
        isNot(contains('GET /v1/mobile/admin/users/list?limit=50&offset=50')),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin users list opens from one merged paged endpoint', (
    tester,
  ) async {
    final client = _AdminUsersHttpClient(
      users: const [
        {
          'id': 'supplier:SUP-1',
          'source': 'supplier',
          'entity_ref': 'SUP-1',
          'name': 'Supplier One',
          'phone': '998900001',
          'role_label': 'Supplier',
          'blocked': false,
        },
        {
          'id': 'customer:CUS-1',
          'source': 'customer',
          'entity_ref': 'CUS-1',
          'name': 'Customer One',
          'phone': '998900002',
          'role_label': 'Item yaratuvchi',
          'blocked': false,
        },
      ],
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
          routes: {
            AppRoutes.adminWorkerDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerDetailScreen(entry: entry);
            },
            AppRoutes.adminWorkerProfileDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerProfileDetailScreen(entry: entry);
            },
          },
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0; i < 20 && client.requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50'),
      );
      expect(client.requests, isNot(contains('GET /v1/mobile/admin/settings')));
      expect(
        client.requests,
        isNot(contains('GET /v1/mobile/admin/suppliers/list?limit=50')),
      );
      expect(
        client.requests,
        isNot(contains('GET /v1/mobile/admin/customers/list?limit=50')),
      );
      await _selectUserRole(tester, 'Ta’minotchi');
      for (var i = 0;
          i < 20 && find.text('Supplier One').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Supplier One'), findsOneWidget);
      expect(find.text('Customer One'), findsNothing);

      await _selectUserRole(tester, 'Haridor');
      expect(find.text('Supplier One'), findsNothing);
      expect(find.text('Customer One'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin users list filters workers from worker list', (
    tester,
  ) async {
    final client = _AdminUsersHttpClient(
      users: const [
        {
          'id': 'supplier:SUP-1',
          'source': 'supplier',
          'entity_ref': 'SUP-1',
          'name': 'Supplier One',
          'phone': '998900001',
          'role_label': 'Supplier',
          'blocked': false,
        },
      ],
      workers: const [
        {'id': 'worker-1', 'name': 'Jasur worker', 'level': 'Master'},
        {'id': 'worker-2', 'name': 'Ali worker', 'level': 'Brigader'},
      ],
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
          routes: {
            AppRoutes.adminWorkerDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerDetailScreen(entry: entry);
            },
            AppRoutes.adminWorkerProfileDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerProfileDetailScreen(entry: entry);
            },
          },
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0;
          i < 20 &&
              find
                  .byKey(const ValueKey('admin-users-role-picker'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('admin-users-role-picker')),
          findsOneWidget);
      expect(find.text('Supplier One'), findsNothing);
      expect(find.text('Jasur worker'), findsNothing);

      await _selectUserRole(tester, 'Ta’minotchi');
      expect(find.text('Ta’minotchi'), findsOneWidget);
      expect(find.text('Rollar tanlanmagan'), findsNothing);
      for (var i = 0;
          i < 20 && find.text('Supplier One').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Supplier One'), findsOneWidget);

      await _selectUserRole(tester, 'Ishchi');
      expect(find.text('Supplier One'), findsNothing);
      expect(find.text('Jasur worker'), findsOneWidget);
      expect(find.text('Ali worker'), findsOneWidget);
      expect(find.textContaining('Master'), findsOneWidget);

      await tester.tap(find.text('Jasur worker'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Admin boshqaruv'), findsNothing);

      await tester.tap(find.byKey(
        const ValueKey('admin-worker-detail-admin-toggle'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Admin boshqaruv'), findsOneWidget);
      expect(find.text('Telefon'), findsOneWidget);
      expect(find.text('Kiritilmagan'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-worker-detail-phone-action')),
        findsOneWidget,
      );
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('admin-worker-detail-phone-action')),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('admin-worker-detail-phone-input')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-worker-detail-phone-input')),
        '+998901112233',
      );
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('admin-worker-detail-phone-action')),
          )
          .onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('+998901112233'), findsWidgets);
      expect(client.requests, contains('PUT /v1/mobile/admin/workers'));
      expect(find.text('Kirish kodi'), findsOneWidget);
      expect(find.text('Hali generatsiya qilinmagan'), findsOneWidget);

      final refreshButton = find.ancestor(
        of: find.byIcon(Icons.refresh_rounded),
        matching: find.byType(IconButton),
      );
      tester.widget<IconButton>(refreshButton).onPressed!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('401234567890'), findsOneWidget);
      expect(
        client.requests,
        contains('POST /v1/mobile/admin/workers/code/regenerate?id=worker-1'),
      );

      await tester.drag(find.byType(ListView).last, const Offset(0, -360));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ish faoliyati tafsilotlari'));
      await tester.pumpAndSettle();
      expect(find.text('Assign qilingan guruhlar'), findsOneWidget);
      expect(find.text('7 ta rangli pechat'), findsWidgets);
      expect(find.text('Aktiv ishlar'), findsOneWidget);
      expect(find.textContaining('zakaz-worker-1'), findsOneWidget);
      expect(
          find.text('Progress batchlar', skipOffstage: false), findsOneWidget);
      expect(find.text('Loglar', skipOffstage: false), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin qolipchi tab opens worker backed qolipchi profile', (
    tester,
  ) async {
    final client = _AdminUsersHttpClient(
      workers: const [
        {
          'id': 'worker-q',
          'name': 'Qolipchi user',
          'phone': '998900003',
          'level': 'Master',
        },
      ],
      roleAssignments: const [
        {
          'principal_role': 'qolipchi',
          'principal_ref': 'worker-q',
          'role_id': 'qolipchi',
        },
      ],
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
          routes: {
            AppRoutes.adminWorkerDetail: (context) {
              final entry = ModalRoute.of(context)!.settings.arguments!
                  as AdminUserListEntry;
              return AdminWorkerDetailScreen(entry: entry);
            },
          },
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0; i < 20 && client.requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _selectUserRole(tester, 'Qolipchi');
      expect(find.text('Qolipchi user'), findsOneWidget);

      await tester.tap(find.text('Qolipchi user'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Qolipchi'), findsWidgets);
      expect(find.text('Qolipchi user'), findsWidgets);
      expect(find.text('998900003'), findsWidgets);
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/workers/detail?id=worker-q'),
      );
      expect(
        client.requests.any(
          (request) => request.startsWith(
            'GET /v1/mobile/admin/customers/detail',
          ),
        ),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });
}

class _AdminUsersHttpClient implements HttpClient {
  _AdminUsersHttpClient({
    this.users = const <Object>[],
    this.workers = const <Object>[],
    this.roleAssignments = const <Object>[],
  });

  final List<Object> users;
  final List<Object> workers;
  final List<Object> roleAssignments;
  final List<String> requests = <String>[];
  bool createdCustomer = false;
  final Map<String, String> workerCodes = <String, String>{};

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    requests.add(key);

    Object body;
    var statusCode = HttpStatus.ok;
    if (key.startsWith('GET /v1/mobile/admin/workers/profile-detail')) {
      final id = url.queryParameters['id'] ?? '';
      final worker = workers.cast<Map<String, Object?>>().firstWhere(
            (item) => item['id'] == id,
            orElse: () => <String, Object?>{},
          );
      if (worker.isEmpty) {
        statusCode = HttpStatus.notFound;
        body = {'error': 'worker not found'};
      } else {
        body = {
          'worker': {
            'id': worker['id'],
            'name': worker['name'],
            'phone': worker['phone'] ?? '',
            'level': worker['level'] ?? '',
            'code': workerCodes[id] ?? '',
            'code_locked': false,
            'code_retry_after_sec': 0,
          },
          'assigned_groups': [
            {
              'apparatus': '7 ta rangli pechat',
              'group_code': 'A',
              'shift': 'kunduz',
              'start_time': '08:00',
              'end_time': '20:00',
              'work_days_per_week': 6,
              'start_day': 'monday',
              'accounting_enabled': true,
              'worker_ids': [id],
              'workers': [worker],
            },
          ],
          'active_sessions': [
            {
              'session_id': 'session-worker-1',
              'apparatus': '7 ta rangli pechat',
              'order_id': 'zakaz-worker-1',
              'status': 'active',
              'worker_role': 'aparatchi',
              'worker_ref': id,
              'worker_display_name': worker['name'],
              'started_at_unix': 1,
              'updated_at_unix': 2,
            },
          ],
          'recent_batches': [
            {
              'batch_id': 'batch-worker-1',
              'session_id': 'session-worker-1',
              'apparatus': '7 ta rangli pechat',
              'order_id': 'zakaz-worker-1',
              'action': 'pause',
              'status': 'paused',
              'produced_qty': 12,
              'uom': 'kg',
              'qr_payload': '4001ABC',
              'label_item_code': 'VESTA',
              'label_item_name': 'Vesta',
              'executor_name': worker['name'],
            },
          ],
          'recent_logs': [
            {
              'event_id': 'event-worker-1',
              'apparatus': '7 ta rangli pechat',
              'order_id': 'zakaz-worker-1',
              'action': 'start',
              'from_state': 'pending',
              'to_state': 'in_progress',
              'actor_role': 'aparatchi',
              'actor_ref': id,
              'actor_display_name': worker['name'],
              'created_at_unix': 2,
            },
          ],
        };
      }
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    if (key.startsWith('GET /v1/mobile/admin/workers/detail')) {
      final id = url.queryParameters['id'] ?? '';
      final worker = workers.cast<Map<String, Object?>>().firstWhere(
            (item) => item['id'] == id,
            orElse: () => <String, Object?>{},
          );
      if (worker.isEmpty) {
        statusCode = HttpStatus.notFound;
        body = {'error': 'worker not found'};
      } else {
        body = {
          'id': worker['id'],
          'name': worker['name'],
          'phone': worker['phone'] ?? '',
          'level': worker['level'] ?? '',
          'code': workerCodes[id] ?? '',
          'code_locked': false,
          'code_retry_after_sec': 0,
        };
      }
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    if (key.startsWith('GET /v1/mobile/admin/customers/detail')) {
      final ref = url.queryParameters['ref'] ?? '';
      final user = users.cast<Map<String, Object?>>().firstWhere(
            (item) => (item['entity_ref'] ?? item['id']) == ref,
            orElse: () => <String, Object?>{},
          );
      if (user.isEmpty) {
        statusCode = HttpStatus.notFound;
        body = {'error': 'customer not found'};
      } else {
        body = {
          'ref': ref,
          'name': user['name'],
          'phone': user['phone'] ?? '',
          'code': '50QOLIP',
          'code_locked': false,
          'code_retry_after_sec': 0,
          'assigned_items': [],
        };
      }
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    if (key.startsWith('POST /v1/mobile/admin/workers/code/regenerate')) {
      final id = url.queryParameters['id'] ?? '';
      final worker = workers.cast<Map<String, Object?>>().firstWhere(
            (item) => item['id'] == id,
            orElse: () => <String, Object?>{},
          );
      if (worker.isEmpty) {
        statusCode = HttpStatus.notFound;
        body = {'error': 'worker not found'};
      } else {
        workerCodes[id] = '401234567890';
        body = {
          'id': worker['id'],
          'name': worker['name'],
          'phone': worker['phone'] ?? '',
          'level': worker['level'] ?? '',
          'code': workerCodes[id],
          'code_locked': false,
          'code_retry_after_sec': 0,
        };
      }
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    if (key == 'PUT /v1/mobile/admin/workers') {
      body = const {
        'id': 'worker-1',
        'name': 'Jasur worker',
        'phone': '+998901112233',
        'level': 'Master',
      };
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    if (key.startsWith('GET /v1/mobile/admin/users/list')) {
      body = {
        'items': createdCustomer && users.isEmpty
            ? const [
                {
                  'id': 'customer:CUS-1',
                  'source': 'customer',
                  'entity_ref': 'CUS-1',
                  'name': 'chichqoq',
                  'phone': '998901234567',
                  'role_label': 'Item yaratuvchi',
                  'blocked': false,
                },
              ]
            : users,
        'has_more': false,
      };
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    if (key.startsWith('GET /v1/mobile/admin/workers')) {
      body = workers;
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(body),
          statusCode: statusCode,
        ),
      );
    }
    switch (key) {
      case 'GET /v1/mobile/admin/settings':
        body = const {
          'werka_name': '',
          'werka_phone': '',
          'werka_code': 'WERKA-1',
        };
      case 'GET /v1/mobile/admin/customers/list?limit=50':
        body = createdCustomer
            ? const [
                {'ref': 'CUS-1', 'name': 'chichqoq', 'phone': '998901234567'},
              ]
            : const [];
      case 'GET /v1/mobile/admin/roles':
        body = const [
          {
            'id': 'item_creator',
            'label': 'Item yaratuvchi',
            'capability_codes': ['catalog.item.read', 'catalog.item.create'],
            'system': false,
          },
        ];
      case 'GET /v1/mobile/admin/role-assignments':
        body = createdCustomer
            ? const [
                {
                  'principal_role': 'customer',
                  'principal_ref': 'CUS-1',
                  'role_id': 'item_creator',
                },
              ]
            : roleAssignments;
      case 'POST /v1/mobile/admin/customers':
        createdCustomer = true;
        body = const {
          'ref': 'CUS-1',
          'name': 'chichqoq',
          'phone': '998901234567',
        };
      case 'PUT /v1/mobile/admin/role-assignments':
        body = const {
          'principal_role': 'customer',
          'principal_ref': 'CUS-1',
          'role_id': 'item_creator',
        };
      default:
        statusCode = HttpStatus.notFound;
        body = {'error': 'Unhandled request: $key'};
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: statusCode,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final BytesBuilder _body = BytesBuilder();

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  void write(Object? object) {
    if (object != null) {
      _body.add(utf8.encode(object.toString()));
    }
  }

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _body.add(data);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    _body.clear();
    return response;
  }

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    add([charCode]);
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({required String body, required this.statusCode})
      : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  String get reasonPhrase => '';

  @override
  bool get persistentConnection => false;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      throw UnsupportedError('redirect');

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = <String>[value.toString()];
  }

  @override
  List<String>? operator [](String name) => _values[name];

  @override
  String? value(String name) => _values[name]?.join(',');

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
