part of 'admin_production_map_test_screen_test.dart';

const _tabQrRezkaIds = [
  _rezkaId,
  'apparatus:default:asset-011',
  'apparatus:default:asset-012',
  'apparatus:default:asset-013',
  'apparatus:default:asset-014',
];
const _tabQrSelectedId = 'apparatus:default:asset-013';

class _WorkerTabQrFixture extends _TemporaryPauseFixture {
  _WorkerTabQrFixture({
    this.selectedBusy = false,
    this.routeMismatch = false,
    this.unassignedSelected = false,
    this.routeMetadata = true,
  }) : super(station: _tabQrSelectedId);

  final bool selectedBusy;
  final bool routeMismatch;
  final bool unassignedSelected;
  final bool routeMetadata;
  final scopedLookups = <String>[];
  int scannerRoutes = 0;

  Map<String, dynamic> stationControl(String id, {required bool incoming}) {
    final busy =
        id == _rezkaId || (id == station && selectedBusy && !temporarilyPaused);
    final state = incoming
        ? 'pending'
        : busy
            ? 'in_progress'
            : temporarilyPaused && id == station
                ? 'paused'
                : 'pending';
    return {
      'state': state,
      'stage_node_id': 'cut-${_tabQrRezkaIds.indexOf(id)}',
      'previous_stage': _lamination1Id,
      'previous_stage_ready': true,
      'complete_requires_full_report': false,
      'allowed_actions': incoming
          ? busy
              ? <String>[]
              : ['start']
          : busy
              ? ['pause', 'complete']
              : state == 'paused'
                  ? ['resume']
                  : ['start'],
      if (!incoming && busy)
        'temporary_pause': {
          'session_id': 'running-$id',
          'token': pauseToken,
        },
      'temporarily_paused': !incoming && state == 'paused',
      'interaction': {
        'mode': incoming && busy
            ? 'fresh_start_blocked'
            : state == 'in_progress'
                ? 'in_progress'
                : state == 'paused'
                    ? 'paused'
                    : 'fresh_start',
        'start_materials_mode': 'hidden',
        'material_scan_required': false,
        'assigned_materials_display_only': true,
        'material_intake_allowed': false,
        'previous_wip_mode': incoming ? 'scan_required' : 'not_required',
        'opening_wip_mode': 'not_required',
        'qolip_mode': 'not_required',
        'resume_input_required': false,
        'blocking_reason_code': incoming && busy ? 'apparatus_busy' : '',
      },
    };
  }

  @override
  Map<String, dynamic> sequence() => {
        'ok': true,
        'rev': revision,
        'epoch': 'inline-server',
        'scope': '',
        if (unassignedSelected) 'worker_show_all_apparatus_tabs': true,
        'maps': [
          for (final order in maps)
            {'map': order.map.toJson(), 'program': <String, dynamic>{}},
        ],
        'sequences': {
          for (final id in _tabQrRezkaIds)
            id: [_inlineOrderId, _inlineOtherOrderId],
        },
        'visible_order_ids': {
          for (final id in _tabQrRezkaIds)
            id: [_inlineOrderId, _inlineOtherOrderId],
        },
        'queue_states': {
          for (final id in _tabQrRezkaIds)
            id: {
              _inlineOrderId: stationControl(id, incoming: false)['state'],
              _inlineOtherOrderId: stationControl(id, incoming: true)['state'],
            },
        },
        'queue_action_controls': {
          for (final id in _tabQrRezkaIds)
            id: {
              _inlineOrderId: stationControl(id, incoming: false),
              _inlineOtherOrderId: stationControl(id, incoming: true),
            },
        },
        'queue_policies': [],
        'stage_states': {},
        'order_controls': {},
        'order_statuses': {},
        'frozen_orders_by_apparatus': {},
      };

  ProductionMapSaved savedOrder({required bool incoming}) =>
      ProductionMapSaved.fromJson({
        'map': {
          'id': incoming ? _inlineOtherOrderId : _inlineOrderId,
          'order_number': incoming ? '0243' : '0055',
          'title': incoming ? 'CU 737' : 'BINGO SARIQ',
          'product_code': incoming ? 'CU737' : 'BINGO',
          'nodes': [
            {'id': 'start', 'kind': 'start', 'title': 'Start'},
            {
              'id': 'lamination',
              'kind': 'apparatus',
              'title': 'Laminatsiya 1',
              'apparatus_id': _lamination1Id,
            },
            for (var index = 0; index < _tabQrRezkaIds.length; index++)
              {
                'id': 'cut-$index',
                'kind': 'apparatus',
                'title': index == 0 ? 'Rezka' : 'Rezka ${index + 1}',
                'apparatus_id': _tabQrRezkaIds[index],
                'alternative_group_id': 'all-cutting-machines',
              },
            {'id': 'end', 'kind': 'end', 'title': 'Finished'},
          ],
          'edges': [
            {'from': 'start', 'to': 'lamination'},
            for (var index = 0; index < _tabQrRezkaIds.length; index++) ...[
              {'from': 'lamination', 'to': 'cut-$index'},
              {'from': 'cut-$index', 'to': 'end'},
            ],
          ],
        },
        'program': <String, dynamic>{},
      });

