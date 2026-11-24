part of 'admin_production_map_test_screen_test.dart';

void _registerAdminMapWipFactsTests() {
  for (final scenario in [
    'pending',
    'missing',
    'completed',
    'retry',
    'refresh',
    'empty',
    'active_alternative',
    'active_alternative_pending_stage'
  ]) {
    testWidgets('admin order bottom sheet map uses WIP facts: $scenario',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AdminSequenceApparatusStore.instance.clearCache();
      addTearDown(AdminSequenceApparatusStore.instance.clearCache);
      const orderId = 'zakaz-map-wip-facts';
      const cut5 = 'apparatus:default:asset-014';
      final alternative = scenario.startsWith('active_alternative');
      final missingState = scenario == 'missing' || scenario == 'empty';
      final outputConsumer = alternative ? cut5 : _rezkaId;
      final saved = await MobileApi.instance.adminSaveProductionMap(
        ProductionMapDefinition(
          id: orderId,
          orderNumber: '0063',
          title: 'Kreko kuritsa 50 gr',
          productCode: 'KREKO',
          baseLength: 1000,
          nodes: [
            ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
            ProductionMapNode(
                id: 'product', kind: 'task', title: 'Kreko kuritsa 50 gr'),
            ProductionMapNode(
                id: 'print',
                kind: 'apparatus',
                title: 'Bosma',
                apparatusId: _print9Id),
            ProductionMapNode(
                id: 'lam',
                kind: 'apparatus',
                title: 'Laminatsiya 1',
                apparatusId: _lamination1Id),
            ProductionMapNode(
                id: 'cut',
                kind: 'apparatus',
                title: 'Rezka',
                apparatusId: _rezkaId,
                alternativeGroupId: alternative ? 'cut-group' : ''),
            if (alternative)
              const ProductionMapNode(
                  id: 'cut5',
                  kind: 'apparatus',
                  title: 'Rezka 5',
                  apparatusId: cut5,
                  alternativeGroupId: 'cut-group'),
            ProductionMapNode(id: 'end', kind: 'end', title: 'Yakun'),
          ],
          edges: [
            ProductionMapEdge(from: 'start', to: 'product'),
            ProductionMapEdge(from: 'product', to: 'print'),
            ProductionMapEdge(from: 'print', to: 'lam'),
            ProductionMapEdge(from: 'lam', to: 'cut'),
            ProductionMapEdge(from: 'cut', to: 'end'),
            if (alternative) const ProductionMapEdge(from: 'lam', to: 'cut5'),
            if (alternative) const ProductionMapEdge(from: 'cut5', to: 'end'),
          ],
        ),
      );
      final apparatus = await MobileApi.instance.adminApparatus(limit: 200);
      final initial = AdminProductionMapLiveSnapshot(
        maps: [saved],
        sequences: const {},
        visibleOrderIds: const {},
        queueStates: {
          _print9Id: {orderId: 'completed'},
          if (!missingState)
            _lamination1Id: {
              orderId: scenario == 'completed' ? 'completed' : 'pending',
            },
          _rezkaId: {orderId: 'pending'},
          if (alternative) cut5: {orderId: 'in_progress'},
        },
        stageStates: {
          orderId: {
            'print': 'completed',
            if (!missingState)
              'lam': scenario == 'completed' ? 'completed' : 'pending',
            'cut': 'pending',
            if (scenario == 'active_alternative') 'cut5': 'in_progress',
          },
        },
        queuePolicies: const {},
        orderControls: const {},
        orderStatuses: const {},
        completedOrders: const [],
        completionRequests: const [],
        completionRequestDecisions: const [],
        epoch: 'map-facts',
        revision: 1,
      );
      await _usePhoneViewport(tester);
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
          apparatusLoader: () async => apparatus,
          queueSnapshotLoader: () async => initial,
          liveEventsLoader: _idleProductionLiveLoader(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('opened-order-$orderId')));
      await tester.pumpAndSettle();
      await TestModeController.instance.setEnabled(false);
      var wipLoads = 0;
      var rollCount = scenario == 'empty' ? 0 : 8;
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        final mapToggle = find.text('Mahsulot ishlab chiqarish xaritasi');
        await tester.ensureVisible(mapToggle);
        await tester.tap(mapToggle);
        await tester.pumpAndSettle();
        if (scenario == 'retry') {
          expect(find.text('Xarita holati va WIP ma’lumotlari yuklanmadi'),
              findsOneWidget);
          expect(find.text('Navbat kutmoqda'), findsNothing);
          await tester.tap(find.text('Qayta urinish').last);
          await tester.pumpAndSettle();
        }
        final lam = find
            .byKey(const ValueKey('production-map-apparatus-$_lamination1Id'));
        final cut = find.byKey(ValueKey(
            'production-map-apparatus-${alternative ? cut5 : _rezkaId}'));
        if (scenario == 'empty') {
          expect(
              find.descendant(
                  of: lam, matching: find.text('Holat tasdiqlanmagan')),
              findsOneWidget);
          expect(find.descendant(of: lam, matching: find.text('Navbat kutmoqda')),
              findsNothing);
        } else {
          expect(
              find.descendant(
                  of: lam, matching: find.text('Chiqarilgan WIP: 8 ta')),
              findsOneWidget);
          expect(
              find.descendant(
                  of: lam,
                  matching: find.text(
                      scenario == 'completed' ? 'Tugagan' : 'WIP chiqarilgan')),
              findsOneWidget);
          expect(find.descendant(of: lam, matching: find.text('Ishlayapti')),
              findsNothing);
          expect(
              find.descendant(
                  of: cut,
                  matching: find.text(
                      'Kirish WIP: 6 kutmoqda · 1 ishlatilmoqda · 1 ishlatilgan')),
              findsOneWidget);
          expect(find.text('Navbat kutmoqda'), findsNothing);
          if (alternative) {
            expect(find.descendant(of: cut, matching: find.text('Ishlayapti')),
                findsOneWidget);
            expect(find.descendant(of: cut, matching: find.text('Rezka 5')),
                findsOneWidget);
            expect(
                find.byKey(
                    const ValueKey('production-map-apparatus-$_rezkaId')),
                findsNothing);
          }
          if (scenario == 'refresh') {
            rollCount = 9;
            await tester.pump(const Duration(seconds: 15));
            await tester.pumpAndSettle();
            expect(wipLoads, 1, reason: 'the open detail waits for live revisions');
            ProductionDataRevision.notify(epoch: 'map-facts', revision: 2);
            await tester.pumpAndSettle();
            expect(find.text('Chiqarilgan WIP: 9 ta'), findsOneWidget);
            expect(wipLoads, 2);
          }
        }
        for (final request
            in requests.where((r) => r.url.path.endsWith('/wip-batches'))) {
          expect(request.url.queryParameters['order_id'], orderId);
          expect(request.url.queryParameters['status'], 'all');
          expect(request.url.queryParameters.containsKey('apparatus'), isFalse);
        }
        expect(requests.where((r) => r.url.path.endsWith('/sequence')), isEmpty,
            reason: 'the detail already carries the stage states');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
          () => MockClient((request) async {
                requests.add(request);
                if (request.url.path.endsWith('/wip-batches')) {
                  if (++wipLoads == 1 && scenario == 'retry')
                    return http.Response('{}', 503);
                  return http.Response(
                      jsonEncode({
                        'batches': [
                          for (var i = 0; i < rollCount; i++)
                            {
                              'batch_id': 'roll-$i',
                              'order_id': orderId,
                              'apparatus': _lamination1Id,
                              'next_apparatus': outputConsumer,
                              'current_apparatus':
                                  i < 6 ? _lamination1Id : outputConsumer,
                              'action': i == 0 ? 'complete' : 'detach_roll',
                              'status': 'roll_detached',
                              'wip_status': i == 6
                                  ? 'in_use'
                                  : i == 7
                                      ? 'processed'
                                      : 'waiting',
                              'produced_qty': 9000,
                              'uom': 'm',
                              'qr_payload': 'QR-$i',
                              'payload_json': {
                                'stage_node_id': 'lam',
                                'next_stage_node_id': alternative ? 'cut5' : 'cut'
                              },
                            },
                        ]
                      }),
                      200);
                }
                if (request.url.path.endsWith('/opening-wip'))
                  return http.Response('{"records":[]}', 200);
                return http.Response('{}', 404);
              }));
    });
  }
}
