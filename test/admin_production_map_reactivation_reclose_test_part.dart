part of 'admin_production_map_test_screen_test.dart';

class _RecloseFixture extends _RePauseFixture {
  _RecloseFixture({super.station}) {
    phase = 'paused';
    astatka = true;
  }
  final token = List.filled(64, 'a').join();
  bool recloseEnabled = true;

  @override
  Map<String, dynamic> control({bool other = false}) {
    final result = super.control(other: other)..remove('re_pause');
    if (!other && phase == 'paused' && owner != null && recloseEnabled) {
      result['reclose'] = {
        'session_id': 'unstarted-continuation',
        'stage_node_id': result['stage_node_id'],
        'token': token,
        'worker_role': 'aparatchi',
        'worker_ref': owner
      };
    }
    if (!other && phase == 'completed') {
      result['state'] = 'completed';
      result['allowed_actions'] = <String>[];
      result['interaction'] = {
        ...result['interaction'] as Map,
        'mode': 'completed'
      };
    }
    return result;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (!request.url.path.endsWith('/reactivation/reclose'))
      return super.respond(request);
    requests.add(request);
    mutations.add(request);
    if (mutationGate != null) await mutationGate!.future;
    owner = null;
    if (reject) {
      revision++;
      return http.Response('{"error":"queue_action_not_allowed"}', 409);
    }
    changePhase('completed');
    if (loseResponse) throw http.ClientException('response lost after commit');
    return http.Response(
        jsonEncode({'ok': true, 'rev': revision, 'epoch': 'inline-server'}),
        200);
  }

  Future<void> run(WidgetTester tester, Future<void> Function() body) async {
    await http.runWithClient(() async {
      try {
        await body();
      } finally {
        if (mutationGate != null && !mutationGate!.isCompleted) {
          mutationGate!.complete();
        }
        await _pumpRecloseTransition(tester);
        dismissAdminTopNotice();
        await _pumpRecloseTransition(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }, () => MockClient(respond));
  }

  Future<void> openDetail(WidgetTester tester) async {
    await open(tester);
    Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
    await _pumpRecloseTransition(tester);
    await tester
        .tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
    await _pumpRecloseTransition(tester);
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
                product: 'Reclose product',
                firstApparatusId: _print9Id,
                secondApparatusId: station))
    ];
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    snapshot().validateContract();
    await _usePhoneViewport(tester);
    addTearDown(() async {
      if (mutationGate != null && !mutationGate!.isCompleted) {
        mutationGate!.complete();
      }
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
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            queueSnapshotLoader: () async => snapshot(),
            apparatusLoader: () async => apparatus,
            liveEventsLoader: () => events.stream)));
    await _pumpRecloseTransition(tester);
    await tester.tap(find.text(_fixtureApparatusName(station)));
    await _pumpRecloseTransition(tester);
    await TestModeController.instance.setEnabled(false);
    await tester
        .longPress(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
    await _pumpRecloseTransition(tester);
  }
}

Future<void> _pumpRecloseTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _ordinaryRecloseFinishButton() => find
    .descendant(
      of: find.byWidgetPredicate((widget) => const {
            '_BosmaWorkerFinishSheet',
            '_LaminatsiyaWorkerFinishSheet',
          }.contains(widget.runtimeType.toString())),
      matching: find.byType(FilledButton),
    )
    .last;

void _expectOnlyRecloseMutation(_RecloseFixture fixture) {
  expect(fixture.mutations, hasLength(1));
  expect(fixture.mutations.single.url.path, endsWith('/reactivation/reclose'));
  expect(jsonDecode(fixture.mutations.single.body), {
    'apparatus': fixture.station,
    'order_id': _inlineOrderId,
    'session_id': 'unstarted-continuation',
    'stage_node_id': 'second-apparatus',
    'token': fixture.token,
  });
  expect(
    fixture.requests.where((request) => const {
          '/queue-action',
          '/laminatsiya-astatka',
          '/layer-remainders',
        }.any(request.url.path.endsWith)),
    isEmpty,
  );
}

