import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_models.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_top_notice.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';
import 'production_snapshot_test_backend.dart';

part 'worker_compact_sheet_recovery_test_part.dart';

const _station = 'apparatus:default:bosma_7';
const _epoch = 'compact-worker-ui-server';
const _catalog = AdminApparatus(
    id: _station,
    name: 'Compact worker machine',
    operation: 'print',
    technology: 'gravure');
const _rezkaCatalog = AdminApparatus(
    id: 'apparatus:default:rezka_1',
    name: 'Compact Rezka machine',
    operation: 'cut',
    technology: 'slitting');

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
  _CompactHarness({this.catalog = _catalog});

  final AdminApparatus catalog;
  String get stationId => catalog.id;
  String epoch = _epoch;
  final orderControlStates = <String, String>{};
  final detailControlPatch = <String, dynamic>{};
  final detailNodePatch = <String, dynamic>{};
  final events = StreamController<Object>.broadcast();
  final details = <({String apparatus, String orderId})>[];
  Completer<AdminApparatusQueueSnapshot>? pending;
  Completer<AdminApparatusQueueSnapshot>? queueRefresh;
  int queueReads = 0;
  int revision = 7;
  int detailRevision = 7;
  String detailEpoch = _epoch;
  String detailTitle = 'Alpha package';
  String detailState = 'pending';
  Map<String, dynamic>? detailCombo;
  List<Map<String, dynamic>>? detailProducts;
  bool wrongOrder = false;
  bool includeDetailControl = true;
  Object? detailError;
  Future<AdminApparatusQueueSnapshot> Function()? detailResponse;
  bool reportPrompt = false;
  bool detailReportRequired = true;
  String detailReportSessionId = 'report-session-one';
  bool includeHistory = true;
  final temporarilyPausedOrders = <String>{};
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
        'epoch': epoch,
        'rev': revision,
        'scope': 'compact-worker-10',
        'sequences': {stationId: visible},
        'visible_order_ids': {stationId: visible},
        'sequence_versions': {stationId: 'a' * 64},
        'sequence_revisions': {stationId: 5},
        'sequence_positions_by_apparatus': {
          stationId: {
            for (final id in visible) id: id == 'zakaz-a' ? 8 : 3,
          }
        },
        'queue_policies': [
          {
            'apparatus_id': stationId,
            'apparatus': catalog.name,
            'policy': 'strict_sequence',
            'locked': false,
            'reason': '',
          }
        ],
        'queue_states': {
          stationId: {
            for (final id in visible) id: queueStates[id] ?? 'pending'
          }
        },
        'order_controls': {
          for (final entry in orderControlStates.entries)
            entry.key: {'state': entry.value},
        },
        'worker_list_rows': {
          for (final id in {...visible, if (includeHistory) 'zakaz-history'})
            id: {
              ..._row(id),
              if (temporarilyPausedOrders.contains(id))
                'temporarily_paused_apparatus': [stationId],
            },
        },
        'worker_display_states': {
          stationId: {for (final id in visible) id: states[id] ?? 'pending'}
        },
        'worker_report_prompts': {
          if (reportPrompt)
            stationId: {
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
              'apparatus': stationId,
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
              if (detailCombo != null) 'combo': detailCombo,
              if (detailProducts != null) 'products': detailProducts,
              'nodes': [
                {'id': 'start', 'kind': 'start', 'title': 'Start'},
                {
                  'id': 'work',
                  'kind': 'apparatus',
                  'apparatus_id': stationId,
                  'title': 'Full work stage',
                  ...detailNodePatch
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
          stationId: [id]
        },
        visibleOrderIds: {
          stationId: [id]
        },
        queueStates: {
          stationId: {id: detailState}
        },
        queuePolicies: const {},
        orderControls: {
          for (final entry in orderControlStates.entries)
            entry.key: entry.value == 'frozen'
                ? AdminOrderControlState.frozen
                : AdminOrderControlState.active,
        },
        stageStates: const {},
        queueActionControls: {
          stationId: {
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
                ...detailControlPatch,
              })
          }
        },
      );

  Future<AdminApparatusQueueSnapshot> detail(
      {required String apparatus, required String orderId}) async {
    details.add((apparatus: apparatus, orderId: orderId));
    if (detailResponse != null) return detailResponse!();
    if (detailError != null) throw detailError!;
    if (pending != null) return pending!.future;
    return full(orderId);
  }

  Future<void> mount(WidgetTester tester,
      {Size viewport = const Size(390, 844), bool settle = true}) async {
    if (!AppSession.instance.profile!.assignedApparatus.contains(stationId)) {
      AppSession.instance.profile =
          AppSession.instance.profile!.copyWith(assignedApparatus: [stationId]);
    }
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
        apparatusLoader: () async => [catalog],
        queueSnapshotLoader: () async {
          queueReads++;
          if (queueRefresh != null) return queueRefresh!.future;
          return snapshot();
        },
        orderDetailLoader: detail,
        liveEventsLoader: () => events.stream,
      ),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
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

