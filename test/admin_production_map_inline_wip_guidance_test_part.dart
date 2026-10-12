part of 'admin_production_map_test_screen_test.dart';

const _inlineOrderId = 'zakaz-inline-wip';
const _inlineOtherOrderId = 'zakaz-inline-other';
const _inlineWipQr = '400118D5A225166D31898C1F';
const _inlineOtherWipQr = '400118D5A225166D31898C2F';

class _InlineWipFixture {
  _InlineWipFixture(this.entrypoint)
      : phase = entrypoint == 'start'
            ? 'start'
            : entrypoint == 'resume'
                ? 'paused'
                : 'active';

  final String entrypoint;
  String phase;
  String wipStatus = 'waiting';
  bool allowMerge = true;
  bool useOpening = false;
  bool consumeInitialQr = false;
  bool openingStageRejected = false;
  String? mutationRejection;
  String? rejectionPhase;
  int revision = 1;
  final requests = <http.Request>[];
  final mutations = <http.Request>[];
  final events = StreamController<AdminProductionMapLiveSnapshot>.broadcast();
  Completer<void>? lookupGate;
  Completer<void>? mutationGate;
  late List<ProductionMapSaved> maps;
  late List<AdminApparatus> apparatus;

  Map<String, dynamic> control({bool other = false}) {
    final selectedPhase =
        other ? (phase == 'busy' ? 'active' : 'start') : phase;
    final state = switch (selectedPhase) {
      'active' => 'in_progress',
      'paused' => 'paused',
      'frozen' => 'frozen',
      _ => 'pending',
    };
    return {
      'state': state,
      'allowed_actions': switch (selectedPhase) {
        'active' => ['pause', 'complete', if (allowMerge) 'merge'],
        'paused' => ['resume'],
        'frozen' || 'busy' => <String>[],
        _ => ['start'],
      },
      'previous_stage': _print9Id,
      'previous_stage_ready': true,
      'stage_node_id': 'second-apparatus',
      'complete_requires_full_report': false,
      if (selectedPhase == 'active')
        'rezka_input_lineage': [
          {
            'input_batch_id': 'mounted-input',
            'source_kind': 'progress_batch',
            'sequence_no': 1,
            'status': 'in_use'
          },
        ],
      'interaction': {
        'mode': switch (selectedPhase) {
          'active' => 'in_progress',
          'paused' => 'paused',
          'frozen' => 'frozen',
          'busy' => 'fresh_start_blocked',
          _ => 'fresh_start',
        },
        'start_materials_mode': 'hidden',
        'material_scan_required': false,
        'assigned_materials_display_only': true,
        'material_intake_allowed':
            selectedPhase == 'active' && entrypoint == 'intake',
        'previous_wip_mode':
            selectedPhase == 'start' ? 'scan_required' : 'not_required',
        'opening_wip_mode': useOpening && selectedPhase == 'start'
            ? 'scan_required'
            : 'not_required',
        'qolip_mode':
            !other && entrypoint == 'resume' && selectedPhase == 'paused'
                ? 'scan_required'
                : 'not_required',
        'blocking_reason_code': selectedPhase == 'busy' ? 'apparatus_busy' : '',
      },
    };
  }

  AdminProductionMapLiveSnapshot snapshot() => AdminProductionMapLiveSnapshot(
        maps: maps,
        sequences: const {
          _lamination1Id: [_inlineOrderId, _inlineOtherOrderId]
        },
        visibleOrderIds: const {
          _lamination1Id: [_inlineOrderId, _inlineOtherOrderId]
        },
        queueStates: {
          _lamination1Id: {
            _inlineOrderId: control()['state'] as String,
            _inlineOtherOrderId: control(other: true)['state'] as String,
          }
        },
        queuePolicies: const {},
        orderControls: {
          if (phase == 'frozen') _inlineOrderId: AdminOrderControlState.frozen
        },
        queueActionControls: {
          _lamination1Id: {
            _inlineOrderId:
                AdminApparatusQueueOrderActionControl.fromJson(control()),
            _inlineOtherOrderId: AdminApparatusQueueOrderActionControl.fromJson(
                control(other: true)),
          }
        },
        completedOrders: const [],
        completionRequests: const [],
        completionRequestDecisions: const [],
        revision: revision,
        epoch: 'inline-server',
      );

