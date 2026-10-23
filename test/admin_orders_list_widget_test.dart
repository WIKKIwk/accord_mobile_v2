import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/pending_order_widgets.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_screen.dart';
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
const _epoch = 'orders-widget-server';

Map<String, dynamic> _summaryRow(String id, {String state = 'pending'}) => {
      'id': id,
      'code': id == 'order-a' ? '0101' : '0102',
      'title': id == 'order-a' ? 'Alpha package' : 'Beta package',
      'customer_name': id == 'order-a' ? 'Alpha customer' : 'Beta customer',
      'image_id': 'image-$id',
      'display_state': state,
      'watermarks': <Map<String, dynamic>>[],
    };

class _OrdersHarness {
  final List<String> orderIds = const ['order-a', 'order-b'];
  final events = StreamController<Object>.broadcast();
  final reads = <AdminProductionOrderPageRequest>[];
  final detailReads = <({String apparatus, String orderId})>[];
  Completer<AdminApparatusQueueSnapshot>? pendingDetail;
  Object? detailError;
  bool wrongDetailOrder = false;
  int detailRevision = 7;
  String detailEpoch = _epoch;
  String detailState = 'pending';
  String detailTitle = 'Full detail package';
  Duration detailDelay = Duration.zero;
  final detailReplies = <Future<AdminApparatusQueueSnapshot>>[];
  final rowOverrides = <String, Map<String, dynamic>>{};
  final detailControlOverrides = <String, dynamic>{};
  RouteSettings? editorRoute;
  final routeObserver = _DetailRouteObserver();
  String windowId = '';
  bool includePending = false;
  bool includeSequence = false;

  Map<String, dynamic> payload(AdminProductionOrderPageRequest request) {
    final matching = orderIds
        .where((id) => [
              _summaryRow(id)['title'],
              _summaryRow(id)['customer_name'],
              _summaryRow(id)['code'],
            ].join(' ').toLowerCase().contains(request.search.toLowerCase()))
        .toList();
    final offset = int.tryParse(request.cursor ?? '') ?? 0;
    final pendingIds =
        includePending && offset == 0 ? ['pending-a'] : <String>[];
    final ids = matching.skip(offset).take(20 - pendingIds.length).toList();
    return {
      'ok': true,
      'projection': 'orders_list_v1',
      'version': 'v7-${request.search}',
      'epoch': _epoch,
      'rev': 7,
      'scope': 'orders-list-scope',
      'offset': offset,
      'total': matching.length + (includePending ? 1 : 0),
      'next_cursor': offset + ids.length + pendingIds.length <
              matching.length + (includePending ? 1 : 0)
          ? '${offset + ids.length + pendingIds.length}'
          : null,
      'order_ids': ids,
      'rows': {
        for (final id in ids) id: {..._summaryRow(id), ...?rowOverrides[id]}
      },
      'pending_ids': pendingIds,
      'pending_rows': {
        for (final id in pendingIds)
          id: {
            'id': id,
            'code': '0201',
            'title': 'Draft package',
            'customer_name': 'Draft customer',
            'image_id': 'draft-image',
            'kg': 180,
          },
      },
    };
  }

  Future<AdminProductionOrderPage?> read(
      AdminProductionOrderPageRequest request) async {
    reads.add(request);
    if (request.view == 'orders') {
      return AdminProductionOrderPage.fromJson(payload(request));
    }
    if (request.view == 'sequence' && includeSequence) {
      return AdminProductionOrderPage.fromJson({
        ...payload(request),
        'projection': 'sequence_list_v1',
        'pending_ids': <String>[],
        'pending_rows': <String, dynamic>{},
        'rows': {
          for (final id in orderIds)
            id: {
              ..._summaryRow(id),
              'queue_state': 'pending',
              'can_reorder': true,
            }
        },
        'sequence_positions': {
          for (var i = 0; i < orderIds.length; i++) orderIds[i]: i + 1
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
          }
        ],
      });
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
    if (detailDelay > Duration.zero) await Future<void>.delayed(detailDelay);
    return fullDetail(wrongDetailOrder ? 'another-order' : orderId);
  }