_CompactHarness _presentationHarness(String scenario) {
  final harness = _CompactHarness(
      catalog: scenario == 'Rezka running' ? _rezkaCatalog : _catalog);
  final state = switch (scenario) {
    'Rezka running' => 'in_progress',
    'paused resume' => 'paused',
    'print preflight' => 'print_preflight',
    _ => 'pending',
  };
  harness.detailState = state;
  harness.states['zakaz-a'] = state;
  harness.queueStates['zakaz-a'] =
      scenario == 'repeated fresh start' ? 'completed' : state;
  harness.detailControlPatch.addAll({
    'allowed_actions': switch (state) {
      'in_progress' => ['pause', 'complete', 'merge'],
      'paused' => ['resume'],
      'print_preflight' => <String>[],
      _ => ['start'],
    },
    'interaction': {
      ...scanControl()['interaction'] as Map,
      'mode': state == 'pending'
          ? 'fresh_start'
          : state == 'print_preflight'
              ? 'fresh_start_blocked'
              : state,
      'start_materials_mode': 'hidden',
      'material_scan_required': false,
      'resume_input_required': false,
      'previous_wip_mode': 'not_required',
      'opening_wip_mode': 'not_required',
      'qolip_mode':
          scenario == 'Qolip start' ? 'scan_required' : 'not_required',
      'blocking_reason_code':
          state == 'print_preflight' ? 'print_preflight_active' : '',
    },
    if (state == 'print_preflight')
      'print_preflight': {
        'hold_id': 'presentation-hold',
        'idempotency_key': 'presentation-hold',
        'order_id': 'zakaz-a',
        'apparatus': harness.stationId,
        'status': 'running',
        'revision': 1,
      },
    if (scenario == 'Rezka running') ...{
      'rezka_output_kadr_counts': [2, 3],
      'rezka_input_lineage': [
        for (var index = 1; index <= 2; index++)
          {
            'input_batch_id': 'presentation-input-$index',
            'source_kind': 'progress_batch',
            'sequence_no': index,
            'status': index == 1 ? 'processed' : 'in_use',
          },
      ],
    },
  });
  if (scenario == 'Rezka running') {
    harness.detailNodePatch.addAll({
      // Server-selected outputs must survive a refresh without falling back
      // to this deliberately different saved-map plan.
      'rezka_frame_groups': [9],
      'rezka_label_length': 125,
    });
  }
  return harness;
}

Finder _privateWidget(String type) =>
    find.byWidgetPredicate((widget) => widget.runtimeType.toString() == type);
Finder _presentationActionGroup(String scenario) =>
    find.byKey(ValueKey(switch (scenario) {
      'Rezka running' => 'production-order-pause-complete-visible',
      'paused resume' => 'production-order-resume-visible',
      'print preflight' => 'production-order-print-preflight-outcome',
      _ => 'production-order-start-action',
    }));
