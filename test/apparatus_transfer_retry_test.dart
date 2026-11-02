import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/admin/apparatus_transfer_command_store.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'transfer-test-token';
  });
  tearDown(() {
    AppSession.instance.token = null;
  });

  Future<void> submit(String key) async {
    await MobileApi.instance.adminTransferProductionMapOrder(
        orderId: 'zakaz-transfer-retry',
        fromApparatus: 'apparatus:default:bosma_7',
        toApparatus: 'apparatus:default:bosma_8',
        reason: 'Reason $key',
        idempotencyKey: key);
  }

  http.Response success() => http.Response(
      jsonEncode({
        'saved': {
          'map': {
            'id': 'zakaz-transfer-retry',
            'product_code': 'TEST',
            'title': 'Test',
            'nodes': [],
            'edges': []
          },
          'program': {
            'map_id': 'zakaz-transfer-retry',
            'product_code': 'TEST',
            'operations': []
          },
        }
      }),
      200);

  test('lost response retains exact command until acknowledged', () async {
    final commands = <String>[];
    await http.runWithClient(() async {
      await expectLater(
          submit('original-key'), throwsA(isA<TimeoutException>()));
      await submit('new-button-key');
      await submit('next-operation');
    },
        () => MockClient((request) async {
              commands.add(request.body);
              if (commands.length == 1) {
                throw TimeoutException('response lost after commit');
              }
              return success();
            }));
    expect(commands[1], commands[0]);
    expect(jsonDecode(commands[1])['idempotency_key'], 'original-key');
    expect(jsonDecode(commands[2])['idempotency_key'], 'next-operation');
  });

  test('definitive rejection clears command; server failure retains it',
      () async {
    for (final status in [409, 503]) {
      final commands = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await expectLater(
            submit('attempt-$status'), throwsA(isA<MobileApiException>()));
        await submit('retry-$status');
      },
          () => MockClient((request) async {
                commands.add(jsonDecode(request.body) as Map<String, dynamic>);
                return commands.length == 1
                    ? http.Response(
                        '{"error":"apparatus_transfer_target_conflict"}',
                        status)
                    : success();
              }));
      expect(commands[1]['idempotency_key'],
          status == 409 ? 'retry-$status' : 'attempt-$status');
    }
  });

  test('pending commands are isolated by server/account and concurrent retries',
      () async {
    final command = {
      'order_id': 'order',
      'from_apparatus': 'from',
      'to_apparatus': 'to',
      'reason': 'failure',
      'idempotency_key': 'first'
    };
    final results = await Future.wait([
      ApparatusTransferCommandStore.retain('account-a', command),
      ApparatusTransferCommandStore.retain(
          'account-a', {...command, 'idempotency_key': 'second'}),
      ApparatusTransferCommandStore.retain(
          'account-b', {...command, 'idempotency_key': 'other'}),
    ]);
    expect(results[0], results[1]);
    expect(results[2]['idempotency_key'], 'other');
    // Reading preferences anew models a restarted client; only storage carries the command.
    SharedPreferences.resetStatic();
    expect(
        (await ApparatusTransferCommandStore.retain('account-a',
            {...command, 'idempotency_key': 'restart'}))['idempotency_key'],
        'first');
  });
}
