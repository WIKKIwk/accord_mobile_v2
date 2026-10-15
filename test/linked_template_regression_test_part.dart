part of 'admin_calculate_screen_test.dart';

void _registerLinkedTemplateRegressionTests() {
  test('linked template: variant metadata follows quick identity', () {
    final a = _template(itemCode: 'SKU-A').copyWith(variantId: 'template-1');
    expect(a.copyWith(name: 'New display name').variantId, a.variantId);
    expect(a.copyWith(id: '', code: '').variantId, isEmpty);
    expect(a.copyWith(id: 'B', variantId: 'B').variantId, 'B');
  });
  for (final choice in ['no', 'yes', 'use_template']) {
    testWidgets(
        'linked template: existing SKU choice $choice preserves original identities',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      resetMobileApiTestModeData();
      for (final id in ['template-choice-a', 'template-choice-b']) {
        await MobileApi.instance
            .adminSaveProductionMap(_map(id: id, code: '', orderNumber: ''));
      }
      final a = await MobileApi.instance.upsertCalculateOrderTemplate(_template(
          itemCode: 'SKU-A',
          product: 'Product A',
          sourceMapId: 'template-choice-a',
          customerRef: ''));
      final b = await MobileApi.instance.upsertCalculateOrderTemplate(_template(
              itemCode: 'DEMO-HOTLUNCH',
              product: 'Hotlunch',
              sourceMapId: 'template-choice-b',
              customerRef: '')
          .copyWith(id: 'existing-b', code: 'Q-B'));
      await CalculateOrderTemplateStore.instance.load(force: true);
      ProductionMapTestArgs? args;
      await _pumpCalculateScreen(tester,
          template: a,
          onProductionMapArguments: (value) =>
              args = value as ProductionMapTestArgs);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product A').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hotlunch').last);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations(const Locale('uz'));
      expect(find.text(l10n.adminText('calculate.quick_order_exists')),
          findsOneWidget);
      await tester.tap(find.text(l10n.adminText('calculate.$choice')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'KG'), '120');
      await tester.tap(find.text('Hisoblash'));
      await tester.pumpAndSettle();
      final attach = l10n.adminText('calculate.map_attach');
      await tester.scrollUntilVisible(find.text(attach), 240,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(attach));
      await tester.pumpAndSettle();
      final draft = args!.orderContext!.templateDraft!;
      if (choice == 'yes') {
        expect(draft.itemCode, b.itemCode);
        expect(draft.id, isNot(a.id));
        expect(draft.id, isNot(b.id));
        expect(draft.code, isNot(a.code));
        expect(draft.code, isNot(b.code));
        expect(args!.orderContext!.templateAction, 'fork');
        expect(args!.savedMap!.id, isNot(a.sourceMapId));
      } else {
        final expected = choice == 'no' ? a : b;
        expect(draft.id, expected.id);
        expect(draft.code, expected.code);
        expect(draft.itemCode, expected.itemCode);
        expect(args!.savedMap!.id, expected.sourceMapId);
      }
      expect(
          (await MobileApi.instance.calculateOrderTemplates()).map((t) => t.id),
          containsAll([a.id, b.id]));
    });
  }
  test(
      'linked template: TestMode fork validation, source independence and retry agree',
      () async {
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    final source = _map(id: 'template-plan-a', code: '', orderNumber: '')
        .copyWith(productCode: 'SKU-A', nodes: [
      const ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      const ProductionMapNode(
          id: 'cut',
          kind: 'apparatus',
          title: 'Rezka',
          apparatusId: 'apparatus:default:asset-010',
          rezkaKadrCount: 4,
          rezkaFrameGroups: [1, 1, 1, 1]),
      const ProductionMapNode(id: 'end', kind: 'end', title: 'End'),
    ], edges: const [
      ProductionMapEdge(from: 'start', to: 'cut'),
      ProductionMapEdge(from: 'cut', to: 'end')
    ]);
    await MobileApi.instance.adminSaveProductionMap(source);
    final a = await MobileApi.instance.upsertCalculateOrderTemplate(
        _template(itemCode: 'SKU-A', sourceMapId: source.id)
            .copyWith(frameCount: 5));
    final b = a.copyWith(
        id: 'T-B',
        code: 'Q-B',
        itemCode: 'SKU-B',
        product: 'Product B',
        kg: 120,
        variantId: 'T-B');
    final bad =
        source.copyWith(id: 'zakaz-draft-test-mode-fork', productCode: 'SKU-B');
    await expectLater(
        MobileApi.instance.adminSaveProductionMapWithOrder(
            map: bad, template: b, templateAction: 'fork'),
        throwsA(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'rezka_frame_groups_invalid')));
    expect(
        (await MobileApi.instance.calculateOrderTemplates()).single.id, a.id);
    final corrected = bad.copyWith(nodes: [
      for (final node in bad.nodes)
        node.id == 'cut'
            ? node.copyWith(rezkaKadrCount: 5, rezkaFrameGroups: [2, 3])
            : node
    ]);
    final replies = await Future.wait([
      for (var i = 0; i < 2; i++)
        MobileApi.instance.adminSaveProductionMapWithOrder(
            map: corrected, template: b, templateAction: 'fork')
    ]);
    final first = replies[0];
    final retry = replies[1];
    expect(retry.saved.map.id, first.saved.map.id);
    expect(first.template!.sourceMapId, isNot(source.id));
    expect(first.template!.variantId, b.id);
    await CalculateOrderTemplateStore.instance.load(force: true);
    expect(CalculateOrderTemplateStore.instance.templates.map((t) => t.id),
        containsAll([a.id, b.id]));
    expect(
        (await MobileApi.instance.adminProductionMap(source.id))
            .map
            .nodes[1]
            .rezkaFrameGroups,
        [1, 1, 1, 1]);
  });
  testWidgets('linked template: choosing another SKU forks both identity paths',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    const sourceId = 'template-SKU-A-regression';
    await MobileApi.instance
        .adminSaveProductionMap(_map(id: sourceId, code: '', orderNumber: ''));
    final original = _template(
        itemCode: 'SKU-A',
        sourceMapId: sourceId,
        product: 'Product A',
        customerRef: '');
    ProductionMapTestArgs? args;
    await _pumpCalculateScreen(tester, template: original,
        onProductionMapArguments: (value) {
      args = value as ProductionMapTestArgs;
    });
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text(original.product).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotlunch').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'KG'), '120');
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final attach =
        AppLocalizations(const Locale('uz')).adminText('calculate.map_attach');
    await tester.scrollUntilVisible(find.text(attach), 240,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(attach));
    await tester.pumpAndSettle();
    expect(args, isNotNull);
    expect(args!.orderContext!.templateDraft!.itemCode, 'DEMO-HOTLUNCH');
    expect(args!.orderContext!.templateDraft!.id, isNot(original.id));
    expect(args!.orderContext!.templateDraft!.code, isNot(original.code));
    expect(args!.savedMap!.nodes, isNotEmpty);
  });

  test('linked template: HTTP cutting-plan error keeps its reason and status',
      () async {
    await TestModeController.instance.setEnabled(false);
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'error': 'rezka_frame_groups_invalid',
          'message':
              'Rezka A (cut): kesish rejasida 4 kadr taqsimlangan, mahsulot uchun 5 kadr kerak. Kesish rejasini tekshiring.',
          'cutting_plan_conflicts': [
            {'node_id': 'cut', 'planned_frames': 4, 'required_frames': 5}
          ],
        }),
        400,
        headers: {'x-request-id': 'synthetic-request'}));
    await http.runWithClient(() async {
      try {
        await MobileApi.instance.adminSaveProductionMapWithOrder(
            map: _map(id: 'draft', code: '', orderNumber: ''),
            template: _template(itemCode: 'SKU-A'));
        fail('must reject');
      } on MobileApiException catch (error) {
        expect(error.code, 'rezka_frame_groups_invalid');
        expect(error.statusCode, 400);
        expect(error.requestId, 'synthetic-request');
        expect(error.diagnostics['cutting_plan_conflicts'], isNotEmpty);
        expect(error.message, contains('4 kadr'));
        expect(error.message, contains('5 kadr'));
        expect(error.message, isNot(contains('Server sababini')));
      }
    }, () => client);
  });
}
