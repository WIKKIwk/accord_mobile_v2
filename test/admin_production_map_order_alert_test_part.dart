part of 'admin_production_map_test_screen_test.dart';

void _registerOrderAlertTests() {
  const orderId = 'zakaz-alert-blocked';

  Future<void> open(
    WidgetTester tester, {
    String apparatus = _print7Id,
    bool materialAssigned = false,
    int qolipCount = 0,
    bool blocked = false,
  }) async {
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Bosmachi',
      legalName: '',
      ref: 'alert-worker',
      phone: '',
      avatarUrl: '',
      capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [apparatus],
    );
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: orderId,
      title: 'Alert order',
      productCode: 'ALERT',
      apparatusId: apparatus,
      product: 'Alert product',
    ));
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: apparatus,
      orderIds: const [orderId],
    );
    if (materialAssigned) {
      await MobileApi.instance.adminAssignRawMaterialToOrder(
        orderId: orderId,
        apparatus: apparatus,
        barcode: 'ALERT-RAW-MATERIAL',
      );
    }
    for (var index = 0; index < qolipCount; index++) {
      await MobileApi.instance.qolipSaveProductSpec(
        product: const QolipProduct(
          code: 'ALERT',
          name: 'Alert product',
          itemGroup: 'Tayyor mahsulotlar',
        ),
        qolipCode: 'ALERT-QOLIP-$index',
        size: 40,
      );
    }
    setMobileApiTestModeQueueActionControlFixture(
      apparatus: apparatus,
      orderId: orderId,
      control: AdminApparatusQueueOrderActionControl(
        state: 'pending',
        allowedActions: blocked ? const {} : const {'start'},
        hasOnlyKnownActions: true,
        interaction: AdminQueueWorkerInteraction(
          mode: blocked
              ? AdminQueueInteractionMode.freshStartBlocked
              : AdminQueueInteractionMode.freshStart,
          startMaterialsMode: AdminQueueStartMaterialsMode.scanRequired,
          materialScanRequired: true,
          assignedMaterialsDisplayOnly: true,
          materialIntakeAllowed: false,
          previousWipMode: AdminQueuePreviousWipMode.notRequired,
          qolipMode: AdminQueueQolipMode.scanRequired,
          blockingReasonCode: blocked ? 'raw_material_assignment_required' : '',
        ),
      ),
    );
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
        readOnly: true,
        workerMode: true,
        liveEventsLoader: () => const Stream.empty(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_fixtureApparatusName(apparatus)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
    await tester.pumpAndSettle();
  }

  testWidgets('order alerts remain visible when missing resources block start',
      (tester) async {
    await open(tester, blocked: true);
    expect(find.byKey(const ValueKey('material-alert:$orderId:$_print7Id')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('qolip-alert:$orderId:$_print7Id')),
        findsOneWidget);
    expect(find.text('Boshlash'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final scenario in [
    (apparatus: _print7Id, materialAssigned: true, qolipCount: 6),
    (apparatus: _print7Id, materialAssigned: true, qolipCount: 0),
    (apparatus: _print7Id, materialAssigned: false, qolipCount: 6),
    (apparatus: _print8Id, materialAssigned: false, qolipCount: 0),
    (apparatus: _print9Id, materialAssigned: false, qolipCount: 0),
    (apparatus: _lamination1Id, materialAssigned: false, qolipCount: 0),
    (apparatus: _rezkaId, materialAssigned: false, qolipCount: 0),
  ]) {
    testWidgets(
        'order alerts require print apparatus and empty assignments: '
        '${scenario.apparatus}, material=${scenario.materialAssigned}, '
        'qolips=${scenario.qolipCount}', (tester) async {
      await open(
        tester,
        apparatus: scenario.apparatus,
        materialAssigned: scenario.materialAssigned,
        qolipCount: scenario.qolipCount,
      );
      final isPrint =
          const [_print7Id, _print8Id, _print9Id].contains(scenario.apparatus);
      expect(
        find.byKey(ValueKey('material-alert:$orderId:${scenario.apparatus}')),
        isPrint && !scenario.materialAssigned ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(ValueKey('qolip-alert:$orderId:${scenario.apparatus}')),
        isPrint && scenario.qolipCount == 0 ? findsOneWidget : findsNothing,
      );
      if (scenario.qolipCount > 0) {
        expect(find.text('0/${scenario.qolipCount}'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
