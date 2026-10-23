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
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';
import 'production_snapshot_test_backend.dart';

const _station = 'apparatus:default:bosma_7';
const _epoch = 'compact-worker-ui-server';
const _catalog = AdminApparatus(
    id: _station,
    name: 'Compact worker machine',
    operation: 'print',
    technology: 'gravure');

Map<String, dynamic> _row(String id) => {
      'id': id,
      'code': id == 'zakaz-a'
          ? '0101'
          : id == 'zakaz-b'
              ? '0102'
              : '0103',
      'title': id == 'zakaz-a'
          ? 'Alpha package'
          : id == 'zakaz-b'
              ? 'Beta package'
              : 'Completed package',
      'customer_name': 'Worker customer',
      'image_id': 'image-$id',
    };

class _CompactHarness {
  final events = StreamController<Object>.broadcast();
  final details = <({String apparatus, String orderId})>[];
  Completer<AdminApparatusQueueSnapshot>? pending;
  int queueReads = 0;
  int revision = 7;
  int detailRevision = 7;
  String detailEpoch = _epoch;
  String detailTitle = 'Alpha package';
  String detailState = 'pending';
  bool wrongOrder = false;
  bool includeDetailControl = true;
  Object? detailError;
  bool reportPrompt = false;
  bool detailReportRequired = true;
  String detailReportSessionId = 'report-session-one';
  bool includeHistory = true;
  final states = <String, String>{
    'zakaz-a': 'pending',
    'zakaz-b': 'in_progress'
  };
  final queueStates = <String, String>{
    'zakaz-a': 'pending',
    'zakaz-b': 'in_progress'
  };
  List<String> visible = ['zakaz-b', 'zakaz-a'];

  Map<String, dynamic> wire() => {
        'projection': 'worker_list_v1',
        'epoch': _epoch,
        'rev': revision,
        'scope': 'compact-worker-10',
        'sequences': {_station: visible},
        'visible_order_ids': {_station: visible},
        'sequence_versions': {_station: 'a' * 64},
        'sequence_revisions': {_station: 5},
        'sequence_positions_by_apparatus': {
          _station: {
            for (final id in visible) id: id == 'zakaz-a' ? 8 : 3,
          }
        },
        'queue_policies': [
          {
            'apparatus_id': _station,
            'apparatus': 'Compact worker machine',
            'policy': 'strict_sequence',
            'locked': false,
            'reason': '',
          }
        ],
        'queue_states': {
          _station: {for (final id in visible) id: queueStates[id] ?? 'pending'}
        },
        'order_controls': <String, dynamic>{},
        'worker_list_rows': {
          for (final id in {...visible, if (includeHistory) 'zakaz-history'})
            id: _row(id),
        },
        'worker_display_states': {
          _station: {for (final id in visible) id: states[id] ?? 'pending'}
        },
        'worker_report_prompts': {
          if (reportPrompt)
            _station: {
              'zakaz-a': {
                'report_session_id': 'report-session-one',
                'upstream_title': 'Upstream print machine',
              }
            },
        },
        'worker_pending_report_ids': <String, dynamic>{},
        'completed_orders': [
          if (includeHistory)
            {
              'order_id': 'zakaz-history',
              'apparatus': _station,
              'status': 'completed',
              'issue_note': '',
              'completed_at_unix': 700,
            }
        ],
        'completion_requests': <Object>[],
        'completion_request_decisions': <Object>[],
      };

  AdminProductionMapLiveSnapshot snapshot() =>
      AdminProductionMapLiveSnapshot.fromJson(wire());

