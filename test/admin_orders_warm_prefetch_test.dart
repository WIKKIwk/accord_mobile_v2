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
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_order_page_cache.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_warm_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'production_snapshot_test_backend.dart';

const _apparatus = 'apparatus:default:bosma_7';
const _catalog = AdminApparatus(
  id: _apparatus,
  name: 'Warm sequence machine',
  sourceRevision: 1,
  sourceAasxSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  operation: 'print',
  technology: 'gravure',
);
const _epoch = 'orders-warm-ui-server';
const _secondApparatus = AdminApparatus(
  id: 'apparatus:default:bosma_8',
  name: 'Second warm machine',
  operation: 'print',
  technology: 'gravure',
);

Future<AdminProductionOrderPage> _sequencePage({
  int revision = 7,
  String title = 'Visible sequence item',
  String epoch = _epoch,
}) =>
    AdminProductionOrderPage.fromJson({
      'projection': 'sequence_list_v1',
      'version': 'sequence-v$revision',
      'scope': 'warm-sequence-scope',
      'epoch': epoch,
      'rev': revision,
      'offset': 0,
      'total': 1,
      'next_cursor': null,
      'order_ids': ['sequence-only'],
      'sequence_positions': {'sequence-only': 1},
      'sequence_versions': {_apparatus: 'a' * 64},
      'sequence_revisions': {_apparatus: 5},
      'queue_policies': [
        {
          'apparatus_id': _apparatus,
          'apparatus': 'Warm sequence machine',
          'policy': 'strict_sequence',
          'locked': false,
          'reason': '',
        }
      ],
      'rows': {
        'sequence-only': {
          'id': 'sequence-only',
          'code': '0101',
          'title': title,
          'customer_name': 'Sequence customer',
          'image_id': 'sequence-image',
          'queue_state': 'pending',
          'display_state': 'pending',
          'can_reorder': true,
        },
      },
    });

Future<AdminProductionOrderPage> _ordersPage({
  int revision = 7,
  String title = 'Background order item',
}) =>
    AdminProductionOrderPage.fromJson({
      'projection': 'orders_list_v1',
      'version': 'orders-v$revision',
      'scope': 'warm-orders-scope',
      'epoch': _epoch,
      'rev': revision,
      'offset': 0,
      'total': 40,
      'next_cursor': 'orders-next-20',
      'order_ids': [for (var i = 0; i < 20; i++) 'orders-only-$i'],
      'rows': {
        for (var i = 0; i < 20; i++)
          'orders-only-$i': {
            'id': 'orders-only-$i',
            'code': '${200 + i}',
            'title': '$title $i',
            'customer_name': 'Orders customer',
            'image_id': 'orders-image-$i',
            'display_state': 'pending',
            'watermarks': <Map<String, dynamic>>[],
          },
      },
      'pending_ids': <String>[],
      'pending_rows': <String, dynamic>{},
    });

Future<AdminProductionOrderPage> _otherPage(
  String view, {
  int revision = 7,
  String title = 'Background closed item',
  String epoch = _epoch,
}) =>
    AdminProductionOrderPage.fromJson({
      'version': '$view-v$revision',
      'epoch': epoch,
      'rev': revision,
      'offset': 0,
      'total': view == 'move' ? 0 : 1,
      'next_cursor': null,
      if (view == 'move') ...{
        'order_ids': <String>[],
        'sequences': <String, dynamic>{},
        'visible_order_ids': <String, dynamic>{},
        'queue_states': <String, dynamic>{},
        'queue_action_controls': <String, dynamic>{},
        'queue_policies': <Map<String, dynamic>>[],
        'stage_states': <String, dynamic>{},
        'order_controls': <String, dynamic>{},
        'order_statuses': <String, dynamic>{},
        'frozen_orders_by_apparatus': <String, dynamic>{},
        'order_customers': <String, dynamic>{},
        'maps': <Map<String, dynamic>>[],
      },
      if (view == 'closed')
        'closed_orders': [
          {
            'order_id': 'closed-only',
            'order_number': '0901',
            'title': title,
            'product_code': 'closed-image',
            'history_version': 'closed-history-$revision',
            'logs': <Map<String, dynamic>>[],
            'progress_batches': <Map<String, dynamic>>[],
          },
        ],
      if (view == 'audit')
        'workflow_audit': {
          'ok': false,
          'checked_order_count': 43,
          'checked_batch_count': 51,
          'checked_session_count': 62,
          'total_violations': 1,
          'violations': [
            {
              'code': 'unknown_order_queue_state',
              'order_id': 'audit-priority-order',
              'subject': 'Prepared audit finding',
              'detail': 'Audit loaded independently of other tabs',
            },
          ],
        },
    });

