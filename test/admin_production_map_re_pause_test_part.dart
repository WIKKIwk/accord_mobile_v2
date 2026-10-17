part of 'admin_production_map_test_screen_test.dart';

class _RePauseFixture extends _InlineWipFixture {
  _RePauseFixture({super.station}) : super('active');
  String? owner = 'inline-new-shift';
  bool astatka = false;
  bool reject = false;
  bool loseResponse = false;
  String resumeId = 'last-resume';
  int resumeCount = 0;
  AdminProductionMapLiveSnapshot? lastSnapshot;

  @override
  AdminProductionMapLiveSnapshot snapshot() {
    // Use the real decoder: production snapshots contain immutable maps.
    return lastSnapshot = AdminProductionMapLiveSnapshot.fromJson({
      ...sequence(),
      'completed_orders': [],
      'completion_requests': [],
      'completion_request_decisions': [],
    });
  }

  @override
  Map<String, dynamic> control({bool other = false}) => {
        ...super.control(other: other),
        'interaction': {
          ...super.control(other: other)['interaction'] as Map,
          'resume_input_required': false
        },
        if (!other && owner != null)
          're_pause': {
            'resume_id': resumeId,
            'worker_role': 'aparatchi',
            'worker_ref': owner,
          },
        if (!other && astatka)
          'stage_work': {
            'astatka_available': true,
            'astatka_required': true,
          },
      };

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/re-pause')) {
      requests.add(request);
      mutations.add(request);
      if (mutationGate != null) await mutationGate!.future;
      owner = null;
      if (reject) {
        revision++;
        return http.Response('{"error":"queue_action_not_allowed"}', 409);
      }
      changePhase('paused');
      if (loseResponse) throw http.ClientException('Response lost after commit');
      return http.Response(
          jsonEncode({'ok': true, 'rev': revision, 'epoch': 'inline-server'}),
          200);
    }
    if (request.url.path.endsWith('/queue-action')) {
      requests.add(request);
      mutations.add(request);
      final payload = jsonDecode(request.body) as Map;
      expect(payload['action'], 'resume');
      owner = 'inline-new-shift';
      resumeId = 'resume-${++resumeCount}';
      changePhase('active');
      return http.Response(
          jsonEncode({
            'ok': true,
            'rev': revision,
            'epoch': 'inline-server',
            'states': {_inlineOrderId: 'in_progress'},
            'order_control': {'state': 'active'},
            'control_state': {
              'apparatus': station,
              'order_id': _inlineOrderId,
              'rev': revision,
              'epoch': 'inline-server',
              'scope': '',
              'control': control(),
              'queue_state': 'in_progress',
              'stage_states': {},
              'order_control': 'active',
            },
          }),
          200);
    }
    return super.respond(request);
  }

  @override
  Future<void> open(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'inline-new-shift',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [station]);
    maps = [
      for (final other in [false, true])
        await MobileApi.instance.adminSaveProductionMap(
            _twoStageProductionOrderMap(
                id: other ? _inlineOtherOrderId : _inlineOrderId,
                title: other ? 'Other inline work' : 'Inline work',
                productCode: 'REP',
                product: 'Re-pause product',
                firstApparatusId: _print9Id,
                secondApparatusId: station))
    ];
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    snapshot().validateContract();
    await _usePhoneViewport(tester);
    addTearDown(() async {
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
            queueSnapshotLoader: () async => snapshot(),
            apparatusLoader: () async => apparatus,
            liveEventsLoader: () => events.stream)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_fixtureApparatusName(station)));
    await tester.pumpAndSettle();
    await TestModeController.instance.setEnabled(false);
    await tester
        .longPress(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
    await tester.pumpAndSettle();
  }
}

