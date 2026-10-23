import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_order_page_cache.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'production_snapshot_test_backend.dart';
import 'order_scan_bootstrap_fixtures.dart';

const _apparatus = 'apparatus:default:bosma_7';
const _catalog = AdminApparatus(id: _apparatus, name: 'Sequence machine');
const _epoch = 'summary-widget-server';

Map<String, dynamic> _summaryRow(String id, {String state = 'pending'}) => {
      'id': id,
      'code': id == 'order-a' ? '0101' : '0102',
      'title': id == 'order-a' ? 'Alpha package' : 'Beta package',
      'customer_name': id == 'order-a' ? 'Alpha customer' : 'Beta customer',
      'image_id': 'image-$id',
      'queue_state': state,
      'display_state': state,
      'can_reorder': state == 'pending',
    };

class _SummaryHarness {
  _SummaryHarness({this.orderIds = const ['order-a', 'order-b']});

  final List<String> orderIds;
  final events = StreamController<Object>.broadcast();
  final reads = <AdminProductionOrderPageRequest>[];
  final detailReads = <({String apparatus, String orderId})>[];
  Completer<AdminApparatusQueueSnapshot>? pendingDetail;
  Object? detailError;
  bool wrongDetailOrder = false;
  int detailRevision = 7;
  String detailState = 'pending';
  String detailTitle = 'Full detail package';
  final detailReplies = <Future<AdminApparatusQueueSnapshot>>[];
  RouteSettings? editorRoute;

