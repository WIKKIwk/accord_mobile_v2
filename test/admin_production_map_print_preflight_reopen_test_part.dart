part of 'admin_production_map_test_screen_test.dart';

const _colourReopenOrderId = 'zakaz-preflight-reopen';
const _colourReopenAction = ValueKey('print-preflight-reopen-action');
const _colourReopenConfirm = ValueKey('print-preflight-reopen-confirm');

class _ColourReopenFixture {
  String status = 'passed';
  int revision = 1;
  int holdRevision = 1;
  bool rejectStarted = false;
  bool loseResponse = false;
  Completer<void>? mutationGate;
  late ProductionMapSaved order;
  final mutations = <http.Request>[];
  final events = StreamController<AdminProductionMapLiveSnapshot>.broadcast();

  String get queueState =>
      const {'passed', 'running'}.contains(status) ? 'print_preflight' : status;

  Map<String, dynamic> hold() => {
        'hold_id': 'colour-reopen-hold',
        'idempotency_key': 'colour-reopen-hold',
        'order_id': _colourReopenOrderId,
        'apparatus': _print7Id,
        'status': status,
        'revision': holdRevision,
      };

  Map<String, dynamic> control() => {
        'state': queueState,
        'allowed_actions': switch (status) {
          'passed' || 'pending' => ['start'],
          'in_progress' => ['pause', 'complete'],
          'paused' => ['resume'],
          _ => <String>[],
        },
        'previous_stage_ready': true,
        'complete_requires_full_report': false,
        'print_preflight_allowed': status == 'pending',
        if (queueState == 'print_preflight') 'print_preflight': hold(),
        'interaction': {
          'mode': switch (status) {
            'running' => 'fresh_start_blocked',
            'in_progress' => 'in_progress',
            'paused' => 'paused',
            'completed' => 'completed',
            _ => 'fresh_start',
          },
          'start_materials_mode': 'hidden',
          'material_scan_required': false,
          'assigned_materials_display_only': true,
          'material_intake_allowed': false,
          'resume_input_required': false,
          'previous_wip_mode': 'not_required',
          'qolip_mode': 'not_required',
          'blocking_reason_code':
              status == 'running' ? 'print_preflight_active' : '',
        },
      };

  Map<String, dynamic> controlState() => {
        'apparatus': _print7Id,
        'order_id': _colourReopenOrderId,
        'epoch': 'colour-reopen-server',
        'rev': revision,
        'control': control(),
        'queue_state': queueState,
        'stage_states': {},
        'order_control': 'active',
      };

  AdminProductionMapLiveSnapshot snapshot() =>
      AdminProductionMapLiveSnapshot.fromJson({
        ...scanSequence(),
        'epoch': 'colour-reopen-server',
        'rev': revision,
        'scope': 'colour-reopen-worker',
        'maps': [
          {'map': order.map.toJson(), 'program': <String, dynamic>{}}
        ],
        'sequences': {
          _print7Id: [_colourReopenOrderId]
        },
        'visible_order_ids': {
          _print7Id: [_colourReopenOrderId]
        },
        'queue_states': {
          _print7Id: {_colourReopenOrderId: queueState}
        },
        'queue_action_controls': {
          _print7Id: {_colourReopenOrderId: control()}
        },
        'stage_states': {},
        'order_controls': {},
        'queue_policies': [],
      });

