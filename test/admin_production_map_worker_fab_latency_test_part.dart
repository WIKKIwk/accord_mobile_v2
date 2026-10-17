part of 'admin_production_map_test_screen_test.dart';

class _WorkerFabLatencyFixture extends _WorkerQrWindowFixture {
  _WorkerFabLatencyFixture(this.mode)
      : super(mode == 'hidden search' ? 'search' : 'limit 10');

  final String mode;
  Completer<void>? aggregateGate;
  final aggregateStarted = Completer<void>();
  Completer<void>? wipGate;
  final wipReadStarted = Completer<void>();

  @override
  Map<String, dynamic> control({bool other = false}) => {
        ...super.control(other: other),
        if (!other && mode == 'complete sections')
          'interaction': {
            ...(super.control(other: other)['interaction'] as Map),
            'start_materials_mode': 'scan_required',
            'material_scan_required': true,
            'qolip_mode': 'scan_required',
          },
      };

  Map<String, dynamic> validatedProgress() => {
        'ok': true,
        'batch': batch(),
        'active_order_validated': true,
        'validated_apparatus': station,
        'validated_order_id': _inlineOrderId,
        'input_route': {
          'source_stage_node_id': 'first-apparatus',
          'stage_node_id': 'second-apparatus',
          'consumer_apparatus_ids': [station],
          'map_fingerprint': 'fab-latency-map',
          'remapped': false,
        },
      };

  Map<String, dynamic> aggregate() {
    final current = control();
    final responseRevision =
        mode == 'stale aggregate' ? revision - 1 : revision;
    final context = sequence()
      ..['rev'] = responseRevision
      ..['scope'] = 'fab-scoped-context'
      ..['sequences'] = {
        station: [_inlineOrderId]
      }
      ..['visible_order_ids'] = {
        station: [_inlineOrderId]
      }
      ..['queue_states'] = {
        station: {_inlineOrderId: current['state']}
      }
      ..['queue_action_controls'] = {
        station: {_inlineOrderId: current}
      }
      ..['order_controls'] = {
        _inlineOrderId: {'state': 'active'}
      }
      ..['maps'] = [
        {
          'map': maps.first.map.toJson(),
          'program': {'map_id': _inlineOrderId, 'operations': []},
        },
      ];
    return {
      'ok': true,
      'control_state': {
        'apparatus': station,
        'order_id': _inlineOrderId,
        'rev': responseRevision,
        'epoch': 'inline-server',
        'scope': 'fab-scoped-context',
        'control': current,
        'queue_state': current['state'],
        'stage_states': {},
        'order_control': 'active',
      },
      'queue_context': context,
      'validated_progress': validatedProgress(),
      'sections': {
        'materials': {
          'status': 'ready',
          'data': {
            'policy': 'state_all',
            'requires_material': false,
            'material_scan_required': mode == 'complete sections',
            'requirement_groups': [],
            'assigned_barcodes': [],
            'staged_barcodes': [],
            'eligible_barcodes': [],
            'required_scan_count': 0,
            'matched_scan_count': 0,
            'assignments_satisfied': true,
            'scan_satisfied': true,
            'assignments': [],
            'start_assignments': [],
          },
        },
        'qolips': {
          'status': 'ready',
          'data': mode == 'complete sections'
              ? scanQolips()
              : {
                  'ok': true,
                  'qolip': {
                    'qolip_code': '',
                    'required_qolip_count': 0,
                    'required_qolip_codes': [],
                    'required_qolips': [],
                  },
                },
        },
      },
    };
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/progress-qr/lookup')) {
      requests.add(request);
      return http.Response(jsonEncode(validatedProgress()), 200);
    }
    if (request.url.path.endsWith('/order-scan-bootstrap')) {
      requests.add(request);
      if (!aggregateStarted.isCompleted) aggregateStarted.complete();
      if (aggregateGate != null) await aggregateGate!.future;
      if (mode == 'consumed during sections' &&
          request.url.queryParameters['include_sections'] == 'false' &&
          request.url.queryParameters['qr_payload'] == _inlineWipQr) {
        return http.Response('{"error":"progress_batch_in_use"}', 409);
      }
      if (mode == 'old server') return http.Response('', 404);
      if (mode == 'forbidden aggregate') {
        return http.Response('{"error":"forbidden"}', 403);
      }
      return http.Response(jsonEncode(aggregate()), 200);
    }
    if (wipGate != null && request.url.path.endsWith('/wip-batches')) {
      requests.add(request);
      if (!wipReadStarted.isCompleted) wipReadStarted.complete();
      await wipGate!.future;
      return http.Response('{"batches":[]}', 200);
    }
    return super.respond(request);
  }

  AdminProductionMapLiveSnapshot targetUnchangedLive() =>
      AdminProductionMapLiveSnapshot(
        maps: maps,
        sequences: {
          station: [_inlineOrderId, _inlineOtherOrderId]
        },
        visibleOrderIds: {
          station: [_inlineOrderId, _inlineOtherOrderId]
        },
        queueStates: {
          station: {
            _inlineOrderId: control()['state'] as String,
            _inlineOtherOrderId: control(other: true)['state'] as String,
          },
        },
        queuePolicies: const {},
        queueActionControls: {
          station: {
            _inlineOrderId:
                AdminApparatusQueueOrderActionControl.fromJson(control()),
            _inlineOtherOrderId: AdminApparatusQueueOrderActionControl.fromJson(
                control(other: true)),
          },
        },
        orderControls: const {},
        completedOrders: const [],
        completionRequests: const [],
        completionRequestDecisions: const [],
        revision: revision,
        epoch: 'inline-server',
        scope: 'worker-window-10',
      );
}