  Map<String, dynamic> sequence() => {
        'ok': true,
        'rev': revision,
        'epoch': 'inline-server',
        'scope': '',
        'maps': [
          for (final saved in maps)
            {
              'map': saved.map.toJson(),
              'program': {'map_id': saved.map.id, 'operations': []}
            },
        ],
        'sequences': {
          _lamination1Id: [_inlineOrderId, _inlineOtherOrderId]
        },
        'visible_order_ids': {
          _lamination1Id: [_inlineOrderId, _inlineOtherOrderId]
        },
        'queue_states': {
          _lamination1Id: {
            _inlineOrderId: control()['state'],
            _inlineOtherOrderId: control(other: true)['state'],
          }
        },
        'queue_policies': [],
        'stage_states': {},
        'queue_action_controls': {
          _lamination1Id: {
            _inlineOrderId: control(),
            _inlineOtherOrderId: control(other: true),
          }
        },
        'order_controls': {
          if (phase == 'frozen') _inlineOrderId: {'state': 'frozen'}
        },
        'order_statuses': {},
        'frozen_orders_by_apparatus': {},
      };

  Map<String, dynamic> batch({bool other = false}) => {
        'batch_id': other ? 'other-wip' : 'inline-wip',
        'session_id': 'previous-worker-session',
        'order_id': other ? _inlineOtherOrderId : _inlineOrderId,
        'apparatus': _print9Id,
        'action': 'detach_roll',
        'status': 'roll_detached',
        'qr_payload': other ? _inlineOtherWipQr : _inlineWipQr,
        'produced_qty': 100,
        'uom': 'm',
        'finished_goods_meter': 100,
        'finished_goods_kg': 20,
        'bobina_kg': 1,
        'wip_status': wipStatus,
        'next_apparatus': _lamination1Id,
        'current_apparatus':
            wipStatus == 'waiting' ? _print9Id : _lamination1Id,
        if (wipStatus != 'waiting') 'used_by_apparatus': _lamination1Id,
        if (wipStatus != 'waiting') 'used_by_session_id': 'other-shift-session',
        'payload_json': {'next_stage_node_id': 'second-apparatus'},
      };

  Map<String, dynamic> openingBatch() => {
        'batch_id': 'inline-opening-wip',
        'intake_id': 'inline-opening-intake',
        'order_id': _inlineOrderId,
        'sequence_no': 1,
        'qr_payload': _inlineWipQr,
        'quantity_basis': 'measured',
        'quantity': 100,
        'uom': 'm',
        'finished_goods_meter': 100,
        'finished_goods_kg': 20,
        'bobina_kg': 1,
        'wip_status': wipStatus,
        if (wipStatus == 'in_use')
          'used_by_session_id': 'previous-shift-session',
        if (wipStatus == 'in_use') 'used_by_apparatus': _lamination1Id,
      };

  Map<String, dynamic> openingRecord() => {
        'intake': {
          'intake_id': 'inline-opening-intake',
          'idempotency_key': 'inline-opening',
          'order_id': _inlineOrderId,
          'entry_apparatus': _print9Id,
          'source_operation': 'print',
          'source_apparatus': _print9Id,
          'resume_apparatus': _print9Id,
          'resume_stage_node_id': 'first-apparatus',
          'history_status': 'available',
          'status': 'confirmed',
        },
        'batches': [openingBatch()],
      };