  Map<String, dynamic> payload(AdminProductionOrderPageRequest request) {
    final matching = orderIds
        .where((id) => [
              _summaryRow(id)['title'],
              _summaryRow(id)['customer_name'],
              _summaryRow(id)['code'],
            ].join(' ').toLowerCase().contains(request.search.toLowerCase()))
        .toList();
    final offset = int.tryParse(request.cursor ?? '') ?? 0;
    final ids = matching.skip(offset).take(20).toList();
    return {
      'ok': true,
      'projection': 'sequence_list_v1',
      'version': 'v7-${request.search}',
      'epoch': _epoch,
      'rev': 7,
      'scope': 'summary-scope',
      'offset': offset,
      'total': matching.length,
      'next_cursor': offset + ids.length < matching.length
          ? '${offset + ids.length}'
          : null,
      'order_ids': ids,
      'sequence_positions': {
        for (final id in ids) id: orderIds.indexOf(id) + 1,
      },
      'sequence_versions': {_apparatus: 'a' * 64},
      'sequence_revisions': {_apparatus: 5},
      'queue_policies': [
        {
          'apparatus_id': _apparatus,
          'apparatus': 'Sequence machine',
          'policy': 'strict_sequence',
          'locked': false,
          'reason': '',
        },
      ],
      'rows': {for (final id in ids) id: _summaryRow(id)},
    };
  }

  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    reads.add(request);
    if (request.view == 'sequence') {
      return AdminProductionOrderPage.fromJson(payload(request));
    }
    return AdminProductionOrderPage.fromJson({
      'version': 'empty-${request.view}',
      'epoch': _epoch,
      'rev': 7,
      'offset': 0,
      'total': 0,
      'next_cursor': null,
      'closed_orders': [],
    });
  }

  Future<AdminApparatusQueueSnapshot> detail(
      {required String apparatus, required String orderId}) async {
    detailReads.add((apparatus: apparatus, orderId: orderId));
    if (detailError != null) throw detailError!;
    if (detailReplies.isNotEmpty) return detailReplies.removeAt(0);
    if (pendingDetail != null) return pendingDetail!.future;
    return fullDetail(wrongDetailOrder ? 'another-order' : orderId);
  }

  AdminApparatusQueueSnapshot fullDetail(String orderId) =>
      AdminApparatusQueueSnapshot(
        epoch: _epoch,
        scope: 'summary-detail-scope',
        revision: detailRevision,
        maps: [
          ProductionMapSaved.fromJson({
            'map': {
              'id': orderId,
              'code': '0101',
              'title': detailTitle,
              'customer_name': 'Alpha customer',
              'product_code': 'FILM-ALPHA',
              'base_length': 15000,
              'order_kg': 200,
              'nodes': [
                {'id': 'start', 'kind': 'start', 'title': 'Start'},
                {
                  'id': 'work',
                  'kind': 'apparatus',
                  'apparatus_id': _apparatus,
                  'title': 'Detailed production operation',
                },
                {'id': 'end', 'kind': 'end', 'title': 'End'},
              ],
              'edges': [
                {'from': 'start', 'to': 'work'},
                {'from': 'work', 'to': 'end'},
              ],
            },
            'program': <String, dynamic>{},
          }),
        ],
        sequences: {
          _apparatus: [orderId]
        },
        visibleOrderIds: {
          _apparatus: [orderId]
        },
        queueStates: {
          _apparatus: {orderId: detailState},
        },
        queuePolicies: const {},
        orderControls: {
          if (detailState == 'frozen') orderId: AdminOrderControlState.frozen,
        },
        queueActionControls: {
          _apparatus: {
            orderId: AdminApparatusQueueOrderActionControl.fromJson({
              ...scanControl(),
              'stage_node_id': 'work',
              if (detailState == 'frozen') ...{
                'state': 'frozen',
                'allowed_actions': <String>[],
                'interaction': {
                  ...scanControl()['interaction'] as Map,
                  'mode': 'frozen',
                },
              },
            }),
          },
        },
      );

  Future<void> mount(WidgetTester tester) async {
    await AdminProductionOrderPage.fromJson(payload(
        const AdminProductionOrderPageRequest(
            view: 'sequence', apparatus: _apparatus)));
    await AdminSequenceApparatusStore.instance.saveApparatus(_catalog);
    await tester.pumpWidget(MaterialApp(
      onGenerateRoute: (settings) {
        editorRoute = settings;
        return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Editor test route')));
      },
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AdminProductionMapOrdersScreen(
        apparatusLoader: () async => [_catalog],
        completionRequestsLoader: () async => [],
        queueSnapshotLoader: () => throw StateError('full snapshot requested'),
        orderPageLoader: read,
        orderDetailLoader: detail,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_ready',
      'window': 'w1',
      'epoch': _epoch,
      'rev': 7,
      'version': 'v7-',
      'resync': false,
    }));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    dismissAdminTopNotice();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await events.close();
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }

  void patch(List<Map<String, dynamic>> ops,
          {String baseVersion = 'v7-',
          String version = 'v8',
          int revision = 8}) =>
      events.add(AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_delta',
        'window': 'w1',
        'epoch': _epoch,
        'rev': revision,
        'base_version': baseVersion,
        'version': version,
        'page_count': 1,
        'changes': [
          {
            'index': 0,
            'ops': [
              {
                'op': 'set',
                'path': ['version'],
                'value': version
              },
              {
                'op': 'set',
                'path': ['rev'],
                'value': revision
              },
              ...ops,
            ],
          },
        ],
      }));
}

Finder _row(String id) => find.byKey(ValueKey('sequence-row-$_apparatus-$id'));

Finder _detailSheet() => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');

dynamic _detailContent(WidgetTester tester) =>
    tester.widget(find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));

