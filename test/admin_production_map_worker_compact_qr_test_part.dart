part of 'admin_production_map_test_screen_test.dart';

/// The existing QR fixture's real HTTP window now contains only compact rows.
/// Scoped reads and legacy/opening QR routing retain the full canonical graph.
class _CompactWorkerQrFixture extends _WorkerQrWindowFixture {
  _CompactWorkerQrFixture(super.scenario);

  final workerDetailReads = <String>[];

  bool get pendingReport => scenario == 'unfinished report while upstream open';

  @override
  Map<String, dynamic> control({bool other = false}) {
    final result = super.control(other: other);
    if (!pendingReport || !other) return result;
    return {
      ...result,
      'state': 'paused',
      'allowed_actions': ['resume'],
      'interaction': {
        ...result['interaction'] as Map,
        'mode': 'paused',
        'resume_input_required': false,
        'previous_wip_mode': 'not_required',
      },
      'stage_work': {
        'upstream_closed': false,
        'astatka_available': true,
        'astatka_required': true,
        'report_session_id': 'unfinished-current-report',
        'upstream_title': 'Still running upstream machine',
      },
    };
  }

  @override
  Future<void> openWindow(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Window worker',
      legalName: '',
      ref: 'qr-window-worker',
      phone: '',
      avatarUrl: '',
      capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [station],
    );
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    maps = [
      for (final other in [false, true])
        ProductionMapSaved.fromJson({
          'map': _twoStageProductionOrderMap(
            id: other ? _inlineOtherOrderId : _inlineOrderId,
            title: other ? 'Other visible order' : 'Order outside window',
            productCode: other ? 'VISIBLE' : 'OUTSIDE',
            product: 'Window product',
            firstApparatusId: _print9Id,
            secondApparatusId:
                !other && scenario == 'wrong route' ? _rezkaId : station,
          ).copyWith(orderNumber: other ? '0001' : '0062').toJson(),
          'program': <String, dynamic>{},
        }),
    ];
    await TestModeController.instance.setEnabled(false);
    await _usePhoneViewport(tester);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      onGenerateRoute: (_) => MaterialPageRoute<String>(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('return-window-qr'),
            onPressed: () => Navigator.of(context).pop(_inlineWipQr),
            child: const Text('Scan window WIP'),
          ),
        ),
      ),
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        apparatusLoader: () async => apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    for (var frame = 0;
        frame < 12 && find.text('Ko‘rsatish: 10 ta').evaluate().isEmpty;
        frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.text('Ko‘rsatish: 10 ta'), findsOneWidget);
    expect(find.byKey(const ValueKey('worker-order-$_inlineOrderId')),
        findsNothing);
    if (scenario == 'search') {
      await tester.enterText(find.byType(EditableText).first, 'Other visible');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(windowReads.last.url.queryParameters['queue_search'],
          'Other visible');
    }
  }

  @override
  Map<String, dynamic> windowSequence() {
    final body = super.windowSequence();
    final maps = (body['maps'] as List).cast<Map>();
    final rows = <String, dynamic>{};
    for (final saved in maps) {
      final map = (saved['map'] as Map).cast<String, dynamic>();
      rows[map['id'] as String] = {
        'id': map['id'],
        'code': (map['code'] as String? ?? '').isNotEmpty
            ? map['code']
            : map['order_number'] ?? '',
        'title': map['title'] ?? '',
        'customer_name': map['customer_name'] ?? '',
        'image_id': map['image_id'] ?? '',
      };
    }
    final states = (body['queue_states'] as Map).cast<String, dynamic>();
    for (final key in const [
      'maps',
      'queue_action_controls',
      'stage_states',
      'order_statuses',
      'frozen_orders_by_apparatus',
      'stage_order_controls',
      'order_customers',
      'calculation_templates',
    ]) {
      body.remove(key);
    }
    return {
      ...body,
      'projection': 'worker_list_v1',
      'worker_list_rows': rows,
      'worker_display_states': {
        for (final apparatus in states.entries)
          apparatus.key: {
            for (final order in (apparatus.value as Map).entries)
              order.key: order.value,
          },
      },
      'worker_report_prompts': <String, dynamic>{},
      'worker_pending_report_ids': {
        if (pendingReport) station: [_inlineOtherOrderId],
      },
      'completed_orders': <Object>[],
      'completion_requests': <Object>[],
      'completion_request_decisions': <Object>[],
    };
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/sequence') &&
        request.url.queryParameters['detail'] == 'true' &&
        request.url.queryParameters['worker_scope'] == 'true') {
      requests.add(request);
      scopedControlReads++;
      final id = request.url.queryParameters['order_id']!;
      workerDetailReads.add(id);
      final body = sequence();
      body['projection'] = 'worker_detail_v1';
      body['scope'] = 'compact-qr-worker-detail-$id';
      body['maps'] = [
        for (final order in maps.where((order) => order.map.id == id))
          {
            'map': order.map.toJson(),
            'program': <String, dynamic>{},
          },
      ];
      return http.Response(jsonEncode(body), 200);
    }
    return super.respond(request);
  }

  @override
  AdminProductionMapLiveSnapshot snapshot() =>
      AdminProductionMapLiveSnapshot.fromJson(windowSequence());
}