void _registerRecloseTests() {
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final detail in [false, true]) {
      for (final lost in [false, true]) {
        testWidgets(
            'ordinary finish recloses unstarted work without reports on $station, detail=$detail, lost=$lost',
            (tester) async {
          final fixture = _RecloseFixture(station: station)
            ..loseResponse = lost
            ..wipStatus = 'in_use';
          await fixture.run(tester, () async {
            if (detail) {
              await fixture.openDetail(tester);
            } else {
              await fixture.open(tester);
            }
            final finish = detail
                ? find.widgetWithText(FilledButton, 'Tugatish')
                : _ordinaryRecloseFinishButton();
            expect(finish, findsOneWidget);
            await tester.ensureVisible(finish);
            await tester.tap(finish);
            await _pumpRecloseTransition(tester);
            expect(fixture.phase, 'completed');
            _expectOnlyRecloseMutation(fixture);
            if (!detail) {
              expect(
                  find.byWidgetPredicate((widget) =>
                      widget.runtimeType.toString() ==
                      '_ReadOnlyOrderDetailSheet'),
                  findsNothing);
            }
            expect(tester.takeException(), isNull);
          });
        });
      }
    }
  }
  for (final invalid in ['ordinary-pause', 'other-worker']) {
    testWidgets(
        'ordinary finish cannot reclose without current permission: $invalid',
        (tester) async {
      final fixture = _RecloseFixture()..wipStatus = 'in_use';
      if (invalid == 'other-worker') {
        fixture.owner = 'other-worker';
      } else {
        fixture.recloseEnabled = false;
      }
      await fixture.run(tester, () async {
        await fixture.openDetail(tester);
        expect(find.widgetWithText(FilledButton, 'Tugatish'), findsNothing);
        expect(fixture.mutations, isEmpty);
        expect(tester.takeException(), isNull);
      });
    });
  }
  testWidgets('ordinary finish cannot reclose after resume and another pause',
      (tester) async {
    final fixture = _RecloseFixture()..wipStatus = 'in_use';
    await fixture.run(tester, () async {
      await fixture.openDetail(tester);
      await tester.ensureVisible(_resumeWipButton());
      await tester.tap(_resumeWipButton());
      await _pumpRecloseTransition(tester);
      expect(fixture.phase, 'active');
      expect(fixture.resumeCount, 1);
      fixture.recloseEnabled = false;
      fixture.changePhase('paused');
      fixture.events.add(fixture.snapshot());
      await _pumpRecloseTransition(tester);
      if (find.byType(BottomSheet).evaluate().isNotEmpty) {
        Navigator.of(tester.element(find.byType(BottomSheet).last)).pop();
        await _pumpRecloseTransition(tester);
      }
      await tester
          .tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await _pumpRecloseTransition(tester);
      expect(find.widgetWithText(FilledButton, 'Tugatish'), findsNothing);
      expect(fixture.mutations, hasLength(1));
      expect(fixture.mutations.single.url.path, endsWith('/queue-action'));
      expect(tester.takeException(), isNull);
    });
  });
  for (final detail in [false, true]) {
    testWidgets(
        'ordinary finish stale reclose never falls back to a report, detail=$detail',
        (tester) async {
      final fixture = _RecloseFixture()..reject = true;
      await fixture.run(tester, () async {
        if (detail) {
          await fixture.openDetail(tester);
        } else {
          await fixture.open(tester);
        }
        final finish = detail
            ? find.widgetWithText(FilledButton, 'Tugatish')
            : _ordinaryRecloseFinishButton();
        await tester.ensureVisible(finish);
        await tester.tap(finish);
        await _pumpRecloseTransition(tester);
        expect(fixture.phase, 'paused');
        _expectOnlyRecloseMutation(fixture);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
            find.byType(BottomSheet), detail ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  }
  testWidgets('ordinary finish double tap sends one reclose without reports',
      (tester) async {
    final fixture = _RecloseFixture()..mutationGate = Completer<void>();
    await fixture.run(tester, () async {
      await fixture.openDetail(tester);
      final finish = find.widgetWithText(FilledButton, 'Tugatish');
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pump();
      final buttons = finish.evaluate();
      if (buttons.isNotEmpty) {
        final onPressed = tester.widget<FilledButton>(finish).onPressed;
        onPressed?.call();
      }
      await tester.pump();
      _expectOnlyRecloseMutation(fixture);
      fixture.mutationGate!.complete();
      await _pumpRecloseTransition(tester);
      expect(fixture.phase, 'completed');
      _expectOnlyRecloseMutation(fixture);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('ordinary finish does not reclose after account switch',
      (tester) async {
    final fixture = _RecloseFixture();
    await fixture.run(tester, () async {
      await fixture.open(tester);
      AppSession.instance.profile = SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Other worker',
          legalName: '',
          ref: 'another-account',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [fixture.station]);
      await tester.tap(_ordinaryRecloseFinishButton());
      await _pumpRecloseTransition(tester);
      expect(fixture.mutations, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final lost in [false, true]) {
      testWidgets(
          'unstarted reclose uses no output or waste form on $station, lost=$lost',
          (tester) async {
        final fixture = _RecloseFixture(station: station)
          ..loseResponse = lost
          ..wipStatus = 'in_use';
        await fixture.run(tester, () async {
          await fixture.open(tester);
          expect(find.byKey(const ValueKey('worker-reclose')), findsOneWidget);
          expect(find.byKey(const ValueKey('worker-re-pause')), findsNothing);
          expect(find.textContaining('Astatka'), findsWidgets);
          await tester.tap(find.byKey(const ValueKey('worker-reclose')));
          await _pumpRecloseTransition(tester);
          expect(fixture.phase, 'completed');
          expect(fixture.mutations, hasLength(1));
          expect(jsonDecode(fixture.mutations.single.body), {
            'apparatus': station,
            'order_id': _inlineOrderId,
            'session_id': 'unstarted-continuation',
            'stage_node_id': 'second-apparatus',
            'token': fixture.token
          });
          expect(
              fixture.requests
                  .where((r) => r.url.path.endsWith('/queue-action')),
              isEmpty);
          expect(
              find.byWidgetPredicate((w) =>
                  w.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
              findsNothing);
          expect(tester.takeException(), isNull);
        });
      });
    }
  }
  for (final owner in <String?>[null, 'other-worker']) {
    testWidgets('reclose hidden for missing or other worker permission: $owner',
        (tester) async {
      final fixture = _RecloseFixture()
        ..owner = owner
        ..astatka = false;
      await fixture.run(tester, () async {
        await fixture.open(tester);
        expect(find.byKey(const ValueKey('worker-reclose')), findsNothing);
        expect(fixture.mutations, isEmpty);
      });
    });
  }
  testWidgets('stale reclose is refreshed without write replay',
      (tester) async {
    final fixture = _RecloseFixture()..reject = true;
    await fixture.run(tester, () async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-reclose')));
      await _pumpRecloseTransition(tester);
      expect(fixture.phase, 'paused');
      expect(fixture.mutations, hasLength(1));
      await tester.longPress(
          find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await _pumpRecloseTransition(tester);
      expect(find.byKey(const ValueKey('worker-reclose')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
