part of 'admin_production_map_test_screen_test.dart';

class _ResumeWipFixture extends _InlineWipFixture {
  _ResumeWipFixture({String station = _lamination1Id})
      : super('resume', station: station) {
    useOpening = true;
    wipStatus = 'in_use';
    sessionJson['apparatus'] = station;
  }

  bool resumeInputRequired = false;
  bool omitResumeInputRequired = false;
  bool allowResume = true;
  bool materialScanRequired = false;
  bool materialSatisfied = false;
  bool qolipScanRequired = false;
  String invalidControl = '';
  final sessionJson = <String, dynamic>{
    'session_id': 'existing-resume-session',
    'apparatus': _lamination1Id,
    'order_id': _inlineOrderId,
    'status': 'roll_detached',
    'worker_role': 'aparatchi',
    'worker_ref': 'resume-worker',
    'worker_display_name': 'Resume worker',
    'started_at_unix': 100,
    'updated_at_unix': 200,
    'payload_json': {'input_opening_wip_batch_id': 'already-attached-input'},
  };

  AdminWorkerRunSession get session =>
      AdminWorkerRunSession.fromJson(sessionJson);

  @override
  Map<String, dynamic> control({bool other = false}) {
    final result = super.control(other: other);
    if (!other) {
      final interaction = result['interaction'] as Map<String, dynamic>;
      interaction['opening_wip_mode'] = 'scan_required';
      interaction['previous_wip_mode'] =
          useOpening ? 'not_required' : 'scan_required';
      interaction['resume_input_required'] = resumeInputRequired;
      if (omitResumeInputRequired) interaction.remove('resume_input_required');
      interaction['qolip_mode'] = qolipScanRequired && phase != 'active'
          ? 'scan_required'
          : 'not_required';
      interaction['start_materials_mode'] =
          materialScanRequired && phase != 'active'
              ? 'scan_required'
              : 'hidden';
      interaction['material_scan_required'] =
          materialScanRequired && phase != 'active';
      if (phase == 'paused' && !allowResume) {
        result['allowed_actions'] = <String>[];
      }
      if (phase == 'active' || phase == 'paused') {
        result['work_activity'] = {
          'worker_role': session.workerRole,
          'worker_ref': session.workerRef,
          'state': phase == 'active' ? 'in_progress' : 'paused',
        };
      }
      if (invalidControl == 'missing field') {
        result.remove('previous_stage_ready');
      }
      if (invalidControl == 'unknown mode') interaction['mode'] = 'unknown';
      if (invalidControl == 'unknown action') {
        result['allowed_actions'] = ['resume', 'unknown'];
      }
      if (invalidControl == 'malformed resume flag')
        interaction['resume_input_required'] = 'false';
    }
    return result;
  }

  @override
  Map<String, dynamic> openingBatch() => {
        ...super.openingBatch(),
        if (wipStatus == 'in_use')
          'batch_id': session.payloadJson['input_opening_wip_batch_id'],
        if (wipStatus == 'in_use') 'used_by_session_id': session.sessionId,
      };

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/raw-material-assignments/lookup')) {
      requests.add(request);
      return http.Response('{"error":"raw_material_stock_not_found"}', 404);
    }
    if (path.endsWith('/raw-material-start-requirements')) {
      requests.add(request);
      final assignment = {
        ...scanAssignment(),
        'order_id': _inlineOrderId,
        'apparatus': station,
        'stock_status': materialSatisfied ? 'in_use' : 'available',
        if (materialSatisfied) 'reserved_order_id': _inlineOrderId,
      };
      return http.Response(
          jsonEncode({
            ...scanMaterials(),
            'scan_satisfied': materialSatisfied,
            'matched_scan_count': materialSatisfied ? 1 : 0,
            'assignments': [assignment],
            'start_assignments': [assignment],
          }),
          200);
    }
    if (path.endsWith('/queue-action')) {
      requests.add(request);
      mutations.add(request);
      if (mutationGate != null) await mutationGate!.future;
      final payload = jsonDecode(request.body) as Map;
      if (payload['action'] == 'start' || payload['action'] == 'resume') {
        if (payload['action'] == 'start') {
          (sessionJson['payload_json'] as Map)['input_opening_wip_batch_id'] =
              payload['progress_batch_id'];
        }
        if (payload.containsKey('progress_batch_id')) wipStatus = 'in_use';
        changePhase('active');
        sessionJson['status'] = 'in_progress';
      }
      return http.Response(
          jsonEncode({
            'ok': true,
            'rev': revision,
            'epoch': 'inline-server',
            'states': {_inlineOrderId: 'in_progress'},
            'session': sessionJson,
            'work_activity': control()['work_activity'],
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
      displayName: 'Resume worker',
      legalName: '',
      ref: 'resume-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [station],
    );
    maps = [
      for (final other in [false, true])
        await MobileApi.instance.adminSaveProductionMap(
          _twoStageProductionOrderMap(
            id: other ? _inlineOtherOrderId : _inlineOrderId,
            title: other ? 'Other inline work' : 'Inline work',
            productCode: other ? 'INLINE-OTHER' : 'INLINE',
            product: 'Inline product',
            firstApparatusId: _print9Id,
            secondApparatusId: station,
          ),
        ),
    ];
    apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    if (invalidControl.isEmpty) snapshot().validateContract();
    await TestModeController.instance.setEnabled(false);
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
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
        queueSnapshotLoader: () async => snapshot(),
        apparatusLoader: () async => apparatus,
        liveEventsLoader: () => events.stream,
      ),
    ));
    await tester.pumpAndSettle();
    if (invalidControl.isNotEmpty) return;
    expect(events.hasListener, isTrue);
    events.add(snapshot());
    await tester.pumpAndSettle();
    await tester.tap(find.text(_fixtureApparatusName(station)));
    await tester.pumpAndSettle();
    if (phase == 'frozen') return;
    await tester
        .tap(find.byKey(const ValueKey('worker-order-$_inlineOrderId')));
    await tester.pumpAndSettle();
  }
}