void _registerCompactWorkerQrTests() {
  for (final scenario in const [
    'limit 10',
    'opening WIP',
    'handoff return',
    'handoff return with hidden current',
    'frozen',
    'wrong route',
    'stale bootstrap',
    'unfinished report while upstream open',
  ]) {
    testWidgets('compact worker FAB QR: $scenario', (tester) async {
      final fixture = _CompactWorkerQrFixture(scenario);
      await http.runWithClient(() async {
        try {
          await fixture.openWindow(tester);
          expect(fixture.snapshot().maps, isEmpty);
          expect(fixture.snapshot().queueActionControls, isEmpty);
          expect(
              fixture.requests.where(
                  (request) => request.url.path.endsWith('/calculate/orders')),
              isEmpty,
              reason:
                  'Compact worker bootstrap cannot fetch every calculation template');
          expect(fixture.workerDetailReads, isEmpty);
          expect(fixture.mapReads, 0,
              reason:
                  'Full graphs are demand-loaded after the explicit QR scan');
          expect(
              fixture.windowReads.every((request) =>
                  request.url.queryParameters['projection'] ==
                  'worker_list_v1'),
              isTrue);
          await fixture.scanFab(tester);
          final sheet = find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');
          if (scenario.startsWith('handoff return')) {
            expect(
                find.byKey(const ValueKey('production-switch-order-confirm')),
                findsOneWidget);
            await tester.tap(find.text(AppLocalizations(const Locale('uz'))
                .productionText('worker.action.no')));
            await tester.pumpAndSettle();
            expect(sheet, findsOneWidget);
            final dynamic busy = tester.widget(sheet);
            expect((busy.order as ProductionMapSaved).map.nodes, isNotEmpty);
            expect([...fixture.mapReadOrderIds, ...fixture.workerDetailReads],
                contains(_inlineOtherOrderId),
                reason:
                    'Busy current work may be outside every compact list row');
          } else if (fixture.pendingReport) {
            expect(fixture.snapshot().workerReportPrompts, isEmpty,
                reason:
                    'Upstream still open must not create an automatic prompt');
            expect(fixture.workerDetailReads, contains(_inlineOtherOrderId),
                reason:
                    'QR preserves an unfinished current report without full list controls');
            expect(sheet, findsOneWidget);
            final dynamic current = tester.widget(sheet);
            expect((current.order as ProductionMapSaved).map.id,
                _inlineOtherOrderId);
            expect((current.order as ProductionMapSaved).map.nodes, isNotEmpty);
          } else if (const ['frozen', 'wrong route', 'stale bootstrap']
              .contains(scenario)) {
            expect(sheet, findsNothing);
            expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
                findsOneWidget);
            expect(find.widgetWithText(FilledButton, 'Boshlash'), findsNothing);
          } else {
            expect(sheet, findsOneWidget);
            final dynamic loaded = tester.widget(sheet);
            expect((loaded.order as ProductionMapSaved).map.nodes, isNotEmpty,
                reason:
                    'QR must hydrate a canonical graph before action authority');
            expect((loaded.order as ProductionMapSaved).map.id, _inlineOrderId);
            final start = find.widgetWithText(FilledButton, 'Boshlash');
            expect(start, findsOneWidget);
            expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
          }
          expect(fixture.mutations, isEmpty,
              reason:
                  'A QR scan may prepare, but never execute a production action');
          expect(
              fixture.windowReads.every((request) =>
                  request.url.queryParameters['queue_limit'] == '10'),
              isTrue);
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
}
