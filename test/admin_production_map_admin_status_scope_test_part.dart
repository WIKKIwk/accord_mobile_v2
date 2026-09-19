part of 'admin_production_map_test_screen_test.dart';

void _registerAdminStatusScopeTests() {
  for (final scenario in [
    'lamination-1',
    'lamination-2',
    'local-only',
    'repeat'
  ]) {
    testWidgets('admin waiting stage uses server operation state: $scenario',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AdminSequenceApparatusStore.instance.clearCache();
      addTearDown(AdminSequenceApparatusStore.instance.clearCache);
      const orderId = 'zakaz-0004';
      final repeated = scenario == 'repeat';
      final producer =
          scenario == 'lamination-2' ? _lamination2Id : _lamination1Id;
      final saved = await MobileApi.instance.adminSaveProductionMap(
        ProductionMapDefinition.fromJson({
          'id': orderId,
          'order_number': '0004',
          'title': 'Kids 15 sht',
          'product_code': 'KIDS',
          'nodes': [
            {'id': 'start', 'kind': 'start', 'title': 'Start'},
            {
              'id': 'print',
              'kind': 'apparatus',
              'title': 'Bosma',
              'apparatus_id': _print9Id
            },
            for (final (id, apparatus) in [
              ('lam1', _lamination1Id),
              ('lam2', _lamination2Id)
            ])
              {
                'id': id,
                'kind': 'apparatus',
                'title': _fixtureApparatusName(apparatus),
                'apparatus_id': apparatus,
                'alternative_group_id': 'lamination'
              },
            {
              'id': 'next',
              'kind': 'apparatus',
              'title': repeated ? 'Laminatsiya 1' : 'Rezka',
              'apparatus_id': repeated ? _lamination1Id : _rezkaId
            },
            {'id': 'end', 'kind': 'end', 'title': 'Kids'},
          ],
          'edges': [
            {'from': 'start', 'to': 'print'},
            for (final id in ['lam1', 'lam2']) ...[
              {'from': 'print', 'to': id},
              {'from': id, 'to': 'next'},
            ],
            {'from': 'next', 'to': 'end'},
          ],
        }),
      );
      final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
      AdminProductionMapLiveSnapshot snapshot(int revision, bool sharedDone) =>
          AdminProductionMapLiveSnapshot(
            maps: [saved],
            sequences: const {},
            visibleOrderIds: const {},
            queueStates: {
              _print9Id: {orderId: 'completed'},
              producer: {orderId: 'completed'},
            },
            stageStates: {
              orderId: {
                'print': 'completed',
                'lam1': sharedDone || producer == _lamination1Id
                    ? 'completed'
                    : 'pending',
                'lam2': sharedDone || producer == _lamination2Id
                    ? 'completed'
                    : 'pending',
                'next': 'pending',
              },
            },
            queuePolicies: const {},
            orderControls: const {},
            orderStatuses: const {
              orderId: AdminProductionOrderStatusDetail(
                  lifecycleStatus: 'in_progress',
                  orderStatus: 'partially_completed'),
            },
            completedOrders: const [],
            completionRequests: const [],
            completionRequestDecisions: const [],
            epoch: 'waiting-stage',
            revision: revision,
          );
      var current = snapshot(1, scenario != 'local-only');
      await _usePhoneViewport(tester);
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
          apparatusLoader: () async => apparatus,
          queueSnapshotLoader: () async => current,
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pumpAndSettle();
      final watermark =
          find.byKey(const ValueKey('opened-order-active-watermark-$orderId'));
      void expectWaiting(String name) {
        expect(watermark, findsOneWidget);
        expect(
            find.descendant(
                of: watermark, matching: find.text('Kutmoqda: $name')),
            findsWidgets);
      }

      expectWaiting(scenario == 'local-only'
          ? 'Laminatsiya 2'
          : repeated
              ? 'Laminatsiya 1'
              : 'Rezka');
      if (scenario == 'local-only') {
        // A participant's local report does not close the shared operation.
        // Only the later server-confirmed stage closure advances the watermark.
        current = snapshot(2, true);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expectWaiting('Rezka');
      }
      if (!repeated) {
        expect(
            find.descendant(
                of: watermark, matching: find.text('Kutmoqda: Laminatsiya 2')),
            findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }

  for (final (globalState, localState, accent) in [
    ('in_progress', 'pending', null),
    ('paused', 'pending', null),
    ('waiting_next_stage', 'pending', null),
    ('print_preflight', 'pending', null),
    ('paused', 'in_progress', const Color(0xFF2E7D32)),
    ('in_progress', 'paused', const Color(0xFFF9A825)),
    ('in_progress', 'frozen', const Color(0xFFC62828)),
    ('frozen', 'pending', const Color(0xFFC62828)),
    ('completed_with_issue', 'pending', const Color(0xFFC62828)),
  ]) {
    testWidgets(
        'admin sequence scopes color: global=$globalState local=$localState',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AdminSequenceApparatusStore.instance.clearCache();
      addTearDown(AdminSequenceApparatusStore.instance.clearCache);
      const orderId = 'zakaz-0021';
      final saved = await MobileApi.instance.adminSaveProductionMap(
        _twoStageProductionOrderMap(
          id: orderId,
          title: 'Scoped status',
          productCode: 'SCOPE',
          product: 'Scope',
          firstApparatusId: _print7Id,
          secondApparatusId: _lamination1Id,
        ),
      );
      final apparatus = (await MobileApi.instance.adminApparatus(limit: 200))
          .where((item) => item.id == _print7Id || item.id == _lamination1Id)
          .toList();
      AdminProductionMapLiveSnapshot snapshot(int revision, String local) =>
          AdminProductionMapLiveSnapshot(
            maps: [saved],
            sequences: const {
              _print7Id: [orderId],
              _lamination1Id: [orderId]
            },
            visibleOrderIds: const {
              _print7Id: [orderId],
              _lamination1Id: [orderId]
            },
            queueStates: {
              _print7Id: {orderId: local},
              _lamination1Id: {orderId: 'in_progress'},
            },
            orderStatuses: {
              orderId: AdminProductionOrderStatusDetail(
                  lifecycleStatus: 'in_progress', orderStatus: globalState),
            },
            queuePolicies: const {},
            orderControls: const {},
            completedOrders: const [],
            completionRequests: const [],
            completionRequestDecisions: const [],
            epoch: 'scoped-color',
            revision: revision,
          );
      var current = snapshot(1, localState);
      await _usePhoneViewport(tester);
      final theme = ThemeData(useMaterial3: true);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
          apparatusLoader: () async => apparatus,
          queueSnapshotLoader: () async => current,
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      Color rowColor(String apparatusId) {
        final row = find.byKey(ValueKey('sequence-row-$apparatusId-$orderId'));
        expect(row, findsOneWidget);
        return tester
            .widget<Material>(
                find.descendant(of: row, matching: find.byType(Material)).first)
            .color!;
      }

      Color tint(Color color) => Color.alphaBlend(color.withValues(alpha: .16),
          theme.colorScheme.surfaceContainerLowest);
      final actual = rowColor(_print7Id);
      if (accent == null) {
        expect(actual, isNot(tint(const Color(0xFF2E7D32))));
        expect(actual, isNot(tint(const Color(0xFF1565C0))));
        expect(actual, isNot(tint(const Color(0xFFF9A825))));
        expect(
            find.descendant(
                of: find
                    .byKey(const ValueKey('sequence-row-$_print7Id-$orderId')),
                matching: find.byWidgetPredicate((widget) {
                  final decoration = switch (widget) {
                    DecoratedBox() => widget.decoration,
                    Ink() => widget.decoration,
                    _ => null,
                  };
                  return decoration is BoxDecoration &&
                      decoration.gradient != null;
                })),
            findsNothing);
      } else {
        expect(actual, tint(accent));
      }
      if (globalState == 'in_progress' && localState == 'pending') {
        // Changing the apparatus filter must change the source of the color.
        await tester.tap(find.text('Aparat: 7 ta rangli bosma aparat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Laminatsiya 1').last);
        await tester.pumpAndSettle();
        expect(rowColor(_lamination1Id), tint(const Color(0xFF2E7D32)));
        await tester.tap(find.text('Aparat: Laminatsiya 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('7 ta rangli bosma aparat').last);
        await tester.pumpAndSettle();
        expect(rowColor(_print7Id), actual);
        current = snapshot(2, 'in_progress');
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(rowColor(_print7Id), tint(const Color(0xFF2E7D32)));
        // The unfiltered Orders tab must retain its global status.
        await tester.tap(find.text('Buyurtmalar'));
        await tester.pumpAndSettle();
        final row = find.byKey(const ValueKey('opened-order-$orderId'));
        expect(
            tester
                .widget<Material>(find
                    .descendant(of: row, matching: find.byType(Material))
                    .first)
                .color,
            tint(const Color(0xFF2E7D32)));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
