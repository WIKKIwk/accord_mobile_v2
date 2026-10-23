part of 'admin_production_map_test_screen_test.dart';

void _registerStageFreezeScopeTests() {
  for (final paged in [false, true]) {
    testWidgets(
        'admin stage menus keep local holds separate from global actions paged=$paged',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      const orderId = 'zakaz-stage-freeze-menu';
      final saved = await MobileApi.instance.adminSaveProductionMap(
          _productionOrderMap(
              id: orderId,
              title: 'Scope',
              productCode: 'SCOPE',
              apparatusId: _godexId,
              product: 'Scope'));
      final apparatus = (await MobileApi.instance.adminApparatus(limit: 200))
          .where((item) => item.id == _godexId)
          .toList();
      final frozen = AdminStageOrderControl.fromJson({
        'order_id': orderId,
        'stage_node_id': 'apparatus',
        'state': 'frozen',
        'freeze_request': {'target_apparatus': _godexId},
      });
      tester.view.physicalSize = const Size(1800, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      for (final localFrozen in [false, true]) {
        final control = scanControl()
          ..['stage_control_state'] = localFrozen ? 'frozen' : '';
        if (localFrozen) {
          control['state'] = 'frozen';
          control['allowed_actions'] = [];
          (control['interaction'] as Map)['mode'] = 'frozen';
        }
        final snapshot = AdminApparatusQueueSnapshot(
            maps: [
              saved
            ],
            sequences: const {
              _godexId: [orderId]
            },
            visibleOrderIds: const {
              _godexId: [orderId]
            },
            queueStates: {
              _godexId: {orderId: localFrozen ? 'frozen' : 'pending'}
            },
            queueActionControls: {
              _godexId: {
                orderId: AdminApparatusQueueOrderActionControl.fromJson(control)
              }
            },
            queuePolicies: const {},
            orderControls: const {},
            stageFreezeSupported: true,
            stageOrderControls: localFrozen ? [frozen] : const [],
            revision: 1,
            epoch: 'stage-menu-$localFrozen');
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
            queueSnapshotLoader: () async => snapshot,
            orderPageLoader: paged
                ? (request) async => AdminProductionOrderPage(
                    version: 'stage-menu-$localFrozen-${request.view}',
                    total: 1,
                    offset: 0,
                    epoch: snapshot.epoch,
                    revision: 1,
                    orderIds: const [orderId],
                    snapshot: snapshot)
                : null,
          ),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ketma-ketlik'));
        await tester.pumpAndSettle();
        final row =
            find.byKey(const ValueKey('sequence-row-$_godexId-$orderId'));
        expect(row, findsOneWidget,
            reason: 'admin retains access to a frozen stage');
        await tester.longPress(row);
        await tester.pumpAndSettle();
        expect(
            find.text(localFrozen
                ? 'Shu bosqichni muzdan ochish'
                : 'Shu bosqichda muzlatish'),
            findsOneWidget);
        expect(find.text('Butun buyurtmani muzlatish'), findsNothing);
        expect(find.text('Mapni o‘zgartirish'), findsOneWidget);
        if (!localFrozen)
          expect(find.text('Butun buyurtmani o‘chirish'), findsOneWidget);
        Navigator.of(tester.element(find.text('Mapni o‘zgartirish'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buyurtmalar'));
        await tester.pumpAndSettle();
        await tester
            .longPress(find.byKey(const ValueKey('opened-order-$orderId')));
        await tester.pumpAndSettle();
        expect(find.text('Butun buyurtmani muzlatish'), findsOneWidget,
            reason: 'a local hold must not be presented as a global hold');
        expect(find.text('Shu bosqichni muzdan ochish'), findsNothing);
        Navigator.of(tester.element(find.text('Butun buyurtmani muzlatish')))
            .pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