  Future<http.Response> respond(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/order-scan-bootstrap')) return http.Response('', 404);
    if (path.endsWith('/sequence'))
      return http.Response(jsonEncode(sequence()), 200);
    if (path.endsWith('/raw-material-assignments'))
      return http.Response('[]', 200);
    if (path.endsWith('/raw-material-intake-candidates')) {
      return http.Response(
          jsonEncode([
            {
              'order_id': _inlineOrderId,
              'apparatus': _lamination1Id,
              'barcode': 'RAW-INLINE-1',
              'item_code': 'FILM-INLINE',
              'item_name': 'Additional film',
              'item_group': 'film',
              'stock_status': 'available',
              'stock_qty': 100,
              'stock_uom': 'kg',
              'execution_status': 'compatible',
            }
          ]),
          200);
    }
    if (path.endsWith('/qolip-validate'))
      return http.Response(jsonEncode(scanQolips()), 200);
    if (path.endsWith('/wip-batches'))
      return http.Response('{"batches":[]}', 200);
    if (path.endsWith('/opening-wip/qr/report')) {
      if (!useOpening)
        return http.Response('{"error":"opening_wip_qr_not_found"}', 404);
      return http.Response(jsonEncode({'record': openingRecord()}), 200);
    }
    if (path.endsWith('/opening-wip/lookup')) {
      final payload = jsonDecode(request.body) as Map;
      if (payload['qr_payload'] == '')
        return http.Response(
            jsonEncode({
              'batches': [
                if (useOpening &&
                    wipStatus == 'waiting' &&
                    !openingStageRejected)
                  openingBatch(),
              ]
            }),
            200);
      if (openingStageRejected)
        return http.Response('{"error":"opening_wip_qr_mismatch"}', 409);
      return http.Response(jsonEncode({'batch': openingBatch()}), 200);
    }
    if (path.endsWith('/lookup')) {
      final payload = jsonDecode(request.body) as Map;
      final qr = payload['qr_payload'];
      if (useOpening || (qr != _inlineWipQr && qr != _inlineOtherWipQr)) {
        return http.Response('{"error":"progress_batch_not_found"}', 404);
      }
      if (lookupGate != null) await lookupGate!.future;
      final other = qr == _inlineOtherWipQr;
      return http.Response(
          jsonEncode({
            'batch': batch(other: other),
            'active_order_validated': true,
            if (payload.containsKey('apparatus'))
              'validated_apparatus': payload['apparatus'],
            if (payload.containsKey('order_id'))
              'validated_order_id': payload['order_id'],
          }),
          200);
    }
    if (path.endsWith('/queue-action') ||
        path.endsWith('/raw-material-intake')) {
      mutations.add(request);
      if (mutationGate != null) await mutationGate!.future;
      if (mutationRejection != null) {
        if (rejectionPhase != null) changePhase(rejectionPhase!);
        return http.Response(jsonEncode({'error': mutationRejection}), 409);
      }
      return http.Response(
          jsonEncode({
            'ok': true,
            'states': {_inlineOrderId: 'in_progress'},
            'order_control': {'state': 'active'},
          }),
          200);
    }
    return http.Response('{"error":"not_found"}', 404);
  }

