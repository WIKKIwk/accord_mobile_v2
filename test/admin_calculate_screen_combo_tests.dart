part of 'admin_calculate_screen_test.dart';

void _registerComboTests() {
  testWidgets(
      'planner recalculates an unchanged combo without a catalog create request',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Planner',
        legalName: 'Planner',
        ref: 'PLANNER',
        phone: '',
        avatarUrl: '',
        capabilities: ['production.map.manage']);
    const ref = ProductionComboReference(
        id: 'combo-planner',
        itemCode: 'COMBO-PLANNER',
        name: 'Existing combo',
        revision: 3,
        layoutFingerprint: 'fingerprint');
    var comboWrites = 0;
    await http.runWithClient(() async {
      await _pumpCalculateScreen(tester,
          template: _mixedTemplate().copyWith(
              combo: ref,
              name: ref.name,
              product: ref.name,
              itemCode: ref.itemCode));
      tester.view.physicalSize = const Size(430, 5000);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Umumiy KG'), '400');
      await tester.tap(find.text('Hisoblash'));
      await tester.pumpAndSettle();
      expect(AppSession.instance.can('catalog.item.create'), isFalse);
      expect(comboWrites, 0);
      expect(find.byKey(const ValueKey('combo-name-input')), findsNothing);
      expect(find.text('Kombo · v3'), findsOneWidget);
      expect(
          find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/admin/combos') comboWrites++;
              if (request.url.path == '/v1/mobile/calculate') {
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      'kg': 400,
                      'width_mm': 575,
                      'results': [
                        {'rounded_length': 500}
                      ]
                    }),
                    200);
              }
              return http.Response('{"templates":[]}', 200);
            }));
  });

  testWidgets(
      'combo calculate cancel does not enable opening or create a catalog item',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await _pumpCalculateScreen(tester, template: _mixedTemplate());
    tester.view.physicalSize = const Size(430, 5000);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Umumiy KG'), '300');
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Komboga nom bering'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('combo-name-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Kombo nomini kiriting'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('combo-name-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsNothing);
    expect(find.text('Avtomatik ochish'), findsNothing);
    expect(find.textContaining('Kombo · v'), findsNothing);
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Komboga nom bering'), findsOneWidget);
    await _confirmComboName(tester, 'Yangi vitaminlar');
    expect(find.textContaining('Kombo · v1'), findsOneWidget);
  });

  testWidgets(
      'choosing a combo restores ordered children rather than nesting its catalog SKU',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    const ref = ProductionComboReference(
        id: 'combo-picked',
        itemCode: 'COMBO-77',
        name: 'Tanlangan kombo',
        revision: 3,
        layoutFingerprint: 'fingerprint');
    var comboReads = 0;
    await http.runWithClient(() async {
      await _pumpCalculateScreen(tester);
      tester.view.physicalSize = const Size(430, 5000);
      await tester.pumpAndSettle();
      final label = AppLocalizations(const Locale('uz'))
          .adminText('calculate.product_select');
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanlangan kombo'));
      await tester.pumpAndSettle();
      expect(comboReads, 1);
      expect(find.text('Kombo · v3'), findsOneWidget);
      expect(find.text('Jami: 6 kadr · foydali en 560 mm'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Umumiy KG'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '1 ta kadrning eni'),
          findsNWidgets(4));
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/admin/combos') {
                comboReads++;
                expect(request.url.queryParameters['item_code'], 'COMBO-77');
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      'combo': ref.toJson(),
                      'template': _mixedTemplate()
                          .copyWith(
                              combo: ref, name: ref.name, product: ref.name)
                          .toJson()
                    }),
                    200);
              }
              if (request.url.path == '/v1/mobile/admin/items') {
                return http.Response(
                    jsonEncode([
                      {
                        'code': 'COMBO-77',
                        'name': 'Tanlangan kombo',
                        'item_group': 'Kombo',
                        'uom': 'kg'
                      }
                    ]),
                    200);
              }
              return http.Response('{"templates":[]}', 200);
            }));
  });

  testWidgets(
      'account change during combo calculation discards result before name or catalog write',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    final calculation = Completer<http.Response>();
    var writes = 0;
    await http.runWithClient(() async {
      await _pumpCalculateScreen(tester, template: _mixedTemplate());
      tester.view.physicalSize = const Size(430, 5000);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Umumiy KG'), '300');
      await tester.tap(find.text('Hisoblash'));
      await tester.pump();
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.admin,
          displayName: 'Other',
          legalName: 'Other',
          ref: 'OTHER',
          phone: '',
          avatarUrl: '');
      calculation.complete(http.Response(
          jsonEncode({
            'ok': true,
            'kg': 300,
            'width_mm': 575,
            'results': [
              {'rounded_length': 500}
            ]
          }),
          200));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('combo-name-input')), findsNothing);
      expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsNothing);
      expect(writes, 0);
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/calculate') {
                return calculation.future;
              }
              if (request.url.path == '/v1/mobile/admin/combos') writes++;
              return http.Response('{"templates":[]}', 200);
            }));
  });

  testWidgets(
      'changing customer clears the old combo master instead of reusing another customer tooling',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    const ref = ProductionComboReference(
        id: 'combo-customer',
        itemCode: 'COMBO-CUSTOMER',
        name: 'Original combo',
        revision: 1,
        layoutFingerprint: 'signature');
    await http.runWithClient(() async {
      await _pumpCalculateScreen(tester,
          template: _mixedTemplate().copyWith(
              combo: ref,
              itemCode: ref.itemCode,
              name: ref.name,
              product: ref.name,
              customer: 'Current Customer'));
      tester.view.physicalSize = const Size(430, 5000);
      await tester.pumpAndSettle();
      expect(find.text('Kombo · v1'), findsOneWidget);
      await tester.tap(find.text('Current Customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Customer'));
      await tester.pumpAndSettle();
      expect(find.text('Kombo · v1'), findsNothing);
      expect(find.text('Original combo'), findsNothing);
      expect(find.text('New Customer'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/admin/customers/list') {
                return http.Response(
                    '[{"ref":"NEW-CUSTOMER","name":"New Customer"}]', 200);
              }
              return http.Response('{"templates":[]}', 200);
            }));
  });

  testWidgets(
      'combo prompt opens once and KG recalculation retains name and revision',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    ProductionMapTestArgs? mapArgs;
    await _pumpCalculateScreen(tester,
        template: _mixedTemplate(),
        onProductionMapArguments: (value) =>
            mapArgs = value as ProductionMapTestArgs);
    tester.view.physicalSize = const Size(430, 5000);
    await tester.pumpAndSettle();
    final kg = find.widgetWithText(TextFormField, 'Umumiy KG');
    await tester.enterText(kg, '300');
    await tester.tap(find.text('Hisoblash'));
    await tester.tap(find.text('Hisoblash'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('combo-name-input')), findsOneWidget);
    await _confirmComboName(tester, 'Nomlangan kombo', doubleSubmit: true);
    expect(find.text('Nomlangan kombo'), findsWidgets);
    expect(find.text('Kombo · v1'), findsOneWidget);
    await tester.enterText(kg, '400');
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('combo-name-input')), findsNothing);
    expect(find.text('Nomlangan kombo'), findsWidgets);
    expect(find.text('Kombo · v1'), findsOneWidget);
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, '1 ta kadrning eni').first, '120');
    await tester.pumpAndSettle();
    expect(find.text('Mahsulotlar bo‘yicha taxminiy chiqish'), findsNothing);
    await tester.tap(find.text('Hisoblash'));
    await tester.pumpAndSettle();
    expect(find.text('Kombo · v2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    final attach =
        AppLocalizations(const Locale('uz')).adminText('calculate.map_attach');
    await tester.tap(find.text(attach));
    await tester.pumpAndSettle();
    expect(mapArgs!.orderContext!.orderName, 'Nomlangan kombo');
    final draft = mapArgs!.orderContext!.templateDraft!;
    expect(draft.combo!.revision, 2);
    expect(draft.itemCode, draft.combo!.itemCode);
    expect(draft.products.map((p) => p.itemCode),
        ['SKU-1', 'SKU-2', 'SKU-3', 'SKU-4']);

    expect(find.byKey(const ValueKey('combo-name-input')), findsNothing);
  });
}