  @override
  Map<String, dynamic> batch({bool other = false}) => {
        ...super.batch(other: other),
        'apparatus': _lamination1Id,
        'next_apparatus': _rezkaId,
        'payload_json': {'next_stage_node_id': 'cut-0'},
      };

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/lookup')) {
      requests.add(request);
      final body = jsonDecode(request.body) as Map;
      if (body['apparatus'] != null) {
        scopedLookups.add(body['apparatus'] as String);
      }
      if (lookupGate != null) await lookupGate!.future;
      return http.Response(
          jsonEncode({
            'batch': batch(other: true),
            'active_order_validated': true,
            if (body['apparatus'] != null) ...{
              'validated_apparatus': body['apparatus'],
              'validated_order_id': body['order_id'],
            },
            if (routeMetadata)
              'input_route': {
                'source_stage_node_id': 'lamination',
                'stage_node_id': 'cut-0',
                'consumer_apparatus_ids':
                    routeMismatch ? [_rezkaId] : _tabQrRezkaIds,
                'map_fingerprint': 'five-cutting-machines',
                'remapped': false,
              },
          }),
          200);
    }
    if (request.url.path.endsWith('/queue-action')) {
      requests.add(request);
      mutations.add(request);
      return http.Response('{"error":"queue_action_not_allowed"}', 409);
    }
    return super.respond(request);
  }

  Future<void> openTabs(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Five-machine worker',
      legalName: '',
      ref: 'inline-new-shift',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [
        for (final id in _tabQrRezkaIds)
          if (!unassignedSelected || id != station) id,
      ],
    );
    apparatus = [
      for (var index = 0; index < _tabQrRezkaIds.length; index++)
        AdminApparatus(
          id: _tabQrRezkaIds[index],
          name: index == 0 ? 'Rezka' : 'Rezka ${index + 1}',
          operation: 'cut',
          family: 'cutting',
          sortOrder: index,
        ),
      const AdminApparatus(
          id: _lamination1Id, name: 'Laminatsiya 1', operation: 'laminate'),
    ];
    maps = [savedOrder(incoming: false), savedOrder(incoming: true)];
    snapshot().validateContract();
    events.onListen = () => scheduleMicrotask(() {
          if (!events.isClosed) events.add(snapshot());
        });
    await _usePhoneViewport(tester);
    addTearDown(() async {
      if (lookupGate != null && !lookupGate!.isCompleted)
        lookupGate!.complete();
      dismissAdminTopNotice();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await events.close();
    });
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      onGenerateRoute: (_) {
        scannerRoutes++;
        return MaterialPageRoute<String>(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('return-tab-qr'),
              onPressed: () => Navigator.of(context).pop(_inlineOtherWipQr),
              child: const Text('Scan tab WIP'),
            ),
          ),
        );
      },
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        queueSnapshotLoader: () async => snapshot(),
        apparatusLoader: () async => apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    await _pumpTemporaryPauseUi(tester);
    await selectTab(tester, 'Rezka 4');
  }

  Future<void> selectTab(WidgetTester tester, String label) async {
    final tab = find.text(label);
    expect(tab, findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .toList()
            .toString());
    await tester.ensureVisible(tab);
    await tester.tap(tab);
    await _pumpTemporaryPauseUi(tester);
  }

  Future<void> scanFab(WidgetTester tester) async {
    final scan = tester
        .widget<AparatchiDock>(find.byType(AparatchiDock))
        .onQrScanRequested!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('return-tab-qr')));
    await _pumpTemporaryPauseUi(tester);
    await scan;
    await _pumpTemporaryPauseUi(tester);
  }
}

