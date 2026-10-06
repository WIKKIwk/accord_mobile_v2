part of 'admin_production_map_test_screen_test.dart';

void _registerFrozenWorkerVisibilityTests() {
  for (final source in [
    'global',
    'upstream-queue',
    'status',
    'upstream-control'
  ]) {
    testWidgets(
        'worker frozen visibility survives live, search and unfreeze: $source',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      const orderId = 'zakaz-fv1';
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Laminatsiyachi',
        legalName: '',
        ref: 'frozen-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [_lamination1Id],
      );
      final saved = await MobileApi.instance.adminSaveProductionMap(
        _twoStageProductionOrderMap(
            id: orderId,
            title: 'Frozen product',
            productCode: 'FV1',
            product: 'Frozen product',
            firstApparatusId: _print7Id,
            secondApparatusId: _lamination1Id),
      );
      final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
      AdminProductionMapLiveSnapshot snapshot(int revision, bool frozen,
              {bool requested = false}) =>
          AdminProductionMapLiveSnapshot(
            maps: [saved],
            sequences: const {
              _lamination1Id: [orderId]
            },
            visibleOrderIds: const {
              _lamination1Id: [orderId]
            },
            queueStates: {
              _lamination1Id: {orderId: 'pending'},
              if (source == 'upstream-queue' && frozen)
                _print7Id: {orderId: 'frozen'},
            },
            queuePolicies: const {},
            orderControls: {
              if (source == 'global' && frozen)
                orderId: AdminOrderControlState.frozen,
              if (requested) orderId: AdminOrderControlState.freezeRequested,
            },
            orderStatuses: {
              if (source == 'status' && frozen)
                orderId: const AdminProductionOrderStatusDetail(
                    orderStatus: 'frozen'),
            },
            queueActionControls: {
              if (source == 'upstream-control' && frozen)
                _print7Id: {
                  orderId: const AdminApparatusQueueOrderActionControl(
                      state: 'frozen')
                },
            },
            completedOrders: const [
              AdminCompletedQueueOrder(
                  apparatus: _lamination1Id,
                  orderId: orderId,
                  completedAtUnix: 1)
            ],
            completionRequests: const [],
            completionRequestDecisions: const [],
            epoch: 'frozen-visibility',
            revision: revision,
          );
      var current = snapshot(1, true);
      final events = StreamController<AdminProductionMapLiveSnapshot>();
      addTearDown(events.close);
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
            readOnly: true,
            workerMode: true,
            apparatusLoader: () async => apparatus,
            queueSnapshotLoader: () async => current,
            liveEventsLoader: () => events.stream),
      ));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('worker-order-$orderId'));
      expect(row, findsNothing, reason: 'initial worker load hides the order');
      current = snapshot(2, true);
      events.add(current);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'Frozen product');
      await tester.pumpAndSettle();
      expect(row, findsNothing, reason: 'search must not restore a frozen row');
      await tester.tap(find.text('Tugallangan'));
      await tester.pumpAndSettle();
      final productLabels = find.byWidgetPredicate((widget) =>
          widget is Text && (widget.data?.contains('Frozen product') ?? false));
      expect(productLabels, findsNothing,
          reason: 'earlier completed work on this order is hidden too');
      current = snapshot(3, false);
      events.add(current);
      await tester.pumpAndSettle();
      expect(productLabels, findsWidgets,
          reason: 'unfreeze restores the completed history');
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.tap(find.text(_fixtureApparatusName(_lamination1Id)));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget, reason: 'unfreeze restores the queue');
      events.add(snapshot(2, true));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget,
          reason: 'an old freeze frame cannot hide it again');
      final staleTap = tester
          .widget<InkWell>(
              find.descendant(of: row, matching: find.byType(InkWell)).first)
          .onTap!;
      current = snapshot(4, true);
      events.add(current);
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      staleTap();
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Bu buyurtma (Frozen product) muzlatilgan. Adminga xabar bering.'),
          findsOneWidget);
      expect(
          find.byWidgetPredicate((widget) =>
              widget.runtimeType.toString() == '_ReadOnlyOrderDetailSheet'),
          findsNothing);
      dismissAdminTopNotice();
      current = snapshot(5, false, requested: true);
      events.add(current);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget,
          reason: 'a pending freeze request still lets the worker stop work');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
