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

  testWidgets('admin creates one traceable QR per Opening WIP roll',
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
        home: AdminProductionMapOrdersScreen(
          progressDriverUrlPicker: (_) async => 'http://printer.test',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-opening-wip-launch')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('production-opening-wip-launch')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-location')),
      'Laminatsiya oldi',
    );
    await tester.enterText(
      find.byKey(const ValueKey('opening-wip-roll-count')),
      '2',
    );
    final printerButton =
        find.byKey(const ValueKey('opening-wip-pick-printer'));
    await tester.ensureVisible(printerButton);
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
    expect(records.single.batches, hasLength(2));
    expect(
      records.single.batches.map((batch) => batch.qrPayload).toSet(),
      hasLength(2),
    );
    expect(
      records.single.intake.historyStatus,
      'unavailable_before_cutover',
    );
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