  void changeStatus(String next) {
    if (status != next) holdRevision++;
    status = next;
    revision++;
    setMobileApiTestModeQueueActionControlFixture(
      apparatus: _print7Id,
      orderId: _colourReopenOrderId,
      control: AdminApparatusQueueOrderActionControl.fromJson(control()),
    );
  }

  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/print-preflight')) {
      mutations.add(request);
      expect(jsonDecode(request.body), containsPair('action', 'reopen'));
      expect(jsonDecode(request.body),
          containsPair('hold_id', 'colour-reopen-hold'));
      expect(jsonDecode(request.body),
          containsPair('expected_revision', holdRevision));
      if (mutationGate != null) await mutationGate!.future;
      if (rejectStarted) {
        changeStatus('in_progress');
        return http.Response('{"error":"print_preflight_not_ready"}', 409);
      }
      changeStatus('running');
      if (loseResponse)
        throw http.ClientException('Response lost after commit');
      return http.Response(
          jsonEncode({
            'ok': true,
            'hold': hold(),
            'control_state': controlState(),
          }),
          200);
    }
    if (request.url.path.endsWith('/order-scan-bootstrap')) {
      return http.Response(
          jsonEncode({
            'ok': true,
            'control_state': controlState(),
            'sections': {
              'materials': {'status': 'not_required'},
              'qolips': {'status': 'not_required'},
            },
          }),
          200);
    }
    return http.Response('{}', 200);
  }

  Future<void> open(WidgetTester tester, {bool workerMode = true}) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = SessionProfile(
      role: workerMode ? UserRole.aparatchi : UserRole.admin,
      displayName: 'Worker',
      legalName: '',
      ref: 'colour-reopen-worker',
      phone: '',
      avatarUrl: '',
      capabilities: [
        if (!workerMode) 'admin.access',
        'apparatus.queue.read',
        'apparatus.queue.manage'
      ],
      assignedApparatus: [_print7Id],
    );
    order = await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: _colourReopenOrderId,
      title: 'Colour trial',
      productCode: 'COLOUR',
      apparatusId: _print7Id,
      product: 'Colour trial',
    ));
    final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
    changeStatus(status);
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
      theme: ThemeData(useMaterial3: true),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
          readOnly: workerMode,
          workerMode: workerMode,
          queueSnapshotLoader: () async => snapshot(),
          liveEventsLoader: () => events.stream,
          apparatusLoader: () async => workerMode
              ? apparatus
              : apparatus.where((item) => item.id == _print7Id).toList(),
          closedOrdersLoader: () async => const []),
    ));
    await tester.pumpAndSettle();
    if (workerMode) {
      await tester.tap(find.text('7 ta rangli bosma aparat'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.longPress(
        find.byKey(const ValueKey('worker-order-$_colourReopenOrderId')));
    await tester.pumpAndSettle();
    expect(find.byKey(_colourReopenAction), findsOneWidget);
    await tester.tap(find.byKey(_colourReopenAction));
    await tester.pumpAndSettle();
    expect(
        find.text('Rostdan ham rang chiqarilyapti holatiga qaytarmoqchimisiz?'),
        findsOneWidget);
    expect(mutations, isEmpty,
        reason: 'Opening the menu and dialog must not mutate the trial');
  }
}

class _UnreadableColourReopenFixture extends _ColourReopenFixture {
  _UnreadableColourReopenFixture({required this.commitBeforeFailure});

  final bool commitBeforeFailure;
  bool readsUnavailable = false;

  @override
  AdminProductionMapLiveSnapshot snapshot() {
    if (readsUnavailable) {
      throw http.ClientException('Read temporarily unavailable');
    }
    return super.snapshot();
  }

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/print-preflight')) {
      mutations.add(request);
      expect(jsonDecode(request.body),
          containsPair('expected_revision', holdRevision));
      readsUnavailable = true;
      if (commitBeforeFailure) {
        changeStatus('running');
        throw http.ClientException('Response lost after commit');
      }
      return http.Response('{"error":"print_preflight_not_ready"}', 409);
    }
    return super.respond(request);
  }
}

class _DelayedColourReopenFixture extends _ColourReopenFixture {
  final reply = Completer<void>();
  AdminProductionMapLiveSnapshot? stale;
  bool returnStale = false;

  @override
  AdminProductionMapLiveSnapshot snapshot() =>
      returnStale ? stale! : super.snapshot();

  AdminProductionMapLiveSnapshot latest() => super.snapshot();

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/print-preflight')) {
      mutations.add(request);
      changeStatus('running');
      stale = super.snapshot();
      final response = http.Response(jsonEncode({
        'ok': true,
        'hold': hold(),
        'control_state': controlState(),
      }), 200);
      await reply.future;
      returnStale = true;
      return response;
    }
    return super.respond(request);
  }
}

