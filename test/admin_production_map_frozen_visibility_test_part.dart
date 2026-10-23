part of 'admin_production_map_test_screen_test.dart';

void _registerFrozenWorkerVisibilityTests() {
  for (final source in [
    'global',
    'upstream-queue',
    'status',
    'upstream-control',
    'upstream-issue'
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
            queuePolicies: {
              if (source == 'upstream-issue')
                _lamination1Id: const AdminApparatusQueuePolicy(
                    apparatus: _lamination1Id,
                    policy: ApparatusQueuePolicy.freePick),
            },
            orderControls: {
              if (source == 'global' && frozen)
                orderId: AdminOrderControlState.frozen,
              if (requested) orderId: AdminOrderControlState.freezeRequested,
            },
            orderStatuses: {
              if (source == 'upstream-issue' && frozen)
                orderId: const AdminProductionOrderStatusDetail(
                    orderStatus: 'active', completedWithIssueCount: 1),
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
      final events =
          StreamController<AdminProductionMapLiveSnapshot>.broadcast();
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final row = find.byKey(const ValueKey('worker-order-$orderId'));
      if (source.startsWith('upstream-')) {
        expect(row, findsOneWidget,
            reason:
                'an upstream hold or issue leaves downstream WIP available');
        current = snapshot(2, true);
        events.add(current);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.enterText(
            find.byType(EditableText).first, 'Frozen product');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(row, findsOneWidget,
            reason: 'live refresh and search preserve downstream availability');
        await tester.tap(find.widgetWithText(Tab, 'Tugallangan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('Frozen product'), findsWidgets,
            reason: 'healthy completed history stays visible downstream');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        return;
      }
      expect(row, findsNothing, reason: 'initial worker load hides the order');
      current = snapshot(2, true);
      events.add(current);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.byType(EditableText).first, 'Frozen product');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(row, findsNothing, reason: 'search must not restore a frozen row');
      await tester.tap(find.widgetWithText(Tab, 'Tugallangan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final productLabels = find.byKey(
          const ValueKey(('worker-completed-order', orderId, _lamination1Id)));
      expect(productLabels, findsNothing,
          reason: 'earlier completed work on this order is hidden too');
      current = snapshot(3, false);
      events.add(current);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.widgetWithText(Tab, 'Tugallangan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(productLabels, findsWidgets,
          reason: 'unfreeze restores the completed history');
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.tap(find.text(_fixtureApparatusName(_lamination1Id)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(row, findsOneWidget, reason: 'unfreeze restores the queue');
      events.add(snapshot(2, true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(row, findsOneWidget,
          reason: 'an old freeze frame cannot hide it again');
      final staleTap = tester
          .widget<InkWell>(
              find.descendant(of: row, matching: find.byType(InkWell)).first)
          .onTap!;
      current = snapshot(4, true);
      events.add(current);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(row, findsNothing);
      staleTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(row, findsOneWidget,
          reason: 'a pending freeze request still lets the worker stop work');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }
}
