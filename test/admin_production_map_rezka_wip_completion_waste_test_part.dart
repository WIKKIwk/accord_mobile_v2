part of 'admin_production_map_test_screen_test.dart';

void _registerRezkaWipCompletionWasteTests() {
  for (final scenario in [
    (name: 'waiting WIP', totalWasteOnly: false, fullReport: false),
    (name: 'last intermediate WIP', totalWasteOnly: true, fullReport: false),
    (name: 'last final WIP', totalWasteOnly: false, fullReport: true),
  ]) {
    testWidgets('Rezka WIP completion waste: ${scenario.name}', (tester) async {
      const orderId = 'zakaz-rezka-wip-waste-dialog';
      await TestModeController.instance.setEnabled(true);
      await AppSession.instance.setSession(
        token: 'worker-rezka-wip-waste-token',
        profile: const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Rezka operatori',
          legalName: '',
          ref: 'worker-rezka-wip-waste',
          phone: '',
          avatarUrl: '',
          capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
          assignedApparatus: [_rezkaId],
        ),
      );
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: orderId,
          title: 'Rezka WIP waste dialog',
          productCode: 'RZW',
          orderNumber: '0062',
          apparatusId: _rezkaId,
          product: 'Rezka mahsulot',
        ),
      );
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: _rezkaId,
        orderIds: const [orderId],
      );
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: _rezkaId,
        orderId: orderId,
        action: 'start',
      );
      setMobileApiTestModeQueueActionControlFixture(
        apparatus: _rezkaId,
        orderId: orderId,
        control: _inProgressQueueControl(
          completeRequiresFullReport: scenario.fullReport,
          completeRequiresRezkaTotalWasteOnly: scenario.totalWasteOnly,
          stageNodeId: 'rezka-stage',
          rezkaOutputKadrCounts: const [3],
          rezkaInputLineage: const [
            AdminRezkaInputLink(
              inputBatchId: 'rezka-wip-a',
              sequenceNo: 1,
              status: 'in_use',
            ),
          ],
        ),
      );
      await _usePhoneViewport(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
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
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('worker-order-$orderId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tugatish'));
      await tester.pumpAndSettle();

      expect(find.text('Chiqish rulonlari (1 ta)'), findsOneWidget);
      expect(find.text('1-rulon — 3 kadrli'), findsOneWidget);
      final totalWasteFieldCount = find
              .widgetWithText(TextFormField, 'Chiqindi')
              .evaluate()
              .length +
          find.widgetWithText(TextFormField, 'Jami chiqindi').evaluate().length;
      expect(
        totalWasteFieldCount,
        scenario.totalWasteOnly || scenario.fullReport ? 1 : 0,
      );
      for (final label in [
        'Bosma chiqindisi',
        'Laminatsiya chiqindisi',
        'Chet chiqindisi',
      ]) {
        expect(
          find.widgetWithText(TextFormField, label),
          scenario.fullReport ? findsOneWidget : findsNothing,
        );
      }
    });
  }
}
