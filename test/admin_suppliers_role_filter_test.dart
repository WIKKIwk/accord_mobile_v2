import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_suppliers_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_users_role_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'test_mode_enabled': true,
    });
    AdminUsersRoleStore.instance.clearCache();
    resetMobileApiTestModeData();
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
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    AdminUsersRoleStore.instance.clearCache();
  });

  testWidgets(
    'remembers selected role in users screen and persists across navigation',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Initially no role saved
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
      await tester.pumpAndSettle();

      // Expect 'Rol: Tanlanmagan'
      expect(find.text('Rol: Tanlanmagan'), findsOneWidget);

      // Select 'Omborchi' (AdminUserKind.werka)
      await tester.tap(find.byKey(const ValueKey('admin-users-role-filter-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-users-role-option-chip-werka')));
      await tester.pumpAndSettle();

      expect(find.text('Rol: Omborchi'), findsOneWidget);
      expect(AdminUsersRoleStore.instance.cachedRole, AdminUserKind.werka);

      // Navigate away and return
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Should immediately restore 'Rol: Omborchi'
      expect(find.text('Rol: Omborchi'), findsOneWidget);
    },
  );

  testWidgets(
    'restores saved role from SharedPreferences on cold start',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final key = AdminUsersRoleStore.preferenceKey(profileRef: 'ADMIN-001');
      SharedPreferences.setMockInitialValues({
        'test_mode_enabled': true,
        key: AdminUserKind.customer.name,
      });
      AdminUsersRoleStore.instance.clearCache();

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
      await tester.pumpAndSettle();

      // Cold start: It should restore 'Rol: Haridor' (localized for customer)
      expect(find.text('Rol: Haridor'), findsOneWidget);
      expect(AdminUsersRoleStore.instance.cachedRole, AdminUserKind.customer);
    },
  );
}
