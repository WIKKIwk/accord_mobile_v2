import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _product =
    QolipProduct(code: 'ITEM', name: 'Product', itemGroup: 'Tayyor mahsulot');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
  });

  test('single and batch receipts send and restore persisted warehouse',
      () async {
    final bodies = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      final single = await MobileApi.instance.qolipSaveProductSpec(
          product: _product,
          qolipCode: 'Q-1',
          size: 40,
          warehouse: 'Flexo ombori');
      expect(single.warehouse, 'Flexo ombori');
      await MobileApi.instance.qolipSaveProductSpec(
          product: single,
          qolipCode: 'Q-RENAMED',
          size: 41,
          previousQolipCode: 'Q-1');
      final batch = await MobileApi.instance.qolipSaveProductSpecsBatch(
          product: _product,
          warehouse: 'Flexo ombori',
          specs: [const QolipProductSpecBatchItem(qolipCode: 'Q-2', size: 40)]);
      expect(batch.single.warehouse, 'Flexo ombori');
    },
        () => MockClient((request) async {
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              bodies.add(body);
              final isBatch = body.containsKey('specs');
              final spec =
                  isBatch ? body['specs'][0] as Map<String, dynamic> : body;
              expect(spec['warehouse'], 'Flexo ombori');
              final product = {
                'code': 'ITEM',
                'name': 'Product',
                'item_group': 'Tayyor mahsulot',
                'qolip_code': spec['qolip_code'],
                'warehouse': spec['warehouse'],
                'size': spec['size'],
                'has_qolip_spec': true
              };
              return http.Response(
                  jsonEncode(isBatch
                      ? {
                          'products': [product]
                        }
                      : {'product': product}),
                  200);
            }));
    expect(bodies, hasLength(3));
  });

  for (final warehouses in [
    <String>['Flexo ombori'],
    <String>['Bosma ombori', 'Flexo ombori'],
    <String>[]
  ]) {
    testWidgets('receipt warehouse selection for $warehouses', (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                        onPressed: () => showQolipProductSpecSheet(context,
                            initialProduct: _product),
                        child: const Text('Open'),
                      ))),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        if (warehouses.isEmpty) {
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
          return;
        }
        final field = tester.widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>));
        expect(field.initialValue,
            warehouses.length == 1 ? warehouses.single : isNull);
        if (warehouses.length > 1) {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Flexo ombori').last);
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<DropdownButtonFormField<String>>(
                      find.byType(DropdownButtonFormField<String>))
                  .initialValue,
              'Flexo ombori');
        }
      },
          () => MockClient((request) async {
                expect(request.url.path, '/v1/mobile/qolip/blocks');
                return http.Response(
                    jsonEncode({'warehouses': warehouses, 'blocks': []}), 200);
              }));
    });
  }
}
