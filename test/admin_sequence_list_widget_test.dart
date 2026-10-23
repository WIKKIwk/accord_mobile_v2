import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_order_page_cache.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    if (pendingDetail != null) return pendingDetail!.future;
    return fullDetail(wrongDetailOrder ? 'another-order' : orderId);
  }

  AdminApparatusQueueSnapshot fullDetail(String orderId) =>
      AdminApparatusQueueSnapshot(
        epoch: _epoch,
        scope: 'summary-detail-scope',
        revision: 7,
        maps: [
          ProductionMapSaved.fromJson({
            'map': {
              'id': orderId,
              'code': '0101',
              'title': 'Full detail package',
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
          _apparatus: {orderId: 'pending'},
        },
        queuePolicies: const {},
        orderControls: const {},
        queueActionControls: {
          _apparatus: {
            orderId: AdminApparatusQueueOrderActionControl.fromJson({
              ...scanControl(),
              'stage_node_id': 'work',
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
}

Finder _row(String id) => find.byKey(ValueKey('sequence-row-$_apparatus-$id'));

Finder _detailSheet() => find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');

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
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'summary-widget-admin',
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