class _WarmUiHarness {
  _WarmUiHarness({this.twoApparatus = false}) {
    store = AdminSequenceWarmStore(
      apparatusLoader: () async => catalog,
      selectedApparatusLoader: (_) async => _apparatus,
      pageLoader: (request) async {
        warmReads.add(request);
        if (request.view == 'sequence') {
          return sequenceReply?.future ?? _sequencePage(revision: revision);
        }
        if (request.view == 'orders') {
          return ordersReply?.future ??
              _ordersPage(revision: revision, title: ordersTitle);
        }
        if (request.view == 'audit' && auditReply != null) {
          return auditReply!.future;
        }
        if (request.view == 'closed' && closedReply != null) {
          return closedReply!.future;
        }
        return _otherPage(request.view, revision: revision);
      },
      liveLoader: (_) {
        final stream =
            StreamController<AdminProductionMapLiveMessage>.broadcast();
        backgroundStreams.add(stream);
        return stream.stream;
      },
      scopeReader: currentAdminSequenceWarmScope,
    );
  }

  late final AdminSequenceWarmStore store;
  final bool twoApparatus;
  List<AdminApparatus> get catalog =>
      [_catalog, if (twoApparatus) _secondApparatus];
  final warmReads = <AdminProductionOrderPageRequest>[];
  final foregroundReads = <AdminProductionOrderPageRequest>[];
  final detailReads = <String>[];
  final imageReads = <String>[];
  final backgroundStreams = <StreamController<AdminProductionMapLiveMessage>>[];
  final events = StreamController<Object>.broadcast();
  Completer<AdminProductionOrderPage?>? sequenceReply;
  Completer<AdminProductionOrderPage?>? ordersReply;
  Completer<AdminProductionOrderPage?>? auditReply;
  Completer<AdminProductionOrderPage?>? closedReply;
  int revision = 7;
  String ordersTitle = 'Background order item';

  String get scope => currentAdminSequenceWarmScope();
  int get warmOrdersReads => warmReads.where((r) => r.view == 'orders').length;
  int get foregroundOrdersReads =>
      foregroundReads.where((r) => r.view == 'orders').length;

  void configure() => store.configure(
        scope: scope,
        profileRef: AppSession.instance.profile?.ref,
        foreground: true,
      );

  Future<void> prepare(WidgetTester tester) async {
    configure();
    expect(await store.prepare(scope), isNotNull);
    await tester.pumpAndSettle();
  }

  Future<AdminProductionOrderPage?> foreground(
      AdminProductionOrderPageRequest request) async {
    foregroundReads.add(request);
    if (request.view == 'orders') {
      return _ordersPage(revision: revision, title: 'Foreground order item');
    }
    if (request.view == 'sequence') return _sequencePage(revision: revision);
    return _otherPage(request.view,
        revision: revision, title: 'Foreground closed item');
  }