List<ButtonStyleButton> _actionButtons(WidgetTester tester, String scenario) {
  final group = _presentationActionGroup(scenario);
  final widget = tester.widget(group);
  return widget is ButtonStyleButton
      ? [widget]
      : tester
          .widgetList<ButtonStyleButton>(find.descendant(
              of: group,
              matching:
                  find.byWidgetPredicate((item) => item is ButtonStyleButton)))
          .toList();
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

  _registerHydratedSheetRecoveryTests();

  testWidgets('worker does not see the combo details card', (tester) async {
    final harness = _CompactHarness()
      ..detailCombo = {
        'id': 'combo-1',
        'item_code': 'COMBO-1',
        'name': 'Shashoqcha',
        'revision': 1,
      }
      ..detailProducts = [
        {
          'id': 'p1',
          'item_code': 'SKU-A',
          'product': 'Yashil',
          'frame_product_size_mm': 120,
          'frame_count': 2,
        },
        {
          'id': 'p2',
          'item_code': 'SKU-B',
          'product': 'Kukuruz qora',
          'frame_product_size_mm': 120,
          'frame_count': 1,
        },
      ];
    await harness.mount(tester, viewport: const Size(390, 844));
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();

    expect(_privateWidget('_OrderStartUnifiedCard'), findsOneWidget);
    expect(_privateWidget('_OrderSummaryCard'), findsOneWidget);
    expect(find.byKey(const ValueKey('production-order-combo:zakaz-a')),
        findsNothing);
    expect(find.byKey(const ValueKey('production-order-combo-toggle')),
        findsNothing);
    for (final value in [
      'Kombo ma’lumotlari',
      'Kombo tarkibi',
      'Kombo · v1',
      'Shashoqcha',
      'COMBO-1',
    ]) {
      expect(find.text(value), findsNothing);
    }
    expect(find.textContaining('SKU-A'), findsNothing);
    expect(harness.details, [(apparatus: _station, orderId: 'zakaz-a')]);
    await harness.close(tester);
  });

  for (final authority in [true, false]) {
    testWidgets(
        authority
            ? 'compact cached worker long press exposes fresh scoped temporary pause'
            : 'compact cached worker long press hides absent scoped pause authority',
        (tester) async {
      final catalog = _catalog.copyWith(
          sourceRevision: 1, sourceAasxSha256: 'a' * 64);
      final harness = _CompactHarness(catalog: catalog)
        ..detailState = 'in_progress';
      if (authority) {
        harness.detailControlPatch['temporary_pause'] = {
          'session_id': 'unfinished-cached-roll',
          'token': 'b' * 64,
        };
      }
      final backend = MemoryProductionSnapshotBackend();
      ProductionSnapshotStore.debugOverride =
          ProductionSnapshotStore(backend: backend);
      await TestModeController.instance.setEnabled(false);
      await ProductionSnapshotStore.instance.write(
          scope: currentSessionReadScope(),
          key: jsonEncode(['canonical-queue-v1', true, false, true, 10, '']),
          value: {
            'schema': 1,
            'snapshot': encodeProductionMapQueueSnapshot(harness.snapshot()),
            'apparatus': [encodeCachedApparatus(catalog)],
          });
      final mutations = <http.Request>[];
      await http.runWithClient(() async {
        await harness.mount(tester, settle: false);
        expect(tester.takeException(), isNull,
            reason: 'Restored compact list must fit the phone viewport');
        expect(harness.queueReads, 0,
            reason: 'This must exercise restored compact rows, not a fresh list');
        expect(harness.events.hasListener, isTrue);
        await tester.longPress(_workerRow('zakaz-b'));
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(harness.details,
            [(apparatus: _station, orderId: 'zakaz-b')]);
        expect(find.byKey(const ValueKey('worker-temporary-pause')),
            authority ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull,
            reason: 'Bosma long-press menu must fit the phone viewport');
        expect(harness.queueReads, 0,
            reason: 'Scoped action authority must not refresh the global list');
        expect(backend.writeCount, 1,
            reason: 'One scoped detail must not certify and persist the list');
        if (authority) {
          final globalRefresh = Completer<AdminApparatusQueueSnapshot>();
          harness.queueRefresh = globalRefresh;
          await tester.tap(find.byKey(const ValueKey('worker-temporary-pause')));
          for (var frame = 0; frame < 8; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(mutations, hasLength(1));
          expect(jsonDecode(mutations.single.body), {
            'apparatus': _station,
            'order_id': 'zakaz-b',
            'session_id': 'unfinished-cached-roll',
            'token': 'b' * 64,
          });
          expect(mutations.single.url.path.endsWith('/temporary-pause'), isTrue);
          expect(globalRefresh.isCompleted, isFalse);
          expect(backend.writeCount, 1);
          harness.queueStates['zakaz-b'] = 'paused';
          harness.states['zakaz-b'] = 'paused';
          globalRefresh.complete(harness.snapshot());
          await _flushHydration(tester);
        } else {
          expect(mutations, isEmpty);
        }
        await harness.close(tester);
      }, () => MockClient((request) async {
            if (request.method == 'POST') {
              mutations.add(request);
              return http.Response('{"ok":true}', 200);
            }
            return http.Response('{}', 404);
          }));
    });
  }

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
    expect(find.byKey(const ValueKey('production-order-start-action')),
        findsNothing,
        reason: 'An initial summary must not fabricate a confirmed action');
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
      final retainedStart = find.widgetWithText(FilledButton, 'Boshlash');
      expect(retainedStart, findsOneWidget,
          reason: 'The last confirmed action remains rendered during resync');
      expect(tester.widget<FilledButton>(retainedStart).onPressed, isNull,
          reason: 'Presentation cannot authorize an unsynchronized action');
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

  for (final scenario in [
    'fresh start',
    'repeated fresh start',
    'Rezka running',
    'paused resume',
    'print preflight',
    'Qolip start',
  ]) {
    testWidgets('compact worker preserves $scenario presentation during resync',
        (tester) async {
      final harness = _presentationHarness(scenario);
      expect(
          harness
              .full('zakaz-a')
              .queueActionControls[harness.stationId]!['zakaz-a']!
              .contractValid,
          isTrue,
          reason: 'The presentation fixture must begin with real authority');
      await harness.mount(tester, viewport: const Size(700, 1800));
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      final originalState = tester.state(_sheet());
      final card = _privateWidget('_OrderStartUnifiedCard');
      final originalHeight = tester.getSize(card).height;
      expect(_presentationActionGroup(scenario), findsOneWidget);
      final dynamic before = _content(tester);
      final oldCallbacks = <VoidCallback>[
        if (scenario == 'print preflight') ...[
          before.onPrintPreflightPassed as VoidCallback,
          before.onPrintPreflightFailed as VoidCallback,
        ] else if (scenario == 'Rezka running') ...[
          before.onPause as VoidCallback,
          before.onMerge as VoidCallback,
          before.onComplete as VoidCallback,
        ] else if (scenario == 'paused resume')
          before.onResume as VoidCallback
        else
          before.onStart as VoidCallback,
      ];
      List<String>? plan;
      List<String>? merge;
      if (scenario == 'Rezka running') {
        plan = List<String>.from((tester
                .widget(_privateWidget('_RezkaWipSplitInstruction')) as dynamic)
            .lines);
        merge = List<String>.from(
            (tester.widget(_privateWidget('_RezkaMergeStateCard')) as dynamic)
                .lines);
        expect(_content(tester).uiState.rezkaOutputKadrCounts, [2, 3]);
        expect(_content(tester).uiState.rezkaInputLineage, hasLength(2));
      }
      if (scenario == 'Qolip start') {
        expect(find.byKey(const ValueKey('production-qolips-expansion')),
            findsOneWidget);
      }
      harness
        ..revision = 8
        ..detailRevision = 8
        ..pending = Completer<AdminApparatusQueueSnapshot>();
      harness.events.add(harness.snapshot());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_content(tester).uiState.contractSynchronized, isFalse);
      expect(_content(tester).actionsEnabled, isFalse);
      expect(_content(tester).presentationUiState, isNotNull);
      expect(_presentationActionGroup(scenario), findsOneWidget);
      expect(_actionButtons(tester, scenario), isNotEmpty);
      expect(_actionButtons(tester, scenario).every((b) => b.onPressed == null),
          isTrue,
          reason: 'Rendered old controls must stay disabled');
      expect(tester.getSize(card).height, closeTo(originalHeight, 0.5),
          reason: 'A temporary authority gap must not collapse the card');
      expect(identical(tester.state(_sheet()), originalState), isTrue);
      expect(_contractWarning(), findsNothing);
      expect(_contractProgress(), findsNothing);
      if (scenario == 'Rezka running') {
        expect(_content(tester).uiState.rezkaOutputKadrCounts, isEmpty);
        expect(
            _content(tester).presentationUiState.rezkaOutputKadrCounts, [2, 3]);
        expect(_content(tester).presentationUiState.stageNodeId, 'work');
        expect(_content(tester).presentationUiState.rezkaInputLineage,
            hasLength(2));
        expect(
            (tester.widget(_privateWidget('_RezkaWipSplitInstruction'))
                    as dynamic)
                .lines,
            plan);
        expect(
            (tester.widget(_privateWidget('_RezkaMergeStateCard')) as dynamic)
                .lines,
            merge);
        final button =
            find.byKey(const ValueKey('production-order-merge-action'));
        expect(button, findsOneWidget);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
      }
      if (scenario == 'Qolip start') {
        expect(find.byKey(const ValueKey('production-qolips-expansion')),
            findsOneWidget);
      }
      // Retained callbacks may be invoked after a pointer event was queued.
      // They must not even start an HTTP read/form while authority is stale.
      final requests = <http.Request>[];
      await TestModeController.instance.setEnabled(false);
      try {
        await http.runWithClient(() async {
          for (final callback in oldCallbacks) {
            callback();
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          expect(requests, isEmpty);
          expect(_privateWidget('_ProgressQtyDialog'), findsNothing);
        },
            () => MockClient((request) async {
                  requests.add(request);
                  return http.Response(
                      '{"error":"unexpected_stale_callback"}', 503);
                }));
      } finally {
        await TestModeController.instance.setEnabled(true);
      }
      if (scenario == 'fresh start') {
        harness.detailState = 'in_progress';
        harness.detailControlPatch.clear();
      }
      harness.pending!.complete(harness.full('zakaz-a'));
      await tester.pumpAndSettle();
      expect(_content(tester).uiState.contractSynchronized, isTrue);
      expect(identical(tester.state(_sheet()), originalState), isTrue);
      if (scenario == 'fresh start') {
        expect(find.byKey(const ValueKey('production-order-start-action')),
            findsNothing);
        expect(
            find.byKey(
                const ValueKey('production-order-pause-complete-visible')),
            findsOneWidget);
      } else {
        expect(_presentationActionGroup(scenario), findsOneWidget);
        if (scenario != 'Qolip start') {
          expect(
              _actionButtons(tester, scenario).any((b) => b.onPressed != null),
              isTrue);
        }
      }
      await harness.close(tester);
    });
  }

  for (final boundary in ['account', 'epoch', 'order', 'freeze']) {
    testWidgets('compact worker does not reuse presentation across $boundary',
        (tester) async {
      final harness = _CompactHarness();
      await harness.mount(tester);
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-order-start-action')),
          findsOneWidget);
      harness.pending = Completer<AdminApparatusQueueSnapshot>();
      var targetOrder = 'zakaz-a';
      if (boundary == 'account') {
        AppSession.instance.token = 'different-presentation-account';
        AppSession.instance.profile = AppSession.instance.profile!
            .copyWith(ref: 'different-presentation-worker');
        AppSession.instance.revision.value++;
      } else if (boundary == 'order') {
        await tester
            .tap(find.byKey(const ValueKey('production-order-detail-close')));
        await tester.pumpAndSettle();
        targetOrder = 'zakaz-b';
        await tester.tap(_workerRow(targetOrder));
      } else {
        harness.revision = 8;
        harness.detailRevision = 8;
        if (boundary == 'epoch') {
          harness.epoch = 'replacement-presentation-server';
          harness.detailEpoch = harness.epoch;
        } else {
          harness.orderControlStates['zakaz-a'] = 'frozen';
          harness.detailState = 'frozen';
          harness.detailControlPatch.addAll({
            'allowed_actions': <String>[],
            'interaction': {
              ...scanControl()['interaction'] as Map,
              'mode': 'frozen',
              'start_materials_mode': 'hidden',
              'material_scan_required': false,
              'qolip_mode': 'not_required',
            },
          });
        }
        harness.events.add(harness.snapshot());
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('production-order-start-action')),
          findsNothing,
          reason:
              'A presentation cache cannot cross this identity/safety boundary');
      if (boundary == 'account') {
        expect(_sheet(), findsNothing,
            reason: 'Switching accounts closes the old account detail route');
      } else {
        expect(_content(tester).uiState.contractSynchronized, isFalse);
        expect(_content(tester).presentationUiState, isNull);
        expect(_content(tester).actionsEnabled, isFalse);
      }
      harness.pending!.complete(harness.full(targetOrder));
      await tester.pump();
      await harness.close(tester);
    });
  }

  testWidgets(
      'compact worker denied detail refresh clears actions until validated reopen',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final originalState = tester.state(_sheet());
    final start = find.byKey(const ValueKey('production-order-start-action'));
    expect(start, findsOneWidget);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    final oldStart = _content(tester).onStart as VoidCallback;
    harness
      ..revision = 8
      ..detailRevision = 8
      ..detailError = const MobileApiException(
          statusCode: 403, code: 'forbidden', message: 'Access revoked');
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(2));
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    expect(_content(tester).presentationUiState, isNull,
        reason: 'A denied scoped read invalidates previously confirmed display');
    expect(_content(tester).actionsEnabled, isFalse);
    expect(start, findsNothing);
    expect(find.byKey(const ValueKey('production-order-pause-complete-visible')),
        findsNothing);
    expect(find.byKey(const ValueKey('production-order-merge-action')),
        findsNothing);
    final requests = <http.Request>[];
    await TestModeController.instance.setEnabled(false);
    try {
      await http.runWithClient(() async {
        oldStart();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(requests, isEmpty,
            reason: 'A retained callback cannot operate after access denial');
      }, () => MockClient((request) async {
        requests.add(request);
        return http.Response('{"error":"unexpected_denied_action"}', 503);
      }));
    } finally {
      await TestModeController.instance.setEnabled(true);
    }
    harness
      ..revision = 9
      ..detailRevision = 9
      ..detailError = null;
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(2),
        reason: 'Permission denial stops automatic recovery until reopened');
    await tester.tap(find.byKey(const ValueKey('production-order-detail-close')));
    await tester.pumpAndSettle();
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(3));
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    expect(_content(tester).actionsEnabled, isTrue);
    expect(start, findsOneWidget);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    expect(identical(tester.state(_sheet()), originalState), isFalse,
        reason: 'Reopening after denial creates a new scoped detail state');
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
      'temporary removal starts reordered first compact order while global refresh is blocked',
      (tester) async {
    final harness = _CompactHarness()
      ..detailState = 'in_progress'
      ..visible = ['zakaz-a', 'zakaz-b'];
    harness.states['zakaz-a'] = 'in_progress';
    harness.queueStates['zakaz-a'] = 'in_progress';
    harness.states['zakaz-b'] = 'pending';
    harness.queueStates['zakaz-b'] = 'pending';
    harness.detailControlPatch['temporary_pause'] = {
      'session_id': 'compact-unfinished-roll',
      'token': List.filled(64, 'c').join(),
    };
    harness.events.onListen = () => scheduleMicrotask(() {
          if (!harness.events.isClosed) harness.events.add(harness.snapshot());
        });
    final mutations = <http.Request>[];
    final started = Completer<http.Response>();
    await http.runWithClient(() async {
      await harness.mount(tester, viewport: const Size(390, 1100));
      await tester.longPress(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      expect(harness.details, [(apparatus: _station, orderId: 'zakaz-a')]);
      harness.queueRefresh = Completer<AdminApparatusQueueSnapshot>();
      final globalReads = harness.queueReads;
      await TestModeController.instance.setEnabled(false);
      await tester.tap(find.byKey(const ValueKey('worker-temporary-pause')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(mutations, hasLength(1));
      expect(mutations.single.url.path, endsWith('/temporary-pause'));
      expect(harness.queueReads, greaterThan(globalReads));
      expect(harness.queueRefresh!.isCompleted, isFalse);

      // An admin moves the suspended order below B. The fresh scoped read
      // authorizes the new first order while the global cursor is still old.
      harness
        ..visible = ['zakaz-b', 'zakaz-a']
        ..revision = 8
        ..detailRevision = 8
        ..detailState = 'pending'
        ..detailTitle = 'Urgent next package';
      harness.detailControlPatch.remove('temporary_pause');
      harness.states['zakaz-a'] = 'paused';
      harness.queueStates['zakaz-a'] = 'paused';
      harness.pending = Completer<AdminApparatusQueueSnapshot>();
      dismissAdminTopNotice();
      await tester.tap(_workerRow('zakaz-b'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(harness.details, [
        (apparatus: _station, orderId: 'zakaz-a'),
        (apparatus: _station, orderId: 'zakaz-b'),
      ]);
      expect(_sheet(pending: true), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing,
          reason: 'The old compact row cannot invent start permission');
      harness.pending!.complete(harness.full('zakaz-b'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_sheet(pending: false), findsOneWidget);
      expect(_content(tester).uiState.contractSynchronized, isTrue);
      final start = find.widgetWithText(FilledButton, 'Boshlash');
      expect(start, findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      final dynamic sheet = tester.widget(_sheet(pending: false));
      expect(sheet.queueActionsInFlight.value, isEmpty,
          reason: 'The pause busy state ends at ACK, not global refresh');
      expect(sheet.currentQueueSnapshot().revision, 8);
      expect(harness.queueRefresh!.isCompleted, isFalse);
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump();
      expect(mutations, hasLength(2),
          reason: 'Next work starts without waiting for the global snapshot');
      expect(mutations.last.url.path, endsWith('/queue-action'));
      expect(jsonDecode(mutations.last.body)['order_id'], 'zakaz-b');
      expect(jsonDecode(mutations.last.body)['action'], 'start');
      expect(harness.queueRefresh!.isCompleted, isFalse);
      expect(harness.details, hasLength(2),
          reason: 'Start reuses its fresh scoped contract without a preflight');
      started.complete(http.Response(
          jsonEncode({
            'ok': true,
            'states': {'zakaz-a': 'paused', 'zakaz-b': 'in_progress'},
          }),
          200));
      harness.queueRefresh!.complete(harness.snapshot());
      await tester.pumpAndSettle();
      await harness.close(tester);
    }, () => MockClient((request) {
      if (request.method == 'POST') {
        mutations.add(request);
        return request.url.path.endsWith('/temporary-pause')
            ? Future.value(http.Response('{"ok":true}', 200))
            : started.future;
      }
      if (request.url.path.endsWith('/order-scan-bootstrap')) {
        final control = harness.full('zakaz-b')
            .queueActionControls[_station]!['zakaz-b']!;
        Map<String, dynamic> section(Object data) => {
              'status': 'ready',
              'apparatus': _station,
              'order_id': 'zakaz-b',
              'stage_node_id': 'work',
              'data': data,
            };
        return Future.value(http.Response(
            jsonEncode({
              'ok': true,
              'control_state': {
                'apparatus': _station,
                'order_id': 'zakaz-b',
                'rev': 8,
                'epoch': _epoch,
                'scope': 'fresh-next-order-setup',
                'control': jsonDecode(control.serverContractSignature),
                'queue_state': 'pending',
                'stage_states': <String, String>{},
                'order_control': 'active',
              },
              'sections': {
                'material_assignments': section(<Object>[]),
                'input_progress': {
                  ...section({'batches': <Object>[]}),
                  'limit': 500,
                  'status_filter': 'waiting',
                },
              },
            }),
            200));
      }
      return Future.value(http.Response('{"error":"not_found"}', 404));
    }));
  });

  testWidgets('temporary pause label survives compact refresh and clears on resume',
      (tester) async {
    final harness = _CompactHarness()..visible = ['zakaz-a', 'zakaz-b'];
    harness.states.addAll({'zakaz-a': 'paused', 'zakaz-b': 'pending'});
    harness.queueStates.addAll({'zakaz-a': 'paused', 'zakaz-b': 'pending'});
    harness.temporarilyPausedOrders.add('zakaz-a');
    await harness.mount(tester);
    expect(harness.snapshot().queueActionControls, isEmpty);
    expect(_sequenceRow(tester, 'zakaz-a').apparatusLabel, 'Vaqtincha yechilgan');
    expect(find.textContaining('Vaqtincha yechilgan'), findsWidgets);
    harness.revision++;
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    expect(_sequenceRow(tester, 'zakaz-a').apparatusLabel, 'Vaqtincha yechilgan');
    expect(harness.details, isEmpty,
        reason: 'The display label must not require action authority hydration');
    harness.temporarilyPausedOrders.clear();
    harness.states['zakaz-a'] = 'in_progress';
    harness.queueStates['zakaz-a'] = 'in_progress';
    harness.revision++;
    harness.events.add(harness.snapshot());
    await tester.pumpAndSettle();
    expect(_sequenceRow(tester, 'zakaz-a').apparatusLabel, isEmpty);
    expect(find.textContaining('Vaqtincha yechilgan'), findsNothing);
    await harness.close(tester);
  });

  for (final outcome in ['success', 'rejected', 'lost response', 'newer live']) {
    testWidgets(
        'temporary removal acknowledges compact pause before refresh: $outcome',
        (tester) async {
      final harness = _CompactHarness()..detailState = 'in_progress';
      harness.states['zakaz-a'] = 'in_progress';
      harness.queueStates['zakaz-a'] = 'in_progress';
      harness.detailControlPatch['temporary_pause'] = {
        'session_id': 'compact-unfinished-roll',
        'token': List.filled(64, 'c').join(),
      };
      harness.events.onListen = () => scheduleMicrotask(() {
            if (!harness.events.isClosed) harness.events.add(harness.snapshot());
          });
      final response = Completer<http.Response>();
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await harness.mount(tester, viewport: const Size(390, 1100));
        final initial = harness.snapshot();
        await tester.longPress(_workerRow('zakaz-a'));
        await tester.pumpAndSettle();
        expect(harness.details, hasLength(1));
        final action = find.byKey(const ValueKey('worker-temporary-pause'));
        expect(action, findsOneWidget);
        harness.queueRefresh = Completer<AdminApparatusQueueSnapshot>();
        await TestModeController.instance.setEnabled(false);
        final reads = harness.queueReads;
        await tester.tap(action);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, endsWith('/temporary-pause'));
        expect(harness.details, hasLength(1),
            reason: 'The menu already hydrated authority; no click preflight');
        expect(_sequenceRow(tester, 'zakaz-a').tone.toString(),
            endsWith('.inProgress'), reason: 'Do not pause before acknowledgement');
        if (outcome == 'newer live') {
          // Another device already resumed after this pause committed, while
          // its POST response was still delayed in transit.
          harness.revision = 9;
          harness.detailRevision = 9;
          harness.events.add(harness.snapshot());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (outcome == 'lost response') {
          response.completeError(http.ClientException('Response lost after commit'));
        } else {
          response.complete(http.Response(
              outcome == 'rejected'
                  ? '{"error":"queue_action_not_allowed"}'
                  : '{"ok":true}',
              outcome == 'rejected' ? 409 : 200));
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(harness.queueReads, greaterThan(reads));
        expect(harness.queueRefresh!.isCompleted, isFalse);
        expect(_sequenceRow(tester, 'zakaz-a').tone.toString(),
            endsWith(outcome == 'success' ? '.paused' : '.inProgress'),
            reason: 'An acknowledged pause paints immediately; an uncertain '
                'response or newer live state cannot invent or rewind state');
        expect(_sequenceRow(tester, 'zakaz-b').tone.toString(),
            endsWith('.inProgress'), reason: 'Other rows retain their state');
        expect(initial.queueStates[_station]!['zakaz-a'], 'in_progress',
            reason: 'Canonical immutable snapshots remain untouched');
        expect(initial.workerDisplayStates[_station]!['zakaz-a'], 'in_progress');
        expect(requests.where((request) => request.method == 'POST'), hasLength(1));
        // The canonical read remains authoritative, including a later resume.
        harness.queueRefresh!.complete(harness.snapshot());
        await tester.pumpAndSettle();
        expect(_sequenceRow(tester, 'zakaz-a').tone.toString(),
            endsWith('.inProgress'));
        await harness.close(tester);
      }, () => MockClient((request) {
        requests.add(request);
        return request.method == 'POST'
            ? response.future
            : Future.value(http.Response('{"error":"not_found"}', 404));
      }));
    });
  }

  testWidgets(
      'compact worker temporary removal hydrates authority and reconciles stale token',
      (tester) async {
    final token = List.filled(64, 'c').join();
    final harness = _CompactHarness()
      ..detailState = 'in_progress'
      ..pending = Completer<AdminApparatusQueueSnapshot>();
    harness.states['zakaz-a'] = 'in_progress';
    harness.queueStates['zakaz-a'] = 'in_progress';
    harness.detailControlPatch['temporary_pause'] = {
      'session_id': 'compact-unfinished-roll',
      'token': token,
    };
    harness.events.onListen = () => scheduleMicrotask(() {
          if (!harness.events.isClosed) harness.events.add(harness.snapshot());
        });
    final mutations = <http.Request>[];
    await http.runWithClient(() async {
      expect(harness.snapshot().queueActionControls, isEmpty);
      await harness.mount(tester, viewport: const Size(390, 1100));
      await tester.longPress(_workerRow('zakaz-a'));
      await tester.pump();
      expect(harness.details, [(apparatus: _station, orderId: 'zakaz-a')]);
      final action = find.byKey(const ValueKey('worker-temporary-pause'));
      expect(action, findsNothing,
          reason: 'A compact display row cannot authorize suspension');
      harness.pending!.complete(harness.full('zakaz-a'));
      await tester.pumpAndSettle();
      harness.pending = null;
      expect(action, findsOneWidget,
          reason: 'The hydrated full control supplies suspension authority');
      expect(harness.details, hasLength(1));
      expect(mutations, isEmpty);

      // The menu retains its captured token while a newer compact revision
      // withdraws full controls. The backend rejects that token without an
      // output action fallback or a mutation retry.
      harness.detailControlPatch.remove('temporary_pause');
      harness
        ..revision = 8
        ..detailRevision = 8;
      harness.events.add(harness.snapshot());
      await tester.pumpAndSettle();
      await TestModeController.instance.setEnabled(false);
      final reads = harness.queueReads;
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(mutations, hasLength(1));
      expect(mutations.single.url.path, endsWith('/temporary-pause'));
      expect(jsonDecode(mutations.single.body), {
        'apparatus': _station,
        'order_id': 'zakaz-a',
        'session_id': 'compact-unfinished-roll',
        'token': token,
      });
      expect(harness.queueReads, greaterThan(reads),
          reason: 'An uncertain/rejected write is reconciled through reads');
      expect(find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString().contains('ProgressQty')), findsNothing);
      expect(harness.queueStates['zakaz-a'], 'in_progress');
      dismissAdminTopNotice();
      await tester.pumpAndSettle();
      await tester.longPress(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      expect(harness.details, hasLength(2));
      expect(action, findsNothing,
          reason: 'The latest scoped detail no longer offers suspension');
      expect(mutations, hasLength(1));
      await harness.close(tester);
    }, () => MockClient((request) async {
      if (request.method == 'POST') {
        mutations.add(request);
        return http.Response('{"error":"queue_action_not_allowed"}', 409);
      }
      return http.Response('{"error":"not_found"}', 404);
    }));
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
