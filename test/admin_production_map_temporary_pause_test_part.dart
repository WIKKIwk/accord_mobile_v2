part of 'admin_production_map_test_screen_test.dart';

class _TemporaryPauseFixture extends _RePauseFixture {
  _TemporaryPauseFixture({super.station});
  final pauseToken = List.filled(64, 'b').join();
  bool available = true;
  bool temporarilyPaused = false;

  @override
  Future<void> open(WidgetTester tester) async {
    // A connected live stream confirms the initial HTTP cursor. Leaving this
    // silent would correctly withdraw action authority after its ready timeout.
    events.onListen = () => scheduleMicrotask(() {
          if (!events.isClosed) events.add(snapshot());
        });
    await super.open(tester);
  }

  Future<void> openWithScannedOrder(WidgetTester tester) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'inline-new-shift',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [station],
    );
    maps = [
      for (final other in [false, true])
        await MobileApi.instance
            .adminSaveProductionMap(_twoStageProductionOrderMap(
          id: other ? _inlineOtherOrderId : _inlineOrderId,
          title: other ? 'Other inline work' : 'Inline work',
          productCode: 'TEMP',
          product: 'Temporary interruption',
          firstApparatusId: _print9Id,
          secondApparatusId: station,
        )),
    ];
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    await TestModeController.instance.setEnabled(false);
    await _usePhoneViewport(tester);
    events.onListen = () => scheduleMicrotask(() {
          if (!events.isClosed) events.add(snapshot());
        });
    addTearDown(() async {
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
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        initialWorkerQrPayload: _inlineOtherWipQr,
        queueSnapshotLoader: () async => snapshot(),
        apparatusLoader: () async => apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await _pumpTemporaryPauseUi(tester);
  }

  @override
  Map<String, dynamic> control({bool other = false}) {
    final result = super.control(other: other)..remove('re_pause');
    if (!other && available && phase == 'active') {
      result['temporary_pause'] = {
        'session_id': 'same-unfinished-roll',
        'token': pauseToken,
      };
    }
    result['temporarily_paused'] =
        !other && phase == 'paused' && temporarilyPaused;
    return result;
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (!request.url.path.endsWith('/temporary-pause')) {
      return super.respond(request);
    }
    requests.add(request);
    mutations.add(request);
    if (mutationGate != null) await mutationGate!.future;
    if (reject) {
      available = false;
      revision++;
      return http.Response('{"error":"queue_action_not_allowed"}', 409);
    }
    temporarilyPaused = true;
    changePhase('paused');
    if (loseResponse) throw http.ClientException('Response lost after commit');
    return http.Response('{"ok":true}', 200);
  }
}

