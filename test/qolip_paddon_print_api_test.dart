import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'qolip-print-test';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'print-clerk',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });
  test('printing uses scoped mold pallet endpoint without lifecycle writes',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final job = await MobileApi.instance.qolipPrintPaddonQr(
          code: ' qp-00012 ',
          driverUrl: 'http://printer/',
          transport: PrintTransport.offline);
      expect(job.epc, 'QP-00012');
      expect(job.isPaddonCodeLabel, isTrue);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/v1/mobile/qolip/paddons/qr/print');
      final payload = jsonDecode(requests.single.body) as Map;
      expect(payload['print_transport'], 'offline');
      expect(payload['qolip_code'], 'QP-00012');
      expect(payload.containsKey('action'), isFalse);
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'qr_payload': 'QP-00012',
                    'print': {
                      'qr_payload': 'QP-00012',
                      'label_kind': 'paddon_code'
                    }
                  }),
                  200);
            }));
  });
  test('mismatched QR response cannot be printed', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance
              .qolipPrintPaddonQr(code: 'QP-00012', driverUrl: ''),
          throwsFormatException);
    },
        () => MockClient((_) async => http.Response(
            '{"ok":true,"qr_payload":"QP-OTHER","print":{}}', 200)));
  });
}
