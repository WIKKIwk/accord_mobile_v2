import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _godexId = 'apparatus:test:godex-demo';
const _print9Id = 'apparatus:default:bosma_9';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'test_mode_enabled': true,
    });
    AdminSequenceApparatusStore.instance.clearCache();
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
    AdminSequenceApparatusStore.instance.clearCache();
  });

  testWidgets(
    'remembers selected apparatus in sequence tab and persists across screens',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. First open: Godex is default since no apparatus was saved yet
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
          home: AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ketma-ketlik'));
      await tester.pumpAndSettle();

      // Initially default apparatus is shown
      expect(find.text('Aparat: Godex aparat - DEMO'), findsOneWidget);

      // 2. User selects '9 ta rangli bosma aparat'
      await tester.tap(find.text('Aparat: Godex aparat - DEMO'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('admin-filter-option-9 ta rangli bosma aparat')),
      );
      await tester.pumpAndSettle();

      // Now 9 ta rangli bosma aparat is selected
      expect(find.text('Aparat: 9 ta rangli bosma aparat'), findsOneWidget);

      // Verify it was stored in store cache
      expect(
        AdminSequenceApparatusStore.instance.cachedApparatusId,
        _print9Id,
      );

      // 3. User closes screen and opens it again (simulate navigating away and returning)
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
          home: AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ketma-ketlik'));
      await tester.pumpAndSettle();

      // It should IMMEDIATELY have '9 ta rangli bosma aparat' selected!
      expect(find.text('Aparat: 9 ta rangli bosma aparat'), findsOneWidget);
    },
  );

  testWidgets(
    'restores saved apparatus from SharedPreferences on cold start',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pre-seed SharedPreferences as if previously saved by the app
      final key = AdminSequenceApparatusStore.preferenceKey(profileRef: 'ADMIN-001');
      SharedPreferences.setMockInitialValues({
        'test_mode_enabled': true,
        key: _print9Id,
        '${key}_name': '9 ta rangli bosma aparat',
      });
      AdminSequenceApparatusStore.instance.clearCache();

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
          home: AdminProductionMapOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ketma-ketlik'));
      await tester.pumpAndSettle();

      // Cold start: It should restore '9 ta rangli bosma aparat' from SharedPreferences!
      expect(find.text('Aparat: 9 ta rangli bosma aparat'), findsOneWidget);

      // And user can still tap and switch to another apparatus
      await tester.tap(find.text('Aparat: 9 ta rangli bosma aparat'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('admin-filter-option-Godex aparat - DEMO')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aparat: Godex aparat - DEMO'), findsOneWidget);
      expect(
        AdminSequenceApparatusStore.instance.cachedApparatusId,
        _godexId,
      );
    },
  );

  testWidgets(
    'admin search matches displayed customers and preserves queue positions',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final maps = [
        _sequenceSearchMap(
          id: 'zakaz-sequence-search-alpha',
          title: 'Alpha sequence order',
        ).copyWith(code: '0011', customerName: 'Alpha customer'),
        for (var index = 1; index <= 4; index++)
          _sequenceSearchMap(
            id: 'zakaz-sequence-search-$index',
            title: 'Intermediate order $index',
          ).copyWith(code: '001${index + 1}'),
        _sequenceSearchMap(
          id: 'zakaz-sequence-search-beta',
          title: 'Beta sequence order',
        ).copyWith(code: '0016', customerName: 'Map customer'),
      ];
      for (final map in maps) {
        await MobileApi.instance.adminSaveProductionMap(map);
      }
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _godexId,
        orderIds: maps.map((map) => map.id).toList(),
      );
      final initial =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
      final snapshot = AdminApparatusQueueSnapshot(
        maps: initial.maps,
        sequences: initial.sequences,
        visibleOrderIds: initial.visibleOrderIds,
        queueStates: initial.queueStates,
        queuePolicies: initial.queuePolicies,
        orderControls: initial.orderControls,
        orderCustomers: const {'zakaz-sequence-search-beta': 'Miray'},
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapOrdersScreen(
            queueSnapshotLoader: () async => snapshot,
            liveEventsLoader: () => const Stream.empty(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ketma-ketlik'));
      await tester.pumpAndSettle();

      expect(find.text('Alpha sequence order'), findsOneWidget);
      expect(find.text('Beta sequence order'), findsOneWidget);

      Finder filteredRow(String id) => find.byKey(
            ValueKey('sequence-static-$_godexId-zakaz-sequence-search-$id'),
          );

      await tester.enterText(find.byType(EditableText), '0016');
      await tester.pumpAndSettle();

      expect(find.text('Alpha sequence order'), findsNothing);
      expect(find.text('Beta sequence order'), findsOneWidget);
      expect(
        find.descendant(of: filteredRow('beta'), matching: find.text('6')),
        findsOneWidget,
      );
      expect(find.byType(ReorderableListView), findsNothing);

      await tester.enterText(find.byType(EditableText), 'sequence order');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: filteredRow('alpha'), matching: find.text('1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filteredRow('beta'), matching: find.text('6')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(EditableText), 'mIrAy');
      await tester.pumpAndSettle();
      expect(find.text('Alpha sequence order'), findsNothing);
      expect(find.text('Beta sequence order'), findsOneWidget);
      expect(find.text('Miray • 1 ta aparat'), findsOneWidget);
      expect(
        find.descendant(of: filteredRow('beta'), matching: find.text('6')),
        findsOneWidget,
      );

      await tester.tap(find.text('Buyurtmalar'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('opened-order-zakaz-sequence-search-beta')),
        findsOneWidget,
      );
      expect(find.text('Alpha sequence order'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'alpha CUSTOMER');
      await tester.pumpAndSettle();
      expect(find.text('Alpha sequence order'), findsOneWidget);
      expect(find.text('Beta sequence order'), findsNothing);

      await tester.enterText(find.byType(EditableText), 'no matching customer');
      await tester.pumpAndSettle();
      expect(find.text('Alpha sequence order'), findsNothing);
      expect(find.text('Beta sequence order'), findsNothing);

      await tester.enterText(find.byType(EditableText), '');
      await tester.tap(find.text('Ketma-ketlik'));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey(
            'sequence-row-$_godexId-zakaz-sequence-search-beta',
          )),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    },
  );
}

ProductionMapDefinition _sequenceSearchMap({
  required String id,
  required String title,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: '${id.toUpperCase()}-PRODUCT',
    title: title,
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      const ProductionMapNode(
        id: 'apparatus',
        kind: 'apparatus',
        title: 'Godex aparat - DEMO',
        apparatusId: _godexId,
      ),
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: title,
        itemCode: '${id.toUpperCase()}-PRODUCT',
      ),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'apparatus'),
      ProductionMapEdge(from: 'apparatus', to: 'end'),
    ],
  );
}
