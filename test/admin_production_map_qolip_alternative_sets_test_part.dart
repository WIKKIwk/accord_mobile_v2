part of 'admin_production_map_test_screen_test.dart';

void _registerQolipAlternativeSetTests() {
  testWidgets(
      'worker alternative molds reject mixed scans and reset the chosen set',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const orderId = 'zakaz-alternative-worker-scan';
    const product = QolipProduct(
        code: 'DEMO-HOTLUNCH',
        name: 'Hotlunch',
        itemGroup: 'Demo tayyor mahsulotlar');
    const machine = AdminApparatus(
        id: _godexId, name: 'Godex aparat - DEMO', sourceRevision: 1);
    for (final codes in [
      ['ALT-A1', 'ALT-A2'],
      ['ALT-B1', 'ALT-B2']
    ]) {
      await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: 'Qolip ombori',
        specs: [
          for (final code in codes)
            QolipProductSpecBatchItem(qolipCode: code, size: 42)
        ],
      );
    }
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: orderId,
      title: 'Muqobil order',
      productCode: product.code,
      apparatusId: _godexId,
      product: product.name,
      orderNumber: '0781',
    ));
    await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _godexId, orderIds: [orderId]);
    await MobileApi.instance.adminSaveRawMaterialRule(
      apparatus: machine,
      currentRule: _testRawMaterialRule(machine),
      requiresMaterial: false,
      startPolicy: AdminRawMaterialStartPolicy.stateAll,
      itemGroups: const [],
    );
    setMobileApiTestModeQueueActionControlFixture(
      apparatus: _godexId,
      orderId: orderId,
      control: _freshStartQueueControl(
          materialScanRequired: false,
          qolipMode: AdminQueueQolipMode.scanRequired),
    );
    final stored = await MobileApi.instance
        .qolipProducts(query: product.code, withQolipOnly: true);
    expect(stored.map((mold) => mold.setId).toSet().length, 2,
        reason: stored
            .map((mold) => '${mold.qolipCode}: ${mold.setId}')
            .join(' | '));
    final requirements = await MobileApi.instance
        .adminProductionMapQolipRequirements(
            apparatus: _godexId, orderId: orderId);
    expect(requirements.requiredQolips.map((mold) => mold.setId).toSet().length,
        2);
    await AppSession.instance.setSession(
        token: 'alternative-worker',
        profile: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Worker',
          legalName: '',
          ref: 'alternative-worker',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_godexId],
        ));
    await _usePhoneViewport(tester);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: const AdminProductionMapOrdersScreen(
          readOnly: true, workerMode: true),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(machine.name));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
    await tester.pumpAndSettle();
    expect(find.text('Muqobil qoliplar'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '));
    await tester.tap(
        find.byKey(const ValueKey('production-quick-scanner-manual-toggle')));
    await tester.pumpAndSettle();
    Future<void> scan(String code) async {
      await tester.enterText(
          find.byKey(const ValueKey('production-quick-scanner-manual')), code);
      await tester.tap(find.byTooltip('Qabul qilish'));
      await tester.pumpAndSettle();
    }

    Finder progress(String value) => find.descendant(
          of: find.byKey(const ValueKey('production-qolips-expansion')),
          matching: find.text(value),
        );
    await scan('ALT-A1');
    expect(progress('1/2'), findsOneWidget);
    await scan('ALT-B1');
    expect(progress('1/2'), findsOneWidget);
    expect(find.byType(ProductionQuickScannerPanel), findsOneWidget);
    await tester.ensureVisible(find.text('Komplektni almashtirish'));
    await tester.tap(find.text('Komplektni almashtirish'));
    await tester.pumpAndSettle();
    expect(find.text('Muqobil qoliplar'), findsOneWidget);
    await scan('ALT-B1');
    expect(progress('1/2'), findsOneWidget);
    await scan('ALT-B2');
    expect(progress('2/2'), findsOneWidget);
    expect(find.byType(ProductionQuickScannerPanel), findsNothing);
  });
}
