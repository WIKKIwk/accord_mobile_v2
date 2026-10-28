part of 'admin_production_map_test_screen_test.dart';

void _registerStageParticipantsTests() {
  for (final tab in ['Ketma-ketlik', 'Buyurtmalar']) {
    testWidgets('admin stage participants long press in $tab', (tester) async {
      await TestModeController.instance.setEnabled(true);
      AdminSequenceApparatusStore.instance.clearCache();
      addTearDown(AdminSequenceApparatusStore.instance.clearCache);
      const orderId = 'zakaz-stage-people';
      await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        orderNumber: '0042',
        title: 'Participant order',
        productCode: 'PEOPLE',
        product: 'People product',
        apparatusId: _print8Id,
      ));
      await MobileApi.instance.adminSaveProductionMapSequence(
          apparatus: _print8Id, orderIds: const [orderId]);
      final catalog = (await MobileApi.instance.adminApparatus(limit: 200))
          .where((apparatus) => apparatus.id == _print8Id)
          .toList();
      await AdminSequenceApparatusStore.instance.saveApparatus(catalog.single);
      final snapshot =
          await MobileApi.instance.adminProductionMapQueueSnapshot();
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
          apparatusLoader: () async => catalog,
          queueSnapshotLoader: () async => snapshot,
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey(tab == 'Buyurtmalar'
          ? 'opened-order-$orderId'
          : 'sequence-row-$_print8Id-$orderId'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final mapToggle = find.text('Mahsulot ishlab chiqarish xaritasi');
      await tester.ensureVisible(mapToggle);
      await tester.tap(mapToggle);
      await tester.pumpAndSettle();
      final machine =
          find.byKey(const ValueKey('production-map-apparatus-$_print8Id'));
      await tester.ensureVisible(machine);
      await TestModeController.instance.setEnabled(false);

      var attempts = 0;
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await tester.longPress(machine);
        await tester.pumpAndSettle();
        expect(find.text('Ishtirokchilarni yuklab bo‘lmadi'), findsOneWidget);
        await tester.tap(find.text('Qayta urinish').last);
        await tester.pumpAndSettle();
        expect(find.text('Ishtirokchilar'), findsOneWidget);
        expect(find.text('Ali'), findsOneWidget);
        expect(find.text('Boshlagan · Qatnashgan'), findsOneWidget);
        expect(find.text('Vali'), findsOneWidget);
        expect(find.text('Ishlayapti'), findsWidgets);
        expect(requests, hasLength(2));
        expect(requests.last.url.queryParameters, {
          'order_id': orderId,
          'stage_node_id': 'apparatus',
          'apparatus': _print8Id,
        });
        expect(requests.last.headers['Authorization'], 'Bearer token');

        Navigator.of(tester.element(find.text('Ishtirokchilar'))).pop();
        await tester.pumpAndSettle();
        await tester.longPress(machine);
        await tester.pumpAndSettle();
        expect(find.text('Bu bosqichda hali ishtirokchilar qayd etilmagan'),
            findsOneWidget);
        Navigator.of(tester.element(find.text('Ishtirokchilar'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(machine);
        await tester.pumpAndSettle();
        expect(
            find.text(AppLocalizations(const Locale('uz'))
                .productionText('worker.wip.history.title')),
            findsOneWidget);
        Navigator.of(tester.element(find.text(
                AppLocalizations(const Locale('uz'))
                    .productionText('worker.wip.history.title'))))
            .pop();
        await tester.pumpAndSettle();
        await tester.longPress(machine);
        await tester.pumpAndSettle();
        expect(find.text('Ali'), findsOneWidget);
        AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Worker',
          legalName: '',
          ref: 'worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read'],
        );
        AppSession.instance.revision.value++;
        await tester.pump();
        expect(find.text('Hisob yoki ruxsatlar o‘zgardi. Oynani qayta oching'),
            findsOneWidget);
        expect(find.text('Ali'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/stage-participants')) {
                  requests.add(request);
                  attempts++;
                  if (attempts == 1) return http.Response('{}', 503);
                  return http.Response(
                      jsonEncode({
                        'participants': attempts == 2 || attempts >= 4
                            ? [
                                {
                                  'display_name': 'Vali',
                                  'started': false,
                                  'state': 'working'
                                },
                                {
                                  'display_name': 'Ali',
                                  'started': true,
                                  'state': 'participated'
                                },
                              ]
                            : [],
                      }),
                      200);
                }
                if (request.url.path.endsWith('/wip-batches')) {
                  return http.Response('{"batches":[]}', 200);
                }
                if (request.url.path.endsWith('/opening-wip')) {
                  return http.Response('{"records":[]}', 200);
                }
                return http.Response('{}', 200);
              }));
    });
  }
}