  Future<void> open(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'New shift',
      legalName: '',
      ref: 'inline-new-shift',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_lamination1Id],
    );
    maps = [
      for (final other in [false, true])
        await MobileApi.instance
            .adminSaveProductionMap(_twoStageProductionOrderMap(
          id: other ? _inlineOtherOrderId : _inlineOrderId,
          title: other ? 'Other inline work' : 'Inline work',
          productCode: other ? 'INLINE-OTHER' : 'INLINE',
          product: 'Inline product',
          firstApparatusId: _print9Id,
          secondApparatusId: _lamination1Id,
        )),
    ];
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    snapshot().validateContract();
    if (consumeInitialQr) await TestModeController.instance.setEnabled(false);
    await _usePhoneViewport(tester);
    addTearDown(() async {
      if (lookupGate != null && !lookupGate!.isCompleted)
        lookupGate!.complete();
      if (mutationGate != null && !mutationGate!.isCompleted)
        mutationGate!.complete();
      dismissAdminTopNotice();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await events.close();
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        initialWorkerQrPayload: consumeInitialQr ? _inlineWipQr : '',
        queueSnapshotLoader: () async => snapshot(),
        apparatusLoader: () async => apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    if (consumeInitialQr) return;
    await tester.tap(find.text('Laminatsiya 1'));
    await tester.pumpAndSettle();
    await TestModeController.instance.setEnabled(false);
    await tester
        .tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
    await tester.pumpAndSettle();
    if (entrypoint == 'merge' || entrypoint == 'intake') {
      final action = find.byKey(ValueKey(entrypoint == 'merge'
          ? 'production-order-merge-action'
          : 'receive-additional-raw-material'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
    }
    expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
  }

  Future<void> Function(String) scanner(WidgetTester tester) => tester
      .widget<ProductionQuickScannerPanel>(
          find.byType(ProductionQuickScannerPanel))
      .onCodeDetected;

  void changePhase(String next, {bool publish = false}) {
    phase = next == 'active-no-merge' ? 'active' : next;
    if (next == 'active-no-merge') allowMerge = false;
    revision++;
    if (publish) events.add(snapshot());
  }
}

void _expectInlineWipGuidance(WidgetTester tester, String key,
    {Map<String, Object> values = const {}}) {
  final dialog = find.byKey(const ValueKey('production-wip-guidance-dialog'));
  expect(dialog, findsOneWidget);
  final l10n = AppLocalizations(const Locale('uz'));
  final message = l10n.productionText(key, values: {
    'apparatus': 'Laminatsiya 1',
    'order': 'Inline work',
    'action': l10n.productionText('worker.action.merge'),
    ...values,
  });
  expect(find.descendant(of: dialog, matching: find.textContaining(message)),
      findsOneWidget);
  expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
      findsNothing);
}

Future<void> _closeInlineWipGuidance(WidgetTester tester) async {
  final dialog = find.byKey(const ValueKey('production-wip-guidance-dialog'));
  if (dialog.evaluate().isEmpty) return;
  await tester.tap(find.descendant(
      of: dialog,
      matching: find.text(AppLocalizations(const Locale('uz'))
          .productionText('worker.action.close'))));
  await tester.pumpAndSettle();
}

void _registerInlineWipGuidanceTests() {
  testWidgets(
      'worker inline WIP guidance: initial queue QR is consumed once without a camera',
      (tester) async {
    final fixture = _InlineWipFixture('start')..consumeInitialQr = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      expect(find.byType(MobileScanner), findsNothing);
      expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
          findsNothing);
      final start = find.widgetWithText(FilledButton, 'Boshlash');
      expect(start, findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(
          find.text(AppLocalizations(const Locale('uz'))
              .productionText('worker.progress.previous.confirmed')),
          findsOneWidget);
      final lookupsBeforeLiveUpdate =
          fixture.requests.where((r) => r.url.path.endsWith('/lookup')).length;
      expect(lookupsBeforeLiveUpdate, 4,
          reason:
              'FAB and detail each identify once and validate one scoped route');
      fixture.changePhase('start', publish: true);
      await tester.pumpAndSettle();
      expect(fixture.requests.where((r) => r.url.path.endsWith('/lookup')),
          hasLength(lookupsBeforeLiveUpdate),
          reason: 'A live refresh must not replay the initial QR');
      expect(find.byType(ProductionQuickScannerPanel), findsNothing);
      expect(find.byType(MobileScanner), findsNothing);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'worker inline WIP guidance: waiting input enables explicit start',
      (tester) async {
    final fixture = _InlineWipFixture('start');
    await http.runWithClient(() async {
      await fixture.open(tester);
      final start = find.widgetWithText(FilledButton, 'Boshlash');
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      final scan = fixture.scanner(tester)(_inlineWipQr);
      await tester.pumpAndSettle();
      await scan;
      expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
          findsNothing);
      expect(
          find.text(AppLocalizations(const Locale('uz'))
              .productionText('worker.progress.previous.confirmed')),
          findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(fixture.mutations, isEmpty,
          reason: 'Selecting a valid input must wait for explicit Start');
    }, () => MockClient(fixture.respond));
  });

  for (final entrypoint in ['start', 'merge']) {
    testWidgets('worker inline WIP guidance: $entrypoint rejects another order',
        (tester) async {
      final fixture = _InlineWipFixture(entrypoint);
      await http.runWithClient(() async {
        await fixture.open(tester);
        final scan = fixture.scanner(tester)(_inlineOtherWipQr);
        await tester.pumpAndSettle();
        _expectInlineWipGuidance(tester, 'worker.qr.wrong_order_context',
            values: {
              'opened': 'Inline work',
              'order': 'Other inline work',
            });
        _expectInlineWipGuidance(tester, 'worker.qr.start_ready',
            values: {'order': 'Other inline work'});
        expect(fixture.mutations, isEmpty);
        expect(fixture.requests.where((r) => r.url.path.endsWith('/lookup')),
            isNotEmpty);
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final scenario in ['waiting', 'wrong-stage', 'in-use']) {
    testWidgets('worker inline WIP guidance: opening input $scenario',
        (tester) async {
      final fixture =
          _InlineWipFixture(scenario == 'in-use' ? 'merge' : 'start')
            ..useOpening = true
            ..openingStageRejected = scenario == 'wrong-stage'
            ..wipStatus = scenario == 'in-use' ? 'in_use' : 'waiting';
      await http.runWithClient(() async {
        await fixture.open(tester);
        final scan = fixture.scanner(tester)(_inlineWipQr);
        await tester.pumpAndSettle();
        if (scenario == 'waiting') {
          await scan;
          expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
              findsNothing);
          expect(
              find.text(AppLocalizations(const Locale('uz'))
                  .productionText('worker.progress.previous.confirmed')),
              findsOneWidget);
          expect(
              tester
                  .widget<FilledButton>(
                      find.widgetWithText(FilledButton, 'Boshlash'))
                  .onPressed,
              isNotNull);
          expect(
              find.descendant(
                  of: find.byKey(
                      const ValueKey('production-order-opening-wip-input')),
                  matching: find.text('QR: $_inlineWipQr')),
              findsOneWidget);
          final validated = fixture.requests.where((r) =>
              r.url.path.endsWith('/opening-wip/lookup') &&
              (jsonDecode(r.body) as Map)['qr_payload'] == _inlineWipQr);
          expect(validated, hasLength(1));
        } else {
          _expectInlineWipGuidance(
              tester,
              scenario == 'in-use'
                  ? 'worker.qr.roll_in_use'
                  : 'worker.opening_wip.qr_mismatch');
          await _closeInlineWipGuidance(tester);
          await scan;
        }
        expect(fixture.mutations, isEmpty);
        expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
            findsNothing);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final status in ['in_use', 'processed', 'unknown']) {
    testWidgets(
        'worker inline WIP guidance: merge validates $status before confirmation',
        (tester) async {
      final fixture = _InlineWipFixture('merge')..wipStatus = status;
      await http.runWithClient(() async {
        await fixture.open(tester);
        final scan = fixture.scanner(tester)(
            status == 'unknown' ? 'UNKNOWN-WIP-QR' : _inlineWipQr);
        await tester.pumpAndSettle();
        final key = status == 'in_use'
            ? 'worker.qr.roll_in_use'
            : status == 'processed'
                ? 'worker.error.wip_used'
                : 'worker.qr.not_found';
        if (status == 'unknown') {
          expect(
              find.textContaining(
                  AppLocalizations(const Locale('uz')).productionText(key)),
              findsWidgets);
        } else {
          _expectInlineWipGuidance(tester, key);
          if (status == 'in_use') {
            final dialog =
                find.byKey(const ValueKey('production-wip-guidance-dialog'));
            expect(
                find.descendant(
                    of: dialog,
                    matching: find.textContaining(
                        AppLocalizations(const Locale('uz'))
                            .productionText('worker.qr.loaded_active'))),
                findsOneWidget);
            expect(
                find.descendant(
                    of: dialog,
                    matching: find.textContaining(
                        AppLocalizations(const Locale('uz'))
                            .productionText('worker.action.merge'))),
                findsNothing);
          }
        }
        expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
            findsNothing);
        expect(fixture.mutations, isEmpty);
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets(
      'worker inline WIP guidance: waiting merge validates and confirms once',
      (tester) async {
    final fixture = _InlineWipFixture('merge')
      ..mutationGate = Completer<void>();
    await http.runWithClient(() async {
      await fixture.open(tester);
      final scanner = fixture.scanner(tester);
      final scan = scanner(_inlineWipQr);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
          findsOneWidget);
      expect(fixture.mutations, isEmpty);
      final lookups = fixture.requests
          .where((r) => r.url.path.endsWith('/lookup'))
          .toList();
      expect(lookups.length, greaterThanOrEqualTo(2));
      expect(jsonDecode(lookups.first.body), isNot(contains('apparatus')));
      expect(
          lookups.any((r) =>
              (jsonDecode(r.body) as Map)['apparatus'] == _lamination1Id),
          isTrue);
      await scanner(_inlineWipQr);
      await scanner(_inlineOtherWipQr);
      await tester.pump();
      expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
          findsOneWidget);
      expect(fixture.mutations, isEmpty);
      await tester.tap(find.byKey(const ValueKey('production-merge-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(fixture.mutations, hasLength(1));
      expect(jsonDecode(fixture.mutations.single.body),
          containsPair('action', 'merge'));
      expect(jsonDecode(fixture.mutations.single.body),
          containsPair('qr_payload', _inlineWipQr));
      expect(jsonDecode(fixture.mutations.single.body),
          containsPair('order_id', _inlineOrderId));
      expect(jsonDecode(fixture.mutations.single.body),
          containsPair('apparatus', _lamination1Id));
      await scanner(_inlineWipQr);
      await scanner(_inlineOtherWipQr);
      expect(fixture.mutations, hasLength(1));
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      await scan;
      expect(fixture.mutations, hasLength(1));
      expect(find.textContaining('2-rulon 1-rulonning davomiga ulandi.'),
          findsWidgets);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'worker inline WIP guidance: material intake distinguishes WIP from raw material',
      (tester) async {
    final fixture = _InlineWipFixture('intake');
    await http.runWithClient(() async {
      await fixture.open(tester);
      final scan = fixture.scanner(tester)(_inlineWipQr);
      await tester.pumpAndSettle();
      _expectInlineWipGuidance(tester, 'worker.qr.material_mode');
      _expectInlineWipGuidance(tester, 'worker.qr.active_merge');
      expect(fixture.mutations, isEmpty,
          reason: 'A WIP QR must never enter raw-material intake');
      await _closeInlineWipGuidance(tester);
      await scan;
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  for (final rejection in [
    'merge_input_already_used',
    'queue_action_not_allowed',
    'apparatus_busy'
  ]) {
    testWidgets(
        'worker inline WIP guidance: confirmed merge explains POST $rejection',
        (tester) async {
      final fixture = _InlineWipFixture('merge')
        ..mutationRejection = rejection
        ..rejectionPhase = rejection == 'queue_action_not_allowed'
            ? 'paused'
            : rejection == 'apparatus_busy'
                ? 'busy'
                : null;
      await http.runWithClient(() async {
        await fixture.open(tester);
        final scanner = fixture.scanner(tester);
        final scan = scanner(_inlineWipQr);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
            findsOneWidget);
        expect(fixture.mutations, isEmpty);
        await tester
            .tap(find.byKey(const ValueKey('production-merge-confirm')));
        await tester.pumpAndSettle();
        final key = switch (rejection) {
          'merge_input_already_used' => 'worker.error.merge_input_already_used',
          'queue_action_not_allowed' => 'worker.qr.paused_resume',
          _ => 'worker.waiting.apparatus_busy_detail',
        };
        _expectInlineWipGuidance(tester, key, values: {
          if (rejection == 'queue_action_not_allowed')
            'action': AppLocalizations(const Locale('uz'))
                .productionText('worker.action.resume'),
          if (rejection == 'apparatus_busy') 'order': 'Other inline work',
        });
        expect(fixture.mutations, hasLength(1));
        expect(find.textContaining('2-rulon 1-rulonning davomiga ulandi.'),
            findsNothing);
        await scanner(_inlineWipQr);
        await scanner(_inlineOtherWipQr);
        expect(fixture.mutations, hasLength(1));
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(fixture.mutations, hasLength(1));
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets(
      'worker inline WIP guidance: resume Qolip scanner explains scanned WIP',
      (tester) async {
    final fixture = _InlineWipFixture('resume');
    await http.runWithClient(() async {
      await fixture.open(tester);
      final scan = fixture.scanner(tester)(_inlineWipQr);
      await tester.pumpAndSettle();
      _expectInlineWipGuidance(tester, 'worker.qr.paused_resume', values: {
        'action': AppLocalizations(const Locale('uz'))
            .productionText('worker.action.resume'),
      });
      _expectInlineWipGuidance(tester, 'worker.qr.resume_molds');
      expect(fixture.mutations, isEmpty);
      final resume = find.widgetWithText(FilledButton, 'Davom ettirish');
      expect(resume, findsOneWidget);
      expect(tester.widget<FilledButton>(resume).onPressed, isNull,
          reason: 'WIP cannot satisfy the pending Qolip scan');
      await _closeInlineWipGuidance(tester);
      await scan;
    }, () => MockClient(fixture.respond));
  });

  for (final phase in ['active', 'paused', 'frozen', 'busy']) {
    testWidgets(
        'worker inline WIP guidance: start refreshes $phase during lookup',
        (tester) async {
      final fixture = _InlineWipFixture('start')
        ..lookupGate = Completer<void>();
      await http.runWithClient(() async {
        await fixture.open(tester);
        final scanner = fixture.scanner(tester);
        final scan = scanner(_inlineWipQr);
        await tester.pump();
        await scanner(_inlineWipQr);
        expect(fixture.requests.where((r) => r.url.path.endsWith('/lookup')),
            hasLength(1));
        fixture.changePhase(phase);
        fixture.lookupGate!.complete();
        await tester.pumpAndSettle();
        final key = switch (phase) {
          'active' => 'worker.qr.active_merge',
          'paused' => 'worker.qr.paused_resume',
          'frozen' => 'worker.freeze.named',
          _ => 'worker.waiting.apparatus_busy_detail',
        };
        _expectInlineWipGuidance(tester, key, values: {
          if (phase == 'paused')
            'action': AppLocalizations(const Locale('uz'))
                .productionText('worker.action.resume'),
          if (phase == 'busy') 'order': 'Other inline work',
        });
        expect(fixture.mutations, isEmpty);
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final phase in ['active', 'paused', 'frozen', 'busy']) {
    testWidgets(
        'worker inline WIP guidance: late callback explains live $phase state',
        (tester) async {
      final fixture = _InlineWipFixture('start');
      await http.runWithClient(() async {
        await fixture.open(tester);
        final oldScanner = fixture.scanner(tester);
        fixture.changePhase(phase, publish: true);
        await tester.pumpAndSettle();
        expect(find.byType(ProductionQuickScannerPanel), findsNothing);
        final scan = oldScanner(_inlineWipQr);
        await tester.pumpAndSettle();
        final key = switch (phase) {
          'active' => 'worker.qr.active_merge',
          'paused' => 'worker.qr.paused_resume',
          'frozen' => 'worker.freeze.named',
          _ => 'worker.waiting.apparatus_busy_detail',
        };
        _expectInlineWipGuidance(tester, key, values: {
          if (phase == 'paused')
            'action': AppLocalizations(const Locale('uz'))
                .productionText('worker.action.resume'),
          if (phase == 'busy') 'order': 'Other inline work',
        });
        expect(fixture.mutations, isEmpty);
        await _closeInlineWipGuidance(tester);
        await scan;
      }, () => MockClient(fixture.respond));
    });
  }

  for (final phase in ['active-no-merge', 'paused', 'frozen', 'busy']) {
    testWidgets(
        'worker inline WIP guidance: merge refreshes $phase after confirmation',
        (tester) async {
      final fixture = _InlineWipFixture('merge');
      await http.runWithClient(() async {
        await fixture.open(tester);
        final scan = fixture.scanner(tester)(_inlineWipQr);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('production-merge-confirm-dialog')),
            findsOneWidget);
        expect(fixture.mutations, isEmpty);
        fixture.changePhase(phase);
        await tester
            .tap(find.byKey(const ValueKey('production-merge-confirm')));
        await tester.pumpAndSettle();
        final key = switch (phase) {
          'active-no-merge' => 'worker.qr.active',
          'paused' => 'worker.qr.paused_resume',
          'frozen' => 'worker.freeze.named',
          _ => 'worker.waiting.apparatus_busy_detail',
        };
        _expectInlineWipGuidance(tester, key, values: {
          if (phase == 'paused')
            'action': AppLocalizations(const Locale('uz'))
                .productionText('worker.action.resume'),
          if (phase == 'busy') 'order': 'Other inline work',
        });
        expect(fixture.mutations, isEmpty);
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }
}
