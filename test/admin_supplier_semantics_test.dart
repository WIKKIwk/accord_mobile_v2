import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_dock.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_supplier_list_module.dart';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin supplier list builds with semantics enabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AdminSupplierListModule(
            items: const [
              AdminUserListEntry(
                id: '1',
                name: 'Werka',
                phone: '',
                kind: AdminUserKind.werka,
              ),
              AdminUserListEntry(
                id: '2',
                name: 'Supplier one',
                phone: '',
                kind: AdminUserKind.supplier,
              ),
              AdminUserListEntry(
                id: '3',
                name: 'Customer one',
                phone: '',
                kind: AdminUserKind.customer,
              ),
            ],
            onTapUser: (_) {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin supplier shell builds with dock semantics enabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: AppShell(
          title: 'Suppliers',
          subtitle: '',
          bottom: const AdminDock(activeTab: AdminDockTab.user),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AdminSupplierListModule(
                items: const [
                  AdminUserListEntry(
                    id: '1',
                    name: 'Werka',
                    phone: '',
                    kind: AdminUserKind.werka,
                  ),
                  AdminUserListEntry(
                    id: '2',
                    name: 'Supplier one',
                    phone: '',
                    kind: AdminUserKind.supplier,
                  ),
                  AdminUserListEntry(
                    id: '3',
                    name: 'Customer one',
                    phone: '',
                    kind: AdminUserKind.customer,
                  ),
                ],
                onTapUser: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin dock exposes the current user profile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          bottomNavigationBar: AdminDock(
            activeTab: AdminDockTab.user,
            showPrimaryFab: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Foydalanuvchi'), findsOneWidget);
    expect(find.text('Foydalanuvchilar'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin user dock opens the users page', (tester) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.adminSuppliers) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Text('Foydalanuvchilar page'),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(
              bottomNavigationBar: const AdminDock(
                activeTab: AdminDockTab.user,
                showPrimaryFab: false,
              ),
            ),
          );
        },
        home: const Scaffold(
          bottomNavigationBar: AdminDock(
            activeTab: AdminDockTab.home,
            showPrimaryFab: false,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Foydalanuvchi'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(observer.routeNames, contains(AppRoutes.adminSuppliers));
    expect(find.text('Foydalanuvchilar page'), findsOneWidget);
  });
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<String?> routeNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routeNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}
