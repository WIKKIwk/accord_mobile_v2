import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/gscale/gscale_mobile_app.dart';
import 'package:accord_mobile_v2/src/features/gscale/presentation/gscale_mode_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets(
      'formula receipt selects its material and clears every old receipt field',
      (tester) async {
    await saveOperatorControlDraft(const OperatorControlDraft(
      orderId: 'order-0317',
      itemCode: 'OLD',
      itemName: 'Old material',
      itemRequiresDimensions: true,
      warehouse: 'Own W',
      printMode: 'label',
      printer: 'godex',
      quantitySource: 'manual',
      manualQtyText: '182.16',
      manualDuplicateText: '3',
      babinaEnabled: true,
      babinaText: '2',
      warehouseMode: 'default',
      defaultWarehouse: 'Own W',
      widthText: '495',
      micronText: '50',
      lengthText: '8000',
      materialSupplier: 'Xitoy',
      contextSaved: true,
    ));
    await _withCatalog(
        tester, [_item('OTHER', 'Other'), _item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pumpAndSettle();
      expect(find.text('PE PR'), findsOneWidget);
      expect(find.text('Old material'), findsNothing);
      expect(find.text('Own W'), findsNothing);
      expect(_field(tester, 'Eni (mm)'), '');
      expect(_field(tester, 'Mikron'), '');
      expect(_field(tester, 'Metraj (m)'), '');
      final saved = await loadOperatorControlDraft();
      expect(saved.orderId, 'order-0317');
      expect(saved.itemCode, 'PE PR');
      expect(saved.warehouse, '');
      expect(saved.defaultWarehouse, '');
      expect(saved.manualQtyText, '');
      expect(saved.manualDuplicateText, '');
      expect(saved.babinaText, '');
      expect(saved.materialSupplier, '');
      expect(saved.contextSaved, isFalse);

      final warehouseField = find
          .ancestor(
            of: find.text('Ombor tanlang'),
            matching: find.byType(InkWell),
          )
          .first;
      await tester.ensureVisible(warehouseField);
      await tester.tap(warehouseField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Own W').last);
      await tester.pumpAndSettle();
      // This entry keeps the normal QR receipt fields, even in a master's
      // own warehouse which normally offers the QR-free simple receipt.
      expect(find.widgetWithText(TextField, 'Eni (mm)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Metraj (m)'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Kirim qilish'), findsNothing);
    });
  });

  for (final ambiguous in [false, true]) {
    testWidgets(
        ambiguous
            ? 'ambiguous material does not select an arbitrary item'
            : 'missing material stays unselected', (tester) async {
      final items = ambiguous
          ? [_item('PE-A', 'PE PR'), _item('PE-B', 'PE PR')]
          : [_item('OTHER', 'Other')];
      await _withCatalog(tester, items, () async {
        await tester.pumpWidget(_app(_dashboard()));
        await tester.pumpAndSettle();
        expect(find.text('Homashyo'), findsOneWidget);
        expect(
            find.textContaining(ambiguous
                ? 'bir nechta katalog'
                : 'katalog mahsuloti topilmadi'),
            findsOneWidget);
        expect((await loadOperatorControlDraft()).itemCode, isEmpty);
      });
    });
  }

  for (final variant in ['', 'other-variant', 'variant-lg']) {
    testWidgets('formula receipt resumes only a batch with its saved variant: $variant',
        (tester) async {
      final batch = GScaleRpsBatchSession.fromJson({
        'id': 'active-formula-batch', 'revision': 1, 'active': true,
        'item_code': 'PE PR', 'item_name': 'PE PR', 'warehouse': 'Own W',
        'length_m': 125, 'order_assignment': {
          'order_id': 'order-0317',
          if (variant.isNotEmpty) 'preparation_formula': {
            'material_id': 'builtin-pe-pr', 'variant_id': variant,
          },
        },
      });
      await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
        await tester.pumpWidget(_app(_dashboard(batch: batch, formulaVariantId: 'variant-lg')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Faol batch tanlangan shnek formulasiga bog‘lanmagan'),
            variant == 'variant-lg' ? findsNothing : findsWidgets);
      });
    });
  }

  testWidgets(
      'an active batch keeps its context and reports a conflicting formula material',
      (tester) async {
    final active = GScaleRpsBatchSession.fromJson({
      'id': 'active-batch',
      'revision': 7,
      'active': true,
      'order_assignment': {'order_id': 'order-0317', 'apparatus': 'pechat'},
      'driver_url': 'usb://local',
      'item_code': 'PET',
      'item_name': 'Existing PET',
      'warehouse': 'Own W',
      'printer': 'godex',
      'print_mode': 'label',
      'quantity_source': 'manual',
      'manual_qty_kg': 0,
      'tare_enabled': false,
      'tare_kg': 0,
      'width_mm': 390,
      'micron': 12,
      'length_m': 125,
    });
    await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(_dashboard(batch: active)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Existing PET • 390 mm'), findsOneWidget);
      expect(find.text('PE PR'), findsNothing);
      expect(find.textContaining('Boshqa homashyo yoki order uchun batch faol'),
          findsOneWidget);
      expect(find.text('Faol batch orderi: order-0317'), findsOneWidget);
    });
  });

  testWidgets(
      'Tayyorlov wrapper keeps the original order after snapshot refresh',
      (tester) async {
    final order = PreparationOrder.fromJson({
      'id': 'order-0317',
      'code': '0317',
      'title': 'Silver choy',
      'order_kg': '300',
      'width_mm': 495,
      'saved': false,
    });
    await _withCatalog(tester, [_item('PET', 'PET'), _item('PE PR', 'PE PR')],
        () async {
      await tester.pumpWidget(_app(GScaleModeScreen(
        initialOrder: order,
        initialMaterialId: 'builtin-pe-pr',
        initialMaterialName: 'PE PR',
        freshForm: true,
      )));
      await tester.pumpAndSettle();
      expect(find.text('0317 — Silver choy'), findsOneWidget);
      expect(find.text('PE PR'), findsOneWidget);
      final dashboard = tester
          .widget<OperatorDashboardPage>(find.byType(OperatorDashboardPage));
      expect(dashboard.linkedOrderId, 'order-0317');
      expect(AppSession.instance.profile?.role, UserRole.tayyorlovMasteri);
      expect(_field(tester, 'Eni (mm)'), '');
      expect(_field(tester, 'Mikron'), '');
      expect(_field(tester, 'Metraj (m)'), '');
    });
  });

  testWidgets(
      'late catalog response keeps receipt context locked until the preset is ready',
      (tester) async {
    final catalogReady = Completer<void>();
    bool? orderLocked;
    await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(OperatorDashboardPage(
        server: null,
        controlOnly: true,
        linkedOrderId: 'order-0317',
        freshForm: true,
        initialMaterialId: 'builtin-pe-pr',
        initialMaterialName: 'PE PR',
        orderSectionBuilder: (disabled) {
          orderLocked = disabled;
          return const SizedBox.shrink();
        },
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
                tareKg: 0)),
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(orderLocked, isTrue);
      expect(find.widgetWithText(TextField, 'Eni (mm)'), findsNothing);
      final warehouseInk = find
          .ancestor(
              of: find.text('Ombor tanlang'), matching: find.byType(InkWell))
          .first;
      expect(tester.widget<InkWell>(warehouseInk).onTap, isNull);
      catalogReady.complete();
      await tester.pumpAndSettle();
      expect(orderLocked, isFalse);
      expect(find.text('PE PR'), findsOneWidget);
      expect(_field(tester, 'Eni (mm)'), '');
      expect(
          tester
              .widget<TextField>(find.widgetWithText(TextField, 'Eni (mm)'))
              .enabled,
          isTrue);
    }, intercept: (request) async {
      if (request.url.path.endsWith('/gscale/items')) await catalogReady.future;
      return null;
    });
  });

  testWidgets(
      'formula receipt uses the backend catalog when demo mode is enabled',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    var reads = 0;
    await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pumpAndSettle();
      expect(reads, greaterThan(0));
      expect(find.text('PE PR'), findsOneWidget);
      expect(_field(tester, 'Eni (mm)'), '');
    }, intercept: (request) async {
      if (request.url.path.endsWith('/gscale/items')) reads++;
      return null;
    });
  });

  testWidgets('late formula context initializes the selected material',
      (tester) async {
    await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(_dashboard(freshForm: false)));
      await tester.pumpAndSettle();
      expect(find.text('Homashyo'), findsOneWidget);
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pumpAndSettle();
      expect(find.text('PE PR'), findsOneWidget);
      expect(_field(tester, 'Eni (mm)'), '');
    });
  });

  testWidgets(
      'late original order binding does not abandon the material preset',
      (tester) async {
    await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(_dashboard(linkedOrderId: '')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Buyurtma yoki homashyo ma’lumoti'),
          findsOneWidget);
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pumpAndSettle();
      expect(find.text('PE PR'), findsOneWidget);
      expect(find.textContaining('Buyurtma yoki homashyo ma’lumoti'),
          findsNothing);
    });
  });

  testWidgets(
      'temporary order revalidation does not consume an unapplied preset',
      (tester) async {
    final firstLookup = Completer<void>();
    var first = true;
    await _withCatalog(tester, [_item('PE PR', 'PE PR')], () async {
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_app(_dashboard(linkedOrderId: '')));
      await tester.pump();
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pumpAndSettle();
      expect(find.text('PE PR'), findsOneWidget);
      firstLookup.complete();
      await tester.pumpAndSettle();
      expect(find.text('PE PR'), findsOneWidget);
    }, intercept: (request) async {
      if (first && request.url.path.endsWith('/gscale/items')) {
        first = false;
        await firstLookup.future;
      }
      return null;
    });
  });

  testWidgets(
      'a late old material lookup cannot replace a newer formula context',
      (tester) async {
    final oldCatalog = Completer<void>();
    await _withCatalog(tester, [_item('PE PR', 'PE PR'), _item('PET', 'PET')],
        () async {
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(_app(_dashboard(
        materialId: 'builtin-pet',
        materialName: 'PET',
      )));
      await tester.pumpAndSettle();
      expect(find.text('PET'), findsOneWidget);
      oldCatalog.complete();
      await tester.pumpAndSettle();
      expect(find.text('PET'), findsOneWidget);
      expect(find.text('PE PR'), findsNothing);
    }, intercept: (request) async {
      if (request.url.path.endsWith('/gscale/items') &&
          request.url.queryParameters['q'] == 'builtin-pe-pr') {
        await oldCatalog.future;
      }
      return null;
    });
  });

  testWidgets('material lookup error survives printer state refresh',
      (tester) async {
    await _withCatalog(tester, [_item('OTHER', 'Other')], () async {
      await tester.pumpWidget(_app(_dashboard()));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('katalog mahsuloti topilmadi'), findsOneWidget);
      await tester.pumpWidget(_app(_dashboard(
        printTransport: PrintTransport.bluetooth,
      )));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('katalog mahsuloti topilmadi'), findsOneWidget);
      expect(find.text('Homashyo'), findsOneWidget);
    });
  });
}

