part of 'worker_compact_queue_widget_test.dart';

void _expectNoHydrationErrorUi() {
  expect(
      find.byKey(const ValueKey('admin-sequence-detail-retry')), findsNothing);
  expect(_contractWarning(), findsNothing);
}

Future<void> _flushHydration(WidgetTester tester) async {
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump();
  }
}

void _registerHydratedSheetRecoveryTests() {
  testWidgets(
      'hydrated sheet fresh scoped read recovers when list baseline clears during GET',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    final dynamic filter = tester.widget(find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'WorkerQueueLimitFilter'));
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final state = tester.state(_sheet());
    final oldRead = Completer<AdminApparatusQueueSnapshot>();
    harness
      ..revision = 8
      ..detailRevision = 8
      ..pending = oldRead;
    harness.events.add(harness.snapshot());
    await _flushHydration(tester);
    expect(harness.details, hasLength(2));
    final listRead = Completer<AdminApparatusQueueSnapshot>();
    harness.queueRefresh = listRead;
    (filter.onChanged as ValueChanged<int>)(20);
    await _flushHydration(tester);
    final fresh = Completer<AdminApparatusQueueSnapshot>();
    harness.pending = fresh;
    oldRead.complete(harness.full('zakaz-a'));
    await _flushHydration(tester);
    expect(harness.details, hasLength(3),
        reason: 'A retired window read must hand off to a fresh scoped GET');
    fresh.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(listRead.isCompleted, isFalse,
        reason: 'Scoped authority must not wait for another global list read');
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    expect(_content(tester).actionsEnabled, isTrue);
    expect(identical(tester.state(_sheet()), state), isTrue);
    _expectNoHydrationErrorUi();
    listRead.complete(harness.snapshot());
    await tester.pumpAndSettle();
    await harness.close(tester);
  });

  testWidgets(
      'hydrated sheet successful stale responses catch up without another push',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    var reads = 0;
    harness
      ..revision = 8
      ..detailResponse = () async {
        harness.detailRevision = reads++ < 4 ? 7 : 8;
        return harness.full('zakaz-a');
      };
    harness.events.add(harness.snapshot());
    await _flushHydration(tester);
    expect(harness.details, hasLength(5));
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    _expectNoHydrationErrorUi();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(6),
        reason:
            'All reads completed successfully; recovery needs no later event');
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    _expectNoHydrationErrorUi();
    final recoveredReads = harness.details.length;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(recoveredReads),
        reason: 'Healthy detail never polls');
    await harness.close(tester);
  });

  for (final invalid in ['missing', 'inconsistent']) {
    testWidgets(
        'hydrated sheet successful $invalid control read is not published and recovers',
        (tester) async {
      final harness = _CompactHarness();
      await harness.mount(tester);
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      final state = tester.state(_sheet());
      harness
        ..revision = 8
        ..detailRevision = 8;
      if (invalid == 'missing') {
        harness.includeDetailControl = false;
      } else {
        harness.detailControlPatch
            .addAll(_presentationHarness('paused resume').detailControlPatch);
        harness.detailControlPatch['state'] = 'paused';
        expect(
            harness
                .full('zakaz-a')
                .queueActionControls[_station]!['zakaz-a']!
                .contractValid,
            isTrue,
            reason:
                'The valid control disagrees only with this snapshot queue state');
      }
      harness.events.add(harness.snapshot());
      await _flushHydration(tester);
      expect(
          (tester.widget(_sheet()) as dynamic).currentQueueSnapshot(), isNull);
      expect(_content(tester).uiState.contractSynchronized, isFalse);
      expect(_content(tester).actionsEnabled, isFalse);
      _expectNoHydrationErrorUi();
      harness
        ..includeDetailControl = true
        ..detailControlPatch.clear();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(_content(tester).uiState.contractSynchronized, isTrue);
      expect(identical(tester.state(_sheet()), state), isTrue);
      _expectNoHydrationErrorUi();
      await harness.close(tester);
    });
  }

  testWidgets(
      'hydrated sheet transient refresh retries automatically and retains the form',
      (tester) async {
    final harness = _presentationHarness('print preflight');
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final state = tester.state(_sheet());
    harness
      ..revision = 8
      ..detailRevision = 8
      ..detailError = const MobileApiException(
          statusCode: 503,
          code: 'unavailable',
          message: 'Detail read unavailable');
    harness.events.add(harness.snapshot());
    await _flushHydration(tester);
    expect(harness.details, hasLength(2));
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    expect(find.text('Detail read unavailable'), findsNothing);
    _expectNoHydrationErrorUi();
    harness.detailError = null;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    expect(identical(tester.state(_sheet()), state), isTrue);
    _expectNoHydrationErrorUi();
    await harness.close(tester);
  });

  testWidgets(
      'hydrated sheet recovery backs off while stale then stops on fresh authority',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    harness.revision = 8;
    harness.events.add(harness.snapshot());
    await _flushHydration(tester);
    expect(harness.details, hasLength(5));
    await tester.pump(const Duration(milliseconds: 250));
    await _flushHydration(tester);
    expect(harness.details, hasLength(9));
    harness.detailRevision = 8;
    await tester.pump(const Duration(milliseconds: 550));
    await tester.pumpAndSettle();
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    expect(harness.details, hasLength(10));
    _expectNoHydrationErrorUi();
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(harness.details, hasLength(10));
    await harness.close(tester);
  });

  testWidgets(
      'hydrated sheet timeout fresh read keeps its lease after late old completion and reopen',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final old = Completer<AdminApparatusQueueSnapshot>();
    harness
      ..revision = 8
      ..detailRevision = 8
      ..pending = old;
    harness.events.add(harness.snapshot());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    _expectNoHydrationErrorUi();
    final fresh = Completer<AdminApparatusQueueSnapshot>();
    harness.pending = fresh;
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(harness.details, hasLength(3));
    old.complete(harness.full('zakaz-a'));
    await tester.pump();
    await tester
        .tap(find.byKey(const ValueKey('production-order-detail-close')));
    await tester.pumpAndSettle();
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pump();
    expect(harness.details, hasLength(3),
        reason: 'An old completion cannot retire the newer shared GET lease');
    fresh.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    _expectNoHydrationErrorUi();
    await harness.close(tester);
  });

  testWidgets(
      'hydrated sheet shares one timeout budget across stale retry and hung GET',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    final stale = Completer<AdminApparatusQueueSnapshot>();
    final hung = Completer<AdminApparatusQueueSnapshot>();
    var reads = 0;
    harness
      ..revision = 8
      ..detailResponse = () => reads++ == 0 ? stale.future : hung.future;
    harness.events.add(harness.snapshot());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4900));
    stale.complete(harness.full('zakaz-a'));
    await tester.pump();
    expect(harness.details, hasLength(3));
    final fresh = Completer<AdminApparatusQueueSnapshot>();
    harness
      ..detailRevision = 8
      ..detailResponse = () => fresh.future;
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(harness.details, hasLength(4),
        reason:
            'The entire stale+hung read expires before automatic fresh GET');
    hung.complete(harness.full('zakaz-a'));
    await tester.pump();
    fresh.complete(harness.full('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    _expectNoHydrationErrorUi();
    await harness.close(tester);
  });

  testWidgets(
      'hydrated sheet forbidden refresh stops automatic reads until reopened',
      (tester) async {
    final harness = _presentationHarness('print preflight');
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    harness
      ..revision = 8
      ..detailRevision = 8
      ..detailError = const MobileApiException(
          statusCode: 403, code: 'forbidden', message: 'Read access denied');
    harness.events.add(harness.snapshot());
    await _flushHydration(tester);
    _expectNoHydrationErrorUi();
    expect(find.text('Read access denied'), findsNothing);
    expect(_content(tester).uiState.contractSynchronized, isFalse);
    final reads = harness.details.length;
    harness
      ..revision = 9
      ..detailRevision = 9
      ..detailError = null;
    harness.events.add(harness.snapshot());
    await tester.pump(const Duration(seconds: 20));
    await _flushHydration(tester);
    expect(harness.details, hasLength(reads));
    await tester
        .tap(find.byKey(const ValueKey('production-order-detail-close')));
    await tester.pumpAndSettle();
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    await harness.close(tester);
  });

  for (final boundary in ['close', 'account']) {
    testWidgets('hydrated sheet automatic recovery cancels on $boundary',
        (tester) async {
      final harness = _CompactHarness();
      await harness.mount(tester);
      await tester.tap(_workerRow('zakaz-a'));
      await tester.pumpAndSettle();
      harness
        ..revision = 8
        ..detailRevision = 8
        ..detailError = const MobileApiException(
            code: 'unavailable', message: 'Unavailable');
      harness.events.add(harness.snapshot());
      await _flushHydration(tester);
      final reads = harness.details.length;
      if (boundary == 'close') {
        await tester
            .tap(find.byKey(const ValueKey('production-order-detail-close')));
      } else {
        AppSession.instance.token = 'replacement-recovery-account';
        AppSession.instance.profile = AppSession.instance.profile!
            .copyWith(ref: 'replacement-recovery-worker');
        AppSession.instance.revision.value++;
      }
      await _flushHydration(tester);
      await tester.pump(const Duration(seconds: 20));
      await _flushHydration(tester);
      expect(harness.details, hasLength(reads));
      _expectNoHydrationErrorUi();
      await harness.close(tester);
    });
  }

  testWidgets(
      'hydrated sheet automatic recovery pauses in background and resumes fresh',
      (tester) async {
    final harness = _CompactHarness();
    await harness.mount(tester);
    await tester.tap(_workerRow('zakaz-a'));
    await tester.pumpAndSettle();
    harness
      ..revision = 8
      ..detailRevision = 8
      ..detailError =
          const MobileApiException(code: 'unavailable', message: 'Unavailable');
    harness.events.add(harness.snapshot());
    await _flushHydration(tester);
    final reads = harness.details.length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    try {
      await tester.pump(const Duration(seconds: 20));
      await _flushHydration(tester);
      expect(harness.details, hasLength(reads));
      harness.detailError = null;
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    await tester.pumpAndSettle();
    expect(_content(tester).uiState.contractSynchronized, isTrue);
    _expectNoHydrationErrorUi();
    await harness.close(tester);
  });
}
