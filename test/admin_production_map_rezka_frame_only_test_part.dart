part of 'admin_production_map_test_screen_test.dart';

void _registerRezkaFrameOnlyTests() {
  for (final scenario in [
    'single',
    'skip',
    'skip-cancel',
    'missing',
    'fractional',
    'legacy-zero',
    'template-linked',
    'unlinked',
    'existing-groups',
    'invalid-groups',
    'save-guard',
  ]) {
    testWidgets('Rezka frame-only setup: $scenario', (tester) async {
      await TestModeController.instance.setEnabled(true);
      await _usePhoneViewport(tester);
      const mapId = 'zakaz-rezka-frame-only';
      final existing = {
        'legacy-zero',
        'template-linked',
        'unlinked',
        'existing-groups',
        'invalid-groups',
        'save-guard'
      }.contains(scenario);
      final groups = scenario == 'existing-groups'
          ? [1, 2]
          : scenario == 'invalid-groups'
              ? [4]
              : <int>[];
      final nodes = [
        const ProductionMapNode(
            id: 'start', kind: 'start', title: 'Start', x: 420, y: 32),
        if (existing)
          ProductionMapNode(
              id: 'rezka',
              kind: 'apparatus',
              title: 'Rezka',
              apparatusId: _rezkaId,
              rezkaKadrCount: groups.isEmpty ? 0 : 3,
              rezkaFrameGroups: groups,
              rezkaLabelLength: 120,
              x: 420,
              y: 164),
        const ProductionMapNode(
            id: 'end', kind: 'end', title: 'End', x: 420, y: 296),
      ];
      final map = ProductionMapDefinition(
          id: mapId,
          title: 'Frame-only order',
          productCode: 'FRAME-ONLY',
          code: '0004',
          orderNumber: '0004',
          widthMm: 765,
          nodes: nodes,
          edges: existing
              ? const [
                  ProductionMapEdge(from: 'start', to: 'rezka'),
                  ProductionMapEdge(from: 'rezka', to: 'end')
                ]
              : const [ProductionMapEdge(from: 'start', to: 'end')]);
      await MobileApi.instance.adminSaveProductionMap(map);
      await MobileApi.instance
          .upsertCalculateOrderTemplate(CalculateOrderTemplate.fromJson({
        'id': 'template-frame-only',
        'code': '0004',
        'order_number': '0004',
        'name': 'Frame-only order',
        'item_code': 'FRAME-ONLY',
        'product': 'Frame-only order',
        'source_map_id': scenario == 'unlinked'
            ? 'different-order'
            : scenario == 'template-linked'
                ? 'template-$mapId'
                : mapId,
        'frame_count': scenario == 'missing'
            ? 0
            : scenario == 'fractional'
                ? 2.5
                : scenario == 'existing-groups'
                    ? 4
                    : 3,
        'width_mm': 765,
      }));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminProductionMapTestScreen(savedMap: map),
      ));
      await tester.pumpAndSettle();
      if (scenario == 'save-guard') {
        await tester.tap(find.byKey(const ValueKey('production-map-save')));
        await tester.pumpAndSettle();
        expect(
            find.textContaining('kadr sozlamasi to‘liq emas'), findsOneWidget);
        expect(
            (await MobileApi.instance.adminProductionMap(mapId))
                .map
                .nodes
                .firstWhere((node) => node.id == 'rezka')
                .rezkaKadrCount,
            0);
      } else {
        if (existing) {
          await tester.tap(find.text('Rezka'));
        } else {
          await _tapMapTool(tester, 'Rezka');
          await tester.pumpAndSettle();
          await tester.tap(
              find.text(scenario.startsWith('skip') ? 'Skip' : 'Rezka').last);
        }
        await tester.pumpAndSettle();
        expect(find.text('Rezka sozlash'), findsOneWidget);
        for (final label in [
          'Buyurtma bo‘yicha',
          'Kadr bo‘yicha',
          'Kadr soni',
          'Etiketka uzunligi'
        ]) {
          expect(find.text(label), findsNothing);
        }
        final blocked = {'missing', 'fractional', 'unlinked', 'invalid-groups'}
            .contains(scenario);
        if (blocked) {
          expect(
              find.textContaining(scenario == 'invalid-groups'
                  ? 'guruhlari kadr soniga mos emas'
                  : 'Buyurtmada kadr soni topilmadi'),
              findsOneWidget);
          final save = find
              .ancestor(
                  of: find.text('Saqlash'), matching: find.byType(InkWell))
              .first;
          expect(tester.widget<InkWell>(save).onTap, isNull);
          Navigator.of(tester.element(find.text('Rezka sozlash'))).pop();
        } else if (scenario == 'skip-cancel') {
          Navigator.of(tester.element(find.text('Rezka sozlash'))).pop();
        } else {
          expect(find.text('Kadr 1'), findsOneWidget);
          expect(
              find.text(scenario == 'existing-groups' ? 'Kadr 2-3' : 'Kadr 3'),
              findsOneWidget);
          if (scenario == 'skip') {
            await tester.tap(find.byKey(const ValueKey('rezka-frame-join-0')));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Saqlash'));
        }
        await tester.pumpAndSettle();
        if (!blocked) {
          await tester.tap(find.byKey(const ValueKey('production-map-save')));
          await tester.pumpAndSettle();
          var saved = (await MobileApi.instance.adminProductionMap(mapId)).map;
          final rezka =
              saved.nodes.where((node) => node.kind == 'apparatus').toList();
          expect(
              rezka,
              hasLength(scenario == 'skip'
                  ? 5
                  : scenario == 'skip-cancel'
                      ? 0
                      : 1));
          for (final node in rezka) {
            expect(node.rezkaKadrCount, 3);
            expect(
                node.rezkaFrameGroups,
                scenario == 'skip'
                    ? [2, 1]
                    : scenario == 'existing-groups'
                        ? [1, 2]
                        : [1, 1, 1]);
            expect(node.rezkaLabelLength, isNull);
          }
          if (scenario == 'skip') {
            // One shared Rezka operation: edits keep all candidates identical.
            await tester.tap(find.text('Rezka 3').hitTestable());
            await tester.pumpAndSettle();
            await tester.tap(find.text('Kadr 1-2'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Saqlash'));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('production-map-save')));
            await tester.pumpAndSettle();
            saved = (await MobileApi.instance.adminProductionMap(mapId)).map;
            for (final node
                in saved.nodes.where((node) => node.kind == 'apparatus')) {
              expect(node.rezkaFrameGroups, [1, 1, 1]);
              expect(node.alternativeGroupId, rezka.first.alternativeGroupId);
            }
          }
        }
      }
      dismissAdminTopNotice();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
