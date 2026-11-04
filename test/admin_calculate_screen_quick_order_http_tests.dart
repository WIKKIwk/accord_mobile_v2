part of 'admin_calculate_screen_test.dart';

void _registerQuickOrderHttpTests() {
  for (final role in [UserRole.admin, UserRole.brigader, UserRole.salesManager]) {
    testWidgets('bobina sale switch is available before calculation for $role',
        (tester) async {
      await TestModeController.instance.setEnabled(true);
      AppSession.instance.profile = SessionProfile(
        role: role,
        displayName: 'Test',
        legalName: 'Test',
        ref: 'TEST-001',
        phone: '',
        avatarUrl: '',
      );
      await _pumpCalculateScreen(tester);
      final bobinaSwitch =
          find.byKey(const ValueKey('calculate-include-bobina-in-net'));
      await tester.scrollUntilVisible(bobinaSwitch, 240,
          scrollable: find.byType(Scrollable).first);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(bobinaSwitch).value, isFalse);
      await tester.tap(bobinaSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(bobinaSwitch).value, isTrue);
    });
    _registerQuickOrderHttpTest(role);
  }
}

void _registerQuickOrderHttpTest(UserRole role) {
  testWidgets('saved quick order opens without a preliminary template write: $role',
      (tester) async {
    AppSession.instance.profile = SessionProfile(
      role: role,
      displayName: 'Test user',
      legalName: '',
      ref: 'TEST-USER',
      phone: '',
      avatarUrl: '',
    );
    await TestModeController.instance.setEnabled(false);
    const sourceMapId = 'template-quick-order';
    var template = _template(
      itemCode: 'ABCD Family',
      product: 'ABCD Family',
      customer: 'ABCD Family',
      sourceMapId: sourceMapId,
      secondLayerMaterial: 'BOPP metal',
    ).copyWith(
      code: '0012',
      status: 'Rulon',
      frameProductSizeMm: 410,
      frameCount: 1,
      widthMm: 425,
      rollCount: 6,
      firstLayerMaterial: 'PE oq',
      firstLayerMicron: '12',
    );
    final sourceMap = _map(id: sourceMapId, code: '', orderNumber: '')
        .copyWith(widthMm: 425, rollCount: 6, duplicateRezkaLabels: true);
    final requests = <String>[];
    final opened = <Map<String, dynamic>>[];
    var templateSaved = false;
    final client = MockClient((request) async {
      final path = request.url.path;
      requests.add('${request.method} $path');
      Map<String, dynamic> payload;
      if (path == '/v1/mobile/calculate/orders') {
        if (request.method == 'POST') {
          templateSaved = true;
          template = CalculateOrderTemplate.fromJson(
            jsonDecode(request.body) as Map<String, dynamic>,
          );
          payload = {'template': template.toJson()};
        } else {
          if (templateSaved) {
            throw http.ClientException('Template list refresh failed');
          }
          payload = {
            'templates': [template.toJson()]
          };
        }
      } else if (path == '/v1/mobile/calculate') {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        payload = {
          'ok': true,
          'kg': input['kg'],
          'width_mm': 425,
          'waste_percent': 5,
          'layers': input['layers'],
          'results': [
            {'rounded_length': 65000}
          ],
        };
      } else if (path == '/v1/mobile/admin/production-maps') {
        payload = {
          'map': sourceMap.toJson(),
          'program': {'operations': []},
        };
      } else if (path == '/v1/mobile/admin/production-maps/with-order') {
        final input = jsonDecode(request.body) as Map<String, dynamic>;
        opened.add(input);
        final map = (input['map'] as Map).cast<String, dynamic>();
        final number = (12 + opened.length).toString().padLeft(4, '0');
        payload = {
          'ok': true,
          'saved': {
            'map': {
              ...map,
              'id': 'zakaz-$number',
              'code': number,
              'order_number': number
            },
            'program': {'operations': []},
          },
          'template': null,
        };
      } else {
        throw StateError('Unexpected request: ${request.method} $path');
      }
      return http.Response(jsonEncode(payload), 200);
    });
    await http.runWithClient(() async {
      await _pumpCalculateScreen(tester, template: template);
      for (final kg in ['100', '1000']) {
        await tester.scrollUntilVisible(
          find.widgetWithText(TextFormField, 'KG'),
          -240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.widgetWithText(TextFormField, 'KG'), kg);
        await tester.pumpAndSettle();
        final printSideSwitch =
            find.byKey(const ValueKey('calculate-standard-print-side'));
        await tester.scrollUntilVisible(printSideSwitch, 240,
            scrollable: find.byType(Scrollable).first);
        expect(tester.widget<SwitchListTile>(printSideSwitch).value, isTrue);
        expect(find.widgetWithText(SwitchListTile, 'Standart'), findsOneWidget);
        if (kg == '100') {
          await tester.tap(printSideSwitch);
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(printSideSwitch).value, isFalse);
          expect(
              find.widgetWithText(SwitchListTile, 'Nostandart'), findsOneWidget);
        }
        final duplicateToggle = find.byKey(
          const ValueKey('calculate-duplicate-rezka-labels'),
        );
        await tester.scrollUntilVisible(duplicateToggle, 240,
            scrollable: find.byType(Scrollable).first);
        expect(tester.widget<SwitchListTile>(duplicateToggle).value, isFalse);
        if (kg == '100') {
          await tester.tap(duplicateToggle);
          await tester.pumpAndSettle();
        }
        final bobinaSwitch = find.byKey(const ValueKey('calculate-include-bobina-in-net'));
        await tester.scrollUntilVisible(bobinaSwitch, 240,
            scrollable: find.byType(Scrollable).first);
        expect(tester.widget<SwitchListTile>(bobinaSwitch).value, isFalse);
        if (kg == '100') {
          await tester.tap(bobinaSwitch);
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(bobinaSwitch).value, isTrue);
          await tester.tap(bobinaSwitch);
          await tester.pumpAndSettle();
          expect(tester.widget<SwitchListTile>(bobinaSwitch).value, isFalse);
          await tester.tap(bobinaSwitch);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Hisoblash'));
        await tester.tap(find.text('Hisoblash'));
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(bobinaSwitch).value, kg == '100');
        final openLabel = AppLocalizations(const Locale('uz')).adminText('calculate.order_open');
        await tester.scrollUntilVisible(find.text(openLabel), 240,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text(openLabel));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(
          const ValueKey('production-map-order-confirm'),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Zakaz ochilmadi'), findsNothing,
            reason: requests.join('\n'));
        expect(opened.length, kg == '100' ? 1 : 2, reason: requests.join('\n'));
        expect(opened.last['template']['kg'], double.parse(kg));
        expect(opened.last['map']['order_kg'], double.parse(kg));
        expect(opened.last['map']['duplicate_rezka_labels'], kg == '100');
        expect(opened.last['map']['include_bobina_in_net'], kg == '100');
        expect(opened.last['map']['standard_print_side'], kg != '100');
        expect(opened.last['template']['source_map_id'], sourceMapId);
        expect(opened.last['template']['frame_product_size_mm'], 410);
        expect(opened.last['template']['roll_count'], 6);
        expect(opened.last['map']['id'], startsWith('zakaz-draft-'));
        await tester.pump(const Duration(seconds: 6));
      }
      expect(opened.map((input) => input['map']['id']).toSet(), hasLength(2));
      expect(CalculateOrderTemplateStore.instance.templates.single.code, '0012');
      expect(templateSaved,isFalse,reason:'Opening an order must not upsert its source quick template');
    }, () => client);
  });
}
