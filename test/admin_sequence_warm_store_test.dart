import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/production/production_data_revision.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_warm_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _apparatus = [
  AdminApparatus(id: 'a', name: 'Apparatus A'),
  AdminApparatus(id: 'b', name: 'Apparatus B'),
];

Future<AdminProductionOrderPage> _page(
        {int revision = 1, String title = 'Order'}) =>
    AdminProductionOrderPage.fromJson({
      'version': 'v$revision',
      'epoch': 'server',
      'rev': revision,
      'offset': 0,
      'total': 1,
      'next_cursor': null,
      'order_ids': ['o1'],
      'sequence_positions': {'o1': 1},
      'sequences': {},
      'visible_order_ids': {},
      'queue_states': {},
      'queue_action_controls': {},
      'queue_policies': [],
      'stage_states': {},
      'order_controls': {},
      'order_statuses': {},
      'frozen_orders_by_apparatus': {},
      'order_customers': {},
      'maps': [
        {
          'map': ProductionMapDefinition(
              id: 'o1',
              productCode: 'o1',
              title: title,
              nodes: const [],
              edges: const []).toJson(),
          'program': <String, dynamic>{},
        }
      ],
    });

Future<AdminProductionOrderPage> _ordersPage({
  int revision = 1,
  String epoch = 'server',
  String title = 'Orders card',
}) =>
    AdminProductionOrderPage.fromJson({
      'projection': adminOrdersListProjection,
      'version': 'orders-v$revision',
      'epoch': epoch,
      'rev': revision,
      'scope': 'orders-scope',
      'offset': 0,
      'total': 1,
      'next_cursor': null,
      'order_ids': ['o1'],
      'pending_ids': [],
      'pending_rows': {},
      'rows': {
        'o1': {
          'id': 'o1',
          'code': '1',
          'title': title,
          'customer_name': 'Customer',
          'image_id': 'image-id-is-only-metadata',
          'display_state': 'in_progress',
          'watermarks': [],
        },
      },
    });

AdminProductionMapPageWindowMessage _event(String type,
        {int revision = 1, Map<String, dynamic> extra = const {}}) =>
    AdminProductionMapPageWindowMessage.fromJson({
      'type': type,
      'window': AdminSequenceWarmStore.windowId,
      'epoch': 'server',
      'rev': revision,
      'version': 'v$revision',
      'resync': false,
      ...extra,
    });

