import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_warehouses_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_warehouse_filter_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _warehouseFilterKey = ValueKey('admin-warehouse-filter-chip');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'test_mode_enabled': true,
    });
    AdminWarehouseFilterStore.instance.clearCache();
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
    AdminWarehouseFilterStore.instance.clearCache();
  });

  testWidgets(
    'remembers selected warehouse and persists across navigation',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Initial open: No warehouse saved -> Ombor: Tanlanmagan
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
          home: AdminWarehousesScreen(),
        ),
      );

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
          break;
        }
      }

      expect(find.textContaining('Ombor: Tanlanmagan'), findsOneWidget);

      // 2. Select 'Tayyor mahsulot ombori - DEMO'
      await tester.tap(find.byKey(_warehouseFilterKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tayyor mahsulot ombori - DEMO'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ombor: Tayyor mahsulot ombori - DEMO'), findsOneWidget);
      expect(
        AdminWarehouseFilterStore.instance.cachedWarehouse,
        'Tayyor mahsulot ombori - DEMO',
      );

      // 3. Navigate away and return
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
          home: AdminWarehousesScreen(),
        ),
      );

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
          break;
        }
      }

      // Warehouse should immediately be restored!
      expect(find.textContaining('Ombor: Tayyor mahsulot ombori - DEMO'), findsOneWidget);
    },
  );

  testWidgets(
    'restores saved warehouse from SharedPreferences on cold start',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final key = AdminWarehouseFilterStore.preferenceKey(profileRef: 'ADMIN-001');
      SharedPreferences.setMockInitialValues({
        'test_mode_enabled': true,
        key: 'Tayyor mahsulot ombori - DEMO',
      });
      AdminWarehouseFilterStore.instance.clearCache();

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
          home: AdminWarehousesScreen(),
        ),
      );

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      // Cold start: It should restore saved warehouse
      expect(find.textContaining('Ombor: Tayyor mahsulot ombori - DEMO'), findsOneWidget);
      expect(
        AdminWarehouseFilterStore.instance.cachedWarehouse,
        'Tayyor mahsulot ombori - DEMO',
      );
    },
  );
}