  AdminApparatusQueueSnapshot fullDetail(String orderId) =>
      AdminApparatusQueueSnapshot(
        epoch: detailEpoch,
        scope: 'summary-detail-scope',
        revision: detailRevision,
        maps: [
          ProductionMapSaved.fromJson({
            'map': {
              'id': orderId,
              'code': '0101',
              'title': detailTitle,
              'customer_name': 'Alpha customer',
              'image_id': 'image-$orderId',
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
              ...detailControlOverrides,
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
    await AdminProductionOrderPage.fromJson(
        payload(const AdminProductionOrderPageRequest(view: 'orders')));
    await AdminSequenceApparatusStore.instance.saveApparatus(_catalog);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [routeObserver],
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
    await tester.tap(find.text('Buyurtmalar'));
    await tester.pumpAndSettle();
    final dynamic viewport = tester.widget(find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_AdminOrderPageViewport' &&
        (widget as dynamic).window.request.view == 'orders'));
    windowId = viewport.window.liveId as String;
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_ready',
      'window': windowId,
      'epoch': _epoch,
      'rev': 7,
      'version': 'v7-',
      'resync': false,
    }));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    dismissAdminTopNotice();
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
        'window': windowId,
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

class _DetailRouteObserver extends NavigatorObserver {
  final popupRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) popupRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

Finder _row(String id) => find.byKey(ValueKey('opened-order-$id'));

Finder _detailSheet() => find.byWidgetPredicate((widget) =>
    widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet' &&
    !(widget as dynamic).detailPending);

Finder _pendingDetailSheet() => find.byWidgetPredicate((widget) =>
    widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet' &&
    (widget as dynamic).detailPending);

Finder _detailRetry() =>
    find.byKey(const ValueKey('admin-sequence-detail-retry'));

dynamic _detailContent(WidgetTester tester) =>
    tester.widget(find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));

List<String> _rowOrder(WidgetTester tester) => tester
    .widgetList(find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OpenedOrderRow'))
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
    AppSession.instance.token = 'orders-list-test-token';
    AppSession.instance.profile = SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'orders-widget-admin-${++sessionSerial}',
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

  testWidgets('orders tab renders compact rows without maps or eager detail',
      (tester) async {
    final harness = _OrdersHarness();
    await harness.mount(tester);
    expect(_rowOrder(tester), ['order-a', 'order-b']);
    for (final label in ['0101', 'Alpha package', 'Alpha customer']) {
      expect(
          find.descendant(
              of: _row('order-a'), matching: find.textContaining(label)),
          findsWidgets);
    }
    expect(
        find.descendant(
            of: _row('order-a'), matching: find.textContaining('apparat')),
        findsNothing);
    final thumb = tester.widget<AdminOrderCoverThumb>(find.descendant(
        of: _row('order-a'), matching: find.byType(AdminOrderCoverThumb)));
    final url = Uri.parse(thumb.imageUrl);
    expect(url.queryParameters['order_id'], 'order-a');
    expect(url.queryParameters['image_id'], 'image-order-a');
    expect(harness.detailReads, isEmpty);
    expect(_detailSheet(), findsNothing);
    final reads = harness.reads.length;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(harness.reads.length, reads, reason: 'No list polling');
    await harness.dispose(tester);
  });

  testWidgets('orders tab opens existing sheet before delayed full detail',
      (tester) async {
    final harness = _OrdersHarness()
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    final dynamic retainedRow = tester.widget(_row('order-a'));
    final open = retainedRow.onInfo as VoidCallback;
    await tester.tap(_row('order-a'));
    await tester.pump(const Duration(milliseconds: 16));
    open();
    await tester.pump();
    expect(_pendingDetailSheet(), findsOneWidget);
    expect(harness.detailReads, [(apparatus: '', orderId: 'order-a')]);
    final dynamic pending = tester.widget(_pendingDetailSheet());
    expect(pending.apparatus, isNull);
    expect(pending.canManageQueue, isFalse);
    expect(pending.onQueueAction, isNull);
    expect(_detailContent(tester).materialsLoading, isTrue);
    expect(_detailContent(tester).attachedQolipsLoading, isTrue);
    expect(harness.routeObserver.popupRoutes, hasLength(1));
    harness.pendingDetail!.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    final dynamic loaded = tester.widget(_detailSheet());
    expect((loaded.order as ProductionMapSaved).map.nodes, hasLength(3));
    expect(loaded.canManageQueue, isFalse);
    expect(harness.detailReads, hasLength(1));
    expect(harness.routeObserver.popupRoutes, hasLength(1));
    await harness.dispose(tester);
  });

  testWidgets('orders sheet retains State and component geometry on hydration',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final harness = _OrdersHarness()
      ..detailTitle = 'Alpha package'
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    await tester.tap(_row('order-a'));
    await tester.pumpAndSettle();
    final originalState = tester.state(_pendingDetailSheet());
    final components = <Finder>[
      for (final type in [
        '_OrderStartUnifiedCard',
        '_OrderSummaryCard',
        '_OrderMapProgressCard',
      ])
        find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == type),
      find.byKey(const ValueKey('production-order-detail-photo-thumbnail')),
      find.byKey(const ValueKey('production-order-detail-close')),
    ];
    final before = components.map(tester.getRect).toList();
    harness.pendingDetail!.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    expect(identical(tester.state(_detailSheet()), originalState), isTrue);
    for (var i = 0; i < components.length; i++) {
      expect(tester.getRect(components[i]), before[i],
          reason: 'Existing component $i may not jump after hydration');
    }
    await harness.dispose(tester);
  });

  for (final outcome in ['closed', 'account changed']) {
    testWidgets('orders sheet ignores pending response after $outcome',
        (tester) async {
      final harness = _OrdersHarness()
        ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
      await harness.mount(tester);
      await tester.tap(_row('order-a'));
      await tester.pumpAndSettle();
      if (outcome == 'closed') {
        await tester
            .tap(find.byKey(const ValueKey('production-order-detail-close')));
        await tester.pumpAndSettle();
      } else {
        AppSession.instance.token = 'replacement-account';
        await tester.pump();
      }
      harness.pendingDetail!.complete(harness.fullDetail('order-a'));
      await tester.pumpAndSettle();
      expect(_detailSheet(), findsNothing);
      expect(find.text('Full detail package'), findsNothing);
      expect(harness.routeObserver.popupRoutes, hasLength(1));
      await harness.dispose(tester);
    });
  }

  testWidgets('orders sheet close and reopen shares the pending scoped read',
      (tester) async {
    final harness = _OrdersHarness()
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    await tester.tap(_row('order-a'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('production-order-detail-close')));
    await tester.pumpAndSettle();
    await tester.tap(_row('order-a'));
    await tester.pump();
    expect(harness.detailReads, hasLength(1));
    harness.pendingDetail!.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    expect(_detailSheet(), findsOneWidget);
    expect(harness.routeObserver.popupRoutes, hasLength(2));
    await harness.dispose(tester);
  });

  testWidgets('orders long press hydrates full graph before editor actions',
      (tester) async {
    final harness = _OrdersHarness()
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    final full = harness.fullDetail('order-a');
    await MobileApi.instance.adminSaveProductionMap(full.maps.single.map);
    await harness.mount(tester);
    await tester.longPress(_row('order-a'));
    await tester.pump();
    expect(harness.detailReads, [(apparatus: '', orderId: 'order-a')]);
    expect(find.text('Mapni o‘zgartirish'), findsNothing);
    expect(find.text('Buyurtmani tahrirlash'), findsNothing);
    expect(harness.editorRoute, isNull);
    harness.pendingDetail!.complete(full);
    await tester.pumpAndSettle();
    expect(find.text('Mapni o‘zgartirish'), findsOneWidget);
    expect(find.text('Buyurtmani tahrirlash'), findsOneWidget);
    await tester.tap(find.text('Mapni o‘zgartirish'));
    await tester.pumpAndSettle();
    final args = harness.editorRoute!.arguments as ProductionMapTestArgs;
    expect(args.savedMap!.id, 'order-a');
    expect(args.savedMap!.nodes, hasLength(3),
        reason: 'Editors may never receive a presentation-only shell');
    expect(harness.detailReads, hasLength(1));
    await harness.dispose(tester);
  });

  for (final failure in ['missing', 'error', 'epoch', 'stale']) {
    testWidgets(
        'orders summary rejects $failure detail and retries in same route',
        (tester) async {
      final harness = _OrdersHarness();
      if (failure == 'missing') harness.wrongDetailOrder = true;
      if (failure == 'epoch') harness.detailEpoch = 'retired-server';
      if (failure == 'stale') harness.detailRevision = 6;
      if (failure == 'error') {
        harness.detailError = const MobileApiException(
            code: 'unavailable', message: 'Detail unavailable');
      }
      await harness.mount(tester);
      await tester.tap(_row('order-a'));
      await tester.pumpAndSettle();
      expect(_detailSheet(), findsNothing);
      expect(find.text('Full detail package'), findsNothing);
      expect(_pendingDetailSheet(), findsOneWidget);
      expect(_detailRetry(), findsOneWidget);
      harness
        ..wrongDetailOrder = false
        ..detailEpoch = _epoch
        ..detailRevision = 7
        ..detailError = null;
      await tester.tap(_detailRetry());
      await tester.pumpAndSettle();
      expect(_detailSheet(), findsOneWidget);
      expect(harness.routeObserver.popupRoutes, hasLength(1));
      await harness.dispose(tester);
    });
  }

  testWidgets(
      'orders sparse delta updates row order color and apparatus watermark',
      (tester) async {
    final harness = _OrdersHarness();
    await harness.mount(tester);
    final before = _rowColor(tester, 'order-b');
    final reads = harness.reads.length;
    harness.patch([
      {
        'op': 'set',
        'path': ['order_ids'],
        'value': ['order-b', 'order-a']
      },
      {
        'op': 'set',
        'path': ['rows', 'order-b', 'display_state'],
        'value': 'in_progress'
      },
      {
        'op': 'set',
        'path': ['rows', 'order-b', 'watermarks'],
        'value': [
          {'kind': 'active', 'apparatus_id': _apparatus},
        ]
      },
    ]);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['order-b', 'order-a']);
    expect(_rowColor(tester, 'order-b'), isNot(before));
    final dynamic row = tester.widget(_row('order-b'));
    expect(row.tone.toString().split('.').last, 'inProgress');
    expect(row.watermarks, hasLength(1));
    expect(row.watermarks.single.label, contains('Sequence machine'));
    expect(harness.reads.length, reads,
        reason: 'Push may not refetch a matching page');
    expect(harness.detailReads, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets(
      'orders open detail refreshes streamed revision without replacing State',
      (tester) async {
    final harness = _OrdersHarness();
    await harness.mount(tester);
    await tester.tap(_row('order-a'));
    await tester.pumpAndSettle();
    final originalState = tester.state(_detailSheet());
    _detailContent(tester).onToggleSummaryExpanded();
    await tester.pumpAndSettle();
    final refresh = Completer<AdminApparatusQueueSnapshot>();
    harness.detailReplies.add(refresh.future);
    harness.patch([
      {
        'op': 'set',
        'path': ['rows', 'order-a', 'display_state'],
        'value': 'frozen'
      },
    ]);
    await tester.pump();
    await tester.pump();
    expect(harness.detailReads, hasLength(2));
    final dynamic awaiting = tester.widget(_detailSheet());
    expect(awaiting.currentQueueSnapshot(), isNull,
        reason: 'A pushed revision withdraws previous action authority');
    harness
      ..detailRevision = 8
      ..detailState = 'frozen';
    refresh.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    expect(identical(tester.state(_detailSheet()), originalState), isTrue);
    expect(_detailContent(tester).summaryExpanded, isTrue);
    expect(_detailContent(tester).orderControlState,
        AdminOrderControlState.frozen);
    expect(harness.detailReads, hasLength(2));
    await harness.dispose(tester);
  });

  testWidgets(
      'pending summary fetches its full template before detail and resume',
      (tester) async {
    final harness = _OrdersHarness()..includePending = true;
    final detailReply = Completer<http.Response>();
    final reads = <http.Request>[];
    await TestModeController.instance.setEnabled(false);
    await http.runWithClient(() async {
      await harness.mount(tester);
      final card = find.byKey(const ValueKey('pending-order-pending-a'));
      expect(card, findsOneWidget);
      expect(
          find.descendant(
              of: card, matching: find.textContaining('Draft package')),
          findsOneWidget);
      expect(
          reads.where((r) =>
              r.url.path.endsWith('/pending-orders') &&
              r.url.queryParameters['id'] == 'pending-a'),
          isEmpty);
      await tester.tap(card);
      await tester.pump();
      expect(
          reads.where((r) =>
              r.url.path.endsWith('/pending-orders') &&
              r.url.queryParameters['id'] == 'pending-a'),
          hasLength(1));
      expect(find.byType(PendingOrderDetailSheet), findsNothing,
          reason: 'No summary template can become calculation authority');
      expect(find.byType(AdminCalculateScreen), findsNothing);
      detailReply.complete(http.Response(
          jsonEncode({
            'id': 'pending-a',
            'manager_name': 'Detail manager',
            'template': {
              'id': 'template-a',
              'code': '0201',
              'order_number': '0201',
              'customer': 'Draft customer',
              'product': 'Draft package',
              'image_id': 'draft-image',
              'kg': 180,
              'frame_product_size_mm': 145,
              'frame_count': 3,
              'width_mm': 437,
              'layers': [
                {
                  'material_id': 'material-a',
                  'material': 'Detail-only OPP',
                  'micron': '30'
                },
              ],
              'production_options': {
                'print_method': 'flexo',
                'cold_glue': false
              },
            },
          }),
          200));
      await tester.pumpAndSettle();
      final sheet = tester.widget<PendingOrderDetailSheet>(
          find.byType(PendingOrderDetailSheet));
      expect(sheet.order.template.layers.single.material, 'Detail-only OPP');
      expect(sheet.order.template.frameProductSizeMm, 145);
      expect(sheet.order.managerName, 'Detail manager');
      await tester.tap(find.text('Order ochishni tugallash'));
      await tester.pumpAndSettle();
      final calculation = tester
          .widget<AdminCalculateScreen>(find.byType(AdminCalculateScreen));
      expect(calculation.pendingOrderId, 'pending-a');
      expect(calculation.template!.layers.single.material, 'Detail-only OPP');
      expect(calculation.template!.frameProductSizeMm, 145);
      expect(
          reads.where((r) =>
              r.url.path.endsWith('/pending-orders') &&
              r.url.queryParameters['id'] == 'pending-a'),
          hasLength(1));
      await harness.dispose(tester);
    },
        () => MockClient((request) {
              reads.add(request);
              if (request.url.path.endsWith('/pending-orders') &&
                  request.url.queryParameters['id'] == 'pending-a') {
                return detailReply.future;
              }
              return Future.value(http.Response('{}', 404));
            }));
  });

  test(
      'orders summary persistence retains compact wire without graph or template',
      () async {
    final harness = _OrdersHarness()..includePending = true;
    final backend = MemoryProductionSnapshotBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final first = AdminOrderPageCache(persistence: store);
    const request = AdminProductionOrderPageRequest(view: 'orders');
    final page =
        await AdminProductionOrderPage.fromJson(harness.payload(request));
    first.save(
      visit: first.open('ram-scope'),
      apparatus: [
        _catalog.copyWith(
            sourceRevision: 1,
            sourceAasxSha256: 'a' * 64,
            operation: 'print',
            technology: 'gravure')
      ],
      selectedApparatusId: _apparatus,
      windows: [
        AdminOrderPageCacheWindow(request, [page])
      ],
      persistentScope: 'orders-disk-scope',
    );
    await first.flush();
    expect(await store.read(scope: 'orders-disk-scope', key: 'admin-pages-v2'),
        isNotNull);
    first.clear();
    final restarted = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    final restored = await restarted.restore(
        visit: restarted.open('new-process'),
        persistentScope: 'orders-disk-scope');
    expect(restored, isNotNull);
    final saved = restored!.windows.single.pages.single;
    expect(saved.isOrdersList, isTrue);
    expect(saved.snapshot, isNull);
    expect(saved.orderRows['order-a']!.title, 'Alpha package');
    expect(saved.pendingRows['pending-a']!.title, 'Draft package');
    expect(saved.pendingOrders, isEmpty);
    for (final key in [
      'maps',
      'program',
      'calculation_templates',
      'pending_orders',
      'queue_action_controls',
      'stage_states'
    ]) {
      expect(saved.wireValue!.containsKey(key), isFalse,
          reason: 'Full details cannot enter list persistence');
    }
    restarted.clear();
    await harness.events.close();
  });

  testWidgets(
      'orders tab discards legacy full-map cache before compact bootstrap',
      (tester) async {
    final harness = _OrdersHarness();
    final snapshot = harness.fullDetail('legacy-order');
    final page = await AdminProductionOrderPage.fromJson({
      ...encodeProductionMapQueueSnapshot(snapshot),
      'version': 'legacy-full-page',
      'total': 1,
      'offset': 0,
      'next_cursor': null,
      'order_ids': ['legacy-order'],
    });
    expect(page.snapshot!.maps.single.map.nodes, hasLength(3));
    final account = jsonEncode([
      MobileApi.baseUrl,
      AppSession.instance.token,
      '${MobileApi.baseUrl}|${AppSession.instance.profile?.role}|${AppSession.instance.profile?.ref}',
    ]);
    final runtimeScope = jsonEncode([
      account,
      currentSessionReadScope(),
      AppSession.instance.revision.value,
    ]);
    final cache = AdminOrderPageCache.instance;
    cache.save(
      visit: cache.open(runtimeScope),
      apparatus: [_catalog],
      selectedApparatusId: _apparatus,
      windows: [
        AdminOrderPageCacheWindow(
            const AdminProductionOrderPageRequest(view: 'orders'), [page])
      ],
    );
    await harness.mount(tester);
    expect(harness.reads.where((request) => request.view == 'orders'),
        hasLength(1),
        reason: 'Legacy full-map orders must be replaced by compact bootstrap');
    expect(_row('legacy-order'), findsNothing);
    expect(_rowOrder(tester), ['order-a', 'order-b']);
    expect(harness.detailReads, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets(
      'cached orders rows cannot steal sequence long-press hydration scope',
      (tester) async {
    final harness = _OrdersHarness()
      ..includeSequence = true
      ..pendingDetail = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    expect(_row('order-a'), findsOneWidget);
    await tester.tap(find.text('Ketma-ketlik'));
    await tester.pumpAndSettle();
    final sequence =
        find.byKey(const ValueKey('sequence-row-$_apparatus-order-a'));
    expect(sequence, findsOneWidget);
    await tester.longPress(sequence);
    await tester.pump();
    expect(harness.detailReads, [(apparatus: _apparatus, orderId: 'order-a')],
        reason:
            'The active sequence needs scoped authority even with same ID cached in Orders');
    harness.pendingDetail!.complete(harness.fullDetail('order-a'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Shu bosqich:'), findsOneWidget);
    expect(find.text('Butun buyurtma'), findsNothing);
    await harness.dispose(tester);
  });
}