Map<String, dynamic> _item(String code, String name) => {
      'code': code,
      'name': name,
      'item_group': 'Rulon',
      'requires_dimensions': true,
      'order_apparatus_options': {'pechat': 'Bosma'},
    };

OperatorDashboardPage _dashboard({
  GScaleRpsBatchSession? batch,
  bool freshForm = true,
  String linkedOrderId = 'order-0317',
  String materialId = 'builtin-pe-pr',
  String materialName = 'PE PR',
  String formulaVariantId = '',
  PrintTransport printTransport = PrintTransport.wifi,
}) =>
    OperatorDashboardPage(
      server: null,
      controlOnly: true,
      linkedOrderId: linkedOrderId,
      linkedOrderWidthMm: 495,
      freshForm: freshForm,
      initialMaterialId: materialId,
      initialMaterialName: materialName,
      initialFormulaVariantId: formulaVariantId,
      printTransport: printTransport,
      onExitMode: () async {},
      onChangeServer: () async {},
      rpsBatchHistoryLoader: () async => [],
      rpsBatchStateLoader: () async => GScaleRpsBatchResponse(
        ok: true,
        batch: batch ??
            const GScaleRpsBatchSession(
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
    );

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

String _field(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

Future<void> _withCatalog(
  WidgetTester tester,
  List<Map<String, dynamic>> items,
  Future<void> Function() body, {
  Future<http.Response?> Function(http.Request)? intercept,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1400));
  await http.runWithClient(() async {
    try {
      await body();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(null);
    }
  },
      () => MockClient((request) async {
            expect(request.method, 'GET',
                reason:
                    'Opening a formula receipt must not create production or stock');
            final intercepted = await intercept?.call(request);
            if (intercepted != null) return intercepted;
            if (request.url.path.endsWith('/profile')) {
              return _json({
                'role': 'tayyorlov_masteri',
                'ref': 'prep-1',
                'display_name': 'Master',
                'capabilities': [
                  'preparation.access',
                  'gscale.catalog.read',
                  'rps.batch.manage'
                ],
                'assigned_warehouses': ['Own W'],
              });
            }
            if (request.url.path.endsWith('/rps/batch/state')) {
              return _json({
                'ok': true,
                'batch': {'active': false}
              });
            }
            if (request.url.path.endsWith('/gscale/items')) {
              expect(request.url.queryParameters['order_id'], 'order-0317');
              return _json(items);
            }
            if (request.url.path.endsWith('/preparation/snapshot')) {
              return _json({
                'warehouses': ['Own W'],
                'assigned_warehouses': ['Own W'],
                'material_warehouses': ['Own W'],
                'materials': [],
                'orders': [
                  {
                    'id': 'order-0317',
                    'code': '0317',
                    'title': 'Silver choy',
                    'order_kg': '300',
                    'width_mm': 495,
                    'saved': false
                  }
                ],
                'history': [],
              });
            }
            return _json([]);
          }));
}

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});
