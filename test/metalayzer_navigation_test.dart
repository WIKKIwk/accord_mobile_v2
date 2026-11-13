import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/role_dock.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_worker_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/chat/presentation/widgets/chat_role_dock.dart';
import 'package:accord_mobile_v2/src/features/metalayzer/presentation/metalayzer_navigation.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.metalayzer,
      displayName: 'Metalchi',
      legalName: '',
      ref: 'metalayzer-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['metalayzer.access'],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('Chat keeps Metalayzer home and profile navigation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [AppRootNavigation.navigatorObserver],
      initialRoute: AppRoutes.chat,
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => settings.name == AppRoutes.chat
            ? const Scaffold(
                body: Text('Chat sahifasi'),
                bottomNavigationBar: ChatRoleDock())
            : Scaffold(body: Text('Bosh sahifa: ${settings.name}')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(MetalayzerDock), findsOneWidget);
    expect(find.text('Metalayzer'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    final dock = tester.widget<RoleDock>(find.byType(RoleDock));
    expect(dock.destinations.where((item) => item.active), isEmpty,
        reason:
            'Native Chat dock must not also select the Metalayzer home tab');
    await tester.tap(find.text('Metalayzer'));
    await tester.pumpAndSettle();
    expect(find.text('Bosh sahifa: /metalayzer'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('existing warehouse editor scopes assignments to Metalayzer',
      (tester) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
    const entry = AdminUserListEntry(
        id: 'metalayzer-1',
        name: 'Metalchi',
        phone: '',
        kind: AdminUserKind.metalayzer,
        principalRole: UserRole.metalayzer);
    final assigned = <String>[];
    await tester.pumpWidget(_app(AdminWorkerDetailScreen(
      entry: entry,
      detailLoader: (_) async => const AdminWorkerDetail(
          id: 'metalayzer-1',
          name: 'Metalchi',
          phone: '',
          avatarUrl: '',
          level: 'Metalayzer',
          code: '951234567890',
          codeLocked: false,
          codeRetryAfterSec: 0),
      warehouseAssignmentsLoader: () async => [
        for (final warehouse in assigned)
          AdminWarehouseAssignment(
              warehouse: warehouse,
              principalRole: UserRole.metalayzer,
              principalRef: entry.id,
              displayName: entry.name),
        const AdminWarehouseAssignment(
            warehouse: 'Boshqa rol ombori',
            principalRole: UserRole.qolipchi,
            principalRef: 'metalayzer-1',
            displayName: 'Qolipchi'),
      ],
      warehousesLoader: () async =>
          const [AdminWarehouse(warehouse: 'Xomashyo')],
      warehouseAssigner: (
          {required warehouse,
          required principalRole,
          required principalRef,
          required displayName}) async {
        expect(principalRole, UserRole.metalayzer);
        expect(principalRef, 'metalayzer-1');
        assigned.add(warehouse);
        return AdminWarehouseAssignment(
            warehouse: warehouse,
            principalRole: principalRole,
            principalRef: principalRef,
            displayName: displayName);
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('0 ta ombor'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('admin-worker-detail-admin-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Boshqa rol ombori'), findsNothing);
    await tester.drag(find.byKey(const ValueKey('admin-worker-detail-scroll')),
        const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('admin-qolipchi-detail-add-warehouse')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Xomashyo'));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey('admin-material-warehouse-confirm')));
    await tester.pumpAndSettle();
    expect(assigned, ['Xomashyo']);
    expect(
        find.byKey(const ValueKey('admin-qolipchi-detail-warehouse-Xomashyo')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
