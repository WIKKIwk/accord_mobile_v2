import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> payload({bool received = false}) => {
      'paddon': {
        'id': 'p1',
        'code': '00001',
        'location': received ? 'WH-1' : 'Rezka'
      },
      'items': [
        {
          'batch_id': 'b1',
          'apparatus': 'apparatus:default:asset-010',
          'finished_goods_kg': 12,
          'processed_by_apparatus': received ? 'warehouse:WH-1' : ''
        }
      ],
      'warehouses': ['WH-1'],
      'snapshot_token': 'snapshot-v1',
      'can_receive': !received,
      'receipt': received
          ? {'warehouse': 'WH-1', 'accepted_by_display_name': 'Werka'}
          : null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.instance.setSession(
        token: 'token',
        profile: const SessionProfile(
            role: UserRole.werka,
            ref: 'keeper',
            displayName: 'Werka',
            legalName: '',
            phone: '',
            avatarUrl: '',
            capabilities: ['werka.access']));
  });
  tearDown(() => AppSession.instance.clear());

  test('Werka preview and receive use authenticated pallet contract', () async {
    var writes = 0;
    await http.runWithClient(() async {
      final preview = await MobileApi.instance.werkaPaddonPreview(' 00001 ');
      expect(preview.snapshot.items.single.batchId, 'b1');
      final receipt =
          await MobileApi.instance.werkaReceivePaddon(preview, 'WH-1');
      expect(receipt['warehouse'], 'WH-1');
      expect(writes, 1);
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer token');
              if (request.method == 'GET') {
                expect(request.url.path, '/v1/mobile/werka/paddons/preview');
                expect(request.url.queryParameters['code'], '00001');
                return http.Response(jsonEncode(payload()), 200);
              }
              writes++;
              expect(request.url.path, '/v1/mobile/werka/paddons/receive');
              expect(jsonDecode(request.body), {
                'code': '00001',
                'warehouse': 'WH-1',
                'expected_batch_ids': ['b1'],
                'snapshot_token': 'snapshot-v1'
              });
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'receipt': payload(received: true)['receipt']
                  }),
                  200);
            }));
  });

  test(
      'received batch supports warehouse processor without relaxing apparatus IDs',
      () {
    final preview = WerkaPaddonPreview.fromJson(payload(received: true));
    expect(
        preview.snapshot.items.single.processedByApparatus, 'warehouse:WH-1');
    expect(preview.canReceive, isFalse);
    for (final bad in ['Rezka', 'warehouse:', '']) {
      final data = payload();
      (data['items'] as List).single['apparatus'] = bad;
      expect(() => WerkaPaddonPreview.fromJson(data),
          throwsA(isA<MobileApiException>()));
    }
  });

  test('receipt conflict is surfaced to refresh, not retried automatically',
      () async {
    var writes = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.werkaReceivePaddon(
              WerkaPaddonPreview.fromJson(payload()), 'WH-1'),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'paddon_receipt_conflict')));
    },
        () => MockClient((_) async {
              writes++;
              return http.Response(
                  jsonEncode({'error': 'paddon_receipt_conflict'}), 409);
            }));
    expect(writes, 1);
  });
}
