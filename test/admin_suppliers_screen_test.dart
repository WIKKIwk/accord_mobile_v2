import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_suppliers_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_profile_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_suppliers_screen_test_helpers_part_01.dart';
part 'admin_suppliers_screen_test_models_part_02.dart';

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
      capabilities: ['admin.access'],
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
      expect(find.text('Rol: Tanlanmagan'), findsOneWidget);

      navigatorKey.currentState!.pushNamed(AppRoutes.adminUserCreate);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Role tanlang').last);
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
      await tester.enterText(find.byType(EditableText).first, 'chichqoq');
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
        client.requests.any(
          (request) => request.startsWith('GET /v1/mobile/admin/users/list'),
        ),
        isFalse,
      );

      await _selectUserRole(tester, 'Ta’minotchi');
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=supplier'),
      );
      expect(
        client.requests,
        isNot(contains('GET /v1/mobile/admin/users/list?limit=50&offset=50')),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin users cache is not reused after session changes', (
    tester,
  ) async {
    var userListCalls = 0;
    final client = _AdminUsersHttpClient(
      userListResponder: (_) async {
        userListCalls += 1;
        return _UserListResponse(
          items: [
            _supplierUser(
              userListCalls == 1 ? 'ADMIN-A' : 'ADMIN-B',
              userListCalls == 1 ? 'Admin A supplier' : 'Admin B supplier',
            ),
          ],
        );
      },
    );

    Future<void> pumpScreen() async {
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
          home: const AdminSuppliersScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await HttpOverrides.runZoned(() async {
      await pumpScreen();
      await _selectUserRole(tester, 'Ta’minotchi');
      expect(find.text('Admin A supplier'), findsOneWidget);
      expect(userListCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.admin,
        displayName: 'Admin B',
        legalName: 'Admin B',
        ref: 'ADMIN-002',
        phone: '',
        avatarUrl: '',
        capabilities: ['admin.access'],
      );
      AppSession.instance.revision.value++;

      await pumpScreen();
      expect(find.text('Admin A supplier'), findsNothing);
      expect(find.text('Rol: Tanlanmagan'), findsOneWidget);

      await _selectUserRole(tester, 'Ta’minotchi');
      expect(find.text('Admin B supplier'), findsOneWidget);
      expect(find.text('Admin A supplier'), findsNothing);
      expect(userListCalls, 2);

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
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=supplier'),
      );
      for (var i = 0;
          i < 20 && find.text('Supplier One').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Supplier One'), findsOneWidget);
      expect(find.text('Customer One'), findsNothing);

      await _selectUserRole(tester, 'Haridor');
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=customer'),
      );
      expect(find.text('Supplier One'), findsNothing);
      expect(find.text('Customer One'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin users list filters material taminotchi users', (
    tester,
  ) async {
    final client = _AdminUsersHttpClient(
      users: const [
        {
          'id': 'customer:CUS-1',
          'source': 'customer',
          'entity_ref': 'CUS-1',
          'name': 'Customer One',
          'phone': '998900002',
          'role_label': 'Customer',
          'blocked': false,
        },
        {
          'id': 'customer:CUS-MAT',
          'source': 'customer',
          'entity_ref': 'CUS-MAT',
          'name': 'Materialchi One',
          'phone': '998900003',
          'role_label': 'Customer',
          'blocked': false,
        },
      ],
      roleAssignments: const [
        {
          'principal_role': 'material_taminotchi',
          'principal_ref': 'CUS-MAT',
          'role_id': 'material_taminotchi',
          'assigned_item_groups': ['rulon'],
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
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0;
          i < 20 &&
              find
                  .byKey(const ValueKey('admin-users-role-filter-chip'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester
          .tap(find.byKey(const ValueKey('admin-users-role-filter-chip')));
      await tester.pumpAndSettle();
      expect(find.text('Material ta’minotchisi'), findsOneWidget);

      await tester.tap(find.text('Material ta’minotchisi').last);
      await tester.pumpAndSettle();
      expect(
        client.requests,
        contains(
          'GET /v1/mobile/admin/users/list?limit=50&role=material_taminotchi',
        ),
      );
      expect(find.text('Materialchi One'), findsOneWidget);
      expect(find.text('Customer One'), findsNothing);
      expect(find.textContaining('Material ta’minotchisi'), findsWidgets);

      await _selectUserRole(tester, 'Haridor');
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=customer'),
      );
      expect(find.text('Customer One'), findsOneWidget);
      expect(find.text('Materialchi One'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('material taminotchi row opens detail with material entry', (
    tester,
  ) async {
    Object? detailArguments;
    final client = _AdminUsersHttpClient(
      users: const [
        {
          'id': 'material_taminotchi:MAT-NEW',
          'source': 'material_taminotchi',
          'entity_ref': 'MAT-NEW',
          'name': 'Materialchi One',
          'phone': '998900003',
          'principal_role': 'material_taminotchi',
          'role_label': 'Material ta’minotchisi',
          'blocked': false,
        },
      ],
      roleAssignments: const [
        {
          'principal_role': 'material_taminotchi',
          'principal_ref': 'MAT-NEW',
          'role_id': 'material_taminotchi',
          'assigned_item_groups': ['rulon'],
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
            AppRoutes.adminCustomerDetail: (context) {
              detailArguments = ModalRoute.of(context)!.settings.arguments;
              return const Scaffold(body: Text('detail'));
            },
          },
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0;
          i < 20 &&
              find
                  .byKey(const ValueKey('admin-users-role-filter-chip'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _selectUserRole(tester, 'Material ta’minotchisi');
      await tester.tap(find.text('Materialchi One'));
      await tester.pumpAndSettle();

      expect(detailArguments, isA<AdminUserListEntry>());
      final entry = detailArguments! as AdminUserListEntry;
      expect(entry.id, 'MAT-NEW');
      expect(entry.kind, AdminUserKind.materialTaminotchi);
      expect(entry.principalRole, UserRole.materialTaminotchi);
      expect(entry.roleLabel, 'Material ta’minotchisi');

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin users list loads workers from unified profile list', (
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
                  .byKey(const ValueKey('admin-users-role-filter-chip'))
                  .evaluate()
                  .isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('admin-users-role-filter-chip')),
          findsOneWidget);
      expect(find.text('Supplier One'), findsNothing);
      expect(find.text('Jasur worker'), findsNothing);

      await _selectUserRole(tester, 'Ta’minotchi');
      expect(find.text('Rol: Ta’minotchi'), findsOneWidget);
      expect(find.text('Rol: Tanlanmagan'), findsNothing);
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=supplier'),
      );
      for (var i = 0;
          i < 20 && find.text('Supplier One').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Supplier One'), findsOneWidget);

      await _selectUserRole(tester, 'Ishchi');
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=worker'),
      );
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
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Ish faoliyati tafsilotlari'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Assign qilingan guruhlar'), findsOneWidget);
      expect(find.text('7 ta rangli pechat'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Aktiv ishlar'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Aktiv ishlar'), findsOneWidget);
      expect(find.textContaining('zakaz-worker-1'), findsWidgets);
      expect(
          find.text('Progress batchlar', skipOffstage: false), findsOneWidget);
      expect(find.text('Loglar', skipOffstage: false), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user search ignores a stale response from an old query', (
    tester,
  ) async {
    final aliStarted = Completer<void>();
    final releaseAli = Completer<void>();
    final client = _AdminUsersHttpClient(
      userListResponder: (url) async {
        final query = url.queryParameters['q'] ?? '';
        if (query == 'ali') {
          if (!aliStarted.isCompleted) {
            aliStarted.complete();
          }
          await releaseAli.future;
          return _UserListResponse(items: [_supplierUser('ALI', 'Ali')]);
        }
        if (query == 'vali') {
          return _UserListResponse(items: [_supplierUser('VALI', 'Vali')]);
        }
        return const _UserListResponse(items: []);
      },
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
          home: const AdminSuppliersScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await _selectUserRole(tester, 'Ta’minotchi');

      final search = find.byType(EditableText).first;
      await tester.enterText(search, 'ali');
      await tester.pump(const Duration(milliseconds: 221));
      for (var i = 0; i < 20 && !aliStarted.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(aliStarted.isCompleted, isTrue);

      await tester.enterText(search, 'vali');
      await tester.pump(const Duration(milliseconds: 221));
      for (var i = 0; i < 20 && find.text('Vali').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text('Vali'), findsOneWidget);
      expect(find.text('Ali'), findsNothing);

      releaseAli.complete();
      await tester.pumpAndSettle();
      expect(find.text('Vali'), findsOneWidget);
      expect(find.text('Ali'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets(
    'admin user search animates locally removed rows before server reconcile',
    (tester) async {
      final client = _AdminUsersHttpClient(
        userListResponder: (url) async {
          final query = url.queryParameters['q'] ?? '';
          if (query == 'ali') {
            return _UserListResponse(items: [_supplierUser('ALI', 'Ali')]);
          }
          if (query == 'alina') {
            return _UserListResponse(
              items: [_supplierUser('ALINA', 'Alina')],
            );
          }
          return const _UserListResponse(items: []);
        },
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
            home: const AdminSuppliersScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await _selectUserRole(tester, 'Ta’minotchi');

        final search = find.byType(EditableText).first;
        await tester.enterText(search, 'ali');
        await tester.pump(const Duration(milliseconds: 221));
        for (var i = 0; i < 20 && find.text('Ali').evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(find.text('Ali'), findsOneWidget);

        await tester.enterText(search, 'alina');
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(const ValueKey('admin-user-animation-ALI')),
          findsOneWidget,
        );

        await tester.pumpAndSettle();
        expect(find.text('Alina'), findsOneWidget);
        expect(find.text('Ali'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      }, createHttpClient: (_) => client);
    },
  );

  testWidgets(
    'admin user search keeps a verified subset visible while request is pending',
    (tester) async {
      final releaseNarrowSearch = Completer<void>();
      final client = _AdminUsersHttpClient(
        userListResponder: (url) async {
          final query = url.queryParameters['q'] ?? '';
          if (query.isEmpty || query == 'abdu') {
            return _UserListResponse(
              items: [
                _supplierUser('ABDU-SOMA', 'Abdusoma'),
                _supplierUser('ABDU-LLA', 'Abdulla'),
              ],
            );
          }
          if (query == 'abdusoma') {
            await releaseNarrowSearch.future;
            return _UserListResponse(
              items: [_supplierUser('ABDU-SOMA', 'Abdusoma')],
            );
          }
          return const _UserListResponse(items: []);
        },
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
            home: const AdminSuppliersScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await _selectUserRole(tester, 'Ta’minotchi');
        expect(find.text('Abdusoma'), findsOneWidget);
        expect(find.text('Abdulla'), findsOneWidget);

        final search = find.byType(EditableText).first;
        await tester.enterText(search, 'abdu');
        await tester.pump(const Duration(milliseconds: 221));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(AppLoadingIndicator), findsNothing);
        expect(find.text('Abdusoma'), findsOneWidget);
        expect(find.text('Abdulla'), findsOneWidget);

        await tester.enterText(search, 'abdusoma');
        await tester.pump(const Duration(milliseconds: 221));
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.byType(AppLoadingIndicator), findsNothing);
        expect(find.text('Abdusoma'), findsOneWidget);
        expect(find.text('Abdulla'), findsNothing);

        releaseNarrowSearch.complete();
        await tester.pumpAndSettle();
        expect(find.text('Abdusoma'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      }, createHttpClient: (_) => client);
    },
  );

  testWidgets('admin user list shows retry instead of empty state on error', (
    tester,
  ) async {
    var fail = true;
    final client = _AdminUsersHttpClient(
      userListResponder: (url) async {
        if (fail) {
          return const _UserListResponse(
            items: [],
            statusCode: HttpStatus.internalServerError,
          );
        }
        return _UserListResponse(items: [_supplierUser('OK', 'Recovered')]);
      },
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
          home: const AdminSuppliersScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await _selectUserRole(tester, 'Ta’minotchi');

      expect(find.byType(AppRetryState), findsOneWidget);
      expect(find.text('Userlar topilmadi'), findsNothing);

      fail = false;
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(find.byType(AppRetryState), findsNothing);
      expect(find.text('Recovered'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user search rejects stale load-more results', (
    tester,
  ) async {
    final oldPageStarted = Completer<void>();
    final releaseOldPage = Completer<void>();
    final firstPage = List<Object>.generate(
      50,
      (index) => _supplierUser('OLD-$index', 'Old $index'),
    );
    final client = _AdminUsersHttpClient(
      userListResponder: (url) async {
        final query = url.queryParameters['q'] ?? '';
        final offset = int.tryParse(url.queryParameters['offset'] ?? '') ?? 0;
        if (query == 'new') {
          return _UserListResponse(items: [_supplierUser('NEW', 'New user')]);
        }
        if (offset == 50) {
          if (!oldPageStarted.isCompleted) {
            oldPageStarted.complete();
          }
          await releaseOldPage.future;
          return _UserListResponse(
            items: [_supplierUser('STALE', 'Stale page user')],
          );
        }
        return _UserListResponse(items: firstPage, hasMore: true);
      },
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
          home: const AdminSuppliersScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await _selectUserRole(tester, 'Ta’minotchi');

      await tester.fling(find.byType(ListView), const Offset(0, -5000), 5000);
      for (var i = 0; i < 30 && !oldPageStarted.isCompleted; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(oldPageStarted.isCompleted, isTrue);

      await tester.enterText(find.byType(EditableText).first, 'new');
      await tester.pump(const Duration(milliseconds: 221));
      for (var i = 0; i < 20 && find.text('New user').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text('New user'), findsOneWidget);

      releaseOldPage.complete();
      await tester.pumpAndSettle();
      expect(find.text('New user'), findsOneWidget);
      expect(find.text('Stale page user'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin qolipchi tab opens system user profile', (
    tester,
  ) async {
    final client = _AdminUsersHttpClient(
      users: const [
        {
          'id': 'system_user:qolipchi-q',
          'source': 'system_user',
          'entity_ref': 'qolipchi-q',
          'principal_role': 'qolipchi',
          'name': 'Qolipchi user',
          'phone': '998900003',
          'role_label': 'Qolipchi',
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
          },
          home: const AdminSuppliersScreen(),
        ),
      );

      for (var i = 0; i < 20 && client.requests.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await _selectUserRole(tester, 'Qolipchi');
      expect(
        client.requests,
        contains('GET /v1/mobile/admin/users/list?limit=50&role=qolipchi'),
      );
      expect(find.text('Qolipchi user'), findsOneWidget);

      await tester.tap(find.text('Qolipchi user'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Qolipchi'), findsWidgets);
      expect(find.text('Qolipchi user'), findsWidgets);
      expect(find.text('998900003'), findsWidgets);
      expect(
        client.requests,
        contains(
          'GET /v1/mobile/admin/system-users/detail?id=qolipchi-q',
        ),
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
