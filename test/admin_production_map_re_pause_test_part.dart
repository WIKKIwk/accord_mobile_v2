part of 'admin_production_map_test_screen_test.dart';

class _RePauseFixture extends _InlineWipFixture {
  _RePauseFixture({super.station}) : super('active');
  String? owner = 'inline-new-shift';
  bool astatka = false;
  bool reject = false;

  @override
  Map<String, dynamic> control({bool other = false}) => {
        ...super.control(other: other),
        'interaction': {
          ...super.control(other: other)['interaction'] as Map,
          'resume_input_required': false
        },
        if (!other && owner != null)
          're_pause': {
            'resume_id': 'last-resume',
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
      return http.Response(
          jsonEncode({'ok': true, 'rev': revision, 'epoch': 'inline-server'}),
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
