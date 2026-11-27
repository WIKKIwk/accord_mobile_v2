import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preparation_material_management_test.dart' as fixtures;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = fixtures.profile(UserRole.tayyorlovMasteri);
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'order consumption reviews only spendable Seriyo and retries the same command',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(fixtures.app(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const PreparationOrderConsumptionScreen(
                                      orderId: 'o1'))),
                      child: const Text('Buyurtma'))))));
      await tester.tap(find.text('Buyurtma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seriyo tanlash'));
      await tester.pumpAndSettle();
      expect(find.text('Tayyor rulon'), findsNothing);
      expect(find.text('Band seriyo'), findsNothing);
      await tester.tap(find.text('Granula'));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField);
      await tester.enterText(field, '51');
      await tester.pump();
      expect(find.text('Sarfga tayyor qoldiq yetarli emas'), findsOneWidget);
      final review = find.widgetWithText(FilledButton, 'Sarfni ko‘rib chiqish');
      expect(tester.widget<FilledButton>(review).onPressed, isNull);
      await tester.enterText(field, '25');
      await tester.pump();
      expect(find.text('Sarf · 5 kg'), findsOneWidget);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      expect(find.textContaining('Granula · 5 kg'), findsOneWidget);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.tap(review);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarfni tasdiqlash').last);
      await tester.pumpAndSettle();
      expect(writes, hasLength(1));
      expect(writes.single, {
        'order_id': 'o1',
        'warehouse': 'W',
        'expected_order_kg': '20',
        'lines': [
          {'item_code': 'input', 'percent': '25.000000'}
        ],
        'request_id': isNotEmpty,
      });
      await tester.tap(find.text('Oldingi sarfni tekshirish'));
      await tester.pumpAndSettle();
      expect(writes, [writes.first, writes.first]);
      expect(find.text('Buyurtma'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response({
                  'history': [],
                  'assigned_warehouses': ['W'],
                  'assigned_warehouse_ids': {'W': 'w'},
                  'orders': [
                    {'id': 'o1', 'code': '01', 'title': 'P', 'order_kg': '20'}
                  ],
                  'materials': [
                    for (final (id, name, seriyo, qty) in [
                      ('input', 'Granula', true, '10'),
                      ('held', 'Band seriyo', true, '0'),
                      ('roll', 'Tayyor rulon', false, '10')
                    ])
                      {
                        'item_code': id,
                        'name': name,
                        'is_seriyo': seriyo,
                        'visible_warehouses': ['W'],
                        'balances': [
                          {'warehouse': 'W', 'kg': '90'}
                        ],
                        'consumable_balances': [
                          {'warehouse': 'W', 'kg': qty}
                        ],
                      },
                  ],
                });
              }
              expect(request.url.path, '/v1/mobile/preparation/consumptions');
              writes.add(jsonDecode(request.body) as Map<String, dynamic>);
              return writes.length == 1
                  ? fixtures.response({'error': 'Retry'}, 503)
                  : fixtures.response({'id': 'cons-1'});
            }));
  });
}
