import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _laminationId = 'apparatus:default:asset-007';
const _lamination2Id = 'apparatus:default:asset-008';
const _rezkaId = 'apparatus:default:asset-010';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'opening-wip-admin-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Opening WIP admin',
      legalName: 'Opening WIP admin',
      ref: 'ADMIN-OPENING-WIP',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'production_map.manage'],
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('admin creates distinct measured batches from selectable fields',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
        home: AdminOpeningWipScreen(
          progressDriverUrlPicker: (_) async => 'http://printer.test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('opening-wip-order')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('opening-wip-source-operation')),
      findsNothing,
    );

    final locationPicker = find.byKey(
      const ValueKey('opening-wip-location'),
    );
    expect(
      tester.widget(locationPicker),
      isA<DropdownButtonFormField<String>>(),
    );
    await tester.tap(locationPicker);
    await tester.pumpAndSettle();
    expect(find.text('Laminatsiya 1'), findsWidgets);
    expect(find.text('Rezka'), findsOneWidget);
    await tester.tap(find.text('Rezka').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-count')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-meter-0')),
      '125',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-kg-0')),
      '12.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-bobina-0')),
      '1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-meter-1')),
      '140',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-kg-1')),
      '14',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-bobina-1')),
      '1.1',
    );
    expect(
      find.byKey(const ValueKey('opening-wip-roll-diameter-0')),
      findsNothing,
    );
    final printerButton =
        find.byKey(const ValueKey('opening-wip-pick-printer'));
    final openingWipScrollable = find.descendant(
      of: find.byKey(const ValueKey('opening-wip-fields')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      printerButton,
      240,
      scrollable: openingWipScrollable.first,
    );
    await tester.tap(printerButton);
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('opening-wip-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final records = await MobileApi.instance.adminOpeningWipRecords(
      orderId: 'zakaz-opening-wip-1',
    );
    expect(records, hasLength(1));
    expect(records.single.intake.currentLocation, 'Rezka');
    expect(records.single.batches, hasLength(2));
    expect(
      records.single.batches.map((batch) => batch.finishedGoodsMeter).toList(),
      [125, 140],
    );
    expect(
      records.single.batches.map((batch) => batch.finishedGoodsKg).toList(),
      [12.5, 14],
    );
    expect(
      records.single.batches.map((batch) => batch.bobinaKg).toList(),
      [1, 1.1],
    );
    expect(
      records.single.batches.map((batch) => batch.qrPayload).toSet(),
      hasLength(2),
    );
    expect(
      records.single.intake.historyStatus,
      'unavailable_before_cutover',
    );
  });

  testWidgets(
      'current location excludes apparatus outside map and keeps skip alternatives',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingAlternativeOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('opening-wip-location')));
    await tester.pumpAndSettle();

    expect(find.text('Laminatsiya 1'), findsWidgets);
    expect(find.text('Laminatsiya 2'), findsOneWidget);
    expect(find.text('Rezka'), findsNothing);
  });

  testWidgets('rezka Opening WIP requires diameter per roll', (tester) async {
    await MobileApi.instance.adminSaveProductionMap(
      _openingOrder(
        id: 'zakaz-opening-wip-rezka',
        apparatusId: _rezkaId,
        includeRezkaStage: false,
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
        home: const AdminOpeningWipScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('opening-wip-roll-diameter-0')),
      findsOneWidget,
    );
  });

  testWidgets('work map does not render the Opening WIP intake',
      (tester) async {
    await MobileApi.instance.adminSaveProductionMap(_openingOrder());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('opening-wip-order')), findsNothing);
    expect(find.text('Opening WIP'), findsNothing);
  });
}

ProductionMapDefinition _openingOrder({
  String id = 'zakaz-opening-wip-1',
  String apparatusId = _laminationId,
  bool includeRezkaStage = true,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: 'ITEM-OPENING-WIP',
    title: 'Opening WIP mahsulot',
    orderNumber: 'OWIP-0001',
    nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'lamination',
        kind: 'apparatus',
        title: apparatusId == _rezkaId ? 'Rezka' : 'Laminatsiya 1',
        apparatusId: apparatusId,
      ),
      if (includeRezkaStage)
        const ProductionMapNode(
          id: 'rezka',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: _rezkaId,
        ),
      const ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      const ProductionMapEdge(from: 'start', to: 'lamination'),
      if (includeRezkaStage) ...const [
        ProductionMapEdge(from: 'lamination', to: 'rezka'),
        ProductionMapEdge(from: 'rezka', to: 'end'),
      ] else
        const ProductionMapEdge(from: 'lamination', to: 'end'),
    ],
  );
}

ProductionMapDefinition _openingAlternativeOrder() {
  return const ProductionMapDefinition(
    id: 'zakaz-opening-wip-alternative',
    productCode: 'ITEM-OPENING-WIP-ALT',
    title: 'Opening WIP alternative',
    orderNumber: 'OWIP-ALT',
    nodes: [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'lamination-1',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _laminationId,
        alternativeGroupId: 'alt-laminatsiya',
        alternativeGroupLabel: 'Laminatsiya',
      ),
      ProductionMapNode(
        id: 'lamination-2',
        kind: 'apparatus',
        title: 'Laminatsiya 2',
        apparatusId: _lamination2Id,
        alternativeGroupId: 'alt-laminatsiya',
        alternativeGroupLabel: 'Laminatsiya',
      ),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: 'lamination-1'),
      ProductionMapEdge(from: 'start', to: 'lamination-2'),
      ProductionMapEdge(from: 'lamination-1', to: 'end'),
      ProductionMapEdge(from: 'lamination-2', to: 'end'),
    ],
  );
}
