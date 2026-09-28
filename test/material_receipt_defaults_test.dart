import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/gscale/material_receipt_defaults.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/widgets/preparation_kirim_order_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('warehouse preference uses frequency, recency, allowed scope and user',
      () async {
    final prefs = MaterialWarehousePreferences('server/user-1');
    expect(await prefs.preferred(['A', 'B']), isNull);
    expect(await prefs.preferred(['A']), 'A');
    await prefs.record('A');
    await prefs.record('A');
    await prefs.record('B');
    expect(await prefs.preferred(['A', 'B']), 'A');
    await prefs.record('B');
    expect(await prefs.preferred(['A', 'B']), 'B');
    expect(await prefs.preferred(['A']), 'A');
    expect(
        await MaterialWarehousePreferences('server/user-2')
            .preferred(['A', 'B']),
        isNull);
  });

  test('each saved micron is a separate material choice', () {
    final choices = MaterialReceiptChoice.fromItems([
      SupplierItem.fromJson({
        'code': 'PET',
        'name': 'PET',
        'order_microns': [12, 20, 12]
      })
    ]);
    expect(choices.map((item) => item.micron), [12, 20]);
  });

  testWidgets(
      'receipt order section selects the supplied order and refreshes its width',
      (tester) async {
    final initial = PreparationOrder.fromJson({
      'id': 'order-1',
      'code': '0035',
      'title': 'Guruch',
      'order_kg': '100',
      'width_mm': 384,
      'saved': false
    });
    PreparationOrder? selected;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: Scaffold(
          body: PreparationKirimOrderSection(
        initialOrder: initial,
        loadOrders: () async => [initial],
        onOrderChanged: (order) => selected = order,
      )),
    ));
    await tester.pumpAndSettle();
    expect(selected?.id, 'order-1');
    expect(find.text('0035 — Guruch'), findsOneWidget);
    expect(find.text('Order eni: 384 mm'), findsOneWidget);
  });

  testWidgets(
      'receipt auto-selects a single order material and lets users choose among several',
      (tester) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material-1',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'raw_material.assign',
        'gscale.catalog.read',
        'rps.batch.manage'
      ],
      assignedWarehouses: ['A', 'B'],
    );
    final prefs = MaterialWarehousePreferences(jsonEncode(
        [MobileApi.baseUrl, UserRole.materialTaminotchi.name, 'material-1']));
    await prefs.record('B');
    await saveOperatorControlDraft(const OperatorControlDraft(
      itemCode: 'OLD',
      itemName: 'Old material',
      warehouse: 'A',
      printMode: 'label',
      printer: 'zebra',
      quantitySource: 'manual',
      manualQtyText: '',
      manualDuplicateText: '',
      babinaEnabled: false,
      babinaText: '',
      warehouseMode: 'manual',
      defaultWarehouse: '',
      widthText: '900',
      micronText: '99',
      lengthText: '234',
      contextSaved: true,
    ));
    var catalogRequests = 0;
    Widget dashboard(String id, double width) => MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: Scaffold(
            body: OperatorDashboardPage(
          controlOnly: true,
          server: null,
          linkedOrderId: id,
          linkedOrderWidthMm: width,
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
                  tareKg: 0)),
        )));
    String field(String label) => tester
        .widget<TextField>(find.widgetWithText(TextField, label))
        .controller!
        .text;
    await http.runWithClient(() async {
      await tester.pumpWidget(dashboard('order-1', 384));
      await tester.pumpAndSettle();
      expect(field('Eni (mm)'), '384');
      expect(field('Mikron'), '');
      expect(field('Metraj (m)'), '');
      expect(find.text('Old material'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('PET'), findsNothing);
      await tester.tap(find.text('Homashyo'));
      await tester.pumpAndSettle();
      expect(find.text('PET — 12 mkm'), findsOneWidget);
      expect(find.text('PET — 20 mkm'), findsOneWidget);
      expect(find.text('PP — 30 mkm'), findsOneWidget);
      await tester.tap(find.text('PET — 20 mkm'));
      await tester.pumpAndSettle();
      expect(field('Mikron'), '20');
      expect(field('Eni (mm)'), '384');
      expect(catalogRequests, 1);
      await tester.enterText(find.widgetWithText(TextField, 'Eni (mm)'), '390');
      await tester.enterText(
          find.widgetWithText(TextField, 'Metraj (m)'), '777');
      await tester.pumpWidget(dashboard('order-2', 500));
      await tester.pumpAndSettle();
      expect(field('Eni (mm)'), '500');
      expect(find.text('PET'), findsOneWidget);
      expect(field('Mikron'), '12');
      expect(field('Metraj (m)'), '');
      expect(find.text('B'), findsOneWidget);
      expect(catalogRequests, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/gscale/items')) {
                catalogRequests++;
                final orderId = request.url.queryParameters['order_id'];
                expect(orderId, anyOf('order-1', 'order-2'));
                final items = orderId == 'order-1'
                    ? [
                        {
                          'code': 'PET',
                          'name': 'PET',
                          'requires_dimensions': true,
                          'order_microns': [12, 20]
                        },
                        {
                          'code': 'PP',
                          'name': 'PP',
                          'requires_dimensions': true,
                          'order_microns': [30]
                        }
                      ]
                    : [
                        {
                          'code': 'PET',
                          'name': 'PET',
                          'requires_dimensions': true,
                          'order_microns': [12]
                        }
                      ];
                return http.Response(jsonEncode(items), 200);
              }
              if (request.url.path.endsWith('/warehouses')) {
                return http.Response(
                    jsonEncode([
                      {'warehouse': 'A'},
                      {'warehouse': 'B'}
                    ]),
                    200);
              }
              return http.Response('{}', 200);
            }));
  });
}
