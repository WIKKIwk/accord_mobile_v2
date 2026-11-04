part of 'admin_production_map_test_screen_test.dart';

void _registerWorkerOutputProgressTests() {
  for (final (station, label) in [
    (_print7Id, 'Bosma progressi'),
    (_lamination1Id, 'Laminatsiya progressi'),
  ]) {
    testWidgets('worker output progress in the open sheet: $label',
        (tester) async {
      const orderId = 'zakaz-output-progress';
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Apparatchi',
        legalName: '',
        ref: 'worker-output-progress',
        phone: '',
        avatarUrl: '',
        capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [station],
      );
      final api = MobileApi.instance;
      await api.adminSaveProductionMap(_productionOrderMap(
        id: orderId,
        title: 'Output progress order',
        productCode: 'OUTPUT',
        product: 'Output product',
        apparatusId: station,
        baseLength: 950,
      ));
      await api.adminSaveProductionMapSequence(
          apparatus: station, orderIds: const [orderId]);
      await api.adminApparatusQueueActionResult(
          apparatus: station, orderId: orderId, action: 'start');

      Future<void> recordOutput(double meters) async {
        await api.adminApparatusQueueActionResult(
          apparatus: station,
          orderId: orderId,
          action: 'detach_roll',
          producedQty: meters,
          grossQty: 20,
          uom: 'm',
        );
        await api.adminApparatusQueueActionResult(
            apparatus: station, orderId: orderId, action: 'resume');
      }

      await recordOutput(200);
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: station,
        orderId: orderId,
        control: _inProgressQueueControl(stageNodeId: 'apparatus'),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
          liveEventsLoader: () => const Stream.empty(),
        ),
      ));
      await tester.pumpAndSettle();
      final progress =
          find.byKey(const ValueKey('worker-order-output-progress'));
      expect(progress, findsNothing);
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      await _pumpCompletedWorkFrames(tester);

      final actions =
          find.byKey(const ValueKey('production-order-pause-complete-visible'));
      final detach =
          find.descendant(of: actions, matching: find.byType(OutlinedButton));
      final bar = find.descendant(
          of: progress, matching: find.byType(LinearProgressIndicator));
      expect(find.text(label), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
      final measured = find.textContaining('200 / ');
      final remaining = find.text('800 m qoldi');
      expect(tester.getTopLeft(remaining).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(measured).dy));
      expect(tester.getTopLeft(remaining).dx, tester.getTopLeft(measured).dx);
      expect(tester.widget<LinearProgressIndicator>(bar).value, 0.2);
      expect(tester.getBottomLeft(progress).dy,
          lessThan(tester.getTopLeft(detach).dy));

      await recordOutput(100);
      await tester.pump(const Duration(seconds: 30));
      await _pumpCompletedWorkFrames(tester);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('700 m qoldi'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
