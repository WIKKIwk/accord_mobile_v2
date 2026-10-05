part of 'admin_calculate_screen_test.dart';

void _registerQuickOrderHttpTests() {
  testWidgets('saved quick order opens even when post-save list refresh fails',
      (tester) async {
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
        .copyWith(widthMm: 425, rollCount: 6);
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
        await tester.ensureVisible(find.text('Hisoblash'));
        await tester.tap(find.text('Hisoblash'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Zakaz ochish'), 240,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('Zakaz ochish'));
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
        expect(opened.last['template']['source_map_id'], sourceMapId);
        expect(opened.last['template']['frame_product_size_mm'], 410);
        expect(opened.last['template']['roll_count'], 6);
        expect(opened.last['map']['id'], startsWith('zakaz-draft-'));
        await tester.pump(const Duration(seconds: 6));
      }
      expect(opened.map((input) => input['map']['id']).toSet(), hasLength(2));
      expect(CalculateOrderTemplateStore.instance.templates.single.code, '0012');
    }, () => client);
  });
}
