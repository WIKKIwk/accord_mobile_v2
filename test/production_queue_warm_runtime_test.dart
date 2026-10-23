import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/production/production_queue_warm_runtime.dart';
import 'package:accord_mobile_v2/src/core/production/worker_queue_warm_store.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_warm_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdminSequenceWarmStore admin;
  late WorkerQueueWarmStore worker;
  late List<StreamController<AdminProductionMapLiveMessage>> streams;
  late int adminReads;
  late int workerReads;

  void session(UserRole role, List<String> capabilities) {
    AppSession.instance.token = 'warm-runtime-test';
    AppSession.instance.profile = SessionProfile(
      role: role,
      ref: 'warm-runtime',
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
      pageLoader: (_) async {
        adminReads++;
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
    expect(adminReads, 1);
    expect(workerReads, 0);
    expect(admin.peek(currentAdminSequenceWarmScope()), isNotNull);
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
    expect(adminReads, 1);
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
}