  AdminApparatusQueueSnapshot full(String id) => AdminApparatusQueueSnapshot(
        projection: 'worker_detail_v1',
        epoch: detailEpoch,
        revision: detailRevision,
        scope: 'worker-full-$id',
        maps: [
          ProductionMapSaved.fromJson({
            'map': {
              'id': wrongOrder ? 'wrong-order' : id,
              'code': _row(id)['code'],
              'title': detailTitle,
              'customer_name': 'Worker customer',
              'product_code': 'WORKER-FILM',
              'image_id': 'image-$id',
              'nodes': [
                {'id': 'start', 'kind': 'start', 'title': 'Start'},
                {
                  'id': 'work',
                  'kind': 'apparatus',
                  'apparatus_id': _station,
                  'title': 'Full work stage'
                },
                {'id': 'end', 'kind': 'end', 'title': 'Finished product'},
              ],
              'edges': [
                {'from': 'start', 'to': 'work'},
                {'from': 'work', 'to': 'end'}
              ],
            },
            'program': <String, dynamic>{},
          })
        ],
        sequences: {
          _station: [id]
        },
        visibleOrderIds: {
          _station: [id]
        },
        queueStates: {
          _station: {id: detailState}
        },
        queuePolicies: const {},
        orderControls: const {},
        stageStates: const {},
        queueActionControls: {
          _station: {
            if (includeDetailControl)
              id: AdminApparatusQueueOrderActionControl.fromJson({
                ...scanControl(),
                'stage_node_id': 'work',
                'state': detailState,
                'allowed_actions': detailState == 'pending'
                    ? ['start']
                    : ['pause', 'complete'],
                'interaction': {
                  ...scanControl()['interaction'] as Map,
                  'mode':
                      detailState == 'pending' ? 'fresh_start' : 'in_progress',
                  'start_materials_mode': 'hidden',
                  'material_scan_required': false,
                  'qolip_mode': 'not_required',
                },
                if (reportPrompt)
                  'stage_work': {
                    'upstream_closed': true,
                    'astatka_available': true,
                    'astatka_required': detailReportRequired,
                    'report_session_id': detailReportSessionId,
                    'upstream_title': 'Upstream print machine',
                  },
              })
          }
        },
      );

  Future<AdminApparatusQueueSnapshot> detail(
      {required String apparatus, required String orderId}) async {
    details.add((apparatus: apparatus, orderId: orderId));
    if (detailError != null) throw detailError!;
    if (pending != null) return pending!.future;
    return full(orderId);
  }

