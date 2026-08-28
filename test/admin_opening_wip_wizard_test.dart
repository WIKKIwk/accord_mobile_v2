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
    await MobileApi.instance.adminCreateFactoryLocation(name: 'Bosma oldi');
    await MobileApi.instance.adminCreateFactoryLocation(
      name: 'Laminatsiya oldi',
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
        home: AdminOpeningWipScreen(
          progressDriverUrlPicker: (_) async => 'http://printer.test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('opening-wip-order')), findsOneWidget);

    final locationPicker = find.byKey(
      const ValueKey('opening-wip-location'),
    );
    expect(
      tester.widget(locationPicker),
      isA<DropdownButtonFormField<String>>(),
    );
    await tester.tap(locationPicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laminatsiya oldi').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-count')),
      '2',
    );
    await tester.tap(
      find.byKey(const ValueKey('opening-wip-quantity-basis')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('O‘lchangan').last);
    await tester.pumpAndSettle();

    final uomPicker = find.byKey(const ValueKey('opening-wip-uom'));
    expect(
      tester.widget(uomPicker),
      isA<DropdownButtonFormField<String>>(),
    );
    expect(find.text('kg'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-quantity-0')),
      '12.5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-quantity-1')),
      '14',
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
    expect(records.single.intake.currentLocation, 'Laminatsiya oldi');
    expect(records.single.batches, hasLength(2));
    expect(
      records.single.batches.map((batch) => batch.quantity).toList(),
      [12.5, 14],
    );
    expect(
      records.single.batches.map((batch) => batch.uom).toSet(),
      {'kg'},
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

ProductionMapDefinition _openingOrder() {
  return const ProductionMapDefinition(
    id: 'zakaz-opening-wip-1',
    productCode: 'ITEM-OPENING-WIP',
    title: 'Opening WIP mahsulot',
    orderNumber: 'OWIP-0001',
    nodes: [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'lamination',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _laminationId,
      ),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: 'lamination'),
      ProductionMapEdge(from: 'lamination', to: 'end'),
    ],
  );
}