dynamic _resumeWipCard(WidgetTester tester) => tester.widget(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_OrderStartUnifiedCard',
      ),
    );

Finder _resumeWipButton() =>
    find.widgetWithText(FilledButton, 'Davom ettirish');

void _registerResumeWipTests() {
  for (final station in [_rezkaId, _lamination1Id]) {
    const omitFlag = false;
    testWidgets(
        'resume WIP: attached input needs no local QR (station: $station)',
        (tester) async {
      final fixture = _ResumeWipFixture(station: station)
        ..omitResumeInputRequired = omitFlag;
      await http.runWithClient(() async {
        await fixture.open(tester);
        final control = AdminApparatusQueueOrderActionControl.fromJson(
          fixture.control(),
        );
        expect(control.contractValid, isTrue);
        expect(
          control.isConsistentWith(AdminOrderControlState.active,
              queueState: 'paused'),
          isTrue,
        );
        expect(control.allows('resume'), isTrue);
        final dynamic card = _resumeWipCard(tester);
        expect(card.uiState.contractSynchronized, isTrue);
        expect(card.uiState.openingWipRequired, isTrue);
        expect(card.uiState.previousProgressReady, isFalse);
        expect(card.previousProgressBatch, isNull);
        expect(card.openingWipBatch, isNull);
        expect(card.actionInFlight, isFalse);
        expect(card.materialStartReady, isTrue);
        expect(card.requiresQolipScan, isFalse);
        expect(fixture.session.status, 'roll_detached');
        final input = AdminOpeningWipBatch.fromJson(fixture.openingBatch());
        expect(input.wipStatus, 'in_use');
        expect(input.usedBySessionId, fixture.session.sessionId);
        final sessionId = fixture.session.sessionId;
        final lineage = Map<String, dynamic>.from(fixture.session.payloadJson);
        expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed,
          isNotNull,
          reason: 'Resume does not require a new input for the paused session',
        );
        await tester.ensureVisible(_resumeWipButton());
        await tester.tap(_resumeWipButton());
        await tester.pumpAndSettle();
        expect(fixture.mutations, hasLength(1));
        final payload = jsonDecode(fixture.mutations.single.body) as Map;
        expect(payload['action'], 'resume');
        expect(payload['apparatus'], station);
        expect(payload['order_id'], _inlineOrderId);
        expect(payload.containsKey('qr_payload'), isFalse);
        expect(payload.containsKey('progress_batch_id'), isFalse);
        expect(fixture.session.sessionId, sessionId);
        expect(fixture.session.payloadJson, lineage);
        expect(fixture.session.status, 'in_progress');
        expect(fixture.wipStatus, 'in_use');
        expect(_resumeWipCard(tester).uiState.showPause, isTrue);
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('resume WIP: missing input requirement fails closed',
      (tester) async {
    final fixture = _ResumeWipFixture()
      ..omitResumeInputRequired = true
      ..invalidControl = 'missing resume flag';
    await http.runWithClient(() async {
      await fixture.open(tester);
      expect(
          AdminApparatusQueueOrderActionControl.fromJson(fixture.control())
              .contractValid,
          isFalse);
      expect(_resumeWipButton(), findsNothing);
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'resume WIP: scanning a next roll asks for Resume without blocking it',
      (tester) async {
    final fixture = _ResumeWipFixture()..wipStatus = 'waiting';
    await http.runWithClient(() async {
      await fixture.open(tester);
      expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      final scan = fixture.scanner(tester)(_inlineWipQr);
      await tester.pumpAndSettle();
      _expectInlineWipGuidance(tester, 'worker.qr.paused_resume', values: {
        'action': AppLocalizations(const Locale('uz'))
            .productionText('worker.action.resume'),
      });
      expect(fixture.mutations, isEmpty);
      await _closeInlineWipGuidance(tester);
      await scan;
      final dynamic card = _resumeWipCard(tester);
      expect(card.previousProgressBatch, isNull);
      expect(card.openingWipBatch, isNull);
      expect(card.uiState.previousProgressReady, isFalse);
      expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      await tester.ensureVisible(_resumeWipButton());
      await tester.tap(_resumeWipButton());
      await tester.pumpAndSettle();
      expect(fixture.mutations, hasLength(1));
      final payload = jsonDecode(fixture.mutations.single.body) as Map;
      expect(payload['action'], 'resume');
      expect(payload.containsKey('qr_payload'), isFalse);
      expect(payload.containsKey('progress_batch_id'), isFalse);
      expect(fixture.wipStatus, 'waiting',
          reason: 'The next roll waits for a separate Merge');
      expect(_resumeWipCard(tester).uiState.showMerge, isTrue);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('resume WIP: required input without QR stays blocked',
      (tester) async {
    final fixture = _ResumeWipFixture()
      ..resumeInputRequired = true
      ..wipStatus = 'waiting';
    await http.runWithClient(() async {
      await fixture.open(tester);
      expect(_resumeWipCard(tester).uiState.contractSynchronized, isTrue);
      expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNull);
      _resumeWipCard(tester).onResume();
      await tester.pumpAndSettle();
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  for (final useOpening in [false, true]) {
    testWidgets(
        'resume WIP: confirmed ${useOpening ? "opening" : "progress"} QR enables required input',
        (tester) async {
      final fixture = _ResumeWipFixture()
        ..resumeInputRequired = true
        ..useOpening = useOpening
        ..wipStatus = 'waiting';
      await http.runWithClient(() async {
        await fixture.open(tester);
        expect(
            tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNull);
        final scan = fixture.scanner(tester)(_inlineWipQr);
        await tester.pumpAndSettle();
        await scan;
        final dynamic card = _resumeWipCard(tester);
        expect(card.uiState.previousProgressReady, isTrue);
        expect(card.openingWipBatch != null, useOpening);
        expect(card.previousProgressBatch != null, !useOpening);
        expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed,
            isNotNull);
        await tester.ensureVisible(_resumeWipButton());
        await tester.tap(_resumeWipButton());
        await tester.pumpAndSettle();
        expect(fixture.mutations, hasLength(1));
        final payload = jsonDecode(fixture.mutations.single.body) as Map;
        expect(payload['action'], 'resume');
        expect(payload['qr_payload'], _inlineWipQr);
        expect(payload['progress_batch_id'],
            useOpening ? 'inline-opening-wip' : 'inline-wip');
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets(
      'resume WIP: successful Start clears selection before later pause',
      (tester) async {
    final fixture = _ResumeWipFixture()
      ..phase = 'start'
      ..wipStatus = 'waiting';
    await http.runWithClient(() async {
      await fixture.open(tester);
      final start = find.byKey(const ValueKey('production-order-start-action'));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      _resumeWipCard(tester).onStart();
      await tester.pumpAndSettle();
      expect(fixture.mutations, isEmpty);
      final scan = fixture.scanner(tester)(_inlineWipQr);
      await tester.pumpAndSettle();
      await scan;
      expect(_resumeWipCard(tester).openingWipBatch, isNotNull);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(fixture.mutations, hasLength(1));
      final startPayload = jsonDecode(fixture.mutations.single.body) as Map;
      expect(startPayload['action'], 'start');
      expect(startPayload['qr_payload'], _inlineWipQr);
      expect(startPayload['progress_batch_id'], 'inline-opening-wip');
      expect(_resumeWipCard(tester).openingWipBatch, isNull);
      expect(_resumeWipCard(tester).previousProgressBatch, isNull);

      // A recorded output pauses the same session without releasing its input.
      fixture.sessionJson['status'] = 'roll_detached';
      expect(fixture.events.hasListener, isTrue);
      fixture.changePhase('paused', publish: true);
      await tester.pumpAndSettle();
      final dynamic card = _resumeWipCard(tester);
      expect(card.uiState.contractSynchronized, isTrue);
      expect(card.uiState.previousProgressReady, isFalse);
      expect(card.openingWipBatch, isNull);
      expect(card.previousProgressBatch, isNull);
      expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      await tester.ensureVisible(_resumeWipButton());
      await tester.tap(_resumeWipButton());
      await tester.pumpAndSettle();
      expect(fixture.mutations, hasLength(2));
      final resume = jsonDecode(fixture.mutations.last.body) as Map;
      expect(resume['action'], 'resume');
      expect(resume.containsKey('qr_payload'), isFalse);
      expect(resume.containsKey('progress_batch_id'), isFalse);
    }, () => MockClient(fixture.respond));
  });

  for (final satisfied in [false, true]) {
    testWidgets('resume WIP: mandatory materials satisfied=$satisfied',
        (tester) async {
      final fixture = _ResumeWipFixture()
        ..materialScanRequired = true
        ..materialSatisfied = satisfied;
      await http.runWithClient(() async {
        await fixture.open(tester);
        final dynamic card = _resumeWipCard(tester);
        expect(card.uiState.contractSynchronized, isTrue);
        expect(card.materialStartReady, satisfied);
        expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed,
            satisfied ? isNotNull : isNull);
        // Exercise the real preparation guard even for a stale button callback.
        card.onResume();
        await tester.pumpAndSettle();
        expect(fixture.mutations, satisfied ? hasLength(1) : isEmpty);
        if (satisfied) {
          final payload = jsonDecode(fixture.mutations.single.body) as Map;
          expect(payload['action'], 'resume');
          expect(payload.containsKey('qr_payload'), isFalse);
          expect(payload.containsKey('progress_batch_id'), isFalse);
        }
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('resume WIP: mandatory mold scan stays blocked', (tester) async {
    final fixture = _ResumeWipFixture()..qolipScanRequired = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      final dynamic card = _resumeWipCard(tester);
      expect(card.uiState.contractSynchronized, isTrue);
      expect(card.requiresQolipScan, isTrue);
      expect(card.qolipRequirementsLoaded, isTrue);
      expect(card.qolipScanned, isFalse);
      expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNull);
      card.onResume();
      await tester.pumpAndSettle();
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('resume WIP: missing permission grants no action',
      (tester) async {
    final fixture = _ResumeWipFixture()..allowResume = false;
    await http.runWithClient(() async {
      await fixture.open(tester);
      final dynamic card = _resumeWipCard(tester);
      expect(card.uiState.contractSynchronized, isTrue);
      expect(card.uiState.showResume, isFalse);
      expect(_resumeWipButton(), findsNothing);
      card.onResume();
      await tester.pumpAndSettle();
      expect(fixture.mutations, isEmpty);
    }, () => MockClient(fixture.respond));
  });

  for (final invalid in [
    'missing field',
    'unknown mode',
    'unknown action',
    'malformed resume flag'
  ]) {
    testWidgets('resume WIP: invalid control ($invalid) grants no action',
        (tester) async {
      final fixture = _ResumeWipFixture()..invalidControl = invalid;
      await http.runWithClient(() async {
        expect(
            AdminApparatusQueueOrderActionControl.fromJson(fixture.control())
                .contractValid,
            isFalse);
        await fixture.open(tester);
        expect(_resumeWipButton(), findsNothing);
        expect(find.byKey(const ValueKey('production-order-start-action')),
            findsNothing);
        expect(fixture.mutations, isEmpty);
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final phase in ['frozen', 'busy']) {
    testWidgets('resume WIP: $phase retains server restrictions',
        (tester) async {
      final fixture = _ResumeWipFixture(station: _rezkaId)..phase = phase;
      await http.runWithClient(() async {
        await fixture.open(tester);
        expect(_resumeWipButton(), findsNothing);
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('resume WIP: reopening a Rezka screen needs no local scan',
      (tester) async {
    final first = _ResumeWipFixture(station: _rezkaId);
    await http.runWithClient(() async {
      await first.open(tester);
      expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient(first.respond));
    final reopened = _ResumeWipFixture(station: _rezkaId);
    reopened.sessionJson.addAll(first.sessionJson);
    await http.runWithClient(() async {
      await reopened.open(tester);
      expect(_resumeWipCard(tester).openingWipBatch, isNull);
      expect(_resumeWipCard(tester).previousProgressBatch, isNull);
      expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      expect(reopened.session.sessionId, first.session.sessionId);
      expect(reopened.mutations, isEmpty);
    }, () => MockClient(reopened.respond));
  });

  for (final scenario in ['another order', 'in_use', 'wrong stage']) {
    testWidgets('resume WIP: required input rejects $scenario', (tester) async {
      final fixture = _ResumeWipFixture()
        ..resumeInputRequired = true
        ..useOpening = scenario == 'wrong stage'
        ..openingStageRejected = false
        ..wipStatus = scenario == 'in_use' ? 'in_use' : 'waiting';
      await http.runWithClient(() async {
        await fixture.open(tester);
        if (scenario == 'wrong stage') fixture.openingStageRejected = true;
        final scan = fixture.scanner(tester)(
            scenario == 'another order' ? _inlineOtherWipQr : _inlineWipQr);
        await tester.pumpAndSettle();
        _expectInlineWipGuidance(
            tester,
            switch (scenario) {
              'another order' => 'worker.qr.wrong_order_context',
              'in_use' => 'worker.qr.roll_in_use',
              _ => 'worker.opening_wip.qr_mismatch',
            },
            values: {
              if (scenario == 'another order') 'opened': 'Inline work',
              if (scenario == 'another order') 'order': 'Other inline work'
            });
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(_resumeWipCard(tester).previousProgressBatch, isNull);
        expect(_resumeWipCard(tester).openingWipBatch, isNull);
        expect(
            tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNull);
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('resume WIP: in-flight action blocks repeats', (tester) async {
    final fixture = _ResumeWipFixture()..mutationGate = Completer<void>();
    await http.runWithClient(() async {
      await fixture.open(tester);
      final dynamic card = _resumeWipCard(tester);
      expect(
          tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNotNull);
      card.onResume();
      await tester.pump();
      expect(fixture.mutations, hasLength(1));
      expect(_resumeWipCard(tester).actionInFlight, isTrue);
      expect(tester.widget<FilledButton>(_resumeWipButton()).onPressed, isNull);
      card.onResume();
      await tester.pump();
      expect(fixture.mutations, hasLength(1));
      fixture.mutationGate!.complete();
      await tester.pumpAndSettle();
      expect(fixture.mutations, hasLength(1));
    }, () => MockClient(fixture.respond));
  });

  for (final scenario in [
    'another order',
    'in_use',
    'processed',
    'wrong stage'
  ]) {
    testWidgets('resume WIP: Merge preserves $scenario rejection',
        (tester) async {
      final fixture = _ResumeWipFixture()
        ..phase = 'active'
        ..useOpening = scenario == 'wrong stage'
        ..openingStageRejected = scenario == 'wrong stage'
        ..wipStatus = const {'in_use', 'processed'}.contains(scenario)
            ? scenario
            : 'waiting';
      fixture.sessionJson['status'] = 'in_progress';
      await http.runWithClient(() async {
        await fixture.open(tester);
        final dynamic card = _resumeWipCard(tester);
        expect(card.uiState.contractSynchronized, isTrue);
        expect(card.uiState.showMerge, isTrue);
        final merge =
            find.byKey(const ValueKey('production-order-merge-action'));
        expect(tester.widget<FilledButton>(merge).onPressed, isNotNull);
        await tester.ensureVisible(merge);
        await tester.tap(merge);
        await tester.pumpAndSettle();
        expect(fixture.mutations, isEmpty, reason: 'Merge needs an input QR');
        final scan = fixture.scanner(tester)(
          scenario == 'another order' ? _inlineOtherWipQr : _inlineWipQr,
        );
        await tester.pumpAndSettle();
        _expectInlineWipGuidance(
            tester,
            switch (scenario) {
              'another order' => 'worker.qr.wrong_order_context',
              'in_use' => 'worker.qr.roll_in_use',
              'processed' => 'worker.error.wip_used',
              _ => 'worker.opening_wip.qr_mismatch',
            },
            values: {
              if (scenario == 'another order') 'opened': 'Inline work',
              if (scenario == 'another order') 'order': 'Other inline work',
            });
        expect(fixture.mutations, isEmpty);
        await _closeInlineWipGuidance(tester);
        await scan;
        expect(fixture.mutations, isEmpty);
      }, () => MockClient(fixture.respond));
    });
  }
}
