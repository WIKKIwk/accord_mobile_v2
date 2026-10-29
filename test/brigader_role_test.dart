import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_home_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionProfile _profile([List<String> grants = const ['brigader.access']]) =>
    SessionProfile.fromJson({
      'role': 'brigader',
      'display_name': 'Brigader',
      'ref': 'brigader_test',
      'capabilities': grants,
    });

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile();
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('native brigader identity survives session and directory decoding',
      () async {
    await AppSession.instance.setSession(token: 'token', profile: _profile());
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await AppSession.instance.load();
    final profile = AppSession.instance.profile!;
    expect(profile.role, UserRole.brigader);
    expect(profile.toJson()['role'], 'brigader');
    expect(profile.accessRole, UserRole.brigader);
    expect(profile.isCapabilityOnlyProfile, isFalse);
    expect(AppSession.instance.homeRoute, AppRoutes.brigaderHome);
    expect(AppSession.instance.canUseAdminComponents, isTrue);
    expect(profile.hasCapability('admin.access'), isFalse);
    final entry = AdminUserListEntry.fromJson({
      'source': 'system_user',
      'principal_role': 'brigader',
      'entity_ref': 'brigader_test',
      'name': 'Brigader',
    });
    expect(entry.kind, AdminUserKind.brigader);
    expect(entry.roleLabel, 'Brigader');
  });

  test('all requested admin components and their nested action routes are open',
      () {
    for (final route in [
      AppRoutes.brigaderHome,
      AppRoutes.adminFactoryMap,
      AppRoutes.adminCalculateOrders,
      AppRoutes.adminCalculate,
      AppRoutes.adminProductionMapTest,
      AppRoutes.adminProductionMapOrders,
      AppRoutes.adminSuppliers,
      AppRoutes.adminActivity,
      AppRoutes.adminItemBulkMove,
      AppRoutes.adminOpeningWip,
      AppRoutes.adminWipBatches,
      AppRoutes.adminNotifications,
      AppRoutes.adminApparatusSettings,
      AppRoutes.adminAdditionalSettings,
      AppRoutes.adminWarehouses,
      AppRoutes.adminFactoryLocations,
      AppRoutes.adminRawMaterialSettings,
      AppRoutes.adminCalculateMaterials,
      AppRoutes.adminWorkerSettings,
      AppRoutes.adminItemGroupCreate,
      AppRoutes.adminUserCreate,
      AppRoutes.adminWorkerDetail,
      AppRoutes.adminWorkerProfileDetail,
      AppRoutes.adminItemDetail,
      AppRoutes.adminRawMaterialAssignments,
      AppRoutes.adminQueuePolicies,
      AppRoutes.adminApparatusCreate,
      AppRoutes.adminProgressQrScan,
      AppRoutes.apparatusPaddons,
      AppRoutes.apparatusPaddonDetail,
      AppRoutes.inventoryMovements,
    ]) {
      expect(AppRouter.canOpenRoute(route), isTrue, reason: route);
    }
  });

  test('omitted administration stays closed even with stale admin grants', () {
    AppSession.instance.profile = _profile([
      'brigader.access',
      'admin.access',
      'admin.settings.read',
      'role.capability.read',
      'production.map.manage',
    ]);
    for (final route in [
      AppRoutes.adminRoles,
      AppRoutes.adminSettings,
      AppRoutes.adminTelegram,
      AppRoutes.adminTraining,
      AppRoutes.adminEmergencyReset,
      AppRoutes.adminServerMonitor,
      AppRoutes.adminPushConfig,
      AppRoutes.gscaleMode,
      AppRoutes.rezkaSplit,
    ]) {
      expect(AppRouter.canOpenRoute(route), isFalse, reason: route);
    }
    AppSession.instance.profile = _profile([]);
    expect(AppRouter.canOpenRoute(AppRoutes.adminProductionMapOrders), isFalse);
  });

  testWidgets('brigader home reuses the existing admin page and dock',
      (tester) async {
    await tester.pumpWidget(_app(const AdminHomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(AdminHomeScreen), findsOneWidget);
    expect(find.byType(AdminDock), findsOneWidget);
    expect(find.text('Brigader'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'native system brigader creation uses the existing form and 93 code',
      (tester) async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      Object body;
      if (request.url.path.endsWith('/roles')) {
        body = [
          {
            'id': 'brigader',
            'label': 'Brigader',
            'base_role': 'brigader',
            'capability_codes': ['brigader.access'],
            'system': true,
          }
        ];
      } else if (request.url.path.endsWith('/system-users')) {
        final input = jsonDecode(request.body) as Map;
        expect(input['role'], 'brigader');
        expect(input['name'], 'Ali Brigader');
        body = {
          'id': 'brigader_ali',
          'role': 'brigader',
          'name': 'Ali Brigader',
          'phone': '+998901234567'
        };
      } else if (request.url.path.endsWith('/code/regenerate')) {
        expect(request.url.queryParameters['id'], 'brigader_ali');
        body = {
          'id': 'brigader_ali',
          'role': 'brigader',
          'name': 'Ali Brigader',
          'phone': '+998901234567',
          'code': '931234567890'
        };
      } else {
        throw StateError('Unexpected request ${request.url}');
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const AdminUserCreateScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Role tanlang').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Brigader');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Brigader').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Ali Brigader');
      await tester.enterText(find.byType(TextField).at(1), '+998901234567');
      await tester
          .tap(find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'));
      await tester.pumpAndSettle();
      expect(calls, contains('POST /v1/mobile/admin/system-users'));
      expect(calls,
          contains('POST /v1/mobile/admin/system-users/code/regenerate'));
      expect(calls.any((call) => call.contains('/customers')), isFalse);
      expect(calls.any((call) => call.contains('/role-assignments')), isFalse);
      expect(find.text('931234567890'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => client);
  });
}
