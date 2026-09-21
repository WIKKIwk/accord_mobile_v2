import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'test-token';
  });
  tearDown(() => AppSession.instance.token = null);

  testWidgets('early close card requires comment and returns trimmed reason', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        result = await showProductionMapEarlyCloseDialog(context);
      }, child: const Text('Open')),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(DropdownButton), findsNothing);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Yopish')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Yopish')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '  Mijoz rad etdi  ');
    await tester.pump();
    await tester.tap(find.text('Yopish'));
    await tester.pumpAndSettle();
    expect(result, 'Mijoz rad etdi');
    expect(tester.takeException(), isNull);
  });

  testWidgets('early close cancel returns no reason', (tester) async {
    String? result = 'not cancelled';
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        result = await showProductionMapEarlyCloseDialog(context);
      }, child: const Text('Open')),
    ))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sabab');
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  for (final state in ['freeze_requested', 'frozen']) {
    test('early close API sends only order action and comment: $state', () async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        final result = await MobileApi.instance.adminEarlyCloseProductionOrder(
          orderId: ' zakaz-1 ', comment: ' Muammo ');
        expect(result, AdminOrderControlState.fromRaw(state));
      }, () => MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'ok': true, 'control': {
          'state': state, 'early_close': {'comment': 'Muammo',
            'closed_at_unix': state == 'frozen' ? 123 : null},
        }}), 200);
      }));
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/v1/mobile/admin/production-maps/order-control');
      expect(requests.single.method, 'POST');
      expect(jsonDecode(requests.single.body), {
        'order_id': 'zakaz-1', 'action': 'close_early', 'comment': 'Muammo',
      });
    });
  }

  for (final code in [
    'order_not_started', 'order_already_completed',
    'early_close_comment_required_or_too_long', 'order_freeze_target_not_found',
    'order_freeze_target_ambiguous', 'order_freeze_requested',
    'order_frozen', 'order_control_action_not_allowed',
  ]) {
    test('early close errors describe closure instead of freezing: $code', () async {
      await http.runWithClient(() async {
        await expectLater(MobileApi.instance.adminEarlyCloseProductionOrder(
          orderId: 'zakaz-0009', comment: 'Mijoz rad etdi'),
          throwsA(isA<MobileApiException>()
            .having((error) => error.code, 'server error code', code)
            .having((error) => error.message, 'action-specific message', isNot(contains('muzlat')))
            .having((error) => error.message, 'human-readable message', isNot(equals(code)))));
      }, () => MockClient((_) async => http.Response(jsonEncode({'error': code}), 409)));
    });
  }

  test('ordinary freeze keeps the existing not-started explanation', () async {
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.adminProductionMapOrderControl(
        orderId: 'zakaz-0009', action: AdminOrderControlAction.freeze),
        throwsA(isA<MobileApiException>().having((error) => error.message,
          'freeze message', 'Boshlanmagan buyurtmani muzlatib bo‘lmaydi')));
    }, () => MockClient((_) async => http.Response('{"error":"order_not_started"}', 409)));
  });

  test('unstarted closed order still has a final reason in empty history', () {
    final order = AdminClosedProductionOrder.fromJson({
      'order_id': 'zakaz-0009', 'order_number': '0009',
      'closed_by_role': 'admin', 'closed_by_ref': 'admin-1',
      'closed_by_display_name': 'Ali', 'completed_at_unix': 123,
      'logs': [], 'progress_batches': [],
      'early_close': {'comment': 'Mijoz rad etdi', 'closed_at_unix': 123},
    });
    expect(order.logs, hasLength(1));
    expect(order.logs.single.action, 'close_early');
    expect(order.logs.single.issueNote, 'Mijoz rad etdi');
    expect(order.logs.single.actorDisplayName, 'Ali');
    expect(order.logs.single.createdAtUnix, 123);
    expect(order.progressBatches, isEmpty);
  });

  test('early closure appends after unchanged normal history', () {
    final json = <String, dynamic>{
      'order_id': 'zakaz-1', 'closed_by_role': 'admin', 'closed_by_ref': 'admin-1',
      'closed_by_display_name': 'Ali', 'completed_at_unix': 123,
      'logs': [{
        'event_id': 'start-1', 'apparatus': 'apparatus:test:one', 'action': 'start',
        'actor_display_name': 'Vali', 'created_at_unix': 122,
      }],
    };
    final healthy = AdminClosedProductionOrder.fromJson(json);
    json['early_close'] = {'comment': 'Material mos emas', 'closed_at_unix': 123};
    final closed = AdminClosedProductionOrder.fromJson(json);
    expect(healthy.logs, hasLength(1));
    expect(closed.logs, hasLength(2));
    expect(closed.logs.first.eventId, healthy.logs.first.eventId);
    expect(closed.logs.first.actorDisplayName, 'Vali');
    expect(closed.logs.last.action, 'close_early');
    expect(closed.logs.last.issueNote, 'Material mos emas');
    expect(closed.logs.last.actorDisplayName, 'Ali');
    expect(closed.logs.last.createdAtUnix, 123);
    expect(closed.progressBatches, isEmpty, reason: 'No invented production output');
  });
}
