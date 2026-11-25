import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/printing/session_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/m3_confirm_dialog.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/raw_material_scan_dialog.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_list_row.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_expandable_filter_chip.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_production_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/material_paddon_details_sheet.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/material_paddon_issue_dialog.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_production_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _epc = '303132333435363738394142';
const _recipe = {
  'variant_id': 'variant-lg',
  'variant_name': 'LG',
  'material_id': 'pe-pr',
  'material_name': 'PE PR',
  'captured_at': '2026-10-29T05:00:00Z',
  'formulas': [
    {
      'name': 'A',
      'share_percent': '30.000000',
      'lines': [
        {'item_code': 'S1', 'name': 'Seriya ORIGINAL', 'percent': '88.000000'},
        {'item_code': 'S2', 'name': 'Seriya 2', 'percent': '12.000000'},
      ]
    },
    {
      'name': 'B',
      'share_percent': '70.000000',
      'lines': [
        {'item_code': 'S2', 'name': 'Seriya 2', 'percent': '100.000000'},
      ]
    },
  ],
};

Map<String, dynamic> _order({String id = 'zakaz-0317', String code = '0317'}) =>
    {
      'order_id': id,
      'order_code': code,
      'order_title': 'Silver choy $code',
      'customer_name': 'Silver choy',
      'active_batch_count': 1,
      'batch_count': 1,
      'roll_count': 1,
      'total_net_kg': '23.000000',
      'total_length_m': '125.000000',
      'last_activity_at': '2026-10-29T05:01:00Z',
    };

Map<String, dynamic> _batch({Object? recipe = _recipe}) => {
      'batch_id': 'batch-lg',
      'order_id': 'zakaz-0317',
      'item_code': 'PE PR',
      'item_name': 'PE PR',
      'warehouse': 'Own W',
      'active': true,
      'started_at': '2026-10-29T05:00:00Z',
      'ended_at': '',
      'last_activity_at': '2026-10-29T05:01:00Z',
      'roll_count': 1,
      'total_net_kg': '23.000000',
      'total_length_m': '125.000000',
      'preparation_formula': recipe,
    };

Map<String, dynamic> _roll({Object? recipe = _recipe}) => {
      'epc': _epc,
      'receipt_name': 'MAT-TRACE-1',
      'item_code': 'PE PR',
      'item_name': 'PE PR',
      'warehouse': 'Own W',
      'net_kg': '23.000000',
      'gross_kg': '25.000000',
      'length_m': '125.000000',
      'width_mm': '495.000000',
      'micron': '50.000000',
      'printed_at': '2026-10-29T05:01:00Z',
      'preparation_formula': recipe,
    };

SessionProfile _profile(
        {String ref = 'prep-1',
        UserRole role = UserRole.tayyorlovMasteri,
        List<String> capabilities = const [
          'preparation.access',
          'rps.batch.manage'
        ]}) =>
    SessionProfile(
        role: role,
        displayName: 'Master',
        legalName: '',
        ref: ref,
        phone: '',
        avatarUrl: '',
        capabilities: capabilities);

http.Response _json(Object value, {int status = 200}) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'});

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: home,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );

http.Response _route(http.Request request, {Object? recipe = _recipe}) {
  expect(request.method, 'GET');
  expect(request.headers['Authorization'], 'Bearer token');
  switch (request.url.path) {
    case '/v1/mobile/preparation/production/batches':
      return _json({
        'batches': [_batch(recipe: recipe)],
        'has_more': false,
        'next_offset': null
      });
    case '/v1/mobile/preparation/production/orders':
      return _json({
        'orders': [_order()],
        'has_more': false,
        'next_offset': null
      });
    case '/v1/mobile/preparation/production/order':
      expect(request.url.queryParameters['order_id'], 'zakaz-0317');
      return _json({
        'order': _order(),
        'batches': [_batch(recipe: recipe)],
        'has_more': false,
        'next_offset': null
      });
    case '/v1/mobile/preparation/production/batch':
      expect(request.url.queryParameters['batch_id'], 'batch-lg');
      return _json({
        'batch': _batch(recipe: recipe),
        'rolls': [_roll(recipe: recipe)],
        'has_more': false,
        'next_offset': null
      });
    default:
      fail(
          'Unexpected request ${request.url}: the journal must use saved production records');
  }
}

Future<void> _openOrders(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('production-view-orders')));
  await tester.pumpAndSettle();
}

