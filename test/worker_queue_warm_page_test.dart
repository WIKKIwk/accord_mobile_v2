import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
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
}