void _registerPrintPreflightReopenTests() {
  for (final committed in [false, true]) {
    testWidgets(
        'print preflight reopen retains confirmed colour after ${committed ? 'lost response' : 'rejection'} and failed refresh',
        (tester) async {
      final fixture = _UnreadableColourReopenFixture(
          commitBeforeFailure: committed);
      await http.runWithClient(() async {
        await fixture.open(tester);
        final row = find.byKey(
            const ValueKey('worker-order-$_colourReopenOrderId'));
        LinearGradient? gradient(Widget widget) {
          final decoration = switch (widget) {
            DecoratedBox() => widget.decoration,
            Ink() => widget.decoration,
            _ => null,
          };
          return decoration is BoxDecoration &&
                  decoration.gradient is LinearGradient
              ? decoration.gradient as LinearGradient
              : null;
        }
        final coloured = find.descendant(
            of: row,
            matching: find.byWidgetPredicate((w) => gradient(w) != null));
        final before = gradient(tester.widget(coloured))!.colors;
        await fixture.openConfirmation(tester);
        await tester.tap(find.byKey(_colourReopenConfirm));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(fixture.status, committed ? 'running' : 'passed');
        expect(fixture.mutations, hasLength(1));
        expect(gradient(tester.widget(coloured))!.colors, before,
            reason: 'An uncertain response must retain the confirmed display');
        // Recover through a canonical read/live event, never another POST.
        fixture.readsUnavailable = false;
        fixture.changeStatus(fixture.status);
        fixture.events.add(fixture.snapshot());
        await tester.pumpAndSettle();
        dismissAdminTopNotice();
        if (committed) {
          await tester.tap(row);
          await tester.pumpAndSettle();
          expect(find.widgetWithText(FilledButton, 'Rang chiqdi'), findsOneWidget);
          expect(find.widgetWithText(OutlinedButton, 'Rang chiqmadi'), findsOneWidget);
        } else {
          await tester.longPress(row);
          await tester.pumpAndSettle();
          expect(find.byKey(_colourReopenAction), findsOneWidget);
        }
        expect(fixture.mutations, hasLength(1));
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('print preflight reopen late response preserves newer live approval',
      (tester) async {
    final fixture = _DelayedColourReopenFixture();
    await http.runWithClient(() async {
      await fixture.open(tester);
      addTearDown(() {
        if (!fixture.reply.isCompleted) fixture.reply.complete();
      });
      await fixture.openConfirmation(tester);
      await tester.tap(find.byKey(_colourReopenConfirm));
      await tester.pump();
      fixture.changeStatus('passed');
      fixture.events.add(fixture.latest());
      await tester.pumpAndSettle();
      fixture.reply.complete();
      await tester.pumpAndSettle();
      expect(fixture.status, 'passed');
      await tester.longPress(find.byKey(
          const ValueKey('worker-order-$_colourReopenOrderId')));
      await tester.pumpAndSettle();
      expect(find.byKey(_colourReopenAction), findsOneWidget,
          reason: 'An old reply/read cannot erase newer canonical controls');
      expect(fixture.mutations, hasLength(1));
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets('print preflight reopen refuses a superseded confirmation',
      (tester) async {
    final fixture = _ColourReopenFixture();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.openConfirmation(tester);
      fixture.changeStatus('running');
      fixture.changeStatus('passed');
      fixture.events.add(fixture.snapshot());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_colourReopenConfirm));
      await tester.pumpAndSettle();
      expect(fixture.mutations, isEmpty);
      expect(fixture.status, 'passed');
    }, () => MockClient(fixture.respond));
  });

  for (final tab in ['Buyurtmalar', 'Ketma-ketlik']) {
    testWidgets('print preflight reopen from admin $tab requires confirmation',
        (tester) async {
      final fixture = _ColourReopenFixture();
      await http.runWithClient(() async {
        await fixture.open(tester, workerMode: false);
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        final order = find.byKey(ValueKey(tab == 'Buyurtmalar'
            ? 'opened-order-$_colourReopenOrderId'
            : 'sequence-row-$_print7Id-$_colourReopenOrderId'));
        await tester.longPress(order);
        await tester.pumpAndSettle();
        expect(find.byKey(_colourReopenAction), findsOneWidget);
        await tester.tap(find.byKey(_colourReopenAction));
        await tester.pumpAndSettle();
        expect(fixture.mutations, isEmpty);
        await tester.tap(find.byKey(_colourReopenConfirm));
        await tester.pumpAndSettle();
        expect(fixture.status, 'running');
        expect(fixture.mutations, hasLength(1));
        await tester.longPress(order);
        await tester.pumpAndSettle();
        expect(find.byKey(_colourReopenAction), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final dismiss in [false, true]) {
    testWidgets(
        'print preflight reopen ${dismiss ? 'dismiss' : 'cancel'} sends no request',
        (tester) async {
      final fixture = _ColourReopenFixture();
      await http.runWithClient(() async {
        await fixture.open(tester);
        await fixture.openConfirmation(tester);
        if (dismiss) {
          await tester.tapAt(const Offset(5, 5));
        } else {
          await tester
              .tap(find.byKey(const ValueKey('print-preflight-reopen-cancel')));
        }
        await tester.pumpAndSettle();
        expect(fixture.mutations, isEmpty);
        expect(fixture.status, 'passed');
      }, () => MockClient(fixture.respond));
    });
  }

  for (final loseResponse in [false, true]) {
    testWidgets(
        'print preflight reopen restores outcome buttons after ${loseResponse ? 'lost response' : 'confirmation'}',
        (tester) async {
      final fixture = _ColourReopenFixture()
        ..loseResponse = loseResponse
        ..mutationGate = Completer<void>();
      await http.runWithClient(() async {
        await fixture.open(tester);
        final original = fixture.snapshot();
        await fixture.openConfirmation(tester);
        await tester.tap(find.byKey(_colourReopenConfirm));
        await tester.pump();
        expect(fixture.mutations, hasLength(1));
        expect(fixture.status, 'passed',
            reason: 'Wait for the server before changing the colour state');
        fixture.mutationGate!.complete();
        await tester.pumpAndSettle();
        expect(fixture.status, 'running');
        expect(fixture.mutations, hasLength(1));
        expect(
            original.queueActionControls[_print7Id]![_colourReopenOrderId]!
                .printPreflight!.isPassed,
            isTrue);
        dismissAdminTopNotice();
        await tester.tap(
            find.byKey(const ValueKey('worker-order-$_colourReopenOrderId')));
        await tester.pumpAndSettle();
        expect(
            find.widgetWithText(FilledButton, 'Rang chiqdi'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Rang chiqmadi'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  for (final status in [
    'pending',
    'running',
    'in_progress',
    'paused',
    'completed'
  ]) {
    testWidgets('print preflight reopen is hidden for $status', (tester) async {
      final fixture = _ColourReopenFixture()..status = status;
      await http.runWithClient(() async {
        await fixture.open(tester);
        final card =
            find.byKey(const ValueKey('worker-order-$_colourReopenOrderId'));
        if (status == 'completed') {
          expect(card, findsNothing);
        } else {
          await tester.longPress(card);
        }
        await tester.pumpAndSettle();
        expect(find.byKey(_colourReopenAction), findsNothing);
        expect(fixture.mutations, isEmpty);
        expect(tester.takeException(), isNull);
      }, () => MockClient(fixture.respond));
    });
  }

  testWidgets('print preflight reopen sends no request after a live Start',
      (tester) async {
    final fixture = _ColourReopenFixture();
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.openConfirmation(tester);
      fixture.changeStatus('in_progress');
      fixture.events.add(fixture.snapshot());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_colourReopenConfirm));
      await tester.pumpAndSettle();
      expect(fixture.mutations, isEmpty);
      expect(fixture.status, 'in_progress');
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });

  testWidgets(
      'print preflight reopen rejects work started while confirmation was open',
      (tester) async {
    final fixture = _ColourReopenFixture()..rejectStarted = true;
    await http.runWithClient(() async {
      await fixture.open(tester);
      await fixture.openConfirmation(tester);
      await tester.tap(find.byKey(_colourReopenConfirm));
      await tester.pumpAndSettle();
      expect(fixture.mutations, hasLength(1));
      expect(fixture.status, 'in_progress');
      dismissAdminTopNotice();
      await tester.longPress(
          find.byKey(const ValueKey('worker-order-$_colourReopenOrderId')));
      await tester.pumpAndSettle();
      expect(find.byKey(_colourReopenAction), findsNothing);
      expect(fixture.mutations, hasLength(1));
      expect(tester.takeException(), isNull);
    }, () => MockClient(fixture.respond));
  });
}