Future<void> _withApp(WidgetTester tester, Future<void> Function() body,
    FutureOr<http.Response> Function(http.Request) respond) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await http.runWithClient(() async {
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => MockClient((request) async => respond(request)));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile();
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('production route requires the master role and its workspace capability',
      () {
    expect(AppRouter.canOpenRoute(AppRoutes.preparationProduction), isTrue);
    AppSession.instance.profile = _profile(role: UserRole.admin);
    expect(AppRouter.canOpenRoute(AppRoutes.preparationProduction), isFalse);
    AppSession.instance.profile = _profile(capabilities: const []);
    expect(AppRouter.canOpenRoute(AppRoutes.preparationProduction), isFalse);
  });

  testWidgets('master home opens the production journal', (tester) async {
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationScreen()));
      await tester.pumpAndSettle();
      final entry = find.text('Tayyorlov hisobi');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(PreparationProductionScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('production-batch:batch-lg')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        (request) => request.url.path.endsWith('/preparation/snapshot')
            ? _json({
                'warehouses': [],
                'assigned_warehouses': [],
                'material_warehouses': [],
                'materials': [],
                'orders': [],
                'history': []
              })
            : _route(request));
  });

  testWidgets('paddons show incoming stock and use their own balance filter',
      (tester) async {
    final requests = <Uri>[];
    await _withApp(tester, () async {
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-status-active')));
      await tester.pumpAndSettle();

      final paddons = find.byKey(const ValueKey('production-view-paddons'));
      await tester.ensureVisible(paddons);
      await tester.pumpAndSettle();
      await tester.tap(paddons);
      await tester.pumpAndSettle();
      expect(requests.last.path, endsWith('/raw-material-paddons'));
      expect(requests.last.queryParameters['status'], 'all');
      expect(find.text('Granula zaxirasi'), findsOneWidget);
      expect(find.textContaining('P-001'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('preparation-paddon:p1')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Granula zaxirasi'),
        ),
        findsOneWidget,
      );
      expect(find.text('Granula'), findsOneWidget);
      expect(find.text('Partiya: LOT-1'), findsOneWidget);
      expect(find.text('3 ta qop'), findsOneWidget);
      expect(find.text('Jami 75 kg'), findsOneWidget);
      final issue = find.byKey(const ValueKey('paddon-open-issue'));
      final print = find.byKey(const ValueKey('paddon-print-qr'));
      expect(
        tester.getRect(print).top - tester.getRect(issue).bottom,
        greaterThanOrEqualTo(8),
      );
      await tester.tapAt(const Offset(12, 12));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('paddon-balance-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-balance-empty')));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['status'], 'empty');
      expect(find.byKey(const ValueKey('preparation-paddon:p1')), findsNothing);
      expect(find.text('Xomashyo paddonlari topilmadi.'), findsOneWidget);

      final batches = find.byKey(const ValueKey('production-view-batches'));
      await tester.ensureVisible(batches);
      await tester.pumpAndSettle();
      final readsBeforeReturning = requests.length;
      await tester.tap(batches);
      await tester.pumpAndSettle();
      expect(requests.length, readsBeforeReturning);
      expect(requests.lastWhere((uri) => uri.path.endsWith('/production/batches'))
          .queryParameters['status'], 'active');
      expect(find.text('Holat: Davom etmoqda'), findsOneWidget);
      expect(find.byKey(const ValueKey('production-batch:batch-lg')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, (request) {
      requests.add(request.url);
      if (!request.url.path.endsWith('/raw-material-paddons')) {
        return _route(request);
      }
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer token');
      return _json({
        'has_more': false,
        'next_offset': null,
        'paddons': [
          if (request.url.queryParameters['status'] != 'empty')
            {
              'paddon_id': 'p1',
              'paddon_code': 'P-001',
              'name': 'Granula zaxirasi',
              'warehouse': 'Own W',
              'remaining_kg': '75.000000',
              'contents': [
                {
                  'item_name': 'Granula',
                  'lot_number': 'LOT-1',
                  'kind': 'bag',
                  'line_no': 1,
                  'remaining_count': 3,
                  'remaining_kg': '75.000000',
                },
              ],
            },
        ],
      });
    });
  });

  for (final (materialRole, plainRoll) in [(false, false), (true, false), (true, true)]) {
    testWidgets('paddon FAB receives stock for the active role ($materialRole, plain roll $plainRoll)',
        (tester) async {
      if (materialRole) {
        AppSession.instance.profile = _profile(
          ref: 'material-1',
          role: UserRole.materialTaminotchi,
          capabilities: ['gscale.catalog.read', 'gscale.print'],
        ).copyWith(assignedWarehouses: ['Own W']);
      }
      expect(AppRouter.canOpenRoute(AppRoutes.materialPaddons), materialRole);
      final submissions = <Object?>[];
      var created = false;
      await _withApp(tester, () async {
        await tester.pumpWidget(_app(materialRole
            ? const PreparationProductionScreen.materialPaddons()
            : const PreparationProductionScreen()));
        await tester.pumpAndSettle();
        if (!materialRole) {
          expect(find.byIcon(Icons.add_rounded), findsOneWidget);
          final paddons = find.byKey(const ValueKey('production-view-paddons'));
          await tester.ensureVisible(paddons);
          await tester.pumpAndSettle();
          await tester.tap(paddons);
          await tester.pumpAndSettle();
        }
        await tester.tap(materialRole
            ? find.byKey(const ValueKey('material-paddons-fab'))
            : find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Paddon qo‘shish'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('paddon-empty-mode')),
          materialRole ? findsNothing : findsOneWidget,
        );
        if (!materialRole) {
          await tester.enterText(
              find.byKey(const ValueKey('paddon-name')), '  Ertalabki granula  ');
        }
        await tester.tap(find.byKey(const ValueKey('paddon-item-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Granula'));
        await tester.pumpAndSettle();
        if (plainRoll) {
          await tester.tap(find.byKey(const ValueKey('paddon-kind-0-G1')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Rulon').last);
          await tester.pumpAndSettle();
          expect(find.text('Rulon o‘lchamlari'), findsOneWidget);
          expect(find.text('Qalinligi'), findsNothing);
        }
        await tester.enterText(find.byKey(const ValueKey('paddon-count-0')), '3');
        final kg = find.byKey(const ValueKey('paddon-unit-kg-0'));
        await tester.ensureVisible(kg);
        if (!materialRole) await tester.enterText(kg, '25');
        final save = find.byKey(const ValueKey('paddon-receipt-save'));
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(submissions.length, 1);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(submissions.length, 2);
        expect(submissions.first, submissions.last);
        expect(find.byKey(const ValueKey('preparation-paddon:p-new')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      }, (request) {
        switch (request.url.path) {
          case '/v1/mobile/raw-material-paddons':
            if (request.method == 'POST') {
              final body = jsonDecode(request.body) as Map;
              expect(body['warehouse'], 'Own W');
              if (materialRole) {
                expect(body.containsKey('name'), isFalse);
              } else {
                expect(body['name'], 'Ertalabki granula');
              }
              expect(body['contents'], [
                {
                  'item_code': 'G1',
                  'lot_number': '',
                  'kind': plainRoll ? 'roll' : 'bag',
                  'count': 3,
                  if (!materialRole) 'unit_kg': '25',
                }
              ]);
              expect(body['request_id'], isNotEmpty);
              submissions.add(body);
              if (submissions.length == 1) {
                return _json({'error': 'Temporary error'}, status: 503);
              }
              created = true;
              return _json({'paddon_id': 'p-new', 'paddon_code': 'XP-NEW'});
            }
            return _json({
              'has_more': false,
              'paddons': [
                if (created)
                  {
                    'paddon_id': 'p-new',
                    'paddon_code': 'XP-NEW',
                    'warehouse': 'Own W',
                    'remaining_kg': materialRole ? '0' : '75',
                    'unweighed_count': materialRole ? 3 : 0,
                    'contents': [
                      {
                        'item_name': 'Granula',
                        'kind': 'bag',
                        'remaining_count': 3,
                        if (!materialRole) 'unit_kg': '25',
                        'unweighed_count': materialRole ? 3 : 0,
                        'remaining_kg': materialRole ? '0' : '75',
                      }
                    ],
                  },
              ],
            });
          case '/v1/mobile/preparation/snapshot':
            return _json({
              'warehouses': ['Own W'],
              'assigned_warehouses': ['Own W'],
              'material_warehouses': ['Own W'],
              'materials': [
                {'item_code': 'G1', 'name': 'Granula'}
              ],
              'orders': [],
              'history': [],
            });
          case '/v1/mobile/gscale/items':
            return _json([
              {'code': 'G1', 'name': 'Granula', 'uom': 'kg', 'warehouse': ''}
            ]);
          default:
            return _route(request);
        }
      });
    });
  }

  testWidgets('master opens an empty paddon in an assigned shared warehouse',
      (tester) async {
    const code = 'XP-ABCDEF0123456789';
    const title = 'Tayyor rulonlar';
    const receipt = 'MAT-TRACE-1';
    const warehouse = 'Shared W';
    const paddon = {
      'paddon_id': 'p-empty',
      'paddon_code': code,
      'name': title,
      'warehouse': warehouse,
      'remaining_kg': '0',
      'remaining_count': 0,
      'unweighed_count': 0,
      'contents': [],
    };
    final submissions = <Map<String, dynamic>>[];
    var attached = false;

    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      final paddons = find.byKey(const ValueKey('production-view-paddons'));
      await tester.ensureVisible(paddons);
      await tester.pumpAndSettle();
      await tester.tap(paddons);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddon qo‘shish'));
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('paddon-empty-mode'));
      final name = find.byKey(const ValueKey('paddon-name'));
      final save = find.byKey(const ValueKey('paddon-receipt-save'));
      expect(find.byKey(const ValueKey('paddon-item-0')), findsOneWidget);
      final warehouseField = find.byKey(const ValueKey('paddon-warehouse-filled'));
      await tester.tap(warehouseField);
      await tester.pumpAndSettle();
      expect(find.text(warehouse), findsNothing);
      Navigator.of(tester.element(find.text('Own W').last)).pop();
      await tester.pumpAndSettle();

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paddon-item-0')), findsNothing);
      expect(find.text('Paddon ochish'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Omborni tanlang'), findsOneWidget);
      expect(submissions, isEmpty);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(warehouse).last);
      await tester.pumpAndSettle();
      await tester.enterText(name, title);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Qayta urinish'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(submissions, hasLength(2));
      expect(submissions.first, submissions.last);
      expect(find.text('Paddon $code ochildi'), findsOneWidget);

      final row = find.byKey(const ValueKey('preparation-paddon:p-empty'));
      expect(find.descendant(of: row, matching: find.textContaining('Qoldiq: 0 kg')),
          findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final qr = find.byType(QrImageView);
      expect(qr, findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(code)),
          findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-open-issue')), findsNothing);
      Navigator.of(tester.element(qr)).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('production-view-rolls')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('production-roll:$_epc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-$code')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-save')));
      await tester.pumpAndSettle();
      expect(attached, isTrue);
      expect(find.text('1 ta rulon $code paddoniga biriktirildi'), findsOneWidget);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'raw-material-paddons':
          if (request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body, {
              'warehouse': warehouse,
              'name': title,
              'contents': [],
              'request_id': isNotEmpty,
            });
            submissions.add(body);
            if (submissions.length == 1) {
              return _json({'error': 'Javob olinmadi'}, status: 503);
            }
            return _json({'paddon_id': 'p-empty', 'paddon_code': code});
          }
          return _json({
            'paddons': [if (submissions.isNotEmpty) paddon],
            'has_more': false,
          });
        case 'snapshot':
          return _json({
            'warehouses': [warehouse, 'Own W', 'Other W'],
            'assigned_warehouses': [warehouse, 'Own W', 'Other W'],
            'material_warehouses': ['Own W', 'Other W'],
            'materials': [],
            'orders': [],
            'history': [],
          });
        case 'rolls':
          return _json({'rolls': [_roll()], 'has_more': false});
        case 'paddon-options':
          expect(submissions, hasLength(2));
          expect(jsonDecode(request.body), {
            'receipt_names': [receipt],
            'offset': 0,
          });
          return _json({
            'paddons': [paddon],
            'has_more': false,
            'roll_selection': {
              'batch_ids': [],
              'total_rolls': 1,
              'receipt_names_by_warehouse': {warehouse: [receipt]},
              'skipped': {},
              'packed_rolls': [],
            },
          });
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], code);
          expect(body['receipt_names'], [receipt]);
          attached = true;
          return _json({'paddon_code': code, 'receipt_names': [receipt]});
        default:
          return _route(request);
      }
    });
  });

  testWidgets('batch packing opens an empty paddon for the compatible rolls',
      (tester) async {
    const batchId = 'batch:lg';
    const otherId = 'batch:other';
    const warehouse = 'Packing W';
    const sourceWarehouse = 'Ibrohim W';
    const otherWarehouse = 'Ulug‘bek W';
    const code = 'XP-ABCDEF0123456789';
    const title = 'Tayyor rulonlar';
    var created = false;
    var attached = false;
    var optionsReads = 0;

    await _withApp(tester, () async {
      tester.view.physicalSize = const Size(390, 780);
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('production-batch:$batchId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-batch:$otherId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();

      expect(find.text('Mos paddon topilmadi.'), findsOneWidget);
      expect(find.text('Mavjud paddonni topish'), findsOneWidget);
      expect(find.text('$warehouse • 2 ta rulon'), findsOneWidget);
      expect(find.text('$sourceWarehouse • 2 ta rulon'), findsOneWidget);
      expect(find.text('$otherWarehouse • 1 ta rulon'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-open-paddon-$warehouse')));
      await tester.pumpAndSettle();
      expect(find.text(warehouse), findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-empty-mode')), findsNothing);
      expect(find.byKey(const ValueKey('paddon-item-0')), findsNothing);
      await tester.enterText(find.byKey(const ValueKey('paddon-name')), title);
      await tester.tap(find.byKey(const ValueKey('paddon-receipt-save')));
      await tester.pumpAndSettle();

      expect(created, isTrue);
      expect(attached, isFalse);
      expect(optionsReads, 2);
      final target = find.byKey(const ValueKey('production-attach-paddon-$code'));
      expect(tester.widget<ListTile>(target).selected, isTrue);
      expect(find.text('3 ta rulondan 2 tasi biriktiriladi'), findsOneWidget);
      expect(find.text('1 ta rulon boshqa omborda qoladi'), findsOneWidget);
      expect(find.text('$sourceWarehouse → $warehouse • 1 ta rulon ko‘chiriladi'),
          findsOneWidget);
      expect(find.text('$otherWarehouse → $warehouse • 1 ta rulon ko‘chiriladi'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-save')));
      await tester.pumpAndSettle();
      expect(attached, isTrue);
      expect(find.text('2 ta rulon $code paddoniga biriktirildi'), findsOneWidget);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'batches':
          return _json({
            'batches': [
              {..._batch(), 'batch_id': batchId, 'roll_count': 2},
              {..._batch(), 'batch_id': otherId, 'roll_count': 1},
            ],
            'has_more': false,
          });
        case 'paddon-options':
          optionsReads++;
          return _json({
            'paddons': [
              if (created)
                {
                  'paddon_id': 'p-shared',
                  'paddon_code': code,
                  'name': title,
                  'warehouse': warehouse,
                  'remaining_kg': '0',
                  'contents': [],
                },
            ],
            'has_more': false,
            'batch_selection': {
              'batch_ids': [batchId, otherId],
              'total_rolls': 3,
              'receipt_names_by_warehouse': {
                sourceWarehouse: ['MAT-A', 'MAT-B'],
                otherWarehouse: ['MAT-C'],
              },
              'transfer_receipt_names_by_warehouse': {
                warehouse: ['MAT-A', 'MAT-C'],
              },
              'skipped': {},
            },
          });
        case 'snapshot':
          return _json({
            'warehouses': [warehouse, sourceWarehouse, otherWarehouse],
            'assigned_warehouses': [warehouse, sourceWarehouse, otherWarehouse],
            'material_warehouses': [],
            'materials': [],
            'orders': [],
            'history': [],
          });
        case 'raw-material-paddons':
          expect(request.method, 'POST');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['warehouse'], warehouse);
          expect(body['name'], title);
          expect(body['contents'], isEmpty);
          expect(created, isFalse);
          created = true;
          return _json({'paddon_id': 'p-shared', 'paddon_code': code});
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['batch_ids'], [batchId, otherId]);
          expect(body['code'], code);
          expect(body['receipt_names'], ['MAT-A', 'MAT-C']);
          expect(body['transfer_between_warehouses'], isTrue);
          attached = true;
          return _json({
            'paddon_code': code,
            'receipt_names': ['MAT-A', 'MAT-C'],
          });
        default:
          return _route(request);
      }
    });
  });

  testWidgets('batch detail packs the entire batch across receipt pages',
      (tester) async {
    const batchId = 'batch:lg';
    const code = 'XP-ABCDEF0123456789';
    const warehouse = 'Own W';
    const receipts = ['MAT-TRACE-1', 'MAT-TRACE-2'];
    var attached = false;

    await _withApp(tester, () async {
      await tester.pumpWidget(
        _app(const PreparationProductionBatchScreen(batchId: batchId)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();
      expect(find.text('2 ta rulondan 2 tasi biriktirishga yaroqli'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-$code')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-save')));
      await tester.pumpAndSettle();
      expect(attached, isTrue);
      expect(find.text('2 ta rulon $code paddoniga biriktirildi'), findsOneWidget);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'batch':
          return _json({
            'batch': {..._batch(), 'batch_id': batchId, 'roll_count': 2},
            'rolls': [_roll()],
            'has_more': true,
            'next_offset': 1,
          });
        case 'paddon-options':
          expect(jsonDecode(request.body), {'batch_id': batchId, 'offset': 0});
          return _json({
            'paddons': [
              {
                'paddon_id': 'p1',
                'paddon_code': code,
                'warehouse': warehouse,
                'remaining_kg': '0',
                'contents': [],
              },
            ],
            'has_more': false,
            'batch_selection': {
              'batch_ids': [batchId],
              'total_rolls': 2,
              'receipt_names_by_warehouse': {warehouse: receipts},
              'skipped': {},
            },
          });
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['batch_id'], batchId);
          expect(body['receipt_names'], receipts);
          attached = true;
          return _json({'paddon_code': code, 'receipt_names': receipts});
        default:
          return _route(request);
      }
    });
  });

  testWidgets(
      'paddon partial checkout keeps bag balance and identifies different rolls',
      (tester) async {
    const code = 'XP-ABCDEF0123456789';
    final entries = [
      {
        'kind': 'bag',
        'issuable_count': 1,
        'remaining_count': 1,
        'line_no': 1,
        'unit_kg': '25',
        'remaining_kg': '25'
      },
      {
        'kind': 'roll',
        'issuable_count': 1,
        'remaining_count': 1,
        'line_no': 2,
        'remaining_kg': '0'
      },
      {
        'kind': 'roll',
        'issuable_count': 1,
        'remaining_count': 1,
        'line_no': 3,
        'remaining_kg': '0',
        'width_mm': '500',
        'micron': '40'
      },
      {
        'kind': 'bag',
        'issuable_count': 1,
        'remaining_count': 1,
        'line_no': 4,
        'remaining_kg': '15',
        'open_unit_no': 2
      },
    ];
    final pallet = PreparationMaterialPaddon.fromJson({
      'paddon_id': 'p1',
      'paddon_code': code,
      'warehouse': 'Own W',
      'remaining_kg': '40',
      'contents': [
        for (final e in entries)
          {...e, 'item_name': 'Material', 'lot_number': 'LOT'}
      ]
    });
    final submits = <Map>[];
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () =>
                      showMaterialPaddonIssue(context, pallet, null),
                  child: const Text('Open'))))));
      Future<void> open() async {
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
      }

      Future<void> tapKey(String key) async {
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await open();
      await tapKey('paddon-issue-line');
      expect(find.text('Material • rulon • LOT'), findsOneWidget);
      expect(find.text('Material • rulon • LOT • 500 mm • 40 mkm'),
          findsOneWidget);
      await tester.tap(find.text('Material • qop • LOT • 25 kg dan').last);
      await tester.pumpAndSettle();
      await tapKey('paddon-partial');
      await tester.enterText(
          find.byKey(const ValueKey('paddon-issue-weight-1-0')), '10');
      await tapKey('paddon-issue-save');
      expect(submits, isEmpty);
      await tester.enterText(
          find.byKey(const ValueKey('paddon-remainder-kg')), '15');
      await tapKey('paddon-issue-save');
      expect(submits.single['remainder_kg'], '15');
      expect(submits.single['weights'], ['10']);
      expect(submits.single.containsKey('destination'), isFalse);
      await open();
      await tapKey('paddon-issue-line');
      await tester.tap(find.textContaining('Ochilgan №2').last);
      await tester.pumpAndSettle();
      await tapKey('paddon-partial');
      await tester.enterText(
          find.byKey(const ValueKey('paddon-issue-weight-4-0')), '5');
      await tester.pumpAndSettle();
      expect(find.text('Paddonda qoladi: 10 kg'), findsOneWidget);
      await tapKey('paddon-issue-save');
      expect(submits.last['open_unit_no'], 2);
      expect(submits.last['expected_open_kg'], '15');
      expect(submits.last['remainder_kg'], '10.000000');
    }, (request) {
      if (request.url.path.endsWith('/locations')) return _json([]);
      final payload = jsonDecode(request.body) as Map;
      submits.add(payload);
      return _json({
        'issue_id': 'i${submits.length}',
        'paddon_code': code,
        'destination': 'Own W',
        'label_warehouse': 'Own W',
        'labels': [
          {
            'barcode': _epc,
            'item_code': 'M',
            'item_name': 'Material',
            'kg': payload['weights'][0]
          }
        ]
      });
    });
  });

  testWidgets(
      'paddon print history resumes only untouched labels after a printer interruption',
      (tester) async {
    const code = 'XP-ABCDEF0123456789';
    final pallet = PreparationMaterialPaddon.fromJson({
      'paddon_id': 'p1',
      'paddon_code': code,
      'warehouse': 'Own W',
      'remaining_kg': '0',
      'contents': []
    });
    final jobs = <String>[];
    final states = <String, Map<String, Object?>>{};
    const channel = MethodChannel('accord/bluetooth_printer');
    const printer =
        BluetoothPrinterProfile(name: 'XP-P323B', address: '00:11:22:33:44:55');
    final messenger = tester.binding.defaultBinaryMessenger;
    SessionBluetoothPrinter.remember(printer);
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pairedPrinters') {
        return [
          {'name': printer.name, 'address': printer.address}
        ];
      }
      if (call.method == 'printLabel') {
        final code = (call.arguments as Map)['epc'] as String;
        jobs.add(code);
        if (jobs.length == 2) throw PlatformException(code: 'disconnect');
        return {'ok': true, 'bytes': 1};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SessionBluetoothPrinter.forget();
    });
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showMaterialPaddonDetails(context, pallet,
                      onChanged: () {}),
                  child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-issue-history')));
      await tester.pumpAndSettle();
      Future<void> history() async {
        await tester.tap(find.textContaining('3 ta birlik').last);
        await tester.pumpAndSettle();
      }

      await history();
      await tester.tap(find.text('3 ta yorliq chiqarish'));
      await tester.pumpAndSettle();
      expect(jobs, ['UNIT-1', 'UNIT-2']);
      Navigator.of(tester.element(find.text('Chiqim yorliqlari'))).pop();
      await tester.pumpAndSettle();
      await history();
      expect(find.textContaining('Chop etilgan'), findsOneWidget);
      expect(find.textContaining('Chop holatini tekshiring'), findsOneWidget);
      SessionBluetoothPrinter.remember(printer);
      await tester.tap(find.text('1 ta yorliq chiqarish'));
      await tester.pumpAndSettle();
      expect(jobs, ['UNIT-1', 'UNIT-2', 'UNIT-3']);
      await tester.tap(find.byTooltip('Yorliq chiqqanini tasdiqlash'));
      await tester.pumpAndSettle();
      expect(states.values.every((s) => s['printed'] == true), isTrue);
      expect(jobs, hasLength(3));
    }, (request) {
      if (request.url.path.endsWith('/print')) {
        final data = jsonDecode(request.body) as Map;
        final key = data['barcode'] as String;
        if (data['action'] == 'start') {
          expect(states[key]?['attempt'], data['previous_attempt']);
        }
        final state = {
          'attempt': data['attempt'] as String,
          'printed': data['action'] == 'confirm'
        };
        states[key] = state;
        return _json(state);
      }
      return _json({
        'issues': [
          {
            'issue_id': 'i1',
            'paddon_code': code,
            'destination': 'Own W',
            'label_warehouse': 'Own W',
            'print_tracking': true,
            'print_states': states,
            'labels': [
              for (var i = 1; i <= 3; i++)
                {
                  'barcode': 'UNIT-$i',
                  'item_code': 'M',
                  'item_name': 'Material',
                  'kg': '10'
                }
            ]
          }
        ]
      });
    });
  });

  for (final viaScan in [true, false]) {
    testWidgets(
      'paddon checkout weighs and labels each unit (scan: $viaScan)',
      (tester) async {
        const code = 'XP-ABCDEF0123456789';
        const printerAddress = '00:11:22:33:44:55';
        if (viaScan) {
          AppSession.instance.profile = _profile(
            ref: 'material-1',
            role: UserRole.materialTaminotchi,
            capabilities: [
              'gscale.catalog.read',
              'gscale.print',
              'inventory.movement.manage',
            ],
          );
        }
        final labels = <Map<Object?, Object?>>[];
        final submits = <Map<dynamic, dynamic>>[];
        final lookedUp = <String?>[];
        const channel = MethodChannel('accord/bluetooth_printer');
        final messenger = tester.binding.defaultBinaryMessenger;
        SessionBluetoothPrinter.remember(
          const BluetoothPrinterProfile(
            name: 'XP-P323B',
            address: printerAddress,
          ),
        );
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'pairedPrinters') {
            return [
              {'name': 'XP-P323B', 'address': printerAddress},
            ];
          }
          if (call.method == 'printLabel') {
            labels.add(Map<Object?, Object?>.from(call.arguments as Map));
            return {'ok': true, 'bytes': 1};
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          SessionBluetoothPrinter.forget();
        });

        await _withApp(
          tester,
          () async {
            tester.view.physicalSize = const Size(360, 780);
            await tester.pumpWidget(
              _app(
                viaScan
                    ? const PreparationProductionScreen.materialPaddons()
                    : const PreparationProductionScreen(),
              ),
            );
            await tester.pumpAndSettle();
            if (viaScan) {
              await tester.tap(
                find.byKey(const ValueKey('material-paddons-fab')),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('Paddon QR skaneri'));
              await tester.pumpAndSettle();
              final input = find.descendant(
                of: find.byType(RawMaterialScanDialog),
                matching: find.byType(TextField),
              );
              await tester.enterText(input, 'raw-material-paddon:$code');
              await tester.testTextInput.receiveAction(TextInputAction.done);
              await tester.pumpAndSettle();
              expect(lookedUp, [code]);
            } else {
              final tab = find.byKey(const ValueKey('production-view-paddons'));
              await tester.ensureVisible(tab);
              await tester.pumpAndSettle();
              await tester.tap(tab);
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(const ValueKey('preparation-paddon:p1')),
              );
              await tester.pumpAndSettle();
              expect(lookedUp, isEmpty);
            }
            await tester.tap(find.byKey(const ValueKey('paddon-print-qr')));
            await tester.pumpAndSettle();
            expect(labels, hasLength(1));
            expect(
              (labels.single['epc'] as String).toUpperCase(),
              'RAW-MATERIAL-PADDON:$code',
            );
            expect(labels.single['item_name'], 'GRANULA ZAXIRASI');
            expect(labels.single['material_data_matrix'], isNull);
            labels.clear();

            final openIssue = find.byKey(const ValueKey('paddon-open-issue'));
            await tester.ensureVisible(openIssue);
            await tester.tap(openIssue);
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('paddon-issue-count')),
              '2',
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const ValueKey('paddon-issue-weight-1-0')),
              '24,6',
            );
            final save = find.byKey(const ValueKey('paddon-issue-save'));
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(submits, isEmpty);
            final secondWeight = find.byKey(
              const ValueKey('paddon-issue-weight-1-1'),
            );
            await tester.ensureVisible(secondWeight);
            await tester.enterText(secondWeight, '26.1');
            final destination = find.byKey(
              const ValueKey('paddon-issue-destination'),
            );
            await tester.ensureVisible(destination);
            await tester.tap(destination);
            await tester.pumpAndSettle();
            if (!viaScan) {
              expect(find.text('Sex • State'), findsNothing);
            }
            await tester.tap(
              find.text(viaScan ? 'Sex • State' : 'Own Next • Ombor').last,
            );
            await tester.pumpAndSettle();
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(submits, hasLength(1));
            expect(labels, isEmpty);
            expect(find.text('Natijani tekshirish'), findsOneWidget);
            await tester.tap(save);
            await tester.pumpAndSettle();
            expect(submits, hasLength(2));
            expect(submits.first, submits.last);
            expect(find.text('Chiqim yorliqlari'), findsOneWidget);
            expect(find.textContaining('50.7 kg'), findsOneWidget);
            expect(
              find.textContaining(viaScan ? 'Sex • State' : 'Own Next • Ombor'),
              findsOneWidget,
            );
            expect(labels.map((label) => label['epc']), [
              _epc,
              'PREP-PADDON-LEGACY',
            ]);
            expect(labels.map((label) => label['gross_qty']), [24.6, 26.1]);
            expect(
              labels.every(
                (label) =>
                    (label['item_name'] as String).contains('LOT-1') &&
                    !label.containsKey('material_data_matrix'),
              ),
              isTrue,
            );
            final reprint = find.byKey(const ValueKey('paddon-print-unit:$_epc'));
            await tester.ensureVisible(reprint);
            await tester.tap(reprint);
            await tester.pumpAndSettle();
            expect(labels, hasLength(3));
            expect(labels.last, labels.first);
            expect(submits, hasLength(2));
            expect(tester.takeException(), isNull);
          },
          (request) {
            switch (request.url.path) {
              case '/v1/mobile/raw-material-paddons':
                final exactCode = request.url.queryParameters['code'];
                if (exactCode != null) lookedUp.add(exactCode);
                final remaining = submits.length < 2 ? 3 : 1;
                return _json({
                  'has_more': false,
                  'paddons': [
                    {
                      'paddon_id': 'p1',
                      'paddon_code': code,
                      'name': 'Granula zaxirasi',
                      'warehouse': 'Own W',
                      'remaining_kg': '0',
                      'unweighed_count': remaining,
                      'contents': [
                        {
                          'line_no': 1,
                          'item_name': 'Granula',
                          'lot_number': 'LOT-1',
                          'kind': 'bag',
                          'remaining_count': remaining,
                          'unweighed_count': remaining,
                          'remaining_kg': '0',
                        },
                      ],
                    },
                  ],
                });
              case '/v1/mobile/admin/inventory/locations':
                return _json([
                  {'id': 'state-sex', 'name': 'Sex', 'kind': 'state'},
                  {
                    'id': 'warehouse-next',
                    'name': 'Own Next',
                    'kind': 'warehouse',
                    'warehouse_id': 'next',
                  },
                ]);
              case '/v1/mobile/raw-material-paddons/issues':
                final body = jsonDecode(request.body) as Map;
                expect(body['code'], code);
                expect(body['line_no'], 1);
                expect(body['weights'], ['24.6', '26.1']);
                expect(
                  body['destination'],
                  viaScan
                      ? {'kind': 'state', 'id': 'state-sex'}
                      : {'kind': 'warehouse', 'id': 'next'},
                );
                submits.add(body);
                if (submits.length == 1) {
                  return _json({'error': 'No response'}, status: 503);
                }
                return _json({
                  'issue_id': 'issue1',
                  'paddon_code': code,
                  'destination': viaScan ? 'Sex' : 'Own Next',
                  'destination_kind': viaScan ? 'state' : 'warehouse',
                  'label_warehouse': viaScan ? 'Own W' : 'Own Next',
                  'labels': [
                    for (final (barcode, weight) in [
                      (_epc, '24.6'),
                      ('PREP-PADDON-LEGACY', '26.1'),
                    ])
                      {
                        'barcode': barcode,
                        'item_name': 'Granula',
                        'item_code': 'G1',
                        'lot_number': 'LOT-1',
                        'kg': weight,
                      },
                  ],
                });
              default:
                return _route(request);
            }
          },
        );
      },
    );
  }

  testWidgets('notes and audience apply only to the selected rolls', (tester) async {
    const secondEpc = '303132333435363738394143';
    const thirdEpc = '303132333435363738394144';
    const audience = {'mode': 'roles', 'roles': ['homashyo_rezkachi']};
    const note = {
      'text': 'Keyin tekshirilsin', 'revision': 1, 'audience': audience,
    };
    final rolls = [
      _roll(),
      {..._roll(), 'epc': secondEpc, 'receipt_name': 'MAT-TRACE-2'},
      {..._roll(), 'epc': thirdEpc, 'receipt_name': 'MAT-TRACE-3'},
    ];
    var writes = 0;
    final confirmSave = Completer<void>();
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-batch:batch-lg')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-view-rolls')));
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('production-roll:$_epc'));
      final second = find.byKey(const ValueKey('production-roll:$secondEpc'));
      await tester.longPress(first);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslatma qo‘shish'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('production-note-input')),
          note['text']! as String);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('production-note-audience')));
      await tester.pumpAndSettle();
      final audienceChips = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(FilterChip),
      );
      expect(
        tester.widgetList<FilterChip>(audienceChips).map((chip) => chip.key),
        const [
          ValueKey('production-note-audience-rezka_master'),
          ValueKey('production-note-audience-homashyo_rezkachi'),
          ValueKey('production-note-audience-rezka_worker'),
        ],
      );
      final cutter = find.byKey(const ValueKey(
          'production-note-audience-homashyo_rezkachi'));
      await tester.ensureVisible(cutter);
      await tester.tap(cutter);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-note-save')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      final notice = find.widgetWithText(MaterialBanner, 'Eslatma saqlandi');
      expect(notice, findsNothing);
      confirmSave.complete();
      await tester.pumpAndSettle();
      expect(notice, findsOneWidget);
      expect(tester.getTopLeft(notice).dy,
          tester.getBottomLeft(find.byType(AppBar)).dy);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(find.byType(RpsQrReprintSheet), findsOneWidget);
      expect(find.text(note['text']! as String), findsOneWidget);
      expect(find.text('Homashyo rezkachisi'), findsOneWidget);
      Navigator.of(tester.element(find.text(note['text']! as String))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-roll:$thirdEpc')));
      await tester.pumpAndSettle();
      expect(find.byType(RpsQrReprintSheet), findsOneWidget);
      expect(find.text(note['text']! as String), findsNothing);
    }, (request) {
      if (request.url.path.endsWith('/production/rolls')) {
        return _json({'rolls': rolls, 'has_more': false, 'next_offset': null});
      }
      if (request.url.path.endsWith('/production/notes')) {
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body), {
          'scope': 'rolls',
          'rolls': [
            {'receipt_name': 'MAT-TRACE-1', 'expected_revision': 0},
            {'receipt_name': 'MAT-TRACE-2', 'expected_revision': 0},
          ],
          'text': note['text'],
          'audience': audience,
        });
        writes++;
        return confirmSave.future.then((_) {
          rolls[0]['roll_note'] = note;
          rolls[1]['roll_note'] = note;
          return _json({
            'notes': {'MAT-TRACE-1': note, 'MAT-TRACE-2': note}
          });
        });
      }
      return _route(request);
    });
  });

  testWidgets('roll note warning lists replacements and saves only to blank notes',
      (tester) async {
    const secondEpc = '303132333435363738394143';
    const thirdEpc = '303132333435363738394144';
    const text = 'Enini 120 mm qilib kesish';
    const existing = {'text': 'Faqat grenki uchun', 'revision': 1};
    final rows = [
      {..._roll(), 'roll_note': existing},
      {
        ..._roll(),
        'epc': secondEpc,
        'receipt_name': 'MAT-TRACE-2',
        'batch_note': {'text': 'Batch eslatmasi', 'revision': 1},
        'roll_note': {'text': '', 'revision': 2},
      },
      {
        ..._roll(),
        'epc': thirdEpc,
        'receipt_name': 'MAT-TRACE-3',
        'roll_note': {'text': text, 'revision': 1},
      },
    ];
    var writes = 0;
    await _withApp(tester, () async {
      tester.view.physicalSize = const Size(320, 680);
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-view-rolls')));
      await tester.pumpAndSettle();

      final first = find.byKey(const ValueKey('production-roll:$_epc'));
      final second = find.byKey(const ValueKey('production-roll:$secondEpc'));
      final third = find.byKey(const ValueKey('production-roll:$thirdEpc'));
      await tester.longPress(first);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      await tester.ensureVisible(third);
      await tester.tap(third);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eslatma qo‘shish'));
      await tester.pumpAndSettle();

      final warning = find.byKey(const ValueKey('production-note-overwrite-warning'));
      expect(warning, findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('production-note-input')),
        text,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 ta rulondan 1 tasining eslatmasi almashtiriladi.'),
          findsOneWidget);
      await tester.ensureVisible(warning);
      await tester.tap(warning);
      await tester.pumpAndSettle();
      expect(find.descendant(of: warning, matching: find.textContaining(_epc)),
          findsOneWidget);
      expect(find.descendant(of: warning, matching: find.textContaining(secondEpc)),
          findsNothing);
      expect(find.descendant(of: warning, matching: find.textContaining(thirdEpc)),
          findsNothing);
      expect(writes, 0);

      await tester.tap(find.text('Faqat eslatmasi yo‘qlariga yozish'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.widgetWithText(MaterialBanner, 'Eslatma saqlandi'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }, (request) {
      if (request.url.path.endsWith('/production/rolls')) {
        return _json({'rolls': rows, 'has_more': false});
      }
      if (request.url.path.endsWith('/production/notes')) {
        expect(request.method, 'PATCH');
        expect(jsonDecode(request.body), {
          'scope': 'rolls',
          'rolls': [
            {'receipt_name': 'MAT-TRACE-2', 'expected_revision': 2},
          ],
          'text': text,
        });
        writes++;
        final saved = {'text': text, 'revision': 3};
        rows[1]['roll_note'] = saved;
        return _json({'notes': {'MAT-TRACE-2': saved}});
      }
      return _route(request);
    });
  });

  testWidgets('journal FAB attaches selected order rolls and releases their original QR',
      (tester) async {
    const code = 'XP-ABCDEF0123456789';
    const otherEpc = '303132333435363738394143';
    const selected = ['MAT-TRACE-1', 'MAT-TRACE-2'];
    final attachRequests = <Object?>[];
    var packed = false;
    var released = false;
    final paddon = () => {
      'paddon_id': 'p1',
      'paddon_code': code,
      'name': 'PE zaxirasi',
      'warehouse': 'Own W',
      'remaining_kg': !packed ? '0' : released ? '23' : '46',
      'contents': [
        if (packed)
          for (final (line, barcode) in [(1, _epc), (2, otherEpc)])
            if (!released || line != 1)
              {
                'line_no': line,
                'kind': 'roll',
                'item_name': 'PE',
                'remaining_kg': '23',
                'remaining_count': 1,
                'issuable_count': 1,
                'prepared_barcode': barcode,
              },
      ],
    };
    final fab = find.byIcon(Icons.add_rounded);
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await _openOrders(tester);
      await tester.tap(find.byKey(const ValueKey('production-order:zakaz-0317')));
      await tester.pumpAndSettle();
      expect(fab, findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-batch:batch-lg')));
      await tester.pumpAndSettle();
      final fabPosition = tester.getCenter(fab);
      final first = find.byKey(const ValueKey('production-roll:$_epc'));
      await tester.ensureVisible(first);
      await tester.longPress(first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-roll:$otherEpc')));
      await tester.pumpAndSettle();
      expect(tester.getCenter(fab), fabPosition);
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));

      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.text('Eslatma qo‘shish'), findsOneWidget);
      expect(find.text('Tanlovni bekor qilish'), findsOneWidget);
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();
      expect(find.text('2 ta tanlangan rulon'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-$code')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const ValueKey('production-attach-paddon-save'));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Natijani tekshirish'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('2 ta rulon $code paddoniga biriktirildi'), findsOneWidget);
      expect(attachRequests, hasLength(2));
      expect(attachRequests[0], attachRequests[1]);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      Navigator.of(tester.element(first)).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(PreparationProductionOrderScreen))).pop();
      await tester.pumpAndSettle();
      final paddons = find.byKey(const ValueKey('production-view-paddons'));
      await tester.ensureVisible(paddons);
      await tester.tap(paddons);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preparation-paddon:p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('paddon-open-issue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paddon-issue-weight-1-0')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('paddon-issue-save')));
      await tester.pumpAndSettle();
      expect(released, isTrue);
      expect(find.text('Chiqim yorliqlari'), findsNothing);
      expect(find.text(otherEpc), findsOneWidget);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'batch':
          return _json({
            'batch': _batch(recipe: null),
            'rolls': [
              _roll(recipe: null),
              {..._roll(recipe: null), 'epc': otherEpc, 'receipt_name': selected.last},
            ],
            'has_more': false,
          });
        case 'paddon-options':
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'receipt_names': selected, 'offset': 0});
          return _json({'paddons': [paddon()], 'has_more': false});
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map;
          expect(body['code'], code);
          expect(body['receipt_names'], selected);
          expect(body['request_id'], isNotEmpty);
          attachRequests.add(body);
          if (attachRequests.length == 1) {
            return _json({'error': 'Javob olinmadi'}, status: 503);
          }
          packed = true;
          return _json({'paddon_code': code, 'receipt_names': selected});
        case 'raw-material-paddons':
          return _json({'paddons': [paddon()], 'has_more': false});
        case 'issues':
          final body = jsonDecode(request.body) as Map;
          expect(body['code'], code);
          expect(body['line_no'], 1);
          expect(body['weights'], ['23']);
          expect(body, isNot(contains('destination')));
          released = true;
          return _json({
            'issue_id': 'release-1',
            'paddon_code': code,
            'destination': 'Own W',
            'label_warehouse': 'Own W',
            'existing_qr': true,
            'labels': [{'barcode': _epc, 'item_code': 'PE', 'item_name': 'PE', 'kg': '23'}],
          });
        default:
          return _route(request);
      }
    });
  });

  testWidgets('manual packing displays the current paddon and attaches eligible rolls',
      (tester) async {
    const packedCode = 'XP-ABCDEF0123456789';
    const targetCode = 'XP-ABCDEF012345678A';
    const freeEpc = '303132333435363738394143';
    const packedReceipt = 'MAT-TRACE-1';
    const freeReceipt = 'MAT-TRACE-2';
    var reads = 0;
    var writes = 0;
    final action = find.text('Paddonga biriktirish');
    final confirm = find.byKey(const ValueKey('production-attach-paddon-save'));

    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-view-rolls')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('production-roll:$_epc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-roll:$freeEpc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.text('2 ta rulondan 1 tasi biriktirishga yaroqli'), findsOneWidget);
      final packed = find.byKey(const ValueKey('production-attach-packed-rolls'));
      await tester.tap(packed);
      await tester.pumpAndSettle();
      expect(find.descendant(of: packed, matching: find.text(_epc)), findsOneWidget);
      expect(find.text('Oq zaxira • $packedCode'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-$targetCode')));
      await tester.pumpAndSettle();
      expect(find.text('2 ta rulondan 1 tasi biriktiriladi'), findsOneWidget);
      expect(writes, 0);
      await tester.tap(find.text('Yaroqli rulonlarni biriktirish'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('1 ta rulon $targetCode paddoniga biriktirildi'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('1 ta rulondan 0 tasi biriktirishga yaroqli'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      expect(writes, 1);
      expect(reads, 2);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'rolls':
          return _json({
            'rolls': [
              _roll(),
              {..._roll(), 'epc': freeEpc, 'receipt_name': freeReceipt},
            ],
            'has_more': false,
          });
        case 'paddon-options':
          reads++;
          expect(request.method, 'POST');
          expect(request.url.queryParameters['preview_partial'], 'true');
          expect(jsonDecode(request.body), {
            'receipt_names': [packedReceipt, if (writes == 0) freeReceipt],
            'offset': 0,
          });
          return _json({
            'paddons': [
              if (writes == 0)
                {
                  'paddon_id': 'target',
                  'paddon_code': targetCode,
                  'warehouse': 'Own W',
                  'remaining_kg': '0',
                  'contents': [],
                },
            ],
            'has_more': false,
            'roll_selection': {
              'batch_ids': [],
              'total_rolls': writes == 0 ? 2 : 1,
              'receipt_names_by_warehouse': {
                if (writes == 0) 'Own W': [freeReceipt],
              },
              'skipped': {'packed': 1},
              'packed_rolls': [
                {
                  'barcode': _epc,
                  'paddon_name': 'Oq zaxira',
                  'paddon_code': packedCode,
                },
              ],
            },
          });
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], targetCode);
          expect(body['receipt_names'], [freeReceipt]);
          expect(body['request_id'], isNotEmpty);
          writes++;
          return _json({'paddon_code': targetCode, 'receipt_names': [freeReceipt]});
        default:
          return _route(request);
      }
    });
  });

  testWidgets('existing paddon search can select a destination for a roll transfer',
      (tester) async {
    const code = 'XP-ABCDEF0123456789';
    const otherCode = 'XP-ABCDEF012345678A';
    const warehouse = 'Ibrohim W';
    const destination = 'Qadoqlash W';
    const receipt = 'MAT-TRACE-1';
    const target = {
      'paddon_id': 'p-existing',
      'paddon_code': code,
      'name': 'PE zaxirasi',
      'warehouse': destination,
      'remaining_kg': '0',
      'contents': [],
    };
    const elsewhere = {
      'paddon_id': 'p-other',
      'paddon_code': otherCode,
      'name': 'Seryo zaxirasi',
      'warehouse': 'Seryo W',
      'remaining_kg': '0',
      'contents': [],
    };
    final queries = <String>[];
    var writes = 0;
    await _withApp(tester, () async {
      tester.view.physicalSize = const Size(390, 780);
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-view-rolls')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('production-roll:$_epc')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();

      final title = find.text('Paddonga biriktirish');
      final surface = find.ancestor(
        of: title,
        matching: find.byWidgetPredicate(
          (widget) => widget is Material && widget.type == MaterialType.card,
        ),
      ).first;
      expect(tester.getSize(surface).width, 390 - m3DialogInsetPadding.horizontal);
      await tester.tap(find.byKey(const ValueKey('production-find-existing-paddon')));
      await tester.pumpAndSettle();

      final search = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'Seryo zaxirasi');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final incompatible = find.byKey(const ValueKey('production-existing-paddon-$otherCode'));
      expect(tester.widget<AdminCatalogListRow>(incompatible).onTap, isNull);
      expect(find.textContaining('Bu omborda yaroqli rulon yo‘q'), findsOneWidget);

      await tester.enterText(search, code);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-existing-paddon-$code')));
      await tester.pumpAndSettle();
      final chosen = find.byKey(const ValueKey('production-attach-paddon-$code'));
      expect(tester.widget<ListTile>(chosen).selected, isTrue);
      expect(find.text('$warehouse → $destination • 1 ta rulon ko‘chiriladi'),
          findsOneWidget);
      expect(find.text('Ko‘chirish va biriktirish'), findsOneWidget);
      expect(writes, 0);
      await tester.tap(find.byKey(const ValueKey('production-attach-paddon-save')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(queries, containsAllInOrder(['Seryo zaxirasi', code]));
      expect(find.text('1 ta rulon $code paddoniga biriktirildi'), findsOneWidget);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'rolls':
          return _json({'rolls': [_roll()], 'has_more': false});
        case 'paddon-options':
          expect(request.url.queryParameters['transfer_between_warehouses'], 'true');
          return _json({
            'paddons': [{
              ...target,
              'paddon_id': 'p-first-page',
              'paddon_code': 'XP-ABCDEF012345678B',
              'warehouse': warehouse,
            }],
            'has_more': true,
            'next_offset': 50,
            'roll_selection': {
              'batch_ids': [],
              'total_rolls': 1,
              'receipt_names_by_warehouse': {warehouse: [receipt]},
              'transfer_warehouses': [destination],
              'skipped': {},
              'packed_rolls': [],
            },
          });
        case 'raw-material-paddons':
          expect(request.method, 'GET');
          final query = request.url.queryParameters['q']!;
          queries.add(query);
          return _json({
            'paddons': [if (query == code) target else elsewhere],
            'has_more': false,
          });
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['code'], code);
          expect(body['receipt_names'], [receipt]);
          expect(body['transfer_between_warehouses'], isTrue);
          writes++;
          return _json({'paddon_code': code, 'receipt_names': [receipt]});
        default:
          return _route(request);
      }
    });
  });

  testWidgets('batch list applies one note to the selected batches in place',
      (tester) async {
    const batchId = 'batch:lg';
    const otherId = 'batch:other';
    const batchCode = 'B-0317';
    const audience = {'mode': 'roles', 'roles': ['rezka_master']};
    final notes = <String, Map<String, dynamic>>{
      batchId: {
        'text': 'Oldingi eslatma',
        'revision': 1,
        'audience': audience,
      },
    };
    final batchRow = find.byKey(const ValueKey('production-batch:$batchId'));
    final otherRow = find.byKey(const ValueKey('production-batch:$otherId'));
    final fab = find.byIcon(Icons.add_rounded);
    final input = find.byKey(const ValueKey('production-note-input'));

    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      final fabPosition = tester.getCenter(fab);

      await tester.longPress(otherRow);
      await tester.pumpAndSettle();
      await tester.tap(batchRow);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      await tester.tap(otherRow);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: batchRow,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
      await tester.longPress(otherRow);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
      expect(tester.getCenter(fab), fabPosition);
      expect(find.byType(PreparationProductionBatchScreen), findsNothing);

      await tester.tap(fab);
      await tester.pumpAndSettle();
      expect(find.text('Paddonga biriktirish'), findsOneWidget);
      await tester.tap(find.text('2 ta batchga eslatma'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(find.text('Turli rollar tanlangan'), findsOneWidget);
      await tester.enterText(input, 'Enini 120 mm qilib kesish');
      await tester.pumpAndSettle();
      final warning = find.byKey(const ValueKey('production-note-overwrite-warning'));
      expect(find.text('2 ta batchdan 1 tasining eslatmasi almashtiriladi.'),
          findsOneWidget);
      expect(find.text('Faqat eslatmasi yo‘qlariga yozish'), findsOneWidget);
      expect(notes[batchId]!['revision'], 1);
      expect(notes.containsKey(otherId), isFalse);
      await tester.tap(warning);
      await tester.pumpAndSettle();
      expect(find.textContaining(batchCode), findsOneWidget);
      expect(find.textContaining(otherId), findsNothing);
      await tester.tap(find.text('Hammasiga yozish'));
      await tester.pumpAndSettle();
      expect(notes[batchId]!['revision'], 2);
      expect(notes[otherId]!['revision'], 1);
      expect(find.widgetWithText(MaterialBanner, 'Eslatma saqlandi'),
          findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

      await tester.tap(batchRow);
      await tester.pumpAndSettle();
      expect(find.byType(PreparationProductionBatchScreen), findsOneWidget);
      expect(find.textContaining('Enini 120 mm qilib kesish'), findsOneWidget);
    }, (request) {
      final batch = {
        ..._batch(recipe: null),
        'batch_id': batchId,
        'batch_code': batchCode,
        'batch_note': notes[batchId],
      };
      switch (request.url.path.split('/').last) {
        case 'batches':
          return _json({
            'batches': [
              batch,
              {..._batch(), 'batch_id': otherId, 'batch_note': notes[otherId]},
            ],
            'has_more': false,
          });
        case 'batch':
          expect(request.url.queryParameters['batch_id'], batchId);
          expect(notes[batchId]!['revision'], 2,
              reason: 'The note is edited in the list');
          return _json({'batch': batch, 'rolls': [], 'has_more': false});
        case 'notes':
          expect(request.method, 'PATCH');
          expect(jsonDecode(request.body), {
            'scope': 'batches',
            'batches': [
              {'batch_id': batchId, 'expected_revision': 1},
              {'batch_id': otherId, 'expected_revision': 0},
            ],
            'text': 'Enini 120 mm qilib kesish',
          });
          notes[batchId] = {
            'text': 'Enini 120 mm qilib kesish',
            'revision': 2,
            'audience': audience,
          };
          notes[otherId] = {
            'text': 'Enini 120 mm qilib kesish',
            'revision': 1,
            'audience': {'mode': 'all'},
          };
          return _json({'notes': notes});
        default:
          return _route(request);
      }
    });
  });

  testWidgets('packing selected batches previews their rolls and retries the same selection',
      (tester) async {
    const batchId = 'batch:lg';
    const otherId = 'batch:other';
    const batchIds = [batchId, otherId];
    const code = 'XP-ABCDEF0123456789';
    const packedCode = 'XP-ABCDEF012345678A';
    final writes = <Map<String, dynamic>>[];
    var previewReads = 0;
    final row = find.byKey(const ValueKey('production-batch:$batchId'));
    final otherRow = find.byKey(const ValueKey('production-batch:$otherId'));
    final target = find.byKey(const ValueKey('production-attach-paddon-$code'));
    final confirm = find.byKey(const ValueKey('production-attach-paddon-save'));

    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.longPress(row);
      await tester.pumpAndSettle();
      await tester.tap(otherRow);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();

      expect(find.text('2 ta batch tanlandi'), findsOneWidget);
      expect(find.text('5 ta rulondan 3 tasi biriktirishga yaroqli'),
          findsOneWidget);
      await tester.tap(find.text('1 ta rulon allaqachon paddonda'));
      await tester.pumpAndSettle();
      expect(find.text(_epc), findsOneWidget);
      expect(find.text('Oq zaxira • $packedCode'), findsOneWidget);
      expect(find.text('1 ta rulon kesilgan yoki sarflangan'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('5 ta rulondan 2 tasi biriktiriladi'), findsOneWidget);
      expect(find.text('1 ta rulon boshqa omborda qoladi'), findsOneWidget);
      expect(writes, isEmpty);

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Batchdagi rulonlar holati o‘zgargan'), findsOneWidget);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('5 ta rulondan 1 tasi biriktiriladi'), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Natijani tekshirish'), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(find.text('1 ta rulon $code paddoniga biriktirildi'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(writes, hasLength(3));
      expect(writes[0]['receipt_names'], ['MAT-A', 'MAT-B']);
      expect(writes[1]['receipt_names'], ['MAT-A']);
      expect(writes[1], writes[2]);
      expect(previewReads, 2);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'batches':
          return _json({
            'batches': [
              {..._batch(), 'batch_id': batchId, 'roll_count': 3},
              {..._batch(), 'batch_id': otherId, 'roll_count': 2},
            ],
            'has_more': false,
          });
        case 'batch':
          fail('Batch rolls are resolved on the server without opening details');
        case 'paddon-options':
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'batch_ids': batchIds, 'offset': 0});
          previewReads++;
          return _json({
            'paddons': [
              {
                'paddon_id': 'p1',
                'paddon_code': code,
                'warehouse': 'Own W',
                'remaining_kg': '0',
                'contents': [],
              },
            ],
            'has_more': false,
            'batch_selection': {
              'batch_ids': batchIds,
              'total_rolls': 5,
              'receipt_names_by_warehouse': {
                'Own W': ['MAT-A', if (previewReads == 1) 'MAT-B'],
                'Other W': ['MAT-C'],
              },
              'skipped': {
                'packed': 1,
                'consumed': 1,
                if (previewReads > 1) 'unavailable': 1,
              },
              'packed_rolls': [
                {
                  'barcode': _epc,
                  'paddon_name': 'Oq zaxira',
                  'paddon_code': packedCode,
                },
              ],
            },
          });
        case 'paddon-attach':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['batch_ids'], batchIds);
          expect(body['code'], code);
          expect(body['request_id'], isNotEmpty);
          writes.add(body);
          if (writes.length == 1) {
            return _json({
              'code': 'preparation_conflict',
              'error': 'Batchdagi rulonlar holati o‘zgargan',
            }, status: 409);
          }
          if (writes.length == 2) {
            return _json({'error': 'Javob olinmadi'}, status: 503);
          }
          return _json({'paddon_code': code, 'receipt_names': ['MAT-A']});
        default:
          return _route(request);
      }
    });
  });

  testWidgets('an unassigned batch note keeps its text when audience changes', (tester) async {
    const batchId = 'batch:lg';
    const noteText = 'Ushbu batch tekshirilsin';
    final batch = {
      ..._batch(recipe: null),
      'batch_id': batchId,
      'order_id': ''
    };
    var writes = 0;
    const initialAudience = {'mode': 'roles', 'roles': ['rezka_master', 'rezka_worker']};
    const updatedAudience = {'mode': 'roles', 'roles': ['rezka_worker']};
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-batch:$batchId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-batch-note')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('production-note-input')), noteText);
      await tester.pump();
      final audience = find.byKey(const ValueKey('production-note-audience'));
      final rezkaMaster = find.byKey(const ValueKey('production-note-audience-rezka_master'));
      final rezkaWorker = find.byKey(const ValueKey('production-note-audience-rezka_worker'));
      await tester.tap(audience);
      await tester.pumpAndSettle();
      await tester.ensureVisible(rezkaMaster);
      await tester.tap(rezkaMaster);
      await tester.pumpAndSettle();
      await tester.ensureVisible(rezkaWorker);
      await tester.tap(rezkaWorker);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-note-save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-note-input')), findsNothing);
      expect(find.widgetWithText(MaterialBanner, 'Eslatma saqlandi'),
          findsOneWidget);
      expect(find.textContaining(noteText), findsOneWidget);
      expect(find.textContaining('Rezka master, Ishchi rezka'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('production-batch-note')));
      await tester.pumpAndSettle();
      await tester.tap(audience);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(rezkaMaster).selected, isTrue);
      expect(tester.widget<FilterChip>(rezkaWorker).selected, isTrue);
      await tester.ensureVisible(rezkaMaster);
      await tester.tap(rezkaMaster);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-note-save')));
      await tester.pumpAndSettle();
      expect(writes, 2);
      await tester.tap(find.byKey(const ValueKey('production-roll:$_epc')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(RpsQrReprintSheet),
          matching: find.text(noteText),
        ),
        findsOneWidget,
      );
      expect(find.descendant(
        of: find.byType(RpsQrReprintSheet),
        matching: find.text('Ishchi rezka'),
      ), findsOneWidget);
    }, (request) {
      switch (request.url.path.split('/').last) {
        case 'batches':
          return _json({
            'batches': [batch],
            'has_more': false
          });
        case 'batch':
          expect(request.url.queryParameters['batch_id'], batchId);
          return _json({
            'batch': batch,
            'rolls': [_roll(recipe: null)],
            'has_more': false
          });
        case 'notes':
          expect(request.method, 'PATCH');
          final audience = writes == 0 ? initialAudience : updatedAudience;
          expect(jsonDecode(request.body), {
            'scope': 'batch',
            'batch_id': batchId,
            'expected_revision': writes,
            if (writes == 0) 'text': noteText,
            'audience': audience,
          });
          writes++;
          final note = {'text': noteText, 'revision': writes, 'audience': audience};
          batch['batch_note'] = note;
          return _json({
            'notes': {batchId: note}
          });
        default:
          return _route(request);
      }
    });
  });

  testWidgets('order opens material, frozen recipe and produced roll QR',
      (tester) async {
    final paths = <String>[];
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await _openOrders(tester);
      await tester
          .tap(find.byKey(const ValueKey('production-order:zakaz-0317')));
      await tester.pumpAndSettle();
      expect(find.byType(PreparationProductionOrderScreen), findsOneWidget);
      expect(find.textContaining('PE PR'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('production-batch:batch-lg')));
      await tester.pumpAndSettle();
      expect(find.byType(PreparationProductionBatchScreen), findsOneWidget);
      expect(find.textContaining('LG'), findsWidgets);
      expect(find.textContaining('Seriya ORIGINAL'), findsWidgets);
      final roll = find.byKey(const ValueKey('production-roll:$_epc'));
      await tester.ensureVisible(roll);
      await tester.tap(roll);
      await tester.pumpAndSettle();
      expect(find.textContaining(_epc), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(paths.any((path) => path.contains('/formulas')), isFalse);
    }, (request) {
      paths.add(request.url.path);
      return _route(request);
    });
  });

  testWidgets('order and batch lists use the shared admin row style',
      (tester) async {
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await _openOrders(tester);

      AdminCatalogListRow row(String key) => tester.widget<AdminCatalogListRow>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(AdminCatalogListRow),
            ),
          );
      AdminSummaryCard card(String key) => tester.widget<AdminSummaryCard>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(AdminSummaryCard),
            ),
          );

      const firstOrder = 'production-order:zakaz-0317';
      const secondOrder = 'production-order:zakaz-0318';
      expect(row(firstOrder).slot, M3SegmentVerticalSlot.top);
      expect(row(secondOrder).slot, M3SegmentVerticalSlot.bottom);
      expect(row(firstOrder).title, '0317 • Silver choy 0317');
      expect(row(firstOrder).subtitle, contains('Silver choy'));
      expect(row(firstOrder).subtitle, contains('1 ta ishlab chiqarish'));
      expect(row(firstOrder).subtitle, contains('1 ta rulon • 23 kg • 125 m'));
      expect(card(firstOrder).showChevron, isFalse);
      expect(row(firstOrder).onTap, isNotNull);
      await tester.tap(find.byKey(const ValueKey(firstOrder)));
      await tester.pumpAndSettle();

      const summary = 'production-order-summary';
      const firstBatch = 'production-batch:batch-lg';
      const secondBatch = 'production-batch:batch-2';
      final scheme = Theme.of(
        tester.element(find.byKey(const ValueKey(summary))),
      ).colorScheme;
      expect(
        card(summary).backgroundColor,
        Color.alphaBlend(
          scheme.primaryContainer.withValues(alpha: 0.6),
          scheme.surfaceContainerLowest,
        ),
      );
      expect(card(firstBatch).backgroundColor, scheme.surfaceContainerLowest);
      expect(row(summary).slot, M3SegmentVerticalSlot.top);
      expect(row(summary).subtitle, contains('1 ta rulon • 23 kg • 125 m'));
      expect(row(firstBatch).slot, M3SegmentVerticalSlot.middle);
      expect(row(secondBatch).slot, M3SegmentVerticalSlot.bottom);
      expect(row(firstBatch).title, 'PE PR');
      expect(row(firstBatch).subtitle, contains('LG'));
      expect(row(firstBatch).subtitle, contains('Davom etmoqda • Own W'));
      expect(row(firstBatch).subtitle, contains('1 ta rulon • 23 kg • 125 m'));
      expect(card(firstBatch).showChevron, isFalse);
      expect(row(firstBatch).onTap, isNotNull);
      expect(tester.takeException(), isNull);
    }, (request) {
      if (request.url.path.endsWith('/production/orders')) {
        return _json({
          'orders': [
            _order(),
            _order(id: 'zakaz-0318', code: '0318'),
          ],
          'has_more': false,
          'next_offset': null,
        });
      }
      if (request.url.path.endsWith('/production/order')) {
        return _json({
          'order': _order(),
          'batches': [
            _batch(),
            {..._batch(), 'batch_id': 'batch-2', 'item_name': 'PE oq'},
          ],
          'has_more': false,
          'next_offset': null,
        });
      }
      return _route(request);
    });
  });

  testWidgets('legacy output has an explicit unknown formula', (tester) async {
    await _withApp(tester, () async {
      await tester.pumpWidget(
          _app(const PreparationProductionBatchScreen(batchId: 'batch-lg')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Formula qayd etilmagan'), findsWidgets);
      expect(find.textContaining('Seriya ORIGINAL'), findsNothing);
      expect(
          find.byKey(const ValueKey('production-roll:$_epc')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, (request) => _route(request, recipe: null));
  });

  testWidgets('batch details use shared list rows for status, recipe and rolls',
      (tester) async {
    const secondEpc = '303132333435363738394143';
    await _withApp(tester, () async {
      tester.view.physicalSize = const Size(320, 1100);
      await tester.pumpWidget(
          _app(const PreparationProductionBatchScreen(batchId: 'batch-lg')));
      await tester.pumpAndSettle();

      AdminCatalogListRow row(String key) => tester.widget<AdminCatalogListRow>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(AdminCatalogListRow),
            ),
          );
      const summary = 'production-batch-summary';
      const recipe = 'production-batch-recipe';
      const firstRoll = 'production-roll:$_epc';
      const secondRoll = 'production-roll:$secondEpc';
      final scheme = Theme.of(
        tester.element(find.byKey(const ValueKey(summary))),
      ).colorScheme;
      final headerColor = Color.alphaBlend(
        scheme.primaryContainer.withValues(alpha: 0.6),
        scheme.surfaceContainerLowest,
      );
      expect(row(summary).backgroundColor, headerColor);
      expect(row(recipe).backgroundColor, headerColor);
      expect(row(summary).slot, M3SegmentVerticalSlot.top);
      expect(row(summary).title, 'Davom etmoqda');
      expect(row(summary).subtitle, contains('Own W'));
      expect(row(summary).subtitle, contains('1 ta rulon • 23 kg • 125 m'));
      expect(row(recipe).slot, M3SegmentVerticalSlot.middle);
      expect(row(recipe).title, 'Formula qayd etilmagan');
      expect(row(firstRoll).slot, M3SegmentVerticalSlot.middle);
      expect(row(secondRoll).slot, M3SegmentVerticalSlot.bottom);
      expect(row(firstRoll).title, _epc);
      expect(
          row(firstRoll).subtitle, contains('23 kg • 125 m • 495 mm • 50 mkm'));
      expect(row(firstRoll).onTap, isNotNull);
      final card = tester.widget<AdminSummaryCard>(find.descendant(
        of: find.byKey(const ValueKey(firstRoll)),
        matching: find.byType(AdminSummaryCard),
      ));
      expect(card.backgroundColor, scheme.surfaceContainerLowest);
      expect(card.showChevron, isFalse);
      expect(card.titleMaxLines, 2);
      expect(
          tester
              .renderObject<RenderParagraph>(find.text(_epc))
              .didExceedMaxLines,
          isFalse);
      await tester.tap(find.byKey(const ValueKey(firstRoll)));
      await tester.pumpAndSettle();
      expect(find.textContaining(_epc), findsWidgets);
      expect(tester.takeException(), isNull);
    },
        (request) => _json({
              'batch': _batch(recipe: null),
              'rolls': [
                _roll(recipe: null),
                {
                  ..._roll(recipe: null),
                  'epc': secondEpc,
                  'receipt_name': 'MAT-TRACE-2'
                },
              ],
              'has_more': false,
              'next_offset': null,
            }));
  });

  testWidgets('saved recipe keeps its complete content in the segmented list',
      (tester) async {
    await _withApp(tester, () async {
      await tester.pumpWidget(
          _app(const PreparationProductionBatchScreen(batchId: 'batch-lg')));
      await tester.pumpAndSettle();
      final recipe = find.byKey(const ValueKey('production-batch-recipe'));
      final surface = tester.widget<M3SegmentFilledSurface>(find.descendant(
        of: recipe,
        matching: find.byType(M3SegmentFilledSurface),
      ));
      expect(surface.slot, M3SegmentVerticalSlot.middle);
      final scheme = Theme.of(tester.element(recipe)).colorScheme;
      expect(
        surface.backgroundColor,
        Color.alphaBlend(
          scheme.primaryContainer.withValues(alpha: 0.6),
          scheme.surfaceContainerLowest,
        ),
      );
      expect(find.text('Shnek formulasi: LG'), findsOneWidget);
      expect(find.text('Shnek A • 30%'), findsOneWidget);
      expect(find.text('Shnek B • 70%'), findsOneWidget);
      expect(find.text('Seriya ORIGINAL — 88%'), findsOneWidget);
      expect(find.text('Seriya 2 — 12%'), findsOneWidget);
      expect(find.text('Seriya 2 — 100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, (request) => _route(request));
  });

  testWidgets('a batch roll sheet can be pulled down while scrolled',
      (tester) async {
    await _withApp(tester, () async {
      tester.view.physicalSize = const Size(390, 640);
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-batch:batch-lg')));
      await tester.pumpAndSettle();
      final roll = find.byKey(const ValueKey('production-roll:$_epc'));
      await tester.ensureVisible(roll);
      await tester.tap(roll);
      await tester.pumpAndSettle();

      final sheet = find.byType(RpsQrReprintSheet);
      final bottomSheet =
          find.ancestor(of: sheet, matching: find.byType(BottomSheet));
      final reprint =
          find.byKey(const ValueKey('production-roll-reprint-$_epc'));
      expect(find.descendant(of: sheet, matching: find.byTooltip('Yopish')),
          findsNothing);
      await tester.ensureVisible(reprint);
      await tester.pumpAndSettle();
      expect(Scrollable.of(tester.element(reprint)).position.pixels,
          greaterThan(0));

      final top = tester.getRect(bottomSheet).topCenter;
      final drag = await tester.startGesture(
          top + const Offset(0, kMinInteractiveDimension / 2));
      await drag.moveBy(const Offset(0, 30));
      await drag.moveBy(const Offset(0, 100));
      await tester.pump();
      expect(tester.getRect(bottomSheet).top, greaterThan(top.dy));
      await drag.moveBy(const Offset(0, 320));
      await drag.up();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.byType(PreparationProductionBatchScreen), findsOneWidget);
    }, _route);
  });

  for (final printFails in [false, true]) {
    testWidgets(
        'production roll QR reprints the existing label (failure: $printFails)',
        (tester) async {
      SessionBluetoothPrinter.remember(const BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: 'preparation-printer',
      ));
      const channel = MethodChannel('accord/bluetooth_printer');
      final printCalls = <MethodCall>[];
      var confirmed = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
          (call) async {
        printCalls.add(call);
        if (printFails) {
          throw PlatformException(
              code: 'printer_error', message: 'Printer ulanmagan');
        }
        return {'ok': true};
      });
      addTearDown(() {
        SessionBluetoothPrinter.forget();
        tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await _withApp(tester, () async {
        await tester.pumpWidget(
            _app(const PreparationProductionBatchScreen(batchId: 'batch-lg')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('production-roll:$_epc')));
        await tester.pumpAndSettle();
        expect(find.byType(RpsQrReprintSheet), findsOneWidget);
        final reprint =
            find.byKey(const ValueKey('production-roll-reprint-$_epc'));
        await tester.ensureVisible(reprint);
        await tester.tap(reprint);
        await tester.pumpAndSettle();
        expect(printCalls, hasLength(1));
        expect(printCalls.single.method, 'printLabel');
        expect((printCalls.single.arguments as Map)['epc'], _epc);
        expect(confirmed, !printFails);
        if (printFails) expect(find.text('Printer ulanmagan'), findsOneWidget);
      }, (request) {
        if (request.url.path.endsWith('/reprint/prepare')) {
          expect(jsonDecode(request.body),
              {'barcode': _epc, 'order_id': 'zakaz-0317'});
          return _json({
            'reprint_id': 'raw_label_test',
            'stock': {
              'barcode': _epc,
              'item_code': 'PE PR',
              'qty': 23,
              'source_receipt_id': 'MAT-TRACE-1'
            },
            'print': {
              'epc': _epc,
              'item_code': 'PE PR',
              'item_name': 'PE PR',
              'gross_qty': 23,
              'label_kind': 'material_product',
              'printer': 'godex'
            },
          });
        }
        if (request.url.path.endsWith('/reprint/confirm')) {
          expect(jsonDecode(request.body),
              {'barcode': _epc, 'reprint_id': 'raw_label_test'});
          confirmed = true;
          return _json({'ok': true});
        }
        return _route(request);
      });
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('paging appends orders and searching starts a fresh result',
      (tester) async {
    final queries = <Map<String, String>>[];
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await _openOrders(tester);
      final search = find.byType(AdminCatalogSearchField);
      expect(search, findsOneWidget);
      expect(find.ancestor(of: search, matching: find.byType(AppBar)),
          findsOneWidget);
      expect(find.byType(AdminExpandableFilterChip<String>), findsOneWidget);
      expect(
          find.byKey(const ValueKey('production-status-active')), findsNothing);
      final more = find.byKey(const ValueKey('production-load-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-order:zakaz-0318')),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-order:zakaz-0318')),
          findsOneWidget,
          reason: 'live refresh must retain loaded history pages');
      await tester.enterText(
          find.byKey(const ValueKey('production-search')), '0317');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-order:zakaz-0318')),
          findsNothing);
      expect(queries.any((query) => query['offset'] == '1'), isTrue);
      expect(queries.last['q'], '0317');
      expect(queries.last['offset'], '0');
      await tester.tap(find.byKey(const ValueKey('production-status-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-status-active')));
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'active');
      expect(queries.last['offset'], '0');
      expect(queries.last['q'], '0317');
      expect(
          find.byKey(const ValueKey('production-status-active')), findsNothing);
      expect(find.text('Holat: Davom etmoqda'), findsOneWidget);
      tester.widget<AdminCatalogSearchField>(search).focusNode.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: search, matching: find.byIcon(Icons.close_rounded)));
      await tester.pumpAndSettle();
      expect(queries.last['q'], isEmpty);
      expect(queries.last['status'], 'active');
      expect(tester.widget<AdminCatalogSearchField>(search).controller.text,
          isEmpty);
      expect(tester.takeException(), isNull);
    }, (request) {
      expect(request.method, 'GET');
      if (request.url.path.endsWith('/production/batches')) {
        return _route(request);
      }
      final query = request.url.queryParameters;
      queries.add(query);
      final second = query['offset'] == '1';
      return _json({
        'orders': [second ? _order(id: 'zakaz-0318', code: '0318') : _order()],
        'has_more': !second && (query['q'] ?? '').isEmpty,
        'next_offset': !second && (query['q'] ?? '').isEmpty ? 1 : null
      });
    });
  });

  testWidgets('swiping between tabs keeps their pages and applies journal deltas',
      (tester) async {
    var orderReads = 0;
    var batchReads = 0;
    var extended = false;
    var changePending = false;
    var deliveredUpdate = false;
    final first = _order();
    final second = _order(id: 'zakaz-0318', code: '0318');
    final watchVersions = <String>[];
    final pages = find.byKey(const ValueKey('production-view-pages'));
    final batchRow = find.byKey(const ValueKey('production-batch:batch-lg'));
    final firstRow = find.byKey(const ValueKey('production-order:zakaz-0317'));
    final secondRow = find.byKey(const ValueKey('production-order:zakaz-0318'));

    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await _openOrders(tester);
      final more = find.byKey(const ValueKey('production-load-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(extended, isTrue);
      expect(secondRow, findsOneWidget);

      await tester.timedDrag(
        pages, const Offset(-300, 0), const Duration(milliseconds: 350),
      );
      await tester.pumpAndSettle();
      expect(batchRow, findsOneWidget);
      expect(batchReads, 1);
      await tester.timedDrag(
        pages, const Offset(300, 0), const Duration(milliseconds: 350),
      );
      await tester.pumpAndSettle();
      expect(firstRow, findsOneWidget);
      expect(secondRow, findsOneWidget);
      expect(orderReads, 1);

      changePending = true;
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(deliveredUpdate, isTrue);
      expect(firstRow, findsNothing);
      expect(secondRow, findsOneWidget);
      expect(find.textContaining('4 ta rulon'), findsOneWidget);
      expect(watchVersions, contains('loaded'));
      expect(orderReads, 1);
      expect(tester.takeException(), isNull);
    }, (request) {
      if (request.url.path.endsWith('/production/batches')) {
        batchReads++;
        return _route(request);
      }
      if (request.url.path.endsWith('/production/orders')) {
        orderReads++;
        expect(request.url.queryParameters['offset'], '0');
        return _json({
          'orders': [first],
          'has_more': true,
          'next_offset': 1,
          'journal_sync': {'version': 'first', 'hashes': ['first-row']},
        });
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/v1/mobile/preparation/production/sync');
      final query = jsonDecode(request.body) as Map<String, dynamic>;
      expect(query['view'], 'orders');
      final version = (query['baseline'] as Map)['version'] as String;
      if (query['watch'] == true) watchVersions.add(version);
      if (query['length'] == 100 && version == 'first') {
        expect(query['watch'], isFalse);
        extended = true;
        return _json({
          'type': 'delta',
          'base_version': 'first',
          'has_more': false,
          'next_offset': null,
          'journal_sync': {
            'version': 'loaded',
            'hashes': ['first-row', 'second-row'],
          },
          'upserts': {'second-row': second},
        });
      }
      if (changePending && version == 'loaded') {
        expect(query['length'], 100);
        expect((query['baseline'] as Map)['hashes'], ['first-row', 'second-row']);
        deliveredUpdate = true;
        return _json({
          'type': 'delta',
          'base_version': 'loaded',
          'has_more': false,
          'next_offset': null,
          'journal_sync': {'version': 'changed', 'hashes': ['updated-row']},
          'upserts': {'updated-row': {...second, 'roll_count': 4}},
        });
      }
      return _json({'type': 'unchanged', 'version': version});
    });
  });

  testWidgets('a failed read can be retried without creating production',
      (tester) async {
    var attempts = 0;
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-batch:batch-lg')),
          findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    }, (request) {
      expect(request.method, 'GET');
      return ++attempts == 1
          ? _json({'code': 'preparation_store', 'error': 'Unavailable'},
              status: 503)
          : _route(request);
    });
  });

  testWidgets('late old-account results are discarded', (tester) async {
    final pending = Completer<http.Response>();
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pump();
      AppSession.instance.profile = _profile(ref: 'prep-2');
      AppSession.instance.revision.value++;
      pending.complete(_json({
        'batches': [_batch()],
        'has_more': false,
        'next_offset': null
      }));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-batch:batch-lg')),
          findsNothing);
      expect(tester.takeException(), isNull);
    }, (_) => pending.future);
  });

  testWidgets('automatic refresh stops on covered routes and paused app',
      (tester) async {
    var reads = 0;
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      expect(reads, 1);
      final context = tester.element(find.byType(PreparationProductionScreen));
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')))));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 16));
      expect(reads, 1);
      Navigator.of(tester.element(find.text('Covered'))).pop();
      await tester.pumpAndSettle();
      final beforePause = reads;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 16));
      expect(reads, beforePause);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(reads, greaterThan(beforePause));
      expect(tester.takeException(), isNull);
    }, (request) {
      reads++;
      return _route(request);
    });
  });
}