void _registerRePauseTests() {
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final loseResponse in [false, true]) {
      testWidgets(
          're-pause then resume with immutable snapshot on $station, lost response=$loseResponse',
          (tester) async {
        final fixture = _RePauseFixture(station: station)
          ..loseResponse = loseResponse
          ..wipStatus = 'in_use';
        await http.runWithClient(() async {
          await fixture.open(tester);
          for (var cycle = 0; cycle < 2; cycle++) {
            if (cycle > 0) {
              await tester.longPress(
                  find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
              await tester.pumpAndSettle();
            }
            final snapshot = fixture.lastSnapshot!;
            final control = snapshot.queueActionControls[station]![_inlineOrderId]!;
            expect(control.state, 'in_progress');
            await tester.tap(find.byKey(const ValueKey('worker-re-pause')));
            await tester.pumpAndSettle();
            expect(fixture.phase, 'paused');
            expect(fixture.mutations, hasLength(cycle * 2 + 1));
            expect(
                snapshot.queueActionControls[station]![_inlineOrderId],
                same(control),
                reason: 'Local invalidation must preserve the canonical snapshot');
            expect(tester.takeException(), isNull);
            dismissAdminTopNotice();
            await tester.pumpAndSettle();
            await tester.tap(
                find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
            await tester.pumpAndSettle();
            final dynamic card = _resumeWipCard(tester);
            expect(card.actionInFlight, isFalse);
            expect(card.uiState.resumeWipReady, isTrue);
            expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed,
                isNotNull);
            await tester.ensureVisible(_resumeWipButton());
            await tester.tap(_resumeWipButton());
            await tester.pumpAndSettle();
            expect(fixture.phase, 'active');
            expect(fixture.mutations, hasLength((cycle + 1) * 2));
            final resume = jsonDecode(fixture.mutations.last.body) as Map;
            expect(resume['action'], 'resume');
            expect(resume.containsKey('qr_payload'), isFalse);
            expect(resume.containsKey('progress_batch_id'), isFalse);
            expect(fixture.wipStatus, 'in_use');
            final sheet = find.byWidgetPredicate((widget) =>
                widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet');
            Navigator.of(tester.element(sheet)).pop();
            await tester.pumpAndSettle();
          }
          final pauseIds = fixture.mutations
              .where((request) => request.url.path.endsWith('/re-pause'))
              .map((request) => (jsonDecode(request.body) as Map)['resume_id'])
              .toSet();
          expect(pauseIds, hasLength(2));
          expect(tester.takeException(), isNull);
        }, () => MockClient(fixture.respond));
      });
    }
  }

  testWidgets('re-pause releases the shared action while its detail stays open',
      (tester) async {
    final fixture = _RePauseFixture(station: _rezkaId)
      ..mutationGate = Completer<void>();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-re-pause')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.mutations, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(_resumeWipCard(tester).actionInFlight, isTrue);
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      expect(fixture.phase, 'paused');
      expect(_resumeWipCard(tester).actionInFlight, isFalse);
      expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      expect(fixture.mutations, hasLength(1));
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    testWidgets('re-pause long press preserves report actions on $station',
        (tester) async {
      final fixture = _RePauseFixture(station: station)..astatka = true;
      await http.runWithClient(() async {
        await fixture.open(tester);
        expect(find.byKey(const ValueKey('worker-re-pause')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('worker-re-pause')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(fixture.mutations, hasLength(1));
        expect(jsonDecode(fixture.mutations.single.body), {
          'apparatus': station,
          'order_id': _inlineOrderId,
          'resume_id': 'last-resume'
        });
        expect(fixture.phase, 'paused');
        expect(find.text('Ish qayta pauzaga o‘tkazildi'), findsOneWidget);
        expect(
            fixture.requests.where((r) => r.url.path.endsWith('/queue-action')),
            isEmpty);
        dismissAdminTopNotice();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => MockClient(fixture.respond));
    });
  }
  for (final owner in <String?>[null, 'another-worker']) {
    testWidgets('re-pause hidden for absent or other worker checkpoint: $owner',
        (tester) async {
      final fixture = _RePauseFixture()..owner = owner;
      await http.runWithClient(() async {
        await fixture.open(tester);
        expect(find.byKey(const ValueKey('worker-re-pause')), findsNothing);
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }
  testWidgets('re-pause rejected stale checkpoint refreshes without replay',
      (tester) async {
    final fixture = _RePauseFixture()..reject = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-re-pause')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(fixture.mutations, hasLength(1));
      expect(fixture.phase, 'active');
      expect(find.textContaining('Qayta pauza tasdiqlanmadi'), findsOneWidget);
      await tester.longPress(
          find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('worker-re-pause')), findsNothing);
    }, () => MockClient(fixture.respond));
  });
  testWidgets('re-pause completion is ignored after an account switch',
      (tester) async {
    final fixture = _RePauseFixture()..mutationGate = Completer<void>();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-re-pause')));
      await tester.pump();
      expect(fixture.mutations, hasLength(1));
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Other',
          legalName: '',
          ref: 'another-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_lamination1Id]);
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ish qayta pauzaga o‘tkazildi'), findsNothing);
      expect(find.textContaining('Qayta pauza tasdiqlanmadi'), findsNothing);
      expect(fixture.mutations, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient(fixture.respond));
  });
}
