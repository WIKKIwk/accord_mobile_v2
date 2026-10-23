import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_models.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/production/worker_queue_warm_store.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'production_snapshot_test_backend.dart';

void main() {
  testWidgets('readOnly worker route adopts prepared rows without a fresh read',
      (tester) async {
    const apparatus = 'apparatus:default:asset-007';
    SharedPreferences.setMockInitialValues({});
    // Disable actual transport in this widget test; the prepared service and
    // production page integration remain enabled under a normal worker token.
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'warm-worker';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'warm-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: [apparatus],
    );
    final map = ProductionMapSaved.fromJson({
      'map': {
        'id': 'zakaz-warm-order',
        'code': 'WARM',
        'title': 'Warm order',
        'product_code': 'P-WARM',
        'nodes': [
          {'id': 'start', 'kind': 'start', 'title': 'Start'},
          {
            'id': 'work',
            'kind': 'apparatus',
            'apparatus_id': apparatus,
            'title': 'Work'
          },
          {'id': 'end', 'kind': 'end', 'title': 'End'},
        ],
        'edges': [
          {'from': 'start', 'to': 'work'},
          {'from': 'work', 'to': 'end'},
        ],
      },
      'program': <String, dynamic>{},
    });
    final live = StreamController<AdminProductionMapLiveMessage>.broadcast();
    var queueReads = 0;
    var catalogReads = 0;
    final warm = WorkerQueueWarmStore(
      limitLoader: (_) async => 10,
      snapshotLoader: (_, __) async {
        queueReads++;
        return AdminProductionMapLiveSnapshot(
          maps: [map],
          epoch: 'warm-server',
          revision: 7,
          scope: 'warm-scope',
          sequences: const {
            apparatus: ['zakaz-warm-order']
          },
          visibleOrderIds: const {
            apparatus: ['zakaz-warm-order']
          },
          queueStates: const {
            apparatus: {'zakaz-warm-order': 'pending'}
          },
          queuePolicies: const {},
          orderControls: const {},
          completedOrders: const [],
          completionRequests: const [],
          completionRequestDecisions: const [],
        );
      },
      apparatusLoader: () async {
        catalogReads++;
        return const [AdminApparatus(id: apparatus, name: 'Warm machine')];
      },
      liveLoader: (_, __, ___) => live.stream,
    );
    WorkerQueueWarmStore.debugOverride = warm;
    addTearDown(() async {
      warm.reset();
      WorkerQueueWarmStore.debugOverride = null;
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
      await live.close();
      await TestModeController.instance.setEnabled(false);
    });
    await warm.start(
        scope: currentSessionReadScope(), preferenceAccount: 'worker');
    expect(queueReads, 1);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const SizedBox.shrink(),
      routes: {
        '/queue': (_) => const AdminProductionMapOrdersScreen(
            workerMode: true, readOnly: true),
      },
    ));
    await tester.pumpAndSettle();
    unawaited(navigator.currentState!.pushNamed('/queue'));
    // First route frame must already contain actual rows, without waiting for
    // preference I/O, another animation frame, or a network response.
    await tester.pump();
    // Navigator measures a newly pushed MaterialPageRoute offstage before
    // starting its transition. Its very first build already has actual rows.
    expect(
        find.byKey(const ValueKey('worker-order-zakaz-warm-order'),
            skipOffstage: false),
        findsOneWidget);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const ValueKey('worker-order-zakaz-warm-order')),
        findsOneWidget);
    expect(queueReads, 1);
    expect(catalogReads, 1);
    expect(live.hasListener, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    warm.reset();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'persisted rows beat an unfinished warm read and cannot be overwritten by it',
      (tester) async {
    const apparatus = 'apparatus:default:asset-007';
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    final originalBase = ServerEndpointStore.instance.baseUrl;
    // Flutter blocks native HTTP in widget tests. A loopback endpoint also
    // makes it explicit that this case cannot contact a real ERP transport.
    await ServerEndpointStore.instance.setBaseUrl('http://127.0.0.1:1');
    AppSession.instance.token = 'slow-warm-worker';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'slow-warm-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: [apparatus],
    );
    final rawApparatus = <String, dynamic>{
      'apparatus_id': apparatus,
      'source_revision': 1,
      'source_aasx_sha256': 'a' * 64,
      'display': {'display_name': 'Disk machine', 'catalog_order': 5},
      'equipment_class_id': 'equipment-class:printing:gravure',
      'physical_asset_id': 'physical-asset:accord:disk-machine',
      'capabilities': {'print': 3},
      'execution_profile': {
        'operation': 'print',
        'technology': 'gravure',
        'color_station_count': 8,
      },
      'lifecycle': {'state': 'active'},
    };
    final catalog = [AdminApparatus.fromJson(rawApparatus)];
    AdminProductionMapLiveSnapshot snapshot(String title, int revision) =>
        AdminProductionMapLiveSnapshot(
          maps: [
            ProductionMapSaved.fromJson({
              'map': {
                'id': 'zakaz-disk-warm',
                'code': 'DISK',
                'title': title,
                'product_code': 'P-DISK',
                'nodes': [
                  {'id': 'start', 'kind': 'start', 'title': 'Start'},
                  {
                    'id': 'work',
                    'kind': 'apparatus',
                    'apparatus_id': apparatus,
                    'title': 'Work'
                  },
                  {'id': 'end', 'kind': 'end', 'title': 'End'},
                ],
                'edges': [
                  {'from': 'start', 'to': 'work'},
                  {'from': 'work', 'to': 'end'},
                ],
              },
              'program': <String, dynamic>{},
            })
          ],
          epoch: 'disk-server',
          revision: revision,
          scope: 'disk-worker-scope',
          sequences: const {
            apparatus: ['zakaz-disk-warm']
          },
          visibleOrderIds: const {
            apparatus: ['zakaz-disk-warm']
          },
          queueStates: const {
            apparatus: {'zakaz-disk-warm': 'pending'}
          },
          queuePolicies: const {},
          orderControls: const {},
          completedOrders: const [],
          completionRequests: const [],
          completionRequestDecisions: const [],
        );
    var checkedDiskEligibility = false;
    final backend = MemoryProductionSnapshotBackend()
      ..beforeRead = () async {
        // The production restore must pass its real non-demo eligibility
        // check. Once disk I/O begins, disable subsequent native transport and
        // image fetches, which Flutter widget tests deliberately do not serve.
        expect(await TestModeController.instance.isEnabled(), isFalse);
        checkedDiskEligibility = true;
        await TestModeController.instance.setEnabled(true);
      };
    final persistence = ProductionSnapshotStore(backend: backend);
    ProductionSnapshotStore.debugOverride = persistence;
    final disk = snapshot('Disk baseline', 7);
    await persistence.write(
        scope: currentSessionReadScope(),
        key: jsonEncode(['canonical-queue-v1', true, false, true, 10, '']),
        value: {
          'schema': 1,
          'snapshot': encodeProductionMapQueueSnapshot(disk),
          'apparatus': [
            for (final item in catalog) encodeCachedApparatus(item)
          ],
        });
    final pending = Completer<AdminApparatusQueueSnapshot>();
    final started = Completer<void>();
    var queueReads = 0;
    final warm = WorkerQueueWarmStore(
      limitLoader: (_) async => 10,
      snapshotLoader: (_, __) {
        queueReads++;
        if (!started.isCompleted) started.complete();
        return pending.future;
      },
      apparatusLoader: () async => catalog,
      liveLoader: (_, __, ___) => throw StateError('The page owns live now'),
    );
    WorkerQueueWarmStore.debugOverride = warm;
    addTearDown(() async {
      warm.reset();
      if (!pending.isCompleted) {
        pending.complete(snapshot('Late warm result', 8));
      }
      WorkerQueueWarmStore.debugOverride = null;
      ProductionSnapshotStore.debugOverride = null;
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
      await ServerEndpointStore.instance.setBaseUrl(originalBase);
      await TestModeController.instance.setEnabled(false);
    });
    final warming = warm.start(
        scope: currentSessionReadScope(), preferenceAccount: 'worker');
    await started.future;
    expect(pending.isCompleted, isFalse);
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AdminProductionMapOrdersScreen(workerMode: true, readOnly: true),
    ));
    for (var turn = 0; turn < 8; turn++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byKey(const ValueKey('worker-order-zakaz-disk-warm')),
        findsOneWidget);
    expect(find.text('Disk baseline'), findsOneWidget);
    expect(pending.isCompleted, isFalse,
        reason: 'Usable disk rows must not wait behind the warm HTTP future');
    expect(queueReads, 1);
    expect(checkedDiskEligibility, isTrue);
    pending.complete(snapshot('Late warm result', 8));
    await warming;
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Disk baseline'), findsOneWidget);
    expect(find.text('Late warm result'), findsNothing,
        reason: 'A detached warm read cannot replace the page-owned baseline');
    expect(queueReads, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    warm.reset();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