void _registerWorkerTabQrTests() {
  for (final modern in [true, false]) {
    testWidgets(
        'worker FAB QR stays on selected cutting tab with another busy, routeMetadata=$modern',
        (tester) async {
      final fixture = _WorkerTabQrFixture(routeMetadata: modern);
      await http.runWithClient(() async {
        await fixture.openTabs(tester);
        await fixture.scanFab(tester);
        expect(fixture.scopedLookups, isNotEmpty);
        expect(fixture.scopedLookups, everyElement(_tabQrSelectedId));
        expect(find.text('0243'), findsOneWidget);
        expect(
            find.byKey(
                const ValueKey('production-switch-order-temporary-pause')),
            findsNothing);
        final start = find.widgetWithText(FilledButton, 'Boshlash');
        expect(start, findsOneWidget);
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        await tester.ensureVisible(start);
        await tester.tap(start);
        await _pumpTemporaryPauseUi(tester);
        expect(fixture.mutations, hasLength(1));
        final body = jsonDecode(fixture.mutations.single.body) as Map;
        expect(body['apparatus'], _tabQrSelectedId);
        expect(body['order_id'], _inlineOtherOrderId);
        expect(body['action'], 'start');
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('worker FAB QR rejects route outside selected cutting tab',
      (tester) async {
    final fixture = _WorkerTabQrFixture(routeMismatch: true);
    await http.runWithClient(() async {
      await fixture.openTabs(tester);
      await fixture.scanFab(tester);
      expect(fixture.scopedLookups, isEmpty);
      expect(fixture.mutations, isEmpty);
      expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
          findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
          findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'worker FAB QR pauses only selected cutting tab and reopens there',
      (tester) async {
    final fixture = _WorkerTabQrFixture(selectedBusy: true);
    await http.runWithClient(() async {
      await fixture.openTabs(tester);
      await fixture.scanFab(tester);
      final pause =
          find.byKey(const ValueKey('production-switch-order-temporary-pause'));
      expect(pause, findsOneWidget);
      final confirmation = find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString() == '_WorkerTemporaryPauseSwitchSheet');
      for (final identity in ['0055', 'BINGO SARIQ', 'Rezka 4']) {
        expect(
            find.descendant(
                of: confirmation, matching: find.textContaining(identity)),
            findsOneWidget);
      }
      await tester.tap(pause);
      await _pumpTemporaryPauseUi(tester);
      expect(fixture.mutations, hasLength(1));
      expect(fixture.mutations.single.url.path, endsWith('/temporary-pause'));
      final body = jsonDecode(fixture.mutations.single.body) as Map;
      expect(body['apparatus'], _tabQrSelectedId);
      expect(body['order_id'], _inlineOrderId);
      expect(body['session_id'], 'running-$_tabQrSelectedId');
      expect(fixture.stationControl(_rezkaId, incoming: false)['state'],
          'in_progress');
      expect(fixture.scopedLookups, everyElement(_tabQrSelectedId));
      expect(find.text('0243'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Boshlash'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('worker FAB QR requires an apparatus on the completed tab',
      (tester) async {
    final fixture = _WorkerTabQrFixture();
    await http.runWithClient(() async {
      await fixture.openTabs(tester);
      await fixture.selectTab(tester, 'Tugallangan');
      final scan = tester
          .widget<AparatchiDock>(find.byType(AparatchiDock))
          .onQrScanRequested!();
      await _pumpTemporaryPauseUi(tester);
      expect(fixture.scannerRoutes, 0);
      expect(fixture.scopedLookups, isEmpty);
      expect(fixture.mutations, isEmpty);
      expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
          findsOneWidget);
      await _closeInlineWipGuidance(tester);
      await scan;
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('worker FAB QR does not scan from an unassigned visible tab',
      (tester) async {
    final fixture = _WorkerTabQrFixture(unassignedSelected: true);
    await http.runWithClient(() async {
      await fixture.openTabs(tester);
      final scan = tester
          .widget<AparatchiDock>(find.byType(AparatchiDock))
          .onQrScanRequested!();
      await _pumpTemporaryPauseUi(tester);
      expect(fixture.scannerRoutes, 0);
      expect(fixture.scopedLookups, isEmpty);
      expect(fixture.mutations, isEmpty);
      expect(find.byKey(const ValueKey('production-wip-guidance-dialog')),
          findsOneWidget);
      await _closeInlineWipGuidance(tester);
      await scan;
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  for (final boundary in ['camera', 'lookup']) {
    testWidgets(
        'worker FAB QR discards changed tab round trip during $boundary',
        (tester) async {
      final fixture = _WorkerTabQrFixture();
      await http.runWithClient(() async {
        await fixture.openTabs(tester);
        final controller =
            tester.widget<TabBar>(find.byType(TabBar)).controller!;
        final selectedIndex = controller.index;
        if (boundary == 'lookup') fixture.lookupGate = Completer<void>();
        final scan = tester
            .widget<AparatchiDock>(find.byType(AparatchiDock))
            .onQrScanRequested!();
        await tester.pumpAndSettle();
        if (boundary == 'lookup') {
          await tester.tap(find.byKey(const ValueKey('return-tab-qr')));
          await _pumpTemporaryPauseUi(tester);
          expect(fixture.requests.where((r) => r.url.path.endsWith('/lookup')),
              hasLength(1));
        }
        controller.animateTo(0);
        await _pumpTemporaryPauseUi(tester);
        controller.animateTo(selectedIndex);
        await _pumpTemporaryPauseUi(tester);
        if (boundary == 'camera') {
          await tester.tap(find.byKey(const ValueKey('return-tab-qr')));
        } else {
          fixture.lookupGate!.complete();
        }
        await _pumpTemporaryPauseUi(tester);
        await scan;
        expect(fixture.scopedLookups, isEmpty);
        expect(fixture.mutations, isEmpty);
        expect(
            find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
            findsNothing);
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }
}
