import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/production/production_queue_warm_runtime.dart';
import 'package:accord_mobile_v2/src/core/production/worker_queue_warm_store.dart';
import 'package:accord_mobile_v2/src/core/production/supply_tasks_warm_store.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_warm_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _selectedApparatus = 'apparatus:default:bosma_7';

AdminProductionOrderPage _runtimeSequencePage() =>
    const AdminProductionOrderPage(
      version: 'sequence-v1',
      epoch: 'server',
      revision: 1,
      scope: 'sequence-scope',
      projection: adminSequenceListProjection,
      total: 0,
      offset: 0,
      wireValue: {
        'projection': adminSequenceListProjection,
        'version': 'sequence-v1',
        'epoch': 'server',
        'rev': 1,
        'scope': 'sequence-scope',
        'offset': 0,
        'order_ids': [],
        'rows': {}
      },
    );

Future<AdminProductionOrderPage> _runtimeOrdersPage() =>
    AdminProductionOrderPage.fromJson({
      'projection': adminOrdersListProjection,
      'version': 'orders-v1',
      'epoch': 'server',
      'rev': 1,
      'scope': 'orders-scope',
      'offset': 0,
      'total': 1,
      'next_cursor': null,
      'order_ids': ['order-1'],
      'pending_ids': [],
      'pending_rows': {},
      'rows': {
        'order-1': {
          'id': 'order-1',
          'code': '1',
          'title': 'Product',
          'customer_name': 'Customer',
          'image_id': 'metadata-only',
          'display_state': 'pending',
          'watermarks': []
        }
      },
    });

