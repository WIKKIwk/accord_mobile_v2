import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_catalog.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.tayyorlovMasteri,
      displayName: 'Master',
      legalName: '',
      ref: 'prep-1',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'preparation.access',
        'gscale.catalog.read',
        'rps.batch.manage'
      ],
      assignedWarehouses: ['Own W'],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  MockClient client() => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/mobile/preparation/snapshot');
        return http.Response(
            jsonEncode({
              'warehouses': ['Own W', 'Other W'],
              'assigned_warehouses': ['Own W'],
              'material_warehouses': ['Own W'],
              'materials': [],
              'orders': [],
              'history': [],
            }),
            200,
            headers: {'content-type': 'application/json'});
      });

  test('scale destinations include only assigned warehouses and support search',
      () async {
    await http.runWithClient(() async {
      final all = await fetchGScaleDefaultWarehouses();
      expect(all.map((w) => w.warehouse), ['Own W']);
      final filtered =
          await fetchGScaleDefaultWarehouses(query: 'other', limit: 1);
      expect(filtered, isEmpty);
    }, client);
  });

  testWidgets('receipt warehouse picker shows only assigned warehouses',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OperatorDashboardPage(
              server: null,
              controlOnly: true,
              onExitMode: () async {},
              onChangeServer: () async {},
              rpsBatchStateLoader: () async => const GScaleRpsBatchResponse(
                ok: true,
                batch: GScaleRpsBatchSession(
                  id: '',
                  active: false,
                  driverUrl: '',
                  itemCode: '',
                  itemName: '',
                  warehouse: '',
                  printer: '',
                  printMode: 'label',
                  quantitySource: 'manual',
                  manualQtyKg: 0,
                  tareEnabled: false,
                  tareKg: 0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final warehouseField = find.ancestor(
        of: find.text('Ombor tanlang'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(warehouseField);
      await tester.tap(warehouseField);
      await tester.pumpAndSettle();

      expect(find.text('Own W'), findsOneWidget);
      expect(find.text('Other W'), findsNothing);
    }, client);
  });

  testWidgets('explicit scale destination overrides saved default warehouse',
      (tester) async {
    await saveOperatorControlDraft(const OperatorControlDraft(
      itemCode: 'RAW-1',
      itemName: 'Kley',
      itemRequiresDimensions: false,
      warehouse: 'Own W',
      printMode: 'label',
      printer: 'godex',
      quantitySource: 'manual',
      manualQtyText: '10',
      manualDuplicateText: '',
      babinaEnabled: false,
      babinaText: '',
      warehouseMode: 'default',
      defaultWarehouse: 'Own W',
      lengthText: '125',
    ));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: OperatorDashboardPage(
        server: null,
        controlOnly: true,
        initialWarehouse: 'Other W',
        onExitMode: () async {},
        onChangeServer: () async {},
        rpsBatchHistoryLoader: () async => [],
        rpsBatchStateLoader: () async => const GScaleRpsBatchResponse(
          ok: true,
          batch: GScaleRpsBatchSession(
            id: '',
            active: false,
            driverUrl: '',
            itemCode: '',
            itemName: '',
            warehouse: '',
            printer: '',
            printMode: 'label',
            quantitySource: 'manual',
            manualQtyKg: 0,
            tareEnabled: false,
            tareKg: 0,
          ),
        ),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Other W'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
      await tester.pumpAndSettle();
      expect(find.text('Ombor: Other W • Qo‘lda kg • Babina: Yo‘q'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, client);
  });
}
