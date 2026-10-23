import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_models.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _apparatus = 'apparatus:default:asset-005';

class _MemoryBackend implements ProductionSnapshotBackend {
  final data = <String, Uint8List>{};
  final times = <String, int>{};
  Completer<void>? readGate;
  Completer<void>? readStarted;

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async {
    final saved = data[id];
    if (readStarted?.isCompleted == false) readStarted!.complete();
    await readGate?.future;
    return saved;
  }

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    data[id] = Uint8List.fromList(bytes);
    times[id] = savedAtMs;
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async => [
        for (final entry in data.entries)
          ProductionSnapshotStoredEntry(
              id: entry.key,
              bytes: entry.value.length,
              savedAtMs: times[entry.key]!),
      ];

  @override
  Future<void> remove(String id) async {
    data.remove(id);
    times.remove(id);
  }

  @override
  Future<void> clear() async {
    data.clear();
    times.clear();
  }
}

ProductionMapSaved _order(String title) => ProductionMapSaved.fromJson({
      'map': {
        'id': 'zakaz-cached',
        'code': 'CACHE-001',
        'title': title,
        'product_code': 'P1',
        'nodes': [
          {'id': 'start', 'kind': 'start', 'title': 'Start'},
          {
            'id': 'work',
            'kind': 'apparatus',
            'apparatus_id': _apparatus,
            'title': 'Work',
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

AdminProductionMapLiveSnapshot _snapshot({
  String title = 'Cached order',
  String epoch = 'server',
  int revision = 7,
  String scope = 'window-10',
}) =>
    AdminProductionMapLiveSnapshot(
      maps: [_order(title)],
      epoch: epoch,
      revision: revision,
      scope: scope,
      sequences: const {
        _apparatus: ['zakaz-cached'],
      },
      sequenceVersions: {_apparatus: 'a' * 64},
      sequenceRevisions: {_apparatus: revision},
      visibleOrderIds: const {
        _apparatus: ['zakaz-cached'],
      },
      queueStates: const {
        _apparatus: {'zakaz-cached': 'pending'},
      },
      queuePolicies: const {},
      orderControls: const {},
      completedOrders: const [],
      completionRequests: const [],
      completionRequestDecisions: const [],
    );

AdminApparatus _catalogEntry() => AdminApparatus.fromJson({
      'apparatus_id': _apparatus,
      'source_revision': 1,
      'source_aasx_sha256': 'a' * 64,
      'display': {'display_name': 'Cache press', 'catalog_order': 5},
      'equipment_class_id': 'equipment-class:printing:gravure',
      'physical_asset_id': 'physical-asset:accord:cache-press',
      'capabilities': {'print': 3},
      'execution_profile': {
        'operation': 'print',
        'technology': 'gravure',
        'color_station_count': 8,
      },
      'lifecycle': {'state': 'active'},
    });

String _cacheKey({
  int limit = 10,
  bool readOnly = true,
  bool workerMode = true,
  bool supplyViewerMode = false,
}) =>
    jsonEncode([
      'canonical-queue-v1',
      workerMode,
      supplyViewerMode,
      readOnly,
      if (workerMode) limit,
      if (workerMode) '',
    ]);

class _Fixture {
  _Fixture({
    this.readOnly = true,
    this.workerMode = true,
    this.supplyViewerMode = false,
  });

  final bool readOnly;
  final bool workerMode;
  final bool supplyViewerMode;
  final backend = _MemoryBackend();
  late final store = ProductionSnapshotStore(backend: backend);
  final events = StreamController<Object>.broadcast();
  final catalog = [_catalogEntry()];
  var reads = 0;
  var liveConnections = 0;
  Future<AdminApparatusQueueSnapshot> Function()? load;
  Future<List<AdminApparatus>> Function()? loadCatalog;

  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'persisted-worker-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Cached Worker',
      legalName: '',
      ref: 'cached-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_apparatus],
    );
    ProductionSnapshotStore.debugOverride = store;
  }

  Future<void> seed({
    String? scope,
    int limit = 10,
    Map<String, dynamic>? value,
  }) =>
      store.write(
        scope: scope ?? currentSessionReadScope(),
        key: _cacheKey(
            limit: limit,
            readOnly: readOnly,
            workerMode: workerMode,
            supplyViewerMode: supplyViewerMode),
        value: value ??
            {
              'schema': 1,
              'snapshot': encodeProductionMapQueueSnapshot(_snapshot()),
              'apparatus': [for (final a in catalog) encodeCachedApparatus(a)],
            },
      );

  Widget screen() => MaterialApp(
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: AdminProductionMapOrdersScreen(
          workerMode: workerMode,
          supplyViewerMode: supplyViewerMode,
          readOnly: readOnly,
          apparatusLoader: () => loadCatalog?.call() ?? Future.value(catalog),
          queueSnapshotLoader: () {
            reads++;
            return load?.call() ??
                Future.error(StateError('Unexpected full snapshot request'));
          },
          liveEventsLoader: () {
            liveConnections++;
            return events.stream;
          },
        ),
      );

  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen());
    if (settle) await pump(tester);
  }

  Future<void> pump(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void ready({
    String epoch = 'server',
    int revision = 7,
    String scope = 'window-10',
    bool resync = false,
  }) =>
      events.add(AdminProductionMapLiveStateReady(
        epoch: epoch,
        revision: revision,
        scope: scope,
        recovered: !resync,
        recoverySupported: true,
        resync: resync,
      ));

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await store.flush();
    await events.close();
    expect(tester.takeException(), isNull);
  }
}

void main() {
  tearDown(() {
    ProductionSnapshotStore.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  for (final diskReturnsFirst in [false, true]) {
    testWidgets(
        'slow cache times out and cannot install late rows '
        '(disk before HTTP=$diskReturnsFirst)', (tester) async {
      final fixture = _Fixture(readOnly: false);
      await fixture.initialize();
      await fixture.seed();
      fixture.backend
        ..readGate = Completer<void>()
        ..readStarted = Completer<void>();
      final fresh = Completer<AdminApparatusQueueSnapshot>();
      fixture.load = () => fresh.future;
      await fixture.open(tester, settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(fixture.backend.readStarted!.isCompleted, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.reads, 0);
      await tester.pump(const Duration(milliseconds: 101));
      expect(fixture.reads, 1,
          reason: 'Optional disk must not block the bounded HTTP path');
      if (diskReturnsFirst) {
        fixture.backend.readGate!.complete();
        await fixture.pump(tester);
        expect(find.text('Cached order'), findsNothing,
            reason: 'An expired restore attempt must not publish a baseline');
        expect(fixture.events.hasListener, isFalse);
      }
      fresh.complete(_snapshot(title: 'Fresh after slow disk', revision: 9));
      await fixture.pump(tester);
      expect(find.text('Fresh after slow disk'), findsWidgets);
      if (!diskReturnsFirst) {
        fixture.backend.readGate!.complete();
        await fixture.pump(tester);
        expect(find.text('Cached order'), findsNothing);
        expect(find.text('Fresh after slow disk'), findsWidgets);
      }
      expect(fixture.reads, 1);
      await tester.tap(find.byKey(const ValueKey('worker-order-zakaz-cached')));
      await fixture.pump(tester);
      final dynamic sheet = tester.widget(find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'));
      final baseline = sheet.queueSnapshotListenable
          as ValueListenable<AdminApparatusQueueSnapshot?>;
      expect(baseline.value?.revision, 9,
          reason: 'Only the fresh server baseline can authorize actions');
      await fixture.close(tester);
    });
  }

  testWidgets(
      'cached rows display before a server event and recovered uses no HTTP',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed();
    await fixture.open(tester);
    expect(find.byKey(const ValueKey('worker-order-zakaz-cached')),
        findsOneWidget);
    expect(fixture.events.hasListener, isTrue);
    expect(fixture.reads, 0);
    fixture.ready();
    await fixture.pump(tester);
    expect(fixture.reads, 0);
    expect(find.byKey(const ValueKey('worker-order-zakaz-cached')),
        findsOneWidget);
    await fixture.close(tester);
  });

  testWidgets(
      'contiguous replay updates cached rows and persists only after ready',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed();
    final scope = currentSessionReadScope();
    await fixture.open(tester);
    fixture.events.add(AdminProductionMapLiveStateDelta(
      epoch: 'server',
      scope: 'window-10',
      baseRevision: 7,
      revision: 8,
      protocol: 'state_delta_v2',
      patch: {
        'maps': {
          'upsert': {
            'zakaz-cached': encodeCachedProductionMap(_order('Updated order'))
          },
          'remove': <String>[],
        },
      },
    ));
    await fixture.pump(tester);
    expect(fixture.reads, 0);
    expect(find.text('Updated order'), findsWidgets);
    expect(
        (await fixture.store.read(scope: scope, key: _cacheKey()))?['snapshot']
            ['rev'],
        7);
    fixture.ready(revision: 8);
    await fixture.pump(tester);
    await fixture.store.flush();
    final saved = await fixture.store.read(scope: scope, key: _cacheKey());
    expect(saved?['snapshot']['rev'], 8);
    expect(saved?['snapshot']['maps'][0]['map']['title'], 'Updated order');
    await fixture.close(tester);
  });

  for (final mode in ['gap', 'epoch', 'scope']) {
    testWidgets('$mode mismatch performs one canonical HTTP reconciliation',
        (tester) async {
      final fixture = _Fixture();
      await fixture.initialize();
      await fixture.seed();
      final fresh = Completer<AdminApparatusQueueSnapshot>();
      fixture.load = () => fresh.future;
      await fixture.open(tester);
      fixture.ready(
        revision: mode == 'epoch' ? 1 : 9,
        epoch: mode == 'epoch' ? 'new-server' : 'server',
        scope: mode == 'scope' ? 'new-window' : 'window-10',
        resync: true,
      );
      await fixture.pump(tester);
      expect(fixture.reads, 1);
      expect(find.byKey(const ValueKey('worker-order-zakaz-cached')),
          findsOneWidget);
      fresh.complete(_snapshot(
        title: 'Fresh $mode order',
        revision: mode == 'epoch' ? 1 : 9,
        epoch: mode == 'epoch' ? 'new-server' : 'server',
        scope: mode == 'scope' ? 'new-window' : 'window-10',
      ));
      await fixture.pump(tester);
      expect(find.text('Fresh $mode order'), findsWidgets);
      expect(fixture.reads, 1);
      await fixture.close(tester);
    });
  }

  testWidgets(
      'invalid application cache schema falls back to a fresh HTTP load',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed(value: {'schema': 99, 'snapshot': <String, dynamic>{}});
    fixture.load = () async => _snapshot(title: 'Fresh after corrupt cache');
    await fixture.open(tester);
    expect(fixture.reads, 1);
    expect(find.text('Fresh after corrupt cache'), findsWidgets);
    await fixture.close(tester);
  });

  testWidgets('other account and queue-window baselines never display',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed(scope: '${currentSessionReadScope()}-other-account');
    await fixture.seed(limit: 20);
    final fresh = Completer<AdminApparatusQueueSnapshot>();
    fixture.load = () => fresh.future;
    await fixture.open(tester);
    expect(fixture.reads, 1);
    expect(
        find.byKey(const ValueKey('worker-order-zakaz-cached')), findsNothing);
    fresh.complete(_snapshot(title: 'Current account order'));
    await fixture.pump(tester);
    expect(find.text('Current account order'), findsWidgets);
    await fixture.close(tester);
  });

  testWidgets(
      'offline recovery retains the cached rows without certifying them',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed();
    fixture.load = () => Future.error(http.ClientException('offline'));
    await fixture.open(tester);
    fixture.events.addError(http.ClientException('offline'));
    await fixture.pump(tester);
    expect(find.byKey(const ValueKey('worker-order-zakaz-cached')),
        findsOneWidget);
    expect(
        (await fixture.store.read(
            scope: currentSessionReadScope(),
            key: _cacheKey()))?['snapshot']['rev'],
        7);
    await fixture.close(tester);
  });

  for (final outcome in ['code', 'name', 'offline', 'forbidden', 'invalid']) {
    testWidgets('search clear uses connection progress: $outcome',
        (tester) async {
      final fixture = _Fixture();
      await fixture.initialize();
      await fixture.seed();
      await fixture.open(tester);
      fixture.ready();
      await fixture.pump(tester);
      final progress = find.byKey(
          const ValueKey('production-orders-connection-progress'));
      final warning = find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString() == '_QueueSnapshotWarningBanner');
      expect(progress, findsNothing);

      fixture.load = () async => _snapshot(scope: 'searched-window');
      await tester.enterText(find.byType(EditableText).first,
          outcome == 'name' ? 'Cached order' : 'CACHE-001');
      await tester.pump(const Duration(milliseconds: 350));
      await fixture.pump(tester);
      fixture.ready(scope: 'searched-window');
      await fixture.pump(tester);
      expect(fixture.reads, 1);

      // The first x closes the keyboard; the second clears the search.
      await tester.tap(find.byTooltip('Yopish'));
      await tester.pump();
      await tester.tap(find.byTooltip('Tozalash'));
      await tester.pump(const Duration(milliseconds: 350));
      await fixture.pump(tester);
      expect(fixture.liveConnections, 3);
      expect(fixture.reads, 1, reason: 'Clearing restores the unfiltered cache');
      expect(find.byKey(const ValueKey('worker-order-zakaz-cached')),
          findsOneWidget);
      expect(warning, findsNothing,
          reason: 'A new search window is waiting for server confirmation');
      expect(progress, findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(progress).value, isNull);

      if (outcome == 'offline') {
        fixture.load = () => Future.error(http.ClientException('offline'));
        final indicator = tester.element(progress);
        for (var attempt = 0; attempt < 3; attempt++) {
          final connections = fixture.liveConnections;
          fixture.events.addError(http.ClientException('offline'));
          await fixture.pump(tester);
          expect(progress, findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
          await fixture.pump(tester);
          expect(fixture.liveConnections, greaterThan(connections),
              reason: 'Retrying must continue automatically during an outage');
          expect(identical(tester.element(progress), indicator), isTrue,
              reason: 'The indicator must stay mounted between retries');
          expect(warning, findsNothing);
          expect(find.text('Cached order'), findsWidgets);
        }
      }

      if (outcome == 'forbidden' || outcome == 'invalid') {
        final connections = fixture.liveConnections;
        fixture.events.addError(MobileApiException(
          code: outcome == 'forbidden'
              ? 'forbidden'
              : 'production_map_snapshot_contract_invalid',
          statusCode: outcome == 'forbidden' ? 403 : null,
          message: 'Confirmed server error',
        ));
        await fixture.pump(tester);
        expect(progress, findsNothing);
        expect(find.text('Confirmed server error'), findsOneWidget);
        await tester.pump(const Duration(seconds: 35));
        expect(fixture.liveConnections, connections,
            reason:
                'Authorization and invalid contracts are not network retries');
      } else {
        fixture.ready();
        await fixture.pump(tester);
        expect(progress, findsNothing);
        expect(warning, findsNothing);
        final connections = fixture.liveConnections;
        await tester.pump(const Duration(seconds: 35));
        expect(fixture.liveConnections, connections,
            reason: 'A confirmed quiet stream must not keep reconnecting');
      }
      await fixture.close(tester);
    });
  }

  testWidgets('late apparatus catalog cannot cross an account switch',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed();
    final lateCatalog = Completer<List<AdminApparatus>>();
    fixture.loadCatalog = () => lateCatalog.future;
    await fixture.open(tester);
    expect(find.text('Cache press'), findsWidgets);
    AppSession.instance.token = 'other-worker-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Other Worker',
      legalName: '',
      ref: 'other-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_apparatus],
    );
    AppSession.instance.revision.value++;
    lateCatalog
        .complete([fixture.catalog.single.copyWith(name: 'Late old press')]);
    await fixture.pump(tester);
    expect(find.text('Late old press'), findsNothing);
    expect(find.text('Cache press'), findsWidgets);
    expect(
        await fixture.store
            .read(scope: currentSessionReadScope(), key: _cacheKey()),
        isNull);
    await fixture.close(tester);
  });

  testWidgets(
      'non-worker baseline with empty server scope restores and recovers',
      (tester) async {
    final fixture = _Fixture(workerMode: false, supplyViewerMode: true);
    await fixture.initialize();
    await fixture.seed(value: {
      'schema': 1,
      'snapshot': encodeProductionMapQueueSnapshot(_snapshot(scope: '')),
      'apparatus': [for (final a in fixture.catalog) encodeCachedApparatus(a)],
    });
    await fixture.open(tester);
    expect(find.text('Cached order'), findsWidgets);
    expect(fixture.reads, 0);
    fixture.ready(scope: '');
    await fixture.pump(tester);
    expect(fixture.reads, 0);
    await fixture.close(tester);
  });

  testWidgets(
      'cached writable screen exposes no action baseline before recovery',
      (tester) async {
    final fixture = _Fixture(readOnly: false);
    await fixture.initialize();
    await fixture.seed();
    await fixture.open(tester);
    await tester.tap(find.byKey(const ValueKey('worker-order-zakaz-cached')));
    await fixture.pump(tester);
    final sheetFinder = find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');
    expect(sheetFinder, findsOneWidget);
    final dynamic sheet = tester.widget(sheetFinder);
    final baseline = sheet.queueSnapshotListenable
        as ValueListenable<AdminApparatusQueueSnapshot?>;
    expect(baseline.value, isNull,
        reason: 'Locally cached rows cannot authorize production actions');
    fixture.ready();
    await fixture.pump(tester);
    expect(baseline.value?.revision, 7);
    fixture.events.addError(http.ClientException('offline'));
    await fixture.pump(tester);
    expect(baseline.value, isNull);
    await fixture.close(tester);
  });

  testWidgets(
      'logout generation blocks delayed saves from the old mounted screen',
      (tester) async {
    final fixture = _Fixture();
    await fixture.initialize();
    await fixture.seed();
    final scope = currentSessionReadScope();
    await fixture.open(tester);
    fixture.ready();
    await tester.pump();
    await fixture.store.clear();
    // The old widget can still be mounted while logout awaits other stores.
    // Even a later valid stream event must not recreate its deleted cache.
    fixture.events.add(const AdminProductionMapLiveStateDelta(
      epoch: 'server',
      scope: 'window-10',
      baseRevision: 7,
      revision: 8,
      protocol: 'state_delta_v2',
      patch: {},
    ));
    await fixture.pump(tester);
    await fixture.close(tester);
    expect(await fixture.store.read(scope: scope, key: _cacheKey()), isNull);
    expect(fixture.backend.data, isEmpty);
  });
}
