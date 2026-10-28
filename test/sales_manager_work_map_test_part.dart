part of 'admin_production_map_test_screen_test.dart';

void _registerSalesManagerWorkMapTests() {
  testWidgets(
      'sales manager work map preserves edits and hides operational actions',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const id = 'zakaz-sales-test';
    await MobileApi.instance.adminSaveProductionMap(_productionOrderMap(
      id: id,
      orderNumber: 'SALES-1',
      title: 'Sales order',
      productCode: 'ITEM-SALES',
      product: 'Sales product',
      apparatusId: _print8Id,
    ));
    await MobileApi.instance
        .adminSaveProductionMapSequence(apparatus: _print8Id, orderIds: [id]);
    final catalog = await MobileApi.instance.adminApparatus(limit: 200);
    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.salesManager,
      displayName: 'Sales',
      legalName: 'Sales',
      ref: 'sales_manager_test',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'sales.access',
        'production.map.read',
        'production.order.create',
        'production.order.edit',
        'production.map.edit'
      ],
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
        queueSnapshotLoader: () async => snapshot,
        apparatusLoader: () async =>
            catalog.where((item) => item.id == _print8Id).toList(),
        liveEventsLoader: () => const Stream.empty(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Surish'), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);
    final row = find.byKey(const ValueKey('sequence-static-$_print8Id-$id'));
    expect(row, findsOneWidget);
    await tester.longPress(row);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_tree_outlined), findsWidgets);
    expect(find.text('Buyurtmani tahrirlash'), findsOneWidget);
    expect(find.byIcon(Icons.ac_unit_rounded), findsNothing);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
    expect(find.textContaining('muzlatish'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await TestModeController.instance.setEnabled(false);
  });
}