  Future<void> mount(WidgetTester tester) async {
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
        apparatusLoader: () async => catalog,
        completionRequestsLoader: () async => [],
        queueSnapshotLoader: () => throw StateError('Full queue may not warm'),
        orderPageLoader: foreground,
        orderDetailLoader: ({required apparatus, required orderId}) async {
          detailReads.add(orderId);
          throw StateError('Details may not warm');
        },
        liveEventsLoader: () => events.stream,
        sequenceWarmStore: store,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> showOrders(WidgetTester tester) async {
    await tester.tap(find.text('Buyurtmalar'));
    await tester.pumpAndSettle();
  }

  Future<TestGesture> revealOrders(WidgetTester tester) async {
    final viewport = tester.getRect(find.byType(TabBarView));
    final gesture = await tester
        .startGesture(Offset(viewport.right - 32, viewport.top + 160));
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(Offset(-viewport.width * .35, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    expect(controller.index, 0,
        reason: 'Keep the first drag before Orders becomes the selected tab');
    expect(controller.animation!.value, greaterThan(0));
    expect(controller.animation!.value, lessThan(.5));
    return gesture;
  }

  void expectRevealedOrder(WidgetTester tester) {
    final row = _order('orders-only-0');
    expect(row, findsOneWidget);
    expect(
        find.descendant(
            of: row, matching: find.textContaining('Background order item 0')),
        findsOneWidget);
    final viewport = tester.getRect(find.byType(TabBarView));
    final bounds = tester.getRect(row);
    expect(bounds.overlaps(viewport), isTrue);
    expect(bounds.left, greaterThan(viewport.center.dx),
        reason:
            'The incoming Orders page is only partly revealed on the right');
    // A touch drag intentionally ignores child hit tests. Verify the paint
    // chain instead, including offstage, opacity and sliver visibility gates.
    RenderObject child = tester.renderObject(row);
    while (child.parent != null) {
      final parent = child.parent!;
      expect(parent.paintsChild(child), isTrue,
          reason: '${parent.runtimeType} must paint the revealed Orders row');
      child = parent;
    }
  }

  Future<void> readyOrders(WidgetTester tester) async {
    final viewport = tester
        .widgetList(find.byWidgetPredicate((widget) =>
            widget.runtimeType.toString() == '_AdminOrderPageViewport'))
        .firstWhere(
            (widget) => (widget as dynamic).window.request.view == 'orders');
    final dynamic window = (viewport as dynamic).window;
    final AdminProductionOrderPage page = window.pages.first;
    events.add(AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_ready',
      'window': window.liveId,
      'epoch': page.epoch,
      'rev': page.revision,
      'version': page.version,
      'resync': false,
    }));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    dismissAdminTopNotice();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    store.dispose();
    await events.close();
    for (final stream in backgroundStreams) {
      if (!stream.isClosed) await stream.close();
    }
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }

  Future<http.Response> httpRead(http.Request request) async {
    if (request.url.path.endsWith('/order-image/view')) {
      imageReads.add(request.url.queryParameters['order_id']!);
    }
    if (request.url.path.endsWith('/closed-order')) {
      detailReads.add(request.url.queryParameters['id']!);
    }
    return http.Response('{}', 404);
  }
}

Finder _order(String id) => find.byKey(ValueKey('opened-order-$id'));

void _session(String name) {
  AppSession.instance.token = 'warm-ui-token-$name';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.admin,
    ref: 'warm-ui-$name',
    displayName: 'Admin',
    legalName: 'Admin',
    phone: '',
    avatarUrl: '',
    capabilities: ['admin.access'],
  );
}

