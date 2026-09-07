part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerLatencyTests() {
  for (final action in ['start', 'resume']) {
    testWidgets(
        'worker $action sends one POST without preflight and releases UI before refresh',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      const orderId = 'zakaz-worker-fast-start';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'worker-fast',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_print7Id],
      );
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        title: 'Fast start',
        productCode: 'FAST',
        apparatusId: _print7Id,
        product: 'Fast product',
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _print7Id, orderIds: const [orderId]);
      setMobileApiTestModeQueueActionControlFixture(
          apparatus: _print7Id,
          orderId: orderId,
          control: action == 'start'
              ? _freshStartQueueControl()
              : _requeuedQueueControl(ready: true));
      await _usePhoneViewport(tester);
      final requests = <http.Request>[];
      final post = Completer<http.Response>();
      final refresh = Completer<http.Response>();
      await http.runWithClient(() async {
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
          home: const AdminProductionMapOrdersScreen(
              readOnly: true, workerMode: true),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('7 ta rangli bosma aparat'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('worker-fast-start').first);
        await tester.pumpAndSettle();
        final start = action == 'start'
            ? find.widgetWithText(FilledButton, 'Boshlash')
            : find.descendant(
                of: find
                    .byKey(const ValueKey('production-order-resume-visible')),
                matching: find.byType(FilledButton));
        expect(start, findsOneWidget);
        await TestModeController.instance.setEnabled(false);
        // Two callbacks in the same frame must not send two mutations.
        final onPressed = tester.widget<FilledButton>(start).onPressed!;
        onPressed();
        onPressed();
        await tester.pump();
        expect(requests, hasLength(1));
        expect(requests.single.method, 'POST');
        expect(requests.single.url.path, endsWith('/queue-action'));
        expect(jsonDecode(requests.single.body)['action'], action);
        post.complete(http.Response(
            jsonEncode({
              'ok': true,
              'states': {orderId: 'in_progress'},
              'order_status': {
                'order_status': 'in_progress',
                'lifecycle_status': 'in_progress'
              },
              'order_control': {'state': 'active'},
            }),
            200));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // An acknowledged Start must stop showing its old button even while
        // both canonical background refreshes remain deliberately unresolved.
        expect(start, findsNothing);
        expect(requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(refresh.isCompleted, isFalse);
        expect(requests.where((r) => r.method == 'GET'), isNotEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        refresh.complete(http.Response('{"error":"store_failed"}', 503));
        await tester.pump();
        await tester.pump(const Duration(seconds: 11));
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) {
                requests.add(request);
                return request.method == 'POST' ? post.future : refresh.future;
              }));
    });
  }
}