Future<void> _pumpTemporaryPauseUi(WidgetTester tester) async {
  // Status/subtitle marquees keep animating on narrow phones.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _registerTemporaryPauseTests() {
  for (final station in [_print8Id, _lamination1Id, _rezkaId]) {
    for (final lost in [false, true]) {
      testWidgets(
          'temporary removal preserves unfinished roll on $station, lost=$lost',
          (tester) async {
        final fixture = _TemporaryPauseFixture(station: station)
          ..loseResponse = lost
          ..astatka = true
          ..wipStatus = 'in_use';
        await http.runWithClient(() async {
          await fixture.open(tester);
          expect(find.byKey(const ValueKey('worker-temporary-pause')),
              findsOneWidget);
          final before = fixture.lastSnapshot!;
          await tester
              .tap(find.byKey(const ValueKey('worker-temporary-pause')));
          await _pumpTemporaryPauseUi(tester);
          expect(fixture.phase, 'paused');
          expect(fixture.mutations, hasLength(1));
          expect(jsonDecode(fixture.mutations.single.body), {
            'apparatus': station,
            'order_id': _inlineOrderId,
            'session_id': 'same-unfinished-roll',
            'token': fixture.pauseToken,
          });
          expect(before.queueActionControls[station]![_inlineOrderId]!.state,
              'in_progress',
              reason: 'Do not mutate immutable canonical snapshots');
          expect(fixture.wipStatus, 'in_use');
          expect(
              find.byWidgetPredicate((widget) =>
                  widget.runtimeType.toString().contains('ProgressQty')),
              findsNothing);
          expect(
              fixture.requests
                  .where((r) => r.url.path.endsWith('/queue-action')),
              isEmpty);
          dismissAdminTopNotice();
          await _pumpTemporaryPauseUi(tester);
          await tester
              .tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
          await _pumpTemporaryPauseUi(tester);
          expect(find.byKey(const ValueKey('worker-temporarily-paused-status')),
              findsOneWidget);
          expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed,
              isNotNull);
          await tester.ensureVisible(_resumeWipButton());
          await tester.tap(_resumeWipButton());
          await _pumpTemporaryPauseUi(tester);
          expect(fixture.phase, 'active');
          expect(fixture.mutations, hasLength(2));
          final resume = jsonDecode(fixture.mutations.last.body) as Map;
          expect(resume['action'], 'resume');
          expect(resume.containsKey('qr_payload'), isFalse);
          expect(resume.containsKey('finished_goods_meter'), isFalse);
          expect(resume.containsKey('finished_goods_kg'), isFalse);
          expect(fixture.wipStatus, 'in_use');
          expect(find.byKey(const ValueKey('worker-temporarily-paused-status')),
              findsNothing);
          expect(tester.takeException(), isNull);
        }, () => MockClient(fixture.respond));
      });
    }
  }

  testWidgets('temporary removal is offered when switching by another order QR',
      (tester) async {
    final fixture = _TemporaryPauseFixture();
    await http.runWithClient(() async {
      await fixture.openWithScannedOrder(tester);
      expect(
          find.byKey(const ValueKey('production-switch-order-temporary-pause')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('production-switch-order-complete')),
          findsOneWidget);
      expect(fixture.mutations, isEmpty);
      final confirmation = find.byWidgetPredicate((widget) =>
          widget.runtimeType.toString() == '_WorkerTemporaryPauseSwitchSheet');
      for (final identity in ['Inline work', 'Laminatsiya 1']) {
        expect(
            find.descendant(
                of: confirmation, matching: find.textContaining(identity)),
            findsOneWidget);
      }
      final pause =
          find.byKey(const ValueKey('production-switch-order-temporary-pause'));
      // The parent detail's async QR validation can mount this sheet on the
      // last startup frame. Finish its entrance before targeting the button.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(pause);
      await tester.tap(pause);
      await _pumpTemporaryPauseUi(tester);
      expect(fixture.phase, 'paused');
      expect(fixture.mutations, hasLength(1));
      expect(fixture.mutations.single.url.path, endsWith('/temporary-pause'));
      expect(
          find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString().contains('ProgressQty')),
          findsNothing);
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('temporary removal absent authority stays hidden',
      (tester) async {
    final fixture = _TemporaryPauseFixture()..available = false;
    await http.runWithClient(() async {
      await fixture.open(tester);
      expect(
          find.byKey(const ValueKey('worker-temporary-pause')), findsNothing);
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('temporary removal stale response reconciles without replay',
      (tester) async {
    final fixture = _TemporaryPauseFixture()..reject = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-temporary-pause')));
      await _pumpTemporaryPauseUi(tester);
      expect(fixture.mutations, hasLength(1));
      expect(fixture.phase, 'active');
      expect(find.textContaining('Vaqtincha yechish tasdiqlanmadi'),
          findsOneWidget);
      dismissAdminTopNotice();
      await _pumpTemporaryPauseUi(tester);
      await tester.longPress(
          find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
      await _pumpTemporaryPauseUi(tester);
      expect(
          find.byKey(const ValueKey('worker-temporary-pause')), findsNothing);
      expect(fixture.mutations, hasLength(1));
    }, () => MockClient(fixture.respond));
  });

  for (final switchServer in [false, true]) {
    testWidgets(
        'temporary removal old menu cannot send after scope switch, server=$switchServer',
        (tester) async {
      final fixture = _TemporaryPauseFixture();
      final originalBaseUrl = ServerEndpointStore.instance.baseUrl;
      await http.runWithClient(() async {
        await fixture.open(tester);
        addTearDown(
            () => ServerEndpointStore.instance.setBaseUrl(originalBaseUrl));
        if (switchServer) {
          await ServerEndpointStore.instance
              .setBaseUrl('https://other.example.com');
        } else {
          AppSession.instance.profile = const SessionProfile(
            role: UserRole.aparatchi,
            displayName: 'Other',
            legalName: '',
            ref: 'other-worker',
            phone: '',
            avatarUrl: '',
            capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
            assignedApparatus: [_lamination1Id],
          );
        }
        await tester.tap(find.byKey(const ValueKey('worker-temporary-pause')));
        await _pumpTemporaryPauseUi(tester);
        expect(fixture.mutations, isEmpty);
        expect(fixture.phase, 'active');
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('temporary removal completion is ignored after account switch',
      (tester) async {
    final fixture = _TemporaryPauseFixture()..mutationGate = Completer<void>();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await tester.tap(find.byKey(const ValueKey('worker-temporary-pause')));
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
      await _pumpTemporaryPauseUi(tester);
      expect(find.textContaining('Buyurtma vaqtincha yechildi'), findsNothing);
      expect(
          find.textContaining('Vaqtincha yechish tasdiqlanmadi'), findsNothing);
      expect(fixture.mutations, hasLength(1));
    }, () => MockClient(fixture.respond));
  });
}
