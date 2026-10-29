import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_list_row.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_expandable_filter_chip.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_production_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
      final entry = find.text('Ishlab chiqarish');
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(PreparationProductionScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('production-order:zakaz-0317')),
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

  testWidgets('order opens material, frozen recipe and produced roll QR',
      (tester) async {
    final paths = <String>[];
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();

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
      expect(row(summary).slot, M3SegmentVerticalSlot.top);
      expect(row(summary).title, 'Davom etmoqda');
      expect(row(summary).subtitle, contains('Own W'));
      expect(row(summary).subtitle, contains('1 ta rulon • 23 kg • 125 m'));
      expect(row(recipe).slot, M3SegmentVerticalSlot.middle);
      expect(row(recipe).title, 'Formula qayd etilmagan');
      expect(row(firstRoll).slot, M3SegmentVerticalSlot.middle);
      expect(row(secondRoll).slot, M3SegmentVerticalSlot.bottom);
      expect(row(firstRoll).title, _epc);
      expect(row(firstRoll).subtitle,
          contains('23 kg • 125 m • 495 mm • 50 mkm'));
      expect(row(firstRoll).onTap, isNotNull);
      final card = tester.widget<AdminSummaryCard>(find.descendant(
        of: find.byKey(const ValueKey(firstRoll)),
        matching: find.byType(AdminSummaryCard),
      ));
      expect(card.showChevron, isFalse);
      expect(card.titleMaxLines, 2);
      expect(
          tester.renderObject<RenderParagraph>(find.text(_epc)).didExceedMaxLines,
          isFalse);
      await tester.tap(find.byKey(const ValueKey(firstRoll)));
      await tester.pumpAndSettle();
      expect(find.textContaining(_epc), findsWidgets);
      expect(tester.takeException(), isNull);
    }, (request) => _json({
          'batch': _batch(recipe: null),
          'rolls': [
            _roll(recipe: null),
            {..._roll(recipe: null), 'epc': secondEpc},
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
      expect(find.text('Shnek formulasi: LG'), findsOneWidget);
      expect(find.text('Shnek A • 30%'), findsOneWidget);
      expect(find.text('Shnek B • 70%'), findsOneWidget);
      expect(find.text('Seriya ORIGINAL — 88%'), findsOneWidget);
      expect(find.text('Seriya 2 — 12%'), findsOneWidget);
      expect(find.text('Seriya 2 — 100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, (request) => _route(request));
  });

  testWidgets('paging appends orders and searching starts a fresh result',
      (tester) async {
    final queries = <Map<String, String>>[];
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
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

  testWidgets('a failed read can be retried without creating production',
      (tester) async {
    var attempts = 0;
    await _withApp(tester, () async {
      await tester.pumpWidget(_app(const PreparationProductionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-order:zakaz-0317')),
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
        'orders': [_order()],
        'has_more': false,
        'next_offset': null
      }));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-order:zakaz-0317')),
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