List<String> _rowOrder(WidgetTester tester) => tester
    .widgetList(find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_SequenceOrderRow'))
    .map((widget) => ((widget as dynamic).order as ProductionMapSaved).map.id)
    .toList();

Color? _rowColor(WidgetTester tester, String id) => tester
    .widget<Material>(
        find.descendant(of: _row(id), matching: find.byType(Material)).first)
    .color;

void main() {
  var sessionSerial = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    AdminOrderPageCache.debugOverride = AdminOrderPageCache();
    ProductionSnapshotStore.debugOverride =
        ProductionSnapshotStore(backend: MemoryProductionSnapshotBackend());
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    AppSession.instance.token = 'summary-test-token';
    AppSession.instance.profile = SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'summary-widget-admin-${++sessionSerial}',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
  });

  tearDown(() async {
    AdminOrderPageCache.instance.clear();
    AdminOrderPageCache.debugOverride = null;
    ProductionSnapshotStore.debugOverride = null;
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('sequence list renders summaries without maps or detail requests',
      (tester) async {
    final harness = _SummaryHarness();
    await harness.mount(tester);
    expect(_rowOrder(tester), ['order-a', 'order-b']);
    final first = _row('order-a');
    for (final text in ['0101', 'Alpha package', 'Alpha customer']) {
      expect(find.descendant(of: first, matching: find.textContaining(text)),
          findsWidgets);
    }
    expect(find.descendant(of: first, matching: find.textContaining('apparat')),
        findsNothing);
    expect(harness.detailReads, isEmpty);
    expect(_detailSheet(), findsNothing);
    final thumb = tester.widget<AdminOrderCoverThumb>(find.descendant(
        of: first, matching: find.byType(AdminOrderCoverThumb)));
    final url = Uri.parse(thumb.imageUrl);
    expect(url.path, endsWith('/production-maps/order-image/view'));
    expect(url.queryParameters['order_id'], 'order-a');
    expect(url.queryParameters['image_id'], 'image-order-a');
    final reads = harness.reads.length;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(harness.reads.length, reads, reason: 'No queue polling');
    await harness.dispose(tester);
  });

  testWidgets('sequence summary tap waits for one scoped complete detail read',
      (tester) async {
    final harness = _SummaryHarness()
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    await tester.tap(_row('order-a'));
    await tester.pump();
    await tester.tap(_row('order-a'));
    await tester.pump();
    expect(harness.detailReads, [(apparatus: _apparatus, orderId: 'order-a')]);
    expect(_detailSheet(), findsNothing,
        reason: 'Summary fields cannot authorize detailed actions');
    harness.pendingDetail!.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    expect(_detailSheet(), findsOneWidget);
    final dynamic sheet = tester.widget(_detailSheet());
    expect((sheet.order as ProductionMapSaved).map.nodes, hasLength(3));
    expect(
        (sheet.order as ProductionMapSaved).map.title, 'Full detail package');
    expect(harness.detailReads, hasLength(1));
    await harness.dispose(tester);
  });

  testWidgets('sequence summary long press hydrates before edit actions',
      (tester) async {
    final harness = _SummaryHarness()
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    final full = harness.fullDetail('order-a');
    // This is the existing in-memory API fixture, never an ERP write.
    await MobileApi.instance.adminSaveProductionMap(full.maps.single.map);
    await harness.mount(tester);
    await tester.longPress(_row('order-a'));
    await tester.pump();
    expect(harness.detailReads, [(apparatus: _apparatus, orderId: 'order-a')]);
    expect(find.text('Mapni o‘zgartirish'), findsNothing);
    expect(find.text('Buyurtmani tahrirlash'), findsNothing);
    expect(harness.editorRoute, isNull);
    harness.pendingDetail!.complete(full);
    await tester.pumpAndSettle();
    expect(find.text('Mapni o‘zgartirish'), findsOneWidget);
    expect(find.text('Buyurtmani tahrirlash'), findsOneWidget);
    await tester.tap(find.text('Mapni o‘zgartirish'));
    await tester.pumpAndSettle();
    expect(find.text('Editor test route'), findsOneWidget);
    final args = harness.editorRoute!.arguments as ProductionMapTestArgs;
    expect(args.savedMap!.id, 'order-a');
    expect(args.savedMap!.nodes, hasLength(3),
        reason: 'The editor must receive a full graph, never a summary shell');
    expect(args.savedMap!.title, 'Full detail package');
    expect(harness.detailReads, hasLength(1));
    await harness.dispose(tester);
  });

  test('sequence summaries persist in v2 without canonical map shells',
      () async {
    final harness = _SummaryHarness();
    final backend = MemoryProductionSnapshotBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final first = AdminOrderPageCache(persistence: store);
    final request = const AdminProductionOrderPageRequest(
        view: 'sequence', apparatus: _apparatus);
    final page =
        await AdminProductionOrderPage.fromJson(harness.payload(request));
    final catalog = _catalog.copyWith(
      sourceRevision: 1,
      sourceAasxSha256: 'a' * 64,
      operation: 'print',
      technology: 'gravure',
    );
    first.save(
      visit: first.open('ram-scope'),
      apparatus: [catalog],
      selectedApparatusId: _apparatus,
      windows: [
        AdminOrderPageCacheWindow(request, [page])
      ],
      persistentScope: 'disk-scope',
    );
    await first.flush();
    expect(await store.read(scope: 'disk-scope', key: 'admin-pages-v2'),
        isNotNull);
    expect(
        await store.read(scope: 'disk-scope', key: 'admin-pages-v1'), isNull);
    first.clear();
    final restarted = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    final restored = await restarted.restore(
        visit: restarted.open('ram-scope'), persistentScope: 'disk-scope');
    expect(restored, isNotNull);
    final saved = restored!.windows.single.pages.single;
    expect(saved.isSequenceList, isTrue);
    expect(saved.snapshot, isNull);
    expect(saved.wireValue!.containsKey('maps'), isFalse);
    expect(saved.orderIds, ['order-a', 'order-b']);
    expect(saved.sequenceRows['order-a']!.customerName, 'Alpha customer');
    expect(saved.sequencePositions['order-b'], 2);
    expect(saved.sequenceVersions[_apparatus], 'a' * 64);
    restarted.clear();
    await harness.events.close();
  });

  test('sequence v2 cache does not adopt a legacy v1 baseline', () async {
    final store =
        ProductionSnapshotStore(backend: MemoryProductionSnapshotBackend());
    await store.write(scope: 'disk-scope', key: 'admin-pages-v1', value: {
      'legacy': 'old full map baseline',
    });
    final cache = AdminOrderPageCache(persistence: store);
    expect(
        await cache.restore(
            visit: cache.open('ram-scope'), persistentScope: 'disk-scope'),
        isNull);
    expect(await store.read(scope: 'disk-scope', key: 'admin-pages-v1'),
        isNotNull);
    cache.clear();
  });

  testWidgets(
      'sequence reorder ACK waits for matching summary sequence version',
      (tester) async {
    final harness = _SummaryHarness();
    final writes = <http.Request>[];
    final reply = Completer<http.Response>();
    await http.runWithClient(() async {
      await harness.mount(tester);
      final reads = harness.reads.length;
      await TestModeController.instance.setEnabled(false);
      tester
          .widget<ReorderableListView>(find.byType(ReorderableListView))
          .onReorderItem!(1, 0);
      await tester.pump();
      await tester.pump();
      expect(writes, hasLength(1));
      final sent = jsonDecode(writes.single.body) as Map;
      expect(sent['expected_version'], 'a' * 64);
      expect(sent['order_id'], 'order-b');
      reply.complete(http.Response(
          jsonEncode({
            'ok': true,
            'order_ids': ['order-b', 'order-a'],
            'version': 'b' * 64,
            'revision': 6,
            'epoch': _epoch,
            'adjusted': false,
          }),
          200));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['order-b', 'order-a']);
      // Equal sequence revision with a different version cannot certify ACK.
      harness.patch([
        {
          'op': 'set',
          'path': ['sequence_revisions', _apparatus],
          'value': 6,
        },
      ]);
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['order-b', 'order-a'],
          reason:
              'Mismatched canonical version cannot undo accepted placement');
      harness.patch([
        {
          'op': 'set',
          'path': ['sequence_versions', _apparatus],
          'value': 'b' * 64,
        },
        {
          'op': 'set',
          'path': ['order_ids'],
          'value': ['order-b', 'order-a'],
        },
        {
          'op': 'set',
          'path': ['sequence_positions'],
          'value': {'order-b': 1, 'order-a': 2},
        },
      ], baseVersion: 'v8', version: 'v9', revision: 9);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['order-b', 'order-a']);
      expect(harness.reads.length, reads,
          reason: 'Matching summary cursor settles ACK without recovery GET');
      expect(harness.detailReads, isEmpty);
      expect(writes, hasLength(1));
      await harness.dispose(tester);
    },
        () => MockClient((request) {
              if (request.method == 'POST' &&
                  request.url.path.endsWith('/production-maps/sequence')) {
                writes.add(request);
                return reply.future;
              }
              return Future.value(http.Response('{}', 404));
            }));
  });

  testWidgets(
      'sequence detail reopen rejects cache older than streamed summary',
      (tester) async {
    final harness = _SummaryHarness();
    await harness.mount(tester);
    await tester.tap(_row('order-a'));
    await tester.pumpAndSettle();
    expect(_detailSheet(), findsOneWidget);
    expect(harness.detailReads, hasLength(1));
    harness.detailRevision = 8;
    harness.patch([
      {
        'op': 'set',
        'path': ['rows', 'order-a', 'display_state'],
        'value': 'frozen',
      },
      {
        'op': 'set',
        'path': ['rows', 'order-a', 'can_reorder'],
        'value': false,
      },
    ]);
    await tester.pumpAndSettle();
    final dynamic sheet = tester.widget(_detailSheet());
    expect(sheet.workerMode, isFalse);
    expect(sheet.canManageQueue, isFalse,
        reason: 'Admin information sheet cannot authorize worker mutations');
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    harness.detailRevision = 8;
    await tester.tap(_row('order-a'));
    await tester.pumpAndSettle();
    expect(harness.detailReads, hasLength(2),
        reason: 'An old detail future must be replaced after newer summary');
    expect(_detailSheet(), findsOneWidget);
    final dynamic refreshed = tester.widget(_detailSheet());
    final snapshot =
        refreshed.currentQueueSnapshot() as AdminApparatusQueueSnapshot;
    expect(snapshot.revision, 8);
    await harness.dispose(tester);
  });

  testWidgets(
      'open admin detail refreshes pushed status and retains expansions',
      (tester) async {
    final harness = _SummaryHarness();
    await harness.mount(tester);
    await tester.tap(_row('order-a'));
    await tester.pumpAndSettle();
    final originalState = tester.state(_detailSheet());
    _detailContent(tester).onToggleSummaryExpanded();
    await tester.pumpAndSettle();
    expect(_detailContent(tester).summaryExpanded, isTrue);
    final refresh = Completer<AdminApparatusQueueSnapshot>();
    harness.detailReplies.add(refresh.future);
    harness.patch([
      {
        'op': 'set',
        'path': ['rows', 'order-a', 'display_state'],
        'value': 'frozen',
      },
    ]);
    await tester.pump();
    await tester.pump();
    expect(harness.detailReads, hasLength(2));
    harness.patch([
      {
        'op': 'set',
        'path': ['rows', 'order-a', 'can_reorder'],
        'value': false,
      },
    ], baseVersion: 'v8', version: 'v9', revision: 9);
    await tester.pump();
    await tester.pump();
    expect(harness.detailReads, hasLength(2),
        reason: 'Revision bursts must share the active detail read');
    harness
      ..detailRevision = 9
      ..detailState = 'frozen'
      ..detailTitle = 'Live revised package';
    refresh.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    expect(identical(tester.state(_detailSheet()), originalState), isTrue);
    final content = _detailContent(tester);
    expect(content.map.title, 'Live revised package');
    expect(content.queueStates['order-a'], 'frozen');
    expect(content.orderControlState, AdminOrderControlState.frozen);
    expect(content.summaryExpanded, isTrue);
    expect(harness.detailReads, hasLength(2),
        reason: 'A reply already covering the latest revision needs no reread');
    await harness.dispose(tester);
  });

  for (final outcome in ['closed', 'session changed']) {
    testWidgets('open admin detail ignores pushed refresh after $outcome',
        (tester) async {
      final harness = _SummaryHarness();
      await harness.mount(tester);
      await tester.tap(_row('order-a'));
      await tester.pumpAndSettle();
      final refresh = Completer<AdminApparatusQueueSnapshot>();
      harness.detailReplies.add(refresh.future);
      harness.patch([
        {
          'op': 'set',
          'path': ['rows', 'order-a', 'display_state'],
          'value': 'frozen',
        },
      ]);
      await tester.pump();
      await tester.pump();
      expect(harness.detailReads, hasLength(2));
      if (outcome == 'closed') {
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      } else {
        AppSession.instance.token = 'replacement-session';
        await tester.pump();
      }
      harness
        ..detailRevision = 8
        ..detailState = 'frozen'
        ..detailTitle = 'Obsolete refreshed package';
      refresh.complete(harness.fullDetail('order-a'));
      await tester.pumpAndSettle();
      if (outcome == 'closed') {
        expect(_detailSheet(), findsNothing);
      } else {
        expect(_detailContent(tester).map.title, 'Full detail package');
        expect(_detailContent(tester).orderControlState,
            AdminOrderControlState.active);
      }
      expect(find.text('Obsolete refreshed package'), findsNothing);
      await harness.dispose(tester);
    });
  }

  for (final failure in ['missing', 'error', 'scope']) {
    testWidgets('sequence summary rejects $failure detail before actions',
        (tester) async {
      final harness = _SummaryHarness();
      if (failure == 'missing') harness.wrongDetailOrder = true;
      if (failure == 'error') {
        harness.detailError = const MobileApiException(
            code: 'order_not_available', message: 'Unavailable');
      }
      if (failure == 'scope') {
        harness.pendingDetail = Completer<AdminApparatusQueueSnapshot>();
      }
      await harness.mount(tester);
      await tester.tap(_row('order-a'));
      await tester.pump();
      if (failure == 'scope') {
        AppSession.instance.token = 'different-session';
        harness.pendingDetail!.complete(harness.fullDetail('order-a'));
      }
      await tester.pumpAndSettle();
      expect(harness.detailReads, hasLength(failure == 'missing' ? 2 : 1));
      expect(_detailSheet(), findsNothing);
      expect(find.text('Full detail package'), findsNothing);
      await harness.dispose(tester);
    });
  }

  testWidgets('sequence summary sparse delta updates order and color in place',
      (tester) async {
    final harness = _SummaryHarness();
    await harness.mount(tester);
    final beforeColor = _rowColor(tester, 'order-b');
    final reads = harness.reads.length;
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': 'w1',
      'epoch': _epoch,
      'rev': 8,
      'base_version': 'v7-',
      'version': 'v8',
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {
              'op': 'set',
              'path': ['version'],
              'value': 'v8'
            },
            {
              'op': 'set',
              'path': ['rev'],
              'value': 8
            },
            {
              'op': 'set',
              'path': ['order_ids'],
              'value': ['order-b', 'order-a'],
            },
            {
              'op': 'set',
              'path': ['sequence_positions'],
              'value': {'order-b': 1, 'order-a': 2},
            },
            {
              'op': 'set',
              'path': ['sequence_versions', _apparatus],
              'value': 'b' * 64,
            },
            {
              'op': 'set',
              'path': ['sequence_revisions', _apparatus],
              'value': 6,
            },
            {
              'op': 'set',
              'path': ['rows', 'order-b', 'queue_state'],
              'value': 'in_progress',
            },
            {
              'op': 'set',
              'path': ['rows', 'order-b', 'display_state'],
              'value': 'in_progress',
            },
            {
              'op': 'set',
              'path': ['rows', 'order-b', 'can_reorder'],
              'value': false,
            },
          ],
        },
      ],
    }));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['order-b', 'order-a']);
    expect(_rowColor(tester, 'order-b'), isNot(beforeColor));
    expect(harness.reads.length, reads,
        reason: 'A matching delta must not reload the list');
    expect(harness.detailReads, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets('sequence summary renders every server display state via delta',
      (tester) async {
    final harness = _SummaryHarness();
    await harness.mount(tester);
    final initialReads = harness.reads.length;
    var version = 'v7-';
    var revision = 7;
    const states = {
      'pending': 'neutral',
      'print_preflight': 'printPreflight',
      'print_preflight_passed': 'printPreflightPassed',
      'in_progress': 'inProgress',
      'waiting_next_stage': 'waitingNextStage',
      'paused': 'paused',
      'frozen': 'frozen',
      'issue': 'issue',
      'completed': 'completed',
    };
    for (final entry in states.entries) {
      final baseVersion = version;
      revision++;
      version = 'v$revision';
      harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
        'type': 'page_window_delta',
        'window': 'w1',
        'epoch': _epoch,
        'rev': revision,
        'base_version': baseVersion,
        'version': version,
        'page_count': 1,
        'changes': [
          {
            'index': 0,
            'ops': [
              {
                'op': 'set',
                'path': ['version'],
                'value': version
              },
              {
                'op': 'set',
                'path': ['rev'],
                'value': revision
              },
              {
                'op': 'set',
                'path': ['rows', 'order-a', 'display_state'],
                'value': entry.key,
              },
              {
                'op': 'set',
                'path': ['rows', 'order-a', 'can_reorder'],
                'value': false,
              },
            ],
          },
        ],
      }));
      await tester.pumpAndSettle();
      final dynamic row = tester.widget(_row('order-a'));
      expect(row.tone.toString().split('.').last, entry.value,
          reason: 'Server state ${entry.key} must retain the existing palette');
      expect(row.canReorder, isFalse);
    }
    expect(harness.reads.length, initialReads);
    expect(harness.detailReads, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets(
      'sequence summary search keeps original rank and ignores old window',
      (tester) async {
    final harness = _SummaryHarness();
    await harness.mount(tester);
    await tester.enterText(find.byType(EditableText).first, 'Beta customer');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['order-b']);
    final dynamic row = tester.widget(_row('order-b'));
    expect(row.position, 2,
        reason: 'Search must preserve apparatus queue rank');
    expect(harness.reads.last.search, 'Beta customer');
    final reads = harness.reads.length;
    harness.events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': 'w1',
      'epoch': _epoch,
      'rev': 8,
      'base_version': 'v7-',
      'version': 'late-v8',
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {
              'op': 'set',
              'path': ['version'],
              'value': 'late-v8'
            },
            {
              'op': 'set',
              'path': ['rev'],
              'value': 8
            },
            {
              'op': 'set',
              'path': ['rows', 'order-b', 'title'],
              'value': 'Old window title',
            },
          ],
        },
      ],
    }));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['order-b']);
    expect(find.textContaining('Old window title'), findsNothing);
    expect(find.textContaining('Beta package'), findsWidgets);
    expect(harness.reads.length, reads);
    expect(harness.detailReads, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets('sequence summary scroll appends only the next twenty row window',
      (tester) async {
    final harness = _SummaryHarness(orderIds: [
      'order-a',
      'order-b',
      for (var index = 2; index < 25; index++) 'order-$index',
    ]);
    await harness.mount(tester);
    int count() => tester
        .widget<ReorderableListView>(find.byType(ReorderableListView).first)
        .itemCount;
    expect(count(), 20);
    expect(harness.reads.where((request) => request.cursor != null), isEmpty);
    final scroll = find
        .byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down)
        .hitTestable()
        .first;
    final position = tester.state<ScrollableState>(scroll).position;
    position.jumpTo((position.maxScrollExtent - 200)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble());
    await tester.pump();
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(count(), 25);
    expect(
        harness.reads
            .where((request) => request.cursor != null)
            .map((request) => request.cursor),
        ['20']);
    expect(harness.detailReads, isEmpty);
    await harness.dispose(tester);
  });
}
