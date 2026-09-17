import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const station = 'apparatus:default:asset-007';
  const order = 'zakaz-0073';
  const qr = '400118D5A225166D31898C1F';
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'test-session';
  });
  tearDown(() { AppSession.instance.token = null; });
  for (final validation in ['valid', 'missing', 'wrong_apparatus', 'wrong_order']) {
    test('scoped QR lookup requires exact server confirmation: $validation', () async {
      Object? sent;
      await http.runWithClient(() async {
        final future = MobileApi.instance.adminProgressQrLookup(qr,
          apparatus: station, orderId: order);
        if (validation == 'valid') {
          final batch = await future;
          expect(batch.nextApparatus, 'apparatus:default:asset-008');
          expect(batch.wipStatus, 'waiting');
        } else {
          await expectLater(future, throwsA(isA<MobileApiException>().having(
            (e) => e.code, 'code', 'progress_batch_not_accepted')));
        }
      }, () => MockClient((request) async {
        sent = jsonDecode(request.body);
        return http.Response(jsonEncode({
          if (validation != 'missing') ...{
            'validated_apparatus': validation == 'wrong_apparatus' ? 'apparatus:default:asset-008' : station,
            'validated_order_id': validation == 'wrong_order' ? 'other-order' : order,
          },
          'batch': {
            'batch_id': 'roll-0073', 'order_id': order, 'qr_payload': qr,
            'apparatus': 'apparatus:default:bosma_9',
            'next_apparatus': 'apparatus:default:asset-008', 'wip_status': 'waiting',
          },
        }), 200);
      }));
      expect(sent, {'qr_payload': qr, 'apparatus': station, 'order_id': order});
    });
  }
}
