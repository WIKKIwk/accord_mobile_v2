import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_home_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_create_hub_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capabilities = [
  'sales.access',
  'production.map.read',
  'production.order.create',
  'production.order.edit',
  'production.map.edit',
  'catalog.item.read',
  'catalog.item.create',
  'catalog.item_group.read',
  'party.customer.read',
  'party.customer.manage',
  'push.token.manage',
];

SessionProfile _profile([List<String> capabilities = _capabilities]) =>
    SessionProfile.fromJson({
      'role': 'sales_manager',
      'display_name': 'Sales manager',
      'ref': 'sales_manager_test',
      'capabilities': capabilities,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'sales-token';
    AppSession.instance.profile = _profile();
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('sales identity survives login profile persistence and directory decode',
      () async {
    await AppSession.instance
        .setSession(token: 'sales-token', profile: _profile());
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await AppSession.instance.load();

    final profile = AppSession.instance.profile!;
    expect(profile.role, UserRole.salesManager);
    expect(profile.toJson()['role'], 'sales_manager');
    expect(profile.accessRole, UserRole.salesManager);
    expect(profile.isCapabilityOnlyProfile, isFalse);
    expect(AppSession.instance.homeRoute, AppRoutes.salesHome);
    final entry = AdminUserListEntry.fromJson({
      'source': 'system_user',
      'principal_role': 'sales_manager',
      'entity_ref': 'sales_manager_test',
      'name': 'Sales manager',
    });
    expect(entry.kind, AdminUserKind.salesManager);
    expect(entry.id, 'sales_manager_test');
    expect(entry.roleLabel, 'Sotuv manageri');
  });

  test(
      'sales routes expose reused order, map, customer and finished item flows',
      () {
    for (final route in [
      AppRoutes.salesHome,
      AppRoutes.adminCreateHub,
      AppRoutes.adminCalculate,
      AppRoutes.adminCalculateOrders,
      AppRoutes.adminProductionMapOrders,
      AppRoutes.adminProductionMapTest,
      AppRoutes.adminUserCreate,
      AppRoutes.adminCustomerCreate,
      AppRoutes.adminCustomerDetail,
      AppRoutes.adminSuppliers,
      AppRoutes.adminItemCreate,
    ]) {
      expect(AppRouter.canOpenRoute(route), isTrue, reason: route);
    }
  });

  test('sales cannot enter operational administration even with stale grants',
      () {
    AppSession.instance.profile = _profile([
      ..._capabilities,
      'admin.access',
      'admin.settings.read',
      'production.map.manage',
      'apparatus.queue.manage',
      'catalog.item.bulk_move',
      'party.supplier.manage',
    ]);
    for (final route in [
      AppRoutes.adminHome,
      AppRoutes.adminSupplierCreate,
      AppRoutes.adminRoles,
      AppRoutes.adminEmergencyReset,
      AppRoutes.adminOpeningWip,
      AppRoutes.adminWipBatches,
      AppRoutes.adminQueuePolicies,
      AppRoutes.adminApparatusSettings,
      AppRoutes.adminProgressQrScan,
      AppRoutes.adminItemBulkMove,
      AppRoutes.adminWarehouses,
      AppRoutes.adminCalculateMaterials,
      AppRoutes.apparatusQueue,
    ]) {
      expect(AppRouter.canOpenRoute(route), isFalse, reason: route);
    }
    expect(AppSession.instance.homeRoute, AppRoutes.salesHome);
  });

  testWidgets('sales home reuses the admin home with sales navigation',
      (tester) async {
    final l10n = AppLocalizations(const Locale('uz'));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoutes.salesHome,
      onGenerateRoute: AppRouter.onGenerateRoute,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(AdminHomeScreen), findsOneWidget);
    expect(find.text('Sotuv manageri'), findsOneWidget);
    expect(find.byType(AdminDock), findsOneWidget);
    for (final title in [
      l10n.adminQuickOrdersTitle,
      l10n.adminWorkMapNavTitle
    ]) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(M3SegmentFilledSurface),
      );
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.byType(Icon)),
          findsOneWidget);
      expect(
        find.descendant(
            of: card, matching: find.byIcon(Icons.chevron_right_rounded)),
        findsOneWidget,
      );
    }
    for (final title in [
      l10n.adminCreateItemTitle,
      l10n.adminCreateUserTitle,
      l10n.adminUsersTitle,
      l10n.adminProductionMapTestTitle,
    ]) {
      expect(find.text(title), findsNothing);
    }
    expect(AppRouter.canOpenRoute(AppRoutes.adminProductionMapTest), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales drawer opens products and users through existing pages',
      (tester) async {
    final l10n = AppLocalizations(const Locale('uz'));
    final openedRoutes = <String>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminHomeScreen(),
      onGenerateRoute: (settings) {
        openedRoutes.add(settings.name!);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              Scaffold(appBar: AppBar(), body: Text(settings.name!)),
        );
      },
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminProductsTitle), findsOneWidget);
    expect(find.text(l10n.adminUsersTitle), findsOneWidget);
    expect(find.text(l10n.adminProductionMapTestTitle), findsNothing);
    await tester.tap(find.text(l10n.adminProductsTitle));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(openedRoutes.last, AppRoutes.adminItemCreate);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);
    navigator.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminUsersTitle));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(openedRoutes.last, AppRoutes.adminSuppliers);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales creation hub shows only authorized creation actions',
      (tester) async {
    final l10n = AppLocalizations(const Locale('uz'));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminCreateHubScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text(l10n.adminCreateUserTitle), findsOneWidget);
    expect(find.text(l10n.adminCreateItemTitle), findsOneWidget);
    expect(find.text(l10n.adminCreateOrderTitle), findsOneWidget);
    expect(find.text(l10n.adminErpSettingsTitle), findsNothing);
    expect(find.text(l10n.adminCreateItemGroupTitle), findsNothing);
    expect(
        find.text(l10n.adminText('create_hub.worker_settings')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