Future<AdminProductionOrderPage> _runtimeOtherPage(
        AdminProductionOrderPageRequest request) =>
    AdminProductionOrderPage.fromJson({
      'version': '${request.view}-v1',
      'epoch': 'server',
      'rev': 1,
      'offset': 0,
      'total': 0,
      'next_cursor': null,
      if (request.view == 'move') ...{
        'order_ids': [],
        'maps': [],
      },
      if (request.view == 'closed') 'closed_orders': [],
      if (request.view == 'audit')
        'workflow_audit': {
          'ok': true,
          'checked_order_count': 0,
          'checked_batch_count': 0,
          'checked_session_count': 0,
          'total_violations': 0,
          'violations': [],
        },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdminSequenceWarmStore admin;
  late WorkerQueueWarmStore worker;
  late List<StreamController<AdminProductionMapLiveMessage>> streams;
  late int adminReads;
  late int workerReads;

  void session(UserRole role, List<String> capabilities,
      {String ref = 'warm-runtime'}) {
    AppSession.instance.token = 'warm-runtime-test';
    AppSession.instance.profile = SessionProfile(
      role: role,
      ref: ref,
      displayName: 'Runtime',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: capabilities,
    );
    AppSession.instance.revision.value++;
  }

  Stream<AdminProductionMapLiveMessage> live() {
    final controller = StreamController<AdminProductionMapLiveMessage>();
    streams.add(controller);
    return controller.stream;
  }

  setUp(() {
    adminReads = 0;
    workerReads = 0;
    streams = [];
    admin = AdminSequenceWarmStore(
      apparatusLoader: () async => const [AdminApparatus(id: 'a', name: 'A')],
      selectedApparatusLoader: (_) async => 'a',
      pageLoader: (request) async {
        adminReads++;
        if (request.view == 'orders') {
          return AdminProductionOrderPage.fromJson({
            'projection': adminOrdersListProjection,
            'version': 'orders-v1',
            'epoch': 'server',
            'rev': 1,
            'scope': 'orders-scope',
            'offset': 0,
            'total': 0,
            'next_cursor': null,
            'order_ids': [],
            'pending_ids': [],
            'pending_rows': {},
            'rows': {},
          });
        }
        return const AdminProductionOrderPage(
          version: 'v1',
          epoch: 'server',
          revision: 1,
          total: 0,
          offset: 0,
          wireValue: {'version': 'v1', 'epoch': 'server', 'rev': 1},
        );
      },
      liveLoader: (_) => live(),
      scopeReader: currentAdminSequenceWarmScope,
    );
    worker = WorkerQueueWarmStore(
      scopeReader: currentSessionReadScope,
      limitLoader: (_) async => 10,
      apparatusLoader: () async => const [AdminApparatus(id: 'a', name: 'A')],
      snapshotLoader: (_, __) async {
        workerReads++;
        return const AdminApparatusQueueSnapshot(
          epoch: 'server',
          revision: 1,
          scope: 'worker',
          sequences: {},
          visibleOrderIds: {},
          queueStates: {},
          queuePolicies: {},
          orderControls: {},
        );
      },
      liveLoader: (_, __, ___) => live(),
    );
    AdminSequenceWarmStore.debugOverride = admin;
    WorkerQueueWarmStore.debugOverride = worker;
  });

  tearDown(() async {
    admin.configure(scope: null, foreground: false);
    worker.reset();
    AdminSequenceWarmStore.debugOverride = null;
    WorkerQueueWarmStore.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await Future.wait(streams.map((stream) => stream.close()));
  });

  testWidgets('home runtime prepares admin queue before route exists',
      (tester) async {
    session(UserRole.admin, ['admin.access']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(adminReads, 4);
    expect(workerReads, 0);
    expect(admin.peek(currentAdminSequenceWarmScope()), isNotNull);
    expect(admin.peekOrders(currentAdminSequenceWarmScope()), isNotNull);
    expect(streams.single.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(streams.single.hasListener, isFalse);
  });

  testWidgets('foreground resume reconnects prepared queue without HTTP',
      (tester) async {
    session(UserRole.admin, ['admin.access']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(streams.single.hasListener, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(streams.length, 2);
    expect(adminReads, 4);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('worker login warms bounded worker queue on home',
      (tester) async {
    session(UserRole.aparatchi, ['apparatus.queue.read']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(workerReads, 1);
    expect(adminReads, 0);
    expect(worker.peek(scope: currentSessionReadScope(), queueLimit: 10),
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('logout cancels warm socket and clears account data',
      (tester) async {
    session(UserRole.admin, ['admin.access']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    final scope = currentAdminSequenceWarmScope();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    AppSession.instance.revision.value++;
    await tester.pump();
    expect(admin.peek(scope), isNull);
    expect(streams.single.hasListener, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('accounts without queue access cause no preload', (tester) async {
    session(UserRole.customer, ['customer.access']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(adminReads, 0);
    expect(workerReads, 0);
    expect(streams, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  test('custom admin capabilities preserve supply role warm classification',
      () {
    for (final role in [UserRole.qolipchi, UserRole.materialTaminotchi]) {
      session(role, [
        'admin.access',
        'production.map.manage',
        'apparatus.queue.read',
        role == UserRole.qolipchi ? 'qolip.manage' : 'raw_material.assign'
      ]);
      expect(supplyTasksRoleKind(),
          role == UserRole.qolipchi ? 'qolip' : 'material');
    }
  });

  testWidgets(
      'foreground home warms selected Sequence then each tab prefix once',
      (tester) async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final orders = Completer<AdminProductionOrderPage?>();
    final requests = <AdminProductionOrderPageRequest>[];
    var catalogReads = 0;
    var preferenceReads = 0;
    admin = AdminSequenceWarmStore(
      apparatusLoader: () async {
        catalogReads++;
        return const [
          AdminApparatus(id: 'apparatus:default:other', name: 'Other'),
          AdminApparatus(id: _selectedApparatus, name: 'Selected')
        ];
      },
      selectedApparatusLoader: (profile) async {
        preferenceReads++;
        expect(profile, 'warm-runtime');
        return _selectedApparatus;
      },
      pageLoader: (request) {
        requests.add(request);
        return switch (request.view) {
          'sequence' => sequence.future,
          'orders' => orders.future,
          _ => _runtimeOtherPage(request),
        };
      },
      liveLoader: (_) => live(),
      scopeReader: currentAdminSequenceWarmScope,
    );
    AdminSequenceWarmStore.debugOverride = admin;
    session(UserRole.admin, ['admin.access']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.view), ['sequence']);
    expect(requests.single.apparatus, _selectedApparatus);
    expect(admin.peekOrders(currentAdminSequenceWarmScope()), isNull);

    sequence.complete(_runtimeSequencePage());
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.view), ['sequence', 'orders']);
    expect(admin.peek(currentAdminSequenceWarmScope())!.selectedApparatusId,
        _selectedApparatus);
    expect(admin.peekOrders(currentAdminSequenceWarmScope()), isNull);
    expect(requests.last.apparatus, isEmpty);
    expect(requests.last.target, isEmpty);
    expect(requests.last.search, isEmpty);
    expect(requests.every((request) => request.cursor == null), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, hasLength(2),
        reason: 'Resume joins the pending Orders read');
    orders.complete(_runtimeOrdersPage());
    await tester.pumpAndSettle();
    final prepared = admin.peekOrders(currentAdminSequenceWarmScope())!;
    expect(prepared.isOrdersList, isTrue);
    expect(prepared.orderRows['order-1']!.imageId, 'metadata-only');
    expect(prepared.snapshot, isNull);
    expect(prepared.calculationTemplates, isEmpty);
    expect(prepared.length, 1);
    expect(find.byType(Image), findsNothing);
    expect(catalogReads, 1);
    expect(preferenceReads, 1);
    expect(workerReads, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(requests.map((request) => request.view),
        ['sequence', 'orders', 'move', 'move', 'closed', 'audit']);
    expect(requests.where((request) => request.view == 'move').map((request) =>
        [request.apparatus, request.target]), [
      ['apparatus:default:other', _selectedApparatus],
      [_selectedApparatus, 'apparatus:default:other'],
    ]);
    expect(requests.every((request) => request.cursor == null), isTrue);
    expect(requests, hasLength(6),
        reason: 'Ready state does not poll list/details');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'runtime defers Orders when Sequence becomes ready while app is paused',
      (tester) async {
    final sequence = Completer<AdminProductionOrderPage?>();
    final requests = <String>[];
    admin = AdminSequenceWarmStore(
      apparatusLoader: () async =>
          const [AdminApparatus(id: _selectedApparatus, name: 'Selected')],
      selectedApparatusLoader: (_) async => _selectedApparatus,
      pageLoader: (request) {
        requests.add(request.view);
        return switch (request.view) {
          'sequence' => sequence.future,
          'orders' => _runtimeOrdersPage(),
          _ => _runtimeOtherPage(request),
        };
      },
      liveLoader: (_) => live(),
      scopeReader: currentAdminSequenceWarmScope,
    );
    AdminSequenceWarmStore.debugOverride = admin;
    session(UserRole.admin, ['admin.access']);
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    sequence.complete(_runtimeSequencePage());
    await tester.pumpAndSettle();
    expect(admin.peek(currentAdminSequenceWarmScope()), isNotNull);
    expect(requests, ['sequence']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(requests, ['sequence', 'orders', 'closed', 'audit']);
    expect(admin.peekOrders(currentAdminSequenceWarmScope()), isNotNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'account switch rejects pending old Sequence and warms only current Orders',
      (tester) async {
    final oldSequence = Completer<AdminProductionOrderPage?>();
    final newSequence = Completer<AdminProductionOrderPage?>();
    final ordersAccounts = <String>[];
    var sequenceReads = 0;
    admin = AdminSequenceWarmStore(
      apparatusLoader: () async =>
          const [AdminApparatus(id: _selectedApparatus, name: 'Selected')],
      selectedApparatusLoader: (_) async => _selectedApparatus,
      pageLoader: (request) {
        if (request.view == 'sequence') {
          return ++sequenceReads == 1 ? oldSequence.future : newSequence.future;
        }
        if (request.view == 'orders') {
          ordersAccounts.add(AppSession.instance.profile!.ref);
          return _runtimeOrdersPage();
        }
        return _runtimeOtherPage(request);
      },
      liveLoader: (_) => live(),
      scopeReader: currentAdminSequenceWarmScope,
    );
    AdminSequenceWarmStore.debugOverride = admin;
    session(UserRole.admin, ['admin.access'], ref: 'old-admin');
    await tester
        .pumpWidget(const ProductionQueueWarmRuntime(child: SizedBox()));
    await tester.pumpAndSettle();
    final oldScope = currentAdminSequenceWarmScope();
    session(UserRole.admin, ['admin.access'], ref: 'new-admin');
    await tester.pumpAndSettle();
    expect(sequenceReads, 2);
    oldSequence.complete(_runtimeSequencePage());
    await tester.pumpAndSettle();
    expect(ordersAccounts, isEmpty);
    expect(admin.peek(oldScope), isNull);
    newSequence.complete(_runtimeSequencePage());
    await tester.pumpAndSettle();
    expect(ordersAccounts, ['new-admin']);
    expect(admin.peekOrders(currentAdminSequenceWarmScope()), isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
}