Future<void> _settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Harness {
  _Harness({
    Future<List<AdminApparatus>> Function()? catalog,
    Future<String?> Function(String?)? selection,
    AdminProductionOrderPageLoader? loadPage,
    AdminProductionOrderPageLoader? loadOrders,
    Duration reconnectDelay = const Duration(milliseconds: 10),
    Duration readRetryDelay = Duration.zero,
    String Function()? scopeReader,
  }) {
    store = AdminSequenceWarmStore(
      apparatusLoader: catalog ?? () async => _apparatus,
      selectedApparatusLoader: selection ?? (_) async => 'a',
      pageLoader: (request) async {
        if (request.view == 'orders') {
          ordersRequests.add(request);
          return loadOrders == null ? _ordersPage() : loadOrders(request);
        }
        if (request.view != 'sequence') {
          otherRequests.add(request);
          return _page();
        }
        requests.add(request);
        return loadPage == null
            ? _page(revision: requests.length)
            : loadPage(request);
      },
      liveLoader: (windows) {
        descriptors.add(windows);
        final controller = StreamController<AdminProductionMapLiveMessage>();
        controllers.add(controller);
        return controller.stream;
      },
      reconnectDelay: (_) => reconnectDelay,
      readRetryDelay: readRetryDelay,
      scopeReader: scopeReader,
    );
  }

  late final AdminSequenceWarmStore store;
  final requests = <AdminProductionOrderPageRequest>[];
  final ordersRequests = <AdminProductionOrderPageRequest>[];
  final otherRequests = <AdminProductionOrderPageRequest>[];
  final descriptors = <List<Map<String, Object?>>>[];
  final controllers = <StreamController<AdminProductionMapLiveMessage>>[];

  Future<AdminSequenceWarmSnapshot> start({String scope = 'scope'}) async {
    store.configure(scope: scope, profileRef: 'admin', foreground: true);
    return (await store.prepare(scope))!;
  }

  Future<void> close() async {
    store.dispose();
    for (final controller in controllers) {
      if (!controller.isClosed) await controller.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'preload starts on session foreground and only reads one sequence prefix',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: false);
    await _settle();
    expect(harness.requests, isEmpty);

    final ready = await harness.start();
    expect(ready.apparatus, _apparatus);
    expect(ready.selectedApparatusId, 'a');
    expect(ready.page.orderIds, ['o1']);
    expect(ready.fresh, isFalse);
    expect(harness.requests, hasLength(1));
    expect(harness.requests.single.view, 'sequence');
    expect(harness.requests.single.apparatus, 'a');
    expect(harness.requests.single.cursor, isNull);
    expect(harness.requests.single.search, isEmpty);
    expect(harness.descriptors.single.single['length'], 20);
    expect(harness.descriptors.single.single['version'], 'v1');
    expect(harness.store.peek('other'), isNull);
  });

  test(
      'concurrent callers share the same load and saved apparatus overlaps catalog',
      () async {
    final catalog = Completer<List<AdminApparatus>>();
    final response = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
      catalog: () => catalog.future,
      selection: (_) async => 'b',
      loadPage: (_) => response.future,
    );
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final first = harness.store.prepare('scope');
    final second = harness.store.prepare('scope');
    expect(identical(first, second), isTrue);
    await _settle();
    // The page request starts while the slower apparatus HTTP read is pending.
    expect(catalog.isCompleted, isFalse);
    expect(harness.requests, hasLength(1));
    expect(harness.requests.single.apparatus, 'b');
    response.complete(await _page());
    catalog.complete(_apparatus);
    expect((await first)!.selectedApparatusId, 'b');
    expect(identical(await first, await second), isTrue);
    expect(harness.requests, hasLength(1));
  });

  test('missing or retired selection falls back to catalog first apparatus',
      () async {
    for (final selection in [null, 'retired']) {
      final harness = _Harness(selection: (_) async => selection);
      addTearDown(harness.close);
      final ready = await harness.start();
      expect(ready.selectedApparatusId, 'a');
      expect(harness.requests.last.apparatus, 'a');
      expect(harness.requests.every((request) => request.view == 'sequence'),
          isTrue);
    }
  });

  test(
      'cold screen acquisition reuses the in-flight preload and owns the socket',
      () async {
    final response = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadPage: (_) => response.future);
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final pending = harness.store.prepare('scope');
    final lease = harness.store.acquire('scope');
    expect(identical(pending, lease.ready), isTrue);
    await _settle();
    expect(harness.requests, hasLength(1));
    response.complete(await _page());
    final ready = (await lease.ready)!;
    expect(ready.page.orderIds, ['o1']);
    expect(harness.controllers, isEmpty);
    lease.release();
    expect(harness.controllers, hasLength(1));
    expect(harness.requests, hasLength(1));
  });

  test(
      'warm route handoff cancels background subscription and returns latest page',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    harness.controllers.single.add(_event('page_window_ready'));
    await _settle();
    expect(harness.store.peek('scope')!.fresh, isTrue);
    final lease = harness.store.acquire('scope');
    expect(harness.controllers.single.hasListener, isFalse);
    expect((await lease.ready)!.fresh, isFalse);
    expect(harness.requests, hasLength(1));

    lease.release(
      apparatus: _apparatus,
      selectedApparatusId: 'b',
      page: await _page(revision: 7),
      confirmed: true,
    );
    expect(harness.descriptors, hasLength(2));
    expect(harness.descriptors.last.single['apparatus'], 'b');
    expect(harness.descriptors.last.single['version'], 'v7');
    expect(harness.store.peek('scope')!.page.revision, 7);
    // A new subscription still needs its own ready/recovery barrier.
    expect(harness.store.peek('scope')!.fresh, isFalse);
    lease.release();
    expect(harness.descriptors, hasLength(2));
  });

  test('delta and checkpoint update the prepared page without HTTP reads',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    final original = await harness.start();
    harness.controllers.single
      ..add(_event('page_window_ready'))
      ..add(_event('page_window_checkpoint', revision: 2, extra: {
        'base_version': 'v1',
        'next_cursors': [null],
      }))
      ..add(_event('page_window_delta', revision: 3, extra: {
        'base_version': 'v2',
        'page_count': 1,
        'changes': [
          {
            'index': 0,
            'ops': [
              {
                'op': 'set',
                'path': ['version'],
                'value': 'v3'
              },
              {
                'op': 'set',
                'path': ['rev'],
                'value': 3
              },
              {
                'op': 'set',
                'path': ['maps', 0, 'map', 'title'],
                'value': 'Changed live',
              },
            ],
          },
        ],
      }));
    await _settle();
    final current = harness.store.peek('scope')!;
    expect(current.fresh, isTrue);
    expect(current.page.revision, 3);
    expect(current.page.snapshot!.maps.single.map.title, 'Changed live');
    expect(original.page.snapshot!.maps.single.map.title, 'Order');
    expect(harness.requests, hasLength(1));
  });

  test('resync performs one bounded read and cannot become an HTTP retry loop',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    harness.controllers.last.add(_event('page_window_resync', revision: 2));
    await _settle();
    expect(harness.requests, hasLength(2));
    expect(harness.descriptors.last.single['version'], 'v2');

    harness.controllers.last.add(_event('page_window_resync', revision: 3));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.requests, hasLength(2));
    expect(harness.descriptors.length, greaterThanOrEqualTo(3));
    expect(harness.store.peek('scope')!.fresh, isFalse);

    harness.controllers.last.add(_event('page_window_ready', revision: 2));
    await _settle();
    expect(harness.store.peek('scope')!.fresh, isTrue);
    harness.controllers.last.add(_event('page_window_resync', revision: 3));
    await _settle();
    expect(harness.requests, hasLength(3));
  });

  test('socket reconnect resumes from latest version without HTTP polling',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    harness.controllers.last
        .add(_event('page_window_checkpoint', revision: 2, extra: {
      'base_version': 'v1',
      'next_cursors': [null]
    }));
    await _settle();
    await harness.controllers.last.close();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.descriptors.last.single['version'], 'v2');
    expect(harness.requests, hasLength(1));
    expect(harness.store.peek('scope')!.fresh, isFalse);
  });

  test(
      'background suspension stops stream and foreground validates existing page',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    harness.controllers.single.add(_event('page_window_ready'));
    await _settle();
    harness.store.configure(scope: 'scope', foreground: false);
    expect(harness.controllers.single.hasListener, isFalse);
    expect(harness.store.peek('scope')!.fresh, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.controllers, hasLength(1));
    expect(harness.requests, hasLength(1));

    harness.store.configure(scope: 'scope', foreground: true);
    expect(harness.controllers, hasLength(2));
    expect(harness.requests, hasLength(1));
  });

  test('changed scope discards stale HTTP results and old screen releases',
      () async {
    final oldResponse = Completer<AdminProductionOrderPage?>();
    var calls = 0;
    final harness = _Harness(loadPage: (_) {
      calls++;
      return calls == 1 ? oldResponse.future : _page(revision: 9);
    });
    addTearDown(harness.close);
    harness.store.configure(scope: 'old', foreground: true);
    final old = harness.store.prepare('old');
    final oldLease = harness.store.acquire('old');
    await _settle();
    harness.store.configure(scope: 'new', foreground: true);
    final current = await harness.store.prepare('new');
    expect(current!.page.revision, 9);
    // Retiring the generation releases the caller before old HTTP finishes.
    expect(await old, isNull);
    oldResponse.complete(await _page());
    expect(harness.store.peek('old'), isNull);
    oldLease.release(
        apparatus: _apparatus,
        selectedApparatusId: 'b',
        page: await _page(revision: 1),
        confirmed: true);
    expect(harness.store.peek('new')!.selectedApparatusId, 'a');
    expect(harness.store.peek('new')!.page.revision, 9);
  });

  test('scope reader fails closed even before runtime coordinator is notified',
      () async {
    var scope = 'old';
    final response = Completer<AdminProductionOrderPage?>();
    final harness =
        _Harness(scopeReader: () => scope, loadPage: (_) => response.future);
    addTearDown(harness.close);
    harness.store.configure(scope: scope, foreground: true);
    final old = harness.store.prepare(scope);
    await _settle();
    scope = 'new';
    response.complete(await _page());
    expect(await old, isNull);
    expect(harness.store.peek('old'), isNull);
    expect(harness.controllers, isEmpty);
  });

  test('new canonical screen page supersedes an older pending preload',
      () async {
    final response = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadPage: (_) => response.future);
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final lease = harness.store.acquire('scope');
    await _settle();
    lease.release(
        apparatus: _apparatus,
        selectedApparatusId: 'b',
        page: await _page(revision: 9),
        confirmed: true);
    response.complete(await _page());
    expect((await lease.ready)!.selectedApparatusId, 'b');
    expect(harness.store.peek('scope')!.page.revision, 9);
    expect(harness.requests, hasLength(1));
  });

  test('older stacked route cannot overwrite latest selected apparatus',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    final older = harness.store.acquire('scope');
    final newer = harness.store.acquire('scope');
    newer.release(
        apparatus: _apparatus,
        selectedApparatusId: 'b',
        page: await _page(revision: 7),
        confirmed: true);
    expect(harness.controllers, hasLength(1));
    older.release(
        apparatus: _apparatus,
        selectedApparatusId: 'a',
        page: await _page(revision: 2),
        confirmed: true);
    expect(harness.store.peek('scope')!.selectedApparatusId, 'b');
    expect(harness.descriptors.last.single['version'], 'v7');
  });

  test('failed preload performs no automatic HTTP retries', () async {
    final harness =
        _Harness(loadPage: (_) async => throw StateError('offline'));
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    expect(await harness.store.prepare('scope'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.requests, hasLength(1));
    expect(harness.store.lastError, isA<StateError>());
    expect(harness.controllers, isEmpty);

    final lease = harness.store.acquire('scope');
    expect(await lease.ready, isNull);
    expect(harness.requests, hasLength(2));
    lease.release();
  });

  test('selection-only handoff drops old page and prepares the new apparatus',
      () async {
    var catalogReads = 0;
    final harness = _Harness(catalog: () async {
      catalogReads++;
      return _apparatus;
    });
    addTearDown(harness.close);
    await harness.start();
    final lease = harness.store.acquire('scope');
    // The preference loader intentionally still returns A, simulating an
    // asynchronous preference write while the route is being disposed.
    lease.release(apparatus: _apparatus, selectedApparatusId: 'b');
    expect(harness.store.peek('scope'), isNull);
    final ready = (await harness.store.prepare('scope'))!;
    expect(ready.selectedApparatusId, 'b');
    expect(harness.requests, hasLength(2));
    expect(harness.requests.last.apparatus, 'b');
    expect(catalogReads, 1);
    expect(harness.descriptors.last.single['apparatus'], 'b');
  });

  test('HTTP authorization denial blocks reads until a new scope is installed',
      () async {
    for (final status in [401, 403]) {
      var denied = true;
      final harness = _Harness(loadPage: (_) async {
        if (denied) {
          throw MobileApiException(
              code: 'denied', message: 'denied', statusCode: status);
        }
        return _page(revision: 9);
      });
      addTearDown(harness.close);
      harness.store.configure(scope: 'old', foreground: true);
      expect(await harness.store.prepare('old'), isNull);
      final lease = harness.store.acquire('old');
      expect(await lease.ready, isNull);
      lease.release();
      harness.store.configure(scope: 'old', foreground: false);
      harness.store.configure(scope: 'old', foreground: true);
      await _settle();
      expect(harness.requests, hasLength(1));
      expect(harness.controllers, isEmpty);
      denied = false;
      harness.store.configure(scope: 'new', foreground: true);
      expect((await harness.store.prepare('new'))!.page.revision, 9);
      expect(harness.requests, hasLength(2));
    }
  });

  test('catalog denial rejects an overlapping successful page read', () async {
    final catalog = Completer<List<AdminApparatus>>();
    final response = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
        catalog: () => catalog.future, loadPage: (_) => response.future);
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final ready = harness.store.prepare('scope');
    await _settle();
    catalog.completeError(const MobileApiException(
        code: 'forbidden', message: 'denied', statusCode: 403));
    response.complete(await _page());
    expect(await ready, isNull);
    expect(harness.store.peek('scope'), isNull);
    expect(harness.controllers, isEmpty);
  });

  test('live authorization denial clears ready rows without reconnecting',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    harness.controllers.single.addError(const MobileApiException(
        code: 'unauthorized', message: 'denied', statusCode: 401));
    await _settle();
    expect(harness.store.peek('scope'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.requests, hasLength(1));
    expect(harness.controllers, hasLength(1));
    expect(harness.controllers.single.hasListener, isFalse);
  });

  test('logout clears ready pages and prevents delayed live publication',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    final controller = harness.controllers.single;
    harness.store.configure(scope: null, foreground: false);
    expect(harness.store.peek('scope'), isNull);
    expect(controller.hasListener, isFalse);
    controller.add(_event('page_window_ready'));
    await _settle();
    expect(harness.store.peek('scope'), isNull);
    expect(harness.requests, hasLength(1));
  });

  test('only accepted live revisions notify production detail listeners',
      () async {
    ProductionDataRevision.notify(epoch: 'before-admin-live-test', revision: 0);
    final baseline = ProductionDataRevision.revision.value;
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    // An HTTP projection has no live barrier and must not announce freshness.
    expect(ProductionDataRevision.revision.value, baseline);
    harness.controllers.last.add(_event('page_window_ready'));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline + 1);

    harness.controllers.last
        .add(_event('page_window_checkpoint', revision: 2, extra: {
      'base_version': 'v1',
      'next_cursors': [null]
    }));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline + 2);

    harness.controllers.last
        .add(_event('page_window_delta', revision: 3, extra: {
      'base_version': 'v2',
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {
              'op': 'set',
              'path': ['version'],
              'value': 'v3'
            },
            {
              'op': 'set',
              'path': ['rev'],
              'value': 3
            },
          ],
        },
      ],
    }));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline + 3);

    // Duplicate and stale frames have already been represented by this page.
    harness.controllers.last
      ..add(_event('page_window_checkpoint', revision: 3))
      ..add(_event('page_window_ready', revision: 2));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline + 3);

    // Missing history invokes one HTTP repair, which is still unvalidated.
    harness.controllers.last.add(_event('page_window_resync', revision: 4));
    await _settle();
    expect(harness.requests, hasLength(2));
    expect(ProductionDataRevision.revision.value, baseline + 3);

    final lease = harness.store.acquire('scope');
    await lease.ready;
    harness.controllers.last.add(_event('page_window_ready', revision: 2));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline + 3);
    lease.release();
  });

  test('invalid and changed-scope live frames never notify detail listeners',
      () async {
    ProductionDataRevision.notify(
        epoch: 'before-invalid-admin-live', revision: 0);
    final baseline = ProductionDataRevision.revision.value;
    var scope = 'scope';
    final harness = _Harness(scopeReader: () => scope);
    addTearDown(harness.close);
    await harness.start();
    harness.controllers.last
        .add(_event('page_window_ready', extra: {'window': 'another-window'}));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline);

    harness.controllers.last
        .add(_event('page_window_checkpoint', revision: 2, extra: {
      'base_version': 'invalid',
      'next_cursors': [null]
    }));
    await _settle();
    expect(harness.requests, hasLength(2));
    expect(ProductionDataRevision.revision.value, baseline);

    scope = 'another-account';
    harness.controllers.last.add(_event('page_window_ready', revision: 2));
    await _settle();
    expect(ProductionDataRevision.revision.value, baseline);
    expect(harness.store.peek('scope'), isNull);
  });

  test('Orders preload follows decoded sequence without waiting for live ready',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final orders = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
      loadPage: (_) => sequence.future,
      loadOrders: (_) => orders.future,
    );
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final ready = harness.store.prepare('scope');
    await _settle();
    expect(harness.requests, hasLength(1));
    expect(harness.ordersRequests, isEmpty);

    sequence.complete(await _page());
    expect((await ready)!.page.orderIds, ['o1']);
    expect(orders.isCompleted, isFalse);
    expect(harness.store.peek('scope'), isNotNull);
    expect(harness.store.peekOrders('scope'), isNull);
    expect(harness.ordersRequests, hasLength(1));
    final request = harness.ordersRequests.single;
    expect(request.apparatus, isEmpty);
    expect(request.target, isEmpty);
    expect(request.search, isEmpty);
    expect(request.cursor, isNull);
    expect(request.ifVersion, isNull);
    // The background stream remains a single selected-sequence window.
    expect(harness.descriptors.single, hasLength(1));
    expect(harness.descriptors.single.single['view'], 'sequence');

    final pending = harness.store.prepareOrders('scope');
    final duplicate = harness.store.prepareOrders('scope');
    expect(identical(pending, duplicate), isTrue);
    orders.complete(await _ordersPage());
    expect((await pending)!.isOrdersList, isTrue);
    expect(harness.store.peekOrders('scope')!.orderRows['o1']!.imageId,
        'image-id-is-only-metadata');
    await _settle();
    expect(harness.ordersRequests, hasLength(1));
  });

  test('Orders chaining continues when a screen acquired the sequence lease',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadPage: (_) => sequence.future);
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final lease = harness.store.acquire('scope');
    await _settle();
    expect(harness.ordersRequests, isEmpty);
    sequence.complete(await _page());
    await lease.ready;
    await _settle();
    expect(harness.controllers, isEmpty);
    expect(harness.ordersRequests, hasLength(1));
    expect(harness.store.peekOrders('scope'), isNotNull);
    lease.release();
    expect(harness.descriptors, hasLength(1));
    expect(harness.descriptors.single.single['view'], 'sequence');
  });

  test(
      'early Orders navigation starts immediately and shares the background read',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final orders = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
        loadPage: (_) => sequence.future, loadOrders: (_) => orders.future);
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final first = harness.store.prepareOrders('scope');
    final second = harness.store.prepareOrders('scope');
    expect(identical(first, second), isTrue);
    expect(harness.ordersRequests, hasLength(1));
    expect(sequence.isCompleted, isFalse);
    orders.complete(await _ordersPage());
    expect((await first)!.orderIds, ['o1']);
    sequence.complete(await _page());
    await harness.store.prepare('scope');
    await _settle();
    expect(harness.ordersRequests, hasLength(1));
  });

  test(
      'background Orders failure is observed and explicit callers still receive it',
      () async {
    final orders = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadOrders: (_) => orders.future);
    addTearDown(harness.close);
    await harness.start();
    final pending = harness.store.prepareOrders('scope');
    final expected = expectLater(pending, throwsA(isA<StateError>()));
    orders.completeError(StateError('Orders offline'));
    await expected;
    await _settle();
    expect(harness.store.peek('scope'), isNotNull);
    expect(harness.store.peekOrders('scope'), isNull);
    harness.store.configure(scope: 'scope', foreground: false);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.ordersRequests, hasLength(2));
  });

  test('nontransient Orders failure does not schedule HTTP retries', () async {
    var fail = true;
    final harness = _Harness(loadOrders: (_) async {
      if (fail) throw StateError('Orders offline');
      return _ordersPage();
    });
    addTearDown(harness.close);
    await harness.start();
    // No explicit observer is attached to this first automatic failure.
    await _settle();
    expect(harness.ordersRequests, hasLength(1));
    expect(harness.store.peek('scope'), isNotNull);
    expect(harness.store.peekOrders('scope'), isNull);
    harness.controllers.last.add(_event('page_window_ready'));
    await _settle();
    expect(harness.ordersRequests, hasLength(1));
    fail = false;
    expect((await harness.store.prepareOrders('scope'))!.isOrdersList, isTrue);
    expect(harness.ordersRequests, hasLength(2));
  });

  test('transient Orders failures recover within the shared bounded read',
      () async {
    for (final failure in [
      TimeoutException('offline'),
      http.ClientException('offline'),
      const MobileApiException(
          code: 'order_page_changed', message: 'changed', statusCode: 409),
      for (final status in [408, 429, 503])
        MobileApiException(
            code: 'temporary', message: 'temporary', statusCode: status),
    ]) {
      var reads = 0;
      final first = Completer<AdminProductionOrderPage?>();
      final harness = _Harness(loadOrders: (_) {
        if (++reads == 1) return first.future;
        return _ordersPage();
      });
      addTearDown(harness.close);
      await harness.start();
      final pending = harness.store.prepareOrders('scope');
      expect(identical(pending, harness.store.prepareOrders('scope')), isTrue);
      first.completeError(failure);
      expect((await pending)!.isOrdersList, isTrue);
      expect(harness.requests, hasLength(1));
      expect(harness.ordersRequests, hasLength(2));
      expect(harness.store.peekOrders('scope'), isNotNull);
      expect(harness.store.lastError, isNull);
      await harness.close();
    }
  });

  test('exhausted Orders retry budget recovers on resume without polling',
      () async {
    var fail = true;
    final harness = _Harness(loadOrders: (_) async {
      if (fail) throw TimeoutException('offline');
      return _ordersPage();
    });
    addTearDown(harness.close);
    await harness.start();
    await expectLater(
        harness.store.prepareOrders('scope'), throwsA(isA<TimeoutException>()));
    expect(harness.ordersRequests, hasLength(3));
    expect(harness.store.peek('scope'), isNotNull);
    expect(harness.store.peekOrders('scope'), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.ordersRequests, hasLength(3));
    fail = false;
    harness.store.configure(scope: 'scope', foreground: false);
    harness.store.configure(scope: 'scope', foreground: true);
    expect((await harness.store.prepareOrders('scope'))!.isOrdersList, isTrue);
    expect(harness.ordersRequests, hasLength(4));
    harness.store.configure(scope: 'scope', foreground: false);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.requests, hasLength(1));
    expect(harness.ordersRequests, hasLength(4));
  });

  test(
      'transient catalog and sequence failures still chain Orders after success',
      () async {
    var catalogs = 0;
    var sequences = 0;
    final harness = _Harness(catalog: () async {
      if (++catalogs == 1) throw http.ClientException('offline');
      return _apparatus;
    }, loadPage: (_) async {
      if (++sequences == 1) {
        throw const MobileApiException(
            code: 'order_page_changed', message: 'changed', statusCode: 409);
      }
      return _page();
    });
    addTearDown(harness.close);
    expect((await harness.start()).selectedApparatusId, 'a');
    await _settle();
    expect(catalogs, 2);
    expect(harness.requests, hasLength(2));
    expect(harness.ordersRequests, hasLength(1));
    expect(harness.store.peekOrders('scope'), isNotNull);
  });

  test('exhausted sequence retries still prepare independent tabs', () async {
    var fail = true;
    final harness = _Harness(loadPage: (_) async {
      if (fail) throw TimeoutException('offline');
      return _page();
    });
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    expect(await harness.store.prepare('scope'), isNull);
    expect(harness.requests, hasLength(3));
    await _settle();
    expect(harness.ordersRequests, hasLength(1));
    expect(harness.otherRequests.map((request) => request.view),
        ['move', 'move', 'closed', 'audit']);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(harness.requests, hasLength(3));
    fail = false;
    harness.store.configure(scope: 'scope', foreground: false);
    harness.store.configure(scope: 'scope', foreground: true);
    expect(await harness.store.prepare('scope'), isNotNull);
    await _settle();
    expect(harness.requests, hasLength(4));
    expect(harness.ordersRequests, hasLength(1));
  });

  test(
      'pause during Orders backoff starts no hidden retries and resumes safely',
      () async {
    var reads = 0;
    final harness = _Harness(
      readRetryDelay: const Duration(milliseconds: 20),
      loadOrders: (_) async {
        if (++reads == 1) throw TimeoutException('offline');
        return _ordersPage();
      },
    );
    addTearDown(harness.close);
    await harness.start();
    final pending = harness.store.prepareOrders('scope');
    await _settle();
    harness.store.configure(scope: 'scope', foreground: false);
    expect(await pending, isNull);
    expect(harness.ordersRequests, hasLength(1));
    harness.store.configure(scope: 'scope', foreground: true);
    expect((await harness.store.prepareOrders('scope'))!.isOrdersList, isTrue);
    expect(harness.ordersRequests, hasLength(2));
  });

  test('scope change cancels old Orders backoff before the next request',
      () async {
    var reads = 0;
    final harness = _Harness(
      readRetryDelay: const Duration(seconds: 30),
      loadOrders: (_) async {
        if (++reads == 1) throw TimeoutException('offline');
        return _ordersPage(revision: 9);
      },
    );
    addTearDown(harness.close);
    await harness.start(scope: 'old');
    final old = harness.store.prepareOrders('old');
    await _settle();
    await harness.start(scope: 'new');
    expect(await old, isNull);
    expect((await harness.store.prepareOrders('new'))!.revision, 9);
    expect(harness.ordersRequests, hasLength(2));
    expect(harness.store.peekOrders('old'), isNull);
  });

  test('pause defers hidden Orders work until a later foreground transition',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadPage: (_) => sequence.future);
    addTearDown(harness.close);
    harness.store.configure(scope: 'scope', foreground: true);
    final pending = harness.store.prepare('scope');
    await _settle();
    harness.store.configure(scope: 'scope', foreground: false);
    sequence.complete(await _page());
    expect(await pending, isNotNull);
    expect(await harness.store.prepareOrders('scope'), isNull);
    expect(harness.ordersRequests, isEmpty);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.ordersRequests, hasLength(1));
    expect(harness.store.peekOrders('scope'), isNotNull);
  });

  test('Orders requests from a previous account cannot populate a new scope',
      () async {
    final oldOrders = Completer<AdminProductionOrderPage?>();
    var calls = 0;
    final harness = _Harness(loadOrders: (_) {
      calls++;
      return calls == 1 ? oldOrders.future : _ordersPage(revision: 9);
    });
    addTearDown(harness.close);
    await harness.start(scope: 'old');
    final old = harness.store.prepareOrders('old');
    await harness.start(scope: 'new');
    expect((await harness.store.prepareOrders('new'))!.revision, 9);
    expect(await old, isNull);
    oldOrders.completeError(StateError('Late old-account transport failure'));
    await _settle();
    expect(harness.store.peekOrders('old'), isNull);
    expect(harness.store.peekOrders('new')!.revision, 9);
    harness.store.configure(scope: null, foreground: false);
    expect(harness.store.peekOrders('new'), isNull);
  });

  test('screen canonical Orders handback supersedes older in-flight responses',
      () async {
    final background = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadOrders: (_) => background.future);
    addTearDown(harness.close);
    await harness.start();
    final pending = harness.store.prepareOrders('scope');
    final canonical = await _ordersPage(revision: 7, title: 'Canonical');
    harness.store.rememberOrders('scope', canonical);
    expect(identical(harness.store.peekOrders('scope'), canonical), isTrue);
    background.complete(await _ordersPage());
    expect(identical(await pending, canonical), isTrue);
    harness.store.rememberOrders('scope', await _ordersPage(revision: 3));
    expect(harness.store.peekOrders('scope')!.revision, 7);
    expect(harness.ordersRequests, hasLength(1));
  });

  test('newer Orders handback also supersedes an obsolete request failure',
      () async {
    final background = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadOrders: (_) => background.future);
    addTearDown(harness.close);
    await harness.start();
    final pending = harness.store.prepareOrders('scope');
    harness.store.rememberOrders('scope', await _ordersPage(revision: 7));
    background.completeError(StateError('Old transport failed'));
    expect((await pending)!.revision, 7);
    expect(harness.store.peek('scope'), isNotNull);
  });

  test('Orders accepts only compact bounded first-page baselines', () async {
    for (final invalid in [
      await _page(),
      const AdminProductionOrderPage(
        projection: adminOrdersListProjection,
        scope: 'orders-scope',
        version: 'orders-v1',
        epoch: 'server',
        revision: 1,
        offset: 20,
        total: 20,
        wireValue: {'projection': adminOrdersListProjection},
      ),
      AdminProductionOrderPage(
        projection: adminOrdersListProjection,
        scope: 'orders-scope',
        version: 'orders-v1',
        epoch: 'server',
        revision: 1,
        offset: 0,
        total: 21,
        orderIds: [for (var i = 0; i < 21; i++) 'o$i'],
        wireValue: const {'projection': adminOrdersListProjection},
      ),
    ]) {
      final sequence = Completer<AdminProductionOrderPage?>();
      final harness = _Harness(
          loadPage: (_) => sequence.future, loadOrders: (_) async => invalid);
      addTearDown(harness.close);
      // Foreground demand runs before sequence can start the automatic read.
      harness.store.configure(scope: 'scope', foreground: true);
      await expectLater(harness.store.prepareOrders('scope'),
          throwsA(isA<MobileApiException>()));
      expect(harness.store.peekOrders('scope'), isNull);
      harness.store.rememberOrders('scope', invalid);
      expect(harness.store.peekOrders('scope'), isNull);
      sequence.complete(await _page());
      await harness.store.prepare('scope');
      // Sequence readiness is a new preparation trigger after this explicit
      // invalid read, but neither invalid response consumes transient retries.
      expect(harness.ordersRequests, hasLength(2));
    }
  });

  test('Orders reset rejects retired epochs and stale scope handbacks',
      () async {
    final harness = _Harness();
    addTearDown(harness.close);
    await harness.start();
    await harness.store.prepareOrders('scope');
    harness.store.rememberOrders(
        'scope', await _ordersPage(revision: 1, epoch: 'new-server'));
    harness.store.rememberOrders('scope', await _ordersPage(revision: 99));
    expect(harness.store.peekOrders('scope')!.epoch, 'new-server');
    harness.store.rememberOrders(
        'other-account', await _ordersPage(revision: 99, epoch: 'other'));
    expect(harness.store.peekOrders('scope')!.epoch, 'new-server');
  });

  test('older route Orders handback cannot replace a newer route server epoch',
      () async {
    final oldResponse = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(loadOrders: (_) => oldResponse.future);
    addTearDown(harness.close);
    await harness.start();
    final pending = harness.store.prepareOrders('scope');
    final older = harness.store.acquire('scope');
    final newer = harness.store.acquire('scope');
    newer.release(ordersPage: await _ordersPage(epoch: 'new-server'));
    older.release(ordersPage: await _ordersPage(revision: 99));
    expect(harness.store.peekOrders('scope')!.epoch, 'new-server');
    oldResponse.complete(await _ordersPage(revision: 100));
    expect((await pending)!.epoch, 'new-server');
    expect(harness.ordersRequests, hasLength(1));
  });
}