void main() {
  var serial = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AdminOrderPageCache.debugOverride = AdminOrderPageCache();
    ProductionSnapshotStore.debugOverride =
        ProductionSnapshotStore(backend: MemoryProductionSnapshotBackend());
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    _session('account-${++serial}');
  });
  tearDown(() async {
    AdminOrderPageCache.instance.clear();
    AdminOrderPageCache.debugOverride = null;
    ProductionSnapshotStore.debugOverride = null;
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'ready compact Orders warm page is adopted without duplicate HTTP',
      (tester) async {
    final harness = _WarmUiHarness();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      expect(harness.warmReads.map((r) => r.view),
          ['sequence', 'orders', 'closed', 'audit']);
      expect(harness.store.peekOrders(harness.scope)!.isOrdersList, isTrue);
      expect(harness.store.peekOrders(harness.scope)!.snapshot, isNull);
      expect(harness.imageReads, isEmpty);
      await harness.mount(tester);
      expect(harness.foregroundReads, isEmpty);
      expect(find.textContaining('Visible sequence item'), findsWidgets);
      await harness.showOrders(tester);
      expect(_order('orders-only-0'), findsOneWidget);
      expect(find.textContaining('Background order item 0'), findsWidgets);
      expect(harness.warmOrdersReads, 1);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      expect(
          harness.warmReads.every((r) => r.cursor == null && r.search.isEmpty),
          isTrue);
      final reads = harness.warmReads.length + harness.foregroundReads.length;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(harness.warmReads.length + harness.foregroundReads.length, reads,
          reason: 'Background preparation may not become polling');
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('all default tabs prepare once without hidden details or images',
      (tester) async {
    final harness = _WarmUiHarness(twoApparatus: true);
    await http.runWithClient(() async {
      await harness.prepare(tester);
      expect(harness.warmReads.map((request) => request.view),
          ['sequence', 'orders', 'move', 'move', 'closed', 'audit']);
      final moves =
          harness.warmReads.where((request) => request.view == 'move');
      expect(moves.map((request) => [request.apparatus, request.target]), [
        [_apparatus, _secondApparatus.id],
        [_secondApparatus.id, _apparatus],
      ]);
      expect(harness.imageReads, isEmpty);
      expect(harness.detailReads, isEmpty);
      expect(
          harness.warmReads.every(
              (request) => request.cursor == null && request.search.isEmpty),
          isTrue);
      await harness.mount(tester);
      expect(harness.foregroundReads, isEmpty);
      expect(harness.imageReads.where((id) => id != 'sequence-only'), isEmpty);
      expect(harness.detailReads, isEmpty);

      for (final tab in [
        'Ko‘chirish',
        'Yopilgan',
        'Tekshiruv',
        'Buyurtmalar'
      ]) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
      }
      expect(harness.foregroundReads, isEmpty,
          reason: 'Prepared tab baselines must not be downloaded again');
      expect(harness.warmReads, hasLength(6),
          reason: harness.warmReads
              .map((request) =>
                  '${request.view}:${request.apparatus}->${request.target}')
              .join(', '));
      expect(harness.detailReads, isEmpty);
      await harness.readyOrders(tester);
      final reads = harness.warmReads.length + harness.foregroundReads.length;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(harness.warmReads.length + harness.foregroundReads.length, reads);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('early Audit demand bypasses blocked Orders and rest resumes',
      (tester) async {
    final harness = _WarmUiHarness(twoApparatus: true)
      ..ordersReply = Completer<AdminProductionOrderPage?>()
      ..auditReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      expect(harness.warmReads.map((request) => request.view),
          ['sequence', 'orders']);
      await tester.tap(find.text('Tekshiruv'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(harness.warmReads.where((request) => request.view == 'audit'),
          hasLength(1));
      expect(harness.foregroundReads, isEmpty);
      expect(harness.ordersReply!.isCompleted, isFalse,
          reason: 'Selecting Audit must not wait for the older Orders HTTP');
      harness.auditReply!.complete(await _otherPage('audit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('audit-priority-order'), findsOneWidget);
      expect(harness.ordersReply!.isCompleted, isFalse,
          reason: 'Audit must render independently of the blocked Orders read');
      expect(harness.warmReads.where((request) => request.view == 'orders'),
          hasLength(1));
      expect(harness.warmReads.where((request) => request.view == 'audit'),
          hasLength(1));
      expect(harness.warmReads.where((request) => request.view == 'move'),
          hasLength(2));
      expect(harness.warmReads.where((request) => request.view == 'closed'),
          hasLength(1));
      expect(harness.ordersReply!.isCompleted, isFalse,
          reason:
              'Remaining tabs resume after Audit despite the older Orders HTTP');
      harness.ordersReply!.complete(await _ordersPage());
      await tester.pumpAndSettle();
      expect(harness.warmReads, hasLength(6));
      expect(harness.foregroundReads, isEmpty);
      expect(harness.detailReads, isEmpty);
      expect(harness.imageReads.where((id) => id != 'sequence-only'), isEmpty);
      await tester.tap(find.text('Yopilgan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('closed-order-closed-only')),
          findsOneWidget);
      expect(harness.foregroundReads, isEmpty);
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('Audit opens immediately even while initial Sequence is pending',
      (tester) async {
    final harness = _WarmUiHarness(twoApparatus: true)
      ..sequenceReply = Completer<AdminProductionOrderPage?>()
      ..auditReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      harness.configure();
      await harness.mount(tester);
      expect(harness.warmReads.map((request) => request.view), ['sequence']);
      await tester.tap(find.text('Tekshiruv'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(harness.warmReads.where((request) => request.view == 'audit'),
          hasLength(1));
      expect(harness.sequenceReply!.isCompleted, isFalse);
      harness.auditReply!.complete(await _otherPage('audit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('audit-priority-order'), findsOneWidget);
      expect(harness.sequenceReply!.isCompleted, isFalse);
      expect(harness.foregroundReads, isEmpty);
      expect(harness.warmReads.where((request) => request.view == 'orders'),
          hasLength(1));
      expect(harness.warmReads.where((request) => request.view == 'move'),
          hasLength(2));
      expect(harness.warmReads.where((request) => request.view == 'closed'),
          hasLength(1));
      expect(harness.sequenceReply!.isCompleted, isFalse,
          reason: 'The remaining tabs must not wait for initial Sequence HTTP');
      harness.sequenceReply!.complete(await _sequencePage());
      await tester.pumpAndSettle();
      expect(harness.warmReads.where((request) => request.view == 'orders'),
          hasLength(1));
      expect(harness.warmReads.where((request) => request.view == 'move'),
          hasLength(2));
      expect(harness.warmReads.where((request) => request.view == 'closed'),
          hasLength(1));
      expect(harness.warmReads.where((request) => request.view == 'audit'),
          hasLength(1));
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('late old Sequence cannot replace an early Audit server epoch',
      (tester) async {
    final harness = _WarmUiHarness(twoApparatus: true)
      ..sequenceReply = Completer<AdminProductionOrderPage?>()
      ..auditReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      harness.configure();
      await harness.mount(tester);
      await tester.tap(find.text('Tekshiruv'));
      await tester.pump(const Duration(milliseconds: 400));
      harness.auditReply!.complete(
          await _otherPage('audit', epoch: 'new-audit-server', revision: 1));
      await tester.pumpAndSettle();
      expect(find.textContaining('audit-priority-order'), findsOneWidget);
      harness.sequenceReply!.complete(await _sequencePage());
      await tester.pumpAndSettle();
      expect(find.textContaining('audit-priority-order'), findsOneWidget,
          reason: 'An older initial Sequence must not erase the priority tab');
      final viewport = tester
          .widgetList(find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_AdminOrderPageViewport'))
          .firstWhere(
              (widget) => (widget as dynamic).window.request.view == 'audit');
      final dynamic window = (viewport as dynamic).window;
      expect((window.pages.first as AdminProductionOrderPage).epoch,
          'new-audit-server');
      expect(harness.warmReads.where((request) => request.view == 'audit'),
          hasLength(1));
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('early Move demand uses the catalog without waiting for Sequence',
      (tester) async {
    final harness = _WarmUiHarness(twoApparatus: true)
      ..sequenceReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      harness.configure();
      await harness.mount(tester);
      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      final moves =
          harness.warmReads.where((request) => request.view == 'move');
      expect(moves.map((request) => [request.apparatus, request.target]), [
        [_apparatus, _secondApparatus.id],
        [_secondApparatus.id, _apparatus],
      ]);
      expect(harness.sequenceReply!.isCompleted, isFalse);
      expect(harness.foregroundReads, isEmpty);
      final moveViewports = tester
          .widgetList(find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_AdminOrderPageViewport'))
          .where((widget) => (widget as dynamic).window.request.view == 'move');
      expect(moveViewports, hasLength(2));
      expect(
          moveViewports
              .every((widget) => (widget as dynamic).window.loaded as bool),
          isTrue);
      harness.sequenceReply!.complete(await _sequencePage());
      await tester.pumpAndSettle();
      expect(harness.warmReads.where((request) => request.view == 'move'),
          hasLength(2));
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('prepared Closed rows paint before its first swipe settles',
      (tester) async {
    final harness = _WarmUiHarness(twoApparatus: true);
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(TabBarView));
      final gesture = await tester
          .startGesture(Offset(viewport.right - 32, viewport.top + 160));
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(Offset(-viewport.width * .35, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller.index, 2);
      expect(controller.animation!.value, greaterThan(2));
      expect(controller.animation!.value, lessThan(2.5));
      final row = find.byKey(const ValueKey('closed-order-closed-only'));
      expect(row, findsOneWidget);
      final bounds = tester.getRect(row);
      expect(bounds.overlaps(viewport), isTrue);
      expect(bounds.left, greaterThan(viewport.center.dx));
      RenderObject child = tester.renderObject(row);
      while (child.parent != null) {
        final parent = child.parent!;
        expect(parent.paintsChild(child), isTrue);
        child = parent;
      }
      expect(harness.foregroundReads, isEmpty);
      expect(harness.detailReads, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('ready Orders rows paint during the very first partial swipe',
      (tester) async {
    final harness = _WarmUiHarness();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isEmpty);
      final gesture = await harness.revealOrders(tester);
      harness.expectRevealedOrder(tester);
      expect(harness.warmOrdersReads, 1);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('Orders completing while Sequence is active paint on first swipe',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      expect(_order('orders-only-0'), findsNothing);
      harness.ordersReply!.complete(await _ordersPage());
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isEmpty,
          reason: 'Staging the hidden summary must not download its covers');
      final gesture = await harness.revealOrders(tester);
      harness.expectRevealedOrder(tester);
      expect(harness.warmOrdersReads, 1);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('first swipe never reveals unfiltered warm rows under search',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      await tester.enterText(
          find.byType(EditableText).first, 'different query');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      harness.ordersReply!.complete(await _ordersPage());
      await tester.pumpAndSettle();
      final gesture = await harness.revealOrders(tester);
      expect(_order('orders-only-0'), findsNothing);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isEmpty);
      expect(harness.detailReads, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('first swipe never stages obsolete warm rows into a dirty window',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      harness.revision = 8;
      harness.events
          .add(const AdminProductionMapPageChange(epoch: _epoch, revision: 8));
      await tester.pumpAndSettle();
      harness.ordersReply!.complete(await _ordersPage(revision: 7));
      await tester.pumpAndSettle();
      final gesture = await harness.revealOrders(tester);
      expect(_order('orders-only-0'), findsNothing);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await harness.showOrders(tester);
      expect(find.textContaining('Foreground order item 0'), findsWidgets);
      expect(harness.foregroundOrdersReads, 1);
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('first swipe cannot reveal ready Orders from a previous account',
      (tester) async {
    final harness = _WarmUiHarness();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      _session('different-swipe-account');
      AppSession.instance.revision.value++;
      await tester.pumpAndSettle();
      final gesture = await harness.revealOrders(tester);
      expect(_order('orders-only-0'), findsNothing);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isEmpty);
      expect(harness.detailReads, isEmpty);
      await gesture.cancel();
      await tester.pumpAndSettle();
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('early Orders selection joins existing background HTTP',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      expect(harness.warmOrdersReads, 1);
      expect(harness.store.peekOrders(harness.scope), isNull);
      await harness.mount(tester);
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(harness.foregroundOrdersReads, 0,
          reason: 'Foreground demand must join the existing shared future');
      expect(harness.warmOrdersReads, 1);
      expect(_order('orders-only-0'), findsNothing);
      harness.ordersReply!.complete(await _ordersPage());
      await tester.pumpAndSettle();
      expect(_order('orders-only-0'), findsOneWidget);
      expect(harness.warmOrdersReads, 1);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('joined transient Orders prefetch failure uses foreground loader',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(harness.foregroundOrdersReads, 0);
      harness.ordersReply!.completeError(
          http.ClientException('Background Orders transport interrupted'));
      // The warm store has a finite transient retry budget before this
      // independently authorized visible loader takes over.
      await tester.pump();
      for (var frame = 0;
          frame < 30 && harness.foregroundOrdersReads == 0;
          frame++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pumpAndSettle();
      expect(harness.foregroundOrdersReads, 1);
      expect(find.textContaining('Foreground order item 0'), findsWidgets);
      expect(_order('orders-only-0'), findsOneWidget);
      expect(harness.detailReads, isEmpty);
      await harness.readyOrders(tester);
      final reads = harness.warmReads.length + harness.foregroundReads.length;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(harness.warmReads.length + harness.foregroundReads.length, reads);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('joined forbidden Orders prefetch never falls through HTTP',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      await harness.mount(tester);
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pump(const Duration(milliseconds: 400));
      harness.ordersReply!.completeError(const MobileApiException(
          code: 'forbidden', statusCode: 403, message: 'Orders access denied'));
      await tester.pumpAndSettle();
      expect(harness.foregroundOrdersReads, 0);
      expect(_order('orders-only-0'), findsNothing);
      expect(find.text('Orders access denied'), findsOneWidget);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('same-account profile revision rebinds Orders warm preparation',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      final oldScope = harness.scope;
      final oldReply = harness.ordersReply!;
      await harness.mount(tester);
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_order('orders-only-0'), findsNothing);
      harness
        ..ordersReply = null
        ..ordersTitle = 'Current generation order';
      final readScope = currentSessionReadScope();
      AppSession.instance.profile = AppSession.instance.profile!
          .copyWith(displayName: 'Refreshed admin profile');
      AppSession.instance.revision.value++;
      expect(currentSessionReadScope(), readScope);
      expect(harness.scope, isNot(oldScope));
      await tester.pumpAndSettle();
      expect(find.textContaining('Current generation order 0'), findsWidgets,
          reason: 'The obsolete HTTP request must not block the new scope');
      oldReply.complete(await _ordersPage(title: 'Obsolete generation order'));
      await tester.pumpAndSettle();
      expect(harness.store.peekOrders(oldScope), isNull);
      expect(harness.store.peekOrders(harness.scope), isNotNull);
      expect(harness.backgroundStreams.where((stream) => stream.hasListener),
          isEmpty,
          reason:
              'The rebound screen lease retains exclusive socket ownership');
      await harness.showOrders(tester);
      expect(find.textContaining('Current generation order 0'), findsWidgets);
      expect(find.textContaining('Obsolete generation order'), findsNothing);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('mounted Orders preparation cannot rebind across account change',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      final oldReply = harness.ordersReply!;
      await harness.mount(tester);
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pump(const Duration(milliseconds: 400));
      final reads = harness.warmReads.length;
      _session('another-mounted-account');
      AppSession.instance.revision.value++;
      oldReply.complete(await _ordersPage(title: 'Private original account'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Private original account'), findsNothing);
      expect(_order('orders-only-0'), findsNothing);
      expect(harness.warmReads, hasLength(reads));
      expect(harness.foregroundOrdersReads, 0);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('same-account token refresh loads the current Orders window',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      final oldScope = harness.scope;
      final oldReply = harness.ordersReply!;
      await harness.mount(tester);
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pump(const Duration(milliseconds: 400));
      harness
        ..ordersReply = null
        ..ordersTitle = 'Reauthenticated order';
      final readScope = currentSessionReadScope();
      AppSession.instance.token = '${AppSession.instance.token}-renewed';
      AppSession.instance.revision.value++;
      expect(currentSessionReadScope(), readScope);
      await tester.pumpAndSettle();
      expect(find.textContaining('Reauthenticated order 0'), findsWidgets,
          reason: 'The old account-keyed window must not block navigation');
      oldReply.complete(await _ordersPage(title: 'Old token order'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Old token order'), findsNothing);
      expect(harness.store.peekOrders(oldScope), isNull);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.backgroundStreams.where((stream) => stream.hasListener),
          isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('hidden warm Orders rows do not fetch thumbnails or details',
      (tester) async {
    final harness = _WarmUiHarness();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      expect(harness.imageReads, isEmpty,
          reason: 'Both pure background list reads omit image downloads');
      await harness.mount(tester);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isEmpty,
          reason:
              'Prepared Orders rows must remain invisible while Sequence is active');
      expect(harness.imageReads, contains('sequence-only'));
      expect(harness.detailReads, isEmpty);
      await harness.showOrders(tester);
      expect(harness.imageReads.where((id) => id.startsWith('orders-only-')),
          isNotEmpty,
          reason: 'Only visible order covers are lazily requested');
      expect(harness.imageReads.toSet().length, lessThan(21),
          reason: 'Opening Orders must not eagerly download all twenty covers');
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('newer compact Orders cache survives older warm page adoption',
      (tester) async {
    final harness = _WarmUiHarness();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      final account = jsonEncode([
        MobileApi.baseUrl,
        AppSession.instance.token,
        '${MobileApi.baseUrl}|${AppSession.instance.profile?.role}|${AppSession.instance.profile?.ref}',
      ]);
      final runtime = jsonEncode([
        account,
        currentSessionReadScope(),
        AppSession.instance.revision.value,
      ]);
      final cache = AdminOrderPageCache.instance;
      cache.save(
        visit: cache.open(runtime),
        apparatus: [_catalog],
        selectedApparatusId: _apparatus,
        windows: [
          AdminOrderPageCacheWindow(
            const AdminProductionOrderPageRequest(
                view: 'sequence', apparatus: _apparatus),
            [await _sequencePage(revision: 9, title: 'New cached sequence')],
          ),
          AdminOrderPageCacheWindow(
            const AdminProductionOrderPageRequest(view: 'orders'),
            [await _ordersPage(revision: 9, title: 'New cached order')],
          ),
        ],
      );
      await harness.mount(tester);
      await harness.showOrders(tester);
      expect(find.textContaining('New cached order 0'), findsWidgets);
      expect(find.textContaining('Background order item'), findsNothing);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });

  testWidgets('late old-account Orders prefetch cannot appear in a new account',
      (tester) async {
    final harness = _WarmUiHarness()
      ..ordersReply = Completer<AdminProductionOrderPage?>();
    await http.runWithClient(() async {
      await harness.prepare(tester);
      final oldScope = harness.scope;
      final oldReply = harness.ordersReply!;
      expect(harness.warmOrdersReads, 1);
      _session('new-private-account');
      harness
        ..ordersReply = null
        ..revision = 9
        ..ordersTitle = 'New account order';
      await harness.prepare(tester);
      expect(harness.scope, isNot(oldScope));
      oldReply.complete(await _ordersPage(title: 'Private old account order'));
      await tester.pumpAndSettle();
      expect(harness.store.peekOrders(oldScope), isNull);
      expect(
          harness.store
              .peekOrders(harness.scope)!
              .orderRows['orders-only-0']!
              .title,
          'New account order 0');
      await harness.mount(tester);
      await harness.showOrders(tester);
      expect(find.textContaining('New account order 0'), findsWidgets);
      expect(find.textContaining('Private old account'), findsNothing);
      expect(harness.foregroundOrdersReads, 0);
      expect(harness.detailReads, isEmpty);
      await harness.close(tester);
    }, () => MockClient(harness.httpRead));
  });
}