  Future<void> mount(WidgetTester tester,
      {Size viewport = const Size(390, 844)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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
        workerMode: true,
        readOnly: true,
        apparatusLoader: () async => [_catalog],
        queueSnapshotLoader: () async {
          queueReads++;
          return snapshot();
        },
        orderDetailLoader: detail,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    dismissAdminTopNotice();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await events.close();
    await tester.pump(const Duration(seconds: 35));
    expect(tester.takeException(), isNull);
  }
}

Finder _workerRow(String id) => find.byKey(ValueKey('worker-order-$id'));
Finder _contractProgress() =>
    find.byKey(const ValueKey('worker-contract-sync-progress'));
Finder _contractWarning() => find.text(
    AppLocalizations(const Locale('uz')).productionText('worker.error.sync'));
Finder _sheet({bool? pending}) => find.byWidgetPredicate((widget) =>
    widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet' &&
    (pending == null || (widget as dynamic).detailPending == pending));
dynamic _content(WidgetTester tester) =>
    tester.widget(find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_ReadOnlyOrderDetailContent'));
dynamic _sequenceRow(WidgetTester tester, String id) =>
    tester.widget(find.descendant(
        of: _workerRow(id),
        matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_SequenceOrderRow')));

void main() {
  var serial = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    ProductionSnapshotStore.debugOverride =
        ProductionSnapshotStore(backend: MemoryProductionSnapshotBackend());
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    AppSession.instance.token = 'compact-worker-token';
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      ref: 'compact-worker-${++serial}',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_station],
    );
  });
  tearDown(() async {
    ProductionSnapshotStore.debugOverride = null;
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets(
      'compact worker list renders server membership rank and tone without details',
      (tester) async {
    final harness = _CompactHarness();
    final wire = harness.snapshot();
    expect(wire.maps, isEmpty);
    expect(wire.queueActionControls, isEmpty);
    await harness.mount(tester);
    expect(_workerRow('zakaz-a'), findsOneWidget);
    expect(_workerRow('zakaz-b'), findsOneWidget);
    expect(_workerRow('zakaz-history'), findsNothing);
    final a = _sequenceRow(tester, 'zakaz-a');
    final b = _sequenceRow(tester, 'zakaz-b');
    expect(a.position, 8);
    expect(b.position, 3);
    expect(a.tone.toString().split('.').last, 'neutral');
    expect(b.tone.toString().split('.').last, 'inProgress');
    expect(a.showApparatusCount, isFalse);
    expect(
        find.descendant(
            of: _workerRow('zakaz-a'),
            matching: find.textContaining('Worker customer')),
        findsWidgets);
    expect(harness.details, isEmpty);
    final reads = harness.queueReads;
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(harness.queueReads, reads, reason: 'Compact queue has no polling');
    expect(harness.details, isEmpty);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker row paints actual sheet before full scoped read completes',
      (tester) async {
    final harness = _CompactHarness()
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    final open = _sequenceRow(tester, 'zakaz-a').onTap as VoidCallback;
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pump(const Duration(milliseconds: 16));
    open();
    await tester.pump();
    expect(_sheet(pending: true), findsOneWidget);
    expect(
        find.text(AppLocalizations(const Locale('uz'))
            .productionText('worker.error.sync')),
        findsNothing,
        reason:
            'Missing controls are expected while compact detail is loading');
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    expect(harness.details, [(apparatus: _station, orderId: 'zakaz-a')]);
    final dynamic sheet = tester.widget(_sheet(pending: true));
    expect(sheet.onQueueAction, isNull);
    expect(sheet.currentQueueSnapshot(), isNull);
    expect(_content(tester).materialsLoading, isTrue);
    final originalState = tester.state(_sheet(pending: true));
    harness.pending!.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_sheet(pending: false), findsOneWidget);
    expect(
        identical(tester.state(_sheet(pending: false)), originalState), isTrue);
    final dynamic loaded = tester.widget(_sheet(pending: false));
    expect((loaded.order as ProductionMapSaved).map.nodes, hasLength(3));
    expect(loaded.currentQueueSnapshot(), isNotNull);
    expect(harness.details, hasLength(1));
    await harness.close(tester);
  });

  testWidgets(
      'compact worker pending close and reopen shares one full detail GET',
      (tester) async {
    final harness = _CompactHarness()
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('production-order-detail-close')));
    await tester.pumpAndSettle();
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pump();
    expect(harness.details, hasLength(1));
    harness.pending!.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_sheet(pending: false), findsOneWidget);
    expect(harness.details, hasLength(1));
    await harness.close(tester);
  });

  for (final outcome in ['closed', 'account changed']) {
    testWidgets('compact worker rejects pending detail after $outcome',
        (tester) async {
      final harness = _CompactHarness()
        ..pending = Completer<AdminApparatusQueueSnapshot>();
      await harness.mount(tester);
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      if (outcome == 'closed') {
        await tester
            .tap(find.byKey(const ValueKey('production-order-detail-close')));
        await tester.pumpAndSettle();
      } else {
        AppSession.instance.token = 'new-worker-account';
        await tester.pump();
      }
      harness.detailTitle = 'Obsolete secret detail';
      harness.pending!.complete(harness.full('zakaz-a'));
      await tester.pumpAndSettle();
      expect(_sheet(pending: false), findsNothing);
      expect(find.text('Obsolete secret detail'), findsNothing);
      await harness.close(tester);
    });
  }

  for (final failure in ['epoch', 'revision', 'order', 'error']) {
    testWidgets('compact worker rejects invalid $failure detail before actions',
        (tester) async {
      final harness = _CompactHarness();
      if (failure == 'epoch') harness.detailEpoch = 'old-server';
      if (failure == 'revision') harness.detailRevision = 6;
      if (failure == 'order') harness.wrongOrder = true;
      if (failure == 'error') {
        harness.detailError = const MobileApiException(
            code: 'detail_failed', message: 'Detail unavailable');
      }
      await harness.mount(tester);
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      expect(_sheet(pending: false), findsNothing);
      expect(_sheet(pending: true), findsOneWidget);
      expect((tester.widget(_sheet(pending: true)) as dynamic).onQueueAction,
          isNull);
      harness
        ..detailEpoch = _epoch
        ..detailRevision = 7
        ..wrongOrder = false
        ..detailError = null;
      final retry = find.byKey(const ValueKey('admin-sequence-detail-retry'));
      expect(retry, findsOneWidget);
      expect(
          find.text(AppLocalizations(const Locale('uz'))
              .productionText('worker.error.sync')),
          findsNothing,
          reason: 'A failed detail read keeps its scoped error and retry');
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(_sheet(pending: false), findsOneWidget);
      await harness.close(tester);
    });
  }

  testWidgets(
      'compact worker settled missing control stays silent then shows progress and blocks actions',
      (tester) async {
    final harness = _CompactHarness()..includeDetailControl = false;
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_sheet(pending: false), findsOneWidget);
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    expect(_contractWarning(), findsNothing);
    expect(_contractProgress(), findsNothing,
        reason: 'A brief control synchronization has no visible feedback');
    expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(_contractWarning(), findsNothing,
        reason: 'A settled failure must not become a red contract banner');
    expect(_contractProgress(), findsOneWidget);
    expect(tester.widget(_contractProgress()), isA<LinearProgressIndicator>());
    expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker pending contract waits two seconds then clears progress after hydration',
      (tester) async {
    final harness = _CompactHarness()
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pump();
    expect(_sheet(pending: true), findsOneWidget);
    expect(_contractWarning(), findsNothing);
    expect(_contractProgress(), findsNothing);
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    expect((tester.widget(_sheet()) as dynamic).onQueueAction, isNull);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(_contractWarning(), findsNothing);
    expect(_contractProgress(), findsNothing);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(_contractProgress(), findsOneWidget);
    expect(_contractWarning(), findsNothing);
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    expect(harness.details, hasLength(1),
        reason: 'The UI delay must not create extra detail requests');
    harness.pending!.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_sheet(pending: false), findsOneWidget);
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    expect(_contractProgress(), findsNothing);
    expect(_contractWarning(), findsNothing);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker later contract resync restarts the two second silent period',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final originalState = tester.state(_sheet());
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    for (final revision in [8, 9]) {
      harness
        ..revision = revision
        ..detailRevision = revision
        ..pending = Completer<AdminApparatusQueueSnapshot>();
      harness.events.add(harness.snapshot());
      await tester.pump();
      await tester.pump();
      expect(_content(tester).uiState.contractSynchronized, isFalse);
      expect(_contractWarning(), findsNothing);
      expect(_contractProgress(), findsNothing);
      await tester.pump(const Duration(milliseconds: 1800));
      expect(_contractProgress(), findsNothing,
          reason: 'Each distinct synchronization gets a new grace period');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(_contractProgress(), findsOneWidget);
      expect(_contractWarning(), findsNothing);
      expect(_content(tester).uiState.contractSynchronized, isFalse);
      expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing,
          reason: 'Keeping a handler cannot enable an unsynchronized action');
      harness.pending!.complete(harness.full('zakaz-a'));
      await tester.pumpAndSettle();
      expect(_content(tester).uiState.contractSynchronized, isTrue);
      expect(_contractProgress(), findsNothing);
      expect(_contractWarning(), findsNothing);
      expect(identical(tester.state(_sheet()), originalState), isTrue);
    }
    expect(harness.details, hasLength(3));
    await harness.close(tester);
  });

  for (final showProgress in [false, true]) {
    testWidgets(
        'compact worker closing cancels contract progress ${showProgress ? 'after' : 'before'} delay',
        (tester) async {
      final harness = _CompactHarness()
        ..pending = Completer<AdminApparatusQueueSnapshot>();
      await harness.mount(tester);
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pump();
      if (showProgress) {
        await tester.pump(const Duration(milliseconds: 2050));
        await tester.pump();
        expect(_contractProgress(), findsOneWidget);
      } else {
        await tester.pump(const Duration(milliseconds: 400));
        expect(_contractProgress(), findsNothing);
      }
      await tester
          .tap(find.byKey(const ValueKey('production-order-detail-close')));
      await tester.pumpAndSettle();
      expect(_sheet(), findsNothing);
      harness.pending!.complete(harness.full('zakaz-a'));
      await tester.pump(const Duration(seconds: 3));
      expect(_contractProgress(), findsNothing);
      expect(_contractWarning(), findsNothing);
      expect(tester.takeException(), isNull);
      await harness.close(tester);
    });
  }

  testWidgets(
      'compact worker stream changes row tone without graph or detail read',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    final reads = harness.queueReads;
    harness.states['zakaz-a'] = 'issue';
    harness.revision = 8;
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    expect(_sequenceRow(tester, 'zakaz-a').tone.toString().split('.').last,
        'issue');
    expect(harness.queueReads, reads);
    expect(harness.details, isEmpty);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker repeated occurrence uses server display membership',
      (tester) async {
    final harness = _CompactHarness();
    harness.queueStates['zakaz-a'] = 'completed';
    harness.states['zakaz-a'] = 'pending';
    await harness.mount(tester);
    expect(_workerRow('zakaz-a'), findsOneWidget,
        reason:
            'An earlier completed occurrence cannot hide unfinished work on same machine');
    expect(_sequenceRow(tester, 'zakaz-a').tone.toString().split('.').last,
        'neutral');
    expect(harness.details, isEmpty);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker completed history retains order labels without maps',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester, viewport: const Size(800, 844));
    await tester.ensureVisible(find.text('Tugallangan'));
    await tester.tap(find.text('Tugallangan'));
    await tester.pumpAndSettle();
    final history = find.byKey(
        const ValueKey(('worker-completed-order', 'zakaz-history', _station)));
    expect(history, findsOneWidget);
    expect(
        find.descendant(
            of: history, matching: find.textContaining('Completed package')),
        findsWidgets);
    expect(_workerRow('zakaz-history'), findsNothing);
    expect(harness.details, isEmpty);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker report prompt survives without full stage controls',
      (tester) async {
    final harness = _CompactHarness()..reportPrompt = true;
    await harness.mount(tester);
    expect(find.text('Astatkani topshiring'), findsOneWidget);
    expect(find.textContaining('Upstream print machine'), findsOneWidget);
    expect(harness.details, isEmpty,
        reason: 'Showing a summary report prompt does not hydrate every order');
    await tester.tap(find.text('Keyinroq'));
    await tester.pumpAndSettle();
    harness.revision = 8;
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    expect(find.text('Astatkani topshiring'), findsNothing,
        reason: 'One report session is prompted only once per page lifetime');
    expect(harness.details, isEmpty);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker long press hydrates full controls before action menu',
      (tester) async {
    final harness = _CompactHarness()
      ..detailState = 'in_progress'
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    harness.states['zakaz-a'] = 'in_progress';
    harness.queueStates['zakaz-a'] = 'in_progress';
    expect(
        harness
            .full('zakaz-a')
            .queueActionControls[_station]!['zakaz-a']!
            .contractValid,
        isTrue);
    await harness.mount(tester, viewport: const Size(390, 1100));
    await tester.longPress(_workerRow('zakaz-a'));
    await tester.pump();
    expect(harness.details, [(apparatus: _station, orderId: 'zakaz-a')]);
    Finder menu() => find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_BosmaWorkerFinishSheet');
    expect(menu(), findsNothing);
    harness.pending!.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(menu(), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .whereType<String>()
            .join(' | '));
    expect(harness.details, hasLength(1));
    expect(mobileApiTestModeBosmaAstatkaReports(), isEmpty);
    await harness.close(tester);
  });

  testWidgets(
      'compact worker report confirmation waits for full detail before form',
      (tester) async {
    final harness = _CompactHarness()
      ..reportPrompt = true
      ..detailState = 'in_progress'
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    harness.states['zakaz-a'] = 'in_progress';
    harness.queueStates['zakaz-a'] = 'in_progress';
    await harness.mount(tester);
    expect(find.text('Astatkani topshiring'), findsOneWidget);
    await tester.tap(find.text('Astatka topshirish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    Finder form() => find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_ProgressQtyDialog' &&
        (widget as dynamic).astatkaReport == true);
    expect(harness.details, [(apparatus: _station, orderId: 'zakaz-a')]);
    expect(form(), findsNothing,
        reason:
            'A compact report prompt cannot open a production form with a map shell');
    harness.pending!.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(form(), findsOneWidget);
    final dynamic report = tester.widget(form());
    expect((report.order as ProductionMapSaved).map.nodes, hasLength(3));
    expect(mobileApiTestModeBosmaAstatkaReports(), isEmpty,
        reason: 'Showing a report form must not submit it');
    await harness.close(tester);
  });

  for (final stale in ['completed elsewhere', 'different report session']) {
    testWidgets(
        'compact worker rejects automatic report $stale after full read',
        (tester) async {
      final harness = _CompactHarness()
        ..reportPrompt = true
        ..detailState = 'in_progress'
        ..pending = Completer<AdminApparatusQueueSnapshot>();
      harness.states['zakaz-a'] = 'in_progress';
      harness.queueStates['zakaz-a'] = 'in_progress';
      if (stale == 'completed elsewhere') {
        harness.detailReportRequired = false;
      } else {
        harness.detailReportSessionId = 'different-session';
      }
      await harness.mount(tester);
      await tester.tap(find.text('Astatka topshirish'));
      await tester.pumpAndSettle();
      expect(_sheet(pending: true), findsOneWidget);
      expect(harness.details, hasLength(1));
      harness.pending!.complete(harness.full('zakaz-a'));
      await tester.pumpAndSettle();
      expect(_sheet(pending: false), findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ProgressQtyDialog' &&
              (widget as dynamic).astatkaReport == true),
          findsNothing,
          reason: 'A compact prompt cannot authorize a stale report session');
      expect(mobileApiTestModeBosmaAstatkaReports(), isEmpty);
      await harness.close(tester);
    });
  }

  testWidgets(
      'compact worker menu choice rehydrates after a live revision instead of dropping action',
      (tester) async {
    final harness = _CompactHarness()..detailState = 'in_progress';
    harness.states['zakaz-a'] = 'in_progress';
    harness.queueStates['zakaz-a'] = 'in_progress';
    await harness.mount(tester, viewport: const Size(390, 1100));
    await tester.longPress(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final menu = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_BosmaWorkerFinishSheet');
    expect(menu, findsOneWidget);
    expect(harness.details, hasLength(1));
    harness
      ..revision = 8
      ..detailRevision = 8
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    final action = find.descendant(
        of: menu,
        matching: find.byWidgetPredicate((widget) => widget is OutlinedButton));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(2),
        reason: 'The menu choice must refresh expired scoped authority');
    Finder form() => find.byWidgetPredicate((widget) =>
        widget.runtimeType.toString() == '_ProgressQtyDialog' &&
        (widget as dynamic).astatkaReport == true);
    expect(form(), findsNothing);
    harness.pending!.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(form(), findsOneWidget);
    expect((tester.widget(form()) as dynamic).order.map.nodes, hasLength(3));
    expect(harness.details, hasLength(2));
    expect(mobileApiTestModeBosmaAstatkaReports(), isEmpty);
    await harness.close(tester);
  });
}
