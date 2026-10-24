import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_warm_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = [
  AdminApparatus(id: 'cut', name: 'Cut', operation: 'cut'),
  AdminApparatus(id: 'print-a', name: 'Print A', operation: 'print'),
  AdminApparatus(id: 'print-b', name: 'Print B', operation: 'print'),
];
const _orders = AdminProductionOrderPageRequest(view: 'orders');
const _closed = AdminProductionOrderPageRequest(view: 'closed');
const _audit = AdminProductionOrderPageRequest(view: 'audit');

String _key(AdminProductionOrderPageRequest request) =>
    '${request.view}:${request.apparatus}:${request.target}';

AdminProductionOrderPage _page(AdminProductionOrderPageRequest request,
        {int revision = 1, String epoch = 'server'}) =>
    AdminProductionOrderPage(
      version: '${_key(request)}-$revision',
      total: 0,
      offset: 0,
      epoch: epoch,
      revision: revision,
      // Closed and Audit intentionally do not have a response read scope.
      scope: request.view == 'orders' ? 'orders-scope' : '',
      projection: request.view == 'orders' ? adminOrdersListProjection : '',
      wireValue: {
        if (request.view == 'orders') 'projection': adminOrdersListProjection,
      },
    );

Future<void> _settle() async {
  for (var i = 0; i < 16; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Harness {
  _Harness({
    AdminProductionOrderPageLoader? load,
    List<AdminApparatus> catalog = _catalog,
    String Function()? scopeReader,
  }) {
    store = AdminSequenceWarmStore(
      apparatusLoader: () async => catalog,
      selectedApparatusLoader: (_) async => 'print-a',
      pageLoader: (request) {
        requests.add(request);
        return load == null ? Future.value(_page(request)) : load(request);
      },
      liveLoader: (_) => const Stream.empty(),
      reconnectDelay: (_) => const Duration(hours: 1),
      readRetryDelay: Duration.zero,
      scopeReader: scopeReader,
    );
  }

  late final AdminSequenceWarmStore store;
  final requests = <AdminProductionOrderPageRequest>[];

  Future<void> start({String scope = 'scope'}) async {
    store.configure(scope: scope, foreground: true);
    await store.prepare(scope);
    await _settle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all first pages warm in tab order, with preferred printer Move pair',
      () async {
    final harness = _Harness();
    addTearDown(harness.store.dispose);
    var notifications = 0;
    harness.store.pagesChanges.addListener(() => notifications++);
    await harness.start();
    expect(harness.requests.map(_key), [
      'sequence:print-a:',
      'orders::',
      'move:print-a:print-b',
      'move:print-b:print-a',
      'closed::',
      'audit::',
    ]);
    expect(harness.store.peekPage('scope', _closed), isNotNull);
    expect(harness.store.peekPage('scope', _audit), isNotNull);
    expect(harness.store.peekOrders('scope'), isNotNull);
    expect(identical(harness.store.pagesChanges, harness.store.ordersChanges),
        isTrue);
    expect(notifications, 7); // Scope clear, catalog, and five pages.
    for (final request in harness.requests) {
      expect(request.cursor, isNull);
      expect(request.ifVersion, isNull);
      expect(request.search, isEmpty);
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(harness.requests, hasLength(6));
  });

  test('Move default falls back to another catalog apparatus with one printer',
      () async {
    final harness = _Harness(catalog: _catalog.take(2).toList());
    addTearDown(harness.store.dispose);
    await harness.start();
    expect(harness.requests.where((r) => r.view == 'move').map(_key),
        ['move:print-a:cut', 'move:cut:print-a']);
  });

  test('Audit foreground bypasses sequence and joins one identical future',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final audit = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(load: (request) {
      if (request.view == 'sequence') return sequence.future;
      if (request.view == 'audit') return audit.future;
      return Future.value(_page(request));
    });
    addTearDown(harness.store.dispose);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    final first = harness.store.preparePage('scope', _audit);
    expect(
        identical(first, harness.store.preparePage('scope', _audit)), isTrue);
    expect(harness.requests.map((r) => r.view), ['sequence', 'audit']);
    expect(sequence.isCompleted, isFalse);
    audit.complete(_page(_audit));
    expect(await first, isNotNull);
    sequence.complete(_page(const AdminProductionOrderPageRequest(
        view: 'sequence', apparatus: 'print-a')));
    await harness.store.prepare('scope');
    await _settle();
    expect(harness.requests.map((r) => r.view),
        ['sequence', 'audit', 'orders', 'move', 'move', 'closed']);
  });

  test(
      'finished Audit unlocks remaining tabs even while Sequence stays pending',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final audit = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(load: (request) {
      if (request.view == 'sequence') return sequence.future;
      if (request.view == 'audit') return audit.future;
      return Future.value(_page(request));
    });
    addTearDown(harness.store.dispose);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.store.peekApparatus('scope'), _catalog);
    expect(harness.store.peek('scope'), isNull);
    final pending = harness.store.preparePage('scope', _audit);
    audit.complete(_page(_audit));
    await pending;
    await _settle();
    expect(sequence.isCompleted, isFalse);
    expect(harness.requests.map((r) => r.view),
        ['sequence', 'audit', 'orders', 'move', 'move', 'closed']);
    expect(harness.store.peekPage('scope', _closed), isNotNull);
    sequence.complete(_page(const AdminProductionOrderPageRequest(
        view: 'sequence', apparatus: 'print-a')));
    await harness.store.prepare('scope');
    await _settle();
    expect(harness.requests, hasLength(6));
  });

  test('priority completion releases remaining warming beside blocked Orders',
      () async {
    final orders = Completer<AdminProductionOrderPage?>();
    final audit = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(load: (request) {
      if (request.view == 'orders') return orders.future;
      if (request.view == 'audit') return audit.future;
      return Future.value(_page(request));
    });
    addTearDown(harness.store.dispose);
    await harness.start();
    expect(harness.requests.map((r) => r.view), ['sequence', 'orders']);
    final pendingAudit = harness.store.preparePage('scope', _audit);
    await _settle();
    expect(
        harness.requests.map((r) => r.view), ['sequence', 'orders', 'audit']);
    audit.complete(_page(_audit));
    await pendingAudit;
    await _settle();
    expect(orders.isCompleted, isFalse);
    expect(harness.requests.map((r) => r.view),
        ['sequence', 'orders', 'audit', 'move', 'move', 'closed']);
    expect(harness.store.peekPage('scope', _closed), isNotNull);
    orders.complete(_page(_orders));
    await _settle();
    expect(harness.requests, hasLength(6));
    expect(harness.store.peekOrders('scope'), isNotNull);
  });

  test('foreground demand holds the next low priority read until it completes',
      () async {
    final orders = Completer<AdminProductionOrderPage?>();
    final audit = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(load: (request) {
      if (request.view == 'orders') return orders.future;
      if (request.view == 'audit') return audit.future;
      return Future.value(_page(request));
    });
    addTearDown(harness.store.dispose);
    await harness.start();
    final pendingAudit = harness.store.preparePage('scope', _audit);
    orders.complete(_page(_orders));
    await _settle();
    expect(
        harness.requests.map((r) => r.view), ['sequence', 'orders', 'audit']);
    audit.complete(_page(_audit));
    await pendingAudit;
    await _settle();
    expect(harness.requests.map((r) => r.view),
        ['sequence', 'orders', 'audit', 'move', 'move', 'closed']);
  });

  test('one exhausted page fails independently and never polls', () async {
    var failOrders = true;
    final harness = _Harness(load: (request) async {
      if (request.view == 'orders' && failOrders) {
        throw TimeoutException('offline');
      }
      return _page(request);
    });
    addTearDown(harness.store.dispose);
    await harness.start();
    expect(harness.requests.map((r) => r.view), [
      'sequence',
      'orders',
      'orders',
      'orders',
      'move',
      'move',
      'closed',
      'audit'
    ]);
    expect(harness.store.peekOrders('scope'), isNull);
    expect(harness.store.peekPage('scope', _audit), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(harness.requests, hasLength(8));
    failOrders = false;
    expect(await harness.store.prepareOrders('scope'), isNotNull);
    expect(harness.requests, hasLength(9));
  });

  test('pause freezes next reads while preserving same-account pending future',
      () async {
    final orders = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
        load: (request) => request.view == 'orders'
            ? orders.future
            : Future.value(_page(request)));
    addTearDown(harness.store.dispose);
    await harness.start();
    final pending = harness.store.prepareOrders('scope');
    harness.store.configure(scope: 'scope', foreground: false);
    expect(identical(pending, harness.store.prepareOrders('scope')), isTrue);
    orders.complete(_page(_orders));
    expect(await pending, isNotNull);
    await _settle();
    expect(harness.requests.map((r) => r.view), ['sequence', 'orders']);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.requests.map((r) => r.view),
        ['sequence', 'orders', 'move', 'move', 'closed', 'audit']);
  });

  test('resume retries failed entries without duplicating ready pages',
      () async {
    var failAudit = true;
    final harness = _Harness(load: (request) async {
      if (request.view == 'audit' && failAudit) throw StateError('offline');
      return _page(request);
    });
    addTearDown(harness.store.dispose);
    await harness.start();
    expect(harness.store.peekPage('scope', _audit), isNull);
    failAudit = false;
    harness.store.configure(scope: 'scope', foreground: false);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.requests.map((r) => r.view),
        ['sequence', 'orders', 'move', 'move', 'closed', 'audit', 'audit']);
    expect(harness.store.peekPage('scope', _audit), isNotNull);
  });

  test('account transition notifications never expose the previous catalog',
      () async {
    final harness = _Harness();
    addTearDown(harness.store.dispose);
    await harness.start(scope: 'old');
    expect(harness.store.peekApparatus('old'), _catalog);
    final observed = <List<AdminApparatus>?>[];
    harness.store.pagesChanges.addListener(() {
      observed.add(harness.store.peekApparatus('new'));
    });
    harness.store.configure(scope: 'new', foreground: false);
    expect(observed, isNotEmpty);
    expect(observed, everyElement(isNull));
    expect(harness.store.peekApparatus('old'), isNull);
    expect(harness.store.peekApparatus('new'), isNull);
  });

  test('logout cancels old foreground callers and rejects all late results',
      () async {
    final oldAudit = Completer<AdminProductionOrderPage?>();
    var auditCalls = 0;
    final harness = _Harness(load: (request) {
      if (request.view == 'audit' && ++auditCalls == 1) return oldAudit.future;
      return Future.value(_page(request, revision: 9));
    });
    addTearDown(harness.store.dispose);
    await harness.start(scope: 'old');
    final pending = harness.store.preparePage('old', _audit);
    harness.store.configure(scope: null, foreground: false);
    expect(await pending, isNull);
    await harness.start(scope: 'new');
    expect(harness.store.peekPage('new', _audit)!.revision, 9);
    oldAudit.completeError(StateError('late old transport'));
    await _settle();
    expect(harness.store.peekPage('old', _audit), isNull);
    expect(harness.store.peekPage('new', _audit)!.revision, 9);
  });

  test(
      'authorization failure clears every page and blocks remaining warm reads',
      () async {
    var denied = true;
    final harness = _Harness(load: (request) async {
      if (request.view == 'closed' && denied) {
        throw const MobileApiException(
            code: 'forbidden', message: 'denied', statusCode: 403);
      }
      return _page(request);
    });
    addTearDown(harness.store.dispose);
    await harness.start();
    expect(harness.requests.last.view, 'closed');
    expect(harness.requests.where((r) => r.view == 'audit'), isEmpty);
    expect(harness.store.peekOrders('scope'), isNull);
    expect(harness.store.peek('scope'), isNull);
    expect(await harness.store.preparePage('scope', _audit), isNull);
    harness.store.configure(scope: 'scope', foreground: false);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    expect(harness.requests.last.view, 'closed');
    denied = false;
    await harness.start(scope: 'new');
    expect(harness.store.peekPage('new', _audit), isNotNull);
  });

  test('generic handbacks preserve revision and retired-epoch protections',
      () async {
    final closed = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
        load: (request) => request.view == 'closed'
            ? closed.future
            : Future.value(_page(request)));
    addTearDown(harness.store.dispose);
    await harness.start();
    final pending = harness.store.preparePage('scope', _closed);
    harness.store.rememberPage('scope', _closed, _page(_closed, revision: 7));
    closed.completeError(StateError('obsolete failure'));
    expect((await pending)!.revision, 7);
    harness.store.rememberPage('scope', _closed, _page(_closed, revision: 2));
    expect(harness.store.peekPage('scope', _closed)!.revision, 7);
    harness.store
        .rememberPage('scope', _closed, _page(_closed, epoch: 'new-server'));
    harness.store.rememberPage('scope', _closed, _page(_closed, revision: 99));
    expect(harness.store.peekPage('scope', _closed)!.epoch, 'new-server');
  });

  test('late catalog adds Move pages after an early foreground warm chain',
      () async {
    final catalog = Completer<List<AdminApparatus>>();
    final sequence = Completer<AdminProductionOrderPage?>();
    final requests = <AdminProductionOrderPageRequest>[];
    final store = AdminSequenceWarmStore(
      apparatusLoader: () => catalog.future,
      selectedApparatusLoader: (_) async => 'print-a',
      pageLoader: (request) {
        requests.add(request);
        return request.view == 'sequence'
            ? sequence.future
            : Future.value(_page(request));
      },
      liveLoader: (_) => const Stream.empty(),
      reconnectDelay: (_) => const Duration(hours: 1),
    );
    addTearDown(store.dispose);
    store.configure(scope: 'scope', foreground: true);
    await store.preparePage('scope', _audit);
    await _settle();
    expect(
        requests.map((r) => r.view), ['audit', 'sequence', 'orders', 'closed']);
    expect(store.peekApparatus('scope'), isNull);
    catalog.complete(_catalog);
    await _settle();
    expect(sequence.isCompleted, isFalse);
    expect(requests.where((r) => r.view == 'move').map(_key),
        ['move:print-a:print-b', 'move:print-b:print-a']);
    expect(store.peekApparatus('scope'), _catalog);
  });

  test('custom Move pair is prepared in both configured directions', () async {
    final orders = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
        load: (request) => request.view == 'orders'
            ? orders.future
            : Future.value(_page(request)));
    addTearDown(harness.store.dispose);
    await harness.start();
    harness.store.configureMoveRequests('scope', const [
      AdminProductionOrderPageRequest(
          view: 'move', apparatus: 'cut', target: 'print-b'),
      AdminProductionOrderPageRequest(
          view: 'move', apparatus: 'print-b', target: 'cut'),
    ]);
    orders.complete(_page(_orders));
    await _settle();
    expect(harness.requests.where((r) => r.view == 'move').map(_key),
        ['move:cut:print-b', 'move:print-b:cut']);
  });

  test('noncanonical requests are excluded and RAM page keys remain bounded',
      () async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final harness = _Harness(
        load: (request) => request.view == 'sequence'
            ? sequence.future
            : Future.value(_page(request)));
    addTearDown(harness.store.dispose);
    harness.store.configure(scope: 'scope', foreground: true);
    await _settle();
    for (final request in const [
      AdminProductionOrderPageRequest(view: 'orders', search: 'needle'),
      AdminProductionOrderPageRequest(view: 'closed', cursor: 'next'),
      AdminProductionOrderPageRequest(view: 'audit', ifVersion: 'old'),
      AdminProductionOrderPageRequest(
          view: 'move', apparatus: 'a', target: 'a'),
      AdminProductionOrderPageRequest(view: 'unknown'),
    ]) {
      expect(await harness.store.preparePage('scope', request), isNull);
    }
    expect(harness.requests, hasLength(1));
    for (var i = 0; i < 13; i++) {
      await harness.store.preparePage(
          'scope',
          AdminProductionOrderPageRequest(
              view: 'move', apparatus: 'a$i', target: 'b$i'));
    }
    expect(
        harness.store.peekPage(
            'scope',
            const AdminProductionOrderPageRequest(
                view: 'move', apparatus: 'a0', target: 'b0')),
        isNull);
    expect(
        harness.store.peekPage(
            'scope',
            const AdminProductionOrderPageRequest(
                view: 'move', apparatus: 'a12', target: 'b12')),
        isNotNull);
  });
}