List<http.Request> _fabLatencyRequests(
        _WorkerFabLatencyFixture fixture, int startingAt) =>
    fixture.requests.skip(startingAt).toList(growable: false);

void _expectNoFabBackgroundRefresh(List<http.Request> reads) {
  expect(
      reads.where((request) =>
          request.url.path.endsWith('/apparatus') ||
          request.url.path.endsWith('/completed-orders') ||
          request.url.path.endsWith('/completion-request-decisions') ||
          request.url.path.endsWith('/progress-qr/history') ||
          (request.url.path.endsWith('/sequence') &&
              !request.url.queryParameters.containsKey('apparatus'))),
      isEmpty,
      reason: 'Preparing a QR order must not refresh the main queue, catalog, '
          'or worker history');
}

void _registerWorkerFabLatencyTests() {
  testWidgets(
      'worker FAB QR bounded startup: prepared WIP consumed during sections',
      (tester) async {
    final fixture = _WorkerFabLatencyFixture('consumed during sections')
      ..wipGate = Completer<void>();
    await http.runWithClient(() async {
      try {
        await fixture.openWindow(tester);
        final scan = tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('return-window-qr')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(fixture.wipReadStarted.isCompleted, isTrue);
        // WIP can be consumed by another worker without changing this order's
        // action-control signature. A newer global revision invalidates proof.
        fixture.revision++;
        fixture.wipStatus = 'in_use';
        fixture.events.add(fixture.targetUnchangedLive());
        await tester.pump();
        fixture.wipGate!.complete();
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await _closeInlineWipGuidance(tester);
        await tester.pumpAndSettle();
        await scan;
        final revalidations = fixture.requests.where((request) =>
            request.url.path.endsWith('/order-scan-bootstrap') &&
            request.url.queryParameters['include_sections'] == 'false' &&
            request.url.queryParameters['qr_payload'] == _inlineWipQr);
        expect(revalidations, hasLength(1));
        final start = find.widgetWithText(FilledButton, 'Boshlash');
        expect(
            tester
                .widgetList<FilledButton>(start)
                .every((button) => button.onPressed == null),
            isTrue,
            reason: 'A stale one-use proof must not enable Start after the '
                'server rejects WIP revalidation');
        expect(
            find.text(AppLocalizations(const Locale('uz'))
                .productionText('worker.progress.previous.confirmed')),
            findsNothing);
        expect(fixture.mutations, isEmpty);
      } finally {
        if (!fixture.wipGate!.isCompleted) fixture.wipGate!.complete();
        dismissAdminTopNotice();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await fixture.events.close();
      }
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  for (final mode in [
    'hidden limit',
    'hidden search',
    'complete sections',
    'old server',
    'forbidden aggregate',
    'stale aggregate',
  ]) {
    testWidgets('worker FAB QR bounded startup: $mode', (tester) async {
      final fixture = _WorkerFabLatencyFixture(mode);
      await http.runWithClient(() async {
        try {
          await fixture.openWindow(tester);
          final firstScanRequest = fixture.requests.length;
          await fixture.scanFab(tester);
          final reads = _fabLatencyRequests(fixture, firstScanRequest);
          final sheet = find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');
          final start = find.widgetWithText(FilledButton, 'Boshlash');
          if (mode == 'forbidden aggregate' || mode == 'stale aggregate') {
            expect(sheet, findsNothing);
            expect(start, findsNothing);
            expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
                findsOneWidget);
            expect(
                reads.where((request) =>
                    request.url.path.endsWith('/sequence') ||
                    request.url.path.endsWith('/production-maps')),
                isEmpty,
                reason: 'A denied or stale aggregate cannot authorize a '
                    'legacy fallback');
            expect(reads.length, lessThanOrEqualTo(3),
                reason: 'Aggregate disagreement has only a bounded retry');
          } else {
            expect(sheet, findsOneWidget,
                reason: tester
                    .widgetList<Text>(find.byType(Text))
                    .map((text) => text.data)
                    .toList()
                    .toString());
            expect(find.text('0062'), findsOneWidget);
            expect(start, findsOneWidget);
            expect(tester.widget<FilledButton>(start).onPressed,
                mode == 'complete sections' ? isNull : isNotNull,
                reason: tester
                    .widgetList<Text>(find.byType(Text))
                    .map((text) => text.data)
                    .toList()
                    .toString());
            expect(find.byType(ProductionQuickScannerPanel),
                mode == 'complete sections' ? findsOneWidget : findsNothing,
                reason:
                    'Unscanned Qolips keep their existing scanner and gate');
            if (mode != 'old server') {
              final aggregates = reads.where((request) =>
                  request.url.path.endsWith('/order-scan-bootstrap'));
              expect(aggregates, hasLength(1),
                  reason: 'The FAB aggregate is handed into the sheet once');
              expect(aggregates.single.url.queryParameters['include_context'],
                  'true');
              expect(aggregates.single.url.queryParameters['qr_payload'],
                  _inlineWipQr);
              expect(aggregates.single.url.queryParameters['include_sections'],
                  isNot('false'));
              expect(
                  reads.where((request) =>
                      request.url.path.endsWith('/progress-qr/lookup')),
                  hasLength(1),
                  reason: 'The scoped aggregate validation must replace QR '
                      'replays in the sheet');
              expect(
                  reads.where((request) =>
                      request.url.path.endsWith('/sequence') ||
                      request.url.path.endsWith('/production-maps')),
                  isEmpty,
                  reason: 'The aggregate already contains the target map and '
                      'station controls');
              final images = reads
                  .where((read) => read.url.path.endsWith('/order-image/view'))
                  .toList();
              final dataReads = reads
                  .where((read) => !read.url.path.endsWith('/order-image/view'))
                  .toList();
              expect(images.length, lessThanOrEqualTo(1));
              expect(dataReads.length, lessThanOrEqualTo(4),
                  reason:
                      'Modern startup consists of identification, aggregate, '
                      'and at most the existing assignment/WIP section reads: '
                      '${reads.map((read) => '${read.method} ${read.url.path}').toList()}');
              if (mode == 'complete sections') {
                expect(
                    reads.where((request) =>
                        request.url.path
                            .endsWith('/raw-material-assignments') ||
                        request.url.path
                            .endsWith('/raw-material-start-requirements') ||
                        request.url.path.endsWith('/qolip-validate')),
                    isEmpty,
                    reason: 'Complete material/Qolip sections are reused');
              }
            } else {
              expect(
                  reads.where((request) =>
                      request.url.path.endsWith('/sequence') &&
                      request.url.queryParameters['apparatus'] ==
                          _lamination1Id),
                  isNotEmpty,
                  reason: 'A positively unsupported aggregate retains the '
                      'existing scoped fallback');
              expect(reads.length, lessThanOrEqualTo(16));
            }
          }
          _expectNoFabBackgroundRefresh(reads);
          expect(fixture.mutations, isEmpty,
              reason: 'Scanning prepares Start without executing it');
          expect(find.text('Ko‘rsatish: 10 ta'), findsOneWidget);
          if (mode == 'hidden search') {
            expect(fixture.windowReads.last.url.queryParameters['queue_search'],
                'Other visible');
          }
        } finally {
          dismissAdminTopNotice();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await fixture.events.close();
        }
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets(
      'worker FAB QR bounded startup: delayed aggregate after session change',
      (tester) async {
    final fixture = _WorkerFabLatencyFixture('hidden limit')
      ..aggregateGate = Completer<void>();
    await http.runWithClient(() async {
      try {
        await fixture.openWindow(tester);
        final scan = tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('return-window-qr')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(fixture.aggregateStarted.isCompleted, isTrue);
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Different worker',
          legalName: '',
          ref: 'different-latency-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_lamination1Id],
        );
        fixture.aggregateGate!.complete();
        await tester.pumpAndSettle();
        await scan;
        expect(
            find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
            findsNothing);
        expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing);
        expect(fixture.mutations, isEmpty);
      } finally {
        if (!fixture.aggregateGate!.isCompleted)
          fixture.aggregateGate!.complete();
        dismissAdminTopNotice();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await fixture.events.close();
      }
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });
}
