import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _extruderId = 'apparatus:default:asset-004';
const _regularIds = [
  'apparatus:default:asset-007',
  'apparatus:default:asset-008',
];
const _allIds = [..._regularIds, _extruderId];
const _mapId = 'zakaz-lamination-fit';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
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
    await MobileApi.instance.adminCreateApparatus(
      'Extruder laminatsiya',
      id: _extruderId,
      family: 'laminatsiya',
      kind: 'extruder_laminatsiya',
      capabilities: ['laminate'],
    );
  });

  tearDown(() {
    dismissAdminTopNotice();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
  });

  test('lamination uses technology with inclusive 1050 and 1300 limits', () {
    const regular = AdminApparatus(
      id: 'apparatus:catalog:regular',
      name: 'Extruder in display name only',
      operation: 'laminate',
      technology: 'adhesive_lamination',
    );
    const extruder = AdminApparatus(
      id: 'apparatus:catalog:extruder',
      name: 'Renamed E-01',
      operation: 'laminate',
      technology: 'extrusion_lamination',
    );
    for (final (width, regularFits, extruderFits) in [
      (1050.0, true, true),
      (1050.1, false, true),
      (1051.0, false, true),
      (1300.0, false, true),
      (1300.1, false, false),
      (1301.0, false, false),
      (2200.0, false, false),
    ]) {
      final order = _context(width);
      expect(productionMapApparatusMatchesOrder(regular, order), regularFits,
          reason: 'regular at $width mm');
      expect(productionMapApparatusMatchesOrder(extruder, order), extruderFits,
          reason: 'extruder at $width mm');
    }
  });

  for (final (label, width, kadrCount, groups, enabledIds)
      in <(String, double, int?, List<int>, List<String>)>[
    ('1050 supports all', 1050, null, [], _allIds),
    ('1051 supports extruder', 1051, null, [], [_extruderId]),
    ('1300 supports extruder', 1300, null, [], [_extruderId]),
    ('1301 blocks group', 1301, null, [], []),
    ('2200 blocks group', 2200, null, [], []),
    ('two cuts support extruder', 2200, 2, [], [_extruderId]),
    ('three cuts support all', 2200, 3, [], _allIds),
    ('grouped cuts at 1300 support extruder', 2600, 4, [2, 2], [_extruderId]),
    ('grouped cuts above 1300 block group', 2602, 4, [2, 2], []),
    ('one oversized cut group blocks group', 2600, 4, [1, 3], []),
  ]) {
    testWidgets('lamination picker and Skip: $label', (tester) async {
      await _openMap(tester, width, kadrCount: kadrCount, groups: groups);
      final menu = tester.widget<AdminFabOverlayActionMenu>(
        find.byType(AdminFabOverlayActionMenu),
      );
      expect(
          menu.actions
              .singleWhere((item) => item.title == 'Laminatsiya')
              .enabled,
          enabledIds.isNotEmpty);
      await _openLamination(tester);
      if (enabledIds.isEmpty) {
        expect(find.text('Skip'), findsNothing);
        expect(
          find.text(
              'Laminatsiya apparatga buyurtma kattalik qiladi, iltimos uni bo‘laklab oling'),
          findsOneWidget,
        );
      } else {
        _expectTile(
            tester, 'Laminatsiya 1', enabledIds.contains(_regularIds[0]));
        _expectTile(
            tester, 'Laminatsiya 2', enabledIds.contains(_regularIds[1]));
        _expectTile(
            tester, 'Extruder laminatsiya', enabledIds.contains(_extruderId));
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        await _expectSavedLamination(tester, enabledIds);
      }
      await _disposeMap(tester);
    });
  }

  testWidgets('disabled regular cannot be selected; extruder can be selected',
      (tester) async {
    await _openMap(tester, 1300);
    await _openLamination(tester);
    _expectTile(tester, 'Laminatsiya 1', false);
    _expectTile(tester, 'Laminatsiya 2', false);
    await tester.tap(find.text('Laminatsiya 1'));
    await tester.pumpAndSettle();
    expect(find.text('Skip'), findsOneWidget);
    await tester.tap(find.text('Extruder laminatsiya'));
    await tester.pumpAndSettle();
    expect(find.text('Skip'), findsNothing);
    await _expectSavedLamination(tester, [_extruderId]);
    await _disposeMap(tester);
  });
}

ProductionMapOrderContext _context(double width) => ProductionMapOrderContext(
      orderName: 'Lamination fit',
      productName: 'Lamination fit product',
      itemCode: 'LAM-FIT',
      widthMm: width,
      // A print-only override must not change lamination eligibility.
      printValSizeMm: 650,
    );

Future<void> _openMap(WidgetTester tester, double width,
    {int? kadrCount, List<int> groups = const []}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: AdminProductionMapTestScreen(
      orderContext: _context(width),
      savedMap: ProductionMapDefinition(
        id: _mapId,
        title: 'Lamination fit',
        productCode: 'LAM-FIT',
        orderNumber: '8877',
        widthMm: width,
        nodes: [
          const ProductionMapNode(
              id: 'start', kind: 'start', title: 'Start', x: 420, y: 32),
          if (kadrCount != null)
            ProductionMapNode(
              id: 'rezka',
              kind: 'apparatus',
              title: 'Rezka',
              apparatusId: 'apparatus:default:asset-010',
              rezkaKadrCount: kadrCount,
              rezkaFrameGroups: groups,
              x: 420,
              y: 164,
            ),
          const ProductionMapNode(
              id: 'end', kind: 'end', title: 'End', x: 420, y: 296),
        ],
        edges: [
          if (kadrCount == null)
            const ProductionMapEdge(from: 'start', to: 'end')
          else ...[
            const ProductionMapEdge(from: 'start', to: 'rezka'),
            const ProductionMapEdge(from: 'rezka', to: 'end'),
          ],
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openLamination(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('admin-fab-menu-Laminatsiya')));
  await tester.pumpAndSettle();
}

void _expectTile(WidgetTester tester, String name, bool enabled) {
  final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, name));
  expect(tile.enabled, enabled, reason: name);
  expect(tile.onTap, enabled ? isNotNull : isNull, reason: name);
}

Future<void> _expectSavedLamination(
    WidgetTester tester, List<String> ids) async {
  await tester.tap(find.byKey(const ValueKey('production-map-save')));
  await tester.pumpAndSettle();
  final saved = await MobileApi.instance.adminProductionMap(_mapId);
  expect(
    saved.map.nodes.map((node) => node.apparatusId).where(_allIds.contains),
    unorderedEquals(ids),
  );
}

Future<void> _disposeMap(WidgetTester tester) async {
  dismissAdminTopNotice();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
