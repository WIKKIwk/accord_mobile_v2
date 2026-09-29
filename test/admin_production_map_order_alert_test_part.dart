part of 'admin_production_map_test_screen_test.dart';

void _registerOrderAlertTests() {
  testWidgets('order alerts remain visible when missing resources block start',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const orderId = 'zakaz-alert-blocked';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Bosmachi',
      legalName: '',
      ref: 'alert-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [_print7Id],
    );
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: orderId,
      title: 'Alert order',
      productCode: 'ALERT',
      apparatusId: _print7Id,
      product: 'Alert product',
    ));
    await MobileApi.instance.adminSaveProductionMapSequence(
      apparatus: _print7Id,
      orderIds: const [orderId],
    );
    setMobileApiTestModeQueueActionControlFixture(
      apparatus: _print7Id,
      orderId: orderId,
      control: const AdminApparatusQueueOrderActionControl(
        state: 'pending',
        allowedActions: {},
        hasOnlyKnownActions: true,
        interaction: AdminQueueWorkerInteraction(
          mode: AdminQueueInteractionMode.freshStartBlocked,
          startMaterialsMode: AdminQueueStartMaterialsMode.scanRequired,
          materialScanRequired: true,
          assignedMaterialsDisplayOnly: true,
          materialIntakeAllowed: false,
          previousWipMode: AdminQueuePreviousWipMode.notRequired,
          qolipMode: AdminQueueQolipMode.scanRequired,
          blockingReasonCode: 'raw_material_assignment_required',
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
      home: const AdminProductionMapOrdersScreen(
        readOnly: true,
        workerMode: true,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 ta rangli bosma aparat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('material-alert:$orderId:$_print7Id')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('qolip-alert:$orderId:$_print7Id')),
        findsOneWidget);
    expect(find.text('Boshlash'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
